---
name: compound-knowledge
description: Reuse and record solved problems under claude-review-docs/solutions and promote reusable rules into CLAUDE.md or .claude/skills.
---
 
# Compound Knowledge
 
해결한 문제를 다음 작업에 재사용하기 위한 기록 규칙이다.
 
## 작업 시작 전 (Plan)
- `claude-review-docs/solutions/`에서 같은 모듈·`tags`·`category`의 기록을 먼저 검색해 계획에 반영한다.
- 참고한 기록은 계획(`claude-review-docs/plans/`)에 경로로 남긴다.
## 작업 후 (Compound)
- `claude-review` Issue를 해결하는 PR은 `claude-review-docs/solutions/{category}/{slug}.md`를 작성한다.
- 형식과 필수 frontmatter는 루트 `COMPOUND_ENGINEERING.md`를 따른다.
  - `category`는 문서에 정의된 분류 중 하나이며 폴더 이름과 같아야 한다.
  - `issue`는 PR 본문의 `Closes #N`과 같은 번호여야 한다.
- 재사용 가능한 규칙은 기록에만 두지 않고 다음 중 알맞은 곳으로 승격하고 `applied_to`에 경로를 적는다.
  - 프로젝트 전반 규칙 → `CLAUDE.md`
  - 계층·도메인별 설계 규칙 → 해당 `.claude/skills/*/SKILL.md`
- 일회성 원인(오타, 단순 누락)은 새 규칙으로 승격하지 않는다. 이 경우에도 `applied_to`는 비울 수 없다.
  가장 가까운 SKILL.md(없으면 `CLAUDE.md`)의 기존 규칙을 보강하거나, 해당 기록 경로를 가리키는 한 줄을 추가하고 그 파일을 `applied_to`에 적는다.
  `applied_to`의 파일은 같은 PR에서 실제로 수정되어야 한다.
- 기록은 직접 작성하거나, PR 댓글에 `@claude compound`를 남겨 Claude에게 작성시킬 수 있다. Claude가 만든 기록과 `CLAUDE.md`/SKILL.md 변경은 반드시 개발자가 검토한다.

## 금지
- 코드로 확인되지 않은 추측을 기록하지 않는다.
- 이미 `CLAUDE.md`/SKILL.md에 있는 규칙을 중복 작성하지 않는다. 기존 문장을 보강한다.
