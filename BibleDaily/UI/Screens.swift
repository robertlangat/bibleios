import SwiftUI

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    verseOfTheDay
                    continueReading
                    reminderCard
                    Text("\(settings.translation.name) (\(settings.translation.abbreviation)) · \(settings.translation.license). Reading and search work offline.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .navigationTitle("Bible Daily")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("open_settings")
                }
            }
        }
    }

    private var verseOfTheDay: some View {
        let t = settings.translation
        let ref = VerseOfDay.reference(for: state.today)
        let label = ref.label(t.bookName(ref.book))
        let text = BibleStore.shared.verse(t.id, book: ref.book.number, chapter: ref.chapter, verse: ref.verse ?? 1)?.text ?? ""
        let share = ShareText.format(text: text, reference: label, translation: t)
        return OutlinedCard(strong: true) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verse of the day").font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    Text(state.today.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(text)
                    .font(.system(size: settings.textSize + 1)).italic()
                    .accessibilityIdentifier("votd_text")
                Text("\(label) (\(t.abbreviation))").font(.headline).accessibilityIdentifier("votd_ref")
                HStack(spacing: 18) {
                    Button("Read chapter") { state.open(book: ref.book.number, chapter: ref.chapter, verse: ref.verse) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("votd_read")
                    Button { copyToClipboard(share) } label: { Image(systemName: "doc.on.doc") }
                        .accessibilityLabel("Copy verse of the day")
                    ShareLink(item: share) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share verse of the day")
                        .accessibilityIdentifier("votd_share")
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private var continueReading: some View {
        let label = settings.hasPosition
            ? "\(settings.translation.bookName(Books.book(settings.lastBook))) \(max(settings.lastChapter, 1))"
            : "Genesis 1"
        return Button { state.tab = .read } label: {
            OutlinedCard {
                HStack(spacing: 16) {
                    Image(systemName: "book").font(.title2)
                    VStack(alignment: .leading) {
                        Text(settings.hasPosition ? "Continue reading" : "Start reading").font(.subheadline)
                        Text(label).font(.title3)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue reading, \(label)")
        .accessibilityIdentifier("continue_reading")
    }

    private var reminderCard: some View {
        OutlinedCard {
            HStack(spacing: 16) {
                Image(systemName: "bell").font(.title2)
                VStack(alignment: .leading) {
                    Text("Daily reminder").font(.subheadline)
                    Text(settings.reminderEnabled ? "On at \(timeString(settings.reminderHour, settings.reminderMinute))" : "Off")
                        .font(.headline)
                }
                Spacer()
                NavigationLink("Change") { SettingsView() }.buttonStyle(.bordered)
            }
        }
    }
}

func timeString(_ hour: Int, _ minute: Int) -> String {
    let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    return date.formatted(date: .omitted, time: .shortened)
}

// MARK: - Search

struct SearchView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: SettingsStore
    @State private var query = ""
    @State private var results: SearchResults?
    @State private var searching = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("John 3:16, Psalm 23, love one another", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .accessibilityLabel("Search words, phrases or references")
                            .accessibilityIdentifier("search_field")
                        if !query.isEmpty {
                            Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary, lineWidth: 1))
                    .listRowSeparator(.hidden)
                }
                if let r = results {
                    Section {
                        Text(summary(r)).font(.subheadline.weight(.semibold))
                            .accessibilityIdentifier("search_summary")
                            .listRowSeparator(.hidden)
                        if let hit = r.reference {
                            Button {
                                state.open(book: hit.reference.book.number, chapter: hit.reference.chapter, verse: hit.reference.verse)
                            } label: {
                                OutlinedCard(strong: true) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(hit.label).font(.headline)
                                        Text(hit.preview).lineLimit(4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(hit.label). \(hit.preview)")
                            .accessibilityHint("Opens the chapter")
                            .accessibilityIdentifier("ref_result")
                            .listRowSeparator(.hidden)
                        }
                        ForEach(r.verses) { v in
                            let label = "\(settings.translation.bookName(Books.book(v.book))) \(v.chapter):\(v.verse)"
                            Button { state.open(book: v.book, chapter: v.chapter, verse: v.verse) } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(label).font(.subheadline.bold())
                                    Text(emphasized(v.text, r.terms))
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("result_\(v.book)_\(v.chapter)_\(v.verse)")
                        }
                    }
                } else if !searching {
                    Text("Search the \(settings.translation.name) offline. Try a reference like “John 3:16”, “Jn 3:16” or “Psalm 23”, a word like “shepherd”, or a phrase like “love one another”. Put a phrase in quotes to match it exactly.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .overlay { if searching { ProgressView() } }
            .navigationTitle("Search")
            .task(id: query) {
                let q = query
                results = nil
                guard !q.trimmingCharacters(in: .whitespaces).isEmpty else { searching = false; return }
                searching = true
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
                let t = settings.translation
                let r = await Task.detached(priority: .userInitiated) { BibleStore.shared.search(t, q) }.value
                if Task.isCancelled { return }
                results = r
                searching = false
            }
        }
    }

    private func summary(_ r: SearchResults) -> String {
        if r.reference != nil && r.verses.isEmpty { return "Reference found" }
        if r.verses.isEmpty { return "No results for “\(r.query)”" }
        if r.truncated { return "Showing the first \(r.verses.count) verses" }
        return "\(r.verses.count) verse\(r.verses.count == 1 ? "" : "s") found"
    }

    /// Bolds the start-of-word occurrences of the search terms.
    private func emphasized(_ text: String, _ terms: [String]) -> AttributedString {
        var a = AttributedString(text)
        let lower = text.lowercased()
        for term in terms where !term.isEmpty {
            var start = lower.startIndex
            while let r = lower.range(of: term, range: start..<lower.endIndex) {
                let atWordStart = r.lowerBound == lower.startIndex || !(lower[lower.index(before: r.lowerBound)].isLetter || lower[lower.index(before: r.lowerBound)].isNumber)
                if atWordStart,
                   let lo = AttributedString.Index(r.lowerBound, within: a),
                   let hi = AttributedString.Index(r.upperBound, within: a) {
                    a[lo..<hi].inlinePresentationIntent = .stronglyEmphasized
                }
                start = r.upperBound
            }
        }
        return a
    }
}

// MARK: - Saved

struct SavedView: View {
    enum Kind: String, CaseIterable, Identifiable { case bookmarks = "Bookmarks", highlights = "Highlights", notes = "Notes"; var id: String { rawValue } }
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var marks: MarksStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var kind: Kind = .bookmarks

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Saved items", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()
                let items = kind == .bookmarks ? marks.bookmarks : kind == .highlights ? marks.highlights : marks.notes
                if items.isEmpty {
                    Text(emptyText).font(.subheadline).foregroundStyle(.secondary).padding()
                    Spacer()
                } else {
                    List {
                        ForEach(items) { m in row(m) }
                            .onDelete { idx in idx.map { items[$0] }.forEach(remove) }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Saved")
        }
    }

    private var emptyText: String {
        switch kind {
        case .bookmarks: "No bookmarks yet. Tap a verse while reading and choose Bookmark."
        case .highlights: "No highlights yet. Tap a verse while reading and pick a colour."
        case .notes: "No notes yet. Tap a verse while reading and choose Note."
        }
    }

    private func row(_ m: VerseMark) -> some View {
        let t = settings.translation
        let label = "\(t.bookName(Books.book(m.key.book))) \(m.key.chapter):\(m.key.verse)"
        let text = BibleStore.shared.verse(t.id, book: m.key.book, chapter: m.key.chapter, verse: m.key.verse)?.text ?? ""
        return HStack(alignment: .top, spacing: 12) {
            if let c = Highlight.color(m.highlight, dark: colorScheme == .dark) {
                Circle().fill(c).frame(width: 14, height: 14).padding(.top, 4)
            }
            Button { state.open(book: m.key.book, chapter: m.key.chapter, verse: m.key.verse) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label).font(.headline)
                    if kind == .notes, let n = m.note { Text(n).italic() }
                    Text(text).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("saved_item")
            Button(role: .destructive) { remove(m) } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(kind.rawValue.lowercased().dropLast()) for \(label)")
        }
    }

    private func remove(_ m: VerseMark) {
        marks.update(m.key) {
            switch kind {
            case .bookmarks: $0.bookmarked = false
            case .highlights: $0.highlight = 0
            case .notes: $0.note = nil
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @ObservedObject private var ads = AdsManager.shared
    @State private var permissionDenied = false

    private var reminderTime: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: settings.reminderHour, minute: settings.reminderMinute)) ?? Date() },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                settings.reminderHour = c.hour ?? 7
                settings.reminderMinute = c.minute ?? 0
                reschedule()
            })
    }

    private var reminderOn: Binding<Bool> {
        Binding(get: { settings.reminderEnabled }, set: { on in
            if on {
                Task {
                    if await Reminders.requestPermission() {
                        settings.reminderEnabled = true
                        permissionDenied = false
                        reschedule()
                    } else {
                        permissionDenied = true
                    }
                }
            } else {
                settings.reminderEnabled = false
                reschedule()
            }
        })
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $settings.theme) {
                    ForEach(ThemeMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("theme_picker")
            }
            Section("Text size") {
                Slider(value: $settings.textSize, in: SettingsStore.minText...SettingsStore.maxText, step: 1) {
                    Text("Text size")
                } minimumValueLabel: { Text("A").font(.caption) } maximumValueLabel: { Text("A").font(.title2) }
                    .accessibilityValue("\(Int(settings.textSize)) points")
                Text("In the beginning, God created the heavens and the earth.")
                    .font(.system(size: settings.textSize))
            }
            Section {
                Toggle("Remind me every day", isOn: reminderOn).accessibilityIdentifier("reminder_switch")
                DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                if permissionDenied {
                    Text("Notifications are turned off for Bible Daily. Allow them in the iPhone Settings app › Notifications › Bible Daily.")
                        .font(.footnote).foregroundStyle(.red)
                }
                Button("Send a test reminder now") {
                    Task {
                        if await Reminders.requestPermission() { await Reminders.sendTest(translation: settings.translation) }
                        else { permissionDenied = true }
                    }
                }
            } header: { Text("Daily reminder") } footer: { Text("Shows the verse of the day as a notification.") }
            if ads.privacyOptionsRequired {
                Section("Ads") {
                    Button("Ad privacy choices") { ads.showPrivacyOptions() }
                }
            }
            Section("About this Bible") {
                let t = settings.translation
                Text("\(t.name) (\(t.abbreviation)) · \(t.languageName)").font(.headline)
                Text(t.editionNote)
                Text("License: \(t.license)")
                Text("Source: \(t.source)")
                Link(t.sourceURL, destination: URL(string: t.sourceURL)!)
                Text(t.attribution).font(.footnote).accessibilityIdentifier("attribution")
            }
            Section("About Bible Daily") {
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""). Reading, search and saved items work fully offline with no account. Bookmarks, highlights, notes and settings are stored only on this iPhone. The internet is used only to show ads from Google AdMob.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reschedule() {
        let (on, h, m, t) = (settings.reminderEnabled, settings.reminderHour, settings.reminderMinute, settings.translation)
        Task { await Reminders.reschedule(enabled: on, hour: h, minute: m, translation: t) }
    }
}
