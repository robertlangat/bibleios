#!/usr/bin/env python3
"""Builds BibleDaily/Resources/bible.sqlite from data/eng-web.tsv.gz (book \\t chapter \\t verse \\t text).

The `search` column must be normalized exactly like SearchText.normalize in the app:
lowercase, apostrophes removed, any other non-letter/digit run becomes one space, padded with spaces.
"""
import gzip, sqlite3, sys, os

def normalize(text: str) -> str:
    out, last_space = [], True
    for ch in text.lower():
        if ch in "'’‘ʼ":
            continue
        if ch.isalnum():
            out.append(ch); last_space = False
        elif not last_space:
            out.append(" "); last_space = True
    return "".join(out).strip()

src = sys.argv[1] if len(sys.argv) > 1 else "data/eng-web.tsv.gz"
dst = sys.argv[2] if len(sys.argv) > 2 else "BibleDaily/Resources/bible.sqlite"
if os.path.exists(dst):
    os.remove(dst)
db = sqlite3.connect(dst)
db.executescript("""
PRAGMA page_size = 4096;
CREATE TABLE translations (id TEXT PRIMARY KEY, name TEXT NOT NULL, language TEXT NOT NULL, verse_count INTEGER NOT NULL);
CREATE TABLE verses (
  translation TEXT NOT NULL, book INTEGER NOT NULL, chapter INTEGER NOT NULL, verse INTEGER NOT NULL,
  text TEXT NOT NULL, search TEXT NOT NULL,
  PRIMARY KEY (translation, book, chapter, verse)
) WITHOUT ROWID;
""")
rows = []
with gzip.open(src, "rt", encoding="utf-8") as f:
    for line in f:
        b, c, v, t = line.rstrip("\n").split("\t", 3)
        rows.append(("WEB", int(b), int(c), int(v), t, " " + normalize(t) + " "))
db.executemany("INSERT INTO verses VALUES (?,?,?,?,?,?)", rows)
db.execute("INSERT INTO translations VALUES ('WEB','World English Bible','en',?)", (len(rows),))
db.commit()
db.execute("VACUUM")
db.close()
print(f"{dst}: {len(rows)} verses, {os.path.getsize(dst)/1e6:.1f} MB")
