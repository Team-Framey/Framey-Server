#!/usr/bin/env bash
# EC2 고정 배포 실행기 — workflow가 직접 호출하는 유일한 진입점.
# flock 획득 → fetch → TARGET 검증 → checkout → 해당 커밋의 deploy-dev.sh 실행.
# checkout과 스크립트 실행이 모두 같은 잠금 범위 안에 있어 동시 배포 충돌을 방지
set -Eeuo pipefail

ROOT=/home/ec2-user/Framey-Server
STATE="$ROOT/.git/framey-dev-success"

TARGET=${1:?Deployment SHA required}

[[ "$TARGET" =~ ^[0-9a-f]{40}$ ]] || {
    echo "Invalid SHA: $TARGET" >&2
    exit 1
}

cd "$ROOT"

exec 9>"$ROOT/.git/framey-dev.lock"
flock -w 1200 9

git fetch origin \
    +refs/heads/dev:refs/remotes/origin/dev

if [[ $(git rev-parse --is-shallow-repository) == true ]]; then
    git fetch --unshallow origin
fi

git cat-file -e "$TARGET^{commit}"

git merge-base --is-ancestor "$TARGET" origin/dev

if [[ -f "$STATE" ]]; then

    BASE=$(cat "$STATE")

    if git cat-file -e "$BASE^{commit}" 2>/dev/null; then

        if [[ "$TARGET" != "$BASE" ]] && \
           git merge-base --is-ancestor "$TARGET" "$BASE"; then

            echo "Skipping obsolete deployment: $TARGET"
            exit 0

        fi

    fi

fi

if [[ -n $(git status --porcelain --untracked-files=no) ]]; then

    echo "Tracked changes detected. Aborting deployment." >&2
    exit 1

fi

git checkout --detach "$TARGET"

exec "$ROOT/framey-infrastructure/scripts/deploy-dev.sh" "$TARGET"
