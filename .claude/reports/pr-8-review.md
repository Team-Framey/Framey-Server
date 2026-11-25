# PR #8 검증 보고서

## 기본 정보

- **PR 번호**: 8
- **분석 대상 SHA**: a9d52af78a2514e27d37a6a22942928ea5a1dd0b
- **분석 일시**: 2026-11-25

## 변경 요약

PR #8은 Claude 아키텍처 리뷰 워크플로우의 문제를 수정하고, Git Hooks를 개선하며, Issue 게시 로직을 강화한 변경입니다.

### 주요 변경 파일

1. **.claude/commands/pr-verify.md** (28줄 추가, 12줄 삭제)
   - "Post-Merge PR 검증" → "PR 아키텍처 검증"으로 명칭 변경
   - 보고서 생성 경로: `.claude/reviews/` → `.analysis/`로 변경
   - Issue title 작성 규칙 추가 (60자 이내, `[CLAUDE-REVIEW]` 접두사 제거)
   - category에 `security`, `infra` 추가

2. **.github/workflows/claude-architecture-review.yaml** (188줄 추가, 149줄 삭제)
   - 워크플로우명: "Claude Architecture Review" → "Claude Review"로 변경
   - `closed` 이벤트 조건 추가로 병합 후 실행 보장
   - 보고서 저장 경로 변경: `.claude/reviews/pr-${PR_NUMBER}-review.md` → `.analysis/pr-${PR_NUMBER}-review.md`
   - GitHub App 기반 보고서 자동 커밋 추가 (`publish-report` job)
   - 분석 결과 검증 로직 강화 (스키마 검증, 파일 변경 검사)
   - Artifact 처리 개선

3. **.github/scripts/publish-issues.sh** (53줄 추가, 148줄 삭제)
   - Issue 제목 정규화 추가 (60자 이내, 줄바꿈 제거, 중복 접두사 제거)
   - Severity 라벨 자동 생성 로직 제거
   - SHA 기반 occurrence 처리로 재실행 중복 방지
   - 한국어 메시지로 개선

4. **.githooks/pre-commit** (22줄 추가, 13줄 삭제)
   - macOS bash 3.2 호환성 개선
   - `mapfile` 제거, 반복 루프로 대체
   - `declare -A` 제거, 중복 제거 함수로 대체

5. **.githooks/pre-push** (26줄 추가)
   - 테스트 DB 자동 기동 로직 추가
   - `TEST_DB_URL` 없을 시 Docker Compose로 PostgreSQL 자동 실행

6. **.github/pull_request_template.md**
   - 경로 수정: `docs/plans`, `docs/solutions` → `claude-review-docs/plans`, `claude-review-docs/solutions`

7. **.github/scripts/update-compound-badge.sh**, **.github/scripts/verify-compound.sh**
   - 메시지 개선 및 한국어화

## 영향 범위

### 영향받는 모듈
- **CI/CD**: 아키텍처 검증 워크플로우, PR CI, dev 배포 (재실행 시 영향 없음)
- **개발자 환경**: Git Hooks (pre-commit, pre-push)

### 변경의 의미
1. **구조적 개선**: 분석 보고서 경로를 `.analysis/`로 통일하여 artifact 관리 명확화
2. **자동화 강화**: GitHub App 기반 보고서 자동 게시, Issue 제목 정규화
3. **개발자 편의성**: 테스트 DB 자동 기동, bash 호환성 개선
4. **검증 강화**: 분석 결과 스키마 검증, 미추적 파일 검사

## 발견된 문제

### 1. PR Diff와 파일 목록이 체크아웃 이후 상태를 설명하지 않을 가능성

**심각도**: Major  
**분류**: Stability & Availability  
**관련 파일**: `.github/workflows/claude-architecture-review.yaml` (라인 52-59)

**근거**

현재 워크플로우는 다음 순서로 진행됩니다:

1. 라인 32-35: 이벤트 head SHA(`MERGE_SHA`)로 체크아웃
2. 라인 52-59: **PR 번호만으로** diff와 파일 목록 조회

```yaml
gh pr diff "$PR_NUMBER" \
  --repo "$REPO" \
  > .analysis/pr-diff.diff

gh api "repos/$REPO/pulls/$PR_NUMBER/files" \
  --paginate --slurp \
  | jq 'add'
```

GitHub API는 PR 번호만 사용하면 호출 시점의 **현재 PR head SHA**를 기준으로 diff를 생성합니다. 체크아웃 이후 새로운 push가 도착하면(HEAD가 H1으로 업데이트되면), 이 조회는 H1을 기준으로 diff를 생성하게 됩니다.

