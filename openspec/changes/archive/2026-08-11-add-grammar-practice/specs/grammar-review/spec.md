## ADDED Requirements

### Requirement: Grammar Quiz Round Setup

The system SHALL sample grammar items for a main quiz round by drawing at most one batch worth of items uniformly at random from the target `GrammarBatch`, without replacement. The sample ceiling SHALL default to the shared batch size (40) rather than an independently declared number, so that a round covers a whole batch no matter how the batch size is later adjusted. If the batch holds fewer items than the ceiling, the round SHALL include every item in the batch.

#### Scenario: a full batch yields a round covering every item

- **WHEN** the user starts a main grammar quiz on a batch that holds the maximum number of items
- **THEN** the round SHALL include all of that batch's items exactly once in randomized order

#### Scenario: batch of 8 items yields an eight-item round

- **WHEN** the user starts a main grammar quiz on a batch that holds 8 items
- **THEN** the round SHALL include all 8 items exactly once in randomized order

#### Scenario: an explicit sample ceiling overrides the default

- **WHEN** a caller starts a grammar round on a batch of 25 items with an explicit ceiling of 20
- **THEN** the round SHALL include exactly 20 of that batch's items

### Requirement: Grammar Choice Pool Comes From Item Fields

For each question presented in a grammar quiz, the system SHALL assemble exactly four choice strings composed of the current item's `correct` string and its three `distractors` strings, and SHALL shuffle the four strings before display. The system SHALL NOT sample distractors from other items in the batch or from any other source.

#### Scenario: choices always include exactly the correct answer and all three distractors

- **WHEN** the current item has correct `go` and distractors `[goes, going, gone]`
- **THEN** the choice pool SHALL contain exactly the four strings `go`, `goes`, `going`, `gone` in some order

##### Example: sample choice pools

| Correct  | Distractors                | Choice pool (as a set)                     |
| -------- | -------------------------- | ------------------------------------------ |
| go       | goes, going, gone          | { go, goes, going, gone }                  |
| has      | have, having, had          | { has, have, having, had }                 |
| lost     | loses, losing, losed       | { lost, loses, losing, losed }             |

### Requirement: Grammar Answer Submission Defers Session Advance

When the user selects a choice or taps `我不會` on the current grammar question, the system SHALL record the choice as pending and reveal the answer feedback, but SHALL NOT remove the current item from the round queue or update `wrongCount` yet. The system SHALL advance the round (evaluate correctness against the current item, update `wrongCount` and re-queue as needed, then move to the next item) only when the user taps the `下一題` control that becomes visible in the answered state.

#### Scenario: current question remains visible after answer selection

- **WHEN** the user taps any choice on the current question
- **THEN** the question prompt displayed at the top of the quiz view SHALL remain the same until the user taps `下一題`, and the choice buttons SHALL become disabled while the feedback and `下一題` control are visible

#### Scenario: wrongCount is not incremented until 下一題

- **WHEN** the user selects a wrong choice on an item whose current `wrongCount` is 4, and does not yet tap `下一題`
- **THEN** the item's `wrongCount` SHALL still be 4 in persistent storage

#### Scenario: wrongCount increments on 下一題 after a wrong selection

- **WHEN** the user selects a wrong choice on an item whose current `wrongCount` is 4, then taps `下一題`
- **THEN** the item's `wrongCount` SHALL become 5 in persistent storage before the next question is presented

### Requirement: Grammar Answer Feedback Shows Explanation Whenever Available

The grammar quiz feedback SHALL display a banner immediately after the user selects a choice or taps `我不會`. For a correct selection the banner SHALL show the text `答對`. For a wrong selection or `我不會`, the banner SHALL show the text `正解：{correct}` where `{correct}` is the item's `correct` string. Regardless of correctness, if the current item's `explanation` is non-nil, the system SHALL render the `explanation` text as an additional line beneath the banner. If `explanation` is nil, no explanation line SHALL appear.

#### Scenario: correct answer feedback shows explanation

- **WHEN** the user selects the correct choice on an item with explanation `主詞 I 用動詞原形`
- **THEN** the feedback area SHALL show `答對` and a second line with the text `主詞 I 用動詞原形`

