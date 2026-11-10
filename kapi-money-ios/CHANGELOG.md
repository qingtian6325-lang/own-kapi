# Changelog - 咔皮记账 (Kapi Money iOS)

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
