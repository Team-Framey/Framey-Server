#!/usr/bin/env bash
# FRAMEY DEV 환경 배포 실행 스크립트

set -Eeuo pipefail

ROOT=/home/ec2-user/Framey-Server
cd "$ROOT"

STATE="$ROOT/.git/framey-dev-success"
TARGET=${1:?Deployment SHA required}

COMPOSE=framey-infrastructure/docker/dev/docker-compose.dev.yaml
BASE_URL=https://dev-swagger.framey.kr

SERVICES=()
BUILD=()
APPS=()
VERIFY_APPS=()
UNMAPPED=()
CHANGED=()

MEMBER=false
COLLAGE=false
ARCHIVE=false
SWAGGER=false
NGINX=false

FULL=false
BASE=''

compose() {
    docker compose -f "$COMPOSE" "$@"
}

running() {
    [[ $(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null) == true ]]
}

failed() {
    local code=$?

    trap - ERR

    echo "=======================================" >&2
    echo "⛔️ framey dev deployment failed" >&2
    echo "Target SHA: $TARGET" >&2
    echo "Exit Code: $code" >&2
    echo "=======================================" >&2

    echo "⚠️ WARNING: Some containers may already be running the new version." >&2
    echo "☑️ Last successful deployment SHA remains unchanged." >&2

    echo "🐳 Docker Compose Status:" >&2
    compose ps -a || true

    if ((${#SERVICES[@]})); then
        echo "🚀 Container Logs:" >&2

        compose logs \
            --no-color \
            --tail=80 \
            "${SERVICES[@]}" || true
    fi

    exit "$code"
}

trap failed ERR

echo "⭐️ 배포 대상 커밋 검증"

[[ "$TARGET" =~ ^[0-9a-f]{40}$ ]] || { #SHA 형식 검증
    echo "Invalid deployment SHA: $TARGET" >&2
    exit 1
}

HEAD=$(git rev-parse HEAD) #현재 EC2 작업 디렉터리의 Git HEAD가 가리키는 커밋 가져옴

if [[ "$HEAD" != "$TARGET" ]]; then
    echo "HEAD ($HEAD) != TARGET ($TARGET)" >&2
    echo "Run deployment through deploy-dispatch.sh" >&2
    exit 1
fi

echo "Deployment target: $TARGET"


if [[ -f "$STATE" ]]; then
    BASE=$(cat "$STATE")
fi

echo "Last successful deployment: ${BASE:-none}"

echo "✅ 전체 서비스 배포 여부 필요 여부 체크"
if [[ "${FORCE_FULL:-false}" == "true" ]]; then

    echo "FORCE_FULL enabled"
    FULL=true

elif [[ -z "$BASE" ]] || \
     ! git cat-file -e "$BASE^{commit}" 2>/dev/null; then

    echo "❓이전 배포 찾을수 없음"
    FULL=true

elif ! git merge-base --is-ancestor "$BASE" "$TARGET"; then

    if git merge-base --is-ancestor "$TARGET" "$BASE"; then
        echo "⏭️ 유효하지않은 배포 건너띔"
        exit 0
    fi

    echo "🎋 배포 이력 갈라짐"
    FULL=true
fi

echo "✅ 변경된 파일 확인"
if [[ "$FULL" == true ]]; then

    echo "Full deployment selected"

    MEMBER=true
    COLLAGE=true
    ARCHIVE=true
    SWAGGER=true
    NGINX=true

else

    while IFS= read -r -d '' file; do

        CHANGED+=("$file")
        matched=true

        case "$file" in

            # Shared modules / build configuration
            framey-common/*|\
            framey-web/*|\
            framey-monitoring/*|\
            build.gradle|\
            settings.gradle|\
            gradle.properties|\
            gradle/*|\
            gradlew|\
            gradlew.bat|\
            .dockerignore)

                MEMBER=true
                COLLAGE=true
                ARCHIVE=true
                ;;

            # Member Service
            framey-application/member-service/*)

                MEMBER=true
                ;;

            # Collage Service
            framey-application/collage-service/*)

                COLLAGE=true
                ;;

            # Archive Service
            framey-application/archive-service/*)

                ARCHIVE=true
                ;;

            # Swagger
            framey-infrastructure/swagger-dev/*)

                SWAGGER=true
                ;;

            # Nginx
            framey-infrastructure/nginx/*)

                NGINX=true
                ;;

            # Deployment infrastructure
            framey-infrastructure/docker/dev/*|\
            framey-infrastructure/scripts/*|\
            framey-infrastructure/systemd/*|\
            .github/workflows/dev-deploy.yaml)

                MEMBER=true
                COLLAGE=true
                ARCHIVE=true
                SWAGGER=true
                NGINX=true
                ;;

            # Files that do not affect deployment
            .github/*|\
            .claude/*|\
            docs/*|\
            CLAUDE.md|\
            README.md|\
            .coderabbit.yaml|\
            .gitattributes|\
            .gitignore|\
            .githooks/*|\
            framey-infrastructure/docker/local/*)

                ;;

            # Unmapped files
            *)

                matched=false
                ;;
        esac

        if [[ "$matched" == false ]]; then
            UNMAPPED+=("$file")
        fi

    done < <(
        git diff \
            --name-only \
            --no-renames \
            -z \
            "$BASE" \
            "$TARGET"
    )

fi

if ((${#UNMAPPED[@]})); then
    echo "⚠️ WARNING: ${#UNMAPPED[@]} changed file(s) matched no deployment rule:" >&2
    printf '  - %s\n' "${UNMAPPED[@]}" >&2
fi

echo "🎯 배포할 서비스 결정"
for app in member collage archive; do

    case "$app" in
        member) selected=$MEMBER ;;
        collage) selected=$COLLAGE ;;
        archive) selected=$ARCHIVE ;;
    esac

    if [[ "$selected" == true ]]; then

        SERVICES+=("$app-dev")
        BUILD+=("$app-dev")
        APPS+=("$app")

    fi

done

if [[ "$SWAGGER" == true ]]; then

    SERVICES+=(swagger-dev)
    BUILD+=(swagger-dev)

fi

if [[ "$NGINX" == true ]]; then

    SERVICES+=(nginx)

fi

if ((${#CHANGED[@]})) && ((${#SERVICES[@]} == 0)); then
    echo "📝 NOTICE: Files changed but no deployable service selected:" >&2
    printf '  - %s\n' "${CHANGED[@]}" >&2
fi

echo "➡️ Docker 이미지 빌드 및 컨테이너 실행 - 실제 배포중 "
if ((${#SERVICES[@]})); then

    echo "======================================="
    echo "FRAMEY DEV DEPLOYMENT"
    echo "BASE: ${BASE:-none}"
    echo "TARGET: $TARGET"
    echo "SERVICES: ${SERVICES[*]}"
    echo "======================================="

    compose config --quiet

    if ((${#BUILD[@]})); then

        echo "Building: ${BUILD[*]}"
        compose build "${BUILD[@]}"
    fi

    # nginx 설정 사전 검증 — 새 conf를 임시 컨테이너에 마운트해 nginx -t 실행.
    # compose up 전에 검증해야 잘못된 설정으로 nginx 컨테이너 재생성 실패를 막을 수 있음.
    # upstream(member-dev 등) DNS 해석을 위해 framey-dev 네트워크에 붙이고,
    # ssl_certificate 경로 검증을 위해 letsencrypt 디렉터리도 ro 마운트.
    if [[ "$NGINX" == true ]]; then

        echo "Validating nginx config (pre-deploy)"

        docker run --rm \
            --network framey-dev \
            -v "$ROOT/framey-infrastructure/nginx/dev/default.conf:/etc/nginx/conf.d/default.conf:ro" \
            -v /etc/letsencrypt:/etc/letsencrypt:ro \
            nginx:1.27-alpine \
            nginx -t

    fi

    echo "Starting: ${SERVICES[*]}"

   FORCE=()
       if [[ "$NGINX" == true ]]; then
           FORCE=(--force-recreate)
       fi
       compose up \
           -d \
           --no-build \
           --no-deps \
           "${FORCE[@]}" \
           "${SERVICES[@]}" compose up \
        -d \
        --no-build \
        --no-deps \
        "${SERVICES[@]}"

    echo "✅ 배포한 Spring Boot 서비스만 대상 검사 "
    for app in "${APPS[@]}"; do

        case "$app" in
            member) port=8081 ;;
            collage) port=8082 ;;
            archive) port=8083 ;;
        esac

        echo "Checking health: $app"

        healthy=false

        for attempt in {1..40}; do

            if docker exec "framey-dev-$app" \
                wget -T 5 -qO- \
                "http://127.0.0.1:$port/actuator/health" \
                | grep -Eq '"status"[[:space:]]*:[[:space:]]*"UP"'; then
                healthy=true
                break
            fi
            sleep 5
        done

        if [[ "$healthy" != true ]]; then
            echo "Health Check failed: $app" >&2
            false
        fi
        echo "Health Check passed: $app"
    done

    echo "✅ Nginx 및 Swagger 검증"

    if ! running framey-dev-nginx; then
        echo "ERROR: Nginx container is not running" >&2
        false
    fi

    if ! running framey-dev-swagger; then
        echo "ERROR: Swagger container is not running" >&2
        false
    fi

    docker exec framey-dev-nginx nginx -t

    echo "Reloading Nginx"
    docker exec framey-dev-nginx nginx -s reload

    docker exec framey-dev-nginx \
        wget -T 5 -qO- \
        http://127.0.0.1/health > /dev/null

    docker exec framey-dev-swagger \
        wget -T 5 -qO- \
        http://127.0.0.1:8080/ > /dev/null

    echo "✅  외부 HTTPS 검증"

    curl \
        --fail \
        --silent \
        --show-error \
        --retry 12 \
        --retry-all-errors \
        --retry-delay 5 \
        --max-time 10 \
        "$BASE_URL/" > /dev/null

    echo "✅ OpenAPi 검증 대상 결정"
    if [[ "$NGINX" == true || "$SWAGGER" == true ]]; then
        VERIFY_APPS=(member collage archive)
    else
        VERIFY_APPS=("${APPS[@]}")
    fi

    for app in "${VERIFY_APPS[@]}"; do

        echo "Checking OpenAPI: $app"

        response=$(mktemp)

        curl \
            --fail \
            --silent \
            --show-error \
            --retry 12 \
            --retry-all-errors \
            --retry-delay 5 \
            --max-time 10 \
            "$BASE_URL/api-docs/$app" > "$response"

        python3 - "$response" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    document = json.load(source)

assert document.get("openapi"), "Missing OpenAPI version"

assert isinstance(document.get("paths"), dict), "Missing OpenAPI paths"

for server in document.get("servers", []):
    assert server["url"] in (
        "/",
        "https://dev-swagger.framey.kr"
    ), server
PY

        rm -f "$response"

        echo "OpenAPI verification passed: $app"

    done

fi

printf '%s\n' "$TARGET" > "$STATE.tmp"

mv "$STATE.tmp" "$STATE"

echo "======================================="
echo "FRAMEY DEV DEPLOYMENT SUCCESSFUL"
echo "SHA: $TARGET"
echo "======================================="
