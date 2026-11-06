# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Summary
**framey** is a photo collage platform API built with Spring Boot 3, PostgreSQL. This API helps users easily capture and express the moments they wish to preserve by allowing them to select photos and a theme, from which it then generates a random collage.

## Essential Commands

### Build
- `./gradlew build` — 전체 모듈 빌드 (컴파일 + Checkstyle + 테스트)
- `./gradlew :framey-application:member-service:build` — 특정 서비스만 빌드

### Run
- `./gradlew :framey-application:member-service:bootRun` — member-service 실행
- `./gradlew :framey-application:collage-service:bootRun` — collage-service 실행
- `./gradlew :framey-application:archive-service:bootRun` — archive-service 실행

### Test
- `./gradlew test` — 전체 테스트 (JUnit 5)
- `./gradlew :framey-application:member-service:test` — 특정 모듈 테스트
- `./gradlew :framey-application:member-service:test --tests "ClassName"` — 단일 테스트 클래스

### Code Style
- `./gradlew check` — Checkstyle 포함 전체 검증 (naver-checkstyle 규칙, violation 0건 요구)
- Checkstyle 리포트: 각 모듈 `build/reports/checkstyle/` 하위에 생성

### Local Infrastructure (Docker)
- `docker compose -f framey-infrastructure/docker/local/docker-compose.local.yaml up -d` — 로컬 인프라 기동 (DB, Redis 등)
- `docker compose -f framey-infrastructure/docker/local/docker-compose.test.yaml up -d` — 테스트용 인프라
- `docker compose -f framey-infrastructure/docker/local/docker-compose.local.yaml down` — 종료


