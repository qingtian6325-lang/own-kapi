# Changelog - 咪咪记账 (Mimi Money iOS)

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.1.3] - 2026-11-11

### 🎨 Highlights
- **卡上只剩 View / Got it 两个按钮，与 Kapi 一模一样**：v1.1.2 的确认卡是系统按钮对「取消／确认」、卡内另有一颗自制「修改 (View)」按钮。v1.1.3 把系统确认按钮对的文案直接改名为 **View（左、灰）/ Got it（右、蓝）**——位置与配色本就是同一套系统排版——并撤掉卡内自制按钮。卡上只剩账单信息、✓ 提示行和这一对按钮，没有多余的选择。
- **点 View 打开 App 改这笔**：系统层面「点 deny 按钮」与「下滑关卡」是同一种取消信号、无法区分，本版统一接成「修改」语义：不落正式账，暂存转未确认记录并打开 App 定位到这笔的编辑页（下滑关卡同样会打开 App，这是该机制的已知行为）。其他异常则作废这笔、安静结束。
- **点 Got it 才入账**：与 v1.1.2 相同，点 Got it（原「确认」）后才正式记账，随后直接结束回原 App，全程没有 Done。
- **分层差异**：iOS 26+ 与 iOS 18–25 均使用 View / Got it 自定义文案；iOS 17 的旧确认 API 只接受系统预置文案（Log / Cancel），无法改名，功能不变。App 内扫描后的浮层卡片行为不变。

## [v1.1.2] - 2026-11-11

### 🚀 Highlights
- **识别卡改确认型，告别 Done**：此前「识别账单」是结果型 snippet——识别完先落盘再弹卡，按苹果设计（WWDC25-281）这类卡片底部必有系统 Done 按钮，无法隐藏（v1.1.1 去掉 dialog 后真机实测 Done 仍在）。v1.1.2 改走确认型呈现：识别结果先暂存（不落盘、不计入余额与列表），系统弹出确认卡；点「确认」才真正记账，随后 Intent 返回空结果——没有任何可呈现内容，捷徑流程直接结束回原 App，全程没有 Done。
- **点确认才入账，取消不记账**：在确认卡上取消或下滑 = 这笔不记（暂存永不落盘，自动丢弃），与「先记账再说」彻底分开。
- **「修改 (View)」保留在确认卡内**：点它会把这笔以未确认状态转入正式记录并打开 App 定位到编辑页，改完保存即可；暂存单次消费、双路径互斥，绝不重复记账。
- **按系统版本分层呈现**：iOS 26+ 用 SnippetIntent 驱动的互动确认卡（系统确认按钮文案「确认」，卡面与原结果卡一致）；iOS 18–25 用带卡面视图的确认；iOS 17 降级为纯文字确认。App 内扫描后的浮层卡片行为不变。

## [v1.1.1] - 2026-11-11

### 🔧 Fixes
- **识别提示不再重复显示**：「识别账单」Intent 不再返回 dialog——此前 iOS 会把 dialog「已识别记录以上信息，打开「咪咪记账」查看更多」单独显示成顶部大字，而 snippet 卡片内部又有同一句，于是出现两次。v1.1.1 起 perform() 只返回结果卡片，那句话只在卡片里出现一次（与 Kapi 一致）。

## [v1.1.0] - 2026-11-11

