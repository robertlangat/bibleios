import Foundation

enum Testament { case old, new }

/// A canonical book. `number` (1...66) is the stable key shared by every translation and by
/// bookmarks, highlights and notes, so a Kiswahili edition can be added later without migration.
struct Book: Identifiable, Hashable {
    let number: Int
    let code: String
    let name: String
    let chapters: Int
    let aliases: [String]
    var id: Int { number }
    var testament: Testament { number <= 39 ? .old : .new }
}

enum Books {
    static let all: [Book] = [
        Book(number: 1, code: "GEN", name: "Genesis", chapters: 50, aliases: ["gen", "ge", "gn"]),
        Book(number: 2, code: "EXO", name: "Exodus", chapters: 40, aliases: ["exo", "ex", "exod"]),
        Book(number: 3, code: "LEV", name: "Leviticus", chapters: 27, aliases: ["lev", "le", "lv"]),
        Book(number: 4, code: "NUM", name: "Numbers", chapters: 36, aliases: ["num", "nu", "nm", "nb"]),
        Book(number: 5, code: "DEU", name: "Deuteronomy", chapters: 34, aliases: ["deut", "deu", "dt", "de"]),
        Book(number: 6, code: "JOS", name: "Joshua", chapters: 24, aliases: ["josh", "jos", "jsh"]),
        Book(number: 7, code: "JDG", name: "Judges", chapters: 21, aliases: ["judg", "jdg", "jg", "jdgs"]),
        Book(number: 8, code: "RUT", name: "Ruth", chapters: 4, aliases: ["rut", "ru", "rth"]),
        Book(number: 9, code: "1SA", name: "1 Samuel", chapters: 31, aliases: ["1sam", "1sa", "1sm", "1s"]),
        Book(number: 10, code: "2SA", name: "2 Samuel", chapters: 24, aliases: ["2sam", "2sa", "2sm", "2s"]),
        Book(number: 11, code: "1KI", name: "1 Kings", chapters: 22, aliases: ["1kgs", "1ki", "1kin", "1k"]),
        Book(number: 12, code: "2KI", name: "2 Kings", chapters: 25, aliases: ["2kgs", "2ki", "2kin", "2k"]),
        Book(number: 13, code: "1CH", name: "1 Chronicles", chapters: 29, aliases: ["1chr", "1ch", "1chron"]),
        Book(number: 14, code: "2CH", name: "2 Chronicles", chapters: 36, aliases: ["2chr", "2ch", "2chron"]),
        Book(number: 15, code: "EZR", name: "Ezra", chapters: 10, aliases: ["ezr"]),
        Book(number: 16, code: "NEH", name: "Nehemiah", chapters: 13, aliases: ["neh", "ne"]),
        Book(number: 17, code: "EST", name: "Esther", chapters: 10, aliases: ["esth", "est", "es"]),
        Book(number: 18, code: "JOB", name: "Job", chapters: 42, aliases: ["jb"]),
        Book(number: 19, code: "PSA", name: "Psalms", chapters: 150, aliases: ["ps", "psa", "psalm", "pss", "psm", "pslm"]),
        Book(number: 20, code: "PRO", name: "Proverbs", chapters: 31, aliases: ["prov", "pro", "prv", "pr"]),
        Book(number: 21, code: "ECC", name: "Ecclesiastes", chapters: 12, aliases: ["eccl", "ecc", "ec", "qoh"]),
        Book(number: 22, code: "SNG", name: "Song of Solomon", chapters: 8, aliases: ["song", "sng", "sos", "songofsongs", "canticles", "ss"]),
        Book(number: 23, code: "ISA", name: "Isaiah", chapters: 66, aliases: ["isa", "is"]),
        Book(number: 24, code: "JER", name: "Jeremiah", chapters: 52, aliases: ["jer", "je", "jr"]),
        Book(number: 25, code: "LAM", name: "Lamentations", chapters: 5, aliases: ["lam", "la"]),
        Book(number: 26, code: "EZK", name: "Ezekiel", chapters: 48, aliases: ["ezek", "ezk", "eze"]),
        Book(number: 27, code: "DAN", name: "Daniel", chapters: 12, aliases: ["dan", "da", "dn"]),
        Book(number: 28, code: "HOS", name: "Hosea", chapters: 14, aliases: ["hos", "ho"]),
        Book(number: 29, code: "JOL", name: "Joel", chapters: 3, aliases: ["jol", "joe", "jl"]),
        Book(number: 30, code: "AMO", name: "Amos", chapters: 9, aliases: ["amo", "am"]),
        Book(number: 31, code: "OBA", name: "Obadiah", chapters: 1, aliases: ["obad", "oba", "ob"]),
        Book(number: 32, code: "JON", name: "Jonah", chapters: 4, aliases: ["jon", "jnh"]),
        Book(number: 33, code: "MIC", name: "Micah", chapters: 7, aliases: ["mic", "mc"]),
        Book(number: 34, code: "NAM", name: "Nahum", chapters: 3, aliases: ["nah", "nam", "na"]),
        Book(number: 35, code: "HAB", name: "Habakkuk", chapters: 3, aliases: ["hab", "hb"]),
        Book(number: 36, code: "ZEP", name: "Zephaniah", chapters: 3, aliases: ["zeph", "zep", "zp"]),
        Book(number: 37, code: "HAG", name: "Haggai", chapters: 2, aliases: ["hag", "hg"]),
        Book(number: 38, code: "ZEC", name: "Zechariah", chapters: 14, aliases: ["zech", "zec", "zc"]),
        Book(number: 39, code: "MAL", name: "Malachi", chapters: 4, aliases: ["mal", "ml"]),
        Book(number: 40, code: "MAT", name: "Matthew", chapters: 28, aliases: ["matt", "mat", "mt"]),
        Book(number: 41, code: "MRK", name: "Mark", chapters: 16, aliases: ["mrk", "mar", "mk", "mr"]),
        Book(number: 42, code: "LUK", name: "Luke", chapters: 24, aliases: ["luk", "lk"]),
        Book(number: 43, code: "JHN", name: "John", chapters: 21, aliases: ["jhn", "jn", "joh"]),
        Book(number: 44, code: "ACT", name: "Acts", chapters: 28, aliases: ["act", "ac"]),
        Book(number: 45, code: "ROM", name: "Romans", chapters: 16, aliases: ["rom", "ro", "rm"]),
        Book(number: 46, code: "1CO", name: "1 Corinthians", chapters: 16, aliases: ["1cor", "1co"]),
        Book(number: 47, code: "2CO", name: "2 Corinthians", chapters: 13, aliases: ["2cor", "2co"]),
        Book(number: 48, code: "GAL", name: "Galatians", chapters: 6, aliases: ["gal", "ga"]),
        Book(number: 49, code: "EPH", name: "Ephesians", chapters: 6, aliases: ["eph", "ephes"]),
        Book(number: 50, code: "PHP", name: "Philippians", chapters: 4, aliases: ["phil", "php", "pp"]),
        Book(number: 51, code: "COL", name: "Colossians", chapters: 4, aliases: ["col"]),
        Book(number: 52, code: "1TH", name: "1 Thessalonians", chapters: 5, aliases: ["1thess", "1th", "1thes"]),
        Book(number: 53, code: "2TH", name: "2 Thessalonians", chapters: 3, aliases: ["2thess", "2th", "2thes"]),
        Book(number: 54, code: "1TI", name: "1 Timothy", chapters: 6, aliases: ["1tim", "1ti", "1tm"]),
        Book(number: 55, code: "2TI", name: "2 Timothy", chapters: 4, aliases: ["2tim", "2ti", "2tm"]),
        Book(number: 56, code: "TIT", name: "Titus", chapters: 3, aliases: ["tit", "ti"]),
        Book(number: 57, code: "PHM", name: "Philemon", chapters: 1, aliases: ["philem", "phm", "phlm"]),
        Book(number: 58, code: "HEB", name: "Hebrews", chapters: 13, aliases: ["heb"]),
        Book(number: 59, code: "JAS", name: "James", chapters: 5, aliases: ["jas", "jm", "jam"]),
        Book(number: 60, code: "1PE", name: "1 Peter", chapters: 5, aliases: ["1pet", "1pe", "1pt", "1p"]),
        Book(number: 61, code: "2PE", name: "2 Peter", chapters: 3, aliases: ["2pet", "2pe", "2pt", "2p"]),
        Book(number: 62, code: "1JN", name: "1 John", chapters: 5, aliases: ["1jn", "1jhn", "1jo", "1j", "1joh"]),
        Book(number: 63, code: "2JN", name: "2 John", chapters: 1, aliases: ["2jn", "2jhn", "2jo", "2j", "2joh"]),
        Book(number: 64, code: "3JN", name: "3 John", chapters: 1, aliases: ["3jn", "3jhn", "3jo", "3j", "3joh"]),
        Book(number: 65, code: "JUD", name: "Jude", chapters: 1, aliases: ["jud", "jd"]),
        Book(number: 66, code: "REV", name: "Revelation", chapters: 22, aliases: ["rev", "re", "rv", "revelations", "apocalypse"]),
    ]

    static func book(_ number: Int) -> Book { all[min(max(number, 1), all.count) - 1] }

    static func bookOrNil(_ number: Int) -> Book? { (1...all.count).contains(number) ? all[number - 1] : nil }

    /// The chapter after (book, chapter), crossing book boundaries; nil after Revelation 22.
    static func next(book: Int, chapter: Int) -> (book: Int, chapter: Int)? {
        guard let b = bookOrNil(book) else { return nil }
        if chapter < b.chapters { return (book, chapter + 1) }
        if book < all.count { return (book + 1, 1) }
        return nil
    }

    /// The chapter before (book, chapter), crossing book boundaries; nil at Genesis 1.
    static func previous(book: Int, chapter: Int) -> (book: Int, chapter: Int)? {
        if chapter > 1 { return (book, chapter - 1) }
        if book > 1 { return (book - 1, Books.book(book - 1).chapters) }
        return nil
    }
}
