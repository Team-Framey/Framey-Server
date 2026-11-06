---
name: persistence
description: Repository Port/Adapter rules for FRAMEY services. Apply when implementing data access.
---

# Persistence

## Repository (Port/Adapter)
- **Port**: 도메인이 필요로 하는 조회/저장 인터페이스 — 도메인 측에 정의
- **Adapter**: Port 구현체 + JPA Repository — 인프라 측에 배치
- Service는 JPA Repository가 아닌 Port에 의존한다
- 다른 서비스의 Port/Adapter에 접근하지 않는다

## 규칙
- 조회 전용 작업은 `@Transactional(readOnly = true)` 경계(Service)에서 관리
- 다른 도메인의 데이터가 필요하면 Repository 직접 참조 대신 통신 인터페이스를 사용한다
