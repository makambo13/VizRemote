import SwiftUI
import UIKit

struct PhoneFoundView: View {
    @ObservedObject var appModel: AppModel
    @State private var manualHost = ""
    @State private var manualOpen = true

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                Image("LaunchMark").resizable().frame(width: 28, height: 28)
                Text("VizRemote").font(.system(size: 15, weight: .semibold))
                Spacer()
                HStack(spacing: 7) {
                    Circle().fill(Theme.accent).frame(width: 8, height: 8)
                    Text("Still looking").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(height: 44)

            VStack(alignment: .leading, spacing: 6) {
                Text("Found \(appModel.discoveredTVs.count) \(appModel.discoveredTVs.count == 1 ? "TV" : "TVs")")
                    .font(.system(size: 30, weight: .semibold))
                Text("Pick the one you want to control.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }

            if appModel.discoveredTVs.isEmpty {
                permissionHint
            }

            VStack(spacing: 12) {
                ForEach(appModel.discoveredTVs) { tv in
                    HStack(spacing: 14) {
                        Theme.icon(.tv)
                            .resizable()
                            .frame(width: 26, height: 26)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 54, height: 54)
                            .background(Theme.keyFace)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Theme.keyBorder, lineWidth: 1))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(tv.name).font(.system(size: 17, weight: .semibold))
                            Text(tv.model).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                            Text(tv.host).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.sectionLabel)
                        }
                        Spacer()
                        Button { appModel.connect(to: tv) } label: {
                            Text("Connect")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.background)
                                .padding(.horizontal, 18)
                                .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                        .background(Theme.textPrimary)
                        .clipShape(Capsule())
                    }
                    .padding(16)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.divider, lineWidth: 1))
                }
            }

            Spacer()

            if manualOpen {
                VStack(alignment: .leading, spacing: 10) {
                    Text("TV's IP address").font(.system(size: 15, weight: .medium))
                    HStack(spacing: 8) {
                        TextField("xxx.xxx.xxx.xxx", text: $manualHost)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 16, design: .monospaced))
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(Theme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.fieldBorder, lineWidth: 1))

                        Button { appModel.connectManual(host: manualHost) } label: {
                            Text("Connect")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.background)
                                .padding(.horizontal, 18)
                                .frame(height: 48)
                        }
                        .buttonStyle(.plain)
                        .background(Theme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    Text("On the TV: Menu › Network › Connection Test shows its IP.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.sectionLabel)
                }
                .padding(16)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.divider, lineWidth: 1))
            } else {
                Button { manualOpen = true } label: {
                    Text("Can't find your TV? Enter IP manually")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.accentText)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 14)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    /// There's no documented API to detect "Local Network permission denied" versus
    /// "no TV happens to be on right now" — this is a heuristic, not a real permission
    /// check, offered only because a scan that finds nothing is the one symptom a denied
    /// prompt actually produces (our scan always finishes in a few seconds either way).
    private var permissionHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Didn't find anything?")
                .font(.system(size: 15, weight: .semibold))
            Text("If you tapped \"Don't Allow\" on the Local Network prompt, VizRemote can't scan your Wi-Fi. Turn it back on in Settings.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Theme.insetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.divider, lineWidth: 1))
    }
}

#Preview {
    PhoneFoundView(appModel: .previewDiscovered())
}

#Preview("Empty") {
    let model = AppModel.previewDiscovered()
    model.discoveredTVs = []
    return PhoneFoundView(appModel: model)
}
