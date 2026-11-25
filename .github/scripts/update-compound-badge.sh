#!/usr/bin/env bash
set -euo pipefail

echo "🔑 필수 환경변수 확인"
: "${GH_TOKEN:?GH_TOKEN is required}"
: "${REPO:?REPO is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"
: "${RESULT:?RESULT is required}"

START='<!-- compound-engineering-badge:start -->'
END='<!-- compound-engineering-badge:end -->'
BADGE='![Built with Compound Engineering](https://img.shields.io/badge/Built_with-Compound_Engineering-5B21B6)'
BLOCK=$(printf '%s\n%s\n%s' "$START" "$BADGE" "$END")

# CodeRabbit 이 PR 본문에 넣는 요약 블록의 시작 마커
CR_MARKER='^<!-- This is an auto-generated comment: release notes by coderabbit\.ai -->'
# 'CodeRabbit' 이 들어간 마크다운 제목 (소문자로 바꾼 줄에 적용)
CR_HEADING='^#{1,6}[[:space:]].*coderabbit'

# 최신 본문 조회 (CRLF 제거, 끝 개행은 $(...) 가 제거)
current=$(gh api "repos/$REPO/pulls/$PR_NUMBER" --jq '.body // ""' | tr -d '\r')

# 기존 배지 블록(과 그 앞의 빈 줄) 제거
stripped=$(awk -v s="$START" -v e="$END" '
  $0 == s { skip = 1; pend = 0; next }
  $0 == e { skip = 0; next }
  skip    { next }
  /^[[:space:]]*$/ { pend++; next }
  { while (pend > 0) { print ""; pend-- } print }
' <<< "$current")

# 배지를 넣을 줄 번호를 찾는다. 못 찾으면 빈 문자열(= 맨 아래)
find_anchor() {
  local marker_line prev line n=0

  marker_line=$({ grep -nE "$CR_MARKER" <<< "$stripped" || true; } | head -n 1 | cut -d: -f1)

  if [[ -n "$marker_line" ]]; then
    # 마커 바로 앞(빈 줄 제외)이 CodeRabbit 제목이면 그 제목 위에 넣는다
    prev=$((marker_line - 1))
    while ((prev >= 1)); do
      line=$(sed -n "${prev}p" <<< "$stripped")
      if [[ -z "${line//[[:space:]]/}" ]]; then
        prev=$((prev - 1))
        continue
      fi
      if [[ "${line,,}" =~ $CR_HEADING ]]; then
        echo "$prev"
        return
      fi
      break
    done
    echo "$marker_line"
    return
  fi

  # 마커가 없으면(아직 CodeRabbit 이 실행 전) 템플릿의 CodeRabbit 제목 위에 넣는다
  while IFS= read -r line; do
    n=$((n + 1))
    if [[ "${line,,}" =~ $CR_HEADING ]]; then
      echo "$n"
      return
    fi
  done <<< "$stripped"
}

echo "📋 Compound Engineering 검증 결과: $RESULT"
if [[ "$RESULT" == "pass" ]]; then

  if [[ "$current" == *"$BLOCK"* ]]; then
    echo "⚠️ 기존 Compound Engineering 배지 유지"
    exit 0
  fi

  echo "🔎 배지 삽입 위치 확인"
  anchor=$(find_anchor)

  if [[ -z "$stripped" ]]; then
    updated="$BLOCK"
  elif [[ -n "$anchor" ]]; then
    head_part=""
    if ((anchor > 1)); then
      head_part=$(sed -n "1,$((anchor - 1))p" <<< "$stripped")
    fi
    tail_part=$(sed -n "${anchor},\$p" <<< "$stripped")

    if [[ -n "$head_part" ]]; then
      updated="${head_part}"$'\n\n'"${BLOCK}"$'\n\n'"${tail_part}"
    else
      updated="${BLOCK}"$'\n\n'"${tail_part}"
    fi
  else
    updated="${stripped}"$'\n\n'"${BLOCK}"
  fi

else

  if [[ "$current" != *"$START"* ]]; then
    echo "⚠️제거할 Compound Engineering 배지가 없습니다."
    exit 0
  fi
  updated="$stripped"

fi

# REST 로 본문 갱신 (gh pr edit 의 GraphQL/projects 이슈 회피)
echo "📝 PR 본문 갱신: #${PR_NUMBER}"

body_file=$(mktemp)
trap 'rm -f "$body_file"' EXIT

printf '%s\n' "$updated" > "$body_file"
jq -n --rawfile body "$body_file" '{body: $body}' \
  | gh api --method PATCH "repos/$REPO/pulls/$PR_NUMBER" --input - > /dev/null



echo "========================================"
if [[ "$RESULT" == "pass" ]]; then
  echo "✅ Compound Engineering 배지 적용 완료"
else
  echo "🗑️ Compound Engineering 배지 제거 완료 (검증 결과: $RESULT)"
fi
echo "========================================"
