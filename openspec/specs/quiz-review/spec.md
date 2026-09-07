# quiz-review Specification

## Purpose

TBD - created by archiving change 'flashcard-app-mvp'. Update Purpose after archive.

## Requirements

### Requirement: Preview Screen

The Preview screen SHALL render all cards in the selected batch as a scrollable read-only list, ordered by `importOrder` ascending. Each row SHALL render as `word (partOfSpeech) — translation` when `partOfSpeech` is non-nil, and as `word — translation` when `partOfSpeech` is nil. The screen SHALL provide a control that starts a main quiz on the same batch.

#### Scenario: preview row formatting for word with part of speech

- **WHEN** the preview list renders a card with word `apple`, partOfSpeech `n.`, translation `蘋果`
- **THEN** the row SHALL display the string `apple (n.) — 蘋果`

#### Scenario: preview row formatting for phrase without part of speech

- **WHEN** the preview list renders a card with word `look forward to`, partOfSpeech nil, translation `期待`
- **THEN** the row SHALL display the string `look forward to — 期待`

---
### Requirement: Main Quiz Round Composition

A main quiz round SHALL be initialized with a card set drawn from the selected batch without replacement: up to 50 cards chosen at random when the batch holds 50 or more cards, or all cards in the batch when it holds fewer than 50. The round SHALL end if and only if every card in this initial set has been answered correctly at least once during the round.

#### Scenario: full-size batch draws exactly 50

- **WHEN** the user starts a main quiz on a batch containing 130 cards
- **THEN** the round's initial card set SHALL contain exactly 50 distinct cards drawn from that batch

#### Scenario: undersize batch draws all available

- **WHEN** the user starts a main quiz on a batch containing 12 cards
- **THEN** the round's initial card set SHALL contain exactly those 12 cards

---
### Requirement: Multiple Choice Question Display

Each quiz question SHALL display the current card's `word` (with `partOfSpeech` appended in parentheses when present), four translation choices in a randomly shuffled order, and a separately rendered 「我不會」 control. The four choices SHALL consist of the card's correct translation plus three distractors. The 「我不會」 control SHALL be rendered outside the shuffled choice group.

#### Scenario: question prompt includes part of speech when present

- **WHEN** a question is shown for a card with word `apple` and partOfSpeech `n.`
- **THEN** the question prompt SHALL display the string `apple (n.)`

#### Scenario: question prompt omits part of speech for phrase

- **WHEN** a question is shown for a card with word `look forward to` and partOfSpeech nil
- **THEN** the question prompt SHALL display the string `look forward to`

#### Scenario: 我不會 control is separate from choices

- **WHEN** any quiz question is displayed
- **THEN** the four translation choices SHALL be presented as a shuffled group and the 「我不會」 control SHALL be rendered outside that group

---
### Requirement: Distractor Selection

The three distractors for a question on card `C` within batch `B` SHALL be drawn at random from `B.cards` excluding `C`, and SHALL NOT duplicate `C.translation`. When `B` contains fewer than three eligible distractor translations, the system SHALL draw the remaining distractors at random from cards in other batches of the same deck, again excluding any card whose translation equals `C.translation`.

#### Scenario: distractors drawn from same batch when batch is large enough

- **WHEN** a question is generated for a card in a batch that contains 50 cards with distinct translations
- **THEN** the three distractor translations SHALL all be drawn from the other 49 cards in the same batch and SHALL each differ from the correct translation

#### Scenario: fallback to other batches when batch is too small

- **WHEN** a question is generated for a card in a batch that contains 3 cards with distinct translations
- **THEN** the three distractors SHALL include the 2 other translations from the batch plus 1 additional translation drawn from another batch in the same deck

---
### Requirement: Wrong Answer Re-Queue With Gap

When the user selects a wrong translation or taps 「我不會」 for the current question, the system SHALL increment the card's `wrongCount` by 1, reveal the correct translation to the user, and re-insert the card into the remaining queue at position `min(remaining.count, 3)` from the front. The next question SHALL be drawn from the new head of the queue.

#### Scenario: wrong answer re-queues with three-card gap

- **WHEN** the remaining queue is `[A, B, C, D, E, F]` with `A` as the current question and the user answers `A` incorrectly
- **THEN** the system SHALL increment `A.wrongCount`, reveal `A`'s correct translation, and update the remaining queue to `[B, C, D, A, E, F]` before the next question

#### Scenario: re-queue clamps to remaining queue length

- **WHEN** the remaining queue is `[A, B]` with `A` as the current question and the user answers `A` incorrectly
- **THEN** the system SHALL update the remaining queue to `[B, A]`

##### Example: re-queue positions

