import SwiftUI
import Firebase

@main
struct FitSpoApp: App {
    // wire up your AppDelegate so Firebase.config gets called
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appStateManager = AppStateManager()

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app content
                ContentView()
                    .accentColor(.black)
                
                // Launch screen overlay
                if appStateManager.isLaunchScreenActive {
                    LaunchScreenView(isLaunchScreenActive: $appStateManager.isLaunchScreenActive)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: appStateManager.isLaunchScreenActive)
        }
    }
}
