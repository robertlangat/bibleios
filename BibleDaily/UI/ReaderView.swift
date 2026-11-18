import SwiftUI

struct ReaderView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var marks: MarksStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var showPicker = false
    @State private var actionVerse: Verse?
    @State private var noteVerse: Verse?
    @State private var pendingNote: Verse?
    @State private var lastNoted: Verse?
    @State private var visible = Set<Int>()

    private var translation: Translation { settings.translation }
    private var bookName: String { translation.bookName(Books.book(state.book)) }
    private var title: String { "\(bookName) \(state.chapter)" }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.title2.bold())
                            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
                            .accessibilityAddTraits(.isHeader)
                            .id("top-\(state.chapterKey)")
                        ForEach(state.verses) { v in
                            VerseRow(verse: v, reference: "\(bookName) \(v.chapter):\(v.verse)",
                                     mark: marks.mark(VerseKey(book: v.book, chapter: v.chapter, verse: v.verse)),
                                     size: settings.textSize, dark: colorScheme == .dark)
                                .id(v.id)
                                .onTapGesture { actionVerse = v }
                                .onAppear { visible.insert(v.verse) }
                                .onDisappear { visible.remove(v.verse) }
                        }
                        Divider().padding(.top, 16)
                        Text("\(translation.name) (\(translation.abbreviation)) · \(translation.license)")
                            .font(.footnote).foregroundStyle(.secondary)
                            .padding(16)
                    }
                    // A fresh layout per chapter, so rows of the previous chapter are never reused.
                    .id(state.loadedKey)
                }
                .onChange(of: state.scrollTarget) { scroll(proxy) }
                .onChange(of: state.loadedKey) {
                    visible = []
                    scroll(proxy)
                }
                .onAppear { scroll(proxy) }
            }
            .task(id: visible.min()) {
                // Remember the first visible verse as the reading position.
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled, state.scrollTarget == nil, let v = visible.min(), state.loadedKey == state.chapterKey else { return }
                settings.savePosition(book: state.book, chapter: state.chapter, verse: v)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button { showPicker = true } label: {
                        HStack(spacing: 4) {
                            Text(title).font(.headline)
                            Image(systemName: "chevron.down").font(.caption.bold())
                        }
                        .foregroundStyle(.primary)
                    }
                    .accessibilityLabel(title)
                    .accessibilityHint("Choose book and chapter")
                    .accessibilityIdentifier("reader_title")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("A−") { settings.setTextSize(settings.textSize - 2) }
                        .disabled(settings.textSize <= SettingsStore.minText)
                        .accessibilityLabel("Decrease text size")
                    Button("A+") { settings.setTextSize(settings.textSize + 2) }
                        .disabled(settings.textSize >= SettingsStore.maxText)
                        .accessibilityLabel("Increase text size")
                }
            }
            // Chapter controls and the banner share one inset so the ad can never cover the controls.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    chapterBar
                    BannerSlot()
                }
            }
            .sheet(isPresented: $showPicker) {
                BookPicker(translation: translation, currentBook: state.book) { b, c in
                    showPicker = false
                    state.open(book: b, chapter: c, switchTab: false)
                }
            }
            .sheet(item: $actionVerse, onDismiss: {
                if let p = pendingNote { pendingNote = nil; lastNoted = p; noteVerse = p }
            }) { v in
                let ref = "\(bookName) \(v.chapter):\(v.verse)"
                VerseActionsSheet(verse: v, reference: ref,
                                  shareText: ShareText.format(text: v.text, reference: ref, translation: translation)) {
                    pendingNote = v
                    actionVerse = nil
                }
            }
            .sheet(item: $noteVerse, onDismiss: {
                // Return to the annotated verse (the list can lose its place behind the keyboard).
                if let v = lastNoted { state.scrollTarget = AppState.ScrollTarget(book: v.book, chapter: v.chapter, verse: v.verse) }
            }) { v in
                let key = VerseKey(book: v.book, chapter: v.chapter, verse: v.verse)
                NoteEditor(reference: "\(bookName) \(v.chapter):\(v.verse)", initial: marks.mark(key)?.note ?? "") { note in
                    marks.update(key) { $0.note = note }
                }
            }
        }
    }

    private var chapterBar: some View {
        let prev = Books.previous(book: state.book, chapter: state.chapter)
        let next = Books.next(book: state.book, chapter: state.chapter)
        func label(_ p: (book: Int, chapter: Int)?) -> String {
            guard let p else { return "" }
            return "\(translation.bookName(Books.book(p.book))) \(p.chapter)"
        }
        return HStack {
            Button {
                state.previous()
                AdsManager.shared.chapterChanged()
            } label: { Label(label(prev), systemImage: "chevron.left") }
                .disabled(prev == nil)
                .accessibilityLabel("Previous chapter, \(label(prev))")
                .accessibilityIdentifier("prev_chapter")
            Spacer()
            Button {
                state.next()
                AdsManager.shared.chapterChanged()
            } label: {
                HStack(spacing: 4) { Text(label(next)); Image(systemName: "chevron.right") }
            }
                .disabled(next == nil)
                .accessibilityLabel("Next chapter, \(label(next))")
                .accessibilityIdentifier("next_chapter")
        }
        .font(.subheadline)
        .foregroundStyle(.primary)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.bar)
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        guard let t = state.scrollTarget, t.book == state.book, t.chapter == state.chapter,
              state.loadedKey == state.chapterKey, !state.verses.isEmpty else { return }
        let id: String = t.verse <= 1 ? "top-\(state.chapterKey)"
            : (state.verses.first { $0.verse >= t.verse }?.id ?? "top-\(state.chapterKey)")
        DispatchQueue.main.async {
            proxy.scrollTo(id, anchor: .top)
            if state.scrollTarget?.token == t.token { state.scrollTarget = nil }
        }
    }
}

