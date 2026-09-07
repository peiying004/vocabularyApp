## ADDED Requirements

### Requirement: Single Item Editing

Each item list screen SHALL let the user open an editing screen for one individual item and change its content fields. This applies to the vocabulary preview list (`Card` within a `Batch`) and the grammar preview list (`GrammarItem` within a `GrammarBatch`). The editing screen SHALL be reached by selecting a row while the list is NOT in edit mode; while the list is in edit mode, selecting a row SHALL keep its existing multi-select meaning. The system SHALL rely on the list's built-in selection/navigation arbitration for this switch rather than inspecting edit-mode state in a custom tap handler. The editing screen SHALL be pre-filled with the item's current field values.

For a `Card`, the editable fields SHALL be `word`, `partOfSpeech`, and `translation`. For a `GrammarItem`, the editable fields SHALL be `question`, `correct`, the three entries of `distractors`, and `explanation`.

#### Scenario: User edits a card and saves

- **WHEN** the user selects a card row outside edit mode, changes its translation, and saves
- **THEN** the editing screen closes and the list row displays the new translation

#### Scenario: User cancels editing

- **WHEN** the user opens the editing screen, changes one or more fields, and cancels
- **THEN** no change is persisted and the item keeps all of its original field values

#### Scenario: Selecting a row in edit mode does not open the editor

- **WHEN** the list is in edit mode and the user selects a row
- **THEN** the row is added to the multi-select selection and no editing screen is opened

---

### Requirement: Practice Records And Ordering Preserved On Edit

Editing an item's content SHALL NOT change its `wrongCount` or its `importOrder`. `wrongCount` SHALL remain writable only through `recordWrong()`. The edited item SHALL keep its position in the item list, which is ordered by `importOrder`.

#### Scenario: Editing a card preserves its wrong count

- **WHEN** the user edits the translation of a card whose `wrongCount` is 3
- **THEN** the card's `wrongCount` is still 3 after saving

#### Scenario: Editing an item preserves list position

- **WHEN** the user edits the second item in a batch of five items
- **THEN** the edited item is still displayed in the second position

---

### Requirement: Edit Validation Matches Import Rules

The editing screen SHALL apply the same required-field rules that the import parsers apply, and SHALL disable the save action while any rule is violated. No item that violates these rules SHALL be persisted.

For a `Card`, `word` and `translation` SHALL be non-empty after trimming surrounding whitespace; `partOfSpeech` SHALL NOT be required, and an empty `partOfSpeech` SHALL be stored as nil. For a `GrammarItem`, `question` and `correct` SHALL be non-empty after trimming surrounding whitespace, and `distractors` SHALL contain exactly three entries, each non-empty after trimming; `explanation` SHALL NOT be required, and an empty `explanation` SHALL be stored as nil.

#### Scenario: Save is blocked when a required field is empty

- **WHEN** the user clears the translation field of a card in the editing screen
- **THEN** the save action is disabled and the card's stored translation is unchanged

#### Scenario: Whitespace-only input is treated as empty

- **WHEN** the user replaces a card's word with a string containing only spaces
- **THEN** the save action is disabled

##### Example: card field validation

| word    | partOfSpeech | translation | Save enabled | Stored partOfSpeech |
| ------- | ------------ | ----------- | ------------ | ------------------- |
| apple   | n.           | 蘋果        | yes          | n.                  |
| apple   | (empty)      | 蘋果        | yes          | nil                 |
| (empty) | n.           | 蘋果        | no           | —                   |
| apple   | n.           | (empty)     | no           | —                   |
| "   "   | n.           | 蘋果        | no           | —                   |

##### Example: grammar item field validation

| question      | correct | distractors        | Save enabled |
| ------------- | ------- | ------------------ | ------------ |
| He ___ there. | goes    | go / going / gone  | yes          |
| He ___ there. | goes    | go / going         | no           |
| He ___ there. | goes    | go / (empty) / gone| no           |
| (empty)       | goes    | go / going / gone  | no           |
| He ___ there. | (empty) | go / going / gone  | no           |

---

### Requirement: Fixed Distractor Count

