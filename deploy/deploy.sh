#!/usr/bin/env bash
# Blue/Green 무중단 배포 스크립트. EC2에서 root 권한(SSM RunShellScript)으로 실행됨을 전제로 함.
set -euo pipefail

# ---- 상수 정의 -------------------------------------------------------------
UPSTREAM_FILE="/etc/nginx/framey-upstream.inc"
ENV_FILE="/home/ubuntu/framey/.env"
BLUE_NAME="framey-blue"
GREEN_NAME="framey-green"
BLUE_PORT="8080"
GREEN_PORT="8081"
HEALTH_TIMEOUT_ATTEMPTS=60
HEALTH_CHECK_INTERVAL=2
STOP_TIMEOUT_SECONDS=30

if [[ $# -ne 1 ]]; then
	echo "사용법: $0 <image>  (예: ghcr.io/team-framey/framey-server:<sha>)" >&2
	exit 1
fi
IMAGE="$1"

# ---- 1. 현재 활성 포트 확인 → 배포 대상(반대쪽) 결정 -------------------------
CURRENT_LINE=""
if [[ -f "$UPSTREAM_FILE" ]]; then
	CURRENT_LINE=$(cat "$UPSTREAM_FILE")
fi

CURRENT_PORT=""
if [[ "$CURRENT_LINE" =~ :([0-9]+)\; ]]; then
	CURRENT_PORT="${BASH_REMATCH[1]}"
fi

if [[ "$CURRENT_PORT" == "$BLUE_PORT" ]]; then
	# 현재 blue가 활성 상태 → green에 배포
	TARGET_NAME="$GREEN_NAME"
	TARGET_PORT="$GREEN_PORT"
	PREV_NAME="$BLUE_NAME"
elif [[ "$CURRENT_PORT" == "$GREEN_PORT" ]]; then
	# 현재 green이 활성 상태 → blue에 배포
	TARGET_NAME="$BLUE_NAME"
	TARGET_PORT="$BLUE_PORT"
	PREV_NAME="$GREEN_NAME"
else
	# upstream 파일이 없거나 읽을 수 없음 → 첫 배포로 간주하고 blue를 기본 대상으로 사용
	TARGET_NAME="$BLUE_NAME"
	TARGET_PORT="$BLUE_PORT"
	PREV_NAME=""
fi

echo "[deploy] 현재 활성 포트: ${CURRENT_PORT:-없음(첫 배포)} / 배포 대상: ${TARGET_NAME} (127.0.0.1:${TARGET_PORT})"

# ---- 2. 새 이미지 pull -------------------------------------------------------
echo "[deploy] 이미지 pull: ${IMAGE}"
docker pull "$IMAGE"

# ---- 3. 대상 이름의 기존 컨테이너 제거 (2주기 전 컨테이너 잔재 정리) -----------
if docker ps -a --format '{{.Names}}' | grep -qx "$TARGET_NAME"; then
	echo "[deploy] 기존 ${TARGET_NAME} 컨테이너 삭제"
	docker rm -f "$TARGET_NAME"
fi

# ---- 4. 새 컨테이너 기동 -----------------------------------------------------
echo "[deploy] ${TARGET_NAME} 컨테이너 기동 (호스트 127.0.0.1:${TARGET_PORT} -> 컨테이너 8080)"
docker run -d \
	--name "$TARGET_NAME" \
	--restart unless-stopped \
	--memory 768m \
	--log-driver json-file \
	--log-opt max-size=10m \
	--log-opt max-file=3 \
	--env-file "$ENV_FILE" \
	-p "127.0.0.1:${TARGET_PORT}:8080" \
	"$IMAGE"

# ---- 5. 헬스 체크 (준비될 때까지 대기, 실패 시 새 컨테이너만 정리하고 종료) -----
HEALTH_URL="http://127.0.0.1:${TARGET_PORT}/actuator/health/readiness"
BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT

READY="false"
echo "[deploy] 헬스 체크 시작: ${HEALTH_URL}"
for ((attempt = 1; attempt <= HEALTH_TIMEOUT_ATTEMPTS; attempt++)); do
	HTTP_CODE=$(curl -s -o "$BODY_FILE" -w '%{http_code}' "$HEALTH_URL" || echo "000")
	if [[ "$HTTP_CODE" == "200" ]] && grep -q '"status":"UP"' "$BODY_FILE"; then
		READY="true"
		break
	fi
	sleep "$HEALTH_CHECK_INTERVAL"
done

if [[ "$READY" != "true" ]]; then
	echo "[deploy] 헬스 체크 실패 (약 $((HEALTH_TIMEOUT_ATTEMPTS * HEALTH_CHECK_INTERVAL))초 경과). ${TARGET_NAME} 최근 로그 100줄:" >&2
	docker logs --tail 100 "$TARGET_NAME" || true
	echo "[deploy] 실패한 ${TARGET_NAME} 컨테이너 삭제. 기존 활성 컨테이너/Nginx 설정은 그대로 유지." >&2
	docker rm -f "$TARGET_NAME" || true
	exit 1
fi

echo "[deploy] 헬스 체크 통과: ${TARGET_NAME} UP"

# ---- 6. 트래픽 전환: upstream 파일 변경 → nginx -t 검증 → reload -------------
OLD_UPSTREAM_CONTENT="$CURRENT_LINE"

echo "[deploy] upstream을 127.0.0.1:${TARGET_PORT} 로 전환"
echo "server 127.0.0.1:${TARGET_PORT};" >"$UPSTREAM_FILE"

if ! nginx -t; then
	echo "[deploy] nginx 설정 검증 실패 → upstream 파일 원복" >&2
	if [[ -n "$OLD_UPSTREAM_CONTENT" ]]; then
		printf '%s\n' "$OLD_UPSTREAM_CONTENT" >"$UPSTREAM_FILE"
	else
		rm -f "$UPSTREAM_FILE"
	fi
	exit 1
fi

systemctl reload nginx
echo "[deploy] nginx reload 완료. 트래픽이 ${TARGET_NAME}(${TARGET_PORT})로 전환됨"

# ---- 7. 이전 활성 컨테이너 정리 (graceful shutdown) --------------------------
if [[ -n "$PREV_NAME" ]] && docker ps -a --format '{{.Names}}' | grep -qx "$PREV_NAME"; then
	echo "[deploy] 이전 활성 컨테이너 ${PREV_NAME} 정리 (최대 ${STOP_TIMEOUT_SECONDS}초 대기 후 종료)"
	docker stop -t "$STOP_TIMEOUT_SECONDS" "$PREV_NAME"
	docker rm "$PREV_NAME"
fi

# ---- 8. 사용하지 않는 dangling 이미지 정리 -----------------------------------
echo "[deploy] dangling 이미지 정리"
docker image prune -f

echo "[deploy] 배포 완료: ${IMAGE} → ${TARGET_NAME} (127.0.0.1:${TARGET_PORT})"