### 🚀 Highlights
- **捷徑「识别账单」真正可用（修复根因）**：v1.0.9 及更早的 IPA 是 `swift build` 手工拼包，从不生成 `Metadata.appintents`，iOS 根本发现不了 `ScanScreenshotIntent`。v1.1.0 起 CI 显式运行 `appintentsmetadataprocessor` 提取元数据并塞入 .app，并新增硬验证：`extract.actionsdata` 缺失或不含 `ScanScreenshotIntent` 直接构建失败。
- **「识别账单」Intent 参数收干净**：只保留「内容 / 类型（默认 2）/ 版本（默认 1.1.0）」，与 Kapi 捷徑编排一致；「修改账单 / 确认记账」两个辅助 Intent 设为不在动作库中单独展示。
- **删除错误捷徑流程**：移除自带的截屏→剪贴板→openURL `.shortcut` 文件（未签名本就无法导入），不再打进 .app 与 Release。
- **自动记账指南页改版（Kapi 式）**：四种触发方式分区（①辅助触控 ②轻敲手机背面 ③操作按钮 ④控制中心），附「教程」6 步手动搭建与醒目蓝色「添加专属指令」按钮（iCloud 一键导入链接待用户在设备上生成后填入开通）。
- **分类图标贴纸风升级**：白底圆、浅灰细描边、轻微阴影、emoji 放大；图标库扩充至 14 个分组、520+ 个不重复 emoji。
- **全新 App 图标**：原创贴纸风——蓝白渐变底＋橘猫「咪咪」抱金币、脚边账本。

## [v1.0.8] - 2026-11-11

### 🚀 Highlights
- **全面完成「咪咪记账」(Mimi Money) 独立重构与去 Kapi 化**：
  - 仓库迁移至专属仓库 `https://github.com/qingtian6325-lang/own-mimi`。
  - 全局代码、架构模块、类名、协议、包名、文件夹全面重构更名为 `MimiMoney` 系列：
    - 应用程序核心：`MimiMoneyApp`、`MimiMoneyCore`、`MimiMoneyTests`；
    - 设计系统与状态：`MimiTheme`、`MimiStore`、`MimiModels`、`MimiRootContainerView`、`MimiStatsView`、`MimiStickerIconView`；
    - 智能化与服务：`MimiAIEngine`、`MimiCSVService`、`MimiShortcuts`、`MimiAppShortcutsProvider`。
  - URL Scheme 全面更名为 `mimimoney://`，系统深度链接与 Bundle ID 更新为 `com.jinghao.mimimoney`。
  - 打包生成专属 `MimiScreenshotBookkeeping.shortcut` 快捷指令及 `MimiMoney-iOS.ipa`。
  - 全工程完全清除所有历史遗留标识，实现 100% 独立纯净的「咪咪记账」。

## [v1.0.4] - 2026-11-10

### 🚀 Highlights
- **支持浮窗交互式 Dialog：停留在当前 App，按确认静默记账不跳转，按修改才跳转**：
  - 重构 `ScreenshotResultSnippetView` 与 `AppIntents` 交互体系：在 iOS 系统级浮窗卡片中，按「确认 (Got it)」由 `ConfirmBillIntent` 执行，完全停留在当前银行/支付 App 静默平账入库，绝不跳转；只有用户点击「修改 (View)」才由 `OpenBillForEditIntent` 唤起 App 进行编辑。
  - 提供了快捷指令原生「从菜单中选取 (Choose from Menu)」对话框配置指南，解决苹果阻止导入未签名 `.shortcut` 文件的限制。
- **修复负数余额被绝对值吞没的重大 Bug**：修复 `MimiTheme.formatRM` 错误调用 `abs(value)` 导致账户透支或负数金额（如 `-RM700.00`）错误显示为正数 `RM700.00` 的问题。若透支不够钱，严格显示 `-RM700.00` 并高亮红字警示。
- **重构并理清【期初起始资金 (Initial Capital)】全生命周期**：
  - 每个账户底层独立引入 `initialBalance`（全部记账前的初始资金）与 `balance`（当前实际余额）。
  - **正推法**：输入记账前的起始资金，系统结合历史流水净变动，自动计算当前真实余额。
  - **倒推法**：输入手机银行当前实际余额，系统自动逆向倒推出当年记账前的起始资金。
  - 在【资产管理】与【通用设置】中全面支持双模式校准，历史流水与当前身家严谨闭环。

## [v1.0.3] - 2026-11-10