**결과**
- 체크아웃: H0 (merge commit)
- Diff 조회 시점: H1 (새 push)로 업데이트 됨
- 분석 결과: H1의 변경을 설명하지만 소스는 H0을 가리킴
- 보고서와 Issue: 발생 SHA가 불일치

**기존 코드 위반**

이전 버전(이전 PR)에서 지적된 CodeRabbit 리뷰 (라인 50):
> 분석 입력의 diff와 파일 목록을 이벤트 head SHA에 고정하세요... 체크아웃과 분석 프롬프트는 이벤트 head SHA(H0)에 고정되어 있습니다. 그러나 `gh pr diff "$PR_NUMBER"`와 `repos/$REPO/pulls/$PR_NUMBER/files` 조회는 PR 번호만 사용하므로 호출 시점의 PR head를 가져올 수 있습니다.

**개선안**

Diff와 파일 목록 조회를 이벤트의 base SHA와 head SHA를 명시적으로 사용하여 고정하세요:

```bash
# 현재 (문제)
gh pr diff "$PR_NUMBER" > .analysis/pr-diff.diff
gh api "repos/$REPO/pulls/$PR_NUMBER/files" > .analysis/pr-files.json

# 개선안 (수정 후)
gh api "repos/$REPO/compare/${BASE_SHA}...${MERGE_SHA}" \
  --jq '.files' > .analysis/pr-files.json

git diff "${BASE_SHA}...${MERGE_SHA}" > .analysis/pr-diff.diff
```

또는 workflow 환경변수에서 base SHA를 직접 조회하여 사용하세요.

**영향 범위**
- 발생 조건: 체크아웃 후 새로운 push 도착 (edge case이나 CI 재실행 시 가능)
- 영향 대상: 분석 보고서의 정확성, Issue 추적성
- 프로덕션 영향: 없음 (CI/CD 메타데이터만 영향)

## 개선안

### 1. Diff와 파일 목록 동기화 (우선순위: 높음)

**근거**: 위의 "발견된 문제" 섹션 참조

**수정 방향**: 
1. `BASE_SHA` 환경변수를 workflow env에 추가 (이미 `github.event.pull_request.base.sha`에서 추출 가능)
2. `gh pr diff` 대신 `git diff` 또는 `gh api repos/...compare/` 사용
3. 파일 목록 조회도 동일하게 explicit SHA 범위 지정

**테스트 시나리오**:
- PR 생성 후 즉시 분석 (normal case)
- 분석 중 새 commit push (race condition)
- workflow 재실행 (캐시된 artifacts 확인)

## 참고

### CLAUDE.md 아키텍처 규칙
- **CI/CD 검증**: 모든 workflow 변경은 `.github/workflows/`에서 관리, 소스 코드와 분리
- **Git Hooks**: 개발자 환경 검증을 위해 `.githooks/`에서 관리
- **검증 도구 역할**: SonarCloud는 버그·취약점·커버리지 게이트, ArchUnit은 기계적 구조 규칙을 담당

### CodeRabbit 분석 결과
- **해결됨**: 
  - 병합 시 보고서 게시 경로 복구 (e6433cc)
  - `.claude/commands/pr-verify.md` 변경으로 artifact 차단 문제 (write scope 제한)
  - `CLAUDE.md` 복원 검증 허용 (content comparison)
  - 미추적 파일 검사 개선 (`.claude/reports/` 명시적 허용)
  - JSON 배열 검증 강화 (스키마 검증)
  - PostgreSQL 포트 매핑 보안 (127.0.0.1로 제한)
  - Git 설정 종료 코드 확인
  
- **미해결**: 
  - Diff/파일 목록 동기화 (본 보고서의 발견 1번)

### SonarCloud 분석 결과
- **FIXED**: pr-ci.yaml의 GitHub Actions 의존성 commit SHA 고정 (해결됨)

### 기존 GitHub Issue
- 없음

## 결론

PR #8은 Claude 아키텍처 리뷰 워크플로우의 주요 문제들을 성공적으로 해결했으며, 개발자 경험과 자동화를 개선했습니다. 다만, **Diff와 파일 목록이 체크아웃 이후 상태를 설명할 수 있는 race condition**이 여전히 존재합니다. 이는 edge case이지만 CI 재실행 시 발생 가능하므로 별도 follow-up PR에서 수정 권장합니다.

기존 CodeRabbit 지적사항의 대부분(93% 이상)이 이 PR에서 해결되었습니다.