The grammar editing screen SHALL present exactly three distractor fields and SHALL NOT allow the user to add or remove distractor entries. Only the content of each of the three entries SHALL be editable.

#### Scenario: Grammar editor exposes exactly three distractor fields

- **WHEN** the user opens the editing screen for a grammar item
- **THEN** exactly three distractor fields are shown, with no control to add or remove a field

---

### Requirement: Single Item Creation Within A Batch

Each item list screen SHALL provide an action that opens the editing screen in creation mode, and SHALL append the created item to the batch the list belongs to. The created item's `importOrder` SHALL be one greater than the largest `importOrder` currently present in that batch, so the new item appears last in the list. The created item's `wrongCount` SHALL start at 0. Creation SHALL apply the same validation rules as editing.

#### Scenario: User creates a card in a batch

- **WHEN** the user opens the creation action on a batch holding three cards, fills in valid fields, and saves
- **THEN** the batch holds four cards and the new card is displayed last with `wrongCount` 0

##### Example: importOrder assigned on creation

- **GIVEN** a batch whose cards have `importOrder` values 0, 1, 2
- **WHEN** the user creates one new card
- **THEN** the new card has `importOrder` 3 and the existing cards keep `importOrder` 0, 1, 2

#### Scenario: Cancelling creation adds nothing

- **WHEN** the user opens the creation action, fills in fields, and cancels
- **THEN** no item is added to the batch

---

### Requirement: Creation Blocked At Batch Capacity

The maximum number of items a batch holds SHALL be 40, for both a vocabulary `Batch` and a `GrammarBatch`.

The creation action SHALL remain enabled regardless of how many items the batch holds. When the batch already holds its maximum, invoking the creation action SHALL present a dialog stating that the batch is full and directing the user to use the import function, and SHALL NOT open the editing screen. The item list screen SHALL NOT display a persistent capacity message outside that dialog.

In response to a creation attempt on a full batch, the system SHALL NOT create any item, SHALL NOT create a new batch, SHALL NOT move items between batches, and SHALL NOT exceed the maximum.

#### Scenario: Invoking creation on a full vocabulary batch shows the full dialog

- **WHEN** the user invokes the creation action on a vocabulary batch holding 40 cards
- **THEN** a dialog stating the batch is full is presented, no editing screen is opened, and the batch still holds 40 cards

#### Scenario: Invoking creation on a full grammar batch shows the full dialog

- **WHEN** the user invokes the creation action on a grammar batch holding 40 items
- **THEN** a dialog stating the batch is full is presented, no editing screen is opened, and the batch still holds 40 items

#### Scenario: Creation action stays available below capacity

- **WHEN** the user invokes the creation action on a batch holding 39 items
- **THEN** the editing screen opens in creation mode and no full-batch dialog is presented

#### Scenario: A full batch does not overflow into another batch

- **WHEN** a deck holds batch 1 with 40 cards and batch 2 with 10 cards, and the user invokes the creation action on batch 1
- **THEN** the full-batch dialog is presented, batch 1 still holds 40 cards, batch 2 still holds 10 cards, and no new batch is created

##### Example: capacity boundary behavior

| Items in batch | Creation action | Invoking it opens         |
| -------------- | --------------- | ------------------------- |
| 0              | enabled         | editing screen            |
| 39             | enabled         | editing screen            |
| 40             | enabled         | full-batch dialog         |

---

### Requirement: Single Item Deletion From The Editing Screen

The editing screen for an existing item SHALL provide a delete action that removes that item. The deletion SHALL be committed only after the user confirms it, and SHALL be abandoned with no data change when the user cancels. Deleting from the editing screen SHALL follow the same batch cleanup behavior as item deletion from the list: when the deletion leaves the batch with zero items, the batch SHALL be removed and the deck's remaining batches SHALL be renumbered into a contiguous ascending sequence.

#### Scenario: User deletes an item from the editing screen

- **WHEN** the user opens an item in a batch of five items and confirms deletion
- **THEN** the item is removed, the editing screen closes, and the batch holds the remaining four items

#### Scenario: Deleting the last item of a batch removes the batch

