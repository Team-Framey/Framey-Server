---
name: inter-service-communication
description: Review HTTP communication, RabbitMQ messaging, service boundaries, and reliability patterns in FRAMEY.
---

# Inter-Service Communication

## 절차

### 1. Purpose
FRAMEY 서비스 간 통신 및 외부 시스템 연동 시 계층 간 의존성을 분리하고, 통신 계약을 일관되게 유지한다.

이 Skill은 다음 작업에 적용한다.
- 서비스 간 HTTP 통신
- 외부 API 연동
- RabbitMQ 이벤트 발행
- RabbitMQ 이벤트 수신
- 이벤트 DTO 생성 및 변경
- 메시지 처리 실패 및 재시도 정책 구현

### 2. Dependency Rules
- 서비스 간 직접적인 Gradle 모듈 의존을 금지한다.
- 다른 서비스의 Entity, Repository, Service를 직접 참조하지 않는다.
- 통신은 Application Port를 통해 수행한다.
- 통신 기술 구현은 Infrastructure 계층에 배치한다.
- Application 및 Domain 계층에서 HTTP Client 또는 RabbitMQ 구현 클래스를 직접 사용하지 않는다.
- 다른 서비스의 통신 DTO를 직접 import하지 않는다.

### 3. HTTP Communication
#### Structure

아래 구조는 `framey-application/{service}/src/main/java/framey/{domain}/` 하위에 배치한다. 작업 전 `find framey-application/{service}/src/main/java -type d`로 실제 패키지 구조를 확인한다.

```text
framey-application/{service}/src/main/java/framey/{domain}/
├── application/
│   └── port/
│       └── MemberClientPort.java
└── infrastructure/
    └── client/
        ├── MemberHttpClientAdapter.java
        └── dto/
            ├── MemberClientRequest.java
            └── MemberClientResponse.java
```

#### Rules
- 외부 시스템 및 동기 서비스 간 통신은 HTTP를 사용한다.
- HTTP Client 구현은 `infrastructure/client`에 배치한다.
- HTTP Request/Response DTO는 `infrastructure/client/dto`에 배치한다.
- HTTP 응답 DTO를 Application 또는 Domain 계층에 직접 노출하지 않는다.
- Client Adapter에서 HTTP 응답 DTO를 Application 모델로 변환한다.
- Application Service는 HTTP Client Adapter가 아닌 Port에 의존한다.
- HTTP Client에는 연결 및 응답 Timeout을 설정한다.
- 외부 API 오류는 Application 계층에서 처리 가능한 예외로 변환한다.
- 재시도는 멱등성이 보장되는 요청에 한해 적용한다.
- 외부 API 응답 DTO를 Domain Entity로 직접 사용하지 않는다.

### 4. RabbitMQ Communication
#### Structure

```text
framey-application/{service}/src/main/java/framey/{domain}/
├── application/
│   └── port/
│       └── CollageEventPort.java
└── infrastructure/
    └── event/
        ├── dto/
        │   └── CollageCreatedEventV1.java
        ├── publisher/
        │   └── CollageEventPublisher.java
        └── handler/
            └── CollageCreatedEventHandler.java
```

필요한 역할만 구현하며, 사용하지 않는 패키지는 미리 생성하지 않는다.

#### Event DTO
- RabbitMQ 이벤트 DTO는 `infrastructure/event/dto`에 배치한다.
- 이벤트 DTO는 Java Record로 작성한다.
- 이벤트 Payload에 JPA Entity를 직접 포함하지 않는다.
- 이벤트 계약의 소유권은 발행 서비스에 있다.
- 발행 서비스는 이벤트 이름, 버전, Payload 스키마를 정의한다.
- 구독 서비스는 해당 계약에 맞는 수신 DTO를 자체적으로 정의한다.
- 이벤트 DTO는 서비스별로 독립적으로 관리하지만 동일한 메시지 계약을 준수한다.
- 이벤트 이름과 버전을 명시한다.
- 이벤트 스키마 변경 시 기존 구독자와의 호환성을 검토한다.

#### Publisher
- 이벤트 발행 구현은 `infrastructure/event/publisher`에 배치한다.
- Application 계층은 이벤트 발행 Port에 의존한다.
- Publisher는 해당 Port를 구현한다.
- Application Service에서 `RabbitTemplate`을 직접 사용하지 않는다.
- 메시지 발행에 필요한 Exchange, Routing Key 등은 Infrastructure 설정에서 관리한다.
- 발행 실패 시 처리 정책을 명확히 한다.

