# grammar-import Specification

## Purpose

TBD - created by archiving change 'add-grammar-practice'. Update Purpose after archive.

## Requirements

### Requirement: Grammar Pipe-Delimited Line Parsing

The grammar parser SHALL split each non-blank input line on the `|` character and trim surrounding whitespace from each resulting cell. A line that yields exactly four cells after this split SHALL be interpreted as `question | correct | distractors_csv | explanation`. If a line begins and ends with `|` characters (GFM table row style), the parser SHALL strip exactly one leading and one trailing `|` before splitting, using the same trim-boundary-pipes rule as the vocabulary parser.

#### Scenario: four-cell grammar row produces a parsed item

- **WHEN** the grammar parser receives the single line `I ___ to school every day. | go | goes,going,gone | 主詞 I 用動詞原形`
- **THEN** the parser SHALL produce one `ParsedGrammarItem` with question `I ___ to school every day.`, correct `go`, distractors `[goes, going, gone]`, explanation `主詞 I 用動詞原形`, and zero parse errors

#### Scenario: GFM table row with surrounding pipes produces a parsed item

- **WHEN** the grammar parser receives the single line `| I ___ to school every day. | go | goes,going,gone | 主詞 I 用動詞原形 |`
- **THEN** the parser SHALL produce one `ParsedGrammarItem` with the same fields as if the row had been written without surrounding pipes, and zero parse errors

---
### Requirement: Distractors Column Requires Exactly Three Non-Empty Values

The grammar parser SHALL split the third cell on the `,` character, trim each resulting token of surrounding whitespace, and require exactly three non-empty tokens. A row whose distractors cell trims to fewer than three tokens, more than three tokens, or contains any empty token SHALL produce a `ParseError` referencing that line and no `ParsedGrammarItem`.

#### Scenario: valid three distractors are parsed in order

- **WHEN** the grammar parser receives the third cell content `goes, going, gone`
- **THEN** the resulting `ParsedGrammarItem.distractors` SHALL equal `[goes, going, gone]` in that exact order

#### Scenario: two distractors produce a parse error

- **WHEN** the grammar parser receives the single line `I ___ to school. | go | goes,going | explanation`
- **THEN** the parser SHALL produce zero items and exactly one `ParseError` whose lineNumber is 1 and whose rawLine equals the original line

#### Scenario: empty token inside distractors produces a parse error

- **WHEN** the grammar parser receives the single line `I ___ to school. | go | goes,,gone | explanation`
- **THEN** the parser SHALL produce zero items and exactly one `ParseError` whose lineNumber is 1 and whose rawLine equals the original line

##### Example: distractors column parsing outcomes

| Cell content              | Result                                             |
| ------------------------- | -------------------------------------------------- |
| `goes,going,gone`         | `[goes, going, gone]`                              |
| `goes, going, gone`       | `[goes, going, gone]` (whitespace trimmed)         |
| `goes,going`              | ParseError (fewer than three tokens)               |
| `goes,going,gone,gonna`   | ParseError (more than three tokens)                |
| `goes,,gone`              | ParseError (empty token in the middle)             |
| `,,`                      | ParseError (all tokens empty)                      |

---
### Requirement: Explanation Column Is Optional

The grammar parser SHALL treat the fourth cell as optional. If the fourth cell trims to an empty string, the parser SHALL set the resulting `explanation` field to nil. Otherwise the parser SHALL set `explanation` to the trimmed cell content.

#### Scenario: empty explanation cell yields nil explanation

- **WHEN** the grammar parser receives the single line `I ___ to school every day. | go | goes,going,gone |  `
- **THEN** the parser SHALL produce one item whose `explanation` is nil, with zero parse errors

#### Scenario: non-empty explanation cell is preserved verbatim after trimming

- **WHEN** the grammar parser receives the single line `I ___ to school every day. | go | goes,going,gone | 主詞 I 用動詞原形`
- **THEN** the parser SHALL produce one item whose `explanation` equals `主詞 I 用動詞原形`

---
### Requirement: Grammar Blank And Non-Row Line Handling

