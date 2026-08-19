import NearbyShareCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView:View{
	@EnvironmentObject private var model:LiftDropModel
	@Environment(\.openURL) private var openURL
	@Environment(\.colorScheme) private var colorScheme
	@AppStorage("dotPalette") private var paletteID=DotPalette.shoreline.id
	@AppStorage("appearance") private var appearance=AppearanceOption.system
	@State private var importing=false

	private var palette:DotPalette{.named(paletteID)}

	var body:some View{
		NavigationStack{
			ZStack{
				SignalBackground(palette:palette)
				.overlay(alignment:.center){
					TransferIsland(importing:$importing, palette:palette)
						.environmentObject(model)
						.padding(.horizontal,16)
						.frame(maxWidth:640)
				}
			}
			.navigationTitle("LiftDrop")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar{
				ToolbarItem(placement:.navigationBarTrailing){
					settingsMenu
				}
			}
			.fileImporter(
				isPresented:$importing,
				allowedContentTypes:[.item],
				allowsMultipleSelection:true
			){ result in
				if case let .success(urls)=result{model.choose(urls:urls)}
			}
			.sheet(item:Binding(
				get:{model.qrCodeURL.map(QRItem.init)},
				set:{if $0==nil{model.dismissQRCode()}}
			)){ item in
				QRCodeSheet(url:item.url, dismiss:model.dismissQRCode)
					.presentationDetents([.large])
			}
			.alert(item:$model.receivedLink){ link in
				Alert(
					title:Text("Link from \(link.deviceName)"),
					message:Text(link.url.absoluteString),
					primaryButton:.default(Text("Open")){openURL(link.url)},
					secondaryButton:.cancel()
				)
			}
		}
	}

	private var settingsMenu:some View{
		Menu{
			Picker("Palette", selection:$paletteID){
				ForEach(DotPalette.all){ option in
					Text(option.name).tag(option.id)
				}
			}
			Picker("Appearance", selection:$appearance){
				ForEach(AppearanceOption.allCases){ option in
					Text(option.name).tag(option)
				}
			}
		} label:{
			Image(systemName:"paintpalette")
		}
		.tint(palette.accent(for:colorScheme))
		.accessibilityLabel("Display settings")
	}
}

private struct QRItem:Identifiable{
	let id=UUID()
	let url:URL
}

