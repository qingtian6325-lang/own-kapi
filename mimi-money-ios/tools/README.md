# tools/

## appintents-protocols.json

AppIntents const-gather 协议清单，供 CI 在 stage 1 收割 `.swiftconstvalues` 时通过
`-const-gather-protocols-file` 传给 Swift 编译器（等价于 Xcode 的
`SWIFT_EMIT_CONST_VALUE_PROTOCOLS` 构建设置）。没有这份清单，编译器产出的
`.swiftconstvalues` 不含 AppIntent 常量，`appintentsmetadataprocessor` 无从提取
`Metadata.appintents`。

出处：借自 https://github.com/cyberneel/xtool-on-linux 仓库的
`appintents/appintents-protocols.json`（命令用法见其 docs/SIRI.md）。

v1.1.2 追加：`SnippetIntent`（iOS 26 确认卡的驱动协议，不在上游清单里，
为让 appintentsmetadataprocessor 能提取 ScanConfirmationSnippetIntent 而补入）。
