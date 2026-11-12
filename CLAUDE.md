# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Summary
**framey** is a photo collage platform API built with Spring Boot 4, PostgreSQL. This API helps users easily capture and express the moments they wish to preserve by allowing them to select photos and a theme, from which it then generates a random collage.

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
- `@SpringBootTest`(contextLoads 등)는 실제 PostgreSQL이 필요 — 로컬 실행 시 `TEST_DB_URL`/`TEST_DB_USER`/`TEST_DB_PASSWORD` env 필수 (`application-test.yaml` 참조, CI는 postgres:16 서비스 컨테이너로 주입). 도메인 단위 테스트(MemberTest 등)는 DB 없이 동작한다.

### Code Style
- `./gradlew check` — Checkstyle 포함 전체 검증 (naver-checkstyle 규칙, violation 0건 요구)
- Checkstyle 리포트: 각 모듈 `build/reports/checkstyle/` 하위에 생성

### Local Infrastructure (Docker)
- `docker compose -f framey-infrastructure/docker/local/docker-compose.local.yaml up -d` — 로컬 인프라 기동 (PostgreSQL 16, host 5433→container 5432)
- `docker compose -f framey-infrastructure/docker/local/docker-compose.test.yaml up -d` — 테스트용 인프라
- `docker compose -f framey-infrastructure/docker/local/docker-compose.local.yaml down` — 종료

### Git Hooks (`.githooks/`)
- `git config core.hooksPath .githooks` — 최초 1회 설정 (팀원 온보딩 필수, 로컬 설정이라 자동 전파 안 됨)
- `pre-commit`: staged `.java` 파일이 속한 모듈만 `checkstyleMain` 실행 (test 코드는 검사 안 함). **bash 4+ 문법 사용 (`mapfile`, `declare -A`) — macOS는 `brew install bash` 필요**
- `pre-push`: `dev`/`main` push 시 `./gradlew clean check` 전체 검증, 기타 브랜치는 `check`
- 우회: `git commit --no-verify` / `git push --no-verify` (긴급 시에만)


## Tech Foundation
- **Language/Runtime**: Java 21 (Gradle toolchain, Temurin 21 in CI)
- **Framework**: Spring Boot 4.1.0  (BOM managed via `io.spring.dependency-management`)
- **Build**: Gradle 멀티 모듈 (`settings.gradle` 참고), Spring Boot plugin은 `framey-application/*` 서비스에만 적용
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
- 새 코드는 해당 서비스 모듈 내부에 작성한다.
- 2개 이상 서비스에서 사용하는 기술적 공통 기능만 공유 모듈 승격을 검토한다.
- 도메인별 Entity, DTO, Event는 공유 모듈로 이동하지 않는다.
- 공유 모듈 변경은 사용자 승인 후 진행한다.

### Domain
- JPA Entity는 프로젝트 BaseEntity를 상속한다.
- Entity 간 불필요한 양방향 연관관계를 생성하지 않는다.
- 다른 서비스의 Entity/Repository를 직접 참조하지 않는다.
- 다른 서비스의 Entity와 JPA 연관관계를 생성하지 않는다.
- 다른 서비스의 식별자는 ID 값으로 참조한다.
- 동일 서비스 내부의 도메인 간 의존성은 해당 서비스의 도메인 경계에 따른다.

### Application
- Controller에 비즈니스 로직을 작성하지 않는다.
- Service는 `@Service` + `@RequiredArgsConstructor` 생성자 주입을 사용한다.
- 조회 전용 작업에는 `@Transactional(readOnly = true)`, 변경 작업에는 쓰기 트랜잭션을 사용한다.
- Controller용 DTO와 Service용 DTO를 분리한다. Entity를 응답으로 반환하지 않는다.

### Inter-service Communication

- 서비스 간 직접적인 코드 의존을 금지한다.
- 다른 서비스의 Entity, Repository, Service를 직접 참조하지 않는다.
- 서비스 간 통신은 정의된 통신 계약을 통해 수행한다.
- 외부 시스템 및 동기 서비스 간 통신은 HTTP를 사용한다.
- 서비스 간 비동기 이벤트 전달은 RabbitMQ를 사용한다.

### Infrastructure Structure

각 서비스는 자신의 Infrastructure 구현을 독립적으로 관리한다.

- `infrastructure/persistence`: Repository Adapter 및 JPA 구현
- `infrastructure/client`: HTTP Client 구현
- `infrastructure/client/dto`: HTTP 통신 전용 DTO
- `infrastructure/event/dto`: RabbitMQ 이벤트 Payload DTO
- `infrastructure/event/publisher`: 이벤트 발행 Adapter
- `infrastructure/event/handler`: 이벤트 수신 Handler

### Event Rules

