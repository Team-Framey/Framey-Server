---
name: domain-design
description: Entity and domain model rules for FRAMEY services. Apply when creating or modifying entities.
---

# Domain Design

## Entity
- 프로젝트 `BaseEntity`를 상속한다 (없으면 생성 전 사용자에게 확인)
- Entity 간 불필요한 양방향 연관관계를 생성하지 않는다 — 필요한 방향만 단방향
- 다른 도메인(서비스)의 Entity/Repository를 직접 참조하지 않는다 — 다른 도메인 식별자는 ID 값으로만 참조
- `@Setter` / `@Data` 사용 금지 — 상태 변경은 의도 있는 도메인 메서드로 수행
- 생성은 생성자 또는 정적 팩터리 메서드로 제한한다

## 패키지
- 새 Entity는 해당 서비스(`framey.{domain}`)의 domain 패키지에 배치
- 도메인별 `ErrorCode` enum은 서비스 내 exception 패키지에 배치
