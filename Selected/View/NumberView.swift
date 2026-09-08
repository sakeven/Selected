import SwiftUI

struct NumerberView: View {
    let value: String
    @State private var isCopied = false

    var body: some View {
        Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(value, forType: .string)
            isCopied = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isCopied ? "checkmark" : "equal")
                    .frame(width: 12)
                    .accessibilityHidden(true)
                Text(value).monospacedDigit()
            }
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 8)
            .frame(height: 32)
        }
        .buttonStyle(BarButtonStyle())
        .help("Copy result")
        .accessibilityLabel(Text("Copy result") + Text(": ") + Text(value))
        .accessibilityValue(isCopied ? Text("Copied") : Text(value))
        .task(id: isCopied) {
            guard isCopied else { return }
            do { try await Task.sleep(for: .milliseconds(800)) }
            catch { return }
            isCopied = false
        }
    }
}
