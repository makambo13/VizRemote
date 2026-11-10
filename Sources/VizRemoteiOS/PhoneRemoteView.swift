import SwiftUI
import UIKit

struct PhoneRemoteScreen: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var monitor: ReachabilityMonitor
    @State private var showSettings = false

    var body: some View {
        Group {
            if monitor.state == .connected {
                PhoneConnectedRemoteView(appModel: appModel, showSettings: $showSettings)
            } else {
                PhoneOffView(appModel: appModel, showSettings: $showSettings)
            }
        }
        .navigationDestination(isPresented: $showSettings) {
            PhoneSettingsView(appModel: appModel)
        }
        .navigationBarBackButtonHidden(true)
    }
}

private struct PhoneConnectedRemoteView: View {
    @ObservedObject var appModel: AppModel
    @Binding var showSettings: Bool
    @StateObject private var vm: RemoteViewModel

    init(appModel: AppModel, showSettings: Binding<Bool>) {
        self.appModel = appModel
        self._showSettings = showSettings
        _vm = StateObject(wrappedValue: RemoteViewModel(client: appModel.client!))
    }

    var body: some View {
        VStack(spacing: 20) {
            header
            volumeSection
            dpadSection
            transportSection
            inputSection
            appsSection
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    private func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button { appModel.startSearch() } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 9) {
                        Circle()
                            .fill(Theme.statusConnected)
                            .frame(width: 9, height: 9)
                        Text(appModel.selectedTV?.name ?? "Living Room")
                            .font(.system(size: 20, weight: .semibold))
                        Theme.icon(.chevronDown).resizable().frame(width: 14, height: 14).foregroundStyle(Theme.sectionLabel)
                    }
                    Text("Connected · \(vm.activeInputLabel)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.leading, 18)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button { showSettings = true } label: {
                Theme.icon(.settings)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Rectangle().fill(Theme.divider).frame(width: 1, height: 28).padding(.horizontal, 6)

            Button {
                tap(.medium)
                vm.send(.powerToggle)
            } label: {
                Theme.icon(.power)
                    .resizable()
                    .frame(width: 25, height: 25)
                    .foregroundStyle(Theme.powerGlyph)
                    .frame(width: 58, height: 58)
            }
            .buttonStyle(.plain)
            .background(Theme.powerFace)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.powerBorder, lineWidth: 1))
        }
        .frame(height: 56)
    }

    private var volumeSection: some View {
        HStack(spacing: 10) {
            Button {
                tap(.light)
                vm.toggleMute()
            } label: {
                Theme.icon(vm.muted ? .speakerMuted : .speaker)
                    .resizable()
                    .frame(width: 23, height: 23)
                    .foregroundStyle(vm.muted ? Theme.background : Theme.textPrimary)
                    .frame(width: 64, height: 64)
            }
            .buttonStyle(.plain)
            .background(vm.muted ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.keyFace))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(vm.muted ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.keyBorder), lineWidth: 1))

            HStack(spacing: 0) {
                Button {
                    tap(.light)
                    vm.changeVolume(by: -1)
                } label: {
                    Theme.icon(.minus).resizable().frame(width: 21, height: 21)
                        .frame(width: 60, height: 62)
                }
                .buttonStyle(.plain)

                VStack(spacing: 7) {
                    HStack(spacing: 3) {
                        ForEach(0..<10, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(segmentLit(i) ? Theme.volumeSegmentLit : Theme.volumeSegmentDim)
                                .frame(width: 8, height: 14)
                        }
                    }
                    Text(vm.muted ? "MUTED" : "\(vm.volume)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Button {
                    tap(.light)
                    vm.changeVolume(by: 1)
                } label: {
                    Theme.icon(.plus).resizable().frame(width: 21, height: 21)
                        .frame(width: 60, height: 62)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 64)
            .frame(maxWidth: .infinity)
            .background(Theme.insetSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.divider, lineWidth: 1))
        }
    }

    private func segmentLit(_ index: Int) -> Bool {
        guard !vm.muted else { return false }
        let litCount = Int(ceil(Double(vm.volume) / 10.0))
        return index < litCount
    }

    private var dpadSection: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Theme.keyFaceTop, Theme.insetSurface], center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: 145))
                .overlay(Circle().stroke(Theme.divider, lineWidth: 1))
                .frame(width: 264, height: 264)

            dpadArrow(.up, icon: .chevronUp).offset(y: -92)
            dpadArrow(.down, icon: .chevronDown).offset(y: 92)
            dpadArrow(.left, icon: .chevronLeft).offset(x: -92)
            dpadArrow(.right, icon: .chevronRight).offset(x: 92)

            Button {
                tap(.light)
                vm.send(.ok)
            } label: {
                Text("OK")
                    .font(.system(size: 18, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 112, height: 112)
            }
            .buttonStyle(.plain)
            .background(Theme.okFace)
            .clipShape(Circle())
            .overlay(Circle().stroke(Theme.keyBorder, lineWidth: 1))
        }
    }

    private func dpadArrow(_ key: RemoteKey, icon: Theme.Icon) -> some View {
        Button {
            tap(.light)
            vm.send(key)
        } label: {
            Theme.icon(icon)
                .resizable()
                .frame(width: 26, height: 26)
                .foregroundStyle(Theme.keyGlyph)
                .frame(width: 80, height: 70)
        }
        .buttonStyle(.plain)
    }

    private var transportSection: some View {
        HStack(spacing: 8) {
            transportButton(.back, icon: .back)
            transportButton(.home, icon: .home)
            transportButton(.menu, icon: .menu)
        }
    }

    private func transportButton(_ key: RemoteKey, icon: Theme.Icon) -> some View {
        Button {
            tap(.light)
            vm.send(key)
        } label: {
            Theme.icon(icon)
                .resizable()
                .frame(width: 23, height: 23)
                .foregroundStyle(Theme.keyGlyph)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
        .buttonStyle(.plain)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INPUT")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(Theme.sectionLabel)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.inputs) { input in
                        let active = input.id == vm.activeInputID
                        Button {
                            tap(.light)
                            vm.selectInput(input)
                        } label: {
                            Text(input.label)
                                .font(.system(size: 15, weight: active ? .semibold : .medium))
                                .foregroundStyle(active ? Theme.chipActiveText : Theme.textPrimary)
                                .padding(.horizontal, 18)
                                .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                        .background(active ? AnyShapeStyle(Theme.chipActiveFill) : AnyShapeStyle(Theme.chipIdleFill))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(active ? AnyShapeStyle(Theme.chipActiveFill) : AnyShapeStyle(Theme.divider), lineWidth: 1))
                    }
                }
            }
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { vm.toggleApps() } label: {
                HStack {
                    Text("APPS")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.1)
                    Spacer()
                    Theme.icon(vm.appsOpen ? .chevronUp : .chevronDown)
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                .foregroundStyle(Theme.sectionLabel)
            }
            .buttonStyle(.plain)

            if vm.appsOpen {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    ForEach(vm.apps) { app in
                        Button { vm.launch(app) } label: {
                            VStack(spacing: 7) {
                                Group {
                                    if vm.launchingAppID == app.id {
                                        ProgressView().controlSize(.small).tint(.white)
                                    } else {
                                        Text(app.initial).font(.system(size: 20, weight: .bold))
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(appTint(app.id))
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Theme.keyBorder, lineWidth: 1))
                                Text(app.name)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.launchingAppID != nil)
                    }
                }
            }
        }
    }

    private func appTint(_ id: String) -> Color {
        switch id {
        case "netflix": return Color(red: 0.83, green: 0.11, blue: 0.15)
        case "youtube": return Color(red: 0.95, green: 0.22, blue: 0.20)
        case "prime": return Color(red: 0.11, green: 0.55, blue: 0.85)
        case "disney": return Color(red: 0.07, green: 0.24, blue: 0.56)
        default: return Theme.keyFaceTop
        }
    }
}

