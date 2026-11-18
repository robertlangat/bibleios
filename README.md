# Bible Daily for iOS

Bible Daily is a native iPhone Bible app written in Swift and SwiftUI. It's the iOS version of the [Bible Daily Android app](https://github.com/robertlangat/bible), with the same features, look and Bible text. Reading, search and your saved verses work fully offline from the first launch, and no account is needed.

- **Minimum iOS version:** 17.0 (iPhone)
- **Bundle ID:** `com.robertlangat.bibledaily`
- **Version:** 1.0.0 (build 1)

## Features

| Tab | What it does |
|---|---|
| **Home** | The verse of the day, chosen from the phone's local date, with Read chapter, Copy and Share. Below it are a "Continue reading" shortcut, the daily reminder status, and a Settings (gear) button. |
| **Read** | Tap the title to pick a Testament, book and chapter. The bottom bar moves to the previous or next chapter (across books). The app remembers your position, and `A−`/`A+` change the text size. Tap a verse to bookmark, highlight (4 colours), add a note, copy or share it. |
| **Search** | Offline search by reference (`John 3:16`, `Jn 3:16`, `Psalm 23`, `1 Cor 13:4-7`), word (`shepherd`), phrase (`love one another`) or exact phrase (`"born anew"`). Tapping a result opens the chapter at that verse. |
| **Saved** | Your bookmarks, highlights and notes, stored only on the iPhone. Swipe or tap the bin icon to remove one. |

Settings has the light (default: white with black text), dark and phone theme, text size, the daily reminder (a time picker plus a test button), and the Bible edition and attribution. Copied and shared verses include the reference and translation, for example `… — John 3:16 (World English Bible, WEB)`.

Accessibility: every button has a VoiceOver label, and each verse is read as one item ("John 3:16. For God so loved… Bookmarked. Has note").

## Bible text

The app bundles the **World English Bible (WEB)**, which is in the **Public Domain**: 66 books and 31,098 verses, from the eBible.org `eng-web` USFX edition via [seven1m/open-bibles](https://github.com/seven1m/open-bibles). The attribution reads: "The World English Bible is in the Public Domain. That means that it is not copyrighted. However, 'World English Bible' is a Trademark of eBible.org." It is also shown in Settings › About this Bible.

The text is in `BibleDaily/Resources/bible.sqlite`, a read-only file built by `scripts/build_bible_db.py` from `data/eng-web.tsv.gz`. That's the same data and the same search normalisation as the Android app.

**Adding Kiswahili later:**
1. Add its verses to the database under a new translation id.
2. Add a `Translation` in `BibleDaily/Data/Translations.swift` with its 66 book names.

Bookmarks, highlights and notes are keyed by book, chapter and verse, so they carry over between translations.

## Ads (AdMob): currently Google TEST ads

| | ID | Where |
|---|---|---|
| App ID | `ca-app-pub-3940256099942544~1458002511` (Google test) | `GADApplicationIdentifier` in `project.yml` |
| Banner | `ca-app-pub-3940256099942544/2435281174` (Google test) | `BibleDaily/Ads/AdConfig.swift` |
| Interstitial | `ca-app-pub-3940256099942544/4411468910` (Google test) | `BibleDaily/Ads/AdConfig.swift` |

How the ads behave:
- **Banner:** sits above the tab bar, and takes no space until an ad loads.
- **Interstitial:** at most once every 3 chapter moves, and at least 2 minutes apart.
- **Consent:** the app runs Google's consent prompt, then Apple's App Tracking Transparency prompt, before any ads load.

**Before App Store release:**
1. Create an **iOS** app in AdMob. Your Android ad units don't work on iPhone.
2. Replace the three test IDs above with the new iOS App ID and unit IDs.
3. Add Google's full `SKAdNetworkItems` list to `project.yml`.
4. Create the consent messages in AdMob › Privacy & messaging.

## Build

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). CI also commits the generated `BibleDaily.xcodeproj`, so you can usually open that directly.

```bash
brew install xcodegen
xcodegen generate
open BibleDaily.xcodeproj
```

The app needs Xcode 16 or newer. Swift Package Manager fetches Google Mobile Ads and Google's User Messaging Platform automatically.

**Tests:** `xcodebuild test -scheme BibleDaily -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` runs:
- **Unit tests:** reference parser, search, sharing, verse of the day, and checks that the bundled Bible is complete.
- **UI tests:**
  - first launch
  - chapter navigation and the book picker
  - `John 3:16`, `Jn 3:16`, `Psalm 23` and phrase search
  - the share sheet
  - a bookmark, highlight and note surviving a full app restart, along with the reading position
  - dark mode

On every push to `main`, GitHub Actions (`.github/workflows/ios.yml`, macOS runner) builds the app, runs all tests on an iPhone simulator, and builds an unsigned Release archive for real iPhones. It then publishes the test screenshots to the `ios-ci-artifacts` branch.

## Putting it on an iPhone / the App Store

Apple requires an **Apple Developer Program** membership ($99 a year) to install the app on a real iPhone (TestFlight) or to publish it. There's no sideloadable file like an Android APK. Once you have a membership:

1. In App Store Connect, create an app with bundle ID `com.robertlangat.bibledaily`.
2. In Xcode, open `BibleDaily.xcodeproj`, choose your Team in Signing & Capabilities (or set `DEVELOPMENT_TEAM` in `project.yml`), then **Product › Archive** and **Distribute App › App Store Connect**.
3. In App Store Connect, add the privacy details:
   - The app uses the advertising ID for ads, and doesn't collect any other data.
   - Use the same privacy policy as Android: <https://github.com/robertlangat/bible/blob/main/PRIVACY.md>
4. Add screenshots, then submit for review.

CI can also sign and upload to TestFlight automatically if you add an App Store Connect API key and signing certificate as GitHub secrets.
