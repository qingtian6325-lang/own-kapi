import SwiftUI

/// 问账条 / 聊天输入行的 ＋ 展开面板：相册 / 拍照 / 导入导出 三格大瓷砖。
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
                    .foregroundColor(MimiTheme.textSecondary)
                    .accessibilityHidden(true)
                Text(title)
                    .mimiFont(13, weight: .medium)
                    .foregroundColor(MimiTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 84)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(MimiTheme.fillSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(MimiTheme.strokeSubtle, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .mimiPressable()
        .accessibilityLabel(title)
    }
}
