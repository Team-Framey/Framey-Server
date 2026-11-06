---
description: Add a domain-specific ErrorCode to the target FRAMEY service following project conventions.
argument-hint: "<service> <error-description>"
allowed-tools: Read, Grep, Glob, Edit, Write
---

# Add ErrorCode

$ARGUMENTS에 지정된 도메인의 ErrorCode를 추가한다.

## 절차

### 1. 대상 확인
- 대상 서비스(member/collage/archive)를 확인한다.
- 추가할 오류 상황과 적절한 HttpStatus를 파악한다.
- 불명확하면 사용자에게 질문한다.

### 2. 기존 코드 분석
- 대상 서비스의 기존 `{Domain}ErrorCode` enum이 있는지 확인한다 — 있으면 항목만 추가한다.
- 형식 참조: `framey-common/framey/common/exception/CommonErrorCode.java`
- 동일한 의미의 기존 코드가 있는지 확인해 중복 생성을 방지한다.

### 3. ErrorCode 생성 또는 추가
- 위치: 해당 서비스의 exception 패키지 (`framey.{domain}.exception`)
- `framey.common.response.ErrorCode` 인터페이스 구현
- 코드 형식: `{도메인 약자}-###` (예: `MB-001`, `CL-001`, `AR-001`)
- 한국어 메시지 + `HttpStatus` 지정
- `@Getter` + `@RequiredArgsConstructor` 패턴 사용

### 4. 금지 사항
- `framey-common`의 `CommonErrorCode`에 도메인 전용 코드를 추가하지 않는다 — 공통 모듈 수정은 사용자 승인 필요.
- 문자열 하드코딩 예외 메시지를 코드에 직접 쓰지 않는다.

### 5. 결과 보고
- 생성/수정한 파일
- 추가한 에러 코드 목록 (코드, 메시지, HttpStatus)
