import SwiftUI

public struct MimiChoiceItem: Identifiable {
    public let id: String
    public let icon: String
    public let title: String
    public let subtitle: String?

    public init(id: String, icon: String, title: String, subtitle: String? = nil) {
        self.id = id
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }
}

/// 自家风格选项底栏，替代系统 confirmationDialog。
public struct MimiChoiceSheet: View {
    public var title: String
    public var items: [MimiChoiceItem]
    public var onSelect: (MimiChoiceItem) -> Void
    public var onCancel: () -> Void

    public init(
        title: String,
        items: [MimiChoiceItem],
        onSelect: @escaping (MimiChoiceItem) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.items = items
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(MimiTheme.strokeSubtle)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 10)

            Text(title)
                .mimiFont(17, weight: .bold)
                .foregroundColor(MimiTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            VStack(spacing: 10) {
                ForEach(items) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .mimiFont(20, weight: .regular)
                                .foregroundColor(MimiTheme.textSecondary)
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(MimiTheme.fillSubtle)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .mimiFont(15, weight: .semibold)
                                    .foregroundColor(MimiTheme.textPrimary)
                                if let subtitle = item.subtitle, !subtitle.isEmpty {
                                    Text(subtitle)
                                        .mimiFont(12)
                                        .foregroundColor(MimiTheme.textSecondary)
                                }
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .mimiFont(12, weight: .bold)
                                .foregroundColor(MimiTheme.textMuted)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(MimiTheme.fillSubtle)
                        )
                    }
                    .mimiPressable()
                }
            }
            .padding(.horizontal, 16)

            Button(action: onCancel) {
                Text("取消", bundle: .module)
                    .mimiFont(15, weight: .semibold)
                    .foregroundColor(MimiTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(MimiTheme.fillSubtle)
                    )
            }
            .mimiPressable()
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(MimiTheme.cardBackground)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
