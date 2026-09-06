import SwiftUI

struct PluginActionEditorView: View {
    @Binding var action: Action

    var body: some View {
        PluginField(title: "动作名称") {
            TextField("例如：总结内容", text: $action.meta.title).accessibilityLabel("动作名称")
        }
        PluginSegmentedControl(values: ActionKind.allCases, selection: Binding(get: { action.kind }, set: { action.setKind($0) }), title: { $0.title })
        switch action.kind {
        case .url:
            PluginField(title: "链接模板") {
                TextField("https://example.com/search?q={selected.text}", text: Binding(get: { action.url?.url ?? "" }, set: { action.url?.url = $0 }), axis: .vertical)
                    .accessibilityLabel("链接模板")
            }
            Text("{selected.text} 表示选中文字，{selected.options.标识} 表示选项值。")
                .font(.caption).foregroundStyle(.secondary)
        case .service:
            PluginField(title: "macOS 服务名称") {
                TextField("Make Sticky", text: Binding(get: { action.service?.name ?? "" }, set: { action.service?.name = $0 }))
                    .accessibilityLabel("macOS 服务名称")
            }
        case .keycombo:
            PluginField(title: "快捷键 · 每行一个组合") {
                TextEditor(text: Binding(get: {
                    action.keycombo?.keycombos?.joined(separator: "\n") ?? action.keycombo?.keycombo ?? ""
                }, set: { value in
                    let combos = value.components(separatedBy: "\n")
                    if combos.count == 1 {
                        action.keycombo?.keycombo = value
                        action.keycombo?.keycombos = nil
                    } else {
                        action.keycombo?.keycombo = ""
                        action.keycombo?.keycombos = combos
                    }
                }))
                .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                .frame(minHeight: 65).accessibilityLabel("快捷键组合")
            }
            Text("例如 cmd shift c。多个组合按顺序执行。")
                .font(.caption).foregroundStyle(.secondary)
            if action.keycombo?.supported != nil {
                Text("已有的应用匹配规则会保留，可在 YAML 中修改。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .gpt:
            PluginField(title: "提示词") {
                TextEditor(text: Binding(get: { action.gpt?.prompt ?? "" }, set: { action.gpt?.prompt = $0 }))
                    .font(.body).scrollContentBackground(.hidden)
                    .frame(minHeight: 120).accessibilityLabel("AI 提示词")
            }
            Text("使用 {{selected.text}} 插入选中文字，{{options.标识}} 插入选项值。")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("启用推理", isOn: Binding(get: { action.gpt?.reasoning ?? (action.meta.after == nil || action.meta.after == AfterAction.none) }, set: { action.gpt?.reasoning = $0 }))
                .toggleStyle(.switch).controlSize(.small)
            if let tools = action.gpt?.tools, !tools.isEmpty {
                Label("已保留 \(tools.count) 个 AI 工具，可在 YAML 中编辑。", systemImage: "wrench.and.screwdriver")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .runCommand:
            PluginField(title: "命令与参数") {
                TextEditor(text: Binding(get: { action.runCommand?.command.joined(separator: "\n") ?? "" }, set: {
                    action.runCommand?.command = $0.isEmpty ? [] : $0.components(separatedBy: "\n")
                }))
                .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                .frame(minHeight: 120).accessibilityLabel("命令与参数")
            }
            Text("第一行是程序，之后每行一个参数。选中文字通过 SELECTED_TEXT 传入，工作目录为插件包。")
                .font(.caption).foregroundStyle(.secondary)
        }
        if action.gpt != nil || action.runCommand != nil {
            PluginMenuPicker(title: "结果处理", values: AfterAction.allCases,
                             selection: Binding<AfterAction>(get: { action.meta.after ?? AfterAction.none }, set: { action.meta.after = $0 }), label: resultTitle)
        }
        DisclosureGroup("显示条件") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(ActionRequirement.allCases, id: \.self) { requirement in
                    Toggle(requirement.title, isOn: Binding(get: {
                        action.meta.requirements?.contains(requirement) == true
                    }, set: { enabled in
                        var requirements = action.meta.requirements ?? []
                        requirements.removeAll { $0 == requirement }
                        if enabled { requirements.append(requirement) }
                        action.meta.requirements = requirements.isEmpty ? nil : requirements
                    })).toggleStyle(.switch).controlSize(.small)
                }
                PluginField(title: "文本正则表达式 · 可选") {
                    TextField("不限制", text: $action.meta.regex.text).accessibilityLabel("文本正则表达式")
                }
                PluginStringListField(title: "仅在这些应用显示 · 逗号分隔 bundle ID", values: $action.meta.requiredApps)
                PluginStringListField(title: "在这些应用隐藏 · 逗号分隔 bundle ID", values: $action.meta.excludedApps)
                Text("所有条件须同时满足；动作接收完整选中文本。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.top, 14)
        }.font(.subheadline)
        DisclosureGroup("更多设置") {
            VStack(alignment: .leading, spacing: 16) {
                PluginField(title: "动作标识") {
                    TextField("com.example.action", text: $action.meta.identifier).accessibilityLabel("动作标识")
                }
                Text("应用配置会引用此标识，发布后应保持稳定。")
                    .font(.caption).foregroundStyle(.secondary)
                PluginField(title: "图标") {
                    TextField("symbol:bolt", text: $action.meta.icon).accessibilityLabel("动作图标")
                }
                PluginField(title: "说明") {
                    TextField("简短描述这个动作", text: $action.meta.description.text).accessibilityLabel("动作说明")
                }
            }.padding(.top, 14)
        }.font(.subheadline)
    }

    private func resultTitle(_ result: AfterAction) -> String {
        switch result {
        case .none: return action.gpt != nil ? "打开对话" : "不处理输出"
        case .paste: return "替换选中文本"
        case .copy: return "复制到剪贴板"
        case .show: return "显示结果"
        case .xshow: return "显示并允许替换"
        }
    }
}
