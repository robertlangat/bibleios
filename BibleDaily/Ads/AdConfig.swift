import Foundation

/// AdMob IDs for Bible Daily iOS (publisher 8306955081407788).
/// The App ID is `GADApplicationIdentifier` in project.yml (Info.plist): ca-app-pub-8306955081407788~4913320752.
enum AdConfig {
    static let realBannerUnitID = "ca-app-pub-8306955081407788/9339203814"
    static let realInterstitialUnitID = "ca-app-pub-8306955081407788/8802971015"

    /// Google's iOS test units, used only when the app is launched with `-useTestAdUnits`
    /// (the automated UI test), so CI never requests real ads.
    static let testBannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let testInterstitialUnitID = "ca-app-pub-3940256099942544/4411468910"

    static var useTestUnits: Bool { ProcessInfo.processInfo.arguments.contains("-useTestAdUnits") }
    static var bannerUnitID: String { useTestUnits ? testBannerUnitID : realBannerUnitID }
    static var interstitialUnitID: String { useTestUnits ? testInterstitialUnitID : realInterstitialUnitID }

    /// Show an interstitial at most once every N previous/next chapter moves...
    static let chaptersPerInterstitial = 3
    /// ...and never within this many seconds of the last full-screen ad.
    static let minSecondsBetweenFullScreen: TimeInterval = 120
}
