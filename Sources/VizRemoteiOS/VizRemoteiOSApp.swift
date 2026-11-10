import SwiftUI

@main
struct VizRemoteiOSApp: App {
    @StateObject private var appModel = AppModel()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashView { showSplash = false }
            } else {
                PhoneRootView(appModel: appModel)
            }
        }
    }
}
