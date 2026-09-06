import SwiftUI

struct ApplicationPickerView: View {
    let applications: [Application]
    let select: (Application) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("添加应用").font(.headline).padding(16)
            Divider()
            if applications.isEmpty {
                Text("没有可添加的应用").foregroundStyle(.secondary).padding(24)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        applicationSection("正在运行", applications: applications.filter(\.isRunning))
                        applicationSection("其他应用", applications: applications.filter { !$0.isRunning })
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
