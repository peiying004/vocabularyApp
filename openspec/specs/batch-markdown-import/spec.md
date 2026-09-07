# batch-markdown-import Specification

## Purpose

TBD - created by archiving change 'add-batch-markdown-import'. Update Purpose after archive.

## Requirements

### Requirement: Paste Markdown Into An Existing Batch

Each item list screen SHALL provide a way to paste Markdown text and add the parsed items to the batch that screen belongs to. This applies to the vocabulary preview list (`Card` within a `Batch`) and the grammar preview list (`GrammarItem` within a `GrammarBatch`).

Items added this way SHALL receive `importOrder` values continuing from the batch's current maximum, in the order they appear in the pasted text, and SHALL start with a `wrongCount` of 0. Existing items in the batch SHALL keep their content fields, `wrongCount`, and `importOrder` unchanged.

The paste screen SHALL show how many more items the batch can still hold before the user confirms.

#### Scenario: Pasting items into a batch that has room

- **WHEN** the user pastes 5 valid items into a batch holding 32 items and confirms
- **THEN** the batch holds 37 items, the 5 new items appear last, and no new batch is created

##### Example: importOrder continues from the batch maximum

- **GIVEN** a batch holding 32 items whose `importOrder` values are 0 through 31
- **WHEN** the user pastes 5 valid items and confirms
- **THEN** the new items have `importOrder` 32, 33, 34, 35, 36 in pasted order, each with `wrongCount` 0

#### Scenario: Existing items are untouched by a paste

- **WHEN** the user pastes items into a batch whose existing items carry non-zero wrong counts
- **THEN** those existing items keep their content, their wrong counts, and their `importOrder`

---
### Requirement: Invalid Lines Are Reported Separately From Overflow

The paste screen SHALL apply the same parsing rules as the deck-level import: a line that cannot be parsed SHALL be skipped, SHALL NOT count toward the valid item count, and SHALL be listed with its 1-based line number and original text.

Invalid lines and the over-capacity condition SHALL be presented as two distinct things. The over-capacity decision SHALL be based only on the count of valid items.

#### Scenario: Invalid lines are skipped and listed

- **WHEN** the user pastes text in which 3 lines are valid and 1 line has an unparseable shape, into a batch with room for 10
- **THEN** 3 items are added to the batch and the 1 unparseable line is listed with its line number, and no over-capacity dialog is shown

#### Scenario: Text with no valid items adds nothing

- **WHEN** the user pastes text in which every line is unparseable
- **THEN** no item is added, every unparseable line is listed, and no over-capacity dialog is shown

---
### Requirement: Over-Capacity Paste Requires An Explicit User Choice

When the number of valid parsed items exceeds the batch's remaining capacity, the system SHALL present a dialog stating how many items the batch can still hold and how many do not fit, offering exactly two choices: create new batches for the remainder, or abandon the paste. The system SHALL NOT write anything before the user chooses.

When the number of valid parsed items is less than or equal to the remaining capacity, the system SHALL NOT present this dialog and SHALL write all items into the batch directly.

#### Scenario: Over-capacity paste shows the choice dialog

- **WHEN** the user pastes 12 valid items into a batch holding 32 items of a maximum 40
- **THEN** a dialog is presented stating that 8 fit and 4 do not, offering to create new batches or to abandon, and nothing has been written yet

#### Scenario: Paste within capacity does not show the dialog

- **WHEN** the user pastes 8 valid items into a batch holding 32 items of a maximum 40
- **THEN** no dialog is presented and all 8 items are added to the batch

##### Example: when the dialog appears

| Items in batch | Remaining capacity | Valid pasted items | Dialog shown |
| -------------- | ------------------ | ------------------ | ------------ |
| 32             | 8                  | 5                  | no           |
| 32             | 8                  | 8                  | no           |
| 32             | 8                  | 12                 | yes          |
| 40             | 0                  | 1                  | not reachable — the full-batch dialog resolves the target first, so the paste screen always opens with a deck target |

---
### Requirement: Abandoning An Over-Capacity Paste Writes Nothing

When the user abandons an over-capacity paste, the system SHALL write no items at all. The target batch SHALL hold exactly the items it held before, and the deck SHALL hold exactly the batches it held before. Partial writes SHALL NOT remain.

#### Scenario: User abandons an over-capacity paste

- **WHEN** the user pastes 12 valid items into a batch holding 32 items and chooses to abandon
- **THEN** the batch still holds 32 items and the deck's batch count is unchanged

---
### Requirement: Overflow Fills The Batch Then Creates New Batches

When the user chooses to create new batches for an over-capacity paste, the system SHALL first write enough items to fill the target batch to its maximum, in pasted order, and SHALL then group the remaining items into new batches using the same batch size and the same numbering rule as import. The new batches SHALL be appended after the deck's existing batches, with `index` values continuing from the deck's current maximum, contiguous and non-overlapping. Items in each new batch SHALL have `importOrder` starting at 0.

The system SHALL NOT modify any pre-existing batch other than the target batch, and SHALL NOT produce any batch holding more than the maximum.

#### Scenario: Overflow fills the batch and creates one new batch

- **WHEN** the user pastes 12 valid items into a batch holding 32 items of a maximum 40 and chooses to create new batches
- **THEN** the target batch holds 40 items, one new batch is created holding the remaining 4 items, and 12 items were added in total

##### Example: overflow spanning several new batches

- **GIVEN** a deck whose batches are index=1 (40 items) and index=2 (39 items), maximum 40
- **WHEN** the user pastes 83 valid items into batch index=2 and chooses to create new batches
- **THEN** batch index=2 holds 40 items, and three new batches are created: index=3 (40 items), index=4 (40 items), index=5 (2 items)

#### Scenario: Overflow does not disturb other existing batches

- **WHEN** an over-capacity paste into batch 2 creates new batches
- **THEN** batch 1 holds exactly the items it held before and keeps its `index`

#### Scenario: No batch exceeds the maximum after overflow

- **WHEN** any over-capacity paste completes with new batches created
- **THEN** every batch in the deck holds no more than the maximum number of items

---
### Requirement: Paste With A Deck Target Writes Only New Batches

When the paste screen is opened with a deck as its target — which happens when the user chose to continue from a full batch — every valid parsed item SHALL be placed in newly created batches appended after the deck's existing batches, grouped using the same batch size and numbering rule as import. The screen SHALL NOT show a remaining-capacity figure and SHALL NOT present the over-capacity dialog, because no existing batch is being filled.

No pre-existing batch SHALL be modified. When the pasted text yields no valid items, no batch SHALL be created.

#### Scenario: Deck-target paste creates new batches only

- **WHEN** the user continues from a full batch and pastes 12 valid items
- **THEN** one new batch holding 12 items is appended after the deck's existing batches, the previously full batch still holds 40 items, and no over-capacity dialog is shown

##### Example: deck-target paste spanning several new batches

- **GIVEN** a deck whose batches are index=1 (40 items) and index=2 (40 items), maximum 40
- **WHEN** the user continues from batch index=2 and pastes 83 valid items
- **THEN** three new batches are created: index=3 (40 items), index=4 (40 items), index=5 (3 items), and batches index=1 and index=2 are unchanged

#### Scenario: Deck-target paste with no valid items creates nothing

- **WHEN** the user continues from a full batch and pastes text in which every line is unparseable
- **THEN** no batch is created, the deck's batch count is unchanged, and every unparseable line is listed
