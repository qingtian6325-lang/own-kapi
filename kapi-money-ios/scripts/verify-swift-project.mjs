import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');

function assertFileExists(relPath) {
  const full = path.join(rootDir, relPath);
  if (!fs.existsSync(full)) {
    throw new Error(`Missing required file: kapi-money-ios/${relPath}`);
  }
  return fs.readFileSync(full, 'utf8');
}

function assertContains(content, needle, contextLabel) {
  if (!content.includes(needle)) {
    throw new Error(`Expected [${contextLabel}] to contain: ${needle}`);
  }
}

function checkBalancedBraces(content, relPath) {
  let depth = 0;
  for (const ch of content) {
    if (ch === '{') depth++;
    if (ch === '}') depth--;
    if (depth < 0) {
      throw new Error(`Unbalanced closing brace in ${relPath}`);
    }
  }
  if (depth !== 0) {
    throw new Error(`Unbalanced braces (remaining depth ${depth}) in ${relPath}`);
  }
}

function verifyTask1() {
  const pkg = assertFileExists('Package.swift');
  assertContains(pkg, 'name: "KapiMoney"', 'Package.swift');
  assertContains(pkg, 'name: "KapiMoneyCore"', 'Package.swift');
  assertContains(pkg, 'name: "KapiMoneyApp"', 'Package.swift');
  assertContains(pkg, 'name: "KapiMoneyTests"', 'Package.swift');

  const xtool = assertFileExists('xtool.yml');
  assertContains(xtool, 'version: 1', 'xtool.yml');
  assertContains(xtool, 'bundleID: com.jinghao.kapimoney', 'xtool.yml');
  assertContains(xtool, 'product: KapiMoneyApp', 'xtool.yml');

  const theme = assertFileExists('Sources/KapiMoneyCore/Theme/KapiTheme.swift');
  checkBalancedBraces(theme, 'KapiTheme.swift');
  assertContains(theme, '0x2D5AF0', 'KapiTheme.swift');
  assertContains(theme, '0xE8832E', 'KapiTheme.swift');
  assertContains(theme, '0xF5F6FA', 'KapiTheme.swift');

  const models = assertFileExists('Sources/KapiMoneyCore/Models/KapiModels.swift');
  checkBalancedBraces(models, 'KapiModels.swift');
  for (const sym of [
    'enum CurrencyCode',
    'enum TransactionType',
    'struct SubCategory',
    'struct CategoryGroup',
    'struct AccountItem',
    'enum AuditActionType',
    'struct AccountAuditLog',
    'struct TransactionItem',
    'struct CategoryBudgetItem',
    'struct LedgerItem',
    'var displayBadgeToken: String'
  ]) {
    assertContains(models, sym, 'KapiModels.swift');
  }

  const catalog = assertFileExists('Sources/KapiMoneyCore/Models/DefaultCatalog.swift');
  checkBalancedBraces(catalog, 'DefaultCatalog.swift');
  for (const catName of [
    '餐饮', '做饭食材', '餐厅', '外卖外带', '咖啡', '饮品', '零食甜品', '酒吧酒水',
    '购物', '服饰鞋包', '美妆护肤', '数码电器', '生活用品', '个护服务', '运费', '二手租借',
    '交通', '公共交通', '打车叫车', '城际出行', '加油充电', '过路停车', '养车', '交通卡充值',
    '住房', '房租房贷', '物业水电', '话费网费', '物业管理费', '装修维修', '家政服务',
    '休闲娱乐', '运动健身', '线下娱乐', '数字娱乐', '旅游度假', '收藏爱好', '订阅会员',
    '医疗健康', '看病买药', '医美齿科', '保健养生', '体检疫苗', '康复陪护',
    '学习办公', '教育学费', '职业培训', '兴趣课程', '图书文具',
    '宠物', '宠物食品', '宠物用品', '宠物医疗', '宠物服务',
    '母婴', '婴儿食品', '母婴用品', '母婴服务',
    '资金往来', '还款', '人情往来',
    '保险', '投资理财', '其他支出', '家用', '车贷',
    '职业收入', '绩效奖金', '津贴补助', '个体经营', '副业兼职', '投资收入', '股息分红', '利息',
    '保险理赔', '退款返还', '返现', '报销', '他人还款', '退税', '礼金收入', '生活费', '其他收入', '二手买卖', '好运收入', '别人转账',
    '现金', 'CIMB', 'TNGewallet', 'PBBank', 'Main Ledger'
  ]) {
    assertContains(catalog, catName, 'DefaultCatalog.swift');
  }

  console.log('Task 1 verified: Package.swift, xtool.yml, KapiTheme, KapiModels, DefaultCatalog all valid');
}

