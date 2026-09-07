## MODIFIED Requirements

### Requirement: Creation Blocked At Batch Capacity

The maximum number of items a batch holds SHALL be 40, for both a vocabulary `Batch` and a `GrammarBatch`. No creation path SHALL cause a batch to exceed that maximum.

The creation action SHALL remain enabled regardless of how many items the batch holds. When the batch already holds its maximum, invoking the creation action SHALL present a dialog stating that the batch is full and offering exactly two choices: continue into a new batch, or cancel. The dialog SHALL NOT open the creation menu, the editing screen, or the paste screen before the user chooses. The item list screen SHALL NOT display a persistent capacity message outside that dialog.

Choosing to cancel SHALL create no item and no batch, and SHALL leave the deck unchanged. Choosing to continue SHALL open the creation menu with the deck as the write target instead of the full batch, so that saved content is placed in newly created batches appended after the deck's existing batches. The full batch SHALL NOT be modified by either choice.

#### Scenario: Invoking creation on a full vocabulary batch offers a new batch

- **WHEN** the user invokes the creation action on a vocabulary batch holding 40 cards
- **THEN** a dialog stating the batch is full is presented with a continue option and a cancel option, no creation menu is opened yet, and the batch still holds 40 cards

#### Scenario: Invoking creation on a full grammar batch offers a new batch

- **WHEN** the user invokes the creation action on a grammar batch holding 40 items
- **THEN** a dialog stating the batch is full is presented with a continue option and a cancel option, no creation menu is opened yet, and the batch still holds 40 items

#### Scenario: Cancelling at a full batch changes nothing

- **WHEN** the user invokes the creation action on a full batch and cancels the dialog
- **THEN** no creation menu opens, no item is created, no batch is created, and the deck's batch count is unchanged

#### Scenario: Continuing from a full batch writes into a new batch

- **WHEN** the user invokes the creation action on a full batch, chooses to continue, adds one item by hand, and saves
- **THEN** a new batch holding that one item is appended after the deck's existing batches, and the previously full batch still holds 40 items

#### Scenario: Creation action stays available below capacity

- **WHEN** the user invokes the creation action on a batch holding 39 items
- **THEN** the creation menu opens directly with that batch as the write target, and no full-batch dialog is presented

##### Example: capacity boundary behavior

| Items in batch | Creation action | Invoking it opens | Write target       |
| -------------- | --------------- | ----------------- | ------------------ |
| 0              | enabled         | creation menu     | that batch         |
| 39             | enabled         | creation menu     | that batch         |
| 40             | enabled         | full-batch dialog | new batches, after the user chooses to continue |

## ADDED Requirements

### Requirement: Creation Action Offers Manual Entry And Paste

When the creation menu opens, it SHALL present exactly two options: adding one item by hand, and pasting Markdown. Choosing the manual option SHALL open the editing screen in creation mode. Choosing the paste option SHALL open the paste screen. Both options SHALL write to whichever target the menu was opened with — the current batch when it is below capacity, or the deck when the user chose to continue from a full batch.

#### Scenario: Creation menu offers both paths

- **WHEN** the user invokes the creation action on a batch below capacity
- **THEN** a menu with exactly two options is presented, one for adding a single item by hand and one for pasting Markdown

#### Scenario: Manual option behaves as before on a batch with room

- **WHEN** the user chooses the manual option from a menu opened on a batch below capacity
- **THEN** the editing screen opens in creation mode with empty fields, and saving appends one item to that batch

#### Scenario: Both options honour a deck write target

- **WHEN** the user chooses to continue from a full batch and then picks either menu option
- **THEN** the content saved from that screen is placed in newly created batches appended after the deck's existing batches, and no existing batch is modified
