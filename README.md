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
3. 解压得到带版本号的安装包（如 `MimiMoney-iOS-v1.2.2.ipa`，文件名里的版本号与 Release 版本一致），使用 **Sideloadly** 或 **AltStore / SideStore** 输入免费 Apple ID 签名安装到 iPhone。

## 截屏自动记账设置（快捷指令 + AppIntents）

> 无需下载任何 `.shortcut` 文件（未签名文件 iOS 本就无法导入）。App 已内置原生动作 **「识别账单」**，并自 v1.1.0 起在安装包内携带 `Metadata.appintents`，系统可直接发现该动作。

1. 打开系统 **快捷指令 (Shortcuts)** App → 点右上角 **+** 新建，依次添加动作：
   - **隐藏控制中心 (Hide Control Centre)**
   - **等待 (Wait)** 1 秒
   - **截屏 (Take Screenshot)**
   - **从截屏获取图像 (Get Images from Screenshot)**
   - **识别账单 (咪咪记账)**：将「内容 (Content)」设为上一步的「图像 (Images)」，「类型 (Type)」保持 2；展开参数确认「运行时显示 (Show When Run)」与「运行时打开 (Open When Run)」两个开关都打开。
2. 把这个捷徑绑定到任意触发方式（App 内「自动记账」页有图文教程与「添加专属指令」按钮）：
   - **控制中心**：长按进入编辑 → 添加控制 → 「快捷指令」→ 选取该捷徑
   - **轻敲背面**：设置 → 辅助功能 → 触控 → 轻点背面 → 轻点两下/三下 → 勾选该捷徑
   - **辅助触控**：设置 → 辅助功能 → 触控 → 辅助触控 → 单点/轻点两下/长按 → 选择该捷徑
   - **操作按钮**（iPhone 15 Pro+）：设置 → 操作按钮 → 快捷指令 → 选取该捷徑
3. 付款完成后触发一次：识别卡片浮在付款 App 上方，点 **确认 (Got it)** 原地入账，点 **修改 (View)** 跳进 App 编辑。
