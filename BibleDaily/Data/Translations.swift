import Foundation

/// A bundled Bible edition. All editions live in the bundled `bible.sqlite` (`verses` table,
/// keyed by translation id). To add a Kiswahili edition: add its rows to the database
/// (scripts/build_bible_db.py), add a `Translation` with `languageCode: "sw"` and its 66 book
/// names in `bookNames`, and add it to `Translations.all`.
struct Translation: Identifiable, Hashable {
    let id: String
    let abbreviation: String
    let name: String
    let languageCode: String
    let languageName: String
    let expectedVerses: Int
    let editionNote: String
    let source: String
    let sourceURL: String
    let license: String
    let attribution: String
    var bookNames: [String]? = nil

    func bookName(_ book: Book) -> String {
        if let names = bookNames, names.indices.contains(book.number - 1) { return names[book.number - 1] }
        return book.name
    }
}

enum Translations {
    static let web = Translation(
        id: "WEB",
        abbreviation: "WEB",
        name: "World English Bible",
        languageCode: "en",
        languageName: "English",
        expectedVerses: 31098,
        editionNote: "World English Bible (2020 stable text), 66 books (Protestant canon). Footnotes, section headings and Psalm titles are not shown; the verse text is unchanged.",
        source: "eBible.org USFX edition (eng-web), via the open-bibles collection (github.com/seven1m/open-bibles)",
        sourceURL: "https://ebible.org/find/details.php?id=eng-web",
        license: "Public Domain",
        attribution: "The World English Bible is in the Public Domain. That means that it is not copyrighted. However, \"World English Bible\" is a Trademark of eBible.org. Text provided by eBible.org."
    )

    static let all: [Translation] = [web]
    static let `default` = web

    static func byId(_ id: String?) -> Translation { all.first { $0.id == id } ?? `default` }
}
