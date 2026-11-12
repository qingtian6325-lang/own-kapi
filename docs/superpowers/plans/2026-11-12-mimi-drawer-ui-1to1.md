# Drawer Menu UI 1:1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the left side drawer (`SideDrawerMenuView`) visually and interactionally match gold reference D0, via in-place polish of the existing SwiftUI view + drawer tokens in `MimiTheme`.

**Architecture:** Keep `DrawerDestination` routing and `MimiRootContainerView.handleDrawerSelection` behavior. Concentrate changes in `MimiTheme` (drawer tokens), `SideDrawerMenuView` (layout + interactions + line icons). No new screens; survey row is close-only placeholder; no store/AI changes.

**Tech Stack:** Swift 6, SwiftUI (iOS 16+), existing `MimiMoneyCore`, Node verify script `mimi-money-ios/scripts/verify-swift-project.mjs`.

## Global Constraints

- Scope: **left drawer panel only** (spec `docs/superpowers/specs/2026-11-12-mimi-drawer-ui-1to1-design.md`).
- Icons: **SF Symbol / Canvas line-icon approximation** — do not crop PNGs from screenshots.
- Hard visual bar: hierarchy, copy, **3-column** grids, Pro/VIP, bottom list rows vs gold **D0**. Soft bar: icon likeness; avatar placeholder OK.
- Gold D0 file: `docs/reference-screenshots/WhatsApp_Image_2026-11-12_at_10.21.50_AM-07047f49-69cd-4d20-abfd-c7242565d676.jpg`
- Work on branch `cursor/ui-reference-screenshots`.
- Do **not** redesign stats / calendar page / assets / budgets / categories / settings body UI.
- Host may lack Swift: use `node mimi-money-ios/scripts/verify-swift-project.mjs --all` locally.

## File map

| File | Responsibility |
|---|---|
| `mimi-money-ios/Sources/MimiMoneyCore/Theme/MimiTheme.swift` | Drawer width / Pro·VIP colors / grid icon size tokens |
| `mimi-money-ios/Sources/MimiMoneyCore/Views/SideDrawerMenuView.swift` | Full drawer layout + interactions + line icons |
| `mimi-money-ios/scripts/verify-swift-project.mjs` | Assert new drawer copy/tokens (`更多功能`, `Pro`, `VIP`, `填问卷参与共建`, drawer tokens) |

---

### Task 1: Drawer layout tokens in `MimiTheme` + verify asserts

**Files:**
- Modify: `mimi-money-ios/Sources/MimiMoneyCore/Theme/MimiTheme.swift`
- Modify: `mimi-money-ios/scripts/verify-swift-project.mjs`
- Test: run verify script

**Interfaces:**
- Consumes: existing `MimiTheme` colors / `cardCornerRadius`
- Produces: `drawerWidthFraction`, `drawerGridIconSize`, `proBadgeBlueHex` / `vipGoldHex` (and Color accessors), used by Task 2–3

- [ ] **Step 1: Add failing verify asserts for drawer tokens + labels**

In `verify-swift-project.mjs` `verifyTask1` (or drawer section in `verifyTask5`), add theme asserts:

```javascript
assertContains(theme, 'drawerWidthFraction', 'MimiTheme.swift');
assertContains(theme, 'drawerGridIconSize', 'MimiTheme.swift');
assertContains(theme, 'proBadgeBlueHex', 'MimiTheme.swift');
assertContains(theme, 'vipGoldHex', 'MimiTheme.swift');
```

In the drawer label loop inside `verifyTask5`, ensure these strings are asserted on `SideDrawerMenuView.swift`:

```javascript
'更多功能',
'快捷记账',
'设置',
'填问卷参与共建',
'Pro',
'VIP',
'今',
```

(Keep existing destination labels. Do **not** require the drawer file to contain a card-title link string `全部记录` — calendar view still owns that copy.)

- [ ] **Step 2: Run verify to confirm failure**

Run: `node mimi-money-ios/scripts/verify-swift-project.mjs --all`  
Expected: FAIL mentioning missing `drawerWidthFraction` (or first missing token/label).

- [ ] **Step 3: Implement tokens in `MimiTheme`**

Append after home layout tokens:

```swift
// MARK: - Drawer layout tokens (gold screenshot D0)
public static let drawerWidthFraction: CGFloat = 0.82
public static let drawerContentPadding: CGFloat = 18
public static let drawerSectionSpacing: CGFloat = 18
public static let drawerGridIconSize: CGFloat = 48
public static let drawerGridIconCorner: CGFloat = 14
public static let drawerAvatarSize: CGFloat = 48
public static let drawerHeatmapCellHeight: CGFloat = 22
public static let proBadgeBlueHex: UInt32 = 0x2D5AF0
public static let vipGoldHex: UInt32 = 0xE6A23C
public static var proBadgeBlue: Color { Color(hex: proBadgeBlueHex) }
public static var vipGold: Color { Color(hex: vipGoldHex) }
```

Tune numbers against D0 in later tasks if needed; **names must remain**.

