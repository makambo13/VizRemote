import SwiftUI

struct PhoneRootView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        NavigationStack {
            content
        }
        .preferredColorScheme(colorScheme)
    }

    @ViewBuilder
    private var content: some View {
        switch appModel.screen {
        case .searching:
            PhoneSearchingView(appModel: appModel)
        case .discovered:
            PhoneFoundView(appModel: appModel)
        case .pairing:
            PhonePairingView(appModel: appModel)
        case .remote, .settings:
            if let monitor = appModel.reachability {
                PhoneRemoteScreen(appModel: appModel, monitor: monitor)
            } else {
                PhoneSearchingView(appModel: appModel)
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appModel.appearance {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}
