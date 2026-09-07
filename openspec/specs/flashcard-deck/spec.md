# flashcard-deck Specification

## Purpose

TBD - created by archiving change 'flashcard-app-mvp'. Update Purpose after archive.

## Requirements

### Requirement: Deck-Batch-Card Hierarchy

The system SHALL model vocabulary using three persistent entities: `Deck`, `Batch`, and `Card`. A `Deck` SHALL own zero or more `Batch` instances. A `Batch` SHALL own zero or more `Card` instances. Deleting a `Deck` SHALL cascade-delete its batches, which SHALL cascade-delete their cards.

#### Scenario: cascading delete removes nested data

- **WHEN** the user deletes a deck that owns 3 batches and 130 cards
- **THEN** the deck, its 3 batches, and all 130 cards SHALL be removed from persistent storage

---
### Requirement: Card Fields

Each `Card` SHALL persist the following fields and types: `word` as a non-empty `String`, `partOfSpeech` as an optional `String` (nil means no part of speech), `translation` as a non-empty `String`, `wrongCount` as a non-negative `Int` defaulting to 0, and `importOrder` as an `Int` storing the zero-based position of the card within its owning batch in import order.

#### Scenario: card fields round-trip through persistence

- **WHEN** a card with word `apple`, partOfSpeech `n.`, translation `蘋果`, wrongCount 5, and importOrder 12 is persisted, then re-fetched in a new app launch
- **THEN** all five fields SHALL match the original values exactly

---
### Requirement: Wrong Count Is Monotonic

The system SHALL increment a card's `wrongCount` by exactly 1 for every wrong translation selection or 「我不會」 tap, in either a main quiz or a mistake quiz. The system SHALL NOT decrement `wrongCount` under any circumstance, including correct answers, quiz exit, deck navigation, or app restart.

#### Scenario: correct answer does not change wrongCount

- **WHEN** a card whose current wrongCount is 3 is answered with its correct translation in a quiz
- **THEN** the card's wrongCount SHALL remain 3

#### Scenario: wrong selection increments wrongCount

- **WHEN** a card whose current wrongCount is 3 receives a wrong translation selection in a quiz
- **THEN** the card's wrongCount SHALL become 4

#### Scenario: 我不會 tap increments wrongCount

- **WHEN** a card whose current wrongCount is 3 receives a 「我不會」 tap in a quiz
- **THEN** the card's wrongCount SHALL become 4

---
### Requirement: Batch Index And Immutability

Each `Batch` SHALL store a 1-based `index` that reflects its position within its owning deck. After a `Batch` is created, the system SHALL NOT add cards to it, remove cards from it, or change its `index`.

#### Scenario: batch indices are sequential within a deck

- **WHEN** three batches are created in order within a deck
- **THEN** their indices SHALL be 1, 2, 3 in creation order

#### Scenario: subsequent imports never mutate an existing batch

- **WHEN** the user imports 20 additional cards into a deck whose existing batches have sizes 50, 50, 30 at indices 1, 2, 3
- **THEN** batches 1, 2, 3 SHALL retain their original sizes and contents, and a new batch 4 of size 20 SHALL be created

---
### Requirement: Navigation Surfaces

The system SHALL provide three navigation screens for the vocabulary domain. The Deck List screen SHALL be reachable from the `單字` button on the app Home shell; it SHALL list every deck and SHALL allow creating a new deck by user-supplied name. The Batch List screen SHALL list every batch within a chosen deck and SHALL display, for each batch, its `index`, card count, and the sum of `wrongCount` across the batch's cards. The Batch Home screen SHALL display the selected batch's identity and SHALL offer entering Preview and starting the main quiz as its two navigation actions. It MAY also carry batch-scoped maintenance actions defined by other capabilities; those SHALL NOT be counted as navigation actions.

#### Scenario: empty state on first vocabulary visit

- **WHEN** the user opens the app for the first time and taps the `單字` button on the Home shell before any deck has been created
- **THEN** the Deck List screen SHALL render zero deck rows and SHALL display a visible control to create the first deck

#### Scenario: batch list row content

- **WHEN** the user opens the Batch List for a deck whose batch 1 contains 40 cards whose summed wrongCount is 27
- **THEN** the row for batch 1 SHALL display index 1, card count 40, and cumulative wrongCount 27

#### Scenario: batch home offers preview and quiz

- **WHEN** the user opens Batch Home for any batch
- **THEN** the screen SHALL display one control that opens the Preview screen for that batch and one control that starts a main quiz for that batch
