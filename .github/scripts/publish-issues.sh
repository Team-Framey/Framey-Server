#!/usr/bin/env bash

set -euo pipefail


echo "✅ 필수 환경변수 확인"

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${REPO:?REPO is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"

ISSUES_FILE="${ISSUES_FILE:-.analysis/issues.json}"

LABEL="claude-review"
FIX_LABEL="FIX"

# PR 번호 검증
if [[ ! "$PR_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: Invalid PR_NUMBER: $PR_NUMBER"
  exit 1
fi


echo "✅ JSON 파일 확인"

if [[ ! -f "$ISSUES_FILE" ]]; then
  echo "ERROR: Missing issues.json: $ISSUES_FILE"
  exit 1
fi

if ! jq -e '
  type == "array" and

  all(.[];
    (.title | type == "string" and length > 0) and

    (.severity | IN(
      "critical",
      "major",
      "minor"
    )) and

    (.dedup_key | type == "string" and length > 0) and

    (.dedup_key | test("^[a-zA-Z0-9_./:-]+$")) and

    (.body | type == "string" and length > 0) and

    (.pr == (env.PR_NUMBER | tonumber))
  ) and

  (
    (map(.dedup_key) | unique | length)
    == length
  )
' "$ISSUES_FILE" > /dev/null; then

  echo "ERROR: Invalid issues.json"
  exit 1

fi

count=$(jq 'length' "$ISSUES_FILE")

if (( count == 0 )); then
  echo "No issues to publish"
  exit 0
fi

echo "📋 Total issues to process: $count"

echo "🔖 GitHub 라벨 확인"

# 라벨 목록 조회 실패와 라벨 부재를 구분
labels_file=$(mktemp)
existing_file=$(mktemp)
comments_file=$(mktemp)

trap 'rm -f "$labels_file" "$existing_file" "$comments_file" "${existing_file}.next"' EXIT

if ! gh label list \
  --repo "$REPO" \
  --json name \
  --limit 1000 \
  > "$labels_file"; then

  echo "ERROR: Failed to fetch repository labels"
  exit 1

fi

# ------------------------------------------
# FIX 라벨 확인
# ------------------------------------------

# 기존 프로젝트 라벨이므로 자동 생성하지 않음
if ! jq -e \
  --arg name "$FIX_LABEL" \
  'any(.[]; .name == $name)' \
  "$labels_file" > /dev/null; then

  echo "ERROR: Required label '$FIX_LABEL' does not exist"
  exit 1

fi

# ------------------------------------------
# Claude Review 라벨 생성
# ------------------------------------------

if ! jq -e \
  --arg name "$LABEL" \
  'any(.[]; .name == $name)' \
  "$labels_file" > /dev/null; then

  gh label create "$LABEL" \
    --repo "$REPO" \
    --description "Claude post-merge architecture review" \
    --color "7B61FF"

  echo "Created label: $LABEL"

fi

# ------------------------------------------
# Severity 라벨 생성
# ------------------------------------------

for severity in critical major minor; do

  sev_label="severity-${severity}"

  if jq -e \
    --arg name "$sev_label" \
    'any(.[]; .name == $name)' \
    "$labels_file" > /dev/null; then

    continue

  fi

  case "$severity" in

    critical)
      color="D73A4A"
      ;;

    major)
      color="FB8500"
      ;;

    minor)
      color="F9D65C"
      ;;

  esac

  gh label create "$sev_label" \
    --repo "$REPO" \
    --description "Claude review severity: $severity" \
    --color "$color"

  echo "Created label: $sev_label"

done

echo "🔎 기존 Claude Review Issue 조회"

if ! gh api \
  "repos/$REPO/issues?state=all&labels=$LABEL&per_page=100" \
  --paginate --slurp \
  | jq -e '
      [
        .[][] |
        select(has("pull_request") | not) |
        {
          number,
          state,
          body
        }
      ]
    ' > "$existing_file"; then

  echo "ERROR: Failed to fetch existing issues"
  exit 1

