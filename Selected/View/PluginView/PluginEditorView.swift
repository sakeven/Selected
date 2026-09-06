import SwiftUI
import Yams

struct PluginEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let session: PluginEditorSession
    @ObservedObject var manager: PluginManager
    let didSave: (String) -> Void
    @State private var draft: Plugin
    @State private var source = ""
    @State private var mode = "可视化"
    @State private var section = "基本信息"
    @State private var expandedAction: UUID?
    @State private var expandedOption: UUID?
    @State private var message: String?
    @State private var isError = false

    init(session: PluginEditorSession, manager: PluginManager, didSave: @escaping (String) -> Void) {
        self.session = session
        self.manager = manager
        self.didSave = didSave
        var draft = session.plugin
        if session.existing != nil {
            draft.info.version = draft.info.version.flatMap(PluginVersion.init)?.nextPatch ?? "1.0.0"
        }
        _draft = State(initialValue: draft)
        _expandedAction = State(initialValue: draft.actions.first?.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.title2).foregroundStyle(Color.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.09), in: .rect(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.existing == nil ? "创建你的插件" : "编辑插件").font(.title3.bold())
                    Text(session.existing == nil ? "从一个动作开始，按你的方式工作。" : draft.info.name)
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 16)
                PluginSegmentedControl(values: ["可视化", "YAML"], selection: Binding(get: { mode }, set: switchMode), title: { $0 })
                    .frame(width: 170)
            }.padding(24)
            Divider().opacity(0.5)
            if mode == "YAML" {
                VStack(alignment: .leading, spacing: 12) {
                    Label("切回可视化会解析并校验；保存时重新排版，不保留注释。", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $source)
                        .font(.system(.body, design: .monospaced)).autocorrectionDisabled()
                        .scrollContentBackground(.hidden).padding(14)
                        .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.08)) }
                        .accessibilityLabel("插件 YAML 定义")
                }.padding(24)
            } else {
                PluginSegmentedControl(values: ["基本信息", "动作", "选项"], selection: $section) { value in
                    switch value {
                    case "动作": return "动作  ·  \(draft.actions.count)"
                    case "选项": return "选项  ·  \(draft.info.options.count)"
                    default: return value
                    }
                }.padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 6)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch section {
                        case "动作": actions
                        case "选项": options
                        default: basicInfo
                        }
                    }.padding(24).frame(maxWidth: .infinity)
                }
            }
            Divider().opacity(0.5)
            VStack(alignment: .leading, spacing: 12) {
                if let message {
                    ScrollView {
                        Label(message, systemImage: isError ? "exclamationmark.circle" : "checkmark.circle")
                            .font(.caption).foregroundStyle(isError ? Color.red : .secondary)
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 60)
                }
                HStack(spacing: 10) {
                    Button("检查配置", systemImage: "checkmark.shield") { validate() }
                        .buttonStyle(PluginButtonStyle(emphasis: .quiet))
                    Spacer()
                    Button("取消", role: .cancel) { dismiss() }
                        .buttonStyle(PluginButtonStyle()).keyboardShortcut(.cancelAction)
                    Button(session.existing == nil ? "创建插件" : "保存更改") { save() }
                        .buttonStyle(PluginButtonStyle(emphasis: .primary)).keyboardShortcut(.defaultAction)
                }
            }.padding(.horizontal, 24).padding(.vertical, 16)
        }
        .tint(Color.blue)
        .disclosureGroupStyle(PluginDisclosureGroupStyle())
        .background(Color("PluginBackground"))
        .frame(width: 760, height: 680)
        .interactiveDismissDisabled()
    }

    private var basicInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            PluginCard {
                PluginField(title: "插件名称") {
                    TextField("例如：阅读助手", text: $draft.info.name)
                        .disabled(session.existing != nil && draft.info.identifier == nil)
                        .accessibilityLabel("插件名称")
                }
                PluginField(title: "简介") {
                    TextField("这个插件可以帮你做什么？", text: $draft.info.description.text, axis: .vertical)
                        .lineLimit(2...3).accessibilityLabel("插件简介")
                }
                HStack(alignment: .top, spacing: 16) {
                    PluginField(title: "版本") {
                        TextField("1.0.0", text: $draft.info.version.text).accessibilityLabel("插件版本")
                    }.frame(maxWidth: 180)
                    PluginField(title: "图标") {
                        TextField("symbol:bolt", text: $draft.info.icon).accessibilityLabel("插件图标")
                    }
                }
                if let previous = session.existing?.info.version {
                    Label("当前版本 \(previous)，保存后可恢复上一版本。", systemImage: "clock.arrow.circlepath")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            PluginCard {
                DisclosureGroup("高级设置") {
                    VStack(alignment: .leading, spacing: 16) {
                        PluginField(title: "稳定标识") {
                            TextField("com.example.plugin", text: $draft.info.identifier.text)
                                .disabled(session.existing != nil).accessibilityLabel("插件稳定标识")
                        }
                        if draft.info.identifier == nil {
                            Text("旧插件使用名称作为标识，保持名称不变可以保留已有参数。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        PluginField(title: "最低 Selected 版本 · 可选") {
                            TextField("不限制", text: $draft.info.minSelectedVersion.text)
                                .accessibilityLabel("最低 Selected 版本")
                        }
                        Text("图标也支持文本图标和包内文件，例如 file://./icon.png。")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 16)
                }.font(.subheadline.weight(.medium))
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("选择动作，定义选中文字后的操作。")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    ForEach(ActionKind.allCases) { kind in
                        Button(kind.title) {
                            let action = Action.new(kind: kind)
                            draft.actions.append(action)
                            expandedAction = action.id
                        }
                    }
                } label: {
                    Label("添加动作", systemImage: "plus")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Color.blue)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.blue.opacity(0.08), in: .rect(cornerRadius: 9))
                }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }
            ForEach($draft.actions) { $action in
                PluginCard {
                    DisclosureGroup(isExpanded: Binding(get: { expandedAction == action.id }, set: { expandedAction = $0 ? action.id : nil })) {
                        VStack(alignment: .leading, spacing: 18) {
                            Divider().opacity(0.5)
                            PluginActionEditorView(action: $action)
                            Divider().opacity(0.5)
                            HStack(spacing: 4) {
                                Button("上移", systemImage: "arrow.up") { moveAction(action.id, by: -1) }
                                    .disabled(draft.actions.first?.id == action.id)
                                Button("下移", systemImage: "arrow.down") { moveAction(action.id, by: 1) }
                                    .disabled(draft.actions.last?.id == action.id)
                                Spacer()
                                Button("删除动作", systemImage: "trash", role: .destructive) { draft.actions.removeAll { $0.id == action.id } }
                                    .buttonStyle(PluginButtonStyle(emphasis: .destructive))
                            }.buttonStyle(PluginButtonStyle(emphasis: .quiet))
                        }.padding(.top, 14)
                    } label: {
                        HStack {
                            Label(action.meta.title.isEmpty ? "未命名动作" : action.meta.title, systemImage: "bolt")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(action.kind.title).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("定义可配置的字段，参数值在详情页填写。")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button("添加选项", systemImage: "plus") {
                    let option = Option(identifier: "option_" + UUID().uuidString.prefix(8), type: .string)
                    draft.info.options.append(option)
                    expandedOption = option.id
                }.buttonStyle(PluginButtonStyle())
            }
            if draft.info.options.isEmpty {
                PluginCard {
                    Label("还没有选项", systemImage: "slider.horizontal.3").font(.headline)
                    Text("可以添加语言选择、开关或密钥，让插件按需工作。")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach($draft.info.options) { $option in
                PluginCard {
                    DisclosureGroup(isExpanded: Binding(get: { expandedOption == option.id }, set: { expandedOption = $0 ? option.id : nil })) {
                        VStack(alignment: .leading, spacing: 18) {
                            Divider().opacity(0.5)
                            PluginOptionEditorView(option: $option)
                            HStack {
                                Spacer()
                                Button("删除选项", systemImage: "trash", role: .destructive) { draft.info.options.removeAll { $0.id == option.id } }
                                    .buttonStyle(PluginButtonStyle(emphasis: .destructive))
                            }
                        }.padding(.top, 14)
                    } label: {
                        HStack {
                            Text(option.displayName).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(option.type.title).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func switchMode(_ newMode: String) {
        do {
            if newMode == "YAML" { source = try YAMLEncoder().encode(draft) }
            else {
                let parsed = try YAMLDecoder().decode(Plugin.self, from: source)
                try parsed.validate()
                draft = parsed
                expandedAction = parsed.actions.first?.id
                expandedOption = nil
            }
            mode = newMode
            message = nil
        } catch { show(error) }
    }

    private func currentDraft() throws -> Plugin {
        let plugin = mode == "YAML" ? try YAMLDecoder().decode(Plugin.self, from: source) : draft
        try plugin.validate()
        return plugin
    }

    private func validate() {
        do {
            _ = try currentDraft()
            message = "配置检查通过，保存时将检查版本与标识冲突。"
            isError = false
        } catch { show(error) }
    }

    private func save() {
        do {
            let plugin = try currentDraft()
            try manager.save(plugin, replacing: session.existing)
            didSave(plugin.id)
            dismiss()
        } catch { show(error) }
    }

    private func show(_ error: Error) {
        message = error.localizedDescription
        isError = true
    }

    private func moveAction(_ id: UUID, by offset: Int) {
        guard let index = draft.actions.firstIndex(where: { $0.id == id }) else { return }
        draft.actions.swapAt(index, index + offset)
    }
}

extension Binding where Value == String? {
    var text: Binding<String> {
        Binding<String>(get: { wrappedValue ?? "" }, set: { wrappedValue = $0.isEmpty ? nil : $0 })
    }
}
