import SwiftUI

struct DiscoveryView: View {
    @ObservedObject var appModel: AppModel
    @State private var manualHost = ""
    @State private var manualOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 8) {
                Theme.icon(.tv).resizable().frame(width: 16, height: 16)
                Text("VizRemote").font(.system(size: 13, weight: .semibold))
                Spacer()
                HStack(spacing: 7) {
                    Circle().fill(Theme.accent).frame(width: 7, height: 7)
                    Text("Still looking").font(.system(size: 12))
                }
            }
            .foregroundStyle(Theme.textSecondary)
            .frame(height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text("Found \(appModel.discoveredTVs.count) \(appModel.discoveredTVs.count == 1 ? "TV" : "TVs")")
                    .font(.system(size: 22, weight: .semibold))
                Text("Pick the one you want to control.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(spacing: 12) {
                ForEach(appModel.discoveredTVs) { tv in
                    HStack(spacing: 14) {
                        Theme.icon(.tv)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 52, height: 52)
                            .background(Theme.keyFace)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.keyBorder, lineWidth: 1))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(tv.name).font(.system(size: 16, weight: .semibold))
                            Text(tv.model).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                            Text(tv.host).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.sectionLabel)
                        }
                        Spacer()
                        Button { appModel.connect(to: tv) } label: {
                            Text("Connect")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.background)
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                        .background(Theme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(14)
                    .background(Theme.insetSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.divider, lineWidth: 1))
                }
            }

            Spacer()

            if manualOpen {
                VStack(alignment: .leading, spacing: 10) {
                    Text("TV's IP address").font(.system(size: 13, weight: .medium))
                    HStack(spacing: 8) {
                        TextField("xxx.xxx.xxx.xxx", text: $manualHost)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, design: .monospaced))
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(Theme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.divider, lineWidth: 1))

                        Button { appModel.connectManual(host: manualHost) } label: {
                            Text("Connect")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.background)
                                .padding(.horizontal, 16)
                                .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                        .background(Theme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    Text("On the TV: Menu › Network › Connection Test shows its IP.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sectionLabel)
                }
                .padding(16)
                .background(Theme.insetSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.divider, lineWidth: 1))
            } else {
                Button { manualOpen = true } label: {
                    Text("Can't find your TV? Enter IP manually")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(width: 380, height: 640)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }
}

#Preview {
    DiscoveryView(appModel: .previewDiscovered())
}
