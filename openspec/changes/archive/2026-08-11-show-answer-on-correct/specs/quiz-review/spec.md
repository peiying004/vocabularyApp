## ADDED Requirements

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