struct PhoneOffView: View {
    @ObservedObject var appModel: AppModel
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 20) {
            header
            Spacer()
            VStack(spacing: 30) {
                offGlyph
                VStack(spacing: 12) {
                    Text("\(appModel.selectedTV?.name ?? "Living Room") is probably off")
                        .font(.system(size: 26, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text("A powered‑off VIZIO stops answering on the network, so VizRemote can't wake it. Turn it on with its own remote or the button on the TV — we'll reconnect on our own.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 310)
                }
                HStack(spacing: 8) {
                    Circle().fill(Theme.sectionLabel).frame(width: 8, height: 8)
                    Text("Checking again every few seconds")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Theme.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.divider, lineWidth: 1))
            }
            Spacer()
            VStack(spacing: 4) {
                Button { Task { await appModel.reachability?.checkOnce() } } label: {
                    HStack(spacing: 8) {
                        Theme.icon(.refresh).resizable().frame(width: 19, height: 19)
                        Text("Try now").font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                }
                .buttonStyle(.plain)
                .background(Theme.keyFace)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.keyBorder, lineWidth: 1))

                Button { showSettings = true } label: {
                    Text("Wrong TV or new IP address?")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.accentText)
                }
                .buttonStyle(.plain)
                .frame(height: 48)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button { appModel.startSearch() } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 9) {
                        Circle().fill(Theme.statusUnreachable).frame(width: 9, height: 9)
                        Text(appModel.selectedTV?.name ?? "Living Room")
                            .font(.system(size: 20, weight: .semibold))
                        Theme.icon(.chevronDown).resizable().frame(width: 14, height: 14).foregroundStyle(Theme.sectionLabel)
                    }
                    Text("Not responding")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.leading, 18)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button { showSettings = true } label: {
                Theme.icon(.settings).resizable().frame(width: 22, height: 22)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Rectangle().fill(Theme.divider).frame(width: 1, height: 28).padding(.horizontal, 6)

            Theme.icon(.power)
                .resizable()
                .frame(width: 25, height: 25)
                .foregroundStyle(Theme.statusUnreachable)
                .frame(width: 58, height: 58)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.divider, lineWidth: 1))
        }
        .frame(height: 56)
    }

    private var offGlyph: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Theme.divider, lineWidth: 2)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card))
            .frame(width: 220, height: 128)
    }
}

#Preview("Connected") {
    let appModel = AppModel.previewConnected()
    return NavigationStack { PhoneRemoteScreen(appModel: appModel, monitor: appModel.reachability!) }
}

#Preview("Off") {
    let appModel = AppModel.previewOff()
    return NavigationStack { PhoneRemoteScreen(appModel: appModel, monitor: appModel.reachability!) }
}
