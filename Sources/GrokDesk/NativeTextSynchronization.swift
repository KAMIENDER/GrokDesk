/// Coordinates the short interval where NSTextView has accepted a keystroke
/// but SwiftUI has not rendered the corresponding Binding value yet.
struct NativeTextSynchronization {
    private(set) var lastBindingText = ""
    private var pendingNativeTexts: [String] = []

    @discardableResult
    mutating func nativeTextDidChange(to value: String, isComposing: Bool = false) -> Bool {
        // Marked text is owned by the input method. Publishing transient pinyin
        // through SwiftUI lets an unrelated stream render feed the stale
        // Binding back into NSTextView and dismiss the candidate window.
        guard !isComposing else { return false }
        if pendingNativeTexts.last != value { pendingNativeTexts.append(value) }
        return true
    }

    mutating func replacement(forBinding bindingText: String, nativeText: String,
                              isComposing: Bool = false) -> String? {
        // AppKit must remain the sole owner until the IME commits its candidate.
        guard !isComposing else { return nil }
        // SwiftUI can render one or more stale Binding snapshots between the
        // NSTextView edit and the matching State commit. A stream update makes
        // that race frequent; never push those snapshots back into NSTextView.
        if let synchronizedIndex = pendingNativeTexts.firstIndex(of: bindingText) {
            pendingNativeTexts.removeFirst(synchronizedIndex + 1)
            lastBindingText = bindingText
            return nil
        }
        if !pendingNativeTexts.isEmpty, bindingText == lastBindingText,
           nativeText == pendingNativeTexts.last {
            return nil
        }

        // A value outside the native edit queue is a real external mutation
        // (send cleared the draft, slash command insertion, etc.).
        pendingNativeTexts.removeAll()
        lastBindingText = bindingText
        return nativeText == bindingText ? nil : bindingText
    }
}
