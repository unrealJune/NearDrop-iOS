import SwiftUI

/// A colour ramp for the flip-dot board, ordered dark to bright. Lit dots are
/// dithered across the ramp, so the board bands like a printed halftone rather
/// than showing one flat colour.
struct DotPalette:Identifiable, Hashable{
	let id:String
	let name:String
	private let lightRamp:[String]
	private let darkRamp:[String]
	private let lightAccent:String
	private let darkAccent:String

	func ramp(for scheme:ColorScheme)->[Color]{
		(scheme == .dark ? darkRamp : lightRamp).map(Color.init(hex:))
	}

	func accent(for scheme:ColorScheme)->Color{
		Color(hex:scheme == .dark ? darkAccent : lightAccent)
	}

	func unlit(for scheme:ColorScheme)->Color{
		scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
	}

	/// Ocean ramp borrowed from junephilip.com, abyss through foam.
	static let shoreline=DotPalette(
		id:"shoreline",
		name:"Shoreline",
		lightRamp:["112E3F","28586A","468287","80B8AE"],
		darkRamp:["28586A","468287","80B8AE","A8DDD2","CFD9CA"],
		lightAccent:"28586A",
		darkAccent:"80B8AE"
	)

	static let amber=DotPalette(
		id:"amber",
		name:"Amber",
		lightRamp:["5C3505","A6640F","D98F1A"],
		darkRamp:["734711","B06F16","EBA621","F5C95E"],
		lightAccent:"A6640F",
		darkAccent:"EBA621"
	)

	static let cyan=DotPalette(
		id:"cyan",
		name:"Cyan",
		lightRamp:["075985","0891B2","06B6D4"],
		darkRamp:["0E7490","06B6D4","22D3EE","67E8F9"],
		lightAccent:"0891B2",
		darkAccent:"22D3EE"
	)

	static let mono=DotPalette(
		id:"mono",
		name:"Mono",
		lightRamp:["111827","374151","6B7280"],
		darkRamp:["6B7280","9CA3AF","D1D5DB","F3F4F6"],
		lightAccent:"374151",
		darkAccent:"D1D5DB"
	)

	static let all=[shoreline, amber, cyan, mono]

	static func named(_ id:String)->DotPalette{
		all.first{$0.id==id} ?? shoreline
	}
}

enum AppearanceOption:String, CaseIterable, Identifiable{
	case system, light, dark

	var id:String{rawValue}

	var name:String{
		switch self{
		case .system:return "System"
		case .light:return "Light"
		case .dark:return "Dark"
		}
	}

	var colorScheme:ColorScheme?{
		switch self{
		case .system:return nil
		case .light:return .light
		case .dark:return .dark
		}
	}
}

extension Color{
	init(hex:String){
		var value:UInt64=0
		Scanner(string:hex).scanHexInt64(&value)
		self.init(
			.sRGB,
			red:Double((value>>16) & 0xFF)/255,
			green:Double((value>>8) & 0xFF)/255,
			blue:Double(value & 0xFF)/255
		)
	}
}
