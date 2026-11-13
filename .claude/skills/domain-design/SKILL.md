---
name: domain-design
description: Review FRAMEY entities and domain models for DDD principles, package conventions, and architectural violations.
---

# Domain Design

## Entity
- 프로젝트 `BaseEntity`를 상속한다 (없으면 생성 전 사용자에게 확인)
- Entity 간 불필요한 양방향 연관관계를 생성하지 않는다 — 필요한 방향만 단방향
- 다른 도메인(서비스)의 Entity/Repository를 직접 참조하지 않는다 — 다른 도메인 식별자는 ID 값으로만 참조
- `@Setter` / `@Data` 사용 금지 — 상태 변경은 의도 있는 도메인 메서드로 수행
- 생성은 생성자 또는 정적 팩터리 메서드로 제한한다

## 패키지
- Java 소스 루트: `framey-application/{service}/src/main/java`
- 패키지 루트: `framey.{domain}`
- 모든 서비스(member, collage, archive)는 동일한 패키지 컨벤션을 따른다. 
- Entity는 framey/{domain}/domain/model/ 패키지에 배치한다.
- 새 Entity는 `framey-application/{service}/src/main/java/framey/{domain}/domain/` 하위에 배치 (기존 member-service는 `framey/member/domain/model/`) — 작업 전 `find framey-application/{service}/src/main/java -type d`로 실제 구조를 확인한다
- 도메인별 `ErrorCode` enum은 `framey/{domain}/exception/` 패키지에 배치
