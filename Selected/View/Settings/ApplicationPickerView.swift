import SwiftUI

struct ApplicationPickerView: View {
    let applications: [Application]
    let select: (Application) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add App").font(.headline).padding(16)
            Divider()
            if applications.isEmpty {
                Text("No apps available to add").foregroundStyle(.secondary).padding(24)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        applicationSection("Running", applications: applications.filter(\.isRunning))
                        applicationSection("Other Apps", applications: applications.filter { !$0.isRunning })
                    }.padding(10)
                }
                .frame(maxHeight: 400)
            }
        }
        .frame(width: 320)
        .background(Color("SettingsBackground"))
    }

    @ViewBuilder private func applicationSection(_ title: LocalizedStringKey, applications: [Application]) -> some View {
        if !applications.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.top, 4).padding(.bottom, 2)
                ForEach(applications) { app in
                    Button { select(app) } label: {
                        HStack(spacing: 10) {
                            app.icon.renderingMode(.original).resizable().scaledToFit()
                                .frame(width: 28, height: 28).accessibilityHidden(true)
                            Text(app.localizedName).lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(SettingsButtonStyle(emphasis: .quiet))
                }
            }
        }
    }
}
