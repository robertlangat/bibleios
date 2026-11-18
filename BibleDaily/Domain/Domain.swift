import Foundation

// MARK: - References

struct BibleReference: Equatable {
    let book: Book
    let chapter: Int
    var verse: Int? = nil
    var verseEnd: Int? = nil
    /// True when only a book name was typed (e.g. "Job").
    var bookOnly: Bool = false

    func label(_ bookName: String? = nil) -> String {
        var s = "\(bookName ?? book.name) \(chapter)"
        if let v = verse {
            s += ":\(v)"
            if let e = verseEnd, e > v { s += "-\(e)" }
        }
        return s
    }
}

/// Parses "John 3:16", "Jn 3:16", "Psalm 23", "1 Cor 13:4-7", "II Kings 2", "Song of Solomon 2:1", "Rev.22.21".
enum ReferenceParser {
    private static let regex = try! NSRegularExpression(
        pattern: #"^\s*([1-3]?\s*\p{L}[\p{L}.\s]*?)\s*(\d+)?(?:\s*[:.]\s*(\d+)(?:\s*[-–—]\s*(\d+))?)?\s*$"#
    )

    private static let exactNames: [String: Book] = {
        var m = [String: Book]()
        for b in Books.all { m[key(b.name)] = b }
        return m
    }()

    private static let aliases: [String: Book] = {
        var m = [String: Book]()
        for b in Books.all {
            m[key(b.name)] = b
            m[b.code.lowercased()] = b
            for a in b.aliases { m[a] = b }
        }
        return m
    }()

    static func parse(_ input: String) -> BibleReference? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        func group(_ i: Int) -> String? {
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
        let bookKey = key(group(1) ?? "")
        if bookKey.isEmpty { return nil }
        let versePart = group(3)

        guard let chapter = group(2).flatMap(Int.init) else {
            // A book name alone opens chapter 1, but only for full names, so ordinary words
            // such as "is" or "am" are searched as text instead.
            if versePart != nil { return nil }
            guard let book = exactNames[bookKey] ?? (bookKey == "psalm" ? exactNames["psalms"] : nil) else { return nil }
            return BibleReference(book: book, chapter: 1, bookOnly: true)
        }
        guard let book = aliases[bookKey] ?? prefixMatch(bookKey) else { return nil }
        guard (1...book.chapters).contains(chapter) else { return nil }
        var verse: Int? = nil
        if let vp = versePart {
            guard let v = Int(vp), v >= 1 else { return nil }
            verse = v
        }
        var end: Int? = nil
        if let ep = group(4), let e = Int(ep), let v = verse, e > v { end = e }
        return BibleReference(book: book, chapter: chapter, verse: verse, verseEnd: end)
    }

    /// Lowercase, no dots/spaces, and "I/II/III/First/Second/Third" become 1/2/3.
    static func key(_ raw: String) -> String {
        var s = raw.lowercased().replacingOccurrences(of: ".", with: " ")
        s = s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        let prefixes: [(String, String)] = [
            ("iii ", "3"), ("third ", "3"), ("3rd ", "3"),
            ("ii ", "2"), ("second ", "2"), ("2nd ", "2"),
            ("i ", "1"), ("first ", "1"), ("1st ", "1"),
        ]
        for (p, r) in prefixes where s.hasPrefix(p) {
            s = r + s.dropFirst(p.count)
            break
        }
        return s.replacingOccurrences(of: " ", with: "")
    }

    private static func prefixMatch(_ key: String) -> Book? {
        guard key.count >= 3 else { return nil }
        let books = Set(aliases.filter { $0.key.hasPrefix(key) }.map { $0.value.number })
        return books.count == 1 ? Books.book(books.first!) : nil
    }
}

// MARK: - Search

enum SearchText {
    /// Must match scripts/build_bible_db.py: lowercase, apostrophes dropped, other punctuation → one space.
    static func normalize(_ text: String) -> String {
        var out = ""
        var lastSpace = true
        for ch in text.lowercased() {
            if ch == "'" || ch == "\u{2019}" || ch == "\u{2018}" || ch == "\u{02BC}" { continue }
            if ch.isLetter || ch.isNumber {
                out.append(ch)
                lastSpace = false
            } else if !lastSpace {
                out.append(" ")
                lastSpace = true
            }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }
}

/// Every term must start a word in the verse; whole-phrase matches rank first.
/// A query in quotes requires the exact phrase.
struct TextQuery: Equatable {
    let terms: [String]
    let phrase: String
    let exactPhraseOnly: Bool

