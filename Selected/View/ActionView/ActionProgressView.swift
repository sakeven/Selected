import SwiftUI

struct ActionProgressView: View {
    let session: ActionSession

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if session.isRunning {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: session.completed ? "checkmark" : "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(session.completed ? AppTheme.accent : .secondary)
                }
            }
            .frame(width: 36, height: 36)
            .background(AppTheme.selection, in: .rect(cornerRadius: 10))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.request.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .help(session.request.title)
                Text(session.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            if session.isRunning {
                Button("Cancel Run", systemImage: "xmark") { session.cancel() }
                    .buttonStyle(AppIconButtonStyle())
                    .disabled(!session.canCancel)
                    .help("Cancel Run")
            }
        }
        .frame(width: 320, height: 40)
        .padding(14)
        .modifier(AppPanel(cornerRadius: AppTheme.cardRadius))
    }
}