struct VerseRow: View {
    let verse: Verse
    let reference: String
    let mark: VerseMark?
    let size: Double
    let dark: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            (Text("\(verse.verse) ")
                .font(.system(size: size * 0.65, weight: .bold))
                .baselineOffset(size * 0.35)
             + Text(verse.text).font(.system(size: size)))
                .lineSpacing(size * 0.4)
                .frame(maxWidth: .infinity, alignment: .leading)
            if mark?.bookmarked == true || mark?.hasNote == true {
                VStack(spacing: 4) {
                    if mark?.bookmarked == true { Image(systemName: "bookmark.fill") }
                    if mark?.hasNote == true { Image(systemName: "square.and.pencil") }
                }
                .font(.footnote)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(mark.flatMap { Highlight.color($0.highlight, dark: dark) } ?? .clear, in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(description)
        .accessibilityHint("Opens verse actions")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("verse_\(verse.verse)")
    }

    private var description: String {
        var s = "\(reference). \(verse.text)"
        if mark?.bookmarked == true { s += ". Bookmarked" }
        if (mark?.highlight ?? 0) != 0 { s += ". Highlighted" }
        if mark?.hasNote == true { s += ". Has note" }
        return s
    }
}

struct BookPicker: View {
    let translation: Translation
    let currentBook: Int
    var onPick: (Int, Int) -> Void
    @State private var testament: Testament = .old
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Picker("Testament", selection: $testament) {
                    Text("Old Testament").tag(Testament.old)
                    Text("New Testament").tag(Testament.new)
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
                ForEach(Books.all.filter { $0.testament == testament }) { b in
                    NavigationLink(value: b) {
                        VStack(alignment: .leading) {
                            Text(translation.bookName(b))
                            Text(b.chapters == 1 ? "1 chapter" : "\(b.chapters) chapters").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("book_\(b.number)")
                }
            }
            .listStyle(.plain)
            .navigationTitle("Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .navigationDestination(for: Book.self) { b in
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 10)], spacing: 10) {
                        ForEach(1...b.chapters, id: \.self) { c in
                            Button { onPick(b.number, c) } label: {
                                Text("\(c)")
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(.primary)
                            }
                            .accessibilityLabel("\(translation.bookName(b)) chapter \(c)")
                            .accessibilityIdentifier("chapter_\(c)")
                        }
                    }
                    .padding()
                }
                .navigationTitle(translation.bookName(b))
            }
        }
        .onAppear { testament = currentBook <= 39 ? .old : .new }
    }
}
