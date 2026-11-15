---
name: api-design
description: Review FRAMEY controllers, services, DTOs, exception handling, and API conventions.
---

# API Design

## Controller
- `@RestController` + `@RequestMapping` 사용
- 반환형은 `ResponseEntity<ApiResponse<T>>` — raw Entity, `Map` 직접 반환 금지
- 비즈니스 로직 작성 금지 — Service로 위임
- `try-catch`로 예외 응답을 만들지 않는다 — `CommonExceptionHandler`가 처리
- 입력 검증은 `@Valid` + DTO 제약 어노테이션 사용
- 인증된 사용자 정보는 `@AuthUser`로 주입
- Swagger 어노테이션(`@Operation`, `@ApiResponse` 등)은 Controller에 직접 붙이지 않고 별도 문서화 인터페이스(예: `{Domain}ApiDocs`)에 선언하고 Controller가 구현하게 하여 Controller를 깔끔하게 유지한다.

### Controller 작성 규칙
- 성공 응답은 `ApiResponse`의 static 메서드를 static import한다. **데이터 없음**: `success(SuccessCode)`, **데이터 있음**: `successWithData(SuccessCode, data)`. `SuccessCode`는 `framey.common.response.SuccessCode` enum (OK, CREATED, UPDATED, DELETED).
- 메서드 파라미터는 `final`로 선언한다.
- PathVariable/RequestBody/AuthUser 순서는 기존 패턴을 따른다.

예시:
```java
@DeleteMapping("/{productId}")
public ResponseEntity<ApiResponse<Void>> deleteProduct(
        @AuthUser final Long memberId,
        @PathVariable final Long productId
) {
    productService.deleteProduct(memberId, productId);
    return ResponseEntity.ok(success(SuccessCode.DELETED));
}

@GetMapping("/{productId}")
public ResponseEntity<ApiResponse<GetMemberProductResponse>> getMemberProduct(
        @AuthUser final Long memberId,
        @PathVariable final Long productId
) {
    GetMemberProductResponse product = productService.findMemberProduct(memberId, productId);
    return ResponseEntity.ok(successWithData(SuccessCode.OK, product));
}
```

## Service
- `@Service` + `@RequiredArgsConstructor` 생성자 주입 (`final` 필드)
- 조회 전용 메서드는 `@Transactional(readOnly = true)`
- 데이터 변경 메서드는 쓰기 가능한 `@Transactional`
- 오류는 `BusinessException` + 도메인 `ErrorCode`로 던진다
- 조회 결과가 없을 때는 `orElseThrow(() -> new BusinessException(XxxErrorCode.NOT_FOUND))` 패턴 사용
- Entity → Result 변환은 `map(XxxResult::from)` 등 Result의 static factory로 수행

예시:
```java
public MemberInfo getProfile(final Long memberId) {
    return memberRepository.findById(memberId)
            .map(MemberInfo::from)
            .orElseThrow(() -> new BusinessException(MemberErrorCode.MEMBER_NOT_FOUND));
}
```

## DTO Mapping
- Controller는 Request DTO를 Application Command로 변환한다.
- Service는 Application Command를 입력받아 비즈니스 로직을 수행한다.
- Service는 Application Result를 반환한다.
- Controller는 Application Result를 Response DTO로 변환한다.
- Service는 Controller 전용 DTO에 의존하지 않는다.
- Entity를 Controller에 전달하거나 API 응답으로 직접 반환하지 않는다.

### Response DTO 작성 규칙
- Java `record` 사용.
- DTO 필드에 `@Schema(description = ..., requiredMode = Schema.RequiredMode.REQUIRED)`를 붙여 Swagger 스키마를 정의한다 (DTO 수준의 `@Schema`는 허용 — Controller의 운영 어노테이션과는 구분).
- Result → Response 변환은 DTO 내부의 static factory `from(final XxxResult result)`으로 수행한다.

예시:
```java
@Schema(description = "사용자 정보 응답")
public record MemberResponse(
        @Schema(description = "사용자 ID", requiredMode = Schema.RequiredMode.REQUIRED) Long memberId,
        @Schema(description = "닉네임", requiredMode = Schema.RequiredMode.REQUIRED) String nickname
) {
    public static MemberResponse from(final MemberResult result) {
        return new MemberResponse(result.memberId(), result.nickname());
    }
}
```

## Exception
- 비즈니스 오류는 `BusinessException` + 도메인별 `ErrorCode` enum으로 던진다.
- 도메인 `ErrorCode`는 각 서비스 모듈의 exception 패키지에 생성한다 (`{도메인 약자}-###`, `framey.common.response.ErrorCode` 구현). 형식 참조: `CommonErrorCode.java`.
- Controller/Service에서 `try-catch`로 응답을 만들지 않는다 — `CommonExceptionHandler`가 처리한다.

## 참조
모든 Java 소스는 `{모듈}/src/main/java/` 하위에 있다. 파일 탐색 전 `find {대상 모듈}/src/main/java -type d` 등으로 실제 패키지 구조를 먼저 확인한다.

- 응답 래퍼: `framey-common/src/main/java/framey/common/response/ApiResponse.java`
- 예외: `framey-common/src/main/java/framey/common/exception/BusinessException.java`
- 공통 에러 코드 형식: `framey-common/src/main/java/framey/common/exception/CommonErrorCode.java`
