import SwiftUI

/// Shared type scale for the whole app. Keeping these values centralized avoids
/// chat, settings, cards and sidebars drifting into unrelated visual systems.
enum GrokTypography {
    static let bodySize: CGFloat = 15
    static let itemSize: CGFloat = 14
    static let metadataSize: CGFloat = 12.5

    static let body: Font = .system(size: bodySize)
    static let item: Font = .system(size: itemSize)
    static let metadata: Font = .system(size: metadataSize)

    static func item(_ weight: Font.Weight) -> Font { .system(size: itemSize, weight: weight) }
    static func metadata(_ weight: Font.Weight) -> Font { .system(size: metadataSize, weight: weight) }
}
