import SwiftUI

/// Wraps the named colors/icons in Resources/Assets.xcassets. These resolve correctly
/// only when built through VizRemote.xcodeproj (Xcode's actool compiles the catalog into
/// the app bundle) — plain `swift build` just copies the raw catalog folder without
/// compiling it, so these lookups silently fail to resolve there. Build via Xcode/
/// `xcodebuild`, not `swift build`, to see real colors/icons.
enum Theme {
    static let background = Color("Background")
    static let sidebar = Color("Sidebar")
    static let insetSurface = Color("InsetSurface")
    static let keyFaceTop = Color("KeyFaceTop")
    static let keyFaceBottom = Color("KeyFaceBottom")
    static let keyBorder = Color("KeyBorder")
    static let keyGlyph = Color("KeyGlyph")
    static let keyHover = Color("KeyHover")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let sectionLabel = Color("SectionLabel")
    static let divider = Color("Divider")
    static let powerGlyph = Color("PowerGlyph")
    static let powerFaceTop = Color("PowerFaceTop")
    static let powerFaceBottom = Color("PowerFaceBottom")
    static let powerBorder = Color("PowerBorder")
    static let statusConnected = Color("StatusConnected")
    static let statusUnreachable = Color("StatusUnreachable")
    static let accent = Color("Accent")
    static let accentText = Color("AccentText")
    static let chipActiveFill = Color("ChipActiveFill")
    static let chipActiveText = Color("ChipActiveText")
    static let chipIdleFill = Color("ChipIdleFill")
    static let volumeSegmentLit = Color("VolumeSegmentLit")
    static let volumeSegmentDim = Color("VolumeSegmentDim")
    static let card = Color("Card")
    static let destructive = Color("Destructive")
    static let fieldBorder = Color("FieldBorder")
    static let okFaceTop = Color("OKFaceTop")
    static let okFaceBottom = Color("OKFaceBottom")
    static let searchRing = Color("SearchRing")

    static let keyFace = LinearGradient(colors: [keyFaceTop, keyFaceBottom], startPoint: .top, endPoint: .bottom)
    static let powerFace = LinearGradient(colors: [powerFaceTop, powerFaceBottom], startPoint: .top, endPoint: .bottom)
    static let okFace = LinearGradient(colors: [okFaceTop, okFaceBottom], startPoint: .top, endPoint: .bottom)

    enum Icon: String {
        case back = "icon.back"
        case chevronDown = "icon.chevron.down"
        case chevronLeft = "icon.chevron.left"
        case chevronRight = "icon.chevron.right"
        case chevronUp = "icon.chevron.up"
        case home = "icon.home"
        case menu = "icon.menu"
        case menubarRemote = "icon.menubar.remote"
        case minus = "icon.minus"
        case plus = "icon.plus"
        case power = "icon.power"
        case refresh = "icon.refresh"
        case settings = "icon.settings"
        case speaker = "icon.speaker"
        case speakerMuted = "icon.speaker.muted"
        case tv = "icon.tv"
    }

    static func icon(_ name: Icon) -> Image {
        Image(name.rawValue)
    }
}
