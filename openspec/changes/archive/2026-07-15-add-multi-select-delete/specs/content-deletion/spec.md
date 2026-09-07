## ADDED Requirements

### Requirement: Multi-Select Batch Deletion

Each batch list screen SHALL provide an edit mode that lets the user select one or more batches and delete the selected batches in a single action. This applies symmetrically to the vocabulary batch list (`Batch` under a `Deck`) and the grammar batch list (`GrammarBatch` under a `GrammarDeck`). Deleting a batch SHALL cascade-delete every card or grammar item it owns, together with their practice records (e.g. `wrongCount`). Selection SHALL be cleared and edit mode SHALL exit after a successful deletion.

#### Scenario: User deletes multiple selected batches

- **WHEN** the user enters edit mode on a batch list, selects two batches, and confirms deletion
- **THEN** both selected batches and all their cards or grammar items are removed, and the remaining batches stay in the list

#### Scenario: Deleting a batch removes its practice records

- **WHEN** the user deletes a batch that contains items carrying non-zero `wrongCount`
- **THEN** those items and their accumulated wrong counts are permanently removed with the batch

### Requirement: Multi-Select Item Deletion

Each item list screen SHALL provide an edit mode that lets the user select one or more individual items and delete them in a single action. This applies to the vocabulary preview list (`Card` within a `Batch`) and the grammar preview list (`GrammarItem` within a `GrammarBatch`). Deleting selected items SHALL remove only those items and preserve the remaining items in the same batch. Selection SHALL be cleared and edit mode SHALL exit after a successful deletion.

#### Scenario: User deletes selected items within a batch

- **WHEN** the user enters edit mode on an item list, selects some but not all items, and confirms deletion
- **THEN** only the selected items are removed and the unselected items remain in the batch

### Requirement: Deck Deletion

Each deck list screen SHALL let the user delete a deck. This applies to the vocabulary deck list (`Deck`) and the grammar deck list (`GrammarDeck`). Deleting a deck SHALL cascade-delete all of its batches and every card or grammar item within them.

#### Scenario: User deletes a deck

- **WHEN** the user deletes a deck that owns batches and items
- **THEN** the deck, all of its batches, and all of their cards or grammar items are removed from the app

### Requirement: Deletion Confirmation

Before any multi-select deletion is committed, the system SHALL present a confirmation dialog stating the number of batches or items to be deleted and warning that the associated cards or grammar items and their practice records will also be removed. The deletion SHALL be committed only when the user confirms, and SHALL be abandoned with no data change when the user cancels.

#### Scenario: User confirms deletion

- **WHEN** the user selects items to delete and taps the confirming action in the dialog
- **THEN** the selected items are deleted

#### Scenario: User cancels deletion

- **WHEN** the confirmation dialog is shown and the user cancels
- **THEN** no items are deleted and the selection is preserved

### Requirement: Empty Batch Auto-Removal

When item-level deletion leaves a batch with zero items, the system SHALL remove that now-empty batch automatically as part of the same deletion. An empty batch SHALL NOT remain in a batch list.

#### Scenario: Deleting the last items of a batch removes the batch

- **WHEN** the user deletes every remaining item in a batch
- **THEN** the batch itself is removed and no zero-item batch is shown

### Requirement: Contiguous Batch Renumbering

After any operation that reduces the number of batches in a deck — whole-batch deletion or empty-batch auto-removal — the system SHALL renumber the deck's remaining batches so their `index` values form a contiguous ascending sequence that preserves the existing relative order. No gap or duplicate index SHALL remain. To support this, `Batch.index` and `GrammarBatch.index` SHALL be writable by the renumbering logic.

#### Scenario: Deleting a middle batch renumbers the rest

- **WHEN** a deck has batches numbered 1, 2, 3 and the user deletes batch 2
- **THEN** the remaining batches are renumbered so the list shows batches 1 and 2 with no gap

##### Example: renumber after deleting the middle batch

- **GIVEN** a deck with batches index=1 (20 items), index=2 (20 items), index=3 (15 items)
- **WHEN** the user deletes the batch with index=2
- **THEN** the surviving batches have index=1 (originally 1) and index=2 (originally 3), in that order

##### Example: renumber triggered by empty-batch removal

- **GIVEN** a deck with batches index=1, index=2, index=3 where index=2 has one remaining item
- **WHEN** the user deletes that last item in batch index=2
- **THEN** batch index=2 is auto-removed and the survivors are renumbered to index=1 (originally 1) and index=2 (originally 3)
