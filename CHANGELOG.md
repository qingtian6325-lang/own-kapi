# Changelog - 咔皮记账 (Kapi Money iOS)

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.0.4] - 2026-11-10

### 🚀 Highlights
- **修复负数余额被绝对值吞没的重大 Bug**：修复 `KapiTheme.formatRM` 错误调用 `abs(value)` 导致账户透支或负数金额（如 `-RM700.00`）错误显示为正数 `RM700.00` 的问题。若透支不够钱，严格显示 `-RM700.00` 并高亮红字警示。
- **重构并理清【期初起始资金 (Initial Capital)】全生命周期**：
  - 每个账户底层独立引入 `initialBalance`（全部记账前的初始资金）与 `balance`（当前实际余额）。
  - **正推法**：输入记账前的起始资金，系统结合历史流水净变动，自动计算当前真实余额。
  - **倒推法**：输入手机银行当前实际余额，系统自动逆向倒推出当年记账前的起始资金。
  - 在【资产管理】与【通用设置】中全面支持双模式校准，历史流水与当前身家严谨闭环。

## [v1.0.3] - 2026-11-10

### 🚀 Highlights
- **【自动记账】内置一键跳转添加快捷指令与离线集成**：
  - 在【自动记账】页面新增高亮按钮“⚡ 一键跳转导入「咔皮截屏自动记账」快捷指令”，点击直接唤起 iOS Safari / 快捷指令 App 进行一键安装。
  - 新增“打开「快捷指令」App”与“离线发送至快捷指令 (ShareLink)”双重通道，将 1007 字节的标准快捷指令文件永久内置打包于 App 内部，断网也能导入。
  - 新增“📸 无需快捷指令 · 一键读取剪贴板截图直接记账”快捷按钮，手机截图复制后在 App 内点按直接调用 Apple Vision OCR 记账。

## [v1.0.2] - 2026-11-10

### 🚀 Highlights
- **支持在【设置】与【资产】中自定义设置各账户起始金额（期初余额）**：
  - 【通用设置】新增“💳 账户起始金额与开局资产设置”配置卡，每个账户均可直接输入开局金额并实时保存。
  - 【资产管理】新增“添加自定义资产账户”功能，支持创建 Maybank、GrabPay、加密钱包、备用金等自定义资金账户，并设定其初始开局余额。
  - `KapiStore` 新增 `deleteAccount` 与账户审计全生命周期联动，日常记账、转账与改额实时平账。

## [v1.0.1] - 2026-11-10

### 🚀 Highlights
- **100% 完整交互功能上线**：重构并连接了全部 11 个模块与抽屉页面的底层业务逻辑，去除所有死按钮与空状态提示。
- **纯净空白初始状态 (Clean Empty State)**：新安装 App 打开后，总资产 `RM0.00`、净资产 `RM0.00`、记录天数 `0 天`、交易记录 `0 笔`，无任何伪造或默认演示数据。
- **真实 iOS 快捷指令截屏记账**：快捷指令 `KapiScreenshotBookkeeping.shortcut` 配合 `ReceiptOCRService`（Apple Vision OCR），支持自动截屏识别金额与商户，无截图时自动降级读取系统剪贴板。

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
- 1:1 原生 SwiftUI 咔皮记账界面设计体系（KapiTheme、卡片设计、猫咪吉祥物插画、自研数字键盘）。
- 资产账户体系（Cash, Maybank, TNG eWallet, Touch 'n Go NFC）。
- 离线优先无服务器架构，本地 JSON 与 SQLite 双层持久化支持。
- 基础 GitHub Actions CI 跨平台编译流程。
