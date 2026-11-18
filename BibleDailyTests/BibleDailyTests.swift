import XCTest
@testable import BibleDaily

final class ReferenceParserTests: XCTestCase {
    private func check(_ input: String, _ book: String, _ chapter: Int, _ verse: Int? = nil, _ end: Int? = nil,
                       file: StaticString = #filePath, line: UInt = #line) {
        guard let r = ReferenceParser.parse(input) else { return XCTFail("Could not parse \(input)", file: file, line: line) }
        XCTAssertEqual(r.book.name, book, input, file: file, line: line)
        XCTAssertEqual(r.chapter, chapter, input, file: file, line: line)
        XCTAssertEqual(r.verse, verse, input, file: file, line: line)
        XCTAssertEqual(r.verseEnd, end, input, file: file, line: line)
    }

    func testJohnFullAndAbbreviated() {
        check("John 3:16", "John", 3, 16)
        check("Jn 3:16", "John", 3, 16)
        check("jn3:16", "John", 3, 16)
        check("Jhn 3.16", "John", 3, 16)
        check("  john   3 : 16 ", "John", 3, 16)
    }

    func testPsalmsAndChapters() {
        check("Psalm 23", "Psalms", 23)
        check("Psalms 23", "Psalms", 23)
        check("Ps 23:1", "Psalms", 23, 1)
        check("Psalm 119:105", "Psalms", 119, 105)
    }

    func testNumberedBooksAndRanges() {
        check("1 Cor 13:4-7", "1 Corinthians", 13, 4, 7)
        check("II Kings 2", "2 Kings", 2)
        check("First John 4:19", "1 John", 4, 19)
        check("Song of Solomon 2:1", "Song of Solomon", 2, 1)
        check("Rev.22.21", "Revelation", 22, 21)
        check("Phil 4:13", "Philippians", 4, 13)
        check("Is 53", "Isaiah", 53)
    }

    func testWordsAreNotReferences() {
        XCTAssertNil(ReferenceParser.parse("love"))
        XCTAssertNil(ReferenceParser.parse("is"))
        XCTAssertNil(ReferenceParser.parse("born anew"))
        XCTAssertNil(ReferenceParser.parse("John 22"))
        XCTAssertNil(ReferenceParser.parse("Psalm 151"))
        XCTAssertEqual(ReferenceParser.parse("Job")?.bookOnly, true)
    }

    func testLabels() {
        XCTAssertEqual(ReferenceParser.parse("jn 3:16")?.label(), "John 3:16")
        XCTAssertEqual(ReferenceParser.parse("1 cor 13:4-7")?.label(), "1 Corinthians 13:4-7")
    }
}

final class SearchAndShareTests: XCTestCase {
    func testNormalizeMatchesDatabaseRules() {
        XCTAssertEqual(SearchText.normalize("“For God so loved the world,"), "for god so loved the world")
        XCTAssertEqual(SearchText.normalize("Don’t marvel"), "dont marvel")
    }

    func testQueryBuildsWordAndPhraseConditions() {
        let q = TextQuery.parse("Love one another")!
        XCTAssertEqual(q.terms, ["love", "one", "another"])
        XCTAssertFalse(q.exactPhraseOnly)
        XCTAssertEqual(q.sql(translationId: "WEB", limit: 5).args, ["WEB", "% love%", "% one%", "% another%", "% love one another%"])
        XCTAssertTrue(TextQuery.parse("\"born anew\"")!.exactPhraseOnly)
        XCTAssertNil(TextQuery.parse(" ?! "))
    }

    func testShareTextIncludesReferenceAndTranslation() {
        XCTAssertEqual(ShareText.format(text: "For God so loved the world…", reference: "John 3:16", translation: Translations.web),
                       "For God so loved the world…\n— John 3:16 (World English Bible, WEB)")
    }

    func testVerseOfDayRotatesDaily() {
        let cal = Calendar(identifier: .gregorian)
        let d1 = cal.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 9))!
        let d2 = cal.date(byAdding: .day, value: 1, to: d1)!
        XCTAssertEqual(VerseOfDay.reference(for: d1), VerseOfDay.reference(for: cal.date(byAdding: .hour, value: 10, to: d1)!))
        XCTAssertNotEqual(VerseOfDay.reference(for: d1), VerseOfDay.reference(for: d2))
    }
}

final class BundledBibleTests: XCTestCase {
    private let store = BibleStore.shared

    func testVerseCountAndEveryChapterPresent() {
        XCTAssertEqual(store.verseCount("WEB"), Translations.web.expectedVerses)
        XCTAssertEqual(Books.all.count, 66)
        XCTAssertEqual(Books.all.reduce(0) { $0 + $1.chapters }, 1189)
        for b in Books.all {
            XCTAssertFalse(store.chapter("WEB", book: b.number, chapter: b.chapters).isEmpty, "\(b.name) \(b.chapters)")
        }
    }

    func testKeyVerses() {
        XCTAssertTrue(store.verse("WEB", book: 43, chapter: 3, verse: 16)!.text.hasPrefix("For God so loved the world"))
        XCTAssertTrue(store.verse("WEB", book: 19, chapter: 23, verse: 1)!.text.hasPrefix("Yahweh is my shepherd"))
    }

    func testEveryVerseOfTheDayExists() {
        for r in VerseOfDay.parsed {
            XCTAssertNotNil(store.verse("WEB", book: r.book.number, chapter: r.chapter, verse: r.verse!), r.label())
        }
    }

    func testSearch() {
        let ref = store.search(Translations.web, "Jn 3:16")
        XCTAssertEqual(ref.reference?.label, "John 3:16")
        XCTAssertTrue(ref.verses.isEmpty)
        let phrase = store.search(Translations.web, "born anew")
        XCTAssertTrue(phrase.verses.contains { $0.book == 43 && $0.chapter == 3 && $0.verse == 3 })
        XCTAssertFalse(store.search(Translations.web, "shepherd").verses.isEmpty)
    }
}
