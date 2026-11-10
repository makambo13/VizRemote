import SwiftUI

struct PairingView: View {
    @ObservedObject var appModel: AppModel
    @FocusState private var focusedIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Theme.icon(.tv).resizable().frame(width: 16, height: 16)
                Text("Pairing with \(appModel.selectedTV?.name ?? "your TV")")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Theme.textSecondary)
            .frame(height: 32, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            VStack(spacing: 30) {
                tvGlyph

                VStack(spacing: 8) {
                    Text("Check your TV screen")
                        .font(.system(size: 21, weight: .semibold))
                    if appModel.isFetchingChallenge {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Asking \(appModel.selectedTV?.name ?? "the TV") for a code…")
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("Type the 4-digit code shown on \(appModel.selectedTV?.name ?? "your TV").")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { index in
                        digitField(index)
                    }
                }
                .disabled(appModel.isSubmittingPin)
                .opacity(appModel.isSubmittingPin ? 0.5 : 1)

                if let error = appModel.pairingError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.powerGlyph)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            VStack(spacing: 6) {
                Button { appModel.submitPairing() } label: {
                    Group {
                        if appModel.isSubmittingPin {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Theme.background)
                        } else {
                            Text("Pair")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundStyle(appModel.pairingComplete ? Theme.background : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                .background(appModel.pairingComplete ? Theme.textPrimary : Theme.insetSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(!appModel.pairingComplete || appModel.isSubmittingPin)

                Button { appModel.cancelPairing() } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .disabled(appModel.isSubmittingPin)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(width: 380, height: 600)
        .background(Theme.background)
        .onAppear { focusedIndex = 0 }
    }

    private func digitField(_ index: Int) -> some View {
        TextField("–", text: Binding(
            get: { appModel.pairingDigits[index] },
            set: { newValue in
                appModel.setPairingDigit(index, rawValue: newValue)
                if appModel.pairingDigits[index].count == 1, index < 3 {
                    focusedIndex = index + 1
                }
                if appModel.pairingComplete { focusedIndex = nil }
            }
        ))
        .textFieldStyle(.plain)
        .multilineTextAlignment(.center)
        .font(.system(size: 32, weight: .semibold, design: .monospaced))
        .foregroundStyle(Theme.textPrimary)
        .frame(width: 62, height: 76)
        .background(Theme.insetSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(focusedIndex == index ? Theme.accent : Theme.divider, lineWidth: focusedIndex == index ? 2 : 1)
        )
        .focused($focusedIndex, equals: index)
        .onKeyPress(.delete) {
            if appModel.pairingDigits[index].isEmpty, index > 0 {
                focusedIndex = index - 1
                return .handled
            }
            return .ignored
        }
    }

    private var tvGlyph: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.divider, lineWidth: 2)
                .frame(width: 176, height: 100)
            Rectangle().fill(Theme.divider).frame(width: 2, height: 12)
            RoundedRectangle(cornerRadius: 1).fill(Theme.divider).frame(width: 56, height: 2)
        }
    }
}

#Preview {
    PairingView(appModel: .previewPairing())
}
