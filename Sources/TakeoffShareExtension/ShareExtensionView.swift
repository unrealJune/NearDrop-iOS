import NearbyShareCore
import SwiftUI

struct ShareExtensionView:View{
	@ObservedObject var model:ShareExtensionModel
	@Environment(\.colorScheme) private var colorScheme
	@AppStorage("dotPalette") private var paletteID=DotPalette.shoreline.id
	@AppStorage("appearance") private var appearance=AppearanceOption.system

	private var palette:DotPalette{.named(paletteID)}
	private var accent:Color{palette.accent(for:colorScheme)}

	var body:some View{
		NavigationStack{
			ZStack{
				SignalBackground(palette:palette)
				VStack(spacing:0){
					DotMatrixText(text:status, palette:palette)
						.padding(24)
					Divider()
					content
						.padding(24)
						.frame(maxWidth:.infinity, maxHeight:.infinity)
				}
				.background(.regularMaterial, in:RoundedRectangle(cornerRadius:30, style:.continuous))
				.overlay{
					RoundedRectangle(cornerRadius:30, style:.continuous)
						.stroke(Color.primary.opacity(0.12), lineWidth:0.5)
				}
				.padding(16)
			}
			.preferredColorScheme(appearance.colorScheme)
			.navigationTitle("Takeoff")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar{
				ToolbarItem(placement:.cancellationAction){
					Button("Cancel", action:model.cancel)
				}
			}
			.sheet(item:Binding(
				get:{model.qrCodeURL.map(QRItem.init)},
				set:{if $0==nil{model.dismissQRCode()}}
			)){ item in
				QRCodeSheet(url:item.url, dismiss:model.dismissQRCode)
			}
		}
	}

	@ViewBuilder
	private var content:some View{
		switch model.phase{
		case .loading:
			ProgressView("Preparing items…")
		case .choosing:
			VStack(alignment:.leading, spacing:16){
				Text(model.itemCount==1 ? "Choose a nearby device" : "Send \(model.itemCount) items")
					.font(.headline)
				if model.devices.isEmpty{
					ProgressView("Looking on this Wi-Fi network…")
						.frame(maxWidth:.infinity, alignment:.leading)
				}else{
					ForEach(model.devices, id:\.id){ device in
						Button{model.send(to:device)} label:{
							HStack{
								Image(systemName:"smartphone").foregroundStyle(accent)
								Text(device.name)
								Spacer()
								Image(systemName:"chevron.right").foregroundStyle(.tertiary)
							}
							.frame(minHeight:48)
							.contentShape(Rectangle())
						}
						.buttonStyle(.plain)
					}
				}
				Button(action:model.showQRCode){
					Label("Connect with QR code", systemImage:"qrcode")
						.frame(maxWidth:.infinity)
				}
				.buttonStyle(.bordered)
			}
			.frame(maxWidth:.infinity, alignment:.leading)
		case let .connecting(name):
			state(icon:"antenna.radiowaves.left.and.right", title:"Connecting to \(name)", detail:"Keep this sheet open.")
		case let .approval(pin):
			state(icon:"number.square", title:"Check code \(pin)", detail:"Confirm the same code on Android.")
		case let .sending(progress):
			VStack(spacing:18){
				state(icon:"arrow.up", title:"Sending", detail:"Keep both devices awake.")
				ProgressView(value:progress).tint(accent)
			}
		case .complete:
			state(icon:"checkmark.circle.fill", title:"Sent", detail:"The transfer stayed on your local network.")
		case let .failed(message):
			state(icon:"exclamationmark.triangle.fill", title:"Transfer interrupted", detail:message)
		}
	}

	private func state(icon:String, title:String, detail:String)->some View{
		VStack(spacing:14){
			Image(systemName:icon)
				.font(.system(size:34))
				.foregroundStyle(accent)
			Text(title).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
			Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
		}
		.frame(maxWidth:.infinity, maxHeight:.infinity)
	}

	private var status:String{
		switch model.phase{
		case .loading:return "LOADING"
		case .choosing:return "NEARBY"
		case .connecting:return "LINKING"
		case let .approval(pin):return pin
		case .sending:return "MOVING"
		case .complete:return "ARRIVED"
		case .failed:return "RETRY"
		}
	}
}

private struct QRItem:Identifiable{
	let id=UUID()
	let url:URL
}
