import AppKit
import SwiftUI

/// NSTextView-backed composer that grows with its content and only becomes
/// scrollable after reaching the configured maximum height.
struct AutoGrowingTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    @Binding var isFocused: Bool
    var onSubmit: () -> Void
    var onPasteAttachments: ([URL]) -> Void = { _ in }
    var minHeight: CGFloat = 30
    var maxHeight: CGFloat = 138

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        let textView = AttachmentTextView()
        textView.onPasteAttachments = context.coordinator.handlePastedAttachments
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 3, height: 4)
        textView.font = .systemFont(ofSize: GrokTypography.bodySize)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }
        (textView as? AttachmentTextView)?.onPasteAttachments = context.coordinator.handlePastedAttachments
        if let replacement = context.coordinator.textSynchronization
            .replacement(forBinding: text, nativeText: textView.string,
                         isComposing: textView.hasMarkedText()) {
            textView.string = replacement
            context.coordinator.resize()
        }
        if isFocused, textView.window?.firstResponder !== textView {
            DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoGrowingTextEditor
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var textSynchronization = NativeTextSynchronization()

        init(parent: AutoGrowingTextEditor) { self.parent = parent }

        func textDidBeginEditing(_ notification: Notification) { parent.isFocused = true }
        func textDidEndEditing(_ notification: Notification) { parent.isFocused = false }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            let shouldPublish = textSynchronization.nativeTextDidChange(
                to: textView.string,
                isComposing: textView.hasMarkedText()
            )
            // Do not expose transient Chinese/Japanese IME marked text to
            // SwiftUI. The final committed candidate produces another change
            // notification and is synchronized normally.
            if shouldPublish { parent.text = textView.string }
            resize()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
            // Return must first confirm an active Chinese/Japanese IME candidate;
            // it is not a send command while marked text is still composing.
            if textView.hasMarkedText() { return false }
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true { return false }
            parent.onSubmit()
            return true
        }

        func handlePastedAttachments(_ urls: [URL]) {
            parent.onPasteAttachments(urls)
        }

        func resize() {
            guard let textView, let scrollView, let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            let width = max(scrollView.contentSize.width, 1)
            textContainer.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)
            let contentHeight = ceil(layoutManager.usedRect(for: textContainer).height + textView.textContainerInset.height * 2)
            let target = min(max(contentHeight, parent.minHeight), parent.maxHeight)
            let shouldScroll = contentHeight > parent.maxHeight + 0.5
            scrollView.hasVerticalScroller = shouldScroll
            if parent.height != target { DispatchQueue.main.async { self.parent.height = target } }
        }
    }
}

/// NSTextView normally drops file/image paste because the composer is plain
/// text. Capture those pasteboard payloads and hand them to the ACP attachment
/// pipeline; ordinary text paste still follows the native responder chain.
private final class AttachmentTextView: NSTextView {
    var onPasteAttachments: ([URL]) -> Void = { _ in }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        // A plain-text NSTextView considers an image-only pasteboard invalid,
        // so AppKit may disable Paste before paste(_:) reaches this subclass.
        // Advertise the attachment payload here while preserving native text
        // validation for ordinary clipboard content.
        if item.action == #selector(paste(_:)), hasPasteboardAttachments(NSPasteboard.general) {
            return true
        }
        return super.validateUserInterfaceItem(item)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.type == .keyDown,
           modifiers == .command,
           event.charactersIgnoringModifiers?.lowercased() == "v",
           consumePasteboardAttachments(NSPasteboard.general) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func paste(_ sender: Any?) {
        if consumePasteboardAttachments(NSPasteboard.general) { return }
        super.paste(sender)
    }

    private func hasPasteboardAttachments(_ pasteboard: NSPasteboard) -> Bool {
        if pasteboard.canReadObject(forClasses: [NSURL.self],
                                    options: [.urlReadingFileURLsOnly: true]) {
            return true
        }
        return pasteboard.availableType(from: imagePasteboardTypes) != nil
            || NSImage(pasteboard: pasteboard) != nil
    }

    private func consumePasteboardAttachments(_ pasteboard: NSPasteboard) -> Bool {
        // Finder exposes file selections as NSURL objects. Mapping explicitly
        // avoids relying on an NSArray -> [URL] conditional bridge, which can
        // fail even though the pasteboard contains valid file URLs.
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self],
                                           options: [.urlReadingFileURLsOnly: true]) as? [NSURL])?
            .map { $0 as URL } ?? []
        if !urls.isEmpty {
            onPasteAttachments(urls)
            return true
        }

        // Screenshot tools and browsers do not all advertise an NSImage-
        // readable representation. Preserve common raw image payloads first;
        // NSImage remains the fallback for other image pasteboard formats.
        if let attachment = rawImageAttachment(from: pasteboard) ?? renderedImageAttachment(from: pasteboard) {
            do {
                try FileManager.default.createDirectory(at: AppPaths.pastedAttachments,
                                                        withIntermediateDirectories: true)
                try attachment.data.write(to: attachment.url, options: .atomic)
                onPasteAttachments([attachment.url])
                return true
            } catch {
                NSSound.beep()
                return true
            }
        }
        return false
    }

    private var imagePasteboardTypes: [NSPasteboard.PasteboardType] {
        [.png,
         NSPasteboard.PasteboardType("public.jpeg"),
         NSPasteboard.PasteboardType("public.heic"),
         NSPasteboard.PasteboardType("public.webp"),
         .tiff]
    }

    private func rawImageAttachment(from pasteboard: NSPasteboard) -> (url: URL, data: Data)? {
        let fileExtensions = [
            "png",
            "jpg",
            "heic",
            "webp",
            "tiff"
        ]
        for (type, fileExtension) in zip(imagePasteboardTypes, fileExtensions) {
            guard let data = pasteboard.data(forType: type), !data.isEmpty else { continue }
            return (pastedImageURL(fileExtension: fileExtension), data)
        }
        return nil
    }

    private func renderedImageAttachment(from pasteboard: NSPasteboard) -> (url: URL, data: Data)? {
        guard let image = NSImage(pasteboard: pasteboard),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return (pastedImageURL(fileExtension: "png"), data)
    }

    private func pastedImageURL(fileExtension: String) -> URL {
        AppPaths.pastedAttachments
            .appendingPathComponent("粘贴图片-\(UUID().uuidString.prefix(8)).\(fileExtension)")
    }
}
