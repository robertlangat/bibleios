import Foundation
import SQLite3
import SwiftUI

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct Verse: Identifiable, Hashable {
    let book: Int
    let chapter: Int
    let verse: Int
    let text: String
    var id: String { "\(book)_\(chapter)_\(verse)" }
}

/// Minimal SQLite wrapper (the system library; no third-party dependency).
final class SQLiteDB {
    private var db: OpaquePointer?

    init(path: String, readOnly: Bool) throws {
        let flags = (readOnly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)) | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot open \(path)"])
        }
    }

    deinit { sqlite3_close(db) }

    func execute(_ sql: String, _ args: [Any?] = []) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, args)
        sqlite3_step(stmt)
    }

    func query<T>(_ sql: String, _ args: [Any?] = [], row: (OpaquePointer) -> T) -> [T] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let s = stmt else { return [] }
        defer { sqlite3_finalize(stmt) }
        bind(s, args)
        var out = [T]()
        while sqlite3_step(s) == SQLITE_ROW { out.append(row(s)) }
        return out
    }

    private func bind(_ stmt: OpaquePointer?, _ args: [Any?]) {
        for (i, a) in args.enumerated() {
            let idx = Int32(i + 1)
            switch a {
            case let v as Int: sqlite3_bind_int64(stmt, idx, Int64(v))
            case let v as Bool: sqlite3_bind_int64(stmt, idx, v ? 1 : 0)
            case let v as Double: sqlite3_bind_double(stmt, idx, v)
            case let v as String: sqlite3_bind_text(stmt, idx, v, -1, SQLITE_TRANSIENT)
            default: sqlite3_bind_null(stmt, idx)
            }
        }
    }

    static func string(_ s: OpaquePointer, _ col: Int32) -> String? {
        guard let c = sqlite3_column_text(s, col) else { return nil }
        return String(cString: c)
    }
}

// MARK: - Bible text (bundled, read-only)

struct ReferenceHit: Equatable {
    let reference: BibleReference
    let label: String
    let preview: String
}

struct SearchResults: Equatable {
    var query: String
    var reference: ReferenceHit? = nil
    var verses: [Verse] = []
    var terms: [String] = []
    var truncated = false
}

final class BibleStore {
    static let shared = BibleStore()
    private let db: SQLiteDB

    private init() {
        let path = Bundle.main.path(forResource: "bible", ofType: "sqlite")!
        db = try! SQLiteDB(path: path, readOnly: true)
    }

    func verseCount(_ t: String) -> Int {
        db.query("SELECT COUNT(*) FROM verses WHERE translation = ?", [t]) { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
    }

    func chapter(_ t: String, book: Int, chapter: Int) -> [Verse] {
        db.query("SELECT book, chapter, verse, text FROM verses WHERE translation = ? AND book = ? AND chapter = ? ORDER BY verse",
                 [t, book, chapter], row: Self.verse)
    }

    func verse(_ t: String, book: Int, chapter: Int, verse: Int) -> Verse? {
        db.query("SELECT book, chapter, verse, text FROM verses WHERE translation = ? AND book = ? AND chapter = ? AND verse = ?",
                 [t, book, chapter, verse], row: Self.verse).first
    }

    func search(_ translation: Translation, _ raw: String, limit: Int = 500) -> SearchResults {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return SearchResults(query: query) }

        var hit: ReferenceHit? = nil
        if let ref = ReferenceParser.parse(query) {
            let verses = chapter(translation.id, book: ref.book.number, chapter: ref.chapter)
            let preview: String
            if let v = ref.verse {
                let end = ref.verseEnd ?? v
                preview = verses.filter { (v...end).contains($0.verse) }.map(\.text).joined(separator: " ")
            } else {
                preview = verses.prefix(2).map(\.text).joined(separator: " ")
            }
            if !preview.isEmpty { hit = ReferenceHit(reference: ref, label: ref.label(translation.bookName(ref.book)), preview: preview) }
            if !ref.bookOnly, hit != nil { return SearchResults(query: query, reference: hit) }
        }

        guard let tq = TextQuery.parse(query) else { return SearchResults(query: query, reference: hit) }
        let q = tq.sql(translationId: translation.id, limit: limit + 1)
        let rows = db.query(q.sql, q.args, row: Self.verse)
        return SearchResults(query: query, reference: hit, verses: Array(rows.prefix(limit)), terms: tq.terms, truncated: rows.count > limit)
    }

    private static func verse(_ s: OpaquePointer) -> Verse {
        Verse(book: Int(sqlite3_column_int64(s, 0)), chapter: Int(sqlite3_column_int64(s, 1)),
              verse: Int(sqlite3_column_int64(s, 2)), text: SQLiteDB.string(s, 3) ?? "")
    }
}

// MARK: - Bookmarks, highlights, notes (on-device, writable)

struct VerseKey: Hashable { let book: Int; let chapter: Int; let verse: Int }