    static func parse(_ raw: String) -> TextQuery? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let quotes: Set<Character> = ["\"", "\u{201C}", "\u{201D}"]
        let quoted = t.count >= 2 && quotes.contains(t.first!) && quotes.contains(t.last!)
        let norm = SearchText.normalize(t)
        if norm.isEmpty { return nil }
        var seen = Set<String>()
        let terms = norm.split(separator: " ").map(String.init).filter { seen.insert($0).inserted }
        return TextQuery(terms: terms, phrase: norm, exactPhraseOnly: quoted && terms.count > 1)
    }

    func sql(translationId: String, limit: Int) -> (sql: String, args: [String]) {
        var args = [translationId]
        var conditions = ["translation = ?"]
        if exactPhraseOnly {
            conditions.append("search LIKE ?")
            args.append("% \(phrase) %")
        } else {
            for term in terms {
                conditions.append("search LIKE ?")
                args.append("% \(term)%")
            }
        }
        args.append("% \(phrase)%")
        let sql = "SELECT book, chapter, verse, text FROM verses WHERE " + conditions.joined(separator: " AND ") +
            " ORDER BY CASE WHEN search LIKE ? THEN 0 ELSE 1 END, book, chapter, verse LIMIT \(limit)"
        return (sql, args)
    }
}

// MARK: - Verse of the day & sharing

enum VerseOfDay {
    static let references: [String] = [
        "John 3:16", "Psalm 23:1", "Proverbs 3:5", "Philippians 4:13", "Romans 8:28",
        "Jeremiah 29:11", "Joshua 1:9", "Isaiah 40:31", "Matthew 11:28", "Philippians 4:6",
        "Psalm 46:1", "Romans 12:2", "Hebrews 11:1", "1 John 4:19", "Lamentations 3:22",
        "Psalm 119:105", "Matthew 6:33", "2 Corinthians 5:17", "Galatians 5:22", "Ephesians 2:8",
        "Isaiah 41:10", "Psalm 37:4", "Romans 15:13", "1 Corinthians 13:4", "John 14:6",
        "Matthew 5:16", "Psalm 27:1", "Proverbs 16:3", "Micah 6:8", "Colossians 3:23",
        "1 Peter 5:7", "James 1:5", "Psalm 34:8", "John 16:33", "Deuteronomy 31:6",
        "Psalm 121:1", "Romans 5:8", "Hebrews 13:8", "2 Timothy 1:7", "Zephaniah 3:17",
        "Isaiah 26:3", "Psalm 91:1", "John 15:5", "Matthew 22:37", "Ephesians 4:32",
        "1 Thessalonians 5:16", "Psalm 139:14", "Romans 10:9", "Nahum 1:7", "Psalm 100:4",
        "John 1:1", "Genesis 1:1", "Psalm 51:10", "Proverbs 18:10", "Isaiah 53:5",
        "Matthew 28:20", "Revelation 21:4", "Psalm 118:24", "Joshua 24:15", "1 John 1:9",
        "Hebrews 4:16", "Psalm 19:14", "John 11:25", "Romans 6:23", "Galatians 2:20",
        "Psalm 16:11", "Isaiah 9:6", "James 1:17", "Mark 10:27", "Luke 1:37",
    ]

    static let parsed: [BibleReference] = references.map { ReferenceParser.parse($0)! }

    /// Same rotation as the Android app: days since 1970-01-01 in the phone's local calendar.
    static func reference(for date: Date, calendar: Calendar = .current) -> BibleReference {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let midnight = utc.date(from: DateComponents(year: c.year, month: c.month, day: c.day))!
        let day = Int(floor(midnight.timeIntervalSince1970 / 86_400))
        let n = parsed.count
        return parsed[((day % n) + n) % n]
    }
}

enum ShareText {
    static func format(text: String, reference: String, translation: Translation) -> String {
        "\(text)\n— \(reference) (\(translation.name), \(translation.abbreviation))"
    }
}
