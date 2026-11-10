const https = require('https');
const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN || '';

const releases = [
  {
    id: 439993559,
    tag: 'v1.0.4',
    title: '咔皮记账 iOS v1.0.4 - 修复负数透支显示 & 重构期初资金正逆双推',
    body: `## [v1.0.4] - 2026-11-10

### 🚀 重点修复与核心重构
- **修复负数透支显示为正数的重大 Bug**：修复了金额格式化函数中使用 \`abs(value)\` 导致负数（如 \`-RM700.00\`）被错误显示为正数 \`RM700.00\` 的问题。现在透支或负数金额严格显示负号（如 \`-RM700.00\`），并在首页卡片与资产明细中高亮醒目红字警示。
- **重构并理清【期初起始资金 (Initial Capital)】全生命周期**：
  - 每个资金账户底层独立引入 \`initialBalance\`（全部记账前的初始资金）与 \`balance\`（当前实际余额）。
  - **正推法**：输入记账前的起始资金，系统结合历史流水净变动，自动计算出当前真实余额。
  - **倒推法**：输入手机银行当前实际余额，系统自动逆向倒推出当年记账前的起始资金。
  - 在【资产管理】与【通用设置】中全面支持双模式校准，历史流水与当前身家严谨闭环。

### 📦 资产下载
- **KapiMoney-iOS.ipa**：App 安装包（建议使用 Sideloadly / AltStore 签名安装）
- **KapiScreenshotBookkeeping.shortcut**：快捷指令文件`
  },
  {
    id: 439981415,
    tag: 'v1.0.3',
    title: '咔皮记账 iOS v1.0.3 - 内置一键跳转添加快捷指令与离线集成',
    body: `## [v1.0.3] - 2026-11-10

### 🚀 新增功能
- **【自动记账】内置一键跳转添加快捷指令与离线集成**：
  - 在【自动记账】页面新增高亮按钮“⚡ 一键跳转导入「咔皮截屏自动记账」快捷指令”，点击直接唤起 iOS Safari / 快捷指令 App 进行一键安装。
  - 新增“打开「快捷指令」App”与“离线发送至快捷指令 (ShareLink)”双重通道，将 1007 字节的标准快捷指令文件永久内置打包于 App 内部，断网也能导入。
  - 新增“📸 无需快捷指令 · 一键读取剪贴板截图直接记账”快捷按钮，手机截图复制后在 App 内点按直接调用 Apple Vision OCR 记账。

### 📦 资产下载
- **KapiMoney-iOS.ipa**：App 安装包（建议使用 Sideloadly / AltStore 签名安装）
- **KapiScreenshotBookkeeping.shortcut**：快捷指令文件`
  },
  {
    id: 439978104,
    tag: 'v1.0.2',
    title: '咔皮记账 iOS v1.0.2 - 支持自定义账户起始金额与新增自定义账户',
    body: `## [v1.0.2] - 2026-11-10

### 🚀 新增功能
- **支持在【设置】与【资产】中自定义设置各账户起始金额（期初余额）**：
  - 【通用设置】新增“💳 账户起始金额与开局资产设置”配置卡，每个账户均可直接输入开局金额并实时保存。
  - 【资产管理】新增“添加自定义资产账户”功能，支持创建 Maybank、GrabPay、加密钱包、备用金等自定义资金账户，并设定其初始开局余额。
  - \`KapiStore\` 新增 \`deleteAccount\` 与账户审计全生命周期联动，日常记账、转账与改额实时平账。

### 📦 资产下载
- **KapiMoney-iOS.ipa**：App 安装包（建议使用 Sideloadly / AltStore 签名安装）
- **KapiScreenshotBookkeeping.shortcut**：快捷指令文件`
  },
  {
    id: 439968724,
    tag: 'v1.0.1',
    title: '咔皮记账 iOS v1.0.1 - 100% 完整交互功能上线与纯净空白初始状态',
    body: `## [v1.0.1] - 2026-11-10

### 🚀 重点功能与修复
- **100% 完整交互功能上线**：重构并连接了全部 11 个模块与抽屉页面的底层业务逻辑，去除所有死按钮与空状态提示。
- **纯净空白初始状态 (Clean Empty State)**：新安装 App 打开后，总资产 \`RM0.00\`、净资产 \`RM0.00\`、记录天数 \`0 天\`、交易记录 \`0 笔\`，无任何伪造或默认演示数据。
- **真实 iOS 快捷指令截屏记账**：快捷指令 \`KapiScreenshotBookkeeping.shortcut\` 配合 \`ReceiptOCRService\`（Apple Vision OCR），支持自动截屏识别金额与商户，无截图时自动降级读取系统剪贴板。
- **编译修复**：修复 \`TransactionItem\` 便利构造器缺少 \`tags\` 参数的问题，确保 \`RecordAndAISheetView\` 自定义标签保存正常编译与运行。
- **版本控制与 CI 自动化**：新增 \`VERSION\` 集中版本管理，GitHub Actions 自动化构建产物并同时同步发布到 \`v1.0.1\` 和 \`v1.0.0\` Release。
- **账本管理与双表 CSV 导入**：支持账本切换与预算调整；完整支持包含 151 笔历史账单（140 笔收支 + 11 笔转账）的咔皮双表头 CSV 导入。

### 📦 资产下载
- **KapiMoney-iOS.ipa**：App 安装包（建议使用 Sideloadly / AltStore 签名安装）
- **KapiScreenshotBookkeeping.shortcut**：快捷指令文件`
  },
  {
    id: 439896110,
    tag: 'v1.0.0',
    title: '咔皮记账 iOS v1.0.0 - 初始基础框架发布',
    body: `## [v1.0.0] - 2026-11-10

### 🚀 初始版本发布 (Initial Release)
- 1:1 原生 SwiftUI 咔皮记账界面设计体系（KapiTheme、卡片设计、猫咪吉祥物插画、自研数字键盘）。
- 资产账户体系（Cash, Maybank, TNG eWallet, Touch 'n Go NFC）。
- 离线优先无服务器架构，本地 JSON 与 SQLite 双层持久化支持。
- 基础 GitHub Actions CI 跨平台编译流程。

### 📦 资产下载
- **KapiMoney-iOS.ipa**：App 初始安装包
- **KapiScreenshotBookkeeping.shortcut**：快捷指令初始模板`
  }
];

function updateRelease(rel) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      name: rel.title,
      body: rel.body
    });
    const req = https.request({
      hostname: 'api.github.com',
      path: `/repos/qingtian6325-lang/own-kapi/releases/${rel.id}`,
      method: 'PATCH',
      headers: {
        'User-Agent': 'Node',
        'Authorization': 'token ' + token,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      }
    }, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          console.log(`Successfully updated ${rel.tag} (${rel.id})`);
          resolve();
        } else {
          console.error(`Failed to update ${rel.tag}: ${res.statusCode} - ${d}`);
          reject(new Error(d));
        }
      });
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

(async () => {
  for (const rel of releases) {
    await updateRelease(rel);
  }
  console.log('All releases successfully updated with unique changelogs!');
})();
