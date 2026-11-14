import SwiftUI

/// 自家风格日期/时间弹窗：白底圆角底栏 + 月历格子，替代系统 graphical DatePicker。
public struct MimiDatePickerSheet: View {
    public enum Mode {
        case date
        case dateAndTime
    }

    @Binding public var selection: Date
    public var title: String
    public var mode: Mode
    public var onDone: () -> Void

    @State private var visibleMonth: Date

    public init(
        selection: Binding<Date>,
        title: String = "选择日期",
        mode: Mode = .date,
        onDone: @escaping () -> Void
    ) {
        self._selection = selection
        self.title = title
        self.mode = mode
        self.onDone = onDone
        self._visibleMonth = State(initialValue: Self.startOfMonth(selection.wrappedValue))
    }

    private static let calendar = Calendar(identifier: .gregorian)
    private static let weekdayLabels = ["日", "一", "二", "三", "四", "五", "六"]

    public var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(MimiTheme.strokeSubtle)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 8)

            HStack {
                Text(title)
                    .mimiFont(17, weight: .bold)
                    .foregroundColor(MimiTheme.textPrimary)
                Spacer()
                Button(action: onDone) {
                    Text("完成")
                        .mimiFont(15, weight: .semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(MimiTheme.expenseBlue))
                }
                .mimiPressable()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            monthHeader
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            weekdayHeader
                .padding(.horizontal, 12)

            dayGrid
                .padding(.horizontal, 12)
                .padding(.top, 6)

            if mode == .dateAndTime {
                timeRow
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            }

            Text(summaryText)
                .mimiFont(13, weight: .medium)
                .foregroundColor(MimiTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 18)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(MimiTheme.cardBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .mimiFont(14, weight: .bold)
                    .foregroundColor(MimiTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(MimiTheme.fillSubtle))
            }
            .mimiPressable()

            Spacer()

            Text(monthTitle)
                .mimiFont(16, weight: .bold)
                .foregroundColor(MimiTheme.textPrimary)

            Spacer()

            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .mimiFont(14, weight: .bold)
                    .foregroundColor(MimiTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(MimiTheme.fillSubtle))
            }
            .mimiPressable()
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Self.weekdayLabels, id: \.self) { label in
                Text(label)
                    .mimiFont(12, weight: .semibold)
                    .foregroundColor(MimiTheme.textMuted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        let days = daysInVisibleMonth()
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
            spacing: 6
        ) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    let selected = Self.calendar.isDate(day, inSameDayAs: selection)
                    let isToday = Self.calendar.isDateInToday(day)
                    Button {
                        selectDay(day)
                    } label: {
                        Text("\(Self.calendar.component(.day, from: day))")
                            .mimiFont(15, weight: selected ? .bold : .medium)
                            .foregroundColor(selected ? .white : MimiTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                Circle()
                                    .fill(selected ? MimiTheme.expenseBlue : Color.clear)
                            )
                            .overlay(
                                Circle()
                                    .stroke(isToday && !selected ? MimiTheme.expenseBlue.opacity(0.45) : Color.clear, lineWidth: 1.2)
                            )
                    }
                    .mimiPressable()
                } else {
                    Color.clear.frame(height: 36)
                }
            }
        }
    }

    private var timeRow: some View {
        HStack(spacing: 12) {
            Text("时间")
                .mimiFont(14, weight: .semibold)
                .foregroundColor(MimiTheme.textSecondary)

            Spacer()

            timeStepper(value: hourBinding, range: 0...23, suffix: "时")
            timeStepper(value: minuteBinding, range: 0...59, suffix: "分")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MimiTheme.background)
        )
    }

    private func timeStepper(value: Binding<Int>, range: ClosedRange<Int>, suffix: String) -> some View {
        HStack(spacing: 8) {
            Button {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
            } label: {
                Image(systemName: "minus")
                    .mimiFont(12, weight: .bold)
                    .foregroundColor(MimiTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(MimiTheme.cardBackground))
            }
            .mimiPressable()

            Text(String(format: "%02d%@", value.wrappedValue, suffix))
                .mimiFont(15, weight: .bold, design: .rounded)
                .foregroundColor(MimiTheme.textPrimary)
                .frame(minWidth: 52)

            Button {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
            } label: {
                Image(systemName: "plus")
                    .mimiFont(12, weight: .bold)
                    .foregroundColor(MimiTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(MimiTheme.cardBackground))
            }
            .mimiPressable()
        }
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { Self.calendar.component(.hour, from: selection) },
            set: { newHour in
                var comps = Self.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selection)
                comps.hour = newHour
                if let date = Self.calendar.date(from: comps) {
                    selection = date
                }
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { Self.calendar.component(.minute, from: selection) },
            set: { newMinute in
                var comps = Self.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selection)
                comps.minute = newMinute
                if let date = Self.calendar.date(from: comps) {
                    selection = date
                }
            }
        )
    }

    private var monthTitle: String {
        let y = Self.calendar.component(.year, from: visibleMonth)
        let m = Self.calendar.component(.month, from: visibleMonth)
        return "\(y)年\(m)月"
    }

    private var summaryText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = mode == .dateAndTime ? "yyyy年M月d日 HH:mm" : "yyyy年M月d日"
        return "已选 \(f.string(from: selection))"
    }

    private func shiftMonth(_ delta: Int) {
        if let next = Self.calendar.date(byAdding: .month, value: delta, to: visibleMonth) {
            visibleMonth = Self.startOfMonth(next)
        }
    }

    private func selectDay(_ day: Date) {
        var comps = Self.calendar.dateComponents([.year, .month, .day], from: day)
        if mode == .dateAndTime {
            comps.hour = Self.calendar.component(.hour, from: selection)
            comps.minute = Self.calendar.component(.minute, from: selection)
        } else {
            comps.hour = 12
            comps.minute = 0
        }
        if let date = Self.calendar.date(from: comps) {
            selection = date
            visibleMonth = Self.startOfMonth(date)
        }
    }

    private func daysInVisibleMonth() -> [Date?] {
        guard let monthInterval = Self.calendar.dateInterval(of: .month, for: visibleMonth),
              let range = Self.calendar.range(of: .day, in: .month, for: visibleMonth) else {
            return []
        }
        let firstWeekday = Self.calendar.component(.weekday, from: monthInterval.start) // 1=Sun
        let leading = firstWeekday - 1
        var days: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            if let date = Self.calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                days.append(date)
            }
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private static func startOfMonth(_ date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }
}