#### Scenario: wrong answer feedback shows correct and explanation

- **WHEN** the user selects a wrong choice on an item with correct `go` and explanation `主詞 I 用動詞原形`
- **THEN** the feedback area SHALL show `正解：go` and a second line with the text `主詞 I 用動詞原形`

#### Scenario: item without explanation shows only the banner

- **WHEN** the user selects any choice on an item whose `explanation` is nil
- **THEN** the feedback area SHALL show only the correctness banner and SHALL NOT render an explanation line

### Requirement: Grammar Wrong Answer Re-Queue With Gap

When the user advances past a wrong answer (via `下一題` after a wrong selection or `我不會`), the system SHALL remove the current item from the head of the round queue and SHALL re-insert it later in the queue at position `min(remaining_count_after_removal, 3)` from the head. The next question presented SHALL never be the item just answered wrongly.

#### Scenario: wrong item is re-queued behind three others when available

- **WHEN** the round queue holds items `[A, B, C, D, E]` at the moment `A` is answered wrongly and the user taps `下一題`
- **THEN** after advance the round queue SHALL be `[B, C, D, A, E]` in that order

#### Scenario: wrong item is re-queued at end when queue is short

- **WHEN** the round queue holds items `[A, B]` at the moment `A` is answered wrongly and the user taps `下一題`
- **THEN** after advance the round queue SHALL be `[B, A]` in that order

### Requirement: Grammar Round Completes Only When Every Sampled Item Is Correct

The system SHALL treat a grammar round as finished only after every item originally sampled into the round has been answered correctly at least once. Multiple wrong answers on the same item SHALL keep the item in the round queue via the re-queue rule until it is answered correctly.

#### Scenario: round finishes after last remaining item is answered correctly

- **WHEN** the round queue is reduced to `[A]` after all other items have been answered correctly, and the user answers `A` correctly and taps `下一題`
- **THEN** the system SHALL treat the round as finished and SHALL present the grammar result screen

### Requirement: Grammar Result Summary And Mistake Access

Upon round completion the system SHALL present a result screen that displays the number of items answered correctly on the first try (`correctCount`) and the total count of wrong answer events including `我不會` taps (`wrongTaps`). If `wrongTaps` is greater than zero, the result screen SHALL provide a control that opens a Mistake Review screen listing every item that received at least one wrong answer event during the round; the list order SHALL follow `importOrder` ascending.

#### Scenario: result screen displays counts

- **WHEN** the user finishes a grammar round in which 12 items were originally sampled, 2 items each received exactly one wrong answer before being answered correctly, and no `我不會` taps occurred
- **THEN** the result screen SHALL display `correctCount` 10 and `wrongTaps` 2

#### Scenario: mistake review control is hidden when the round had zero wrong events

- **WHEN** the user finishes a round with zero wrong answer events
- **THEN** the result screen SHALL NOT render a Mistake Review control

### Requirement: Grammar Mistake Quiz Uses Item-Owned Choices

The grammar Mistake Review screen SHALL provide a control that starts a Mistake Quiz consisting of exactly the items from the round's mistake list. The Mistake Quiz SHALL follow the same rules as a main quiz (four-choice display, `我不會`, deferred submit, wrong re-queue, round completes only on all-correct), and SHALL assemble each question's four choices from the item's own `correct` plus `distractors` fields — not from the mistake subset and not from any other batch source. A `我不會` tap or wrong selection during a Mistake Quiz SHALL still increment the item's `wrongCount`.

#### Scenario: mistake quiz choices come from item fields, not from the mistake subset

- **WHEN** the user starts a Mistake Quiz whose subset contains 2 items and answers the first item
- **THEN** the four choices displayed for that first item SHALL be the item's `correct` and its three `distractors` in some order, and NOT any strings drawn from the other mistake item

#### Scenario: mistake quiz wrong selection still increments wrongCount

- **WHEN** during a Mistake Quiz the user selects a wrong choice on an item whose current `wrongCount` is 6, then taps `下一題`
- **THEN** the item's `wrongCount` SHALL become 7 in persistent storage
