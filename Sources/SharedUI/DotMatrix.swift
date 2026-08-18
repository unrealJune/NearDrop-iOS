import SwiftUI

/// A fixed grid of dots, the smallest unit the flip-dot board knows how to draw.
struct DotGrid:Equatable{
	let rows:Int
	let columns:Int
	private let cells:[Bool]

	private init(rows:Int, columns:Int, cells:[Bool]){
		self.rows=max(0, rows)
		self.columns=max(0, columns)
		self.cells=cells
	}

	func isOn(row:Int, column:Int)->Bool{
		guard row>=0, row<rows, column>=0, column<columns else {return false}
		let index=row*columns+column
		return index<cells.count && cells[index]
	}

	static func blank(rows:Int, columns:Int)->DotGrid{
		DotGrid(rows:rows, columns:columns, cells:Array(repeating:false, count:max(0, rows*columns)))
	}

	/// Renders one or more lines of 5x7 glyphs. Lines are centred inside `width`
	/// characters so the board keeps a stable size while its message changes.
	static func lines(_ lines:[String], width:Int?=nil)->DotGrid{
		let rendered=lines.map{Array($0.uppercased())}
		let characterWidth=max(1, width ?? rendered.map(\.count).max() ?? 1)
		let columns=characterWidth*6-1
		let rows=max(1, rendered.count)*8-1
		var cells=Array(repeating:false, count:rows*columns)
		for (lineIndex, characters) in rendered.enumerated(){
			let visible=Array(characters.prefix(characterWidth))
			let leading=(characterWidth-visible.count)/2
			for (characterIndex, character) in visible.enumerated(){
				let bitmap=font[character] ?? font[" "]!
				for row in 0..<7{
					for column in 0..<5 where (bitmap[row] & UInt8(1 << (4-column))) != 0{
						let x=(leading+characterIndex)*6+column
						let y=lineIndex*8+row
						cells[y*columns+x]=true
					}
				}
			}
		}
		return DotGrid(rows:rows, columns:columns, cells:cells)
	}

	static func text(_ text:String, width:Int?=nil)->DotGrid{
		lines([text], width:width)
	}

	static let check=art([
		".......",
		"......#",
		".....##",
		"##..##.",
		".####..",
		"..##...",
		"......."
	])

	static let cross=art([
		"##...##",
		"###.###",
		".#####.",
		"..###..",
		".#####.",
		"###.###",
		"##...##"
	])

	private static func art(_ rows:[String])->DotGrid{
		let columns=rows.map(\.count).max() ?? 0
		var cells=Array(repeating:false, count:rows.count*columns)
		for (row, line) in rows.enumerated(){
			for (column, character) in line.enumerated() where character=="#"{
				cells[row*columns+column]=true
			}
		}
		return DotGrid(rows:rows.count, columns:columns, cells:cells)
	}

	private static let font:[Character:[UInt8]]=[
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
}

/// Draws a `DotGrid` as an electromechanical flip-dot board. Dots whose state
/// changes physically flip: they squash to an edge, swap colour halfway, then
/// open back up. The flip sweeps left to right so the board reads like a sign.
struct DotMatrixDisplay:View{
	let grid:DotGrid
	var palette=DotPalette.shoreline
	/// Overrides the palette ramp with one flat colour, for semantic controls.
	var solidColor:Color?=nil

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.colorScheme) private var colorScheme
	@State private var displayed=DotGrid.blank(rows:0, columns:0)
	@State private var previous=DotGrid.blank(rows:0, columns:0)
	@State private var flipStart:Date?
	@State private var flipID=0

	private let flipDuration=0.22
	private let sweepDuration=0.34
	private let rowDelay=0.07
	private let dotFill=0.82

	/// Ordered 4x4 Bayer thresholds, normalised to 0-1.
	private static let bayer:[[Double]]=[
		[0, 8, 2, 10],
		[12, 4, 14, 6],
		[3, 11, 1, 9],
		[15, 7, 13, 5]
	].map{$0.map{(Double($0)+0.5)/16}}

