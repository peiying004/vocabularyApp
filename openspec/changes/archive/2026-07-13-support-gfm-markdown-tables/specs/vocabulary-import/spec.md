## ADDED Requirements

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
