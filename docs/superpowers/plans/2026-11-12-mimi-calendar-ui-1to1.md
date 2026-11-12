# Calendar「全部记录」UI 1:1 Implementation Plan

> **For agentic workers:** Use executing-plans / SDD task-by-task. Checkboxes for tracking.

**Goal:** Align `AllRecordsCalendarView` to gold C0/C1/C2.

**Architecture:** In-place polish + calendar tokens in `MimiTheme`. Keep store APIs.

**Tech Stack:** SwiftUI, `verify-swift-project.mjs`

## Global Constraints

- Spec: `docs/superpowers/specs/2026-11-12-mimi-calendar-ui-1to1-design.md`
- Gold C0/C1/C2 as named in spec
- Week starts **Sunday** to match C0
- Branch: `cursor/ui-reference-screenshots`

## File map

| File | Change |
|---|---|
| `MimiTheme.swift` | calendar cell height / padding tokens |
| `AllRecordsCalendarView.swift` | layout + Sunday-first + filter summary + coin badge |
| `verify-swift-project.mjs` | assert 日均支出 / 支出分析 / Sunday week if needed |

### Task 1: Theme tokens + verify hooks

- [ ] Add `calendarDayCellHeight`, `calendarHorizontalPadding` to `MimiTheme`
- [ ] Assert tokens in verify Task 1
- [ ] Commit

### Task 2: Calendar chrome vs C0/C1/C2

- [ ] `firstWeekday = 1` (Sunday); weekday header `日一二三四五六`; fix `leadingBlankCount`
- [ ] Filter menu labels display as `收支` / `支出` / `收入`
- [ ] Summary bar switches for expense mode: 日均支出 + 支出分析
- [ ] Coin badge SF/`circle.fill` gold instead of loose emoji if needed; keep highest-day mark
- [ ] Ask bar copy stays `任何事都能问我`
- [ ] verify --all PASS
- [ ] Commit
