---
description: Analyze which services will be redeployed on dev push based on changed files and paths-filter rules.
argument-hint: "(optional) <description-of-changes>"
allowed-tools: Read, Grep, Glob, Bash
---

# Deploy Check

현재 변경 사항이 dev 배포 시 어떤 서비스를 재배포하는지 분석한다.

## 절차

### 1. 변경 파일 수집
- `git status` / `git diff --name-only`로 변경된 파일 목록을 확인한다.

### 2. 배포 트리거 판별
`.github/workflows/dev-deploy.yaml`의 paths-filter 규칙으로 판별한다.

- **공유 모듈 변경 시 전 서비스 재배포**:
  - `framey-common/**`, `framey-web/**`, `framey-monitoring/**`
  - `build.gradle`, `settings.gradle`, `gradle/**`
- **서비스별 트리거**:
  - `framey-application/member-service/**` → member-dev (포트 8081)
  - `framey-application/collage-service/**` → collage-dev (포트 8082)
  - `framey-application/archive-service/**` → archive-dev (포트 8083)
- **인프라 트리거**:
  - `framey-infrastructure/swagger-dev/**` → swagger-dev
  - `framey-infrastructure/nginx/**` → nginx

### 3. 결과 보고
- 재배포 대상 서비스 목록
- 공유 모듈 변경 여부 (변경 시 전체 재배포 경고)
- 배포 후 `/actuator/health` 헬스체크 대상 포트
- 주의 사항: `main`은 배포 워크플로우 없음 — `dev` push 시에만 배포됨
