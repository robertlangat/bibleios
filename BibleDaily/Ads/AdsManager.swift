import AppTrackingTransparency
import GoogleMobileAds
import SwiftUI
import UIKit
import UserMessagingPlatform

/// Consent (Google UMP) → App Tracking Transparency prompt → Google Mobile Ads start →
/// banner + capped interstitials. Reading never depends on any of this.
@MainActor
final class AdsManager: NSObject, ObservableObject {
    static let shared = AdsManager()

    @Published private(set) var ready = false
    @Published private(set) var privacyOptionsRequired = false

    private var started = false
    private var trackingRequested = false
    private var interstitial: InterstitialAd?
    private var loadingInterstitial = false
    private var chapterChanges = 0
    private var lastFullScreen: Date?
    private var showingFullScreen = false

    func start() {
        guard !started else { return }
        started = true
        let info = ConsentInformation.shared
        info.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error { print("Consent info error: \(error.localizedDescription)") }
                ConsentForm.loadAndPresentIfRequired(from: UIApplication.topViewController()) { formError in
                    Task { @MainActor in
                        if let formError { print("Consent form error: \(formError.localizedDescription)") }
                        self.afterConsent()
                    }
                }
            }
        }
        // Consent from an earlier session lets ads start straight away.
        if info.canRequestAds { afterConsent() }
    }

    private func afterConsent() {
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        guard ConsentInformation.shared.canRequestAds else { return }
        guard !trackingRequested else { return }
        trackingRequested = true
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            ATTrackingManager.requestTrackingAuthorization { _ in
                Task { @MainActor in AdsManager.shared.startSDK() }
            }
        } else {
            startSDK()
        }
    }

    private func startSDK() {
        guard !ready else { return }
        MobileAds.shared.start(completionHandler: nil)
        ready = true
        loadInterstitial()
    }

    func showPrivacyOptions() {
        ConsentForm.presentPrivacyOptionsForm(from: UIApplication.topViewController()) { error in
            if let error { print("Privacy options error: \(error.localizedDescription)") }
        }
    }

    // MARK: Interstitial

    private func loadInterstitial() {
        guard ready, interstitial == nil, !loadingInterstitial else { return }
        loadingInterstitial = true
        InterstitialAd.load(with: AdConfig.interstitialUnitID, request: Request()) { ad, error in
            Task { @MainActor in
                let manager = AdsManager.shared
                manager.loadingInterstitial = false
                if let error {
                    print("Interstitial failed to load: \(error.localizedDescription)")
                    try? await Task.sleep(for: .seconds(60))
                    manager.loadInterstitial()
                    return
                }
                ad?.fullScreenContentDelegate = manager
                manager.interstitial = ad
            }
        }
    }

    /// Called when the reader moves to the previous/next chapter.
    func chapterChanged() {
        guard ready else { return }
        chapterChanges += 1
        guard let ad = interstitial else { loadInterstitial(); return }
        guard chapterChanges >= AdConfig.chaptersPerInterstitial, !showingFullScreen else { return }
        if let last = lastFullScreen, Date().timeIntervalSince(last) < AdConfig.minSecondsBetweenFullScreen { return }
        guard let vc = UIApplication.topViewController() else { return }
        chapterChanges = 0
        showingFullScreen = true
        ad.present(from: vc)
    }

    fileprivate func fullScreenFinished() {
        showingFullScreen = false
        lastFullScreen = Date()
        interstitial = nil
        loadInterstitial()
    }
}

extension AdsManager: FullScreenContentDelegate {
    nonisolated func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in AdsManager.shared.lastFullScreen = Date() }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in AdsManager.shared.fullScreenFinished() }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in AdsManager.shared.fullScreenFinished() }
    }
}

extension UIApplication {
    @MainActor
    static func topViewController() -> UIViewController? {
        let root = shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?.rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

// MARK: - Banner

/// Adaptive anchored banner. Takes no space until an ad has loaded (so it is invisible offline).
struct BannerSlot: View {
    @ObservedObject private var ads = AdsManager.shared
    @State private var loaded = false

    var body: some View {
        if ads.ready {
            let width = UIScreen.main.bounds.width
            let size = currentOrientationAnchoredAdaptiveBanner(width: width)
            BannerAdView(adSize: size, loaded: $loaded)
                .frame(width: width, height: loaded ? size.size.height : 0)
                .accessibilityIdentifier(loaded ? "ad_banner_loaded" : "ad_banner")
        }
    }
}

private struct BannerAdView: UIViewRepresentable {
    let adSize: AdSize
    @Binding var loaded: Bool

    func makeCoordinator() -> Coordinator { Coordinator(loaded: $loaded) }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = AdConfig.bannerUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIApplication.topViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    final class Coordinator: NSObject, BannerViewDelegate {
        var loaded: Binding<Bool>
        init(loaded: Binding<Bool>) { self.loaded = loaded }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            loaded.wrappedValue = true
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            loaded.wrappedValue = false
            print("Banner failed to load: \(error.localizedDescription)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak bannerView] in
                bannerView?.load(Request())
            }
        }
    }
}
