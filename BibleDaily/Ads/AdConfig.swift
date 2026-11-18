import Foundation

/// AdMob unit IDs. These are Google's official iOS TEST units, which are safe to load during
/// development. Before App Store release, create an iOS app in AdMob and replace:
///   1. `GADApplicationIdentifier` in project.yml (Info.plist) with your iOS AdMob App ID
///   2. the two unit IDs below with your iOS banner and interstitial unit IDs
/// (The Android unit IDs cannot be used on iOS.)
enum AdConfig {
    static let bannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"

    /// Show an interstitial at most once every N previous/next chapter moves...
    static let chaptersPerInterstitial = 3
    /// ...and never within this many seconds of the last full-screen ad.
    static let minSecondsBetweenFullScreen: TimeInterval = 120
}