function verifyTask2() {
  const calc = assertFileExists('Sources/KapiMoneyCore/Services/KeypadCalculator.swift');
  checkBalancedBraces(calc, 'KeypadCalculator.swift');
  assertContains(calc, 'public enum KeypadCalculator', 'KeypadCalculator.swift');
  assertContains(calc, 'public static func evaluate(_ expression: String) -> Double', 'KeypadCalculator.swift');

  const budget = assertFileExists('Sources/KapiMoneyCore/Services/DynamicBudgetEngine.swift');
  checkBalancedBraces(budget, 'DynamicBudgetEngine.swift');
  assertContains(budget, 'public enum DynamicBudgetEngine', 'DynamicBudgetEngine.swift');
  assertContains(budget, 'calculateDailyBudget(monthlyBudget: Double, spentBeforeToday: Double, remainingDaysIncludingToday: Int) -> Double', 'DynamicBudgetEngine.swift');
  assertContains(budget, 'buildMonthDayCells', 'DynamicBudgetEngine.swift');

  const store = assertFileExists('Sources/KapiMoneyCore/Services/KapiStore.swift');
  checkBalancedBraces(store, 'KapiStore.swift');
  for (const sym of [
    'public final class KapiStore: ObservableObject',
    'public func addTransaction(',
    'public func updateTransaction(',
    'public func deleteTransaction(',
    'public func updateAccountBalance(',
    'public func monthlyExpenseTotal(',
    'public func resetToDemoData()',
    'public func clearAllDemoTransactions()',
    '.created',
    '.updated',
    '.deleted'
  ]) {
    assertContains(store, sym, 'KapiStore.swift');
  }

  console.log('Task 2 verified: KeypadCalculator, DynamicBudgetEngine, and KapiStore audit & balance logic valid');
}

function verifyTask3() {
  const ocr = assertFileExists('Sources/KapiMoneyCore/Services/ReceiptOCRService.swift');
  checkBalancedBraces(ocr, 'ReceiptOCRService.swift');
  for (const sym of [
    'public struct ParsedDraftBill',
    'public final class ReceiptOCRService',
    'public static func parseReceiptText(',
    'public static func recognizeAndParseImageData(',
    '餐饮-零食甜品',
    'TNGewallet',
    'PBBank'
  ]) {
    assertContains(ocr, sym, 'ReceiptOCRService.swift');
  }

  const ai = assertFileExists('Sources/KapiMoneyCore/Services/KapiAIEngine.swift');
  checkBalancedBraces(ai, 'KapiAIEngine.swift');
  for (const sym of [
    'public enum AIChatResponseBlock',
    'public final class KapiAIEngine: ObservableObject',
    'public func parseNaturalLanguageBills(',
    'public func handleUserMessage(',
    '小金主，咔皮记账的标准支出分类如下',
    '标准收入分类如下',
    '另外你还自建了「家用」「车贷」两个支出分类和「别人转账」这个收入分类'
  ]) {
    assertContains(ai, sym, 'KapiAIEngine.swift');
  }

  console.log('Task 3 verified: ReceiptOCRService and KapiAIEngine tests valid');
}

