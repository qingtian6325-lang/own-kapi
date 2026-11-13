import SwiftUI

/// 问账条 / 聊天输入行的 ＋ 展开面板：相册 / 拍照 / 导入导出 三格大瓷砖。
/// 行为与 Kapi 一致：选图或拍照后走 AI 识别生成账单草稿，确认后才入账；
/// 导入导出接 App 已有的 CSV 导入导出功能（设置页「导入导出」区）。
public struct AIAttachmentPanelView: View {
    public var onPickFromAlbum: () -> Void
    public var onTakePhoto: () -> Void
    public var onOpenImportExport: () -> Void

    public init(
        onPickFromAlbum: @escaping () -> Void,
        onTakePhoto: @escaping () -> Void,
        onOpenImportExport: @escaping () -> Void
    ) {
        self.onPickFromAlbum = onPickFromAlbum
        self.onTakePhoto = onTakePhoto
        self.onOpenImportExport = onOpenImportExport
    }

    public var body: some View {
        HStack(spacing: 12) {
            tile(icon: "photo.on.rectangle", title: "相册", action: onPickFromAlbum)
            tile(icon: "camera", title: "拍照", action: onTakePhoto)
            tile(icon: "square.and.arrow.up", title: "导入导出", action: onOpenImportExport)
        }
    }

    private func tile(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .mimiFont(24, weight: .regular)
                    .foregroundColor(Color(hex: 0x6B7285))
                Text(title)
                    .mimiFont(13, weight: .medium)
                    .foregroundColor(MimiTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.92))
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