- [ ] **Step 4: Re-run verify**

Run: `node mimi-money-ios/scripts/verify-swift-project.mjs --all`  
Expected: still FAIL on drawer labels missing in `SideDrawerMenuView` (`填问卷参与共建` / `Pro` / `VIP` / `今`) until Task 2–3 — that is OK if Task 1 only adds theme tokens. Prefer: add theme asserts in Task 1 and only run a focused check, OR temporarily expect full `--all` fail until Task 3. **Commit Task 1 when theme asserts pass** (label asserts can be added in Step 1 of Task 3 if you want Task 1 green alone).

**Recommended split:** Task 1 only adds **theme** asserts + tokens; Task 3 Step 1 adds **label** asserts then implements UI so verify goes green once.

- [ ] **Step 5: Commit**

```bash
git add mimi-money-ios/Sources/MimiMoneyCore/Theme/MimiTheme.swift mimi-money-ios/scripts/verify-swift-project.mjs
git commit -m "feat(ui): add drawer layout tokens to MimiTheme for 1:1 polish"
```

---

### Task 2: Profile row + month heatmap card vs D0

**Files:**
- Modify: `mimi-money-ios/Sources/MimiMoneyCore/Views/SideDrawerMenuView.swift` (profile + heatmap sections)
- Test: verify still builds structurally (braces); full label pass in Task 3

**Interfaces:**
- Consumes: `MimiTheme.drawerWidthFraction`, `drawerAvatarSize`, `proBadgeBlue`, `vipGold`, `cardCornerRadius`, existing `monthDayCells` / store counts
- Produces: profile → `.settings`; whole heatmap card → `.calendar`; today cell shows `今`

- [ ] **Step 1: Replace profile header**

Remove the trailing gear `Button`. Use:

```swift
Button {
    onSelectDestination(.settings)
} label: {
    HStack(spacing: 12) {
        ZStack {
            Circle()
                .fill(Color(hex: 0xFFE8CC))
                .frame(width: MimiTheme.drawerAvatarSize, height: MimiTheme.drawerAvatarSize)
            Text("🐱")
                .font(.system(size: 26))
        }

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(store.userNickname)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(MimiTheme.textPrimary)
                Text("Pro")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(MimiTheme.proBadgeBlue))
            }
            HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10))
                    .foregroundColor(MimiTheme.vipGold)
                Text("VIP")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(MimiTheme.vipGold)
            }
        }

        Spacer()

        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(MimiTheme.textMuted)
    }
}
.buttonStyle(.plain)
.padding(.top, 12)
```

Keep subtitle optional: D0 has Pro/VIP without「已开启智能记账守护」— **drop that subtitle** to match D0.

- [ ] **Step 2: Restyle heatmap card**

Inside the existing calendar `Button` label:

1. Title row: only `November 2026` (or dynamic month string) — **remove** the trailing `全部记录` + chevron `HStack`.
2. Remove weekday header row (`一`…`日`).
3. Remove the `收入多` / `支出多` legend `HStack`.
4. Keep `LazyVGrid` 7 columns with leading empty pads for month start; cell height `MimiTheme.drawerHeatmapCellHeight`.
5. Today cell: fill light blue + `Text("今")` instead of day number when `cell.isToday`.
6. Keep bottom `记录天数` / `总记录` / `连续天数` row.
7. Whole card still `onSelectDestination(.calendar)`.

Today cell sketch:

```swift
ZStack {
    RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(cell.isToday ? Color(hex: 0xDDE9FD) : heatmapMiniColor(for: cell))
        .frame(height: MimiTheme.drawerHeatmapCellHeight)
    if cell.isToday {
        Text("今")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(MimiTheme.expenseBlue)
    } else if cell.day == 15 || cell.day == 30 || cell.expense > 0 || cell.income > 0 {
        // Prefer sparse labels like D0: show day number lightly; OK to show all day numbers at 9pt muted if sparse logic is awkward
        Text("\(cell.day)")
            .font(.system(size: 9, weight: .regular, design: .rounded))
            .foregroundColor(MimiTheme.textMuted)
    }
}
```

Showing all day numbers at muted size is acceptable if sparse-only is too fiddly — hard bar is **今** + no weekday header + no legend + no 全部记录 link.

- [ ] **Step 3: Panel chrome**

Wrap `ScrollView` width:

```swift
.frame(width: UIScreen.main.bounds.width * MimiTheme.drawerWidthFraction)
.background(MimiTheme.background.ignoresSafeArea())
```

If `UIScreen` is undesirable in SwiftUI previews, use `GeometryReader` at the `ZStack` level and pass width — either approach OK as long as fraction token is used.

Keep dimmed scrim `Color.black.opacity(0.32)` + tap `onClose`.

- [ ] **Step 4: Commit**

```bash
git add mimi-money-ios/Sources/MimiMoneyCore/Views/SideDrawerMenuView.swift
git commit -m "feat(ui): align drawer profile and heatmap card to gold D0"
```

---