#### Handler
- 이벤트 수신 Handler는 `infrastructure/event/handler`에 배치한다.
- Handler는 메시지 수신 및 DTO 변환을 담당한다.
- 비즈니스 로직은 Application Service에 위임한다.
- Handler에서 Repository를 직접 호출하지 않는다.
- Handler에서 Entity를 직접 생성하거나 수정하지 않는다.
- Handler는 수신한 이벤트 DTO를 Application Command로 변환한다.
- Application Service는 RabbitMQ 메시지 DTO에 직접 의존하지 않는다.

### 5. Event Contract
이벤트 계약은 발행 서비스가 소유한다.
예시:

```json
{
  "eventType": "collage.created",
  "eventVersion": 1,
  "collageId": 100,
  "memberId": 10
}
```

#### Rules
- 이벤트 이름은 명확한 과거형 사실을 표현한다.
- 이벤트 버전을 관리한다.
- 이벤트 Payload는 필요한 데이터만 포함한다.
- 이벤트 계약 변경 시 구독 서비스와의 호환성을 검토한다.
- 호환되지 않는 변경은 새로운 이벤트 버전 도입을 검토한다.
- 도메인별 이벤트 DTO를 `framey-common`에 추가하지 않는다.

### 6. Transaction & Event Publishing

- DB 트랜잭션과 RabbitMQ 메시지 발행은 기본적으로 하나의 원자적 트랜잭션이 아니다.
- 트랜잭션 커밋 전에 이벤트를 발행하면 롤백된 데이터를 다른 서비스가 처리하게 되므로, 커밋 후 발행(예: `@TransactionalEventListener(phase = AFTER_COMMIT)`)을 기본으로 한다.
- DB 변경과 이벤트 발행의 일관성이 필요한 경우 Transactional Outbox 패턴을 검토한다.
- 트랜잭션 커밋 이후 이벤트를 발행하더라도 메시지 전달이 보장되는 것은 아니다.
- 이벤트 발행 실패 시 복구 방법을 검토한다.

### 7. Reliability

#### Idempotency
- RabbitMQ 메시지는 중복 전달될 수 있다고 가정한다.
- 메시지 처리 로직은 멱등성을 고려하여 구현한다.
- 동일 이벤트를 여러 번 수신해도 데이터가 중복 생성되지 않도록 한다.
- 필요한 경우 이벤트 ID를 사용하여 중복 처리를 방지한다.

#### Retry & DLQ
- 메시지 처리 실패 시 재시도 횟수와 간격을 정의한다.
- 반복 실패한 메시지는 DLQ로 이동하도록 구성한다.
- 무한 재시도로 메시지가 반복 처리되지 않도록 한다.
- 재시도 대상 오류와 재시도하지 않을 오류를 구분한다.

#### ACK / NACK
- 메시지 처리 성공 여부에 따라 ACK/NACK 정책을 정의한다.
- 메시지 처리 실패를 단순히 로그만 남기고 정상 처리로 간주하지 않는다.
- ACK/NACK 정책은 Listener Container 설정과 일치해야 한다.

### 8. Modification Rules
- 다른 서비스의 이벤트 DTO를 직접 import하지 않는다.
- 이벤트 스키마 변경 시 발행자와 구독자의 호환성을 검토한다.
- 이벤트 계약 변경이 필요한 경우 사용자에게 먼저 알린다.
- 공유 모듈에 도메인별 이벤트 DTO를 추가하지 않는다.
- 새로운 통신 기술 도입이 필요한 경우 사용자 승인을 받는다.
- 기존 메시지 계약을 변경할 때는 영향받는 서비스를 확인한다.

### 9. Validation
HTTP 통신 구현 시:
- 정상 응답을 검증한다.
- Timeout 상황을 검증한다.
- 외부 API 오류 응답을 검증한다.
- DTO 변환 결과를 검증한다.

**RabbitMQ 구현 시:**
- 이벤트 직렬화 및 역직렬화를 검증한다.
- Publisher의 메시지 발행 동작을 검증한다.
- Handler의 Application Service 위임을 검증한다.
- 중복 메시지 처리 시나리오를 검증한다.
- 재시도 및 DLQ 설정이 존재하는 경우 실패 시나리오를 검증한다.

검증 결과는 실제 실행 여부와 함께 보고한다.
