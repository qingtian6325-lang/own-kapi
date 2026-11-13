import SwiftUI
#if canImport(UIKit)
import UIKit

public struct UIKitImagePicker: UIViewControllerRepresentable {
    public enum SourceType {
        case camera
        case photoLibrary
    }

    public let sourceType: SourceType
    public let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(sourceType: SourceType, onImagePicked: @escaping (UIImage) -> Void) {
        self.sourceType = sourceType
        self.onImagePicked = onImagePicked
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        #if targetEnvironment(simulator)
        picker.sourceType = .photoLibrary
        #else
        if sourceType == .camera && UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        #endif
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    public class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: UIKitImagePicker

        init(_ parent: UIKitImagePicker) {
            self.parent = parent
        }

        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#if canImport(PhotosUI)
import PhotosUI

/// PHPicker 选图（系统相册选择器，无需相册权限），回调返回图片 Data。
public struct PHPickerImageView: UIViewControllerRepresentable {
    public let onImagePicked: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(onImagePicked: @escaping (Data) -> Void) {
        self.onImagePicked = onImagePicked
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    public class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerImageView

        init(_ parent: PHPickerImageView) {
            self.parent = parent
        }

        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.85) else {
                    return
                }
                DispatchQueue.main.async {
                    self.parent.onImagePicked(data)
                }
            }
        }
    }
}
#endif
#endif

public struct ReceiptViewerItem: Identifiable, Sendable {
    public let id = UUID()
    public let imageData: Data

    public init(imageData: Data) {
        self.imageData = imageData
    }
}

public struct FullscreenReceiptViewer: View {
    public let imageData: Data?
    public var onClose: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    public init(imageData: Data?, onClose: @escaping () -> Void) {
        self.imageData = imageData
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            #if canImport(UIKit)
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { val in
                                let delta = val / lastScale
                                lastScale = val
                                scale = min(max(scale * delta, 1.0), 4.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1.0 {
                                    withAnimation(MimiMotion.quick(reduceMotion: reduceMotion)) {
                                        scale = 1.0
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        scale > 1.0 ?
                        DragGesture()
                            .onChanged { val in
                                offset = CGSize(
                                    width: lastOffset.width + val.translation.width,
                                    height: lastOffset.height + val.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                        : nil
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(MimiMotion.quick(reduceMotion: reduceMotion)) {
                            if scale > 1.0 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                            }
                        }
                    }
                    .padding()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .mimiFont(48)
                        .foregroundColor(.white.opacity(0.6))
                    Text("无法加载小票大图")
                        .mimiFont(16, weight: .medium)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            #else
            Text("小票大图查看")
                .foregroundColor(.white)
            #endif

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .mimiFont(28)
                            .foregroundColor(.white.opacity(0.85))
                            .padding(20)
                    }
                }
                Spacer()
            }
        }
    }
}