### Task 3: 3-column feature grids + bottom list + line icons + verify green

**Files:**
- Modify: `mimi-money-ios/Sources/MimiMoneyCore/Views/SideDrawerMenuView.swift`
- Modify: `mimi-money-ios/scripts/verify-swift-project.mjs` (drawer label asserts)
- Test: `node mimi-money-ios/scripts/verify-swift-project.mjs --all`

**Interfaces:**
- Consumes: `drawerGridIconSize`, `drawerGridIconCorner`, destinations unchanged
- Produces: 3-column「更多功能」+「快捷记账」; footer「设置」「填问卷参与共建」; survey closes drawer only

- [ ] **Step 1: Extend verify drawer labels**

Add to the drawer `for` loop in `verifyTask5`:

```javascript
'更多功能',
'快捷记账',
'设置',
'填问卷参与共建',
'Pro',
'VIP',
'今',
```

Run verify — expect FAIL until UI updated.

- [ ] **Step 2: Change grids to 3 columns + SF Symbol icons**

Replace both `LazyVGrid` column definitions with **3** `GridItem(.flexible())` (not 4).

Replace `drawerGridButton` to take `systemName: String` instead of emoji:

```swift
private func drawerGridButton(systemName: String, title: String, dest: DrawerDestination) -> some View {
    Button {
        onSelectDestination(dest)
    } label: {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: MimiTheme.drawerGridIconCorner, style: .continuous)
                    .fill(Color(hex: 0xF5F6FA))
                    .frame(width: MimiTheme.drawerGridIconSize, height: MimiTheme.drawerGridIconSize)
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(MimiTheme.textPrimary)
            }
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(MimiTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
    .buttonStyle(.plain)
}
```

Suggested symbol mapping (approximate D0 line icons):

| Title | systemName |
|---|---|
| 图表统计 | `chart.pie` |
| 资产管理 | `creditcard` |
| 账本管理 | `book.closed` |
| 预算管理 | `pencil.and.outline` |
| 小组件 | `square.grid.2x2` |
| 分类管理 | `square.grid.3x3` |
| 标签管理 | `bookmark` |
| 导入导出 | `square.and.arrow.up.on.square` |
| 自动记账 | `doc.text` |
| 定时记账 | `clock.arrow.2.circlepath` |

Keep section titles `更多功能` / `快捷记账` and white rounded card backgrounds using `MimiTheme.cardCornerRadius`.

- [ ] **Step 3: Add bottom list rows**

After the 快捷记账 card, add:

```swift
VStack(spacing: 0) {
    drawerListRow(systemName: "gearshape", title: "设置") {
        onSelectDestination(.settings)
    }
    Divider().padding(.leading, 44)
    drawerListRow(systemName: "newspaper", title: "填问卷参与共建") {
        onClose()
    }
}
.background(
    RoundedRectangle(cornerRadius: MimiTheme.cardCornerRadius, style: .continuous)
        .fill(Color.white)
)

// helper:
private func drawerListRow(systemName: String, title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 18))
                .foregroundColor(MimiTheme.textPrimary)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(MimiTheme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(MimiTheme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 4: Run full verify**

Run: `node mimi-money-ios/scripts/verify-swift-project.mjs --all`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mimi-money-ios/Sources/MimiMoneyCore/Views/SideDrawerMenuView.swift mimi-money-ios/scripts/verify-swift-project.mjs
git commit -m "feat(ui): align drawer grids and footer list to gold D0"
```

---

### Task 4: Smoke check + optional screenshot note

**Files:** none required (read-only check)

- [ ] **Step 1: Grep drawer for regressions**

Confirm `SideDrawerMenuView.swift` contains `Pro`, `VIP`, `今`, `填问卷参与共建`, three `GridItem` columns, and does **not** show a heatmap title-row `全部记录` link.

- [ ] **Step 2: Manual device note (if jinghao has phone build)**

Open drawer from home ☰; compare to D0: profile badges, heatmap「今」, 3-col grids, settings + survey rows. Destinations still open.

- [ ] **Step 3: Final commit only if stray fixes**

If Step 1–2 needed tiny token tweaks, commit:

```bash
git commit -m "fix(ui): drawer D0 spacing/token nits after smoke check"
```

Otherwise no empty commit.

---

## Spec coverage checklist

| Spec item | Task |
|---|---|
| D0 gold file named | Global + Tasks 2–3 |
| Profile Pro/VIP + `>` | Task 2 |
| Heatmap no weekday/legend/全部记录 link; 「今」; stats row | Task 2 |
| 3-col 更多功能 / 快捷记账 line icons | Task 3 |
| Bottom 设置 + 填问卷 (close only) | Task 3 |
| Theme tokens | Task 1 |
| verify asserts | Task 1 + 3 |
| No subpage redesign / no PNG crop | Global Constraints |

## Self-review

- No TBD placeholders in steps.
- `DrawerDestination` unchanged; survey uses `onClose` only.
- Token names consistent across tasks (`drawerWidthFraction`, etc.).
