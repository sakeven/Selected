import SwiftUI

struct PluginOptionEditorView: View {
    @Binding var option: Option

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            PluginField(title: "显示名称") {
                TextField("例如：输出语言", text: $option.label.text).accessibilityLabel("选项显示名称")
            }
            PluginField(title: "选项标识") {
                TextField("language", text: $option.identifier).accessibilityLabel("选项标识")
            }
        }
        PluginSegmentedControl(values: OptionType.allCases, selection: $option.type, title: { $0.title })
            .onChange(of: option.type) {
                option.defaultVal = nil
                option.values = option.type == .multiple ? ["first", "second"] : nil
                option.valueLabels = nil
                option.multiline = nil
            }
        switch option.type {
        case .boolean:
            Toggle("默认开启", isOn: Binding(get: { option.defaultVal == "true" }, set: { option.defaultVal = $0.description }))
                .toggleStyle(.switch).controlSize(.small)
        case .multiple:
            PluginStringListField(title: "候选值 · 逗号分隔", values: $option.values)
                .onChange(of: option.values) {
                    if let value = option.defaultVal, option.values?.contains(value) != true { option.defaultVal = nil }
                }
            PluginStringListField(title: "显示名称 · 可选，顺序对应候选值", values: $option.valueLabels)
            PluginMenuPicker(title: "默认值", values: Array(Set(option.values ?? [])).sorted(),
                             selection: Binding(get: { option.defaultVal ?? option.values?.first ?? "" }, set: { option.defaultVal = $0 }), label: { $0 })
        case .string:
            PluginField(title: "默认值") {
                TextField("留空则不设默认值", text: $option.defaultVal.text, axis: .vertical).accessibilityLabel("选项默认值")
            }
            Toggle("允许多行输入", isOn: Binding(get: { option.multiline ?? false }, set: { option.multiline = $0 }))
                .toggleStyle(.switch).controlSize(.small)
        case .secret:
            Label("在插件详情页填写，保存到系统钥匙串。", systemImage: "lock.shield")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        PluginField(title: "填写说明 · 可选") {
            TextField("帮助用户理解如何填写", text: $option.description.text, axis: .vertical)
                .accessibilityLabel("选项填写说明")
        }
    }
}
