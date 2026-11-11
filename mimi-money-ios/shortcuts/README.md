# shortcuts/

历史上的 `MimiScreenshotBookkeeping.shortcut`（截屏 → 剪贴板 → 打开 `mimimoney://quick-scan`）已于 v1.1.0 删除：

- 该文件未经 Apple 签名，iOS 本就无法导入（会提示「不支持导入未签名的快捷指令」）；
- 剪贴板 + openURL 流程会先跳进 App，无法在付款 App 上方直接弹识别卡片，与目标体验不符。

现在的正确做法：App 已内置原生 AppIntent 动作「识别账单」（带 `Metadata.appintents` 注册）。
用户在系统「快捷指令」App 中新建捷徑，依次添加
「隐藏控制中心 → 等待 1 秒 → 截屏 → 从截屏获取图像 → 识别账单（内容 = 图像）」，
再绑定控制中心 / 轻敲背面 / 辅助触控 / 操作按钮任一触发方式即可。
App 内「自动记账」页面有四种触发方式的完整图文教程与「添加专属指令」按钮。
