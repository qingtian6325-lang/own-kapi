import SwiftUI

public struct MimiStickerIconView: View {
    public let iconName: String
    public let categoryName: String
    public let transactionType: TransactionType
    public let useFirstCharIcon: Bool
    public let size: CGFloat
    public let isSelected: Bool

    public init(
        iconName: String,
        categoryName: String = "",
        transactionType: TransactionType = .expense,
        useFirstCharIcon: Bool = false,
        size: CGFloat = 38,
        isSelected: Bool = false
    ) {
        self.iconName = iconName
        self.categoryName = categoryName
        self.transactionType = transactionType
        self.useFirstCharIcon = useFirstCharIcon
        self.size = size
        self.isSelected = isSelected
    }

    public init(name: String, size: CGFloat = 38) {
        self.init(iconName: name, size: size)
    }

    private var firstCharText: String {
        let trimmed = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else {
            return String(iconName.prefix(1))
        }
        return String(first)
    }

    private var isCustomFirstCharToken: Bool {
        if useFirstCharIcon { return true }
        // If iconName is a single CJK character like "家", "车", "别"
        if iconName.count == 1, let scalar = iconName.unicodeScalars.first, scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
            return true
        }
        return false
    }

    public var body: some View {
        if isCustomFirstCharToken {
            ZStack {
                Circle()
                    .fill(
                        transactionType == .expense
                            ? MimiTheme.expenseBlue
                            : MimiTheme.incomeOrange
                    )
                    .frame(width: size, height: size)

                Text(iconName.count == 1 ? iconName : firstCharText)
                    .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .overlay(
                Circle()
                    .strokeBorder(
                        isSelected ? MimiTheme.expenseBlue : Color.clear,
                        lineWidth: 2
                    )
            )
        } else {
            let spec = Self.stickerSpec(for: iconName, fallbackName: categoryName)
            ZStack {
                // 贴纸风：白底圆 + 浅灰细描边 + 轻微阴影，emoji 居中放大（参考 Kapi 分类图标选择器风格，原创实现）
                Circle()
                    .fill(Color.white)
                    .frame(width: size, height: size)
                    .shadow(color: Color.black.opacity(0.08), radius: size * 0.06, x: 0, y: size * 0.03)

                Circle()
                    .fill(spec.background.opacity(0.55))
                    .frame(width: size * 0.82, height: size * 0.82)

                Text(spec.emoji)
                    .font(.system(size: size * 0.58))
            }
            .overlay(
                Circle()
                    .strokeBorder(
                        isSelected
                            ? (transactionType == .expense ? MimiTheme.expenseBlue : MimiTheme.incomeOrange)
                            : Color.black.opacity(0.10),
                        lineWidth: isSelected ? 2.0 : 1.0
                    )
            )
        }
    }

    public struct StickerSpec: Sendable {
        public let emoji: String
        public let background: Color
    }

    public static func stickerSpec(for key: String, fallbackName: String = "") -> StickerSpec {
        switch key {
        // Expense - Food
        case "food_group", "food_restaurant":
            return StickerSpec(emoji: "🍜", background: Color(hex: 0xFFF3E0))
        case "food_ingredients":
            return StickerSpec(emoji: "🥬", background: Color(hex: 0xE8F5E9))
        case "food_takeout":
            return StickerSpec(emoji: "🍱", background: Color(hex: 0xFFF8E1))
        case "food_coffee":
            return StickerSpec(emoji: "☕️", background: Color(hex: 0xEFEBE9))
        case "food_drink":
            return StickerSpec(emoji: "🧋", background: Color(hex: 0xFCE4EC))
        case "food_snack":
            return StickerSpec(emoji: "🍮", background: Color(hex: 0xFFF3E0))
        case "food_bar":
            return StickerSpec(emoji: "🍹", background: Color(hex: 0xF3E5F5))

        // Expense - Shopping
        case "shop_group", "shop_daily":
            return StickerSpec(emoji: "🛍️", background: Color(hex: 0xE3F2FD))
        case "shop_clothes":
            return StickerSpec(emoji: "👗", background: Color(hex: 0xFCE4EC))
        case "shop_beauty":
            return StickerSpec(emoji: "💄", background: Color(hex: 0xF8BBD0).opacity(0.35))
        case "shop_digital":
            return StickerSpec(emoji: "🎧", background: Color(hex: 0xE8EAF6))
        case "shop_care":
            return StickerSpec(emoji: "💇‍♀️", background: Color(hex: 0xF3E5F5))
        case "shop_shipping":
            return StickerSpec(emoji: "📦", background: Color(hex: 0xFFF3E0))
        case "shop_secondhand":
            return StickerSpec(emoji: "🏷️", background: Color(hex: 0xE0F2F1))

        // Expense - Transport
        case "trans_group", "trans_bus":
            return StickerSpec(emoji: "🚌", background: Color(hex: 0xE3F2FD))
        case "trans_taxi":
            return StickerSpec(emoji: "🚕", background: Color(hex: 0xFFFDE7))
        case "trans_train":
            return StickerSpec(emoji: "🚄", background: Color(hex: 0xE8EAF6))
        case "trans_fuel":
            return StickerSpec(emoji: "⛽️", background: Color(hex: 0xFFEBEE))
        case "trans_parking":
            return StickerSpec(emoji: "🅿️", background: Color(hex: 0xE3F2FD))
        case "trans_car":
            return StickerSpec(emoji: "🚗", background: Color(hex: 0xE0F7FA))
        case "trans_card":
            return StickerSpec(emoji: "🪪", background: Color(hex: 0xF1F8E9))

        // Expense - Housing
        case "house_group", "house_rent":
            return StickerSpec(emoji: "🏠", background: Color(hex: 0xFFF3E0))
        case "house_util":
            return StickerSpec(emoji: "💡", background: Color(hex: 0xFFFDE7))
        case "house_phone":
            return StickerSpec(emoji: "📱", background: Color(hex: 0xE3F2FD))
        case "house_prop":
            return StickerSpec(emoji: "🔑", background: Color(hex: 0xFFF8E1))
        case "house_repair":
            return StickerSpec(emoji: "🛠️", background: Color(hex: 0xECEFF1))
        case "house_clean":
            return StickerSpec(emoji: "🧹", background: Color(hex: 0xE8F5E9))

        // Expense - Entertainment
        case "fun_group", "fun_offline":
            return StickerSpec(emoji: "🎡", background: Color(hex: 0xF3E5F5))
        case "fun_sport":
            return StickerSpec(emoji: "🏸", background: Color(hex: 0xE8F5E9))
        case "fun_digital":
            return StickerSpec(emoji: "🎮", background: Color(hex: 0xE8EAF6))
        case "fun_travel":
            return StickerSpec(emoji: "✈️", background: Color(hex: 0xE1F5FE))
        case "fun_hobby":
            return StickerSpec(emoji: "🎨", background: Color(hex: 0xFFF3E0))
        case "fun_sub":
            return StickerSpec(emoji: "📺", background: Color(hex: 0xFCE4EC))

        // Expense - Medical
        case "med_group", "med_doctor":
            return StickerSpec(emoji: "💊", background: Color(hex: 0xFFEBEE))
        case "med_dental":
            return StickerSpec(emoji: "🦷", background: Color(hex: 0xE1F5FE))
        case "med_health":
            return StickerSpec(emoji: "🍵", background: Color(hex: 0xE8F5E9))
        case "med_checkup":
            return StickerSpec(emoji: "🩺", background: Color(hex: 0xE0F2F1))
        case "med_rehab":
            return StickerSpec(emoji: "🩹", background: Color(hex: 0xFFF3E0))

        // Expense - Study & Office
        case "study_group", "study_book":
            return StickerSpec(emoji: "📚", background: Color(hex: 0xE3F2FD))
        case "study_tuition":
            return StickerSpec(emoji: "🎓", background: Color(hex: 0xE8EAF6))
        case "study_pro":
            return StickerSpec(emoji: "💻", background: Color(hex: 0xECEFF1))
        case "study_hobby":
            return StickerSpec(emoji: "🎹", background: Color(hex: 0xF3E5F5))

        // Expense - Pets & Baby
        case "pet_group", "pet_food":
            return StickerSpec(emoji: "🐾", background: Color(hex: 0xFFF3E0))
        case "pet_supply":
            return StickerSpec(emoji: "🦴", background: Color(hex: 0xFFF8E1))
        case "pet_med":
            return StickerSpec(emoji: "🐕", background: Color(hex: 0xFFEBEE))
        case "pet_service":
            return StickerSpec(emoji: "🛁", background: Color(hex: 0xE1F5FE))
        case "baby_group", "baby_food":
            return StickerSpec(emoji: "🍼", background: Color(hex: 0xFCE4EC))
        case "baby_supply":
            return StickerSpec(emoji: "🧸", background: Color(hex: 0xFFF3E0))
        case "baby_service":
            return StickerSpec(emoji: "🎠", background: Color(hex: 0xF3E5F5))

        // Expense - Finance & Other
        case "fund_group", "fund_repay":
            return StickerSpec(emoji: "💳", background: Color(hex: 0xE3F2FD))
        case "fund_gift":
            return StickerSpec(emoji: "🧧", background: Color(hex: 0xFFEBEE))
        case "ins_group":
            return StickerSpec(emoji: "🛡️", background: Color(hex: 0xE8F5E9))
        case "inv_group":
            return StickerSpec(emoji: "📈", background: Color(hex: 0xFFF8E1))
        case "other_exp":
            return StickerSpec(emoji: "✨", background: Color(hex: 0xF3E5F5))

        // Income
        case "inc_job":
            return StickerSpec(emoji: "💰", background: Color(hex: 0xFFF3E0))
        case "inc_bonus":
            return StickerSpec(emoji: "🏆", background: Color(hex: 0xFFF8E1))
        case "inc_allowance":
            return StickerSpec(emoji: "💎", background: Color(hex: 0xE1F5FE))
        case "inc_biz":
            return StickerSpec(emoji: "🏪", background: Color(hex: 0xFFF3E0))
        case "inc_side":
            return StickerSpec(emoji: "🚀", background: Color(hex: 0xE8EAF6))
        case "inc_invest", "inc_dividend", "inc_interest":
            return StickerSpec(emoji: "🪙", background: Color(hex: 0xFFF8E1))
        case "inc_claim":
            return StickerSpec(emoji: "☂️", background: Color(hex: 0xE8F5E9))
        case "inc_refund", "inc_cashback", "inc_reimburse", "inc_repay", "inc_tax":
            return StickerSpec(emoji: "💸", background: Color(hex: 0xE0F2F1))
        case "inc_gift", "inc_living":
            return StickerSpec(emoji: "🎁", background: Color(hex: 0xFCE4EC))
        case "inc_other", "inc_secondhand", "inc_luck":
            return StickerSpec(emoji: "🍀", background: Color(hex: 0xE8F5E9))

        default:
            // If key itself is an emoji, render it on soft warm background
            if key.count <= 2, key.unicodeScalars.first?.properties.isEmoji == true {
                return StickerSpec(emoji: key, background: Color(hex: 0xFFF3E0))
            }
            return StickerSpec(emoji: "🦫", background: Color(hex: 0xFFF3E0))
        }
    }

    public static let stickerGalleryItems: [(category: String, icons: [String])] = [
        ("最近使用", ["🍜", "☕️", "🧋", "🛍️", "🚕", "⛽️", "🏠", "🎮", "💊", "💰"]),
        ("餐饮美食", ["🍜", "🍲", "🍱", "🍔", "🍕", "🍣", "🍗", "🍖", "🥩", "🍤", "🦐", "🦀", "🐙", "🍟", "🌭", "🥪", "🌮", "🌯", "🥙", "🧆", "🥗", "🍝", "🍛", "🍚", "🍙", "🍘", "🥟", "🍢", "🍡", "🍧", "🍨", "🍦", "🥧", "🧁", "🍰", "🎂", "🍮", "🍭", "🍬", "🍫", "🍩", "🍪", "🥐", "🥖", "🥨", "🧀", "🥚", "🍳", "🧈", "🥞", "🧇", "🥓", "🍿", "🧂", "🥫", "🍯", "🥛", "🍼", "☕️", "🫖", "🍵", "🧃", "🥤", "🧋", "🍶", "🍺", "🍻", "🥂", "🍷", "🥃", "🍸", "🍹", "🧉", "🍾", "🍇", "🍈", "🍉", "🍊", "🍋", "🍌", "🍍", "🥭", "🍎", "🍏", "🍐", "🍑", "🍒", "🍓", "🫐", "🥝", "🍅", "🫒", "🥑", "🍆", "🥔", "🥕", "🌽", "🌶️", "🫑", "🥒", "🥬", "🥦", "🧄", "🧅", "🥜", "🌰"]),
        ("日常购物", ["🛍️", "👕", "👗", "👚", "👖", "👔", "👞", "👟", "🥾", "🥿", "👠", "👡", "👢", "👒", "🎩", "🧢", "👑", "💍", "💄", "💅", "🪞", "🕶️", "👓", "⌚️", "🎒", "👜", "👛", "👝", "💼", "🧳", "🌂", "🧴", "🧷", "🧵", "🧶", "🛒", "🛍", "🎁", "🏷️", "💳", "🧾", "📦", "🛋️", "🪑", "🚪", "🧸", "🪆", "🖼️"]),
        ("交通出行", ["🚌", "🚕", "🚗", "🚙", "🛻", "🚚", "🚛", "🏎️", "🚓", "🚑", "🚒", "🚐", "🛵", "🏍️", "🚲", "🛴", "🚂", "🚄", "🚅", "🚆", "🚇", "🚈", "🚉", "✈️", "🛫", "🛬", "🚀", "🛸", "🚁", "🛶", "⛵️", "🚤", "🛳️", "⛴️", "🚢", "⚓️", "⛽️", "🚧", "🚦", "🚥", "🗺️", "🅿️", "🎫", "🧳", "🛂", "🛃", "🪪", "🔑"]),
        ("居家生活", ["🏠", "🏡", "🔑", "🛋️", "🛏️", "🛁", "🚿", "🚽", "🧴", "🧻", "🧺", "🧹", "🧽", "🧼", "🪥", "🪒", "🧯", "🔌", "💡", "🕯️", "🧸", "🪴", "🌷", "🐱", "🐶", "📺", "📻", "⏰", "☎️", "📱", "💻", "🖨️", "⌨️", "🖱️", "🧾", "💧", "🔥", "📦", "🛠️", "🔧", "🔨", "🧰", "🪜", "🚪", "🪟", "🧲"]),
        ("休闲娱乐", ["🎮", "🕹️", "🎲", "🧩", "🃏", "🎯", "🎳", "🎱", "🏓", "🎸", "🎹", "🎻", "🥁", "🎷", "🎺", "🪗", "🎤", "🎧", "🎬", "🎭", "🎨", "🎪", "🎟️", "🎫", "🍿", "📺", "📷", "📹", "🎠", "🎡", "🎢", "🚂", "🏖️", "🏕️", "⛺️", "🏝️", "🗺️", "🧭", "🎆", "🎇", "🧨", "✨", "🎈", "🎉", "🎊", "🎁"]),
        ("运动健身", ["⚽️", "🏀", "🏈", "⚾️", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱", "🪀", "🏓", "🏸", "🥊", "🥋", "🎽", "🛹", "🛼", "🛷", "⛸️", "🥌", "🎿", "⛷️", "🏂", "🏋️", "🤸", "🤾", "🏌️", "🏇", "🧘", "🏄", "🏊", "🚣", "🧗", "🚵", "🚴", "🏆", "🥇", "🥈", "🥉", "🏅", "🎖️", "🏵️", "🎗️", "💪", "🦵", "🦶"]),
        ("医疗健康", ["💊", "💉", "🩸", "🩹", "🩺", "🩻", "🦷", "👁️", "👂", "🧠", "🫀", "🫁", "🦴", "💪", "🌡️", "🧬", "🔬", "🧪", "🧫", "😷", "🤒", "🤕", "🤢", "🤮", "🤧", "🥵", "🥶", "🥴", "😵", "🤯", "🏥", "🚑", "⚕️", "♿️", "🧑‍⚕️", "👨‍⚕️", "👩‍⚕️", "🍵", "🧘", "🛌", "💤", "🧴", "🧼"]),
        ("母婴宠物", ["🍼", "👶", "🧒", "👧", "👦", "🧸", "🪆", "🪀", "🧩", "🎠", "🎡", "🎈", "👕", "👖", "👗", "🧦", "👟", "🎒", "📚", "✏️", "🖍️", "🎨", "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐔", "🐧", "🐦", "🦄", "🐾", "🦴", "🐕", "🐈", "🛁", "🧼"]),
        ("财务金融", ["💰", "💴", "💵", "💶", "💷", "💸", "💳", "🧾", "💎", "⚖️", "🧮", "📈", "📉", "📊", "💹", "🏦", "🏧", "🪙", "💲", "🤑", "🏆", "🥇", "🎖️", "🏅", "📋", "📌", "📎", "✂️", "🗂️", "🗃️", "🗄️", "🔒", "🔓", "🔑", "🗝️", "🧧", "🎁", "🍀", "✨", "⭐️", "🌟", "💫", "🔥"]),
        ("旅行度假", ["✈️", "🚗", "🚢", "🚂", "🏖️", "🏝️", "🏜️", "🏔️", "⛰️", "🌋", "🏕️", "⛺️", "🏨", "🏩", "🏰", "🏯", "🗼", "🗽", "🎡", "🎢", "🎠", "⛲️", "🌉", "🌁", "🌃", "🌄", "🌅", "🌇", "🌆", "🌌", "🎆", "🎇", "📸", "📷", "🗺️", "🧭", "🧳", "🎒", "🕶️", "👒", "📖", "🎫", "🎟️", "🛂", "💱", "🏧"]),
        ("学习办公", ["📚", "📖", "📕", "📗", "📘", "📙", "📓", "📔", "📒", "📝", "✏️", "✒️", "🖋️", "🖊️", "🖌️", "🖍️", "📐", "📏", "📌", "📍", "📎", "🖇️", "✂️", "🗂️", "🗒️", "🗓️", "📆", "📅", "📇", "📈", "📉", "📊", "📋", "💻", "🖥️", "🖨️", "⌨️", "🖱️", "💽", "💾", "💿", "📀", "🎓", "🏫", "📜", "🏆", "🥇", "💡"]),
        ("数码科技", ["📱", "💻", "🖥️", "⌨️", "🖱️", "🖨️", "📷", "📹", "🎥", "📺", "📻", "🎙️", "🎚️", "🎛️", "🧭", "⏱️", "⏰", "⌚️", "📡", "🔋", "🪫", "🔌", "💡", "🔦", "🕯️", "🧯", "🛢️", "💸", "🎮", "🕹️", "🎰", "🧲", "🔭", "🔬", "🧬", "🦾", "🦿", "🤖", "👾", "🛸", "🚀", "🛰️", "🌐", "💾", "💿", "📀"]),
        ("人情社交", ["🎁", "🧧", "💌", "💐", "🌹", "🥀", "🌺", "🌸", "💮", "🏵️", "🌻", "🌼", "🌷", "🪷", "🎂", "🍰", "🧁", "🍾", "🥂", "🍻", "🎉", "🎊", "🎈", "🎀", "🪅", "🪩", "💃", "🕺", "👯", "🧑‍🤝‍🧑", "👨‍👩‍👧", "👨‍👩‍👦", "💑", "💏", "🤝", "👍", "👏", "🙏", "💪", "❤️", "🧡", "💛", "💚", "💙", "💜", "🤎", "🖤", "🤍"])
    ]
}
