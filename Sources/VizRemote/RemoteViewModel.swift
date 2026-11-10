import SwiftUI

@MainActor
final class RemoteViewModel: ObservableObject {
    @Published var volume: Int = 0
    @Published var muted: Bool = false
    @Published var inputs: [InputSource] = []
    @Published var activeInputID: String?
    @Published var appsOpen = true
    @Published var errorMessage: String?

    let apps: [AppShortcut] = [
        AppShortcut(id: "netflix", name: "Netflix", initial: "N", appID: "1", nameSpace: 3),
        AppShortcut(id: "youtube", name: "YouTube", initial: "Y", appID: "1", nameSpace: 5),
        AppShortcut(id: "prime", name: "Prime Video", initial: "P", appID: "4", nameSpace: 2),
        AppShortcut(id: "disney", name: "Disney+", initial: "D", appID: "75", nameSpace: 2),
    ]
    @Published var launchingAppID: String?

    private let client: SmartCastClient

    init(client: SmartCastClient) {
        self.client = client
        Task { await refresh() }
    }

    func refresh() async {
        do {
            volume = try await client.volume()
            inputs = try await client.inputs()
            activeInputID = try await client.currentInput().id
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
        }
    }

    var activeInputLabel: String {
        inputs.first(where: { $0.id == activeInputID })?.label ?? "—"
    }

    func send(_ key: RemoteKey) {
        Task {
            do { try await client.send(key) } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
            }
        }
    }

    func toggleMute() {
        muted.toggle()
        Task { try? await client.setMuted(muted) }
    }

    func changeVolume(by delta: Int) {
        volume = min(100, max(0, volume + delta))
        Task { try? await client.setVolume(volume) }
    }

    func selectInput(_ input: InputSource) {
        activeInputID = input.id
        Task { try? await client.selectInput(input) }
    }

    func toggleApps() { appsOpen.toggle() }

    func launch(_ app: AppShortcut) {
        guard launchingAppID == nil else { return }
        launchingAppID = app.id
        Task {
            defer { launchingAppID = nil }
            do {
                try await client.launchApp(appID: app.appID, nameSpace: app.nameSpace)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
            }
        }
    }
}
