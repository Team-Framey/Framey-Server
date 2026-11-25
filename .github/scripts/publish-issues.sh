#!/usr/bin/env bash

set -euo pipefail


echo "✅ 필수 환경변수 확인"
: "${GH_TOKEN:?GH_TOKEN is required}"
: "${REPO:?REPO is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"

ISSUES_FILE="${ISSUES_FILE:-.analysis/issues.json}"

LABEL="claude-review"
FIX_LABEL="FIX"

TITLE_PREFIX="[CLAUDE-REVIEW]"
TITLE_MAX=60

if [[ ! "$PR_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: Invalid PR_NUMBER: $PR_NUMBER"
  exit 1
fi


SHA_SHORT=""
SHA_TAG=""

if [[ -n "${ANALYSIS_SHA:-}" ]]; then
  if [[ ! "$ANALYSIS_SHA" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
    echo "ERROR: Invalid ANALYSIS_SHA: $ANALYSIS_SHA"
    exit 1
  fi

  SHA_SHORT="${ANALYSIS_SHA:0:12}"
  SHA_TAG="@${SHA_SHORT}"

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
  echo "게시할 이슈가 없습니다."
  exit 0
fi

echo "📋 게시 대상 이슈 수: ${count}개"
echo "🔖 GitHub 라벨 확인"
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

if ! jq -e \
  --arg name "$FIX_LABEL" \
  'any(.[]; .name == $name)' \
  "$labels_file" > /dev/null; then

  echo "ERROR: Required label '$FIX_LABEL' does not exist"
  exit 1

fi

if ! jq -e \
  --arg name "$LABEL" \
  'any(.[]; .name == $name)' \
  "$labels_file" > /dev/null; then

  gh label create "$LABEL" \
    --repo "$REPO" \
    --description "Claude 기반 PR 머지 후 아키텍처 검토" \
    --color "7B61FF"

  echo "🔖 라벨 생성: $LABEL"

fi

echo "🔎 기존 Claude 리뷰 이슈 조회"
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

echo "🔥 이슈 게시 시작"
for ((i=0; i<count; i++)); do
  echo "🚀 이슈 제목 정규화"
  title=$(jq -r \
    --argjson i "$i" \
    --arg prefix "$TITLE_PREFIX" \
    --argjson max "$TITLE_MAX" '
      .[$i].title
      | gsub("[\\r\\n]+"; " ")
      | gsub("^\\s+|\\s+$"; "")
      | sub("^\\[CLAUDE-REVIEW\\]\\s*"; ""; "i")
      | if length > $max then .[0:($max - 1)] + "…" else . end
      | $prefix + " " + .
    ' "$ISSUES_FILE")

  severity=$(jq -r \
    --argjson i "$i" \
    '.[$i].severity' "$ISSUES_FILE")

  dedup_key=$(jq -r \
    --argjson i "$i" \
    '.[$i].dedup_key' "$ISSUES_FILE")

  body=$(jq -r \
    --argjson i "$i" \
    '.[$i].body' "$ISSUES_FILE")

  echo "----------------------------------------"
  echo "이슈 처리 중: $((i + 1))/$count"
  echo "이슈 제목: $title"
  echo "심각도: $severity"
  echo "중복 방지 키: $dedup_key"
  echo "----------------------------------------"

  marker="<!-- claude-dedup: ${dedup_key} -->"

  occurrence="<!-- claude-occurrence: PR-${PR_NUMBER}${SHA_TAG}:${dedup_key} -->"

  echo "👀 기존 이슈 중복 여부 확인"
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

  if [[ -n "$existing" ]]; then
    number=${existing%%$'\t'*}
    state=${existing#*$'\t'}
    echo "🔎 기존 이슈 발견: #${number}"

    if jq -e \
      --argjson number "$number" \
      --arg occurrence "$occurrence" \
      'any(.[];
        .number == $number and
        ((.body // "") | contains($occurrence))
      )' "$existing_file" > /dev/null; then

      echo "⚠️ #${number} 본문에 동일한 발견 내역이 이미 기록되어 있습니다."
      continue
    fi

    if ! gh api \
      "repos/$REPO/issues/$number/comments?per_page=100" \
      --paginate --slurp \
      > "$comments_file"; then

      echo "ERROR: Failed to fetch comments for issue #${number}"

      exit 1

    fi

    if ! jq -e '
      type == "array" and
      all(.[];
        type == "array"
      )
    ' "$comments_file" > /dev/null; then

      echo "ERROR: Invalid comments response for issue #${number}"
      exit 1

    fi

    if jq -e \
      --arg occurrence "$occurrence" \
      'any(.[][];
        (.body // "") | contains($occurrence)
      )' "$comments_file" > /dev/null; then
      echo "⚠️ #${number} 댓글에 동일한 발견 내역이 이미 기록되어 있습니다."
      continue

    fi

    if [[ "$state" == "closed" ]]; then

      if [[ "$severity" == "critical" ||
            "$severity" == "major" ]]; then

        gh issue reopen "$number" \
          --repo "$REPO"
        echo "🔓기존 이슈 재오픈: #${number}"

      else
        echo "⚠️낮은 심각도(minor)로 인해 이슈 #${number}의 종료 상태를 유지합니다."

      fi

    fi
    gh issue comment "$number" \
      --repo "$REPO" \
      --body "${occurrence}

PR #${PR_NUMBER}${SHA_SHORT:+ (${SHA_SHORT})}에서 동일한 문제가 다시 확인되었습니다.

심각도: ${severity}"

    echo "💬 이슈 #${number}에 PR #${PR_NUMBER} 재발견 내역 등록 완료"

    continue

  fi

  echo "🚀 신규 이슈 생성"

  new_number=$(gh issue create \
    --repo "$REPO" \
    --title "$title" \
    --label "$FIX_LABEL" \
    --label "$LABEL" \
    --body "${marker}
${occurrence}

${body}

---
발견 PR: #${PR_NUMBER}
심각도: ${severity}" \
    | sed -n 's#.*/issues/\([0-9][0-9]*\)$#\1#p')

  if [[ -z "$new_number" ]]; then

    echo "ERROR: Issue creation failed"
    exit 1
  fi

  echo "✅ 신규 이슈 생성 완료: #${new_number}"
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

echo "========================================"
echo "📤 이슈 게시 완료"
echo "========================================"
