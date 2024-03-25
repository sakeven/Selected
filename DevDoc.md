面向开发者的文档



## 自定义操作列表

在“设置-应用”中可以配置

配置文件在 `Library/Application Support/Selected/UserConfiguration.json`。

内容示例：

```json
{
  "appConditions": [
    {
      "bundleID": "com.apple.dt.Xcode",
      "actions": ["selected.websearch", "selected.xcode.format"]
    }
  ]
}
```

`appConditions.bundleID` 为应用的 bundleID。
`actions` 为 `action.identifier` 列表。

具体可以用哪些以及如何自定义 action，请看内置操作与自定义插件。

没有为应用配置 action 列表或者为应用配置的 action 列表为空时，将会显示所有可用操作。