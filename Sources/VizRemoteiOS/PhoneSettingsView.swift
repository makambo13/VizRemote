import SwiftUI

struct PhoneSettingsView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    private var details: [TVDetail] {
        [
            TVDetail(label: "Model", value: appModel.selectedTV?.model ?? "—"),
            TVDetail(label: "IP address", value: appModel.selectedTV?.host ?? "—"),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                aboutSection
                appearanceSection
                pairingSection
                Text("VizRemote talks only to your TV, on this network.\nNo account. No cloud.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sectionLabel)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Text("Remote")
                    }
                    .foregroundStyle(Theme.accentText)
                }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("This TV")
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Theme.icon(.tv)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Theme.keyGlyph)
                        .frame(width: 50, height: 50)
                        .background(Theme.keyFace)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.keyBorder, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(appModel.selectedTV?.name ?? "Living Room").font(.system(size: 17, weight: .semibold))
                        HStack(spacing: 6) {
                            Circle().fill(Theme.statusConnected).frame(width: 7, height: 7)
                            Text("Paired · connected").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    Spacer()
                }
                .padding(16)

                Rectangle().fill(Theme.divider).frame(height: 1)

                VStack(spacing: 0) {
                    ForEach(details) { detail in
                        HStack {
                            Text(detail.label).font(.system(size: 15)).foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text(detail.value).font(.system(size: 13, design: .monospaced)).foregroundStyle(Theme.textPrimary)
                        }
                        .frame(height: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.divider, lineWidth: 1))
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Appearance")
            HStack(spacing: 4) {
                ForEach(AppearanceMode.allCases) { mode in
                    let active = mode == appModel.appearance
                    Button { appModel.appearance = mode } label: {
                        Text(mode.label)
                            .font(.system(size: 15, weight: active ? .semibold : .medium))
                            .foregroundStyle(active ? Theme.textPrimary : Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .background(active ? AnyShapeStyle(Theme.card) : AnyShapeStyle(Color.clear))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? AnyShapeStyle(Theme.keyBorder) : AnyShapeStyle(Color.clear), lineWidth: 1))
                }
            }
            .padding(4)
            .background(Theme.insetSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.divider, lineWidth: 1))
        }
    }

    private var pairingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Pairing")
            VStack(spacing: 0) {
                Button { appModel.selectedTV.map { appModel.connect(to: $0) } } label: {
                    HStack {
                        Text("Re-pair this TV").font(.system(size: 17)).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Theme.icon(.chevronRight).resizable().frame(width: 16, height: 16).foregroundStyle(Theme.sectionLabel)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                }
                .buttonStyle(.plain)

                Rectangle().fill(Theme.divider).frame(height: 1)

                Button { appModel.forgetTV() } label: {
                    HStack {
                        Text("Forget \(appModel.selectedTV?.name ?? "this TV")")
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.destructive)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                }
                .buttonStyle(.plain)
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.divider, lineWidth: 1))
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(Theme.sectionLabel)
            .padding(.horizontal, 4)
    }
}

#Preview {
    NavigationStack { PhoneSettingsView(appModel: .previewSettings()) }
}
