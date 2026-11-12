# Home Record UI 1:1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the home「记录」screen + bottom ask bar visually and interactionally match gold reference screenshot A (with B/D for ask-expand and swipe-delete), via in-place polish of existing SwiftUI views.

**Architecture:** Keep logic on `MimiStore` / `DynamicBudgetEngine`. Concentrate changes in `MimiTheme` (tokens), `HomeRecordView` (layout + interactions), `AIAttachmentPanelView` (expand tiles), and `MimiStickerIconView` (Canvas/emoji sticker style for icons that appear on home). No new screens; no AI/business logic changes.

**Tech Stack:** Swift 6, SwiftUI (iOS 16+), existing `MimiMoneyCore`, Node verify script `mimi-money-ios/scripts/verify-swift-project.mjs`, XCTest where host CI can run.

## Global Constraints

- Scope: **home「记录」+ 问我栏 only** (spec `docs/superpowers/specs/2026-11-12-mimi-home-ui-1to1-design.md`).
- Icons: **Canvas / emoji sticker approximation** — do not crop PNGs from screenshots.
- Hard visual bar: layout hierarchy, colors, spacing, copy placement vs gold **A**. Soft bar: sticker likeness.
- Gold A file: `docs/reference-screenshots/WhatsApp_Image_2026-11-12_at_10.22.05_AM__1_-998cbadc-abe7-4a48-bc05-513db3f4e0d2.jpg`
- B ask-expand: `…10.22.05_AM__2_-3382c668-….jpg` · D swipe-delete: `…10.22.06_AM__2_-a732a7ae-….jpg`
- Work on branch `cursor/ui-reference-screenshots` (or a child `cursor/home-ui-1to1` if preferred).
- Do **not** redesign drawer / stats / calendar / assets / category admin / record sheet / bill detail.
- Host may lack Swift: use `node mimi-money-ios/scripts/verify-swift-project.mjs --all` locally; rely on GitHub Actions for `swift test` after push if requested.

## File map

| File | Responsibility |
|---|---|
| `mimi-money-ios/Sources/MimiMoneyCore/Theme/MimiTheme.swift` | Home spacing / radius / shadow / typography tokens |
| `mimi-money-ios/Sources/MimiMoneyCore/Views/HomeRecordView.swift` | Home layout + interactions (swipe delete toast, ask bar) |
| `mimi-money-ios/Sources/MimiMoneyCore/Views/AIAttachmentPanelView.swift` | Album / camera / import-export tiles vs B |
| `mimi-money-ios/Sources/MimiMoneyCore/Components/MimiStickerIconView.swift` | Home-facing sticker look + optional mascot helper |
| `mimi-money-ios/scripts/verify-swift-project.mjs` | Structural asserts for new tokens +「删除成功」 |
| `mimi-money-ios/Tests/MimiMoneyTests/StoreAndBudgetTests.swift` | Extend only if delete/format regressions need a home-facing case |

---

### Task 1: Home layout tokens in `MimiTheme` + verify asserts

**Files:**
- Modify: `mimi-money-ios/Sources/MimiMoneyCore/Theme/MimiTheme.swift`
- Modify: `mimi-money-ios/scripts/verify-swift-project.mjs` (Task 1 / Task 5 sections)
- Test: run verify script

**Interfaces:**
- Consumes: existing `MimiTheme` color hexes (`backgroundHex`, `expenseBlueHex`, …)
- Produces: static layout tokens used by later tasks, e.g. `cardCornerRadius`, `homeHorizontalPadding`, `homeCardSpacing`, `askBarHeight`, `transactionRowIconSize`, `homeCardShadow`

- [ ] **Step 1: Add failing verify asserts for new token names**

In `verify-swift-project.mjs` inside `verifyTask1` (near existing `0x2D5AF0` checks), add:

```javascript
assertContains(theme, 'homeHorizontalPadding', 'MimiTheme.swift');
assertContains(theme, 'cardCornerRadius', 'MimiTheme.swift');
assertContains(theme, 'askBarHeight', 'MimiTheme.swift');
assertContains(theme, 'homeCardShadow', 'MimiTheme.swift');
```

- [ ] **Step 2: Run verify to confirm failure**

Run: `node mimi-money-ios/scripts/verify-swift-project.mjs --all`  
Expected: FAIL mentioning missing `homeHorizontalPadding` (or first missing token).

- [ ] **Step 3: Implement tokens**

Append to `MimiTheme` (keep existing colors; add layout section):

