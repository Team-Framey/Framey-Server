# COMPOUND_ENGINEERING

Compound Engineering으로 해결한 문제의 기록 규칙이다.
Plan 단계의 기존 기록 조회와 Claude 사후 검증이 `claude-review-docs/solutions/`의 기록을 재사용한다.

## 파일 위치

- Plan 기록: `claude-review-docs/plans/{slug}.md`
- Compound 기록: `claude-review-docs/solutions/{category}/{slug}.md`

`slug`는 영문 kebab-case로 쓴다.

`category`는 다음 중 하나이며, 파일이 놓인 폴더 이름과 같아야 한다:
`architecture`, `domain`, `api`, `persistence`, `event`, `test`, `infrastructure`, `security`

## 필수 frontmatter (`claude-review-docs/solutions/**/*.md`)

파일의 **첫 줄**이 `---`여야 하고, 아래 키를 두 번째 `---` 사이에 적는다.

```yaml
---
title: MemberService 트랜잭션 경계 정리
category: persistence
tags: [transaction, member]
issue: 42
pr: 57
applied_to:
  - CLAUDE.md
  - .claude/skills/persistence/SKILL.md
---
```

- `issue`: PR이 해결하는 `claude-review` Issue 번호 (PR 본문의 `Closes #N`과 일치해야 함)
- `applied_to`: 이 기록에서 승격한 규칙이 반영된 파일. `CLAUDE.md` 또는 `.claude/skills/**/SKILL.md`만 허용하며 **같은 PR에서 실제로 수정**되어야 한다. 적은 파일은 모두 수정되어야 한다.

## 본문 권장 구성
1. 증상 / 문제
2. 원인 (근거 코드)
3. 해결
4. 재발 방지 (승격한 규칙과 위치)

## 작성 방법

- 직접 작성하거나, PR 댓글에 `@claude compound`를 남기면 Claude가 PR diff를 기준으로 작성해 같은 브랜치에 커밋한다.
- Claude가 만든 문서와 `CLAUDE.md`/skill 변경은 반드시 개발자가 검토한다.

## 배지 검증 기준 (`.github/scripts/verify-compound.sh`)
- PR 본문에 `Closes/Fixes/Resolves #N`이 있고, 해당 Issue에 `claude-review` 라벨이 있을 것
- `claude-review-docs/plans/*.md` 포함 (Plan 기록)
- 위 frontmatter를 만족하는 `claude-review-docs/solutions/**/*.md` 포함 (PR에 포함된 solutions 문서는 모두 유효해야 함)
- `applied_to` 파일이 이 PR에서 갱신됨

## 관련 파일
- 작업 전/후 행동 규칙: `.claude/skills/compound-knowledge/SKILL.md`
- CI 흐름 설명: `CLAUDE.md`의 "Compound Engineering" 섹션
- 배지 워크플로우: `.github/workflows/compound-engineering-badge.yaml`
- `@claude compound` 워크플로우: `.github/workflows/claude-compound.yaml`
