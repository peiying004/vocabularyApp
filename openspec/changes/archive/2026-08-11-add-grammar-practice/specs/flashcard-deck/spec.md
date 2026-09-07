## MODIFIED Requirements

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