```swift
// MARK: - Home layout tokens (gold screenshot A)
public static let homeHorizontalPadding: CGFloat = 16
public static let homeCardSpacing: CGFloat = 14
public static let cardCornerRadius: CGFloat = 18
public static let askBarHeight: CGFloat = 50
public static let askBarCornerRadius: CGFloat = 25
public static let transactionRowIconSize: CGFloat = 38
public static let progressBarHeight: CGFloat = 18
public static let dailyRingSize: CGFloat = 72

public static var homeCardShadow: Color { Color.black.opacity(0.06) }
public static let homeCardShadowRadius: CGFloat = 10
public static let homeCardShadowY: CGFloat = 3
```

Tune numeric values while implementing Task 2–4 against screenshot A (adjust in later tasks if needed; names must remain).

- [ ] **Step 4: Re-run verify**

Run: `node mimi-money-ios/scripts/verify-swift-project.mjs --all`  
Expected: PASS (or only fail on unrelated pre-existing issues — fix token asserts first).

- [ ] **Step 5: Commit**

```bash
git add mimi-money-ios/Sources/MimiMoneyCore/Theme/MimiTheme.swift mimi-money-ios/scripts/verify-swift-project.mjs
git commit -m "feat(ui): add home layout tokens to MimiTheme for 1:1 polish"
```

---

### Task 2: Top bar + monthly budget card + net worth vs gold A

**Files:**
- Modify: `mimi-money-ios/Sources/MimiMoneyCore/Views/HomeRecordView.swift` (sections `topNavigationBar`, `monthlyBudgetCard`, `netWorthSummaryCard`, `body` paddings)
- Reference: gold A screenshot path in spec §2

**Interfaces:**
- Consumes: `MimiTheme.homeHorizontalPadding`, `homeCardSpacing`, `cardCornerRadius`, `progressBarHeight`, `dailyRingSize`, `homeCardShadow*`
- Produces: visually aligned header + budget + net-worth blocks; existing callbacks unchanged (`onOpenDrawer`, `onSwitchToStats`, `onOpenSearchOrCalendar`, `onOpenBudgetManager`, `onOpenAssetsManager`)

- [ ] **Step 1: Wire body paddings to tokens**

In `body`, replace magic `16` / `14` / `110` with theme tokens where applicable:

```swift
VStack(spacing: 0) {
    topNavigationBar
        .padding(.horizontal, MimiTheme.homeHorizontalPadding)
        // ...
    ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: MimiTheme.homeCardSpacing) {
            monthlyBudgetCard
            netWorthSummaryCard
            transactionFeedSection
        }
        .padding(.horizontal, MimiTheme.homeHorizontalPadding)
        .padding(.bottom, 110)
    }
}
```

- [ ] **Step 2: Align top bar to A**

Gold A shows: hamburger · 「记录」▾ · search circle · 「Main …」capsule.  
If current UI still shows a month capsule between title and search that A does **not** show as a separate blue-tinted chip in that position, match A: keep month access via search/calendar affordance already wired to `onOpenSearchOrCalendar`, and style title/search/ledger like A (white capsules, 22pt bold「记录」).

Keep `Menu` for 记录 → 统计. Keep ledger sheet.

- [ ] **Step 3: Align monthly budget card to A**

Checklist against A:
- Label「月预算剩余」+ eye toggle
- Large remaining amount + chevron → `onOpenBudgetManager`
- Capsule progress with percent badge (e.g. 40%),「已用」+ total budget
- Right:「今日可用」ring with value
- Row「分类预算 共N项」+「展开」; expanded list uses existing `isCategoryBudgetExpanded`
- Card fill white, corner `MimiTheme.cardCornerRadius`, subtle shadow via `homeCardShadow`

Replace hardcoded corner radii / progress height with tokens (`progressBarHeight`, `dailyRingSize`).

- [ ] **Step 4: Align net worth row to A**

- 「净资产」+ amount (respect `isAmountsHidden`)
- 「30天趋势」sparkline
- Tap / chevron toggles `isNetWorthExpanded`; expand/collapse animation
- Optional navigate `onOpenAssetsManager` without breaking collapse control (keep current pattern if both exist)

- [ ] **Step 5: Structural smoke**

Run: `node mimi-money-ios/scripts/verify-swift-project.mjs --all`  
Expected: PASS. Manually compare to A (or note deltas for next task).

- [ ] **Step 6: Commit**

```bash
git add mimi-money-ios/Sources/MimiMoneyCore/Views/HomeRecordView.swift
git commit -m "feat(ui): polish home top bar, budget card, and net worth to gold A"
```

