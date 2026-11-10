import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: AppModel

    private var details: [TVDetail] {
        [
            TVDetail(label: "Model", value: appModel.selectedTV?.model ?? "—"),
            TVDetail(label: "IP address", value: appModel.selectedTV?.host ?? "—"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 4) {
                Button { appModel.closeSettings() } label: {
                    Theme.icon(.chevronLeft).resizable().frame(width: 22, height: 22)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                Text("Settings").font(.system(size: 18, weight: .semibold))
            }
            .padding(.leading, -10)
            .frame(height: 48)

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("This TV")
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        Theme.icon(.tv)
                            .resizable()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 48, height: 48)
                            .background(Theme.keyFace)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Theme.keyBorder, lineWidth: 1))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(appModel.selectedTV?.name ?? "Living Room").font(.system(size: 16, weight: .semibold))
                            HStack(spacing: 6) {
                                Circle().fill(Theme.statusConnected).frame(width: 7, height: 7)
                                Text("Paired · connected").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(14)

                    Rectangle().fill(Theme.divider).frame(height: 1)

                    VStack(spacing: 0) {
                        ForEach(details) { detail in
                            HStack {
                                Text(detail.label).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Text(detail.value).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.textPrimary)
                            }
                            .frame(height: 38)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .background(Theme.insetSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.divider, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Appearance")
                HStack(spacing: 4) {
                    ForEach(AppearanceMode.allCases) { mode in
                        let active = mode == appModel.appearance
                        Button { appModel.appearance = mode } label: {
                            Text(mode.label)
                                .font(.system(size: 13, weight: active ? .semibold : .medium))
                                .foregroundStyle(active ? Theme.textPrimary : Theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                        .buttonStyle(.plain)
                        .background(active ? AnyShapeStyle(Theme.keyFace) : AnyShapeStyle(Color.clear))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? AnyShapeStyle(Theme.keyBorder) : AnyShapeStyle(Color.clear), lineWidth: 1))
                    }
                }
                .padding(4)
                .background(Theme.insetSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.divider, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Pairing")
                VStack(spacing: 0) {
                    Button { appModel.selectedTV.map { appModel.connect(to: $0) } } label: {
                        HStack {
                            Text("Re-pair this TV").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Theme.icon(.chevronRight).resizable().frame(width: 16, height: 16).foregroundStyle(Theme.sectionLabel)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                    }
                    .buttonStyle(.plain)

                    Rectangle().fill(Theme.divider).frame(height: 1)

                    Button { appModel.forgetTV() } label: {
                        HStack {
                            Text("Forget \(appModel.selectedTV?.name ?? "this TV")")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.powerGlyph)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                    }
                    .buttonStyle(.plain)
                }
                .background(Theme.insetSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.divider, lineWidth: 1))
            }

            Spacer()

            Text("VizRemote talks only to your TV, on this network.\nNo account. No cloud.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.sectionLabel)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(width: 380, height: 720)
        .background(Theme.background)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(Theme.sectionLabel)
    }
}

#Preview {
    SettingsView(appModel: .previewSettings())
}
