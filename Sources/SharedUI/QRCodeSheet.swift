import CoreImage.CIFilterBuiltins
import SwiftUI

struct QRCodeSheet:View{
	let url:URL
	let dismiss:()->Void

	var body:some View{
		NavigationStack{
			VStack(spacing:24){
				Spacer()
				.frame(height:8)
				qrImage
					.interpolation(.none)
					.resizable()
					.scaledToFit()
					.frame(maxWidth:280)
					.padding(20)
					.background(.white, in:RoundedRectangle(cornerRadius:24, style:.continuous))
					.accessibilityLabel("Quick Share QR code")
				VStack(spacing:8){
					Text("Open Quick Share on Android")
						.font(.title3.weight(.semibold))
					Text("Choose “Scan QR code,” then point the camera here. Keep Takeoff open and both devices on the same Wi-Fi.")
						.font(.body)
						.foregroundStyle(.secondary)
						.multilineTextAlignment(.center)
				}
				Spacer()
			}
			.padding(24)
			.navigationTitle("Connect with QR")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar{
				ToolbarItem(placement:.confirmationAction){
					Button("Done", action:dismiss)
				}
			}
		}
	}

	private var qrImage:Image{
		let filter=CIFilter.qrCodeGenerator()
		filter.message=Data(url.absoluteString.utf8)
		filter.correctionLevel="L"
		let context=CIContext()
		guard let output=filter.outputImage,
			  let cgImage=context.createCGImage(output.transformed(by:CGAffineTransform(scaleX:12, y:12)), from:output.extent) else{
			return Image(systemName:"qrcode")
		}
		return Image(decorative:cgImage, scale:1)
	}
}
