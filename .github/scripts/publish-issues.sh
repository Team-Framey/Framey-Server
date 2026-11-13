#!/usr/bin/env bash

set -euo pipefail

# ==========================================
# 필수 환경변수 확인
# ==========================================

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${REPO:?REPO is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"

ISSUES_FILE="${ISSUES_FILE:-.analysis/issues.json}"

LABEL="claude-review"

# ==========================================
# JSON 파일 확인
# ==========================================

if [[ ! -f "$ISSUES_FILE" ]]; then
  echo "Missing issues.json: $ISSUES_FILE"
  exit 1
fi

jq -e '
  type == "array" and

  all(.[];
    (.title | type == "string" and length > 0) and
    (.severity | IN("critical","major","minor")) and
    (.dedup_key | type == "string" and length > 0) and
    (.body | type == "string" and length > 0) and
    (.pr == (env.PR_NUMBER | tonumber))
  ) and

  (
    (map(.dedup_key) | unique | length)
    == length
  )
' "$ISSUES_FILE" > /dev/null

count=$(jq 'length' "$ISSUES_FILE")

if (( count == 0 )); then
  echo "No issues to publish"
  exit 0
fi

# ==========================================
# 기본 라벨 생성
# ==========================================

if ! gh label list \
  --repo "$REPO" \
  --json name \
  --limit 1000 \
  | jq -e --arg name "$LABEL" \
    'any(.[]; .name == $name)' > /dev/null; then

  gh label create "$LABEL" \
    --repo "$REPO" \
    --description "Claude post-merge architecture review" \
    --color "7B61FF"

fi

# ==========================================
# 기존 Issue 전체 조회
# ==========================================

existing_file=$(mktemp)

trap 'rm -f "$existing_file"' EXIT

gh api \
  "repos/$REPO/issues?state=all&labels=$LABEL&per_page=100" \
  --paginate --slurp \
  | jq '[
      .[][] |
      select(has("pull_request") | not) |
      {
        number,
        state,
        body
      }
    ]' \
  > "$existing_file"

# ==========================================
# Issue 후보 순회
# ==========================================

for ((i=0; i<count; i++)); do

  title=$(jq -r \
    --argjson i "$i" \
    '.[$i].title' "$ISSUES_FILE")

  severity=$(jq -r \
    --argjson i "$i" \
    '.[$i].severity' "$ISSUES_FILE")

  dedup_key=$(jq -r \
    --argjson i "$i" \
    '.[$i].dedup_key' "$ISSUES_FILE")

  body=$(jq -r \
    --argjson i "$i" \
    '.[$i].body' "$ISSUES_FILE")

  # ----------------------------------------
  # dedup_key 검증
  # ----------------------------------------

  if [[ ! "$dedup_key" =~ ^[a-zA-Z0-9_./:-]+$ ]]; then
    echo "Invalid dedup_key: $dedup_key"
    exit 1
  fi

  # 동일 문제 식별
  marker="<!-- claude-dedup: ${dedup_key} -->"

  # 동일 PR 재실행 식별
  occurrence="<!-- claude-occurrence: PR-${PR_NUMBER}:${dedup_key} -->"

  # ----------------------------------------
  # 기존 Issue 검색
  # ----------------------------------------

  existing=$(jq -r \
    --arg marker "$marker" '
      [.[] |
        select(
          (.body // "") | contains($marker)
        )
      ] |
      first // empty |
      [.number, .state] |
      @tsv
    ' "$existing_file")

  # ========================================
  # 기존 Issue가 있는 경우
  # ========================================

  if [[ -n "$existing" ]]; then

    number=${existing%%$'\t'*}
    state=${existing#*$'\t'}

    # 동일 PR의 재발견 댓글이 있는지 확인
    if gh api \
      "repos/$REPO/issues/$number/comments?per_page=100" \
      --paginate --slurp \
      | jq -e \
        --arg occurrence "$occurrence" \
        'any(.[][];
          (.body // "") | contains($occurrence)
        )' > /dev/null; then

      echo "Already recorded PR #${PR_NUMBER} on issue #${number}"

      continue
    fi

    # --------------------------------------
    # 닫힌 Issue 재오픈
    # --------------------------------------

    if [[ "$state" == "closed" ]]; then

      if [[ "$severity" == "critical" ||
            "$severity" == "major" ]]; then

        gh issue reopen "$number" \
          --repo "$REPO"

        echo "Reopened issue #${number}"

      else

        echo "Issue #${number} remains closed"

      fi

    fi

    # --------------------------------------
    # 재발견 댓글 작성
    # --------------------------------------

    gh issue comment "$number" \
      --repo "$REPO" \
      --body "${occurrence}

PR #${PR_NUMBER}에서 병합된 코드에 동일 문제가 확인되었습니다.

Severity: ${severity}"

    continue

  fi

  # ========================================
  # 신규 Issue 생성
  # ========================================

  sev_label="severity-${severity}"

  if ! gh label list \
    --repo "$REPO" \
    --json name \
    --limit 1000 \
    | jq -e \
      --arg name "$sev_label" \
      'any(.[]; .name == $name)' > /dev/null; then

    gh label create "$sev_label" \
      --repo "$REPO" \
      --color "FFAA00"

  fi

  echo "Creating issue: $title"

  new_number=$(gh issue create \
    --repo "$REPO" \
    --title "$title" \
    --label "$LABEL" \
    --label "$sev_label" \
    --body "${marker}
${occurrence}

${body}

---
발견 PR: #${PR_NUMBER}
Severity: ${severity}" \
    | sed -n 's#.*/issues/\([0-9][0-9]*\)$#\1#p')

  if [[ -z "$new_number" ]]; then
    echo "Issue creation failed"
    exit 1
  fi

  echo "Created issue #${new_number}"

  # ----------------------------------------
  # 현재 실행 중 생성한 Issue도 목록에 반영
  # ----------------------------------------

  jq \
    --argjson number "$new_number" \
    --arg marker "$marker" \
    '. + [
      {
        number: $number,
        state: "open",
        body: $marker
      }
    ]' \
    "$existing_file" \
    > "${existing_file}.next"

  mv "${existing_file}.next" "$existing_file"

done

echo "Issue publication complete"