private struct TransferIsland:View{
	@EnvironmentObject private var model:LiftDropModel
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.openURL) private var openURL
	@Binding var importing:Bool
	let palette:DotPalette

	private var accent:Color{palette.accent(for:colorScheme)}

	private var needsLocalNetworkPermission:Bool{
		model.localNetworkStatus == .waitingForPermission
	}

	var body:some View{
		VStack(spacing:0){
			header
				.padding(.horizontal,24)
				.padding(.top,24)
				.padding(.bottom,20)
			Divider()
			content
				.padding(24)
			if showsFooter{
				Divider()
				footer
					.padding(12)
			}
		}
		.background(.regularMaterial, in:RoundedRectangle(cornerRadius:34, style:.continuous))
		.overlay{
			RoundedRectangle(cornerRadius:34, style:.continuous)
				.stroke(Color.primary.opacity(0.12), lineWidth:0.5)
		}
		.shadow(color:.black.opacity(0.12), radius:28, y:14)
		.animation(.spring(response:0.35, dampingFraction:0.86), value:model.phase)
		.animation(.spring(response:0.35, dampingFraction:0.86), value:model.incomingRequest?.id)
	}

	private var showsFooter:Bool{
		model.incomingRequest==nil
	}

	private var header:some View{
		VStack(alignment:.leading, spacing:16){
			DotMatrixBoard(lines:boardLines, width:9, palette:palette)
			if let request=model.incomingRequest{
				incomingSummary(request)
			}
		}
		.frame(maxWidth:.infinity, alignment:.leading)
	}

	/// The board keeps a fixed character width so it does not resize as the
	/// message changes, and splits into a second row to show an incoming PIN.
	private var boardLines:[String]{
		guard let request=model.incomingRequest else{return [statusText]}
		return ["INCOMING", request.transfer.pinCode ?? ""]
	}

	private func incomingSummary(_ request:LiftDropModel.IncomingRequest)->some View{
		HStack(spacing:12){
			Image(systemName:transferSymbol(request.transfer))
				.font(.title2)
				.foregroundStyle(accent)
				.symbolRenderingMode(.hierarchical)
				.frame(width:30)
			VStack(alignment:.leading, spacing:3){
				Text(incomingDescription(request.transfer))
					.font(.subheadline.weight(.semibold))
					.lineLimit(2)
					.multilineTextAlignment(.leading)
				Text(incomingDetail(request))
					.font(.footnote.monospaced())
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			Spacer(minLength:0)
		}
		.frame(maxWidth:.infinity, alignment:.leading)
	}

	private func incomingDetail(_ request:LiftDropModel.IncomingRequest)->String{
		let total=request.transfer.files.reduce(Int64(0)){$0+$1.size}
		guard total>0 else{return "From \(request.device.name)"}
		return "From \(request.device.name) · \(total.formatted(.byteCount(style:.file)))"
	}

	private func transferSymbol(_ transfer:TransferMetadata)->String{
		if transfer.textDescription != nil{return "link"}
		guard transfer.files.count==1, let mimeType=transfer.files.first?.mimeType else{
			return transfer.files.isEmpty ? "doc" : "doc.on.doc"
		}
		if mimeType.hasPrefix("image/"){return "photo"}
		if mimeType.hasPrefix("video/"){return "film"}
		if mimeType.hasPrefix("audio/"){return "waveform"}
		return "doc"
	}

	@ViewBuilder
	private var content:some View{
		if let request=model.incomingRequest{
			incoming(request)
		}else{
			switch model.phase{
			case .ready:
				ready
			case let .connecting(name):
				transferState(icon:"antenna.radiowaves.left.and.right", title:"Connecting to \(name)", detail:"Establishing an encrypted local connection.")
			case let .awaitingApproval(name, pin):
				transferState(icon:"number.square", title:"Check \(name)", detail:"Confirm that both devices show \(pin).")
			case let .transferring(name, progress):
				VStack(spacing:18){
					transferState(icon:"arrow.left.arrow.right", title:name, detail:"Keep both devices awake and LiftDrop open.")
					ProgressView(value:progress)
						.tint(accent)
						.accessibilityLabel("Transfer progress")
						.accessibilityValue(progress.formatted(.percent.precision(.fractionLength(0))))
				}
			case let .complete(message):
				transferState(icon:"checkmark.circle.fill", title:message, detail:"The transfer stayed on your local network.")
			case let .failed(message):
				transferState(icon:"exclamationmark.triangle.fill", title:"Transfer interrupted", detail:message)
			}
		}
	}

	private var ready:some View{
		VStack(alignment:.leading, spacing:18){
			if needsLocalNetworkPermission{
				localNetworkNotice
			}
			if model.selectedURLs.isEmpty{
				Label{
					VStack(alignment:.leading, spacing:4){
						Text("Send something nearby").font(.headline)
						Text("Choose files, photos, or documents.").font(.subheadline).foregroundStyle(.secondary)
					}
				} icon:{
					Image(systemName:"square.and.arrow.up")
						.font(.title2)
						.foregroundStyle(accent)
				}
			}else{
				Label{
					VStack(alignment:.leading, spacing:4){
						Text(selectionTitle).font(.headline)
						Text("Choose a nearby device.").font(.subheadline).foregroundStyle(.secondary)
					}
				} icon:{
					Image(systemName:"doc.on.doc")
						.font(.title2)
						.foregroundStyle(accent)
				}
				if model.devices.isEmpty && !needsLocalNetworkPermission{
					HStack(spacing:10){
						ProgressView().controlSize(.small)
						Text("Looking on this Wi-Fi network…")
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
				}else if !model.devices.isEmpty{
					VStack(spacing:0){
						ForEach(Array(model.devices.enumerated()), id:\.element.id){ index, device in
							if index>0{Divider()}
							Button{model.send(to:device)} label:{
								DeviceRow(device:device, accent:accent)
							}
							.buttonStyle(.plain)
						}
					}
				}
			}

			if !model.receivedItems.isEmpty{
				Divider()
				Text("Recently received")
					.font(.caption.weight(.semibold))
					.foregroundStyle(.secondary)
					.textCase(.uppercase)
				ForEach(model.receivedItems.prefix(3)){ item in
					ShareLink(item:item.url){
						HStack{
							Image(systemName:"doc")
							VStack(alignment:.leading){
								Text(item.url.lastPathComponent).lineLimit(1)
								Text("From \(item.deviceName)").font(.caption).foregroundStyle(.secondary)
							}
							Spacer()
							Image(systemName:"square.and.arrow.up").foregroundStyle(.secondary)
						}
						.contentShape(Rectangle())
					}
					.buttonStyle(.plain)
					.frame(minHeight:44)
				}
			}
		}
		.frame(maxWidth:.infinity, alignment:.leading)
	}

	/// The system prompt only appears while discovery is running, so the island
	/// explains what is being asked for and offers a way back to Settings if the
	/// prompt was already answered with a no.
	private var localNetworkNotice:some View{
		VStack(alignment:.leading, spacing:10){
			Label{
				VStack(alignment:.leading, spacing:4){
					Text("Allow Local Network access").font(.headline)
					Text("LiftDrop finds nearby devices over Wi-Fi. Allow it when iOS asks, or turn it on in Settings.")
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}
			} icon:{
				Image(systemName:"wifi.exclamationmark")
					.font(.title2)
					.foregroundStyle(.orange)
					.symbolRenderingMode(.hierarchical)
			}
			if let settings=URL(string:UIApplication.openSettingsURLString){
				Button("Open Settings"){openURL(settings)}
					.font(.subheadline.weight(.semibold))
					.frame(minHeight:44)
			}
		}
		.frame(maxWidth:.infinity, alignment:.leading)
	}

	private func incoming(_ request:LiftDropModel.IncomingRequest)->some View{
		HStack(spacing:14){
			DotMatrixChoice(grid:.cross, tint:.orange, label:"Decline", action:model.declineIncoming)
			DotMatrixChoice(grid:.check, tint:.green, label:"Accept", action:model.acceptIncoming)
		}
	}

	private func transferState(icon:String, title:String, detail:String)->some View{
		VStack(spacing:14){
			Image(systemName:icon)
				.font(.system(size:34, weight:.medium))
				.foregroundStyle(statusColor)
				.symbolRenderingMode(.hierarchical)
			Text(title)
				.font(.title3.weight(.semibold))
				.multilineTextAlignment(.center)
			Text(detail)
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
		.frame(maxWidth:.infinity)
	}

	@ViewBuilder
	private var footer:some View{
		switch model.phase{
		case .ready:
			HStack(spacing:10){
				Button{importing=true} label:{
					Label(model.selectedURLs.isEmpty ? "Choose items" : "Choose different items", systemImage:"plus")
						.frame(maxWidth:.infinity)
				}
				.buttonStyle(.borderedProminent)
				.tint(accent)
				if !model.selectedURLs.isEmpty{
					Button(action:model.showQRCode){
						Image(systemName:"qrcode")
							.frame(width:32, height:32)
					}
					.buttonStyle(.bordered)
					.accessibilityLabel("Connect with QR code")
				}
			}
		case .connecting, .awaitingApproval, .transferring:
			Button("Cancel transfer", role:.cancel, action:model.cancelTransfer)
				.frame(maxWidth:.infinity)
		case .complete, .failed:
			Button("Done", action:model.reset)
				.buttonStyle(.borderedProminent)
				.tint(accent)
				.frame(maxWidth:.infinity)
		}
	}

	private var selectionTitle:String{
		model.selectedURLs.count==1 ? model.selectedURLs[0].lastPathComponent : "\(model.selectedURLs.count) items selected"
	}

	private var statusText:String{
		switch model.phase{
		case .ready:
			if needsLocalNetworkPermission{return "ALLOW"}
			return model.selectedURLs.isEmpty ? "LISTENING" : "NEARBY"
		case .connecting:return "LINKING"
		case let .awaitingApproval(_, pin):return pin
		case .transferring:return "MOVING"
		case .complete:return "ARRIVED"
		case .failed:return "RETRY"
		}
	}

	private var statusColor:Color{
		switch model.phase{
		case .failed:return .orange
		case .complete:return .green
		default:return accent
		}
	}

	private func incomingDescription(_ transfer:TransferMetadata)->String{
		if let text=transfer.textDescription{return text}
		if transfer.files.count==1{return transfer.files[0].name}
		return "\(transfer.files.count) files"
	}
}

private struct DotMatrixChoice:View{
	let grid:DotGrid
	let tint:Color
	let label:String
	let action:()->Void

	var body:some View{
		Button(action:action){
			DotMatrixDisplay(grid:grid, solidColor:tint)
				.frame(height:96)
				.frame(maxWidth:.infinity)
				.padding(.vertical,18)
				.contentShape(RoundedRectangle(cornerRadius:24, style:.continuous))
		}
		.buttonStyle(.plain)
		.background(tint.opacity(0.12), in:RoundedRectangle(cornerRadius:24, style:.continuous))
		.overlay{
			RoundedRectangle(cornerRadius:24, style:.continuous)
				.stroke(tint.opacity(0.35), lineWidth:1)
		}
		.accessibilityElement(children:.ignore)
		.accessibilityLabel(label)
		.accessibilityAddTraits(.isButton)
	}
}

private struct DeviceRow:View{
	let device:RemoteDeviceInfo
	let accent:Color
	var body:some View{
		HStack(spacing:14){
			Image(systemName:deviceSymbol(device.type))
				.font(.title3)
				.foregroundStyle(accent)
				.frame(width:34)
			Text(device.name)
				.font(.body.weight(.medium))
				.lineLimit(1)
			Spacer()
			Image(systemName:"chevron.right")
				.font(.caption.weight(.semibold))
				.foregroundStyle(.tertiary)
		}
		.frame(minHeight:52)
		.contentShape(Rectangle())
		.accessibilityElement(children:.combine)
		.accessibilityLabel("\(device.name), nearby \(device.type.accessibilityName)")
	}
}

private func deviceSymbol(_ type:RemoteDeviceInfo.DeviceType)->String{
	switch type{
	case .tablet:return "ipad"
	case .computer:return "laptopcomputer"
	case .phone:return "smartphone"
	case .unknown:return "rectangle.connected.to.line.below"
	}
}

private extension RemoteDeviceInfo.DeviceType{
	var accessibilityName:String{
		switch self{
		case .phone:return "phone"
		case .tablet:return "tablet"
		case .computer:return "computer"
		case .unknown:return "device"
		}
	}
}