| Remaining Queue Before     | Current | Outcome  | Remaining Queue After   |
| -------------------------- | ------- | -------- | ----------------------- |
| [A, B, C, D, E, F]         | A       | wrong    | [B, C, D, A, E, F]      |
| [A, B, C, D]               | A       | wrong    | [B, C, D, A]            |
| [A, B, C]                  | A       | wrong    | [B, C, A]               |
| [A, B]                     | A       | wrong    | [B, A]                  |
| [A]                        | A       | wrong    | [A]                     |

---
### Requirement: Result Screen

When a quiz round ends, the system SHALL display a Result screen showing two numbers scoped to that round: the count of cards that were answered correctly on the first attempt within the round, and the total count of wrong taps within the round (counting each wrong selection and each 「我不會」 tap as one wrong tap). When the wrong-tap count is greater than zero, the Result screen SHALL offer a control to open Mistake Review.

#### Scenario: clean round shows zero wrong and no mistake review

- **WHEN** a round of 50 cards ends and every card was answered correctly on the first attempt
- **THEN** the Result screen SHALL display correct=50, wrong=0, and SHALL NOT render the Mistake Review control

#### Scenario: round with mistakes shows totals and mistake review control

- **WHEN** a round of 50 cards ends and the user made 7 wrong taps in total across 4 distinct cards
- **THEN** the Result screen SHALL display correct=46, wrong=7, and SHALL render the Mistake Review control

---
### Requirement: Mistake Review List

The Mistake Review screen SHALL list every card that received at least one wrong tap during the most recently completed round, ordered by `importOrder` ascending. Each row SHALL use the same formatting as the Preview screen. The screen SHALL provide a control to start a Mistake Quiz built from those cards.

#### Scenario: only the round's mistakes appear

- **WHEN** the most recent round had wrong taps on cards `X`, `Y`, `Z` and no others
- **THEN** Mistake Review for that round SHALL render exactly the rows for `X`, `Y`, `Z` and no other rows

---
### Requirement: Mistake Quiz Loop

A Mistake Quiz round SHALL be composed of every card from the just-completed round's mistake set, and SHALL otherwise follow the same display, distractor, re-queue, and termination rules as a main quiz round. Distractors SHALL continue to be drawn from the owning batch (and fall back to other batches in the deck per the distractor rule). When a Mistake Quiz ends with one or more wrong taps recorded during it, the system SHALL offer a control to launch another Mistake Quiz composed of the new mistake set. The user SHALL be able to leave the loop from any Mistake Quiz Result screen.

#### Scenario: mistake quiz card set equals previous round's mistakes

- **WHEN** the user starts a Mistake Quiz from a round whose mistake set was 4 cards
- **THEN** the Mistake Quiz round's initial card set SHALL contain exactly those 4 cards

#### Scenario: wrong taps in mistake quiz increment wrongCount

- **WHEN** a card with current wrongCount 2 receives a wrong selection or 「我不會」 tap during a Mistake Quiz
- **THEN** the card's wrongCount SHALL become 3

#### Scenario: nested mistake quiz when new mistakes occur

- **WHEN** a Mistake Quiz ends with wrong taps recorded on at least one card during it
- **THEN** the Result screen for that Mistake Quiz SHALL render a control that starts another Mistake Quiz built from those cards

#### Scenario: exit the loop on a clean mistake quiz result

- **WHEN** a Mistake Quiz ends with zero wrong taps during it
- **THEN** the Result screen SHALL NOT render a "next mistake quiz" control and SHALL allow the user to return to Batch Home

---
### Requirement: Correct Answer Reveal On Correct Response

When the user selects the correct translation for the current quiz question, the system SHALL, in addition to displaying the green 「答對」 confirmation, reveal the correct translation on a separate line rendered in a secondary (neutral) color, so the user can see which answer they just selected before advancing. This behavior SHALL apply to both the vocabulary quiz and the grammar quiz. The wrong-answer feedback (red 「正解：xxx」) SHALL remain unchanged.

#### Scenario: correct answer reveals the selected translation

- **WHEN** the user selects the correct translation for the current question
- **THEN** the feedback area SHALL display 「答對」 in green
- **AND** the feedback area SHALL display 「正解：」 followed by the correct translation on a line below, in a secondary (neutral) color

##### Example: correct answer for the word "apple"

- **GIVEN** the current card has word `apple` and correct translation `蘋果`
- **WHEN** the user selects `蘋果`
- **THEN** the feedback area SHALL display `答對` in green on the first line
- **AND** the feedback area SHALL display `正解：蘋果` in a secondary color on the second line

#### Scenario: wrong answer feedback is unchanged

- **WHEN** the user selects a wrong translation or taps 「我不會」
- **THEN** the feedback area SHALL display 「正解：」 followed by the correct translation in red, with no additional 「答對」 line
