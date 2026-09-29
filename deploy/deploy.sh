#!/usr/bin/env bash
# Blue/Green 무중단 배포 스크립트. EC2에서 root 권한(SSM RunShellScript)으로 실행됨을 전제로 함.
#
# 서비스 하나를 배포한다. 서비스가 늘어나도 이 스크립트는 수정하지 않는다 —
# deploy/services.json에 항목을 추가하고 이 스크립트를 서비스 이름과 함께 다시 실행하면 된다.
#
# 사용법: deploy.sh <service> <image>
#   예:   deploy.sh member ghcr.io/team-framey/framey-member:<sha>
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SERVICES_FILE="${SCRIPT_DIR}/services.json"
SITE_CONF_SRC="${SCRIPT_DIR}/nginx/framey.conf"

SITE_CONF_AVAILABLE="/etc/nginx/sites-available/framey-msa.conf"
SITE_CONF_ENABLED="/etc/nginx/sites-enabled/framey-msa.conf"
LOCATIONS_DIR="/etc/nginx/framey/locations"

HEALTH_TIMEOUT_ATTEMPTS=60
HEALTH_CHECK_INTERVAL=2
STOP_TIMEOUT_SECONDS=30

if [[ $# -ne 2 ]]; then
	echo "사용법: $0 <service> <image>  (예: $0 member ghcr.io/team-framey/framey-member:<sha>)" >&2
	exit 1
fi
SERVICE="$1"
IMAGE="$2"

# ---- 0. 사전 준비: jq 설치, 레지스트리 파일 확인 ------------------------------
if ! command -v jq &>/dev/null; then
	echo "[deploy] jq 미설치 → 설치 진행"
	apt-get update -y
	apt-get install -y --no-install-recommends jq
fi

if [[ ! -f "$SERVICES_FILE" ]]; then
	echo "[deploy] services.json을 찾을 수 없음: ${SERVICES_FILE}" >&2
	exit 1
fi

if ! jq -e --arg name "$SERVICE" '.[] | select(.name == $name)' "$SERVICES_FILE" >/dev/null; then
	echo "[deploy] services.json에 '${SERVICE}' 서비스가 없음: ${SERVICES_FILE}" >&2
	exit 1
fi

SERVICE_JSON=$(jq -c --arg name "$SERVICE" '.[] | select(.name == $name)' "$SERVICES_FILE")
BLUE_PORT=$(jq -r '.bluePort' <<<"$SERVICE_JSON")
GREEN_PORT=$(jq -r '.greenPort' <<<"$SERVICE_JSON")
SERVICE_PATH=$(jq -r '.path' <<<"$SERVICE_JSON")
MEMORY=$(jq -r '.memory' <<<"$SERVICE_JSON")

BLUE_NAME="framey-${SERVICE}-blue"
GREEN_NAME="framey-${SERVICE}-green"
UPSTREAM_FILE="/etc/nginx/conf.d/framey-upstream-${SERVICE}.conf"
LOCATION_FILE="${LOCATIONS_DIR}/${SERVICE}.conf"
ENV_FILE="/home/ubuntu/framey/${SERVICE}.env"

echo "[deploy] 서비스: ${SERVICE} / blue=${BLUE_PORT} green=${GREEN_PORT} / path=${SERVICE_PATH} / memory=${MEMORY}"

# ---- 1. 서비스별 환경변수 파일 준비 (없으면 빈 파일 생성) ---------------------
mkdir -p "$(dirname "$ENV_FILE")"
if [[ ! -f "$ENV_FILE" ]]; then
	echo "[deploy] 환경변수 파일이 없어 새로 생성: ${ENV_FILE}"
	touch "$ENV_FILE"
fi

# ---- 2. 공용 사이트 설정(deploy/nginx/framey.conf) 동기화 ---------------------
# 서비스가 늘어나도 이 파일 자체는 바뀌지 않지만, 서버에 아직 없거나 레포 내용과
# 달라졌다면(최초 배포, 혹은 수동 변경 복구) 설치한다.
mkdir -p "$LOCATIONS_DIR"
if [[ ! -f "$SITE_CONF_SRC" ]]; then
	echo "[deploy] 사이트 설정 원본을 찾을 수 없음: ${SITE_CONF_SRC}" >&2
	exit 1
fi

if [[ ! -f "$SITE_CONF_AVAILABLE" ]] || ! cmp -s "$SITE_CONF_SRC" "$SITE_CONF_AVAILABLE"; then
	echo "[deploy] 사이트 설정을 서버와 동기화: ${SITE_CONF_AVAILABLE}"
	install -m 0644 "$SITE_CONF_SRC" "$SITE_CONF_AVAILABLE"
	ln -sf "$SITE_CONF_AVAILABLE" "$SITE_CONF_ENABLED"
	if ! nginx -t; then
		echo "[deploy] 사이트 설정 적용 후 nginx 검증 실패. 컨테이너 배포를 진행하지 않음." >&2
		exit 1
	fi
	systemctl reload nginx
fi

# ---- 3. 현재 활성 포트 확인 → 배포 대상(반대쪽) 결정 -------------------------
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

# ---- 4. 새 이미지 pull -------------------------------------------------------
echo "[deploy] 이미지 pull: ${IMAGE}"
docker pull "$IMAGE"

# ---- 5. 대상 이름의 기존 컨테이너 제거 (2주기 전 컨테이너 잔재 정리) -----------
if docker ps -a --format '{{.Names}}' | grep -qx "$TARGET_NAME"; then
	echo "[deploy] 기존 ${TARGET_NAME} 컨테이너 삭제"
	docker rm -f "$TARGET_NAME"
fi

# ---- 6. 새 컨테이너 기동 -----------------------------------------------------
echo "[deploy] ${TARGET_NAME} 컨테이너 기동 (호스트 127.0.0.1:${TARGET_PORT} -> 컨테이너 8080)"
docker run -d \
	--name "$TARGET_NAME" \
	--restart unless-stopped \
	--memory "$MEMORY" \
	--log-driver json-file \
	--log-opt max-size=10m \
	--log-opt max-file=3 \
	--env-file "$ENV_FILE" \
	-p "127.0.0.1:${TARGET_PORT}:8080" \
	"$IMAGE"

# ---- 7. 헬스 체크 (준비될 때까지 대기, 실패 시 새 컨테이너만 정리하고 종료) -----
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

# ---- 8. location 파일 준비 (서비스 첫 배포 시에만 생성) -----------------------
LOCATION_CREATED="false"
if [[ ! -f "$LOCATION_FILE" ]]; then
	echo "[deploy] location 파일이 없어 새로 생성: ${LOCATION_FILE}"
	cat >"$LOCATION_FILE" <<EOF
location ${SERVICE_PATH} {
	proxy_pass http://framey_${SERVICE};
	proxy_http_version 1.1;
	proxy_set_header Host \$host;
	proxy_set_header X-Real-IP \$remote_addr;
	proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	proxy_set_header X-Forwarded-Proto \$scheme;
}
EOF
	LOCATION_CREATED="true"
fi

# ---- 9. 트래픽 전환: upstream 파일 변경 → nginx -t 검증 → reload -------------
OLD_UPSTREAM_CONTENT="$CURRENT_LINE"

echo "[deploy] upstream(framey_${SERVICE})을 127.0.0.1:${TARGET_PORT} 로 전환"
cat >"$UPSTREAM_FILE" <<EOF
upstream framey_${SERVICE} {
	server 127.0.0.1:${TARGET_PORT};
}
EOF

if ! nginx -t; then
	echo "[deploy] nginx 설정 검증 실패 → upstream/location 파일 원복" >&2
	if [[ -n "$OLD_UPSTREAM_CONTENT" ]]; then
		printf '%s\n' "$OLD_UPSTREAM_CONTENT" >"$UPSTREAM_FILE"
	else
		rm -f "$UPSTREAM_FILE"
	fi
	if [[ "$LOCATION_CREATED" == "true" ]]; then
		rm -f "$LOCATION_FILE"
	fi
	echo "[deploy] 실패한 ${TARGET_NAME} 컨테이너 삭제. 기존 활성 컨테이너/Nginx 설정은 그대로 유지." >&2
	docker rm -f "$TARGET_NAME" || true
	exit 1
fi

systemctl reload nginx
echo "[deploy] nginx reload 완료. ${SERVICE} 트래픽이 ${TARGET_NAME}(${TARGET_PORT})로 전환됨"

# ---- 10. 이전 활성 컨테이너 정리 (graceful shutdown) --------------------------
if [[ -n "$PREV_NAME" ]] && docker ps -a --format '{{.Names}}' | grep -qx "$PREV_NAME"; then
	echo "[deploy] 이전 활성 컨테이너 ${PREV_NAME} 정리 (최대 ${STOP_TIMEOUT_SECONDS}초 대기 후 종료)"
	docker stop -t "$STOP_TIMEOUT_SECONDS" "$PREV_NAME"
	docker rm "$PREV_NAME"
fi

# ---- 11. 사용하지 않는 dangling 이미지 정리 -----------------------------------
echo "[deploy] dangling 이미지 정리"
docker image prune -f

echo "[deploy] 배포 완료: ${SERVICE} ${IMAGE} → ${TARGET_NAME} (127.0.0.1:${TARGET_PORT})"
