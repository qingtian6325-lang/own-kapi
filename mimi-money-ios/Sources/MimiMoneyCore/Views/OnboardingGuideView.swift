import SwiftUI

/// 新手指南：昵称 → 月起始日 → 月预算 → 账户余额 → 完成。
public struct OnboardingGuideView: View {
    @ObservedObject public var store: MimiStore
    public var onFinished: () -> Void

    @State private var step: Int = 0
    @State private var nickname: String = ""
    @State private var startDay: Int = 1
    @State private var budgetText: String = "3000"
    @State private var accountBalances: [String: String] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let totalSteps = 4

    public init(store: MimiStore, onFinished: @escaping () -> Void) {
        self.store = store
        self.onFinished = onFinished
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        stepContent
                    }
                    .padding(20)
                }
                bottomBar
            }
            .background(MimiTheme.background.ignoresSafeArea())
            .navigationTitle(MimiL10n.string("新手指南"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(MimiL10n.string("跳过")) { finish(skip: true) }
                        .accessibilityLabel(MimiL10n.string("跳过新手指南"))
                }
            }
            .onAppear {
                nickname = store.userNickname
                startDay = store.monthStartDay
                budgetText = String(format: "%.0f", store.monthlyBudgetTotal)
                if accountBalances.isEmpty {
                    for acc in store.accounts {
                        accountBalances[acc.id] = String(format: "%.2f", acc.balance)
                    }
                }
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("步骤 \(step + 1)/\(totalSteps)")
                .mimiFont(12, weight: .medium)
                .foregroundColor(MimiTheme.textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(MimiTheme.fillSubtle).frame(height: 6)
                    Capsule()
                        .fill(MimiTheme.expenseBlue)
                        .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(totalSteps), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            stepCard(title: "先认识一下你", subtitle: "昵称会显示在侧边栏，随时可在设置里改。") {
                TextField("怎么称呼你", text: $nickname)
                    .mimiFont(16, weight: .medium)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.cardBackground))
            }
        case 1:
            stepCard(
                title: "月统计从哪天开始？",
                subtitle: "例如选 25 日，则账期为每月 25 日到下月 24 日。首页预算、分类花费、统计「月」都会按这个账期计算。"
            ) {
                Picker("起始日", selection: $startDay) {
                    ForEach(1...28, id: \.self) { day in
                        Text(day == 1 ? "每月 1 日（自然月）" : "每月 \(day) 日").tag(day)
                    }
                }
                #if os(iOS)
                .pickerStyle(.wheel)
                #endif
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.cardBackground))

                let preview = BillingPeriodEngine.period(containing: Date(), startDay: startDay)
                Text("当前账期预览：\(preview.displayRangeLabel)")
                    .mimiFont(13, weight: .medium)
                    .foregroundColor(MimiTheme.expenseBlue)
            }
        case 2:
            stepCard(title: "这个账期预算多少？", subtitle: "月预算会直接影响首页剩余与每日可用金额。") {
                HStack {
                    Text("RM")
                        .mimiFont(16, weight: .bold)
                        .foregroundColor(MimiTheme.textSecondary)
                    TextField("3000", text: $budgetText)
                        .mimiFont(22, weight: .bold, design: .rounded)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.cardBackground))
            }
        default:
            stepCard(title: "设一下账户余额", subtitle: "填写当前各账户余额，净资产才会准。也可以先跳过，之后在「资产管理」里改。") {
                VStack(spacing: 10) {
                    ForEach(store.accounts) { acc in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(acc.name)
                                    .mimiFont(14, weight: .semibold)
                                    .foregroundColor(MimiTheme.textPrimary)
                                Text(acc.isLiability ? "负债" : "资产")
                                    .mimiFont(11)
                                    .foregroundColor(MimiTheme.textSecondary)
                            }
                            Spacer()
                            TextField("0.00", text: binding(for: acc.id))
                                .mimiFont(15, weight: .semibold, design: .rounded)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(MimiTheme.cardBackground))
                    }
                }
            }
        }
    }

    private func stepCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .mimiFont(22, weight: .bold)
                .foregroundColor(MimiTheme.textPrimary)
            Text(subtitle)
                .mimiFont(14)
                .foregroundColor(MimiTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button(MimiL10n.string("上一步")) {
                    withAnimation(MimiMotion.quick(reduceMotion: reduceMotion)) { step -= 1 }
                }
                .mimiFont(15, weight: .semibold)
                .foregroundColor(MimiTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(MimiTheme.fillSubtle))
                .mimiPressable()
            }

            Button(step == totalSteps - 1 ? "完成" : "下一步") {
                if step == totalSteps - 1 {
                    finish(skip: false)
                } else {
                    applyCurrentStep()
                    withAnimation(MimiMotion.quick(reduceMotion: reduceMotion)) { step += 1 }
                }
            }
            .mimiFont(15, weight: .bold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(MimiTheme.expenseBlue))
            .mimiPressable()
            .accessibilityLabel(step == totalSteps - 1 ? "完成新手指南" : "下一步")
        }
        .padding(16)
        .background(MimiTheme.cardBackground.ignoresSafeArea(edges: .bottom))
    }

    private func binding(for accountId: String) -> Binding<String> {
        Binding(
            get: { accountBalances[accountId] ?? "0" },
            set: { accountBalances[accountId] = $0 }
        )
    }

    private func applyCurrentStep() {
        switch step {
        case 0:
            let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { store.setNickname(name) }
        case 1:
            store.setMonthStartDay(startDay)
        case 2:
            if let val = Double(budgetText.replacingOccurrences(of: ",", with: "")) {
                store.updateMonthlyBudget(val)
            }
        default:
            break
        }
    }

    private func finish(skip: Bool) {
        if !skip {
            applyCurrentStep()
            // Persist account initial balances
            for acc in store.accounts {
                guard let text = accountBalances[acc.id],
                      let val = Double(text.replacingOccurrences(of: ",", with: "")) else { continue }
                store.updateAccountBalance(accountId: acc.id, newBalance: val)
            }
        } else {
            // Still save whatever was entered on earlier steps
            if step >= 1 { store.setMonthStartDay(startDay) }
            if step >= 2, let val = Double(budgetText.replacingOccurrences(of: ",", with: "")) {
                store.updateMonthlyBudget(val)
            }
            let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { store.setNickname(name) }
        }
        store.completeOnboarding()
        onFinished()
    }
}
