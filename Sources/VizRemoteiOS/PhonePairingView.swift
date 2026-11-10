import SwiftUI
import UIKit

/// Plain SwiftUI `TextField` never reports a delete on an already-empty field (there's
/// no character to remove, so no text-change event fires) — which is exactly the signal
/// needed to jump focus back a box on the on-screen number pad. Wrapping UITextField's
/// delegate is the standard workaround.
private struct BackspaceAwareField: UIViewRepresentable {
    @Binding var text: String
    var onBackspaceOnEmpty: () -> Void
    var font: UIFont

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.keyboardType = .numberPad
        field.textContentType = .oneTimeCode
        field.textAlignment = .center
        field.font = font
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let parent: BackspaceAwareField
        init(_ parent: BackspaceAwareField) { self.parent = parent }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let isBackspace = string.isEmpty && range.length > 0
            let isEmptyAlready = (textField.text ?? "").isEmpty
            if isBackspace, isEmptyAlready {
                parent.onBackspaceOnEmpty()
                return false
            }
            let digitsOnly = string.filter(\.isNumber)
            if digitsOnly.count > 1 {
                parent.text = digitsOnly
                textField.text = digitsOnly
                return false
            }
            let updated = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: digitsOnly)
            parent.text = String(updated.suffix(1))
            return false
        }
    }
}

struct PhonePairingView: View {
    @ObservedObject var appModel: AppModel
    @FocusState private var focusedIndex: Int?

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Button { appModel.cancelPairing() } label: {
                    Text("Cancel").font(.system(size: 17)).foregroundStyle(Theme.accentText)
                }
                .buttonStyle(.plain)
                .frame(width: 66, alignment: .leading)

                Spacer()
                Text(appModel.selectedTV?.name ?? "your TV").font(.system(size: 17, weight: .semibold))
                Spacer()

                Color.clear.frame(width: 66, height: 44)
            }
            .frame(height: 44)

            VStack(spacing: 26) {
                tvGlyph

                VStack(spacing: 8) {
                    Text("Check your TV screen")
                        .font(.system(size: 26, weight: .semibold))
                    if appModel.isFetchingChallenge {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Asking \(appModel.selectedTV?.name ?? "the TV") for a code…")
                        }
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("Type the 4-digit code shown on \(appModel.selectedTV?.name ?? "your TV").")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    if let error = appModel.pairingError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.destructive)
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
            }

            Spacer()

            VStack(spacing: 6) {
                Button { appModel.submitPairing() } label: {
                    Group {
                        if appModel.isSubmittingPin {
                            ProgressView().tint(Theme.background)
                        } else {
                            Text("Pair").font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundStyle(appModel.pairingComplete ? Theme.background : Theme.sectionLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                }
                .buttonStyle(.plain)
                .background(appModel.pairingComplete ? Theme.textPrimary : Theme.insetSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .disabled(!appModel.pairingComplete || appModel.isSubmittingPin)

                Text("The keyboard opens below with number keys.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sectionLabel)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .onAppear { focusedIndex = 0 }
    }

    private func digitField(_ index: Int) -> some View {
        let nextToFill = appModel.pairingDigits.firstIndex(of: "") == index
        let filled = !appModel.pairingDigits[index].isEmpty

        return BackspaceAwareField(
            text: Binding(
                get: { appModel.pairingDigits[index] },
                set: { newValue in
                    appModel.setPairingDigit(index, rawValue: newValue)
                    if appModel.pairingDigits[index].count == 1, index < 3 {
                        focusedIndex = index + 1
                    }
                    if appModel.pairingComplete { focusedIndex = nil }
                }
            ),
            onBackspaceOnEmpty: {
                if index > 0 { focusedIndex = index - 1 }
            },
            font: UIFont.monospacedSystemFont(ofSize: 34, weight: .semibold)
        )
        .focused($focusedIndex, equals: index)
        .frame(width: 68, height: 84)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(nextToFill ? Theme.accent : (filled ? Theme.fieldBorder : Theme.divider), lineWidth: nextToFill ? 2 : 1)
        )
    }

    private var tvGlyph: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.background)
                    .frame(width: 176, height: 100)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.divider, lineWidth: 2))
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Theme.insetSurface)
                            .frame(width: 22, height: 28)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.accent, lineWidth: 1))
                    }
                }
            }
            Rectangle().fill(Theme.divider).frame(width: 2, height: 12)
            RoundedRectangle(cornerRadius: 1).fill(Theme.divider).frame(width: 56, height: 2)
        }
    }
}

#Preview {
    PhonePairingView(appModel: .previewPairing())
}