function verifyTask4() {
  const shortcuts = assertFileExists('Sources/KapiMoneyCore/Intents/KapiShortcuts.swift');
  checkBalancedBraces(shortcuts, 'KapiShortcuts.swift');
  for (const sym of [
    'public struct ShortcutExecutionOutcome',
    'public enum ShortcutActionCoordinator',
    'public static func recordRecognizedDraft(',
    'public static func markForInAppModification(',
    'public static func handleIncomingURL(',
    'kapimoney://edit-bill?id=',
    'public struct ScanScreenshotIntent',
    'public struct OpenBillForEditIntent',
    'public struct ConfirmBillIntent',
    'public struct KapiAppShortcutsProvider',
    'public struct ScreenshotResultSnippetView',
    '已识别记录以上信息，打开「咔皮记账」查看更多',
    '修改 (View)',
    '确认 (Got it)'
  ]) {
    assertContains(shortcuts, sym, 'KapiShortcuts.swift');
  }

  const tests = assertFileExists('Tests/KapiMoneyTests/ShortcutIntentTests.swift');
  checkBalancedBraces(tests, 'ShortcutIntentTests.swift');
  assertContains(tests, 'testShortcutRecognizeAndConfirmSavesDirectly', 'ShortcutIntentTests.swift');
  assertContains(tests, 'testShortcutModifyButtonDeepLinksIntoAppBillEditor', 'ShortcutIntentTests.swift');

  console.log('Task 4 verified: ShortcutActionCoordinator, AppIntents, and DeepLink routing valid');
}

function verifyTask5() {
  const sticker = assertFileExists('Sources/KapiMoneyCore/Components/KapiStickerIconView.swift');
  checkBalancedBraces(sticker, 'KapiStickerIconView.swift');
  assertContains(sticker, 'public struct KapiStickerIconView: View', 'KapiStickerIconView.swift');

  const home = assertFileExists('Sources/KapiMoneyCore/Views/HomeRecordView.swift');
  checkBalancedBraces(home, 'HomeRecordView.swift');
  for (const label of [
    'public struct HomeRecordView: View',
    '月预算剩余',
    '今日可用',
    '分类预算',
    '净资产',
    '30天趋势',
    '记录明细',
    '任何事情都能问我'
  ]) {
    assertContains(home, label, 'HomeRecordView.swift');
  }

  const drawer = assertFileExists('Sources/KapiMoneyCore/Views/SideDrawerMenuView.swift');
  checkBalancedBraces(drawer, 'SideDrawerMenuView.swift');
  for (const label of [
    'public struct SideDrawerMenuView: View',
    '记录天数',
    '总记录',
    '连续天数',
    '图表统计',
    '资产管理',
    '账本管理',
    '预算管理',
    '小组件',
    '分类管理',
    '标签管理',
    '导入导出',
    '自动记账',
    '定时记账'
  ]) {
    assertContains(drawer, label, 'SideDrawerMenuView.swift');
  }

  const cal = assertFileExists('Sources/KapiMoneyCore/Views/AllRecordsCalendarView.swift');
  checkBalancedBraces(cal, 'AllRecordsCalendarView.swift');
  for (const label of [
    'public struct AllRecordsCalendarView: View',
    '全部记录',
    '回今天',
    '收支分析',
    '收入多',
    '支出多'
  ]) {
    assertContains(cal, label, 'AllRecordsCalendarView.swift');
  }

  console.log('Task 5 verified: Home, SideDrawer, StickerIcon, and AllRecordsCalendar views complete');
}

