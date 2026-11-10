import SwiftUI

@main
struct VizRemoteApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            RootView(appModel: appModel)
        } label: {
            Theme.icon(.menubarRemote).renderingMode(.template)
        }
        .menuBarExtraStyle(.window)
    }
}