### 🚀 Highlights
- **【自动记账】内置一键跳转添加快捷指令与离线集成**：
  - 在【自动记账】页面新增高亮按钮“⚡ 一键跳转导入「咪咪截屏自动记账」快捷指令”，点击直接唤起 iOS Safari / 快捷指令 App 进行一键安装。
  - 新增“打开「快捷指令」App”与“离线发送至快捷指令 (ShareLink)”双重通道，将 1007 字节的标准快捷指令文件永久内置打包于 App 内部，断网也能导入。
  - 新增“📸 无需快捷指令 · 一键读取剪贴板截图直接记账”快捷按钮，手机截图复制后在 App 内点按直接调用 Apple Vision OCR 记账。

## [v1.0.2] - 2026-11-10

### 🚀 Highlights
- **支持在【设置】与【资产】中自定义设置各账户起始金额（期初余额）**：
  - 【通用设置】新增“💳 账户起始金额与开局资产设置”配置卡，每个账户均可直接输入开局金额并实时保存。
  - 【资产管理】新增“添加自定义资产账户”功能，支持创建 Maybank、GrabPay、加密钱包、备用金等自定义资金账户，并设定其初始开局余额。
  - `MimiStore` 新增 `deleteAccount` 与账户审计全生命周期联动，日常记账、转账与改额实时平账。

## [v1.0.1] - 2026-11-10

### 🚀 Highlights
- **100% 完整交互功能上线**：重构并连接了全部 11 个模块与抽屉页面的底层业务逻辑，去除所有死按钮与空状态提示。
- **纯净空白初始状态 (Clean Empty State)**：新安装 App 打开后，总资产 `RM0.00`、净资产 `RM0.00`、记录天数 `0 天`、交易记录 `0 笔`，无任何伪造或默认演示数据。
- **真实 iOS 快捷指令截屏记账**：快捷指令 `MimiScreenshotBookkeeping.shortcut` 配合 `ReceiptOCRService`（Apple Vision OCR），支持自动截屏识别金额与商户，无截图时自动降级读取系统剪贴板。

### 🔧 Fixed & Improved
- **编译修复**：修复 `TransactionItem` 便利构造器缺少 `tags` 参数的问题，确保 `RecordAndAISheetView` 自定义标签保存正常编译与运行。
- **版本控制与 CI 自动化**：新增 `VERSION` 集中版本管理，GitHub Actions 自动化构建产物并同时同步发布到 `v1.0.1` 和 `v1.0.0` Release。
- **账本管理 (Ledger Management)**：支持账本实时切换、新建账本（名称、货币类型、月度预算）、删除非主账本、直接调整月预算。
- **标签管理 (Tag Management)**：支持新增自定义标签、删除标签、点击标签按当前账本筛选交易记录。
- **定时记账 (Scheduled Bills)**：支持周期性扣款项（房租、订阅、贷款等）开关、新增计划、以及“立即入账”真实写入账户余额与账本流水。
- **小组件交互预览 (Widgets Showcase)**：提供小号（今日可用）、中号（7日趋势与结余）、大号（月度总预算环图与三分类）及锁屏小组件的实时数据渲染预览。
- **通用设置 (General Settings)**：支持昵称编辑、触觉反馈开关、存储占用查看与完全离线沙盒重置。
- **收支统计筛选 (Dynamic Stats)**：支持“周 / 月 / 年 / 自定义”周期切换，分类环形图、每日收支柱状图与 Top 10 排行榜完全动态联动。
- **双表头 CSV 完整解析**：全面兼容包含 140 笔收支与 11 笔转账（共 151 笔）的多行带引号转账备注与账户映射。

## [v1.0.0] - 2026-11-10

### Initial Release
- 1:1 原生 SwiftUI 咪咪记账界面设计体系（MimiTheme、卡片设计、猫咪吉祥物插画、自研数字键盘）。
- 资产账户体系（Cash, Maybank, TNG eWallet, Touch 'n Go NFC）。
- 离线优先无服务器架构，本地 JSON 与 SQLite 双层持久化支持。
- 基础 GitHub Actions CI 跨平台编译流程。
