## Purpose

Defines what the public-facing documentation of VocTest (README.md and the three files under docs/) must cover and which statements must stay consistent with the shipped code. It treats documentation as a verifiable deliverable so that later feature changes can check whether the docs were updated.

## ADDED Requirements

### Requirement: Documentation Describes The First-Launch Tutorial

README.md, docs/architecture.md and docs/getting-started.md SHALL describe the first-launch tutorial: that it appears on first launch above the Home screen, that it has four pages, that it can be dismissed with the primary button on the last page or the close button, and that it can be reopened from the Home screen toolbar button. docs/architecture.md SHALL list ContentView.swift, VocTestApp.swift, OnboardingOverlayView.swift, OnboardingPage.swift and OnboardingIllustrations.swift in the project structure section. docs/implementation.md SHALL name OnboardingTests and AcceptanceTests in the test coverage section.

#### Scenario: README feature list mentions the tutorial

- **WHEN** a reader scans the feature overview list in README.md
- **THEN** one bullet SHALL describe the first-launch tutorial and the Home screen button that reopens it

#### Scenario: getting-started first-use steps mention the tutorial

- **WHEN** a reader follows the first-use steps in docs/getting-started.md
- **THEN** the first step SHALL state that a four-page tutorial appears on first launch and how to close it

#### Scenario: project structure lists the tutorial files

- **WHEN** a reader looks at the project structure tree in docs/architecture.md
- **THEN** it SHALL contain ContentView.swift, VocTestApp.swift, OnboardingOverlayView.swift, OnboardingPage.swift and OnboardingIllustrations.swift

---

### Requirement: Architecture Diagram Includes The App Shell

docs/architecture.md SHALL contain a mermaid flowchart of the layered architecture with an "App 殼層" subgraph that contains ContentView, OnboardingOverlayView and a UserDefaults node for the hasSeenOnboarding flag. The subgraph SHALL connect to HomeView with one edge. The UserDefaults node SHALL NOT be placed inside the Model layer subgraph. The existing View, pure-logic and Model layer subgraphs SHALL remain.

#### Scenario: shell subgraph is present and separate from the Model layer

- **WHEN** a reader inspects the layered architecture mermaid block in docs/architecture.md
- **THEN** it SHALL contain a subgraph titled "App 殼層" with nodes for ContentView, OnboardingOverlayView and UserDefaults, and the UserDefaults node SHALL NOT appear inside the Model layer subgraph

---

### Requirement: User Flow Diagrams Match View Navigation

docs/architecture.md SHALL contain two mermaid flowcharts of user flows. The main flow SHALL start at app launch, branch on whether the tutorial has been seen, and pass through Home, deck list, batch list, import, batch home, preview list, quiz, result and mistake review list. The result node's return edge SHALL point to the batch home node and SHALL be labelled with the ResultView button text 「回到批次首頁」. The edge from result to the mistake review list SHALL be labelled 「看錯題」 and the edge from the mistake review list back to quiz SHALL be labelled 「開始錯題複習」. The content-management flow SHALL start at the preview list and cover: tapping a row to edit, the add menu with 「手動輸入一筆」 and 「貼上 Markdown」, the full-batch prompt offering 「開新批次」, the paste overflow prompt offering 「開新批次」 and 「放棄此次新增」, and multi-select deletion followed by empty-batch removal and reindexing. Edge labels SHALL use the button or dialog text shown in the corresponding View.

#### Scenario: result node returns to batch home

- **WHEN** a reader follows the main flow diagram from the result node
- **THEN** the return edge SHALL point to the batch home node and SHALL NOT point to the deck list node

#### Scenario: mistake review list appears between result and quiz

- **WHEN** a reader follows the main flow diagram from the result node along the 「看錯題」 edge
- **THEN** the next node SHALL be the mistake review list, and its outgoing edge 「開始錯題複習」 SHALL lead to the quiz node

#### Scenario: content-management flow covers all four add paths

- **WHEN** a reader follows the content-management flow diagram from the add action
- **THEN** it SHALL show the full-batch decision, the manual and paste choices, and the overflow decision with both 「開新批次」 and 「放棄此次新增」 outcomes

##### Example: edge labels map to view text

| Edge label in diagram | View that shows this text |
| --------------------- | ------------------------- |
| 先複習所有單字 | BatchHomeView |
| 直接開始測驗 | BatchHomeView |
| 看錯題 | ResultView |
| 開始錯題複習 | MistakeReviewView |
| 回到批次首頁 | ResultView |
| 手動輸入一筆 / 貼上 Markdown | PreviewView menu |
| 開新批次 / 放棄此次新增 | BatchImportView confirmationDialog |

---

### Requirement: README Contains Condensed Diagrams

README.md SHALL contain a section placed after the documentation index that holds two mermaid flowcharts: a condensed architecture diagram with at most 10 nodes and a condensed main user flow with at most 10 nodes. Each diagram SHALL be followed by a link to the corresponding section of docs/architecture.md.

#### Scenario: condensed diagrams are present and bounded

- **WHEN** a reader opens README.md
- **THEN** it SHALL contain exactly two mermaid blocks, each with at most 10 nodes, and each followed by a link into docs/architecture.md

---

### Requirement: Documentation Statements Match Parser And Batch Behavior

README.md and docs/getting-started.md SHALL NOT state that YAML front matter is skipped automatically. They SHALL state that non-table lines such as front matter and headings are reported as invalid lines and skipped while the remaining table rows are imported. README.md SHALL NOT state that a full batch cannot receive new content or that no new batch is created; it SHALL state that a new batch is created only after the user confirms. README.md SHALL state that distractor sampling from the same batch applies to the vocabulary route and that grammar items use their own distractors. docs/implementation.md SHALL label the give-up action with the button text 「我不會」 in the quiz state diagram, and its parser sample SHALL include the non-empty guard for word and translation in the two-column branch.

#### Scenario: front matter wording is accurate

- **WHEN** a reader searches README.md and docs/getting-started.md for the phrase 「自動略過 YAML front-matter」
- **THEN** no match SHALL be found, and both files SHALL contain wording that front matter lines are listed as invalid lines and skipped

#### Scenario: batch overflow wording is consistent

- **WHEN** a reader searches README.md for the phrase 「不會自動溢位到別批或另開新批」
- **THEN** no match SHALL be found, and the auto-batching bullet SHALL state that a new batch is created only after user confirmation

#### Scenario: quiz state diagram uses the real button text

- **WHEN** a reader inspects the quiz state diagram in docs/implementation.md
- **THEN** the give-up transition SHALL read 「我不會」 and SHALL NOT read 「不知道」

##### Example: wording before and after

| File | Before | After |
| ---- | ------ | ----- |
| README.md 容錯解析 | 自動略過 YAML front-matter | front-matter 等非表格行列為無效行並跳過，其餘照常匯入 |
| README.md 自動切批 | 不會自動溢位到別批或另開新批 | 批次已滿時需經你同意才開新批次 |
| docs/getting-started.md 匯入格式 | YAML front-matter 與標題列會自動略過 | 表頭列與分隔列自動略過；front-matter 等非表格行會列為無效行 |
| docs/implementation.md 狀態機 | 點「不知道」 | 點「我不會」 |
