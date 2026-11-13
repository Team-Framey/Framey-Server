---
description: Implement a new API in the specified FRAMEY service following project architecture conventions, including tests and validation.
argument-hint: "<service> <api-description>"
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
---

# New API Implementation

$ARGUMENTS에 지정된 API를 구현한다.

## 절차

### 1. 대상 확인
- 대상 서비스(member/collage/archive)를 확인한다.
- 구현할 API의 요구사항을 분석한다.
- 대상 서비스 또는 요구사항이 불명확하면 사용자에게 질문한다.

### 2. 기존 코드 분석
- CLAUDE.md의 아키텍처 규칙을 확인한다.
- 탐색 전 대상 서비스의 실제 패키지 구조를 확인한다: `find framey-application/{service}/src/main/java -type d`. Java 소스 루트는 `{모듈}/src/main/java`, 패키지 루트는 `framey.{domain}`이다.
- 대상 서비스의 기존 패키지 구조와 구현 패턴을 분석한다.
- 재사용 가능한 Entity, DTO, Repository, Service를 확인한다.
- 기존 코드의 중복 구현을 방지한다.
- 다른 서비스 및 공유 모듈을 임의로 수정하지 않는다.

### 3. 관련 Skill 적용
다음 Skill의 규칙을 확인하고 적용한다.

필수:
- `.claude/skills/api-design/SKILL.md`
    - Controller, Service, DTO 구현 규칙

필요한 경우:
- `.claude/skills/domain-design/SKILL.md`
    - Entity 생성 또는 변경이 필요한 경우
- `.claude/skills/persistence/SKILL.md`
    - Repository 구현이 필요한 경우
- `.claude/skills/inter-service-communication/SKILL.md`
    - 외부 또는 도메인 간 통신이 필요한 경우

### 4. 구현 계획 수립
- API의 HTTP Method와 Endpoint를 확인한다.
- Request 및 Response 구조를 정의한다.
- 생성 및 수정이 필요한 파일을 식별한다.
- 기존 코드와의 중복 여부를 검토한다.
- 아키텍처 변경 또는 다른 모듈 수정이 필요한 경우 사용자 승인을 받는다.
- 요구사항이 명확하고 기존 구조 내에서 구현 가능한 경우 바로 진행한다.

### 5. API 구현
1. 기존 코드 재사용 여부 판단
2. 필요한 DTO 정의
3. 필요한 경우 Domain 구현 또는 수정
4. 데이터 접근이 필요한 경우 Repository Port 및 Adapter 구현
5. Service 비즈니스 로직 구현
6. Controller 구현
7. 도메인 ErrorCode 및 BusinessException 적용
8. 기존 프로젝트 규칙에 따른 API 문서화

### 6. 테스트
- Controller 테스트 작성
- Service 테스트 작성
- 필요한 경우 Repository 통합 테스트 작성
- 성공 및 실패 시나리오 검증
- 기존 테스트에 영향을 주는 변경 사항 확인

### 7. 검증
- 대상 서비스의 Gradle check 작업을 실행한다.
- 검증에 실패하면 원인을 분석하고 수정 후 재검증한다.
- 동일한 오류가 반복되거나 작업 범위 밖의 문제가 발견되면 사용자에게 보고한다.
- 테스트를 실행하지 못한 경우 성공했다고 보고하지 않는다.
- 검증을 위해 다른 서비스나 공유 모듈을 임의로 수정하지 않는다.

### 8. 결과 보고
- 생성 및 수정한 파일 목록
- 구현한 API 목록 (HTTP Method, Endpoint)
- 작성한 테스트 및 실행 결과
- 아키텍처 규칙 준수 여부
- 해결되지 않은 문제 및 추가 검토 사항