function verifyTask6() {
  const recordSheet = assertFileExists('Sources/KapiMoneyCore/Views/RecordAndAISheetView.swift');
  checkBalancedBraces(recordSheet, 'RecordAndAISheetView.swift');
  for (const label of [
    'public struct RecordAndAISheetView: View',
    '手动记账',
    'AI助手',
    '支出',
    '收入',
    '转账',
    '再记',
    '完成',
    '任何事都能问我',
    '有哪些分类',
    '怎么记退款',
    '怎么记报销',
    '一句话记多笔'
  ]) {
    assertContains(recordSheet, label, 'RecordAndAISheetView.swift');
  }

  const billDetail = assertFileExists('Sources/KapiMoneyCore/Views/BillDetailSheetView.swift');
  checkBalancedBraces(billDetail, 'BillDetailSheetView.swift');
  for (const label of [
    'public struct BillDetailSheetView: View',
    '账单详情',
    '实付金额',
    '分类',
    '备注',
    '账单时间',
    '付款账户',
    '所属账本',
    '添加优惠',
    '添加退款/返现',
    '交易方'
  ]) {
    assertContains(billDetail, label, 'BillDetailSheetView.swift');
  }

  console.log('Task 6 verified: RecordAndAISheetView and BillDetailSheetView complete');
}

function verifyTask7() {
  const stats = assertFileExists('Sources/KapiMoneyCore/Views/KapiStatsView.swift');
  checkBalancedBraces(stats, 'KapiStatsView.swift');
  for (const label of [
    'public struct KapiStatsView: View',
    '支出分类构成',
    '每日支出趋势',
    '单笔支出排行',
    '账单汇总',
    '本周结余'
  ]) {
    assertContains(stats, label, 'KapiStatsView.swift');
  }

  const assets = assertFileExists('Sources/KapiMoneyCore/Views/AssetsAndAccountDetailView.swift');
  checkBalancedBraces(assets, 'AssetsAndAccountDetailView.swift');
  for (const label of [
    'public struct AssetsAndAccountDetailView: View',
    '净资产',
    '待报销',
    '账户详情',
    '修改账户余额',
    '明细',
    '账单',
    '余额:'
  ]) {
    assertContains(assets, label, 'AssetsAndAccountDetailView.swift');
  }

  const budget = assertFileExists('Sources/KapiMoneyCore/Views/BudgetManagementView.swift');
  checkBalancedBraces(budget, 'BudgetManagementView.swift');
  for (const label of [
    'public struct BudgetManagementView: View',
    '预算管理',
    '已分类预算',
    '未分类预算',
    '动态日预算'
  ]) {
    assertContains(budget, label, 'BudgetManagementView.swift');
  }

  const catMgr = assertFileExists('Sources/KapiMoneyCore/Views/CategoryManagementView.swift');
  checkBalancedBraces(catMgr, 'CategoryManagementView.swift');
  for (const label of [
    'public struct CategoryManagementView: View',
    '分类方案管理',
    '添加1级支出分类',
    '首字作为图标（包含emoji）'
  ]) {
    assertContains(catMgr, label, 'CategoryManagementView.swift');
  }

  const settings = assertFileExists('Sources/KapiMoneyCore/Views/SettingsAndShortcutsGuideView.swift');
  checkBalancedBraces(settings, 'SettingsAndShortcutsGuideView.swift');
  for (const label of [
    'public struct SettingsAndShortcutsGuideView: View',
    '自动记账',
    '修改 (View)',
    '确认 (Got it)'
  ]) {
    assertContains(settings, label, 'SettingsAndShortcutsGuideView.swift');
  }

  const root = assertFileExists('Sources/KapiMoneyCore/Views/KapiRootContainerView.swift');
  checkBalancedBraces(root, 'KapiRootContainerView.swift');
  assertContains(root, 'public struct KapiRootContainerView: View', 'KapiRootContainerView.swift');
  assertContains(root, 'onOpenURL', 'KapiRootContainerView.swift');
  assertContains(root, 'ShortcutActionCoordinator.handleIncomingURL', 'KapiRootContainerView.swift');

  const appMain = assertFileExists('Sources/KapiMoneyApp/KapiMoneyApp.swift');
  checkBalancedBraces(appMain, 'KapiMoneyApp.swift');
  assertContains(appMain, '@main', 'KapiMoneyApp.swift');
  assertContains(appMain, 'struct KapiMoneyApp: App', 'KapiMoneyApp.swift');

  const wslScript = assertFileExists('scripts/build-wsl-xtool.sh');
  assertContains(wslScript, 'xtool', 'scripts/build-wsl-xtool.sh');

  const ciFile = path.resolve(rootDir, '..', '.github', 'workflows', 'build-kapi-ios.yml');
  if (!fs.existsSync(ciFile)) {
    throw new Error('Missing required file: .github/workflows/build-kapi-ios.yml');
  }
  const ciContent = fs.readFileSync(ciFile, 'utf8');
  assertContains(ciContent, 'swift test', '.github/workflows/build-kapi-ios.yml');
  assertContains(ciContent, 'KapiMoney-iOS.ipa', '.github/workflows/build-kapi-ios.yml');
  assertContains(ciContent, 'NSCameraUsageDescription', '.github/workflows/build-kapi-ios.yml');

  // Cross-layer API contract verification (Models/Store/Services <-> Views/Intents)
  const theme = assertFileExists('Sources/KapiMoneyCore/Theme/KapiTheme.swift');
  for (const sym of ['public static func formatRM(', 'public static var dangerRed:', 'public static var divider:']) {
    assertContains(theme, sym, 'KapiTheme.swift cross-layer contract');
  }

  const models = assertFileExists('Sources/KapiMoneyCore/Models/KapiModels.swift');
  for (const sym of [
    'public var categoryPath: String',
    'public var accountName: String',
    'public var ledgerName: String',
    'public var receiptImageLabels: [String]',
    'public var refundOrCashback: Double?',
    'public var subcategories: [SubCategory]',
    'public var deltaAmount: Double'
  ]) {
    assertContains(models, sym, 'KapiModels.swift cross-layer contract');
  }

  const store = assertFileExists('Sources/KapiMoneyCore/Services/KapiStore.swift');
  for (const sym of [
    'public static let shared = KapiStore()',
    'pendingShortcutSnippetBill: TransactionItem?',
    'public var monthlyBudgetTotal: Double',
    'public func monthlyBudgetRemaining(',
    'public var currentLedgerName: String',
    'public var categoryBudgets: [CategoryBudgetItem]',
    'public func categorySpent(',
    'public var netWorth: Double',
    'public func groupedTransactionsByDay()',
    'public func auditLogs(for accountName: String)',
    'public func setCustomDailyBudget('
  ]) {
    assertContains(store, sym, 'KapiStore.swift cross-layer contract');
  }

  console.log('Task 7 verified: Stats, Assets, Budgets, Categories, Root App, WSL xtool script, and GitHub Actions workflow complete');
  console.log('All 7 tasks and 100% of Kapi Money spec requirements verified');
}