- 이벤트 DTO는 각 서비스 내부에서 관리한다.
- 도메인별 이벤트 DTO를 framey-common에 추가하지 않는다.
- 이벤트 Payload에 Entity를 직접 포함하지 않는다.
- 이벤트 계약은 발행자와 구독자가 동일하게 해석할 수 있어야 한다.
- 이벤트 스키마 변경 시 기존 구독자와의 호환성을 검토한다.
- 이벤트 Handler에서는 비즈니스 로직을 작성하지 않는다.
- Handler는 이벤트 DTO를 Application DTO로 변환하여 Service에 위임한다.
- 이벤트 발행은 Application Port를 통해 수행한다.
- RabbitMQ 관련 구현은 Infrastructure 계층에 둔다.
- 메시지 중복 전달을 가정하고 멱등성을 고려한다. 실패 시 재시도/DLQ 정책을 정의한다.
- 이벤트 발행은 트랜잭션 커밋 후에 수행한다 — 상세는 `inter-service-communication` skill 참조.

### 현재 상태
- `member-service`에 첫 도메인(`Member` Entity, `NicknameGenerator`, `MemberErrorCode`)이 구현됨 — 해당 패턴을 기존 코드 기준 패턴으로 참조할 수 있다.
- `collage-service`, `archive-service`는 아직 `Application` 클래스만 있는 초기 상태. 기존 패턴이 없으면 `.claude/skills/`의 규칙을 기준 패턴으로 삼는다.

### Error Handling
- 비즈니스 오류는 `BusinessException` + 도메인별 `ErrorCode` enum 사용.
- 도메인 `ErrorCode`는 각 서비스 모듈에 생성한다 (`{도메인 약자}-###` 형식, `framey-common`의 `ErrorCode` 인터페이스 구현). `framey-common`에는 공통 코드(`CommonErrorCode`, `CM-xxx`)만 둔다.
- 컨트롤러에서 `try-catch`로 예외 응답을 만들지 않는다 — `CommonExceptionHandler`(`@RestControllerAdvice`)가 처리한다.
- 응답은 `ApiResponse.fail(errorCode)`로 통일. 성공 응답: 데이터 없으면 `success(SuccessCode)`, 데이터 있으면 `successWithData(SuccessCode, data)` (`SuccessCode` enum: OK, CREATED, UPDATED, DELETED).

## CI/CD (dev 브랜치 기준)

### PR CI (`.github/workflows/pr-ci.yaml`)
- **트리거**: `dev` 브랜치 대상 PR
- **실행**: `./gradlew clean test check --no-daemon` (Checkstyle + 테스트 통과 필수)
- **인프라**: postgres:16-alpine 서비스 컨테이너, `TEST_DB_URL`/`TEST_DB_USER`/`TEST_DB_PASSWORD` env로 테스트 DB 주입

