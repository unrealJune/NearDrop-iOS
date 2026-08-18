import SwiftUI

@main
struct TakeoffApp:App{
	@StateObject private var model=TakeoffModel()
	@Environment(\.scenePhase) private var scenePhase
	@AppStorage("appearance") private var appearance=AppearanceOption.system

	var body:some Scene{
		WindowGroup{
			ContentView()
				.environmentObject(model)
				.preferredColorScheme(appearance.colorScheme)
		}
		.onChange(of: scenePhase){ phase in
			switch phase{
			case .active:
				model.becomeActive()
			case .inactive, .background:
				model.resignActive()
			@unknown default:
				break
			}
		}
	}
}
