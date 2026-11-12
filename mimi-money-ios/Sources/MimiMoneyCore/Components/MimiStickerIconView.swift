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
                Circle()
                    .fill(Color.white)
                    .frame(width: size, height: size)
                    .shadow(color: Color.black.opacity(0.04), radius: size * 0.02, x: 0, y: size * 0.006)

                Circle()
                    .fill(spec.background)
                    .frame(width: size * 0.90, height: size * 0.90)

                Image(systemName: spec.systemName)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(spec.tint)
                    .symbolRenderingMode(.monochrome)
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
        public let systemName: String
        public let background: Color
        public let tint: Color

        public init(systemName: String, background: Color, tint: Color = Color(hex: 0x5C4A3A)) {
            self.systemName = systemName
            self.background = background
            self.tint = tint
        }
    }

    private static func ink(_ hex: UInt32) -> Color { Color(hex: hex) }

    public static func stickerSpec(for key: String, fallbackName: String = "") -> StickerSpec {
        let normalized = String(key.unicodeScalars.filter { $0.value != 0xFE0F && $0.value != 0xFE0E }.map { Character($0) })
        if let home = homeGoldSpec(normalizedKey: normalized, hint: fallbackName) {
            return home
        }

        // Already an SF Symbol token from the picker
        if key.contains("."), !key.contains(" ") {
            return StickerSpec(systemName: key, background: Color(hex: 0xFFF3E0))
        }

        switch key {
        case "food_group", "food_restaurant":
            return StickerSpec(systemName: "fork.knife", background: Color(hex: 0xFFE0B2))
        case "food_ingredients":
            return StickerSpec(systemName: "leaf.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45))
        case "food_takeout":
            return StickerSpec(systemName: "takeoutbag.and.cup.and.straw.fill", background: Color(hex: 0xFFF8E1))
        case "food_coffee":
            return StickerSpec(systemName: "cup.and.saucer.fill", background: Color(hex: 0xEFEBE9), tint: ink(0x6D4C41))
        case "food_drink":
            return StickerSpec(systemName: "cup.and.saucer.fill", background: Color(hex: 0xFCE4EC), tint: ink(0x8E3A5B))
        case "food_snack":
            return StickerSpec(systemName: "birthday.cake.fill", background: Color(hex: 0xFFF3E0))
        case "food_bar":
            return StickerSpec(systemName: "wineglass.fill", background: Color(hex: 0xF3E5F5), tint: ink(0x6A4C7A))

        case "shop_group", "shop_daily":
            return StickerSpec(systemName: "bag.fill", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A))
        case "shop_clothes":
            return StickerSpec(systemName: "tshirt.fill", background: Color(hex: 0xFCE4EC), tint: ink(0x8E3A5B))
        case "shop_beauty":
            return StickerSpec(systemName: "sparkles", background: Color(hex: 0xF8BBD0).opacity(0.35), tint: ink(0x9C3D6A))
        case "shop_digital":
            return StickerSpec(systemName: "headphones", background: Color(hex: 0xE8EAF6), tint: ink(0x3F4578))
        case "shop_care":
            return StickerSpec(systemName: "scissors", background: Color(hex: 0xF3E5F5), tint: ink(0x6A4C7A))
        case "shop_shipping":
            return StickerSpec(systemName: "shippingbox.fill", background: Color(hex: 0xFFF3E0))
        case "shop_secondhand":
            return StickerSpec(systemName: "tag.fill", background: Color(hex: 0xE0F2F1), tint: ink(0x2F6B63))

        case "trans_group", "trans_bus":
            return StickerSpec(systemName: "bus.fill", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A))
        case "trans_taxi":
            return StickerSpec(systemName: "car.fill", background: Color(hex: 0xFFFDE7), tint: ink(0x8A6A20))
        case "trans_train":
            return StickerSpec(systemName: "tram.fill", background: Color(hex: 0xE8EAF6), tint: ink(0x3F4578))
        case "trans_fuel":
            return StickerSpec(systemName: "fuelpump.fill", background: Color(hex: 0xD6F1FA), tint: ink(0x2A6F8A))
        case "trans_parking":
            return StickerSpec(systemName: "parkingsign", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A))
        case "trans_car":
            return StickerSpec(systemName: "car.side.fill", background: Color(hex: 0xE0F7FA), tint: ink(0x2A6F8A))
        case "trans_card":
            return StickerSpec(systemName: "ticket.fill", background: Color(hex: 0xF1F8E9), tint: ink(0x3E6B45))

        case "house_group", "house_rent":
            return StickerSpec(systemName: "house.fill", background: Color(hex: 0xFFF3E0))
        case "house_util":
            return StickerSpec(systemName: "lightbulb.fill", background: Color(hex: 0xFFF6D0), tint: ink(0x8A6A20))
        case "house_phone":
            return StickerSpec(systemName: "iphone", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A))
        case "house_prop":
            return StickerSpec(systemName: "key.fill", background: Color(hex: 0xFFF8E1))
        case "house_repair":
            return StickerSpec(systemName: "wrench.and.screwdriver.fill", background: Color(hex: 0xECEFF1), tint: ink(0x455A64))
        case "house_clean":
            return StickerSpec(systemName: "bubbles.and.sparkles.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45))

        case "fun_group":
            return StickerSpec(systemName: "ferriswheel", background: Color(hex: 0xF3E5F5), tint: ink(0x6A4C7A))
        case "fun_offline":
            return StickerSpec(systemName: "ticket.fill", background: Color(hex: 0xFFE3C2))
        case "fun_sport":
            return StickerSpec(systemName: "figure.run", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45))
        case "fun_digital":
            return StickerSpec(systemName: "gamecontroller.fill", background: Color(hex: 0xE8EAF6), tint: ink(0x3F4578))
        case "fun_travel":
            return StickerSpec(systemName: "airplane", background: Color(hex: 0xE1F5FE), tint: ink(0x2A6F8A))
        case "fun_hobby":
            return StickerSpec(systemName: "paintpalette.fill", background: Color(hex: 0xFFF3E0))
        case "fun_sub":
            return StickerSpec(systemName: "tv.fill", background: Color(hex: 0xFCE4EC), tint: ink(0x8E3A5B))

        case "med_group", "med_doctor":
            return StickerSpec(systemName: "cross.case.fill", background: Color(hex: 0xFFEBEE), tint: ink(0x9C3D4A))
        case "med_dental":
            return StickerSpec(systemName: "mouth.fill", background: Color(hex: 0xE1F5FE), tint: ink(0x2A6F8A))
        case "med_health":
            return StickerSpec(systemName: "leaf.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45))
        case "med_checkup":
            return StickerSpec(systemName: "stethoscope", background: Color(hex: 0xE0F2F1), tint: ink(0x2F6B63))
        case "med_rehab":
            return StickerSpec(systemName: "bandage.fill", background: Color(hex: 0xFFF3E0))

        case "study_group", "study_book":
            return StickerSpec(systemName: "book.fill", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A))
        case "study_tuition":
            return StickerSpec(systemName: "graduationcap.fill", background: Color(hex: 0xE8EAF6), tint: ink(0x3F4578))
        case "study_pro":
            return StickerSpec(systemName: "laptopcomputer", background: Color(hex: 0xECEFF1), tint: ink(0x455A64))
        case "study_hobby":
            return StickerSpec(systemName: "pianokeys", background: Color(hex: 0xF3E5F5), tint: ink(0x6A4C7A))

        case "pet_group", "pet_food":
            return StickerSpec(systemName: "pawprint.fill", background: Color(hex: 0xFFF3E0))
        case "pet_supply":
            return StickerSpec(systemName: "bone.fill", background: Color(hex: 0xFFF8E1))
        case "pet_med":
            return StickerSpec(systemName: "cross.case.fill", background: Color(hex: 0xFFEBEE), tint: ink(0x9C3D4A))
        case "pet_service":
            return StickerSpec(systemName: "drop.fill", background: Color(hex: 0xE1F5FE), tint: ink(0x2A6F8A))
        case "baby_group", "baby_food":
            return StickerSpec(systemName: "figure.and.child.holdinghands", background: Color(hex: 0xFCE4EC), tint: ink(0x8E3A5B))
        case "baby_supply":
            return StickerSpec(systemName: "teddybear.fill", background: Color(hex: 0xFFF3E0))
        case "baby_service":
            return StickerSpec(systemName: "figure.and.child.holdinghands", background: Color(hex: 0xF3E5F5), tint: ink(0x6A4C7A))

        case "fund_group", "fund_repay":
            return StickerSpec(systemName: "creditcard.fill", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A))
        case "fund_gift":
            return StickerSpec(systemName: "envelope.fill", background: Color(hex: 0xFFEBEE), tint: ink(0x9C3D4A))
        case "ins_group":
            return StickerSpec(systemName: "shield.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45))
        case "inv_group":
            return StickerSpec(systemName: "chart.line.uptrend.xyaxis", background: Color(hex: 0xFFF3C4), tint: ink(0x8A6A20))
        case "other_exp":
            return StickerSpec(systemName: "ellipsis.circle.fill", background: Color(hex: 0xF3E5F5), tint: ink(0x6A4C7A))

        case "inc_job":
            return StickerSpec(systemName: "banknote.fill", background: Color(hex: 0xFFF3E0))
        case "inc_bonus":
            return StickerSpec(systemName: "trophy.fill", background: Color(hex: 0xFFF8E1), tint: ink(0x8A6A20))
        case "inc_allowance":
            return StickerSpec(systemName: "diamond.fill", background: Color(hex: 0xE1F5FE), tint: ink(0x2A6F8A))
        case "inc_biz":
            return StickerSpec(systemName: "storefront.fill", background: Color(hex: 0xFFF3E0))
        case "inc_side":
            return StickerSpec(systemName: "rocket.fill", background: Color(hex: 0xE8EAF6), tint: ink(0x3F4578))
        case "inc_invest", "inc_dividend", "inc_interest":
            return StickerSpec(systemName: "bitcoinsign.circle.fill", background: Color(hex: 0xFFF8E1), tint: ink(0x8A6A20))
        case "inc_claim":
            return StickerSpec(systemName: "umbrella.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45))
        case "inc_refund", "inc_cashback", "inc_reimburse", "inc_repay", "inc_tax":
            return StickerSpec(systemName: "arrow.left.arrow.right.circle.fill", background: Color(hex: 0xE0F2F1), tint: ink(0x2F6B63))
        case "inc_gift", "inc_living":
            return StickerSpec(systemName: "gift.fill", background: Color(hex: 0xFCE4EC), tint: ink(0x8E3A5B))
        case "inc_other", "inc_secondhand", "inc_luck":
            return StickerSpec(systemName: "leaf.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45))

        default:
            if let mapped = symbolForLegacyEmoji(normalized) {
                return StickerSpec(systemName: mapped.systemName, background: mapped.background, tint: mapped.tint)
            }
            return StickerSpec(systemName: "circle.grid.cross.fill", background: Color(hex: 0xFFF3E0))
        }
    }

    /// Catalog still stores emoji keys; map them to SF Symbols so UI never renders emoji glyphs.
    private static func symbolForLegacyEmoji(_ key: String) -> StickerSpec? {
        let table: [String: StickerSpec] = [
            "🍜": StickerSpec(systemName: "fork.knife", background: Color(hex: 0xFFE0B2)),
            "🎃": StickerSpec(systemName: "leaf.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45)),
            "🛍️": StickerSpec(systemName: "bag.fill", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A)),
            "🛍": StickerSpec(systemName: "bag.fill", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A)),
            "☕": StickerSpec(systemName: "cup.and.saucer.fill", background: Color(hex: 0xEFEBE9), tint: ink(0x6D4C41)),
            "☕️": StickerSpec(systemName: "cup.and.saucer.fill", background: Color(hex: 0xEFEBE9), tint: ink(0x6D4C41)),
            "🥤": StickerSpec(systemName: "cup.and.saucer.fill", background: Color(hex: 0xFCE4EC), tint: ink(0x8E3A5B)),
            "🧋": StickerSpec(systemName: "cup.and.saucer.fill", background: Color(hex: 0xFCE4EC), tint: ink(0x8E3A5B)),
            "🍟": StickerSpec(systemName: "birthday.cake.fill", background: Color(hex: 0xFFF3E0)),
            "🍮": StickerSpec(systemName: "birthday.cake.fill", background: Color(hex: 0xFFF3E0)),
            "🍺": StickerSpec(systemName: "wineglass.fill", background: Color(hex: 0xF3E5F5), tint: ink(0x6A4C7A)),
            "🍹": StickerSpec(systemName: "wineglass.fill", background: Color(hex: 0xF3E5F5), tint: ink(0x6A4C7A)),
            "🍱": StickerSpec(systemName: "takeoutbag.and.cup.and.straw.fill", background: Color(hex: 0xFFF8E1)),
            "🥬": StickerSpec(systemName: "leaf.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45)),
            "🧺": StickerSpec(systemName: "basket.fill", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A)),
            "👕": StickerSpec(systemName: "tshirt.fill", background: Color(hex: 0xFCE4EC), tint: ink(0x8E3A5B)),
            "👗": StickerSpec(systemName: "tshirt.fill", background: Color(hex: 0xFCE4EC), tint: ink(0x8E3A5B)),
            "🧴": StickerSpec(systemName: "sparkles", background: Color(hex: 0xF8BBD0).opacity(0.35), tint: ink(0x9C3D6A)),
            "💄": StickerSpec(systemName: "sparkles", background: Color(hex: 0xF8BBD0).opacity(0.35), tint: ink(0x9C3D6A)),
            "📷": StickerSpec(systemName: "camera.fill", background: Color(hex: 0xE8EAF6), tint: ink(0x3F4578)),
            "🎧": StickerSpec(systemName: "headphones", background: Color(hex: 0xE8EAF6), tint: ink(0x3F4578)),
            "🧻": StickerSpec(systemName: "scroll.fill", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A)),
            "🧼": StickerSpec(systemName: "bubbles.and.sparkles.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45)),
            "💇‍♀️": StickerSpec(systemName: "scissors", background: Color(hex: 0xF3E5F5), tint: ink(0x6A4C7A)),
            "📦": StickerSpec(systemName: "shippingbox.fill", background: Color(hex: 0xFFF3E0)),
            "🎁": StickerSpec(systemName: "gift.fill", background: Color(hex: 0xFCE4EC), tint: ink(0x8E3A5B)),
            "🏷️": StickerSpec(systemName: "tag.fill", background: Color(hex: 0xE0F2F1), tint: ink(0x2F6B63)),
            "🚗": StickerSpec(systemName: "car.fill", background: Color(hex: 0xE0F7FA), tint: ink(0x2A6F8A)),
            "🚙": StickerSpec(systemName: "car.side.fill", background: Color(hex: 0xE0F7FA), tint: ink(0x2A6F8A)),
            "🚌": StickerSpec(systemName: "bus.fill", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A)),
            "🚕": StickerSpec(systemName: "car.fill", background: Color(hex: 0xFFFDE7), tint: ink(0x8A6A20)),
            "🚄": StickerSpec(systemName: "tram.fill", background: Color(hex: 0xE8EAF6), tint: ink(0x3F4578)),
            "⛽": StickerSpec(systemName: "fuelpump.fill", background: Color(hex: 0xD6F1FA), tint: ink(0x2A6F8A)),
            "⛽️": StickerSpec(systemName: "fuelpump.fill", background: Color(hex: 0xD6F1FA), tint: ink(0x2A6F8A)),
            "🅿️": StickerSpec(systemName: "parkingsign", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A)),
            "🎫": StickerSpec(systemName: "ticket.fill", background: Color(hex: 0xF1F8E9), tint: ink(0x3E6B45)),
            "🪪": StickerSpec(systemName: "person.text.rectangle.fill", background: Color(hex: 0xF1F8E9), tint: ink(0x3E6B45)),
            "🏠": StickerSpec(systemName: "house.fill", background: Color(hex: 0xFFF3E0)),
            "🏡": StickerSpec(systemName: "house.fill", background: Color(hex: 0xFFF3E0)),
            "💧": StickerSpec(systemName: "drop.fill", background: Color(hex: 0xE1F5FE), tint: ink(0x2A6F8A)),
            "💡": StickerSpec(systemName: "lightbulb.fill", background: Color(hex: 0xFFF6D0), tint: ink(0x8A6A20)),
            "🖥️": StickerSpec(systemName: "desktopcomputer", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A)),
            "📱": StickerSpec(systemName: "iphone", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A)),
            "🏢": StickerSpec(systemName: "building.2.fill", background: Color(hex: 0xFFF8E1)),
            "🔑": StickerSpec(systemName: "key.fill", background: Color(hex: 0xFFF8E1)),
            "🖌️": StickerSpec(systemName: "paintbrush.fill", background: Color(hex: 0xECEFF1), tint: ink(0x455A64)),
            "🛠️": StickerSpec(systemName: "wrench.and.screwdriver.fill", background: Color(hex: 0xECEFF1), tint: ink(0x455A64)),
            "🧹": StickerSpec(systemName: "bubbles.and.sparkles.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45)),
            "🏀": StickerSpec(systemName: "sportscourt.fill", background: Color(hex: 0xFFF3E0)),
            "🏸": StickerSpec(systemName: "figure.run", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45)),
            "🎟️": StickerSpec(systemName: "ticket.fill", background: Color(hex: 0xFFE3C2)),
            "🎟": StickerSpec(systemName: "ticket.fill", background: Color(hex: 0xFFE3C2)),
            "🎮": StickerSpec(systemName: "gamecontroller.fill", background: Color(hex: 0xE8EAF6), tint: ink(0x3F4578)),
            "🚩": StickerSpec(systemName: "flag.fill", background: Color(hex: 0xE1F5FE), tint: ink(0x2A6F8A)),
            "✈️": StickerSpec(systemName: "airplane", background: Color(hex: 0xE1F5FE), tint: ink(0x2A6F8A)),
            "🎨": StickerSpec(systemName: "paintpalette.fill", background: Color(hex: 0xFFF3E0)),
            "💳": StickerSpec(systemName: "creditcard.fill", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A)),
            "📺": StickerSpec(systemName: "tv.fill", background: Color(hex: 0xFCE4EC), tint: ink(0x8E3A5B)),
            "🏥": StickerSpec(systemName: "cross.case.fill", background: Color(hex: 0xFFEBEE), tint: ink(0x9C3D4A)),
            "💊": StickerSpec(systemName: "pills.fill", background: Color(hex: 0xFFEBEE), tint: ink(0x9C3D4A)),
            "🦷": StickerSpec(systemName: "mouth.fill", background: Color(hex: 0xE1F5FE), tint: ink(0x2A6F8A)),
            "🫙": StickerSpec(systemName: "leaf.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45)),
            "🍵": StickerSpec(systemName: "cup.and.saucer.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45)),
            "💉": StickerSpec(systemName: "syringe.fill", background: Color(hex: 0xE0F2F1), tint: ink(0x2F6B63)),
            "🩺": StickerSpec(systemName: "stethoscope", background: Color(hex: 0xE0F2F1), tint: ink(0x2F6B63)),
            "🩹": StickerSpec(systemName: "bandage.fill", background: Color(hex: 0xFFF3E0)),
            "🧑‍⚕️": StickerSpec(systemName: "cross.case.fill", background: Color(hex: 0xFFEBEE), tint: ink(0x9C3D4A)),
            "📖": StickerSpec(systemName: "book.fill", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A)),
            "📚": StickerSpec(systemName: "books.vertical.fill", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A)),
            "🎓": StickerSpec(systemName: "graduationcap.fill", background: Color(hex: 0xE8EAF6), tint: ink(0x3F4578)),
            "💻": StickerSpec(systemName: "laptopcomputer", background: Color(hex: 0xECEFF1), tint: ink(0x455A64)),
            "🎹": StickerSpec(systemName: "pianokeys", background: Color(hex: 0xF3E5F5), tint: ink(0x6A4C7A)),
            "✏️": StickerSpec(systemName: "pencil", background: Color(hex: 0xE3F2FD), tint: ink(0x356A9A)),
            "🐱": StickerSpec(systemName: "cat.fill", background: Color(hex: 0xFFF3E0)),
            "🐶": StickerSpec(systemName: "dog.fill", background: Color(hex: 0xFFF3E0)),
            "🦴": StickerSpec(systemName: "bone.fill", background: Color(hex: 0xFFF8E1)),
            "🐾": StickerSpec(systemName: "pawprint.fill", background: Color(hex: 0xFFF3E0)),
            "🐕": StickerSpec(systemName: "dog.fill", background: Color(hex: 0xFFEBEE), tint: ink(0x9C3D4A)),
            "✂️": StickerSpec(systemName: "scissors", background: Color(hex: 0xE1F5FE), tint: ink(0x2A6F8A)),
            "🛁": StickerSpec(systemName: "drop.fill", background: Color(hex: 0xE1F5FE), tint: ink(0x2A6F8A)),
            "👶": StickerSpec(systemName: "figure.and.child.holdinghands", background: Color(hex: 0xFCE4EC), tint: ink(0x8E3A5B)),
            "🍼": StickerSpec(systemName: "figure.and.child.holdinghands", background: Color(hex: 0xFCE4EC), tint: ink(0x8E3A5B)),
            "🧸": StickerSpec(systemName: "teddybear.fill", background: Color(hex: 0xFFF3E0)),
            "🎠": StickerSpec(systemName: "figure.and.child.holdinghands", background: Color(hex: 0xF3E5F5), tint: ink(0x6A4C7A)),
            "🧧": StickerSpec(systemName: "envelope.fill", background: Color(hex: 0xFFEBEE), tint: ink(0x9C3D4A)),
            "🛡️": StickerSpec(systemName: "shield.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45)),
            "📈": StickerSpec(systemName: "chart.line.uptrend.xyaxis", background: Color(hex: 0xFFF3C4), tint: ink(0x8A6A20)),
            "✨": StickerSpec(systemName: "sparkles", background: Color(hex: 0xF3E5F5), tint: ink(0x6A4C7A)),
            "💰": StickerSpec(systemName: "banknote.fill", background: Color(hex: 0xFFF3E0)),
            "🏆": StickerSpec(systemName: "trophy.fill", background: Color(hex: 0xFFF8E1), tint: ink(0x8A6A20)),
            "💎": StickerSpec(systemName: "diamond.fill", background: Color(hex: 0xE1F5FE), tint: ink(0x2A6F8A)),
            "🏪": StickerSpec(systemName: "storefront.fill", background: Color(hex: 0xFFF3E0)),
            "🚀": StickerSpec(systemName: "rocket.fill", background: Color(hex: 0xE8EAF6), tint: ink(0x3F4578)),
            "🪙": StickerSpec(systemName: "bitcoinsign.circle.fill", background: Color(hex: 0xFFF8E1), tint: ink(0x8A6A20)),
            "☂️": StickerSpec(systemName: "umbrella.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45)),
            "☔": StickerSpec(systemName: "umbrella.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45)),
            "💸": StickerSpec(systemName: "arrow.left.arrow.right.circle.fill", background: Color(hex: 0xE0F2F1), tint: ink(0x2F6B63)),
            "🍀": StickerSpec(systemName: "leaf.fill", background: Color(hex: 0xE8F5E9), tint: ink(0x3E6B45)),
            "🧑": StickerSpec(systemName: "person.fill", background: Color(hex: 0xFFE6CC)),
            "🎡": StickerSpec(systemName: "ferriswheel", background: Color(hex: 0xF3E5F5), tint: ink(0x6A4C7A))
        ]
        return table[key]
    }

    private static func homeGoldSpec(normalizedKey key: String, hint: String) -> StickerSpec? {
        if key == "💡"
            || key == "house_util"
            || hint.contains("控制中心")
            || hint.contains("灯泡")
            || hint.contains("电灯") {
            return StickerSpec(systemName: "lightbulb.fill", background: Color(hex: 0xFFF6D0), tint: ink(0x8A6A20))
        }
        if key == "⛽" || key == "trans_fuel" || hint.contains("加油") {
            return StickerSpec(systemName: "fuelpump.fill", background: Color(hex: 0xD6F1FA), tint: ink(0x2A6F8A))
        }
        if key == "🍜" || key == "food_restaurant" || key == "food_group" || hint.contains("餐厅") {
            return StickerSpec(systemName: "fork.knife", background: Color(hex: 0xFFE0B2))
        }
        if key == "📈" || key == "inv_group" || hint == "投资理财" || hint == "投资收入" || hint.hasSuffix("投资理财") {
            return StickerSpec(systemName: "chart.line.uptrend.xyaxis", background: Color(hex: 0xFFF3C4), tint: ink(0x8A6A20))
        }
        if key == "🎟" || key == "fun_offline" || hint.contains("线下娱乐") {
            return StickerSpec(systemName: "ticket.fill", background: Color(hex: 0xFFE3C2))
        }
        let isPersonToken = key.contains("🧑") || key.contains("⚕") || key == "inc_custom_transfer"
        if hint.contains("别人转账") || key == "inc_custom_transfer" || (isPersonToken && hint.contains("转账")) {
            return StickerSpec(systemName: "person.fill", background: Color(hex: 0xFFE6CC))
        }
        return nil
    }

    /// Icon picker gallery: SF Symbol names only (no emoji).
    public static let stickerGalleryItems: [(category: String, icons: [String])] = [
        ("最近使用", [
            "fork.knife", "cup.and.saucer.fill", "bag.fill", "car.fill", "fuelpump.fill",
            "house.fill", "gamecontroller.fill", "pills.fill", "banknote.fill", "gift.fill"
        ]),
        ("餐饮美食", [
            "fork.knife", "takeoutbag.and.cup.and.straw.fill", "cup.and.saucer.fill", "wineglass.fill",
            "birthday.cake.fill", "leaf.fill", "carrot.fill", "fish.fill"
        ]),
        ("日常购物", [
            "bag.fill", "cart.fill", "tshirt.fill", "sparkles", "headphones", "shippingbox.fill",
            "tag.fill", "gift.fill", "basket.fill"
        ]),
        ("交通出行", [
            "bus.fill", "car.fill", "tram.fill", "fuelpump.fill", "parkingsign", "airplane",
            "bicycle", "ticket.fill", "car.side.fill"
        ]),
        ("居家生活", [
            "house.fill", "lightbulb.fill", "drop.fill", "key.fill", "wrench.and.screwdriver.fill",
            "bubbles.and.sparkles.fill", "iphone", "wifi", "sofa.fill"
        ]),
        ("休闲娱乐", [
            "gamecontroller.fill", "ticket.fill", "tv.fill", "music.note", "paintpalette.fill",
            "film", "figure.run", "airplane", "camera.fill"
        ]),
        ("医疗健康", [
            "cross.case.fill", "pills.fill", "stethoscope", "syringe.fill", "bandage.fill",
            "heart.fill", "leaf.fill"
        ]),
        ("母婴宠物", [
            "figure.and.child.holdinghands", "teddybear.fill", "pawprint.fill", "cat.fill",
            "dog.fill", "bone.fill"
        ]),
        ("财务金融", [
            "banknote.fill", "creditcard.fill", "chart.line.uptrend.xyaxis", "yensign.circle.fill",
            "diamond.fill", "shield.fill", "trophy.fill", "building.columns.fill"
        ]),
        ("学习办公", [
            "book.fill", "graduationcap.fill", "laptopcomputer", "pencil", "doc.text.fill",
            "folder.fill", "pianokeys"
        ])
    ]
}

