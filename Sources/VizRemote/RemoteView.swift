import SwiftUI

struct RemoteScreen: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject var monitor: ReachabilityMonitor

    var body: some View {
        Group {
            if monitor.state == .connected {
                ConnectedRemoteView(appModel: appModel)
            } else {
                TVOffView(appModel: appModel)
            }
        }
    }
}

private struct ConnectedRemoteView: View {
    @ObservedObject var appModel: AppModel
    @StateObject private var vm: RemoteViewModel

    init(appModel: AppModel) {
        self.appModel = appModel
        _vm = StateObject(wrappedValue: RemoteViewModel(client: appModel.client!))
    }

    var body: some View {
        VStack(spacing: 22) {
            header
            volumeSection
            dpadSection
            transportSection
            inputSection
            appsSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(width: 380)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 9) {
                    Circle()
                        .fill(Theme.statusConnected)
                        .frame(width: 9, height: 9)
                    Text(appModel.selectedTV?.name ?? "Living Room")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text("Connected · \(vm.activeInputLabel)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 18)
            }
            Spacer()

            Button { appModel.openSettings() } label: {
                Theme.icon(.settings)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Theme.divider)
                .frame(width: 1, height: 28)
                .padding(.horizontal, 6)

            Button { vm.send(.powerToggle) } label: {
                Theme.icon(.power)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Theme.powerGlyph)
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(.plain)
            .background(Theme.powerFace)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(Theme.powerBorder, lineWidth: 1))
        }
        .frame(height: 56)
    }

    private var volumeSection: some View {
        HStack(spacing: 10) {
            Button { vm.toggleMute() } label: {
                Theme.icon(vm.muted ? .speakerMuted : .speaker)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundStyle(vm.muted ? Theme.background : Theme.textPrimary)
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.plain)
            .background(vm.muted ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.keyFace))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(vm.muted ? AnyShapeStyle(Theme.accent.opacity(0.4)) : AnyShapeStyle(Theme.keyBorder), lineWidth: 1))

            HStack(spacing: 0) {
                Button { vm.changeVolume(by: -1) } label: {
                    Theme.icon(.minus).resizable().frame(width: 20, height: 20)
                        .frame(width: 56, height: 58)
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

                Button { vm.changeVolume(by: 1) } label: {
                    Theme.icon(.plus).resizable().frame(width: 20, height: 20)
                        .frame(width: 56, height: 58)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(Theme.insetSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.divider, lineWidth: 1))
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
                .fill(RadialGradient(colors: [Theme.keyFaceTop, Theme.insetSurface], center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: 130))
                .overlay(Circle().stroke(Theme.divider, lineWidth: 1))
                .frame(width: 236, height: 236)

            dpadArrow(.up, icon: .chevronUp).offset(y: -80)
            dpadArrow(.down, icon: .chevronDown).offset(y: 80)
            dpadArrow(.left, icon: .chevronLeft).offset(x: -80)
            dpadArrow(.right, icon: .chevronRight).offset(x: 80)

            Button { vm.send(.ok) } label: {
                Text("OK")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 100, height: 100)
            }
            .buttonStyle(.plain)
            .background(Theme.okFace)
            .clipShape(Circle())
            .overlay(Circle().stroke(Theme.keyBorder, lineWidth: 1))
        }
        .padding(.top, 4)
    }

    private func dpadArrow(_ key: RemoteKey, icon: Theme.Icon) -> some View {
        Button { vm.send(key) } label: {
            Theme.icon(icon)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(Theme.textPrimary.opacity(0.85))
                .frame(width: 72, height: 64)
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
        Button { vm.send(key) } label: {
            Theme.icon(icon)
                .resizable()
                .frame(width: 22, height: 22)
                .foregroundStyle(Theme.textPrimary.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
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
                        Button { vm.selectInput(input) } label: {
                            Text(input.label)
                                .font(.system(size: 14, weight: active ? .semibold : .medium))
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(vm.apps) { app in
                        Button { vm.launch(app) } label: {
                            VStack(spacing: 7) {
                                Group {
                                    if vm.launchingAppID == app.id {
                                        ProgressView().controlSize(.small).tint(.white)
                                    } else {
                                        Text(app.initial)
                                            .font(.system(size: 20, weight: .bold))
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(Self.appTint(app.id))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.keyBorder, lineWidth: 1))
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

    /// Own solid accent colors, not trademarked artwork — App Store review flags
    /// unlicensed use of third-party logos, so tiles stay letter + color only.
    private static func appTint(_ id: String) -> Color {
        switch id {
        case "netflix": return Color(red: 0.83, green: 0.11, blue: 0.15)
        case "youtube": return Color(red: 0.95, green: 0.22, blue: 0.20)
        case "prime": return Color(red: 0.11, green: 0.55, blue: 0.85)
        case "disney": return Color(red: 0.07, green: 0.24, blue: 0.56)
        default: return Theme.keyFaceTop
        }
    }
}

private struct TVOffView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(spacing: 22) {
            header
            Spacer()
            VStack(spacing: 30) {
                offGlyph
                VStack(spacing: 10) {
                    Text("\(appModel.selectedTV?.name ?? "Living Room") is probably off")
                        .font(.system(size: 22, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text("A powered‑off VIZIO stops answering on the network, so VizRemote can't wake it. Turn it on with its own remote or the button on the TV — we'll reconnect on our own.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 290)
                }
                HStack(spacing: 8) {
                    Circle().fill(Theme.textSecondary).frame(width: 7, height: 7)
                    Text("Checking again every few seconds")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(Theme.insetSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.divider, lineWidth: 1))
            }
            Spacer()
            VStack(spacing: 6) {
                Button {
                    Task { await appModel.reachability?.checkOnce() }
                } label: {
                    HStack(spacing: 8) {
                        Theme.icon(.refresh).resizable().frame(width: 18, height: 18)
                        Text("Try now").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                .background(Theme.keyFace)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.keyBorder, lineWidth: 1))

                Button { appModel.openSettings() } label: {
                    Text("Wrong TV or new IP address?")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .frame(height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(width: 380)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 9) {
                    Circle().fill(Theme.textSecondary).frame(width: 9, height: 9)
                    Text(appModel.selectedTV?.name ?? "Living Room")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text("Not responding")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 18)
            }
            Spacer()

            Button { appModel.openSettings() } label: {
                Theme.icon(.settings).resizable().frame(width: 20, height: 20)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Rectangle().fill(Theme.divider).frame(width: 1, height: 28).padding(.horizontal, 6)

            Theme.icon(.power)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 54, height: 54)
                .background(Theme.insetSurface)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(Theme.divider, lineWidth: 1))
        }
        .frame(height: 56)
    }

    private var offGlyph: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Theme.divider, lineWidth: 2)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.insetSurface))
            .frame(width: 200, height: 118)
    }
}

#Preview("Connected") {
    let appModel = AppModel.previewConnected()
    return RemoteScreen(appModel: appModel, monitor: appModel.reachability!)
}

#Preview("TV Off") {
    let appModel = AppModel.previewOff()
    return RemoteScreen(appModel: appModel, monitor: appModel.reachability!)
}
