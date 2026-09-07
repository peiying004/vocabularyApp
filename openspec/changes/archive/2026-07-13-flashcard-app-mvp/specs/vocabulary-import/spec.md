## ADDED Requirements

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

### Requirement: Blank Line Handling

The parser SHALL silently skip lines that are empty or contain only whitespace, emitting neither a card nor an error for those lines.

#### Scenario: blank lines between vocabulary do not create cards or errors

- **WHEN** the parser receives input whose lines are `apple | n. | 蘋果`, an empty line, a whitespace-only line, then `banana | n. | 香蕉`
- **THEN** the parser SHALL emit exactly two cards in input order and zero parse errors

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

### Requirement: Automatic 50-Card Batching On Persist

When parsed cards are persisted into a deck, the system SHALL group the new cards into batches of exactly 50 cards in import order, with the final batch holding any remainder of 1 to 50 cards. The system SHALL NOT modify any pre-existing batch in the deck, including a trailing batch that holds fewer than 50 cards.

#### Scenario: first import into empty deck creates aligned batches

- **WHEN** the user imports 130 valid cards into a deck that previously had zero batches
- **THEN** the deck SHALL contain three batches with sizes 50, 50, 30 in index order 1, 2, 3

#### Scenario: subsequent import preserves trailing batch

- **WHEN** the user imports 60 additional cards into a deck whose existing batches have sizes 50, 50, 30 at indices 1, 2, 3
- **THEN** the deck SHALL contain five batches with sizes 50, 50, 30, 50, 10 at indices 1 through 5, and batch 3 SHALL still hold its original 30 cards

##### Example: batching outcomes

| Existing Last Batch | New Cards | Resulting New Batches      |
| ------------------- | --------- | -------------------------- |
| (none)              | 130       | 50, 50, 30                 |
| 30                  | 60        | 50, 10 (existing 30 kept)  |
| 50                  | 25        | 25                         |
| 50                  | 100       | 50, 50                     |

### Requirement: Import Entry Points

The system SHALL provide two import entry points. The first SHALL be an in-app paste textbox where the user pastes raw markdown text, selects a target deck, and triggers import. The second SHALL be a file picker that reads `.md` or `.txt` files from the iOS Files app and routes their UTF-8 contents through the same parser.

#### Scenario: paste textbox import flow

- **WHEN** the user pastes pipe-delimited markdown into the paste textbox, selects a target deck, and taps the import action
- **THEN** the system SHALL parse the input, persist the resulting cards into the target deck under the batching rule, and display any `ParseError` records with their line numbers and original line text

#### Scenario: file picker import flow

- **WHEN** the user selects a `.md` or `.txt` file via the iOS Files-app picker and confirms a target deck
- **THEN** the system SHALL read the file as UTF-8, parse it through the same parser, and persist the cards into the target deck under the batching rule