fi

echo "🔥 Issue 게시 시작"

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

  echo ""
  echo "----------------------------------------"
  echo "Processing issue $((i + 1))/$count"
  echo "Title: $title"
  echo "Severity: $severity"
  echo "Dedup key: $dedup_key"
  echo "----------------------------------------"

  # ----------------------------------------
  # 동일 문제 식별 마커
  # ----------------------------------------

  marker="<!-- claude-dedup: ${dedup_key} -->"

  # ----------------------------------------
  # 동일 PR 재실행 식별 마커
  # ----------------------------------------

  occurrence="<!-- claude-occurrence: PR-${PR_NUMBER}:${dedup_key} -->"

  # ========================================
  #  기존 Issue 검색
  # ========================================

  existing=$(jq -r \
    --arg marker "$marker" '
      [
        .[] |
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

    echo "🔎 Existing issue found: #${number}"

    # --------------------------------------
    # Issue 본문에서 occurrence 확인
    # --------------------------------------

    if jq -e \
      --argjson number "$number" \
      --arg occurrence "$occurrence" \
      'any(.[];
        .number == $number and
        ((.body // "") | contains($occurrence))
      )' "$existing_file" > /dev/null; then

      echo "⏭️ Already recorded PR #${PR_NUMBER} in issue #${number} body"

      continue

    fi

    # --------------------------------------
    # Issue 댓글 조회
    # --------------------------------------

    # API 조회 실패 시 중복 댓글이 생성되지 않도록
    # 댓글 조회와 occurrence 검사를 분리

    if ! gh api \
      "repos/$REPO/issues/$number/comments?per_page=100" \
      --paginate --slurp \
      > "$comments_file"; then

      echo "ERROR: Failed to fetch comments for issue #${number}"
      exit 1

    fi

    # --------------------------------------
    # 댓글 JSON 구조 검증
    # --------------------------------------

    if ! jq -e '
      type == "array" and
      all(.[];
        type == "array"
      )
    ' "$comments_file" > /dev/null; then

      echo "ERROR: Invalid comments response for issue #${number}"
      exit 1

    fi

    # --------------------------------------
    # 댓글에서 occurrence 확인
    # --------------------------------------

    if jq -e \
      --arg occurrence "$occurrence" \
      'any(.[][];
        (.body // "") | contains($occurrence)
      )' "$comments_file" > /dev/null; then

      echo "⏭️ Already recorded PR #${PR_NUMBER} in issue #${number} comments"

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

        echo "🔓 Reopened issue #${number}"

      else

        echo "🔒 Issue #${number} remains closed (minor)"

      fi

    fi

    # --------------------------------------
    # 새로운 PR에서 재발견된 경우 댓글 작성
    # --------------------------------------

    gh issue comment "$number" \
      --repo "$REPO" \
      --body "${occurrence}

PR #${PR_NUMBER}에서 병합된 코드에 동일 문제가 확인되었습니다.

Severity: ${severity}"

    echo "💬 Recorded PR #${PR_NUMBER} on issue #${number}"

    continue

  fi

  echo "🚀 신규 Issue 생성"

  sev_label="severity-${severity}"

  new_number=$(gh issue create \
    --repo "$REPO" \
    --title "$title" \
    --label "$FIX_LABEL" \
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

    echo "ERROR: Issue creation failed"
    exit 1

  fi

  echo "✅ Created issue #${new_number}"


  # GitHub Issue 본문에 저장된 마커를
  # 로컬 캐시에도 동일하게 반영

  jq \
    --argjson number "$new_number" \
    --arg marker "$marker" \
    --arg occurrence "$occurrence" \
    '. + [
      {
        number: $number,
        state: "open",
        body: ($marker + "\n" + $occurrence)
      }
    ]' \
    "$existing_file" \
    > "${existing_file}.next"

  mv "${existing_file}.next" "$existing_file"

done

echo ""
echo "========================================"
echo "✅ Issue publication complete"
echo "========================================"
