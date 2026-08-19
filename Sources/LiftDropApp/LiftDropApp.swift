import SwiftUI

@main
struct LiftDropApp:App{
	@StateObject private var model=LiftDropModel()
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
			case .background:
				model.resignActive()
			case .inactive:
				// iOS deactivates the scene while the Local Network permission
				// alert is on screen. Tearing the browser down here cancels the
				// request that alert is asking about, so the answer never sticks.
				break
			@unknown default:
				break
			}
		}
	}
}
