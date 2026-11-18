import SwiftUI
import UserNotifications

/// Launch arguments used by the UI tests: `-resetData` (fresh install state) and `-disableAds`.
enum LaunchOptions {
    static let args = ProcessInfo.processInfo.arguments
    static let resetData = args.contains("-resetData")
    static let disableAds = args.contains("-disableAds")
}

@main
struct BibleDailyApp: App {
    @StateObject private var settings: SettingsStore
    @StateObject private var marks: MarksStore
    @StateObject private var state: AppState
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let s = SettingsStore(reset: LaunchOptions.resetData)
        _settings = StateObject(wrappedValue: s)
        _marks = StateObject(wrappedValue: MarksStore(reset: LaunchOptions.resetData))
        _state = StateObject(wrappedValue: AppState(settings: s))
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(marks)
                .environmentObject(state)
                .preferredColorScheme(settings.theme.colorScheme)
                .tint(.primary)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                state.refreshDate()
                // Keep the next 30 days of reminders topped up.
                let (on, h, m, t) = (settings.reminderEnabled, settings.reminderHour, settings.reminderMinute, settings.translation)
                Task { await Reminders.reschedule(enabled: on, hour: h, minute: m, translation: t) }
            }
        }
    }
}

/// Navigation state shared by the tabs (which tab is showing, what the reader shows).
@MainActor
final class AppState: ObservableObject {
    enum Tab: Hashable { case home, read, search, saved }

    struct ScrollTarget: Equatable {
        let book: Int
        let chapter: Int
        let verse: Int
        let token = UUID()
    }

    @Published var tab: Tab = .home
    @Published private(set) var book: Int
    @Published private(set) var chapter: Int
    @Published var scrollTarget: ScrollTarget?
    @Published private(set) var today = Date()
    /// Verses of the chapter currently in the reader (loaded here so they never go stale).
    @Published private(set) var verses: [Verse] = []
    @Published private(set) var loadedKey = ""
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
        let b = Books.bookOrNil(settings.lastBook) != nil ? settings.lastBook : 1
        book = b
        chapter = min(max(settings.lastChapter, 1), Books.book(b).chapters)
        scrollTarget = ScrollTarget(book: book, chapter: chapter, verse: max(settings.lastVerse, 1))
        loadVerses()
    }

    var chapterKey: String { "\(book)-\(chapter)" }

    private func loadVerses() {
        verses = BibleStore.shared.chapter(settings.translationId, book: book, chapter: chapter)
        loadedKey = chapterKey
    }

    /// Opens a chapter in the reader (scrolled to `verse`) and switches to the Read tab.
    func open(book: Int, chapter: Int, verse: Int? = nil, switchTab: Bool = true) {
        self.book = book
        self.chapter = chapter
        loadVerses()
        scrollTarget = ScrollTarget(book: book, chapter: chapter, verse: verse ?? 1)
        settings.savePosition(book: book, chapter: chapter, verse: verse ?? 1)
        if switchTab { tab = .read }
    }

    func next() {
        if let n = Books.next(book: book, chapter: chapter) { open(book: n.book, chapter: n.chapter, switchTab: false) }
    }

    func previous() {
        if let p = Books.previous(book: book, chapter: chapter) { open(book: p.book, chapter: p.chapter, switchTab: false) }
    }

    func refreshDate() { today = Date() }
}

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var ads = AdsManager.shared

    var body: some View {
        TabView(selection: $state.tab) {
            HomeView().withBanner()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppState.Tab.home)
            ReaderView().withBanner()
                .tabItem { Label("Read", systemImage: "book") }
                .tag(AppState.Tab.read)
            SearchView().withBanner()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(AppState.Tab.search)
            SavedView().withBanner()
                .tabItem { Label("Saved", systemImage: "bookmark") }
                .tag(AppState.Tab.saved)
        }
        .task {
            if !LaunchOptions.disableAds { ads.start() }
        }
    }
}

extension View {
    /// Adds the adaptive banner just above the tab bar (takes no space until an ad loads).
    func withBanner() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { BannerSlot() }
    }
}
