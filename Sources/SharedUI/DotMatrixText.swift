import SwiftUI

struct DotMatrixText:View{
	let text:String
	var activeColor=Color.cyan

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var reveal=0.0

	private let glyphs:[Character:[UInt8]]=[
		"A":[14,17,17,31,17,17,17], "B":[30,17,17,30,17,17,30],
		"C":[14,17,16,16,16,17,14], "D":[30,17,17,17,17,17,30],
		"E":[31,16,16,30,16,16,31], "F":[31,16,16,30,16,16,16],
		"G":[14,17,16,23,17,17,14], "H":[17,17,17,31,17,17,17],
		"I":[14,4,4,4,4,4,14], "J":[7,2,2,2,2,18,12],
		"K":[17,18,20,24,20,18,17], "L":[16,16,16,16,16,16,31],
		"M":[17,27,21,21,17,17,17], "N":[17,25,21,19,17,17,17],
		"O":[14,17,17,17,17,17,14], "P":[30,17,17,30,16,16,16],
		"Q":[14,17,17,17,21,18,13], "R":[30,17,17,30,20,18,17],
		"S":[14,17,16,14,1,17,14], "T":[31,4,4,4,4,4,4],
		"U":[17,17,17,17,17,17,14], "V":[17,17,17,17,17,10,4],
		"W":[17,17,17,21,21,21,10], "X":[17,17,10,4,10,17,17],
		"Y":[17,17,10,4,4,4,4], "Z":[31,1,2,4,8,16,31],
		"0":[14,17,19,21,25,17,14], "1":[4,12,4,4,4,4,14],
		"2":[14,17,1,6,8,16,31], "3":[14,17,1,6,1,17,14],
		"4":[2,6,10,18,31,2,2], "5":[31,16,30,1,1,17,14],
		"6":[14,16,16,30,17,17,14], "7":[31,1,2,4,8,8,8],
		"8":[14,17,17,14,17,17,14], "9":[14,17,17,15,1,1,14],
		" ":[0,0,0,0,0,0,0], "-":[0,0,0,31,0,0,0],
		".":[0,0,0,0,0,0,4]
	]

	var body:some View{
		let characters=Array(text.uppercased())
		let columns=max(1, characters.count*6-1)
		Canvas{ context, size in
			let cell=min(size.width/CGFloat(columns), size.height/7)
			let dot=max(2, cell*0.64)
			for (characterIndex, character) in characters.enumerated(){
				let rows=glyphs[character] ?? glyphs[" "]!
				for row in 0..<7{
					for column in 0..<5{
						let on=(rows[row] & UInt8(1 << (4-column))) != 0
						let sequence=Double(characterIndex*5+column+row)/Double(max(1, columns+6))
						let visible=reduceMotion || reveal>=sequence
						let x=CGFloat(characterIndex*6+column)*cell+(cell-dot)/2
						let y=CGFloat(row)*cell+(cell-dot)/2
						let rect=CGRect(x:x, y:y, width:dot, height:dot)
						let color=on && visible
							? activeColor.opacity(0.82+Double((characterIndex+row+column)%3)*0.08)
							: Color.primary.opacity(0.055)
						context.fill(Path(roundedRect: rect, cornerRadius: dot*0.16), with: .color(color))
					}
				}
			}
		}
		.aspectRatio(CGFloat(columns)/7, contentMode: .fit)
		.frame(maxHeight:64)
		.accessibilityElement(children:.ignore)
		.accessibilityLabel(Text(text))
		.onAppear{
			if reduceMotion{
				reveal=1
			}else{
				withAnimation(.linear(duration:0.55)){reveal=1}
			}
		}
		.onChange(of:text){_ in
			reveal=reduceMotion ? 1 : 0
			withAnimation(.linear(duration:0.55)){reveal=1}
		}
	}
}
