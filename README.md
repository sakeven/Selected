# 功能

一个选择文本后可以进行各种操作的 mac 工具。

当你鼠标选择文本、或者通过键盘选择文本（cmd+A, cmd+shift+方向键）后，会自动弹出 Selected 工具栏，进行快捷的文本操作，比如复制、翻译、搜索、询问 GPT、朗读文本、打开链接、键盘操作、执行命令等等，并且支持自定义插件。

![Screenshot](DocImages/Screenshot.png)

1. 本工具可以对不同应用实现自定义操作列表。(在“设置-应用”中可以配置)
2. 本工具支持自定义 OpenAI 与 Gemini API 的地址与 key。翻译与询问 GPT 功能依赖于此。
3. 本工具支持自定义插件（暂时缺乏文档，还未完整实现）。

## 自定义操作列表

在“设置-应用”中可以配置。

<img src="/Users/sake/workdir/Selected/DocImages/Application-Settings.png" alt="image-20240325203050807" style="zoom:50%;" />

1. 支持增加当前正在运行中的应用（暂不支持删除一个应用）
   * 通过“增加-选择一个应用”增加
2. 支持为某个应用设置一系列操作
   - 通过“增加-选择一个操作”增加
   - 支持删除一个操作
   - 支持拖拽操作以调整排列顺序

## 内置操作

| 操作名     | 操作标识action.identifie | 功能                                                         | 图标 |
| ---------- | ------------------------ | ------------------------------------------------------------ | ---- |
| Web Search | selected.websearch       | 通过 https://www.google.com/search 进行搜索。可以在设置页面自定义。 | 🔍    |
| OpenLinks  | selected.openlinks       | 打开一个 URL 链接                                            | 🔗    |
| Copy       | selected.copy            | 复制当前选中文本                                             | 📃    |
| Speak      | selected.speak           | 朗读文本                                                     | ▶️    |
| 2Chinese   | selected.translation.cn  | 翻译到中文，如果选中的文本为单词，则翻译单词的详细意思。需在设置里配置 API key | 字典 |
| 2English   | selected.translation.en  | 翻译到英文。需在设置里配置 API key                           | 🌍    |

## 自定义插件

插件放置在 `Library/Application Support/Selected/Extensions` 目录下，一个插件一个目录。

插件目录里，必须有 `config.yaml` 文件，用以说明插件的相关信息。

示例：

```yam
info:
  icon: file://./go-logo-white.svg
  name: Go Search
  enabled: true
actions:
- meta:
    title: GoSearch
    icon: file://./go-logo-white.svg
    identifier: selected.gosearch
    after: ""
  url:
    url: https://pkg.go.dev/search?limit=25&m=symbol&q={text}
```

| 字段名                     | 类型   | 含义                                                         |
| -------------------------- | ------ | ------------------------------------------------------------ |
| info                       | object | 插件的基本信息                                               |
| info.icon                  | 字符串 | 图标。图标尺寸应该为 30*30。支持使用 file:// 指定文件。`file://./go-logo-white.svg` 即是从插件目录下的文件加载图标。也支持直接配置 [sf symbol](https://developer.apple.com/cn/sf-symbols/)，比如 `magnifyingglass` （🔍）。显示在设置的插件列表里（还没实现）。 |
| info.name                  | 字符串 | 插件名。显示在设置的插件列表里（还没实现）。                                 |
| enabled                    | 布尔   | 是否激活该插件                                               |
| actions                    | 列表   | 操作（action）列表                                           |
| action.meta                | object | 操作的元信息                                                 |
| action.meta.title          | 字符串 | 操作的标题。用于在鼠标悬浮在工具栏上显示操作的名称。  |
| action.meta.icon           | 字符串 | 配置与 `info.icon` 相同。用于显示在工具栏上。                |
| action.meta.identifier     | 字符串 | action 的 id，唯一标识符                                     |
| action.meta.after     | 字符串 | action 执行完成之后的处理。必填。支持配置空（""）、paste、copy。 |
| action.url                 | object | url 类型的操作                                               |
| action.url.url             | 字符串 | 一个链接，点击操作（action）之后会打开这个链接。支持打开其它应用的 scheme。比如 `https://www.google.com.hk/search?q={text}` 进行谷歌搜索。或者打开 `things:///add?title={text}&show-quick-entry=true` 打开 [Things3](https://culturedcode.com/things/) 添加待办。{text} 用于替换选中的文本。 |
| action.service             | object | service 类型的操作                                           |
| action.service.name | 字符串 | service 名称。比如 `Make Sticky` 新建一个便条（便笺应用）。              |
| action.keycombo            | object | 快捷键类型的操作                                             |
| action.keycombo.keycombo   | 字符串 | 快捷键，比如 "cmd i" 等。支持 "cmd" "shift" "ctr" "option" "fn" "caps" 功能键，以及小写字母、数字、符号等键位。键位支持暂不完整，待测试完善。 |
| action.gpt                 | object | 与 GPT 交互，比如 OpenAI（3.5 turbo 模型）、Gemini。需要在设置里配置相关的 api key。 |
| action.gpt.prompt          | 字符串 | GPT 提示词，比如`丰富细化以下内容。内容为：{text}`。使用 `{text}` 替换选中的文本。 |
| action.runCommand | object | 执行一个命令 |
| action.runCommand.command | 字符串 | 命令与参数列表。命令执行时的工作目录为插件目录。目前提供的环境变量包括：`SELECTED_TEXT`、`SELECTED_BUNDLEID` 分别为当前选中的文本，以及当前所在的应用。 |

每个 action 只能且必须配置 action.url、action.service、action.keycombo、action.gpt、action.runCommand 中的一个。

# 说明

本工具是作者的业余项目，还在快速开发迭代中，功能并不完善。欢迎大家提交功能建议与实现代码。

# 贡献

本项目欢迎任何的贡献。

由于作者是零基础的 Swift、SwiftUI、macOS App 开发小白，所有实现都是通过 GPT、搜索、阅读相关项目（EasyDict、PopClip）的代码与文档获得的，所以如果需要贡献代码，请清楚地说明代码是如何实现的，以及为什么这么实现，以帮助作者理解你代码。
