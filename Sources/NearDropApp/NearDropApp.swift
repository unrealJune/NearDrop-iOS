import SwiftUI

@main
struct NearDropApp:App{
	@StateObject private var model=NearDropModel()
	@Environment(\.scenePhase) private var scenePhase

	var body:some Scene{
		WindowGroup{
			ContentView()
				.environmentObject(model)
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