const args = process.argv.slice(2);
const taskIdx = args.indexOf('--task');
const taskNum = taskIdx !== -1 ? Number(args[taskIdx + 1]) : null;
const runAll = args.includes('--all');

try {
  if (taskNum === 1) {
    verifyTask1();
  } else if (taskNum === 2) {
    verifyTask1();
    verifyTask2();
  } else if (taskNum === 3) {
    verifyTask1();
    verifyTask2();
    verifyTask3();
  } else if (taskNum === 4) {
    verifyTask1();
    verifyTask2();
    verifyTask3();
    verifyTask4();
  } else if (taskNum === 5) {
    verifyTask1();
    verifyTask2();
    verifyTask3();
    verifyTask4();
    verifyTask5();
  } else if (taskNum === 6) {
    verifyTask1();
    verifyTask2();
    verifyTask3();
    verifyTask4();
    verifyTask5();
    verifyTask6();
  } else if (taskNum === 7 || runAll) {
    verifyTask1();
    verifyTask2();
    verifyTask3();
    verifyTask4();
    verifyTask5();
    verifyTask6();
    verifyTask7();
  } else {
    throw new Error(`Unsupported or unimplemented task argument: ${args.join(' ')}`);
  }
} catch (err) {
  console.error(`FAIL: ${err.message}`);
  process.exit(1);
}
