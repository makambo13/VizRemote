import SwiftUI

struct PhoneSearchingView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image("LaunchMark").resizable().frame(width: 28, height: 28)
                Text("VizRemote").font(.system(size: 15, weight: .semibold))
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            VStack(spacing: 40) {
                ZStack {
                    if reduceMotion {
                        Circle()
                            .stroke(Theme.searchRing, lineWidth: 1.5)
                            .frame(width: 200, height: 200)
                            .opacity(0.5)
                    } else {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(Theme.searchRing, lineWidth: 1.5)
                                .frame(width: 80, height: 80)
                                .scaleEffect(pulse ? 2.95 : 1)
                                .opacity(pulse ? 0 : 0.9)
                                .animation(
                                    .easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 0.8),
                                    value: pulse
                                )
                        }
                    }
                    Circle()
                        .fill(Theme.keyFace)
                        .frame(width: 88, height: 88)
                        .overlay(Circle().stroke(Theme.keyBorder, lineWidth: 1))
                        .overlay(
                            Theme.icon(.tv).resizable().frame(width: 34, height: 34).foregroundStyle(Theme.textPrimary)
                        )
                }
                VStack(spacing: 12) {
                    Text("Searching for VIZIO TVs on your network…")
                        .font(.system(size: 26, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text("Make sure the TV is on and on the same Wi-Fi as this iPhone.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
            }

            Spacer()

            Button { appModel.showDiscoveryResults() } label: {
                Text("Can't find your TV? Enter IP manually")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.accentText)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 14)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .onAppear { pulse = true }
    }
}

#Preview {
    PhoneSearchingView(appModel: .previewSearching())
}
