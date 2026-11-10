import SwiftUI

struct SearchingView: View {
    @ObservedObject var appModel: AppModel
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Theme.icon(.tv).resizable().frame(width: 16, height: 16)
                Text("VizRemote").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.textSecondary)
            .frame(height: 32, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            VStack(spacing: 36) {
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Theme.accent.opacity(0.55), lineWidth: 1.5)
                            .frame(width: 200, height: 200)
                            .scaleEffect(pulse ? 1 : 0.35)
                            .opacity(pulse ? 0 : 0.7)
                            .animation(
                                .easeInOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 0.8),
                                value: pulse
                            )
                    }
                    Theme.icon(.tv)
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 76, height: 76)
                        .background(Theme.keyFace)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.keyBorder, lineWidth: 1))
                }
                VStack(spacing: 10) {
                    Text("Searching for VIZIO TVs on your network…")
                        .font(.system(size: 21, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text("Make sure the TV is on and on the same Wi‑Fi as this Mac.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
            }

            Spacer()

            Button { appModel.showDiscoveryResults() } label: {
                Text("Can't find your TV? Enter IP manually")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 28)
        .frame(width: 380, height: 560)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .onAppear { pulse = true }
    }
}

#Preview {
    SearchingView(appModel: .previewSearching())
}
