# 咪咪记账 iOS 原生版 (Mimi Money iOS Native Clone)

基于 **Swift + SwiftUI + AppIntents + Vision OCR + xtool** 构建的 1:1 原生 iPhone 记账应用。

## 核心特性
- **1:1 像素级还原**：月预算仪表盘、今日可用动态日预算（RM92.26）、分类预算进度条、净资产 30 天趋势、收支热力日历、水豚图表统计、资产账户审计明细（记 / 改 / 删）。
- **内置双模 AI 财务官**：离线支持「一句话记多笔」、TNG eWallet / 银行账单收据 Vision OCR 识别、标准收支分类问答，同时支持可选接入自定义大模型 API Key。
- **iOS 快捷指令 (AppIntents) 截屏自动记账弹窗**：
  - 付款成功后自动截屏识别，顶部弹出双按钮卡片：
  - **修改 (View)**：直接跳转进 App 内的「账单详情」编辑页面（mimimoney://edit-bill?id=...）
  - **确认 (Got it)**：无需打开 App，直接入账并关闭弹窗

## 如何下载并安装 .ipa 到 iPhone
1. 打开本仓库顶部的 **[Actions](https://github.com/qingtian6325-lang/own-mimi/actions)** 标签页。
2. 点进最新一条成功的 **Build Mimi Money iOS (.ipa)** 任务，在页面底部 **Artifacts** 区域下载 MimiMoney-iOS-IPA。
3. 解压得到 MimiMoney-iOS.ipa，使用 **Sideloadly** 或 **AltStore / SideStore** 输入免费 Apple ID 签名安装到 iPhone。

## iPhone「轻点背面两下」截屏记账设置
1. 安装 App 后打开系统 **快捷指令 (Shortcuts)** App → 新建快捷指令：
   - 第 1 步：添加动作 **截屏 (Take Screenshot)**
   - 第 2 步：添加动作 **咪咪截图记账 (ScanScreenshotIntent)**，将「截图文件」绑定为上一步的「截屏」结果。
2. 打开 iPhone **设置 → 辅助功能 → 触控 → 轻点背面 → 轻点两下**，勾选刚建好的快捷指令即可。
