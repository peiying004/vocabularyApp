## MODIFIED Requirements

### Requirement: Home Shell As App Root

The system SHALL present a Home shell as the root view of the app. The Home shell SHALL display exactly two primary entry buttons: a Vocabulary button labeled `單字` and a Grammar button labeled `文法`, each rendered as a large tap target with an icon, a primary title, and a secondary descriptive subtitle. Tapping the Vocabulary button SHALL push the vocabulary Deck List screen. Tapping the Grammar button SHALL push the grammar Deck List screen. The Home shell SHALL NOT render any deck rows, batch rows, or quiz elements directly. The Home shell SHALL additionally present a single help control in its trailing toolbar position that re-presents the tutorial overlay; this control SHALL NOT be counted among the two primary entry buttons and SHALL NOT push any screen onto the navigation stack.

#### Scenario: home shell renders both entry buttons on first launch

- **WHEN** the user opens the app for the first time
- **THEN** the root screen SHALL display exactly two buttons whose primary titles are `單字` and `文法` respectively, with no deck rows or batch rows visible

#### Scenario: vocabulary button navigates to Deck List

- **WHEN** the user taps the Vocabulary button on the Home shell
- **THEN** the vocabulary Deck List screen SHALL be pushed onto the navigation stack, and the Home shell SHALL remain in the back stack accessible via the system back gesture

#### Scenario: grammar button navigates to Grammar Deck List

- **WHEN** the user taps the Grammar button on the Home shell
- **THEN** the grammar Deck List screen SHALL be pushed onto the navigation stack, and the Home shell SHALL remain in the back stack accessible via the system back gesture

#### Scenario: help control presents the tutorial without navigating

- **WHEN** the user taps the help control in the Home shell trailing toolbar position
- **THEN** the tutorial overlay SHALL be presented above the Home shell, and no screen SHALL be pushed onto the navigation stack

##### Example: home shell button configuration

| Button       | Primary Title | Subtitle                    | Destination            |
| ------------ | ------------- | --------------------------- | ---------------------- |
| Vocabulary   | 單字           | 四選一翻譯測驗                 | vocabulary Deck List   |
| Grammar      | 文法           | 填空四選一                    | grammar Deck List      |

##### Example: home shell control inventory

| Control       | Placement                | Kind             | Effect                                  |
| ------------- | ------------------------ | ---------------- | --------------------------------------- |
| Vocabulary    | main content area        | primary entry    | pushes vocabulary Deck List             |
| Grammar       | main content area        | primary entry    | pushes grammar Deck List                |
| Help          | trailing toolbar         | auxiliary        | presents tutorial overlay, no navigation |
