# Markdown2HTML — `shortcuts.html` Compilation

`generate-shortcuts.swift` compiles the Markdown source of the in-app keyboard shortcut cheat sheet
(`Sources/vChewingIME_macOS/Resources/<locale>.lproj/shortcuts.html`, reached from the IME menu as
「鍵盤熱鍵使用手冊」) and is the **single home of that HTML's shape**: the document skeleton, the inline
stylesheet and the supported Markdown subset all live in that one script. The per-locale content lives
in the Markdown sources only.

The script runs on the Swift 6.4 toolchain already required by this repository; it has no other
dependency and is never part of a build (nothing in `Package.swift` or the Xcode project refers to it).

## Locales and provenance

| Locale    | Markdown source                                                          | HTML product                                                     |
|-----------|--------------------------------------------------------------------------|------------------------------------------------------------------|
| `zh-Hant` | `vChewing-HomePage.io/manual/shortcuts.md` (**authoritative**), falling back to the checked-in mirror `Sources/vChewingIME_macOS/Resources/shortcuts-src/shortcuts.zh-Hant.md` | `Sources/vChewingIME_macOS/Resources/zh-Hant.lproj/shortcuts.html` |
| `zh-Hans` | `Sources/vChewingIME_macOS/Resources/shortcuts-src/shortcuts.zh-Hans.md` | `Sources/vChewingIME_macOS/Resources/zh-Hans.lproj/shortcuts.html` |
| `en`      | `Sources/vChewingIME_macOS/Resources/shortcuts-src/shortcuts.en.md`      | `Sources/vChewingIME_macOS/Resources/en.lproj/shortcuts.html`    |
| `ja`      | `Sources/vChewingIME_macOS/Resources/shortcuts-src/shortcuts.ja.md`      | `Sources/vChewingIME_macOS/Resources/ja.lproj/shortcuts.html`    |

* Traditional Chinese is authored on the website repository (`vChewing-HomePage.io`), which is where
  the manual's canonical text lives. The mirror inside this repository is kept byte-for-byte identical
  in its body so that the cheat sheet can still be produced when that repository is not at hand; edit
  the website copy first and mirror the change into it.
* Simplified Chinese is **derived** from the Traditional mirror: character-level simplification only,
  with Taiwan vocabulary preserved throughout (`設定 → 设定`, never `设置`; `資料 → 资料`, never
  `数据`; `視窗 → 视窗`, never `窗口`). It is a checked-in file, not a build-time transform.
* English and Japanese were reverse-derived from their hand-written HTML products and then brought up
  to the current content; from here on they are maintained as Markdown. Their prose is a translation
  of the Traditional source — **when a row changes upstream, retranslate it here** rather than editing
  the product.
* Every locale's second line — the one carrying the version number — is generated from the Traditional
  source, so the four products cannot disagree about which release they document. `en`/`ja` keep their
  own sentence, but the version number is read out of `manual/shortcuts.md`.

## Usage

```bash
# Compile every locale this toolchain owns.
Scripts/Markdown2HTML/generate-shortcuts.swift

# Compile one locale.
Scripts/Markdown2HTML/generate-shortcuts.swift --locale zh-Hant

# Fail (exit 1) when a product is out of date; writes nothing.
Scripts/Markdown2HTML/generate-shortcuts.swift --check

# Show each locale's source candidates and product.
Scripts/Markdown2HTML/generate-shortcuts.swift --list
```

The repository root is inferred from the script's own location. Override the website repository's
location with `--homepage <dir>` or the `VCHEWING_HOMEPAGE` environment variable; the default is
`../../../vChewing-HomePage.io` relative to the repository root, which assumes the usual sibling
checkout layout.

## Supported Markdown

Only what the cheat sheet actually uses, so that the products stay diff-stable:

| Syntax | Rendering |
|---|---|
| `# …` | `<h1><strong>…</strong></h1>` |
| Paragraph | `<div>…</div>` |
| `1. …` / `- …` | `<ol>` / `<ul>`, one `<li>` per item |
| Pipe table with a `|-:|-|` separator row | `<table>`; the header row is bolded |
| `<br />` (also accepts `<br>`, `<br/>`, `<br >`) | In a table cell: one `<div>` per segment. Elsewhere: emitted verbatim |
| `**bold**`, `` `code` `` | `<strong>`, `<code>` |
| `&nbsp;` | Passed through as the entity (used by the Japanese notes' spacing) |

Every other character is HTML-escaped. YAML front matter is stripped, with one exception: the key
`note-list: ordered|unordered` is read by the generator and decides whether the leading notes render as
`<ol>` or `<ul>`. The cheat sheet's nine notes are written as an ordered list (`1.`) in the source;
`note-list` exists so that an upstream source which happens to use bullets still renders as `<ol>`
without changing the website's own rendering.

## The toolchain

| Script | Role |
|---|---|
| `generate-shortcuts.swift` | Compiles every locale's Markdown into its `shortcuts.html`. Reads the website repository directly when it is present and falls back to the checked-in Traditional mirror otherwise. |
| `sync-from-homepage.swift` | Copies `vChewing-HomePage.io/manual/shortcuts.md` (front-matter keys plus body) into the Traditional mirror, adding the mirror's own front-matter comments. |
| `derive-zh-Hans.swift` | Re-derives the Simplified source from the Traditional mirror by character-level simplification, then restores the front-matter keys and comments verbatim. |

## Regenerating after an upstream change

1. Edit the Traditional Chinese text on the website repository — it is the authoritative source.
2. Run `Scripts/Markdown2HTML/sync-from-homepage.swift` to pull it into the mirror.
3. Run `Scripts/Markdown2HTML/derive-zh-Hans.swift` to re-derive the Simplified source, then read
   through that diff by hand: ICU leaves a handful of glyphs unconverted (`鍵`／`冊`／`熱`／`彙`／`體`／
   `網`／`臺`／`灣`／`倉`／`蝨`／`螢` at the time of writing) and the script fixes those up from a table,
   but only a human can tell Taiwan vocabulary from Mainland vocabulary.
4. Translate whatever changed into `shortcuts.en.md` and `shortcuts.ja.md` by hand. There is no machine
   translation step, and none is wanted: the wording of the other three locales is shipping copy.
5. Run `Scripts/Markdown2HTML/generate-shortcuts.swift`, then review the `git diff` of all four products.

When `vChewing-HomePage.io` is checked out somewhere other than the default sibling directory, point
the first two steps at it with `VCHEWING_HOMEPAGE=<dir>`.

## Non-goals

* No watch mode, no server, no dependency on a bundler: the product is a single self-contained HTML
  file that opens in a browser from inside the app bundle.
* No CSS or layout changes belong here beyond the stylesheet the script already carries; behaviour of
  the cheat sheet's *content* is out of scope.
* No automatic translation of the Traditional source into `en`／`ja`. Those two are hand-written, and
  the generator treats them as opaque Markdown apart from the shared version-number line.
