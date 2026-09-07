## MODIFIED Requirements

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

## ADDED Requirements

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