---

### Task 3: Transaction feed polish + swipe delete +「删除成功」toast

**Files:**
- Modify: `mimi-money-ios/Sources/MimiMoneyCore/Views/HomeRecordView.swift` (`transactionFeedSection`, `dayTransactionGroupCard`)
- Modify: `mimi-money-ios/scripts/verify-swift-project.mjs` (assert `删除成功` in HomeRecordView)
- Optional test: `mimi-money-ios/Tests/MimiMoneyTests/StoreAndBudgetTests.swift` (delete already covered — only add if home-specific helper needs it)

**Interfaces:**
- Consumes: `store.deleteTransaction(id:)`, `onSelectTransaction`, `MimiStickerIconView`, `MimiTheme.transactionRowIconSize`
- Produces: feed matching C/A row layout; swipe reveals red circular trash; toast「删除成功」like D

- [ ] **Step 1: Add verify assert for toast copy**

In `verifyTask5` home label loop, add `'删除成功'`:

```javascript
for (const label of [
  'public struct HomeRecordView: View',
  '月预算剩余',
  '今日可用',
  '分类预算',
  '净资产',
  '30天趋势',
  '记录明细',
  '任何事情都能问我',
  '删除成功'
]) {
  assertContains(home, label, 'HomeRecordView.swift');
}
```

- [ ] **Step 2: Run verify — expect FAIL**

Run: `node mimi-money-ios/scripts/verify-swift-project.mjs --all`  
Expected: FAIL on `删除成功`.

- [ ] **Step 3: Add toast state + swipeActions**

Add state near other `@State`:

```swift
@State private var showDeleteToast: Bool = false
```

On each transaction row (inside `dayTransactionGroupCard`), after `.buttonStyle(.plain)`:

```swift
.swipeActions(edge: .trailing, allowsFullSwipe: true) {
    Button(role: .destructive) {
        store.deleteTransaction(id: item.id)
        withAnimation(.easeOut(duration: 0.2)) { showDeleteToast = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeIn(duration: 0.2)) { showDeleteToast = false }
        }
    } label: {
        Image(systemName: "trash.fill")
    }
    .tint(MimiTheme.dangerRed)
}
```

Overlay toast in `body` `ZStack` (center), matching D:

```swift
if showDeleteToast {
    Text("删除成功")
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.black.opacity(0.72)))
        .transition(.opacity)
        .zIndex(20)
}
```

- [ ] **Step 4: Polish row layout vs A/C**

- Title: category (or note-first if A shows note as primary — match A: category bold, note secondary)
- Time `HH:mm` + note line as in A (`16:37 | YING LAI…`)
- Account capsule on the right or under meta — match A column structure
- Expense amount blue `-RM…`, income orange `+RM…`
- Icon size `MimiTheme.transactionRowIconSize`
- Day header `M月D日 (周X)` + `支 … | 收 …`

- [ ] **Step 5: Re-run verify**

Run: `node mimi-money-ios/scripts/verify-swift-project.mjs --all`  
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mimi-money-ios/Sources/MimiMoneyCore/Views/HomeRecordView.swift mimi-money-ios/scripts/verify-swift-project.mjs
git commit -m "feat(ui): home feed polish with swipe-delete and delete toast"
```

---

### Task 4: Ask bar + attachment panel vs A/B

**Files:**
- Modify: `mimi-money-ios/Sources/MimiMoneyCore/Views/HomeRecordView.swift` (`floatingBottomBar`)
- Modify: `mimi-money-ios/Sources/MimiMoneyCore/Views/AIAttachmentPanelView.swift`
- Optionally add mascot view in `MimiStickerIconView.swift` or small helper in same Components folder

**Interfaces:**
- Consumes: `onOpenRecordSheet(true)`, `onPickFromAlbum`, `onTakePhoto`, `onOpenImportExport`, `MimiTheme.askBarHeight`
- Produces: collapsed bar matching A; expanded panel matching B

- [ ] **Step 1: Replace 🐱 emoji with Canvas/mascot sticker**

Prefer a dedicated small view (can live at bottom of `MimiStickerIconView.swift`):

```swift
public struct MimiAskMascotView: View {
    public var size: CGFloat = 28
    public var body: some View {
        // Orange/brown cat-capybara face: white circle + Canvas/emoji approximate
        ZStack {
            Circle().fill(Color.white)
            Text("🐱").font(.system(size: size * 0.85))
        }
        .frame(width: size, height: size)
    }
}
```

Use in ask bar leading slot instead of raw `Text("🐱")`.

- [ ] **Step 2: Match ask bar chrome to A**

- White capsule, height `askBarHeight`, horizontal padding, soft shadow
- Leading: mascot +「任何事情都能问我」→ `onOpenRecordSheet(true)`
- Trailing: blue circle `+` / `xmark` toggles `isAskPanelExpanded` with spring animation
- When expanded, show `AIAttachmentPanelView` above bar (already present)

- [ ] **Step 3: Restyle `AIAttachmentPanelView` to B**

B shows three large tiles with illustration-like icons + labels「相册」「拍照」「导入导出」. Update tile:

```swift
.frame(height: 88)
.background(
    RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Color(hex: 0xF5F6FA))
)
```

Use SF Symbols that read closer to B (photo stack, camera, doc/export). Keep callbacks identical.

- [ ] **Step 4: Verify + commit**

Run: `node mimi-money-ios/scripts/verify-swift-project.mjs --all`  
Expected: PASS.

```bash
git add mimi-money-ios/Sources/MimiMoneyCore/Views/HomeRecordView.swift \
  mimi-money-ios/Sources/MimiMoneyCore/Views/AIAttachmentPanelView.swift \
  mimi-money-ios/Sources/MimiMoneyCore/Components/MimiStickerIconView.swift
