import NearbyShareCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView:View{
	@EnvironmentObject private var model:NearDropModel
	@Environment(\.openURL) private var openURL
	@State private var importing=false

	var body:some View{
		NavigationStack{
			ZStack{
				SignalBackground()
				.overlay(alignment:.center){
					TransferIsland(importing:$importing)
						.environmentObject(model)
						.padding(.horizontal,16)
						.frame(maxWidth:640)
				}
			}
			.navigationTitle("NearDrop")
			.navigationBarTitleDisplayMode(.inline)
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
}

private struct QRItem:Identifiable{
	let id=UUID()
	let url:URL
}

private struct TransferIsland:View{
	@EnvironmentObject private var model:NearDropModel
	@Binding var importing:Bool

	var body:some View{
		VStack(spacing:0){
			header
				.padding(.horizontal,24)
				.padding(.top,24)
				.padding(.bottom,20)
			Divider()
			content
				.padding(24)
			Divider()
			footer
				.padding(12)
		}
		.background(.regularMaterial, in:RoundedRectangle(cornerRadius:34, style:.continuous))
		.overlay{
			RoundedRectangle(cornerRadius:34, style:.continuous)
				.stroke(Color.primary.opacity(0.12), lineWidth:0.5)
		}
		.shadow(color:.black.opacity(0.12), radius:28, y:14)
		.animation(.spring(response:0.35, dampingFraction:0.86), value:model.phase)
	}

	private var header:some View{
		VStack(alignment:.leading, spacing:10){
			DotMatrixText(text:statusText, activeColor:statusColor)
				.id(statusText)
			HStack(spacing:8){
				Circle()
					.fill(model.isAvailable ? Color.green : Color.secondary)
					.frame(width:7, height:7)
				Text(model.isAvailable ? "Visible while NearDrop is open" : "Not available in the background")
					.font(.footnote.monospaced())
					.foregroundStyle(.secondary)
			}
		}
		.frame(maxWidth:.infinity, alignment:.leading)
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
					transferState(icon:"arrow.left.arrow.right", title:name, detail:"Keep both devices awake and NearDrop open.")
					ProgressView(value:progress)
						.tint(.teal)
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
			if model.selectedURLs.isEmpty{
				Label{
					VStack(alignment:.leading, spacing:4){
						Text("Send something nearby").font(.headline)
						Text("Choose files, photos, or documents.").font(.subheadline).foregroundStyle(.secondary)
					}
				} icon:{
					Image(systemName:"square.and.arrow.up")
						.font(.title2)
						.foregroundStyle(.teal)
				}
			}else{
				Label{
					VStack(alignment:.leading, spacing:4){
						Text(selectionTitle).font(.headline)
						Text("Choose a nearby Android device.").font(.subheadline).foregroundStyle(.secondary)
					}
				} icon:{
					Image(systemName:"doc.on.doc")
						.font(.title2)
						.foregroundStyle(.teal)
				}
				if model.devices.isEmpty{
					HStack(spacing:10){
						ProgressView().controlSize(.small)
						Text("Looking on this Wi-Fi network…")
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
				}else{
					VStack(spacing:0){
						ForEach(Array(model.devices.enumerated()), id:\.element.id){ index, device in
							if index>0{Divider()}
							Button{model.send(to:device)} label:{
								DeviceRow(device:device)
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

	private func incoming(_ request:NearDropModel.IncomingRequest)->some View{
		VStack(alignment:.leading, spacing:18){
			Label{
				VStack(alignment:.leading, spacing:4){
					Text(request.device.name).font(.headline)
					Text(incomingDescription(request.transfer)).font(.subheadline).foregroundStyle(.secondary)
				}
			} icon:{
				Image(systemName:deviceSymbol(request.device.type))
					.font(.title2)
					.foregroundStyle(.teal)
			}
			if let pin=request.transfer.pinCode{
				Text("Confirm code \(pin) on both devices.")
					.font(.subheadline)
			}
			HStack{
				Button("Decline", role:.cancel, action:model.declineIncoming)
					.buttonStyle(.bordered)
					.frame(maxWidth:.infinity)
				Button("Accept", action:model.acceptIncoming)
					.buttonStyle(.borderedProminent)
					.tint(.teal)
					.frame(maxWidth:.infinity)
			}
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
				.tint(.teal)
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
				.tint(.teal)
				.frame(maxWidth:.infinity)
		}
	}

	private var selectionTitle:String{
		model.selectedURLs.count==1 ? model.selectedURLs[0].lastPathComponent : "\(model.selectedURLs.count) items selected"
	}

	private var statusText:String{
		if model.incomingRequest != nil{return "INCOMING"}
		switch model.phase{
		case .ready:return model.selectedURLs.isEmpty ? "READY" : "NEARBY"
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
		default:return .cyan
		}
	}

	private func incomingDescription(_ transfer:TransferMetadata)->String{
		if let text=transfer.textDescription{return text}
		if transfer.files.count==1{return transfer.files[0].name}
		return "\(transfer.files.count) files"
	}
}

private struct DeviceRow:View{
	let device:RemoteDeviceInfo

	var body:some View{
		HStack(spacing:14){
			Image(systemName:deviceSymbol(device.type))
				.font(.title3)
				.foregroundStyle(.teal)
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
