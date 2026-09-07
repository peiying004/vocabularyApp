# vocabulary-import Specification

## Purpose

TBD - created by archiving change 'flashcard-app-mvp'. Update Purpose after archive.

## Requirements

### Requirement: Pipe-Delimited Line Parsing

The parser SHALL split each input line on the `|` character and trim surrounding whitespace from each resulting cell. A line that yields three cells SHALL be parsed as `word | partOfSpeech | translation`. A line that yields two cells SHALL be parsed as `word | translation` with `partOfSpeech` set to nil. An empty middle cell in a three-cell line SHALL be treated as `partOfSpeech` = nil.

#### Scenario: three-cell line with part of speech

- **WHEN** the parser receives the single line `apple | n. | 蘋果`
- **THEN** the parser SHALL produce one card with word `apple`, partOfSpeech `n.`, translation `蘋果`

#### Scenario: two-cell line without part of speech

- **WHEN** the parser receives the single line `look forward to | 期待`
- **THEN** the parser SHALL produce one card with word `look forward to`, partOfSpeech nil, translation `期待`

#### Scenario: three-cell line with empty middle cell

- **WHEN** the parser receives the single line `look forward to |  | 期待`
- **THEN** the parser SHALL produce one card with word `look forward to`, partOfSpeech nil, translation `期待`

---
### Requirement: Blank Line Handling

The parser SHALL silently skip lines that are empty or contain only whitespace, emitting neither a card nor an error for those lines.

#### Scenario: blank lines between vocabulary do not create cards or errors

- **WHEN** the parser receives input whose lines are `apple | n. | 蘋果`, an empty line, a whitespace-only line, then `banana | n. | 香蕉`
- **THEN** the parser SHALL emit exactly two cards in input order and zero parse errors

---
### Requirement: Invalid Line Reporting

When a non-blank line contains a pipe-cell count that is neither two nor three, the parser SHALL emit a `ParseError` containing the 1-based line number and the original line content. The parser SHALL continue processing remaining lines.

#### Scenario: invalid line with four cells does not abort import

- **WHEN** the parser receives lines `apple | n. | 蘋果`, then `bad line | with | four | cells`, then `banana | n. | 香蕉`
- **THEN** the parser SHALL emit two cards (`apple` from line 1, `banana` from line 3) and one `ParseError` with lineNumber 2 and the original line text

##### Example: mixed valid and invalid input

| Line | Content                          | Result                                              |
| ---- | -------------------------------- | --------------------------------------------------- |
| 1    | apple \| n. \| 蘋果              | Card(word=apple, pos=n., translation=蘋果)          |
| 2    | look forward to \| 期待          | Card(word=look forward to, pos=nil, translation=期待) |
| 3    | look forward to \| \| 期待       | Card(word=look forward to, pos=nil, translation=期待) |
| 4    | bad line with four \| \| \| cells | ParseError(lineNumber=4)                            |

---
### Requirement: Automatic 50-Card Batching On Persist

When parsed cards are persisted into a deck, the system SHALL group the new cards into batches of exactly 40 cards in import order, with the final batch holding any remainder of 1 to 40 cards. The same batch size SHALL apply to grammar items persisted into a grammar deck. The system SHALL NOT modify any pre-existing batch in the deck, including a trailing batch that holds fewer than 40 items.

The batch size SHALL be defined in exactly one place per content type and SHALL NOT be duplicated as a literal anywhere else in the system.

#### Scenario: first import into empty deck creates aligned batches

- **WHEN** the user imports 130 valid cards into a deck that previously had zero batches
- **THEN** the deck SHALL contain four batches with sizes 40, 40, 40, 10 in index order 1, 2, 3, 4

#### Scenario: subsequent import preserves trailing batch

- **WHEN** the user imports 60 additional cards into a deck whose existing batches have sizes 40, 40, 30 at indices 1, 2, 3
- **THEN** the deck SHALL contain five batches with sizes 40, 40, 30, 40, 20 at indices 1 through 5, and batch 3 SHALL still hold its original 30 cards

#### Scenario: grammar import uses the same batch size

- **WHEN** the user imports 50 valid grammar items into a grammar deck that previously had zero batches
- **THEN** the deck SHALL contain two batches with sizes 40 and 10 in index order 1, 2

##### Example: batching outcomes

| Existing Last Batch | New Items | Resulting New Batches     |
| ------------------- | --------- | ------------------------- |
| (none)              | 130       | 40, 40, 40, 10            |
| 30                  | 60        | 40, 20 (existing 30 kept) |
| 40                  | 25        | 25                        |
| 40                  | 100       | 40, 40, 20                |

---
### Requirement: Import Entry Points

