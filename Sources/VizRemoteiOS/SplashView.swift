import SwiftUI

/// Matches SplashDark.dc.html / SplashLight.dc.html: the mark at 120pt, wordmark 22pt
/// below in SF Pro Semibold 26, fade in ~0.3s, then hand off. The static launch screen
/// (Info.plist UILaunchScreen) shows LaunchMark alone first — this view is what's on
/// screen for the brief moment after that, before real content is ready.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opacity: Double = 0
    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image("LaunchMark")
                .resizable()
                .frame(width: 120, height: 120)
            Text("VizRemote")
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(Theme.textPrimary)
        }
        .opacity(opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .onAppear {
            if reduceMotion {
                opacity = 1
            } else {
                withAnimation(.easeOut(duration: 0.3)) { opacity = 1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                onFinished()
            }
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
