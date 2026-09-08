## ADDED Requirements

### Requirement: First-Launch Tutorial Overlay

The system SHALL present a tutorial overlay above the Home shell when the app launches and the persisted seen-tutorial flag is absent or false. The overlay SHALL render a translucent scrim through which the Home shell remains partially visible, and the scrim SHALL intercept all touch input so that no Home shell control responds while the overlay is presented. The overlay SHALL center a single card containing the tutorial content. When the persisted seen-tutorial flag is true at launch, the system SHALL NOT present the overlay.

#### Scenario: overlay appears on a launch with no stored flag

- **WHEN** the app launches and no seen-tutorial flag has been persisted
- **THEN** the tutorial overlay SHALL be presented above the Home shell, showing page 1 of 4

#### Scenario: overlay is suppressed once the flag is true

- **WHEN** the app launches and the persisted seen-tutorial flag is true
- **THEN** the tutorial overlay SHALL NOT be presented, and the Home shell SHALL be immediately interactive

#### Scenario: Home shell controls are inert while the overlay is presented

- **WHEN** the tutorial overlay is presented and the user taps the screen region occupied by the Vocabulary entry button of the Home shell
- **THEN** no navigation SHALL occur and the overlay SHALL remain presented

### Requirement: Tutorial Page Content And Paging

The tutorial card SHALL contain exactly four pages, navigable by horizontal swipe in both directions. Each page SHALL render a vector illustration drawn with SwiftUI primitives, a title, and explanatory body text. The card SHALL display a page indicator showing which of the four pages is currently visible. The page sequence SHALL be a fixed static definition and SHALL NOT be derived from user data. The system SHALL NOT bundle raster image assets for these illustrations.

Every page SHALL present a primary control in the same position at the bottom of the card, so that the card height does not change between pages. On every page except the last, that control SHALL advance to the next page. On the last page, that control SHALL end the tutorial as specified by the exit-path requirement.

#### Scenario: swiping advances and returns through pages

- **WHEN** the user swipes left on page 1 and then swipes right
- **THEN** the card SHALL display page 2 after the first swipe and page 1 after the second, and the page indicator SHALL reflect the visible page in each case

#### Scenario: primary control advances through the pages

- **WHEN** the user activates the primary control at the bottom of the card while page 2 is visible
- **THEN** the card SHALL display page 3, and the primary control SHALL remain in the same position

##### Example: primary control label and effect per page

| Visible page | Primary control label | Effect on activation |
| ------------ | --------------------- | -------------------- |
| 1            | 下一步                 | shows page 2         |
| 2            | 下一步                 | shows page 3         |
| 3            | 下一步                 | shows page 4         |
| 4            | 開始使用               | ends the tutorial    |

#### Scenario: page count and titles are fixed

- **WHEN** the tutorial overlay is presented
- **THEN** the card SHALL contain exactly four pages whose titles, in order, are `兩條學習路線`, `貼上就能出題`, `四選一測驗`, and `答錯會再問一次`

##### Example: tutorial page definitions

| Page | Title          | Body focus                                                                   | Illustration subject                          |
| ---- | -------------- | ---------------------------------------------------------------------------- | --------------------------------------------- |
| 1    | 兩條學習路線     | Vocabulary asks for the Chinese meaning; Grammar asks to fill the blank        | Two side-by-side route cards                  |
| 2    | 貼上就能出題     | A pasted Markdown table is parsed and split into batches of 40 items           | A table transforming into a stack of batches  |
| 3    | 四選一測驗       | Distractors are drawn from the same batch, avoiding guesses among wrong cards  | One question with four options, one marked correct |
| 4    | 答錯會再問一次   | Wrong items are reinserted at the back of the queue until all are answered correctly, and can be drilled again afterwards | A wrong item looping back to the queue tail |

### Requirement: Tutorial Exit Paths And Persistence

The tutorial card SHALL provide a close control in its top-trailing corner that is available on every page, and the final page SHALL additionally provide a primary control that ends the tutorial. Activating either control SHALL dismiss the overlay and SHALL set the persisted seen-tutorial flag to true. The seen-tutorial flag SHALL be persisted in user defaults under the key `hasSeenOnboarding` as a boolean whose absent value resolves to false.

#### Scenario: closing early marks the tutorial as seen

- **WHEN** the user activates the close control while page 2 is visible
- **THEN** the overlay SHALL be dismissed, the persisted seen-tutorial flag SHALL be true, and a subsequent app launch SHALL NOT present the overlay

#### Scenario: completing the tutorial marks it as seen

- **WHEN** the user reaches page 4 and activates the primary end control
- **THEN** the overlay SHALL be dismissed, the persisted seen-tutorial flag SHALL be true, and a subsequent app launch SHALL NOT present the overlay

##### Example: flag state across exit paths

| Starting flag | User action                      | Overlay after action | Flag after action | Overlay on next launch |
| ------------- | -------------------------------- | -------------------- | ----------------- | ---------------------- |
| absent        | activates close control on page 1 | dismissed            | true              | not presented          |
| absent        | activates close control on page 3 | dismissed            | true              | not presented          |
| absent        | activates end control on page 4   | dismissed            | true              | not presented          |
| true          | app launched                      | not presented        | true              | not presented          |

### Requirement: Tutorial Replay Entry Point

The system SHALL provide a persistent control on the Home shell that re-presents the tutorial overlay on demand. Re-presenting the tutorial through this control SHALL always start at page 1 and SHALL leave the persisted seen-tutorial flag unchanged. Dismissing an overlay opened through this control SHALL return the user to the Home shell.

#### Scenario: replaying the tutorial after it was already seen

- **WHEN** the persisted seen-tutorial flag is true and the user activates the Home shell tutorial control
- **THEN** the tutorial overlay SHALL be presented showing page 1, and the persisted seen-tutorial flag SHALL remain true

#### Scenario: dismissing a replayed tutorial does not alter the flag

- **WHEN** the user opens the tutorial through the Home shell control and then activates the close control
- **THEN** the overlay SHALL be dismissed and the persisted seen-tutorial flag SHALL hold the same value it had before the control was activated