## Tech Foundation
- **Language/Runtime**: Java 21 (Gradle toolchain, Temurin 21 in CI)
- **Framework**: Spring Boot (BOM managed via `io.spring.dependency-management`)
- **Build**: Gradle 멀티 모듈 ([settings.gradle](cci:7://file:///Users/yanghwayeong/Desktop/framey-server/server/settings.gradle:0:0-0:0) 참고), Spring Boot plugin은 `framey-application/*` 서비스에만 적용
- **DB**: PostgreSQL (각 서비스 `runtimeOnly 'org.postgresql:postgresql'`)
- **API Docs**: springdoc-openapi 3.1.1 (`framey-web`, Swagger UI)
- **Validation**: spring-boot-starter-validation
- **Code Quality**: Checkstyle 10.26.1, Naver checkstyle 규칙 (`framey-common/checkstyle/naver-checkstyle-rules.xml`), `maxWarnings=0`, `maxErrors=0` — 위반 시 빌드 실패
- **Test**: JUnit 5 (`useJUnitPlatform`), spring-boot-starter-test, `spring-boot-starter-webmvc-test` (MockMvc용)
- **Monitoring**: `framey-monitoring` 모듈 + Actuator (`/actuator/health`로 health check)

## Architecture

### Module Structure
- `framey-common` — 공통 응답(`ApiResponse`), 예외(`BusinessException`, `ErrorCode`), Checkstyle 규칙. 의존성 없는 최하위 모듈.
- `framey-web` — `framey-common`을 `api`로 의존. Web/Validation/Swagger/`CommonExceptionHandler` 공통 웹 계층.
- `framey-monitoring` — 모니터링·Actuator 공통 설정.
- `framey-application/{member,collage,archive}-service` — 각각 독립 실행 가능한 Spring Boot 앱. `framey-common`, `framey-web`을 `api`, `framey-monitoring`을 `implementation`으로 의존.
- `framey-infrastructure` — docker-compose(local/dev/test), nginx, swagger-dev 등 배포 인프라. Gradle 모듈 아님.

### Dependency Rules
- 서비스 간 직접 의존 금지 — 서비스는 공유 모듈(`framey-common`, `framey-web`, `framey-monitoring`)만 의존.
- `framey-common`/`framey-web`/`framey-monitoring` 변경은 3개 서비스 모두 재배포 트리거 (CI paths-filter의 `shared` 필터).
- 새 코드는 서비스 모듈 내부에 두고, 2개 이상 서비스에서 필요할 때만 공유 모듈로 승격.

### Error Handling
- 비즈니스 오류는 `BusinessException` + 도메인별 `ErrorCode` enum 사용.
- 공통 오류는 `CommonErrorCode` (`CM-xxx` 형식, 한국어 메시지 + HttpStatus).
- 응답은 `ApiResponse.fail(errorCode)`로 통일. 컨트롤러에서 `try-catch` 하지 않음 — `CommonExceptionHandler`(`@RestControllerAdvice`)가 처리.

## CI/CD (dev 브랜치 기준)

### PR CI ([.github/workflows/pr-ci.yaml](cci:7://file:///Users/yanghwayeong/Desktop/framey-server/server/.github/workflows/pr-ci.yaml:0:0-0:0))
- **트리거**: `dev` 브랜치 대상 PR
- **실행**: `./gradlew clean test check --no-daemon` (Checkstyle + 테스트 통과 필수)
- **인프라**: postgres:16-alpine 서비스 컨테이너, `TEST_DB_URL`/`TEST_DB_USER`/`TEST_DB_PASSWORD` env로 테스트 DB 주입

### Dev Deploy ([.github/workflows/dev-deploy.yaml](cci:7://file:///Users/yanghwayeong/Desktop/framey-server/server/.github/workflows/dev-deploy.yaml:0:0-0:0))
- **트리거**: `dev` 브랜치 push
- **변경 감지**: `dorny/paths-filter`로 서비스별 배포 여부 판단. 공유 모듈(`framey-common`, `framey-web`, `framey-monitoring`, 루트 gradle 파일) 변경 시 전 서비스 재배포.
- **배포**: SSH로 dev EC2 접속 → `git pull` → `docker compose -f framey-infrastructure/docker/dev/docker-compose.dev.yaml up -d --build --no-deps {변경된 서비스}`
- **Health Check**: `/actuator/health`가 `"status":"UP"` 될 때까지 최대 100초 폴링. 실패 시 `docker logs --tail=50` 출력 후 workflow 실패.
- **포트**: member 8081 / collage 8082 / archive 8083

### Branch Flow
- feature/* → dev (PR + CI) → dev push 시 자동 dev 배포
- `main`은 배포 워크플로우 없음 — 프로덕션 배포 정책은 별도 정의 필요


## Language Conventions
- **Checkstyle 준수**: Naver checkstyle 규칙이 빌드에 강제됨. 수정 후 `./gradlew check` 로컬 통과 필수.
- **Lombok 사용**: `@Getter`, `@RequiredArgsConstructor` 등은 이미 허용 패턴. 단 `@Data`, `@Setter`는 사용하지 않는 것을 기본으로.
- **DI**: 생성자 주입 (`@RequiredArgsConstructor` + `final` 필드). 필드/세터 주입 금지.
- **주석/문서**: 기존 코드베이스와 동일하게 한국어 주석 허용. Checkstyle Javadoc 규칙 준수.
- **응답 형식**: 컨트롤러 반환은 `ApiResponse`로 감싸기. raw entity를 직접 노출하지 않음.
- **예외 메시지**: `ErrorCode` enum의 한국어 메시지 사용 — 문자열 하드코딩 예외 메시지 지양.

## Fix-Feedback Loop
- 빌드/테스트/Checkstyle 실패 시: 실패 원인을 **첫 번째 에러부터** 분석하고, 증상이 아닌 근본 원인을 수정한다. 실패한 작업만 재실행해 확인한다.
- CI(`./gradlew clean test check`)와 로컬 결과가 다르면 환경 차이(DB env, 테스트용 docker-compose)를 먼저 확인한다.
- 같은 유형의 실패가 반복되면 원인을 이 파일의 규칙 섹션에 추가해 재발을 방지한다.

## Compounding Layer
- 이 문서는 누적 업데이트 대상이다. 리뷰에서 반복 지적된 패턴, CI에서 자주 깨지는 규칙, 새로 도입된 기술(예: Redis, RabbitMQ)은 발견 즉시 해당 섹션에 추가한다.
- 일회성 지시(특정 PR에만 해당하는 맥락)는 여기 적지 않는다 — 반복 적용 가능한 규칙만 추가한다.
- 규칙 추가 시 **근거(실패한 CI 로그, 리뷰 코멘트, 아키텍처 결정)**를 함께 기록한다.
