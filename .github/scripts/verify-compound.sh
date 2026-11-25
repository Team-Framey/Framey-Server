#!/usr/bin/env bash

set -euo pipefail
#횐걍뱐수 설정
echo "🔑 필수 환경변수 확인"
: "${GH_TOKEN:?GH_TOKEN is required}"
: "${REPO:?REPO is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"

OUTPUT_FILE="${GITHUB_OUTPUT:-/dev/null}"
SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-/dev/null}"

CLAUDE_LABEL="claude-review"
PLAN_DIR="claude-review-docs/plans"
SOLUTION_DIR="claude-review-docs/solutions"
# 허용되는 category 목록
ALLOWED_CATEGORIES=" architecture domain api persistence event test infrastructure security "

echo "✅ PR 번호 검증"
if [[ ! "$PR_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: Invalid PR_NUMBER: $PR_NUMBER"
  exit 1
fi

OWNER="${REPO%%/*}"
NAME="${REPO#*/}"

reasons=()
CLAUDE_ISSUES=""

finish() {
  local result="$1"

  echo "result=${result}" >> "$OUTPUT_FILE"

  {
    echo "## Compound Engineering 검증 결과: ${result}"
    echo ""
    echo "- PR: #${PR_NUMBER}"
    echo "- 대상 Issue: ${CLAUDE_ISSUES:-없음}"

    if ((${#reasons[@]} > 0)); then
      echo ""
      echo "### 미충족 항목"
      printf -- '- %s\n' "${reasons[@]}"
    fi
  } >> "$SUMMARY_FILE"

  echo "📝 Compound Engineering 검증 결과: ${result}"

  if ((${#reasons[@]} > 0)); then
    printf ' - %s\n' "${reasons[@]}"
  fi

  exit 0
}

echo "🔎 PR이 해결하는 Issue 조회"

# GraphQL 이 실패해도 본문 키워드로 계속 진행
linked_json=$(gh api graphql \
  -f query='
    query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          closingIssuesReferences(first: 50) {
            nodes { number }
          }
        }
      }
    }' \
  -f owner="$OWNER" \
  -f name="$NAME" \
  -F number="$PR_NUMBER" 2>/dev/null || echo '{}')

pr_body=$(gh api "repos/$REPO/pulls/$PR_NUMBER" --jq '.body // ""' | tr -d '\r')

candidates=$(
  {
    jq -r '.data.repository.pullRequest.closingIssuesReferences.nodes[]?.number' \
      <<< "$linked_json" 2>/dev/null || true
    { grep -oiE '\b(close[sd]?|fix(e[sd])?|resolve[sd]?):?[[:space:]]+#[0-9]+' <<< "$pr_body" || true; } \
      | { grep -oE '[0-9]+$' || true; }
  } | sort -un | tr '\n' ' '
)

for n in $candidates; do
  if gh api "repos/$REPO/issues/$n" 2>/dev/null \
    | jq -e --arg label "$CLAUDE_LABEL" \
        '(has("pull_request") | not) and any(.labels[]; .name == $label)' \
        > /dev/null; then
    CLAUDE_ISSUES+="${CLAUDE_ISSUES:+ }$n"
  fi
done

if [[ -z "$CLAUDE_ISSUES" ]]; then
  echo "검증 대상 claude-review 이슈가 없는 PR입니다."
  finish "not-applicable"
fi

echo "✅ claude-review Issue: $CLAUDE_ISSUES"

echo "📁 PR 변경 파일 조회 (삭제 제외)"
changed_file=$(mktemp)

trap 'rm -f "$changed_file"' EXIT

gh api "repos/$REPO/pulls/$PR_NUMBER/files?per_page=100" \
  --paginate \
  --jq '.[] | select(.status != "removed") | .filename' > "$changed_file"

is_changed() {
  grep -Fxq -- "$1" "$changed_file"
}

if ! grep -Eq "^${PLAN_DIR}/.+\.md$" "$changed_file"; then
  reasons+=("Plan 기록 없음: ${PLAN_DIR}/*.md 가 PR에 포함되어야 합니다")
fi

# Compound 기록(docs/solutions) 확인
frontmatter() {
  tr -d '\r' < "$1" | awk '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---"  { exit }
    NR > 1                 { print }
  '
}

# key 가 없어도 파이프라인이 실패하지 않도록 || true (set -e + pipefail 대응)
scalar() {
  local key="$1"

  { grep -E "^${key}:" || true; } | head -n 1 \
    | sed -E "s/^${key}:[[:space:]]*//; s/[[:space:]]+\$//; s/^[\"']//; s/[\"']\$//; s/^#//"
}

# applied_to 항목 중 CLAUDE.md 또는 .claude/skills/**/SKILL.md 만 정확히 추출
# (리스트 형식과 인라인 배열 [a, b] 모두 지원)
applied_paths() {
  awk '
    /^applied_to:/ { f = 1; sub(/^applied_to:/, ""); print; next }
    f && /^[A-Za-z_][A-Za-z0-9_-]*:/ { f = 0 }
    f { print }
  ' \
    | tr ',' '\n' \
    | tr -d '[]' \
    | sed -E "s/^[[:space:]]*-?[[:space:]]*//; s/[[:space:]]+\$//; s/^[\"']//; s/[\"']\$//" \
    | { grep -E '^(CLAUDE\.md|\.claude/skills/[A-Za-z0-9_./-]+/SKILL\.md)$' || true; }
}

solution_ok=false

while IFS= read -r file;
do
  [[ -f "$file" ]] || continue
  base=$(basename "$file")

  [[ "$base" == "README.md" ]] && continue

  fm=$(frontmatter "$file")

  if [[ -z "$fm" ]]; then
    reasons+=("${file}: YAML frontmatter 누락")
    continue
  fi

  doc_ok=true

  for key in title category tags; do
    if [[ -z "$(scalar "$key" <<< "$fm")" ]] \
       && ! grep -Eq "^${key}:[[:space:]]*$" <<< "$fm"; then
      reasons+=("${file}: frontmatter 필수 항목'${key}' 누락")
      doc_ok=false
    fi
  done

  category=$(scalar category <<< "$fm")
  rel="${file#"${SOLUTION_DIR}"/}"
  dir="${rel%%/*}"

  if [[ -n "$category" ]]; then
    if [[ "$ALLOWED_CATEGORIES" != *" $category "* ]]; then
      reasons+=("${file}: category '${category}' 는 허용되지 않음 (${ALLOWED_CATEGORIES})")
      doc_ok=false
    elif [[ "$dir" != "$category" ]]; then
      reasons+=("${file}: 위치(${SOLUTION_DIR}/${dir}/)와 category '${category}' 불일치")
      doc_ok=false
    fi
  fi

  issue=$(scalar issue <<< "$fm")

  if [[ ! "$issue" =~ ^[1-9][0-9]*$ ]] \
     || [[ " $CLAUDE_ISSUES " != *" $issue "* ]]; then
    reasons+=("${file}: frontmatter 'issue'가 해결 대상 claude-review Issue(${CLAUDE_ISSUES})와 일치하지 않음")
    doc_ok=false
  fi

  # 기록이 CLAUDE.md 또는 .claude/skills 와 연결
  # 실제로 이 PR에서 갱신되었는지 확인
  linked=false
  has_applied=false

  while IFS= read -r path; do

    [[ -z "$path" || "$path" == *..* ]] && continue

    has_applied=true

    if [[ -f "$path" ]] && is_changed "$path"; then
      linked=true
    else
      reasons+=("${file}: applied_to '${path}' 가 존재하지 않거나 이 PR에서 갱신되지 않음")
      doc_ok=false
    fi

  done < <(applied_paths <<< "$fm")

  if [[ "$linked" != true && "$has_applied" != true ]]; then
    reasons+=("${file}: applied_to 로 CLAUDE.md 또는 .claude/skills/**/SKILL.md 연결 필요")
    doc_ok=false
  fi

  if [[ "$doc_ok" == true ]]; then
    solution_ok=true
  fi

done < <(grep -E "^${SOLUTION_DIR}/.+\.md$" "$changed_file" || true)

if [[ "$solution_ok" != true ]]; then
  reasons+=("유효한 Compound 기록 없음: ${SOLUTION_DIR}/*.md 가 필요합니다")
fi

if ((${#reasons[@]} > 0)); then
  finish "fail"
fi

finish "pass"
