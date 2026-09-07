# grammar-deck Specification

## Purpose

TBD - created by archiving change 'add-grammar-practice'. Update Purpose after archive.

## Requirements

### Requirement: Grammar Entity Hierarchy

The system SHALL model grammar practice content using three persistent entities: `GrammarDeck`, `GrammarBatch`, and `GrammarItem`. A `GrammarDeck` SHALL own zero or more `GrammarBatch` instances. A `GrammarBatch` SHALL own zero or more `GrammarItem` instances. Deleting a `GrammarDeck` SHALL cascade-delete its batches, which SHALL cascade-delete their items.

#### Scenario: cascading delete removes nested grammar data

- **WHEN** the user deletes a `GrammarDeck` that owns 2 `GrammarBatch` instances holding a total of 30 `GrammarItem` instances
- **THEN** the deck, its 2 batches, and all 30 items SHALL be removed from persistent storage

---
### Requirement: GrammarItem Fields

Each `GrammarItem` SHALL persist the following fields and types: `question` as a non-empty `String`, `correct` as a non-empty `String`, `distractors` as an ordered collection of exactly three non-empty `String` values, `explanation` as an optional `String` (nil means no explanation), `wrongCount` as a non-negative `Int` defaulting to 0, and `importOrder` as an `Int` storing the zero-based position of the item within its owning batch in import order.

#### Scenario: grammar item fields round-trip through persistence

- **WHEN** an item with question `I ___ to school every day.`, correct `go`, distractors `[goes, going, gone]`, explanation `主詞 I 用動詞原形`, wrongCount 4, and importOrder 7 is persisted, then re-fetched in a new app launch
- **THEN** all six fields SHALL match the original values exactly, and the distractors SHALL retain their original order

---
### Requirement: Grammar Wrong Count Is Monotonic

The system SHALL increment a grammar item's `wrongCount` by exactly 1 for every wrong choice selection or `我不會` tap, in either a main grammar quiz or a grammar mistake quiz. The system SHALL NOT decrement `wrongCount` under any circumstance, including correct answers, quiz exit, deck navigation, or app restart.

#### Scenario: correct answer does not change grammar wrongCount

- **WHEN** an item whose current `wrongCount` is 2 is answered with its `correct` string in a grammar quiz
- **THEN** the item's `wrongCount` SHALL remain 2

#### Scenario: wrong selection increments grammar wrongCount

- **WHEN** an item whose current `wrongCount` is 2 receives a wrong choice selection in a grammar quiz
- **THEN** the item's `wrongCount` SHALL become 3

---
### Requirement: Grammar Batch Index And Immutability

Within any `GrammarDeck`, `GrammarBatch` `index` values SHALL be dense positive integers starting at 1, assigned in creation order. Once a batch has been created, its `items` collection SHALL NOT be reordered, and existing items SHALL NOT be moved out of it by subsequent imports.

#### Scenario: grammar batch indices are sequential within a deck

- **WHEN** three batches are created in sequence within the same `GrammarDeck`
- **THEN** their `index` values SHALL be 1, 2, and 3 respectively in creation order

#### Scenario: subsequent grammar imports never mutate an existing batch

- **WHEN** an import adds 25 new items to a deck whose existing batch 1 already holds 15 items
- **THEN** batch 1 SHALL still hold exactly the same 15 items in the same order, and the 25 new items SHALL land in batches 2 and beyond

---
### Requirement: Grammar Navigation Surfaces

The system SHALL provide three navigation screens for the grammar domain. The Grammar Deck List screen SHALL be reachable from the Grammar button on the app Home shell; it SHALL list every `GrammarDeck` and SHALL allow creating a new deck by user-supplied name. The Grammar Batch List screen SHALL list every batch within a chosen deck and SHALL display, for each batch, its `index`, item count, and the sum of `wrongCount` across the batch's items. The Grammar Batch Home screen SHALL display the selected batch's identity and SHALL offer exactly two actions: enter grammar Preview, or start the grammar main quiz.

#### Scenario: empty state on first grammar visit

- **WHEN** the user taps the Grammar button on the Home shell for the first time and no `GrammarDeck` has yet been created
- **THEN** the Grammar Deck List screen SHALL render zero deck rows and SHALL display a visible control to create the first grammar deck

#### Scenario: grammar batch list row content

- **WHEN** the user opens the Grammar Batch List for a deck whose batch 1 contains 20 items whose summed `wrongCount` is 11
- **THEN** the row for batch 1 SHALL display index 1, item count 20, and cumulative `wrongCount` 11

#### Scenario: grammar batch home offers preview and quiz

- **WHEN** the user opens Grammar Batch Home for any batch
- **THEN** the screen SHALL display exactly two action controls: one that opens the grammar Preview screen for that batch, and one that starts a grammar main quiz for that batch