The system SHALL provide two import entry points. The first SHALL be an in-app paste textbox where the user pastes raw markdown text, selects a target deck, and triggers import. The second SHALL be a file picker that reads `.md` or `.txt` files from the iOS Files app and routes their UTF-8 contents through the same parser.

#### Scenario: paste textbox import flow

- **WHEN** the user pastes pipe-delimited markdown into the paste textbox, selects a target deck, and taps the import action
- **THEN** the system SHALL parse the input, persist the resulting cards into the target deck under the batching rule, and display any `ParseError` records with their line numbers and original line text

#### Scenario: file picker import flow

- **WHEN** the user selects a `.md` or `.txt` file via the iOS Files-app picker and confirms a target deck
- **THEN** the system SHALL read the file as UTF-8, parse it through the same parser, and persist the cards into the target deck under the batching rule

---
### Requirement: GFM Table Row Boundary Pipes

The parser SHALL accept lines whose trimmed content both starts with `|` and ends with `|` by stripping exactly one leading and one trailing `|` before splitting on `|`. After stripping, the remaining content SHALL be split on `|` and each cell SHALL be trimmed of surrounding whitespace exactly as for a plain pipe line. A line that ends up with two or three non-empty cells after stripping SHALL be parsed under the existing `Pipe-Delimited Line Parsing` rules.

#### Scenario: three-cell GFM table row with surrounding pipes

- **WHEN** the parser receives the single line `| apple | n. | 蘋果 |`
- **THEN** the parser SHALL produce one card with word `apple`, partOfSpeech `n.`, translation `蘋果`, and zero parse errors

#### Scenario: two-cell GFM table row with surrounding pipes

- **WHEN** the parser receives the single line `| look forward to | 期待 |`
- **THEN** the parser SHALL produce one card with word `look forward to`, partOfSpeech nil, translation `期待`, and zero parse errors

#### Scenario: GFM row with empty middle cell

- **WHEN** the parser receives the single line `| give up |  | 放棄 |`
- **THEN** the parser SHALL produce one card with word `give up`, partOfSpeech nil, translation `放棄`, and zero parse errors

##### Example: mixed GFM and plain-pipe rows

| Line | Content                | Result                                                |
| ---- | ---------------------- | ----------------------------------------------------- |
| 1    | `\| apple \| n. \| 蘋果 \|`   | Card(word=apple, pos=n., translation=蘋果)             |
| 2    | `banana \| n. \| 香蕉`   | Card(word=banana, pos=n., translation=香蕉)            |
| 3    | `\| give up \|  \| 放棄 \|`   | Card(word=give up, pos=nil, translation=放棄)          |

---
### Requirement: GFM Table Separator Line Skipping

The parser SHALL silently skip separator lines commonly emitted by GFM table syntax. A line qualifies as a separator only when (a) the line's original trimmed form contains at least one `|` character, and (b) after any surrounding `|` are removed and each resulting cell is trimmed, every cell is either empty or composed exclusively of the characters `-` and `:`, with at least one cell that is non-empty. A line that does not contain a `|` (for example a YAML front matter `---` marker) SHALL NOT be classified as a separator. A separator line SHALL NOT produce a card and SHALL NOT produce a `ParseError`. After the parser has observed a separator line within the current input, the parser SHALL NOT treat any subsequent line as a table header.

#### Scenario: separator line between header and data rows

- **WHEN** the parser receives lines `| word | pos | translation |`, `| ---- | ---- | ---- |`, `| apple | n. | 蘋果 |`
- **THEN** the parser SHALL produce exactly one card (word=apple, pos=n., translation=蘋果) and zero parse errors

#### Scenario: separator with alignment colons is skipped

- **WHEN** the parser receives the single line `| :--- | :---: | ---: |`
- **THEN** the parser SHALL produce zero cards and zero parse errors

##### Example: separator recognition

| Content              | Classification |
| -------------------- | -------------- |
| `\| --- \| --- \|`         | separator      |
| `\| :--- \| ---: \|`       | separator      |
| `\| :---: \| :---: \|`     | separator      |
| `\| ---abc \| --- \|`      | not a separator (contains letters) |
| `\|  \|  \|`               | not a separator (all cells empty)  |

---
### Requirement: GFM Table Header Row Skipping

The parser SHALL silently skip at most one table header row per input, and only when all of the following conditions hold at the moment the line is encountered: (a) the line's original trimmed form contains at least one `|` character, (b) the parser has not yet produced any cards from the current input, (c) the parser has not yet observed a separator line in the current input, (d) the line yields exactly three cells after any surrounding `|` are removed and trimming is applied, (e) the first cell trimmed and lowercased matches an entry in the word-header keyword set `{ "word", "vocabulary", "term", "單字", "詞彙", "英文" }`, and (f) the third cell trimmed and lowercased matches an entry in the translation-header keyword set `{ "translation", "meaning", "翻譯", "中文", "釋義" }`. A skipped header row SHALL NOT produce a card and SHALL NOT produce a `ParseError`. A line that does not satisfy every condition SHALL be treated as a normal data row.