- **WHEN** the user opens the only remaining item of a batch and confirms deletion
- **THEN** the item and its batch are both removed and the item list screen closes

##### Example: renumbering after deleting the last item of a middle batch

- **GIVEN** a deck with batches index=1 (20 items), index=2 (1 item), index=3 (15 items)
- **WHEN** the user opens the single item in batch index=2 and confirms deletion
- **THEN** batch index=2 is removed and the survivors are renumbered to index=1 (originally 1) and index=2 (originally 3)

#### Scenario: User cancels deletion from the editing screen

- **WHEN** the user chooses the delete action and then cancels the confirmation
- **THEN** the item is not deleted and the editing screen stays open

---

### Requirement: Batch-Level Wrong Count Reset

Each batch home screen SHALL provide an action that resets the accumulated wrong count of every item in that batch to 0. This applies to the vocabulary batch home screen (`BatchHomeView`) and the grammar batch home screen (`GrammarBatchHomeView`). The reset SHALL be committed only after the user confirms it, and SHALL be abandoned with no data change when the user cancels. The action SHALL be disabled when the batch's accumulated wrong count is already 0.

The reset SHALL affect only the batch it was invoked from. It SHALL NOT change any item's content fields, `importOrder`, or batch membership, SHALL NOT remove any item or batch, and SHALL NOT change any batch `index`.

`wrongCount` SHALL remain `private(set)` on `Card` and on `GrammarItem`. The reset SHALL be performed through a named `resetWrongCount()` method on each model, mirroring the existing `recordWrong()` method. No writable `wrongCount` property SHALL be exposed.

#### Scenario: User resets the wrong count of a batch

- **WHEN** the user invokes the reset action on a batch whose items carry non-zero wrong counts and confirms
- **THEN** every item in that batch has a wrong count of 0, the batch home screen shows an accumulated wrong count of 0, and the reset action becomes disabled

##### Example: resetting a three-card batch

- **GIVEN** batch 1 holds cards apple (`wrongCount` 2), banana (`wrongCount` 0), cherry (`wrongCount` 5), displayed as "累計錯 7 次"
- **WHEN** the user invokes the reset action and confirms
- **THEN** apple, banana, and cherry all have `wrongCount` 0, the batch home screen displays "累計錯 0 次", and each card keeps its original word, translation, and `importOrder`

#### Scenario: Reset does not affect other batches

- **WHEN** the user resets the wrong count of batch 1 in a deck that also holds batch 2 with a non-zero accumulated wrong count
- **THEN** batch 1 shows an accumulated wrong count of 0 and batch 2 keeps its original accumulated wrong count

##### Example: only the invoked batch is reset

- **GIVEN** a deck with batch 1 (accumulated wrong count 7) and batch 2 (accumulated wrong count 4)
- **WHEN** the user resets batch 1
- **THEN** the batch list shows batch 1 with accumulated wrong count 0 and batch 2 with accumulated wrong count 4

#### Scenario: User cancels the reset

- **WHEN** the user invokes the reset action and cancels the confirmation
- **THEN** no wrong count changes and the batch home screen still shows the original accumulated wrong count

#### Scenario: Reset action is disabled when nothing has been answered wrong

- **WHEN** the user views a batch whose items all have a wrong count of 0
- **THEN** the reset action is disabled

#### Scenario: Wrong counts accumulate again after a reset

- **WHEN** the user resets a batch and then answers one of its items incorrectly in a quiz
- **THEN** that item's wrong count is 1

---

### Requirement: Reset Is Explicit And Never Automatic

The system SHALL reset an item's `wrongCount` only in response to the user invoking the batch-level reset action. Editing an item's content, creating an item, or deleting another item in the same batch SHALL NOT reset the `wrongCount` of any surviving item.

#### Scenario: Editing content does not reset the wrong count

- **WHEN** the user edits the translation of a card whose `wrongCount` is 4 and saves
- **THEN** the card's `wrongCount` is still 4

#### Scenario: Deleting one item does not reset the others

- **WHEN** the user deletes one item from a batch whose remaining items carry non-zero wrong counts
- **THEN** the remaining items keep their original wrong counts
