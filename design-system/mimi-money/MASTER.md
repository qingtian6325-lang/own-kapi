# Mimi Money — Design System Master

Source of truth for **咪咪记账** iOS UI. Extends Apple HIG; does **not** replace Mimi brand with generic dark/purple fintech palettes.

## Brand anchors (keep)

| Role | Light | Notes |
|------|-------|--------|
| Background | `#F5F6FA` | Soft grey, not pure white |
| Card | `#FFFFFF` | Adaptive dark: `#1A1F2B` |
| Expense | `#2D5AF0` | Primary action / expense |
| Income | `#E8832E` | Income accent |
| Balance | `#36B37E` | Positive / success |
| Danger | `#EF4444` | Destructive |

All surfaces go through `MimiTheme` adaptive tokens (`Color(lightHex:darkHex:)`). Sticker glyph hexes stay fixed.

## Interaction (Apple HIG)

- Touch targets ≥ **44×44 pt** via `mimiMinTouchTarget()` / `MimiHIG.minTouch`
- Press feedback via `mimiPressable()` (not bare `.buttonStyle(.plain)`)
- Icon-only controls need `.accessibilityLabel`
- Swipe/drag never the sole path for critical actions (also button / toolbar)
- Honor `accessibilityReduceMotion` via `MimiMotion.*(reduceMotion:)`
- Typography: `.mimiFont` → **SF Pro Rounded** + Dynamic Type (soft/friendly; no Inter/Roboto)
- Amounts: `.mimiAmountFit()` / `minimumScaleFactor` so values don’t clip

## Motion

Use `MimiMotion` only: `page`, `sheet`, `drawer`, `quick`, `interactive`, transitions.
Handoffs (close A → open B) use `MimiMotion.handoffDelay(_:reduceMotion:)`.
No ad-hoc springs / `easeInOut` on chrome; honor Reduce Motion via `*(reduceMotion:)`.

## AI composer

1. Home / attach → **compact** bottom chrome + suggestion bubbles  
2. Manual → AI → **true full page** immediately  
3. Explicit **展开** / swipe-up / send → **true full page**  
4. Full page: **关闭** button + swipe-down + header X  
5. Mode switch chips share `BookkeepingModeSwitchButton` (`⇌` + label)

## Anti-patterns

- One-off `Color(hex:)` in Views (extend `MimiTheme` instead)
- Emoji as navigation / empty-state / control icons (SF Symbols or `MimiStickerIconView`)
- Glassmorphism / OLED-neon / purple AI dashboards
- Nested gestures that fight scroll or edge-swipe back

## Stack

SwiftUI iOS 17+, `NavigationStack` / system sheets preferred; gold layouts may stay custom but must feel native.