/// 触发自家日期弹窗的按钮行（替代行内系统 DatePicker）。
public struct MimiDateFieldButton: View {
    public var label: String?
    @Binding public var date: Date
    public var mode: MimiDatePickerSheet.Mode
    public var title: String
    @State private var showSheet = false

    public init(
        label: String? = nil,
        date: Binding<Date>,
        mode: MimiDatePickerSheet.Mode = .date,
        title: String = "选择日期"
    ) {
        self.label = label
        self._date = date
        self.mode = mode
        self.title = title
    }

    public var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack(spacing: 6) {
                if let label, !label.isEmpty {
                    Text(label)
                        .mimiFont(13, weight: .medium)
                        .foregroundColor(MimiTheme.textSecondary)
                }
                Text(displayText)
                    .mimiFont(14, weight: .semibold)
                    .foregroundColor(MimiTheme.textPrimary)
                Image(systemName: "chevron.down")
                    .mimiFont(11, weight: .bold)
                    .foregroundColor(MimiTheme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MimiTheme.fillSubtle)
            )
        }
        .mimiPressable()
        .sheet(isPresented: $showSheet) {
            MimiDatePickerSheet(
                selection: $date,
                title: title,
                mode: mode,
                onDone: { showSheet = false }
            )
            #if os(iOS)
            .mimiInteractiveSheet(
                detents: [.height(mode == .dateAndTime ? 520 : 460)],
                showDragIndicator: false
            )
            .presentationCornerRadius(24)
            #endif
        }
    }

    private var displayText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = mode == .dateAndTime ? "M月d日 HH:mm" : "M月d日"
        return f.string(from: date)
    }
}