The grammar parser SHALL silently skip lines that are empty or contain only whitespace, emitting neither an item nor an error for those lines. The grammar parser SHALL also recognize GFM table separator lines (whose cells after boundary strip contain only `-` and `:` characters and whose original trimmed form contains at least one `|`) and skip them silently, and SHALL recognize a table header row that appears before any grammar item has been produced when its four cells match the grammar header keyword sets (word column set `{ question, sentence, 題目, 例句 }` for cell 1 and `{ correct, answer, 正解, 答案 }` for cell 2), skipping such a header row silently. All other non-blank lines whose cell count is neither exactly 4 SHALL produce a `ParseError`.

#### Scenario: blank lines between items do not create items or errors

- **WHEN** the grammar parser receives an input consisting of `I ___ home. | go | goes,going,gone | note1`, an empty line, a whitespace-only line, and `She ___ tea. | drinks | drink,drinking,drank | note2`
- **THEN** the parser SHALL emit exactly two items in input order and zero parse errors

#### Scenario: header row at file top is skipped

- **WHEN** the grammar parser receives lines `| question | correct | distractors | explanation |`, `| -------- | ------- | ----------- | ----------- |`, and `| I ___ home. | go | goes,going,gone | note |`
- **THEN** the parser SHALL emit exactly one item (question `I ___ home.`) and zero parse errors

#### Scenario: separator line without any pipe is not treated as separator

- **WHEN** the grammar parser receives the single line `---`
- **THEN** the parser SHALL produce zero items and exactly one `ParseError` whose lineNumber is 1

---
### Requirement: Automatic Batching On Grammar Persist

When parsed grammar items are persisted into a `GrammarDeck`, the system SHALL group the new items into `GrammarBatch` instances in import order, using the shared batch size defined for the project (40), with the final batch holding any remainder of 1 to 40 items. The batch size SHALL NOT be defined independently for grammar; it SHALL come from the same constant that governs vocabulary batching, so the two sides cannot drift apart.

The system SHALL NOT modify any pre-existing batch in the deck, including a trailing batch that holds fewer than the batch size.

#### Scenario: first grammar import into empty deck creates aligned batches

- **WHEN** the user imports 45 valid grammar items into a `GrammarDeck` that previously had zero batches
- **THEN** the deck SHALL contain two batches with item counts 40 and 5 at indices 1 and 2 respectively

#### Scenario: subsequent grammar import preserves trailing batch

- **WHEN** the user imports 30 additional items into a deck whose existing batches hold 40 and 5 items at indices 1 and 2 respectively
- **THEN** the deck SHALL contain three batches with item counts 40, 5, and 30 at indices 1 through 3 respectively, and batch 2 SHALL still hold its original 5 items in the original order

#### Scenario: grammar and vocabulary use the same batch size

- **WHEN** the batch size constant for grammar is compared with the one for vocabulary
- **THEN** the two SHALL be equal

---
### Requirement: Grammar Import Entry Points

The system SHALL provide two grammar import entry points. The first SHALL be an in-app paste textbox where the user pastes raw markdown text, selects a target `GrammarDeck`, and triggers import. The second SHALL be a file picker that reads `.md` or `.txt` files from the iOS Files app and routes their UTF-8 contents through the same grammar parser. Both entry points SHALL allow the user to select only from `GrammarDeck` instances (never `Deck` instances used by the vocabulary domain).

#### Scenario: grammar paste import flow

- **WHEN** the user pastes pipe-delimited grammar markdown into the grammar paste textbox, selects a `GrammarDeck`, and taps the import action
- **THEN** the system SHALL parse the input, persist the resulting items into the target `GrammarDeck` under the 20-item batching rule, and display any `ParseError` records with their line numbers and original line text

#### Scenario: grammar file picker import flow

- **WHEN** the user selects a `.md` or `.txt` file via the iOS Files app picker in the grammar import view and confirms a target `GrammarDeck`
- **THEN** the system SHALL read the file as UTF-8, parse it through the grammar parser, and persist the items into the target `GrammarDeck` under the 20-item batching rule
