@main
enum NativeTextSynchronizationRegression {
    static func main() {
        var synchronization = NativeTextSynchronization()
        require(synchronization.replacement(forBinding: "", nativeText: "") == nil,
                "equal initial state must not replace native text")

        synchronization.nativeTextDidChange(to: "你")
        require(synchronization.replacement(forBinding: "", nativeText: "你") == nil,
                "a streamed refresh replaced the native edit with a stale Binding")
        synchronization.nativeTextDidChange(to: "你好")
        require(synchronization.replacement(forBinding: "你", nativeText: "你好") == nil,
                "an intermediate Binding commit replaced a newer native edit")
        require(synchronization.replacement(forBinding: "你好", nativeText: "你好") == nil,
                "the final Binding commit must only acknowledge the native edit")

        var chineseIME = NativeTextSynchronization()
        require(chineseIME.nativeTextDidChange(to: "ni", isComposing: true) == false,
                "marked text must stay native until the Chinese IME commits a candidate")
        require(chineseIME.replacement(forBinding: "", nativeText: "ni", isComposing: true) == nil,
                "a streamed refresh interrupted Chinese IME marked text")
        require(chineseIME.nativeTextDidChange(to: "你") == true,
                "the committed Chinese candidate must publish to SwiftUI")
        require(chineseIME.replacement(forBinding: "", nativeText: "你") == nil,
                "a stream refresh replaced the newly committed Chinese candidate")
        require(chineseIME.replacement(forBinding: "你", nativeText: "你") == nil,
                "the committed Chinese candidate did not synchronize cleanly")

        var stressed = NativeTextSynchronization()
        var binding = ""
        var native = ""
        for index in 0..<1_000 {
            native.append(String(index % 10))
            stressed.nativeTextDidChange(to: native)
            require(stressed.replacement(forBinding: binding, nativeText: native) == nil,
                    "stream refresh interrupted native input at iteration \(index)")
            binding = native
            require(stressed.replacement(forBinding: binding, nativeText: native) == nil,
                    "Binding synchronization replaced native input at iteration \(index)")
        }

        var externalChange = NativeTextSynchronization()
        require(externalChange.replacement(forBinding: "hello", nativeText: "hello") == nil,
                "equal synchronized state must remain unchanged")
        require(externalChange.replacement(forBinding: "", nativeText: "hello") == "",
                "an external Binding clear must still replace native text")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
}