struct VerseMark: Identifiable, Hashable {
    let key: VerseKey
    var bookmarked = false
    var highlight = 0
    var note: String? = nil
    var updatedAt = Date()
    var id: VerseKey { key }
    var hasNote: Bool { !(note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var isEmpty: Bool { !bookmarked && highlight == 0 && !hasNote }
}

/// Marks are keyed by canonical reference only, so they follow the verse across translations.
@MainActor
final class MarksStore: ObservableObject {
    @Published private(set) var marks: [VerseKey: VerseMark] = [:]
    private let db: SQLiteDB

    init(reset: Bool = false) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("user_data.sqlite")
        if reset { try? FileManager.default.removeItem(at: url) }
        db = try! SQLiteDB(path: url.path, readOnly: false)
        db.execute("""
            CREATE TABLE IF NOT EXISTS marks (book INTEGER NOT NULL, chapter INTEGER NOT NULL, verse INTEGER NOT NULL,
              bookmarked INTEGER NOT NULL DEFAULT 0, highlight INTEGER NOT NULL DEFAULT 0, note TEXT,
              updated_at REAL NOT NULL, PRIMARY KEY (book, chapter, verse))
            """)
        let rows = db.query("SELECT book, chapter, verse, bookmarked, highlight, note, updated_at FROM marks") { s in
            VerseMark(key: VerseKey(book: Int(sqlite3_column_int64(s, 0)), chapter: Int(sqlite3_column_int64(s, 1)), verse: Int(sqlite3_column_int64(s, 2))),
                      bookmarked: sqlite3_column_int64(s, 3) != 0, highlight: Int(sqlite3_column_int64(s, 4)),
                      note: SQLiteDB.string(s, 5), updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(s, 6)))
        }
        marks = Dictionary(uniqueKeysWithValues: rows.map { ($0.key, $0) })
    }

    func mark(_ key: VerseKey) -> VerseMark? { marks[key] }

    func update(_ key: VerseKey, _ transform: (inout VerseMark) -> Void) {
        var m = marks[key] ?? VerseMark(key: key)
        transform(&m)
        m.updatedAt = Date()
        if let n = m.note { m.note = n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : n }
        if m.isEmpty {
            marks[key] = nil
            db.execute("DELETE FROM marks WHERE book = ? AND chapter = ? AND verse = ?", [key.book, key.chapter, key.verse])
        } else {
            marks[key] = m
            db.execute("INSERT OR REPLACE INTO marks VALUES (?, ?, ?, ?, ?, ?, ?)",
                       [key.book, key.chapter, key.verse, m.bookmarked, m.highlight, m.note, m.updatedAt.timeIntervalSince1970])
        }
    }

    private func sorted(_ filter: (VerseMark) -> Bool) -> [VerseMark] {
        marks.values.filter(filter).sorted { $0.updatedAt > $1.updatedAt }
    }
    var bookmarks: [VerseMark] { sorted { $0.bookmarked } }
    var highlights: [VerseMark] { sorted { $0.highlight != 0 } }
    var notes: [VerseMark] { sorted { $0.hasNote } }
}

// MARK: - Settings (UserDefaults)

enum ThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { self == .system ? "Phone setting" : rawValue.capitalized }
    var colorScheme: ColorScheme? { self == .light ? .light : self == .dark ? .dark : nil }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let minText = 14.0, maxText = 34.0, defaultText = 19.0
    private let d = UserDefaults.standard

    @Published var textSize: Double { didSet { d.set(textSize, forKey: "textSize") } }
    @Published var theme: ThemeMode { didSet { d.set(theme.rawValue, forKey: "theme") } }
    @Published var translationId: String { didSet { d.set(translationId, forKey: "translation") } }
    @Published var reminderEnabled: Bool { didSet { d.set(reminderEnabled, forKey: "reminderEnabled") } }
    @Published var reminderHour: Int { didSet { d.set(reminderHour, forKey: "reminderHour") } }
    @Published var reminderMinute: Int { didSet { d.set(reminderMinute, forKey: "reminderMinute") } }
    @Published var lastBook: Int { didSet { d.set(lastBook, forKey: "lastBook") } }
    @Published var lastChapter: Int { didSet { d.set(lastChapter, forKey: "lastChapter") } }
    @Published var lastVerse: Int { didSet { d.set(lastVerse, forKey: "lastVerse") } }

    init(reset: Bool = false) {
        if reset, let id = Bundle.main.bundleIdentifier { d.removePersistentDomain(forName: id) }
        textSize = d.object(forKey: "textSize") as? Double ?? Self.defaultText
        theme = ThemeMode(rawValue: d.string(forKey: "theme") ?? "") ?? .light
        translationId = d.string(forKey: "translation") ?? Translations.default.id
        reminderEnabled = d.bool(forKey: "reminderEnabled")
        reminderHour = d.object(forKey: "reminderHour") as? Int ?? 7
        reminderMinute = d.object(forKey: "reminderMinute") as? Int ?? 0
        lastBook = d.integer(forKey: "lastBook")
        lastChapter = d.integer(forKey: "lastChapter")
        lastVerse = d.integer(forKey: "lastVerse")
    }

    var translation: Translation { Translations.byId(translationId) }
    var hasPosition: Bool { lastBook > 0 }

    func savePosition(book: Int, chapter: Int, verse: Int) {
        if lastBook != book { lastBook = book }
        if lastChapter != chapter { lastChapter = chapter }
        if lastVerse != verse { lastVerse = verse }
    }

    func setTextSize(_ v: Double) { textSize = min(max(v, Self.minText), Self.maxText) }
}
