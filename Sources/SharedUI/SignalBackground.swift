import SwiftUI

struct SignalBackground:View{
	var palette=DotPalette.shoreline

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.colorScheme) private var colorScheme

	var body:some View{
		let accent=palette.accent(for:colorScheme)
		TimelineView(.animation(minimumInterval:reduceMotion ? 10 : 1/12)){ timeline in
			Canvas{ context, size in
				let time=timeline.date.timeIntervalSinceReferenceDate
				let spacing:CGFloat=22
				for y in stride(from:spacing/2, through:size.height, by:spacing){
					for x in stride(from:spacing/2, through:size.width, by:spacing){
						let distance=hypot(x-size.width/2, y-size.height*0.42)
						let wave=sin(distance/38-time*0.8)
						let alpha=reduceMotion ? 0.1 : 0.07+0.05*(wave+1)/2
						let rect=CGRect(x:x-1.25, y:y-1.25, width:2.5, height:2.5)
						context.fill(Path(ellipseIn:rect), with:.color(accent.opacity(alpha)))
					}
				}
			}
		}
		.background(
			LinearGradient(
				colors:[Color(uiColor:.systemBackground), accent.opacity(colorScheme == .dark ? 0.12 : 0.07), Color(uiColor:.systemBackground)],
				startPoint:.top,
				endPoint:.bottom
			)
		)
		.ignoresSafeArea()
		.accessibilityHidden(true)
	}
}