/// Orange-brown capybara face for the home ask bar. Approximate of gold A, not a cropped asset.
public struct MimiAskMascotView: View {
    public var size: CGFloat = 28

    public init(size: CGFloat = 28) {
        self.size = size
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let fur = Color(hex: 0xE39A4B)
            let ear = Color(hex: 0xC4783A)
            let innerEar = Color(hex: 0xF0C08A)
            let muzzle = Color(hex: 0xF6D7B0)
            let ink = Color(hex: 0x3A2A22)
            let nose = Color(hex: 0xC4654A)

            func ellipse(_ x: CGFloat, _ y: CGFloat, _ ew: CGFloat, _ eh: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: x * w, y: y * h, width: ew * w, height: eh * h))
            }

            context.fill(ellipse(0.10, 0.00, 0.26, 0.30), with: .color(ear))
            context.fill(ellipse(0.64, 0.00, 0.26, 0.30), with: .color(ear))
            context.fill(ellipse(0.06, 0.14, 0.88, 0.82), with: .color(fur))
            context.fill(ellipse(0.16, 0.06, 0.14, 0.16), with: .color(innerEar))
            context.fill(ellipse(0.70, 0.06, 0.14, 0.16), with: .color(innerEar))
            context.fill(ellipse(0.24, 0.50, 0.52, 0.38), with: .color(muzzle))
            context.fill(ellipse(0.30, 0.38, 0.10, 0.12), with: .color(ink))
            context.fill(ellipse(0.60, 0.38, 0.10, 0.12), with: .color(ink))
            context.fill(ellipse(0.43, 0.55, 0.14, 0.10), with: .color(nose))

            var smile = Path()
            smile.move(to: CGPoint(x: 0.40 * w, y: 0.70 * h))
            smile.addQuadCurve(
                to: CGPoint(x: 0.60 * w, y: 0.70 * h),
                control: CGPoint(x: 0.50 * w, y: 0.78 * h)
            )
            context.stroke(smile, with: .color(nose), lineWidth: max(1, w * 0.04))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