	var body:some View{
		TimelineView(.animation(minimumInterval:1/60, paused:flipStart==nil)){ timeline in
			Canvas{ context, size in
				draw(&context, size:size, now:timeline.date)
			}
		}
		.aspectRatio(aspectRatio, contentMode:.fit)
		.onAppear{
			displayed=grid
			previous=DotGrid.blank(rows:grid.rows, columns:grid.columns)
			beginFlip()
		}
		.onChange(of:grid){ newGrid in
			previous=displayed
			displayed=newGrid
			beginFlip()
		}
		.task(id:flipID){
			guard flipStart != nil else {return}
			let settled=sweepDuration+rowDelay+flipDuration+0.05
			try? await Task.sleep(nanoseconds:UInt64(settled*1_000_000_000))
			guard !Task.isCancelled else {return}
			flipStart=nil
		}
	}

	private var aspectRatio:CGFloat{
		let rows=max(1, grid.rows)
		return CGFloat(max(1, grid.columns))/CGFloat(rows)
	}

	private func draw(_ context:inout GraphicsContext, size:CGSize, now:Date){
		let target=displayed
		guard target.rows>0, target.columns>0 else {return}
		let ramp=solidColor.map{[$0]} ?? palette.ramp(for:colorScheme)
		let unlit=palette.unlit(for:colorScheme)
		let cell=min(size.width/CGFloat(target.columns), size.height/CGFloat(target.rows))
		let dot=max(1.5, cell*dotFill)
		let originX=(size.width-cell*CGFloat(target.columns))/2
		let originY=(size.height-cell*CGFloat(target.rows))/2
		let elapsed=flipStart.map{now.timeIntervalSince($0)}
		for row in 0..<target.rows{
			for column in 0..<target.columns{
				let targetOn=target.isOn(row:row, column:column)
				let previousOn=previous.isOn(row:row, column:column)
				var lit=targetOn
				var openness=1.0
				if let elapsed, previousOn != targetOn{
					let columnDelay=sweepDuration*Double(column)/Double(target.columns)
					let rowOffset=rowDelay*Double(row)/Double(target.rows)
					let progress=min(1, max(0, (elapsed-columnDelay-rowOffset)/flipDuration))
					lit = progress<0.5 ? previousOn : targetOn
					openness = progress<=0 || progress>=1 ? 1 : abs(cos(.pi*progress))
				}
				let height=max(cell*0.1, dot*openness)
				let rect=CGRect(
					x:originX+CGFloat(column)*cell+(cell-dot)/2,
					y:originY+CGFloat(row)*cell+(cell-height)/2,
					width:dot,
					height:height
				)
				let color=lit ? ditheredColor(ramp:ramp, row:row, column:column, in:target) : unlit
				context.fill(Path(roundedRect:rect, cornerRadius:min(dot, height)*0.28), with:.color(color))
			}
		}
	}

	/// Ordered dithering across the ramp, so the gradient bands into the dots
	/// instead of smoothly interpolating.
	private func ditheredColor(ramp:[Color], row:Int, column:Int, in grid:DotGrid)->Color{
		guard ramp.count>1 else {return ramp.first ?? .primary}
		let across=Double(column)/Double(max(1, grid.columns-1))
		let down=Double(row)/Double(max(1, grid.rows-1))
		let gradient=min(1, max(0, across*0.78+(1-down)*0.22))
		let threshold=Self.bayer[row%4][column%4]
		let level=Int((gradient*Double(ramp.count-1)+threshold-0.5).rounded(.down))
		return ramp[min(ramp.count-1, max(0, level))]
	}

	private func beginFlip(){
		guard !reduceMotion else{
			flipStart=nil
			return
		}
		flipStart=Date()
		flipID+=1
	}
}

/// A single line of flip-dot text.
struct DotMatrixText:View{
	let text:String
	var palette=DotPalette.shoreline
	var width:Int?=nil

	var body:some View{
		DotMatrixDisplay(grid:.text(text, width:width), palette:palette)
			.frame(maxHeight:76)
			.accessibilityElement(children:.ignore)
			.accessibilityLabel(Text(text))
	}
}

/// A stack of independent flip-dot rows, the way a transit departure board
/// splits its lines.
struct DotMatrixBoard:View{
	let lines:[String]
	var width:Int?=nil
	var palette=DotPalette.shoreline
	var rowHeight:CGFloat=88

	var body:some View{
		VStack(spacing:12){
			ForEach(Array(lines.enumerated()), id:\.offset){ _, line in
				DotMatrixDisplay(grid:.text(line, width:width), palette:palette)
					.frame(maxHeight:rowHeight)
			}
		}
		.accessibilityElement(children:.ignore)
		.accessibilityLabel(lines.filter{!$0.isEmpty}.joined(separator:", "))
	}
}
