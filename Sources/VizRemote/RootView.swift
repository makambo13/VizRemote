import SwiftUI

struct RootView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Group {
            switch appModel.screen {
            case .searching:
                SearchingView(appModel: appModel)
            case .discovered:
                DiscoveryView(appModel: appModel)
            case .pairing:
                PairingView(appModel: appModel)
            case .remote:
                if let monitor = appModel.reachability {
                    RemoteScreen(appModel: appModel, monitor: monitor)
                } else {
                    SearchingView(appModel: appModel)
                }
            case .settings:
                SettingsView(appModel: appModel)
            }
        }
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch appModel.appearance {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}