git commit -m "feat(ui): align ask bar and attachment panel to gold A/B"
```

---

### Task 5: Upgrade home-facing stickers (Canvas/emoji map)

**Files:**
- Modify: `mimi-money-ios/Sources/MimiMoneyCore/Components/MimiStickerIconView.swift` (`stickerSpec(for:)`)
- Smoke via verify (sticker file brace check already exists)

**Interfaces:**
- Consumes: `iconName` strings from `DefaultCatalog` / transactions on home (e.g. restaurant, gas, investment)
- Produces: white circular sticker with soft border + emoji/Canvas closer to A/C

- [ ] **Step 1: Audit icons appearing on gold A feed**

From A: lightbulb-like row, 餐厅 noodles, 加油充电 pump, etc. Ensure `stickerSpec` maps those `iconName`s to distinct emoji + pastel backgrounds (not generic gray).

- [ ] **Step 2: Tighten sticker chrome**

Keep white outer circle, inner pastel disc, emoji ~58% of size, 1pt black 10% stroke — already close; adjust if A shows thicker sticker border or flatter shadow.

- [ ] **Step 3: Verify + commit**

Run: `node mimi-money-ios/scripts/verify-swift-project.mjs --all`  
Expected: PASS.

```bash
git add mimi-money-ios/Sources/MimiMoneyCore/Components/MimiStickerIconView.swift
git commit -m "feat(ui): refine home sticker specs to match gold A style"
```

---

### Task 6: Final acceptance gate

**Files:**
- Possibly touch: `CHANGELOG.md` / `mimi-money-ios/CHANGELOG.md` only if user asks for a release note (default: **skip version bump** per spec)
- Test: verify script; optional push for Actions

- [ ] **Step 1: Full structural verify**

Run: `node mimi-money-ios/scripts/verify-swift-project.mjs --all`  
Expected: `All 7 tasks and 100% of Mimi Money spec requirements verified`

- [ ] **Step 2: Manual checklist (device or screenshot compare)**

- [ ] Static home ≈ gold A (top, budget, net worth, feed, collapsed ask bar)
- [ ] Ask expand ≈ B
- [ ] Swipe delete + toast ≈ D
- [ ] Category budget expand / net worth collapse / eye hide still work
- [ ] Tapping ask opens AI sheet; `+` toggles panel; row tap opens detail

- [ ] **Step 3: Commit any leftover polish; do not push unless user asks**

```bash
git status -sb
# commit only if dirty
```

---

## Spec coverage self-check

| Spec requirement | Task |
|---|---|
| Home + ask bar only | All tasks; Global Constraints |
| Canvas stickers not PNG crop | Task 4–5 |
| Visual + interaction acceptance | Task 2–4, Task 6 |
| In-place polish approach | File map |
| Tokens strict from A | Task 1–2 |
| Gold A / B / D references | Global Constraints + Tasks 2–4 |
| Swipe delete + 删除成功 | Task 3 |
| Verify script asserts | Tasks 1, 3, 6 |
| No other pages / no AI logic | Global Constraints |

## Placeholder scan

No TBD / “implement later” steps; commands and code sketches are concrete. Numeric token values may be fine-tuned during Tasks 2–4 while keeping symbol names stable for verify.