### Dev Deploy (`.github/workflows/dev-deploy.yaml`)
- **트리거**: `dev` 브랜치 push → SSH로 dev EC2 접속 후 `/opt/framey/bin/deploy-dispatch.sh ${{ github.sha }}` 실행 (`command_timeout: 30m`). dispatcher는 repo 밖 고정 경로에 설치 — 서버 최초 설정: `sudo mkdir -p /opt/framey/bin && sudo cp framey-infrastructure/scripts/deploy-dispatch.sh /opt/framey/bin/ && sudo chmod +x /opt/framey/bin/deploy-dispatch.sh`
- **실행 구조**: `deploy-dispatch.sh`(EC2 고정 진입점) — `flock` 획득 → `git fetch` → TARGET이 `origin/dev`의 ancestor인지 검증 → **checkout 전에** 구형 배포 skip(TARGET이 마지막 성공 SHA의 ancestor면 조기 종료) → 서버 tracked 변경 감지 시 거부 → detached HEAD로 TARGET checkout → **해당 커밋의** `deploy-dev.sh` 실행. checkout과 배포 실행이 모두 같은 잠금 범위 안에 있어 동시 배포 충돌 방지. `deploy-dev.sh` 직접 실행 시 HEAD!=TARGET 가드로 차단됨. `FORCE_FULL=true` 환경변수로 수동 full deploy 가능.
- **변경 감지**: `deploy-dev.sh`가 `.git/framey-dev-success`(마지막 성공 SHA)와 대상 SHA의 `git diff`로 누적 변경분 판단. 공유 모듈(`framey-common`, `framey-web`, `framey-monitoring`, 루트 gradle 파일, `framey-infrastructure/docker/dev|scripts|systemd`, workflow 자체) 변경 시 전체 재배포. 베이스 SHA 유실·비선형 이력이면 full deploy. 어떤 규칙에도 매칭되지 않는 변경 파일은 WARNING으로 출력 (새 모듈/루트 설정 누락 감지용).
- **동시 배포 제어**: `concurrency: dev-deploy`(workflow 직렬화) + `deploy-dispatch.sh`의 `flock`(`.git/framey-dev.lock`, 최대 20분 대기). 이미 배포된 SHA로의 구형 배포 요청은 자동 skip.
- **배포**: checkout된 커밋의 `deploy-dev.sh`가 변경 서비스만 `docker compose build` → NGINX 변경 시 새 conf를 임시 컨테이너(`framey-dev` 네트워크, letsencrypt ro 마운트)에서 `nginx -t` 사전 검증 — 실패 시 컨테이너 재생성 전에 배포 중단 → `up -d --no-build --no-deps` → 검증 전부 통과 시에만 성공 SHA 기록 (실패 시 state 미갱신 → 다음 배포가 누적 diff 재계산)
- **검증**: 앱 `/actuator/health` `"UP"` 폴링(최대 200s) → nginx·swagger 컨테이너 미실행 시 ERROR로 즉시 실패(DEV는 상시 실행 환경 전제) → `nginx -t`는 항상, reload는 NGINX 변경 시에만 → `/health` + swagger 응답 → `https://dev-swagger.framey.kr/` 외부 검증 → OpenAPI 검증(nginx/swagger 변경 시 3개 앱 전부, 앱만 변경 시 해당 앱만). 변경 파일이 있으나 배포 대상이 없으면 NOTICE로 파일 목록 출력.
- **부분 배포 실패**: 성공 SHA 미기록은 "다음 배포가 누적 diff를 재시도"하게 만들 뿐, 이미 뜬 컨테이너를 이전 상태로 되돌리지는 않는다(이전 이미지 태그를 보관하지 않으므로 롤백 불가). 실패 시 `docker compose ps -a` + 대상 서비스 로그가 출력되고, 수정 후 다음 배포가 동일 서비스를 다시 빌드·검증한다.
- **DB 스키마**: dev 프로필은 `ddl-auto: validate`이고 마이그레이션 도구(Flyway 등)는 없다 — 새 Entity 추가 시 dev DB에 테이블을 수동 생성하지 않으면 앱 기동 후 healthcheck 실패로 배포가 중단된다. Entity 추가 PR과 함께 dev DB DDL을 준비하거나 스키마 전략을 합의한다.
- **포트**: member 8081 / collage 8082 / archive 8083
- **SSL**: 호스트 certbot + systemd timer로 갱신 (`framey-infrastructure/systemd/framey-certbot-renew.{service,timer}` — 하루 2회, deploy-hook으로 nginx reload). 서버 최초 설정:
  - `sudo cp framey-infrastructure/systemd/framey-certbot-renew.{service,timer} /etc/systemd/system/`
  - `sudo systemctl daemon-reload && sudo systemctl enable --now framey-certbot-renew.timer`
  - 검증: `systemctl list-timers framey-certbot-renew` (활성 확인), `sudo certbot renew --dry-run` (갱신 dry-run)
- **Container Health**: 5개 서비스 모두 compose `healthcheck` 보유 — 앱 3개는 actuator, swagger는 `GET :8080/`, nginx는 `GET /health`(`default.conf` 정의)

### Branch Flow
- feature/* → dev (PR + CI) → dev push 시 자동 dev 배포
- `main`은 배포 워크플로우 없음 — 프로덕션 배포 정책은 별도 정의 필요



## Language Conventions
- **Checkstyle 준수**: Naver checkstyle 규칙이 빌드에 강제됨. 수정 후 `./gradlew check` 로컬 통과 필수.
- **Lombok 사용**: `@Getter`, `@RequiredArgsConstructor` 등은 이미 허용 패턴. 단 `@Data`, `@Setter`는 사용하지 않는 것을 기본으로.
- **DI**: 생성자 주입 (`@RequiredArgsConstructor` + `final` 필드). 필드/세터 주입 금지.
- **주석/문서**: 기존 코드베이스와 동일하게 한국어 주석 허용. Checkstyle Javadoc 규칙 준수.
- **응답 형식**: 컨트롤러 반환은 `ResponseEntity<ApiResponse<T>>`. raw entity를 직접 노출하지 않음.
- **DTO**: Java Record 사용, Request/Response 분리. 인증된 사용자 정보는 `@AuthUser`로 주입.
- **API 문서**: Swagger/springdoc 어노테이션은 별도 문서화 인터페이스에 분리하여 Controller를 깔끔하게 유지한다.
- **예외 메시지**: `ErrorCode` enum의 한국어 메시지 사용 — 문자열 하드코딩 예외 메시지 지양.

## Fix-Feedback Loop
- 빌드/테스트/Checkstyle 실패 시 첫 번째 오류부터 분석한다.
- 실패 원인을 수정한 뒤 관련 검증을 재실행한다.
- 작업 범위 밖의 오류가 발생하면 임의로 다른 모듈을 수정하지 않는다.
- 반복되는 오류는 원인과 해결 방법을 결과 보고에 기록한다.

## Compounding Layer
- 반복적으로 발생하는 문제는 재사용 가능한 규칙으로 정리한다.
- CLAUDE.md 및 Skill 수정이 필요한 경우 변경안을 제안한다.
- 사용자 승인 없이 공통 규칙을 변경하지 않는다.
- 승인된 변경은 PR 리뷰를 통해 반영한다.
- 일회성 작업 맥락은 공통 규칙에 추가하지 않는다.