#### Scenario: three-cell English header row is skipped

- **WHEN** the parser receives lines `| word | pos | translation |`, `| ---- | ---- | ---- |`, `| apple | n. | 蘋果 |`
- **THEN** the parser SHALL produce one card (word=apple, pos=n., translation=蘋果) and zero parse errors

#### Scenario: three-cell Traditional Chinese header row is skipped

- **WHEN** the parser receives lines `| 單字 | 詞性 | 翻譯 |`, `| ---- | ---- | ---- |`, `| acute | adj. | 急性的 |`
- **THEN** the parser SHALL produce one card (word=acute, pos=adj., translation=急性的) and zero parse errors

#### Scenario: header-like row after first card is treated as data

- **WHEN** the parser receives lines `| apple | n. | 蘋果 |`, `| word | pos | translation |`
- **THEN** the parser SHALL produce two cards: card 1 (word=apple, pos=n., translation=蘋果) and card 2 (word=word, pos=pos, translation=translation), and zero parse errors

#### Scenario: three-cell row whose keywords do not match is treated as data

- **WHEN** the parser receives the single line `| foo | bar | baz |`
- **THEN** the parser SHALL produce one card (word=foo, pos=bar, translation=baz) and zero parse errors

##### Example: header-skipping matrix

| Position in input                                                    | Line content                    | Classification                       |
| -------------------------------------------------------------------- | ------------------------------- | ------------------------------------ |
| first non-blank, no separator yet                                    | `\| word \| pos \| translation \|`    | header (skipped, no card, no error)  |
| first non-blank, no separator yet, non-matching cells                | `\| foo \| bar \| baz \|`             | data (card produced)                 |
| after at least one card produced                                     | `\| word \| pos \| translation \|`    | data (card produced with those cells)|
| after a separator line has already been observed in this input       | `\| word \| pos \| translation \|`    | data (card produced with those cells)|

---
### Requirement: Backward Compatibility With Plain Pipe Format

The parser SHALL continue to accept plain pipe-delimited input in exactly the same way as before this change, meaning lines that do not both start and end with `|` SHALL be parsed under the existing `Pipe-Delimited Line Parsing` and `Blank Line Handling` rules without modification. Existing plain-pipe test fixtures SHALL produce byte-for-byte the same `(cards, errors)` output.

#### Scenario: plain three-cell line still parses as one card

- **WHEN** the parser receives the single line `apple | n. | 蘋果`
- **THEN** the parser SHALL produce one card (word=apple, pos=n., translation=蘋果) and zero parse errors

#### Scenario: plain two-cell line still parses as one card

- **WHEN** the parser receives the single line `look forward to | 期待`
- **THEN** the parser SHALL produce one card (word=look forward to, pos=nil, translation=期待) and zero parse errors

#### Scenario: plain-pipe four-cell line still produces a parse error

- **WHEN** the parser receives the single line `bad line | with | four | cells`
- **THEN** the parser SHALL produce zero cards and exactly one parse error whose lineNumber is 1 and whose rawLine equals the original input

---
### Requirement: Batch Capacity Invariant

The per-batch item count established by import chunking SHALL also be a hard upper bound for every operation that adds items to an existing batch, not only for import. Neither a vocabulary `Batch` nor a `GrammarBatch` SHALL hold more than 40 items at any time. Any operation that would exceed the bound SHALL be refused without creating, moving, or modifying any item.

A batch holding fewer than the maximum is valid. Deletion reduces a batch below the maximum and SHALL NOT trigger any refill from other batches.

Batches created before the bound was set to 40 SHALL be left as they are. The system SHALL NOT re-split existing batches to match a changed bound.

#### Scenario: Import chunking respects the bound

- **WHEN** the user imports 130 valid cards into an empty deck
- **THEN** no resulting batch holds more than 40 cards

#### Scenario: Adding to a full batch is refused

- **WHEN** an operation attempts to add a card to a batch that already holds 40 cards
- **THEN** the operation is refused, the batch still holds 40 cards, and no new batch is created

#### Scenario: A partially filled batch is not refilled after deletion

- **WHEN** the user deletes 10 cards from a batch holding 40 cards
- **THEN** the batch holds 30 cards and no cards are moved into it from any other batch

##### Example: capacity bounds per content type

| Batch type     | Maximum items | Source constant                 |
| -------------- | ------------- | ------------------------------- |
| `Batch`        | 40            | `CardImporter.chunkSize`        |
| `GrammarBatch` | 40            | `GrammarItemImporter.chunkSize` |
