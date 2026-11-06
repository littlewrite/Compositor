import UIKit
import PhotosUI
import Combine
import UniformTypeIdentifiers
import CompositorCore

/// The iPad's answer to `PlatformServices`. UIKit lives here and nowhere below it.
@MainActor
final class PadPlatform: PlatformServices {
    let capabilities = PlatformCapabilities(
        hasHoverPointer: false,
        hasHardwareKeyboard: true,
        supportsPencilPressure: true,
        showsPointerCursor: false)

    let modifiers: ModifierStrategy = StickyModifiers()
    let haptics: HapticsStrategy = PadHaptics()
    let files: FileStrategy = PadFiles()
}

/// A finger cannot hold ⌥ down while drawing, so the iPad offers them as toggles.
@MainActor
final class StickyModifiers: ObservableObject, ModifierStrategy {
    @Published private(set) var active: ModifierSet = []
    let offersOnScreenModifiers = true

    func toggle(_ modifier: ModifierSet) {
        if active.contains(modifier) {
            active.remove(modifier)
        } else {
            active.insert(modifier)
        }
    }

    func clear() { active = [] }
}

@MainActor
final class PadHaptics: HapticsStrategy {
    func selectionChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func impact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// Files arrive through the system picker, and stay on disk so RAW can be developed rather than
/// read as bytes.
@MainActor
final class PadFiles: NSObject, FileStrategy, UIDocumentPickerDelegate, PHPickerViewControllerDelegate {
    private var continuation: CheckedContinuation<URL?, Never>?
    private var photoContinuation: CheckedContinuation<URL?, Never>?

    func pickImage() async -> URL? {
        guard let presenter = Self.topViewController() else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            var types: [UTType] = [.image]
            if let raw = UTType("public.camera-raw-image") { types.append(raw) }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
            picker.delegate = self
            presenter.present(picker, animated: true)
        }
    }

    /// The photo library is where pictures usually live on a phone. The picker runs out of process,
    /// so it needs no photo-library permission; the chosen item is copied out because the URL the
    /// item provider hands over is deleted as soon as its completion returns.
    func pickImageFromPhotos() async -> URL? {
        guard let presenter = Self.topViewController() else { return nil }
        return await withCheckedContinuation { continuation in
            photoContinuation = continuation
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            presenter.present(picker, animated: true)
        }
    }

    func save(_ data: Data, suggestedName: String) async -> Bool {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(suggestedName)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return false
        }
        guard let presenter = Self.topViewController() else { return false }

        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                        y: presenter.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activity, animated: true)
        return true
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        continuation?.resume(returning: urls.first)
        continuation = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        continuation?.resume(returning: nil)
        continuation = nil
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else {
            finishPhotos(with: nil)
            return
        }
        let type = provider.registeredTypeIdentifiers.first {
            UTType($0)?.conforms(to: .image) == true
        } ?? provider.registeredTypeIdentifiers.first ?? UTType.image.identifier

        provider.loadFileRepresentation(forTypeIdentifier: type) { [weak self] url, _ in
            var copied: URL?
            if let url {
                // The item provider's URL dies with this completion, so copy it out. A named file
                // in a unique folder gives the imported layer a readable name.
                let folder = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let destination = folder.appendingPathComponent("Photo")
                    .appendingPathExtension(url.pathExtension)
                if (try? FileManager.default.copyItem(at: url, to: destination)) != nil {
                    copied = destination
                }
            }
            Task { @MainActor in self?.finishPhotos(with: copied) }
        }
    }

    private func finishPhotos(with url: URL?) {
        photoContinuation?.resume(returning: url)
        photoContinuation = nil
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var controller = scene?.keyWindow?.rootViewController else { return nil }
        while let presented = controller.presentedViewController {
            controller = presented
        }
        return controller
    }
}
