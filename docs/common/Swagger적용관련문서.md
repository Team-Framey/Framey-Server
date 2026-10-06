## Swagger 적용 가이드

### 서비스 모듈 의존성 추가

Swagger를 사용할 각 서비스 모듈의 `build.gradle`에 `common-web` 의존성을 추가합니다.

```gradle
dependencies {
    implementation project(':common:common-web')
}
```

`common-web`에는 다음 의존성이 포함되어 있습니다.

```gradle
api 'org.springframework.boot:spring-boot-starter-web'
implementation 'org.springframework.boot:spring-boot-starter-validation'
api 'org.springdoc:springdoc-openapi-starter-webmvc-ui:3.1.1'
```

서비스 모듈에서는 별도로 springdoc 의존성을 추가하지 않아도 됩니다.

### 서비스 모듈 기본 설정

각 서비스 모듈의 `application.yml`에 다음 설정을 추가합니다.

```yaml
springdoc:
  api-docs:
    enabled: ${SWAGGER_ENABLED:false}
    path: /v3/api-docs
  swagger-ui:
    enabled: ${SWAGGER_ENABLED:false}
    path: /swagger
    operations-sorter: method
    tags-sorter: alpha
    display-request-duration: true
```

환경변수가 없으면 Swagger는 기본적으로 비활성화됩니다.

### 환경별 설정

#### 로컬 환경

`application-local.yml`:

```yaml
springdoc:
  api-docs:
    enabled: true
  swagger-ui:
    enabled: true
```

실행 프로필:

```text
SPRING_PROFILES_ACTIVE=local
```

로컬 환경에서는 각 실행 서비스에 할당된 포트를 통해 Swagger UI에 접근합니다.

Docker를 사용하는 경우 컨테이너 내부 포트가 아닌 **호스트에 매핑된 포트**를 사용합니다.

예를 들어 Docker 설정이 다음과 같은 경우:

```yaml
ports:
  - "8003:8080"
```

Swagger 접속 주소:

```text
http://localhost:8003/swagger
```

OpenAPI JSON:

```text
http://localhost:8003/v3/api-docs
```

서비스마다 Docker 호스트 포트가 다르다면 각 서비스의 포트에 맞게 접근합니다.

예:

```text
http://localhost:{서비스 포트}/swagger
http://localhost:{서비스 포트}/v3/api-docs
```

`common-web`과 같이 독립적으로 실행되지 않는 공통 라이브러리 모듈에는 별도의 Swagger 주소가 생성되지 않습니다.

#### 개발 환경

> dev 브랜치에 올라갈 경우 적용되는 설정입니다.

`application-dev.yml`:

```yaml
springdoc:
  api-docs:
    enabled: true
  swagger-ui:
    enabled: true
```

배포 환경변수:

```text
SPRING_PROFILES_ACTIVE=dev
SWAGGER_ENABLED=true
```

개발 환경에서도 각 실행 서비스마다 Swagger 문서가 생성됩니다.

외부 Swagger 접속 주소는 Nginx 라우팅 정책에 따라 결정합니다.

예:

```text
https://dev-api.framey.kr/{서비스}/swagger
```

실제 접속 경로는 개발 서버의 Nginx 라우팅 설정 확정 후 적용합니다.

#### 운영 환경

> main 브랜치에 올라갈 경우 적용되는 설정입니다.

`application-prod.yml`:

```yaml
springdoc:
  api-docs:
    enabled: false
  swagger-ui:
    enabled: false
```

배포 환경변수:

```text
SPRING_PROFILES_ACTIVE=prod
SWAGGER_ENABLED=false
```

운영 환경에서는 Swagger UI와 OpenAPI 문서를 비활성화합니다.

### 각 서비스 Controller 작성

Swagger에서 Controller를 그룹화하려면 `@Tag`를 사용합니다.

```java
package framey.user.presentation;

import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(
        name = "User",
        description = "사용자 API"
)
@RestController
@RequestMapping("/api/v1/users")
public class UserController {
}
```

---

### API 명세 작성 방법

각 API에는 `@Operation`을 사용합니다.

```java
@Operation(
        summary = "사용자 조회",
        description = "사용자 ID를 이용하여 사용자 정보를 조회합니다."
)
@GetMapping("/{userId}")
public ApiResponse<UserResponse> getUser(
        @PathVariable final Long userId
) {
    return ApiResponse.success(
            SuccessCode.OK,
            userService.getUser(userId)
    );
}
```

---

### 요청 파라미터 문서화

#### Path Variable

```java
@GetMapping("/{userId}")
public ApiResponse<UserResponse> getUser(
        @Parameter(
                description = "사용자 ID",
                example = "1",
                required = true
        )
        @PathVariable final Long userId
) {
    return ApiResponse.success(
            SuccessCode.OK,
            userService.getUser(userId)
    );
}
```

#### Query Parameter

```java
@GetMapping
public ApiResponse<List<UserResponse>> getUsers(
        @Parameter(
                description = "페이지 번호",
                example = "0"
        )
        @RequestParam(defaultValue = "0") final int page
) {
    return ApiResponse.success(
            SuccessCode.OK,
            userService.getUsers(page)
    );
}
```

---

#### Request와 Response DTO 문서화

DTO 클래스에는 필요한 경우 `@Schema`를 사용합니다.

Springdoc이 기본적인 타입과 필드 정보는 자동으로 문서화하므로, 설명이나 예시가 필요한 DTO 또는 필드에 `@Schema`를 사용하는 것을 권장합니다.

```java
package framey.user.presentation.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

@Schema(description = "회원가입 요청")
public record SignUpRequest(

        @Schema(
                description = "이메일",
                example = "user@framey.kr"
        )
        @NotBlank
        @Email
        String email,

        @Schema(
                description = "비밀번호",
                example = "password123!"
        )
        @NotBlank
        String password
) {
}
```

응답 DTO:

```java
package framey.user.presentation.response;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "사용자 응답")
public record UserResponse(

        @Schema(
                description = "사용자 ID",
                example = "1"
        )
        Long id,

        @Schema(
                description = "이메일",
                example = "user@framey.kr"
        )
        String email
) {
}
```

---

### 인증이 필요한 API인 경우

> 기본적으로 모든 API에 JWT Bearer 인증을 적용합니다. Swagger UI 오른쪽 상단의 `Authorize` 버튼을 선택하고 Access Token을 입력합니다.

```text
eyJhbGciOiJIUzI1NiJ9...
```

`Bearer ` 접두사는 Swagger UI가 자동으로 추가하므로 토큰 값만 입력합니다.

요청에는 다음 헤더가 포함됩니다.

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...
```

---

### 인증이 필요하지 않는 API 처리

로그인, 회원가입, 토큰 재발급처럼 인증이 필요하지 않은 API에는 `@PublicApi`를 추가합니다.

#### 메서드 단위

```java
@PublicApi
@Operation(
        summary = "로그인",
        description = "이메일과 비밀번호로 로그인합니다."
)
@PostMapping("/login")
public ApiResponse<LoginResponse> login(
        @Valid @RequestBody final LoginRequest request
) {
    return ApiResponse.success(
            SuccessCode.OK,
            authService.login(request)
    );
}
```

#### Controller 단위

Controller의 모든 API가 공개 API라면 클래스에 적용할 수 있습니다.

```java
@PublicApi
@Tag(
        name = "Public",
        description = "공개 API"
)
@RestController
@RequestMapping("/api/v1/public")
public class PublicController {
}
```

#### 서비스별 ErrorCode 정의

각 서비스의 ErrorCode를 정의하고 Common의 `ErrorCode`를 implements 해주세요.

```java
package framey.user.exception;

import framey.common.response.ErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum UserErrorCode implements ErrorCode {

    USER_NOT_FOUND(
            "US-001",
            "사용자를 찾을 수 없습니다.",
            HttpStatus.NOT_FOUND
    ),
    EMAIL_ALREADY_EXISTS(
            "US-002",
            "이미 사용 중인 이메일입니다.",
            HttpStatus.CONFLICT
    ),
    INVALID_PASSWORD(
            "US-003",
            "비밀번호가 올바르지 않습니다.",
            HttpStatus.UNAUTHORIZED
    );

    private final String value;
    private final String message;
    private final HttpStatus httpStatus;
}
```

#### 에러 코드 작성 규칙

| 구분 | 규칙 | 예시 |
|---|---|---|
| 서비스 코드 | 서비스별 영문 대문자 코드 | `US`, `AU`, `PO` |
| 에러 코드 | `{서비스 코드}-{번호}` | `US-001` |
| 메시지 | 클라이언트에게 전달 가능한 메시지 | `사용자를 찾을 수 없습니다.` |
| HTTP 상태 | 에러 의미에 맞는 상태 코드 | `404 NOT_FOUND` |

### 비즈니스 예외 발생

서비스 계층에서 `BusinessException`을 발생시킵니다.

```java
public User findUser(final Long userId) {
    return userRepository.findById(userId)
            .orElseThrow(
                    () -> new BusinessException(
                            UserErrorCode.USER_NOT_FOUND
                    )
            );
}
```

`CommonExceptionHandler`에서 예외를 처리하여 다음 형식으로 응답합니다.

```json
{
  "code": "US-001",
  "message": "사용자를 찾을 수 없습니다."
}
```

### Swagger 에러 응답 예제 추가할 경우

API에서 발생 가능한 에러를 문서화하려면 `@ApiErrorCodeExample`을 사용하면 됩니다.

```java
@ApiErrorCodeExample(UserErrorCode.class)
@Operation(
        summary = "사용자 조회",
        description = "사용자 ID로 사용자를 조회합니다."
)
@GetMapping("/{userId}")
public ApiResponse<UserResponse> getUser(
        @PathVariable final Long userId
) {
    return ApiResponse.success(
            SuccessCode.OK,
            userService.getUser(userId)
    );
}
```

`UserErrorCode`의 모든 에러가 HTTP 상태별로 Swagger 응답 예제에 등록됩니다.

따라서 특정 API에서 실제로 발생 가능한 에러만 문서화하려면 아래의 `include` 사용을 권장합니다.

예:

```text
401
- INVALID_PASSWORD_US-003

404
- USER_NOT_FOUND_US-001

409
- EMAIL_ALREADY_EXISTS_US-002
```

---

### 일부 에러 코드만 문서화

특정 API에서 발생하는 에러만 표시하려면 `include`를 사용합니다.

```java
@ApiErrorCodeExample(
        value = UserErrorCode.class,
        include = {
                "USER_NOT_FOUND",
                "INVALID_PASSWORD"
        }
)
```

`include`에는 에러 코드값인 `US-001`이 아니라 **enum 상수 이름**을 작성합니다.

올바른 예:

```text
USER_NOT_FOUND
```

잘못된 예:

```text
US-001
```

---

### 여러 ErrorCode 문서화

한 API에서 공통 에러와 서비스 에러가 함께 발생한다면 여러 enum을 지정할 수 있습니다.

```java
@ApiErrorCodeExample(
        value = {
                CommonErrorCode.class,
                UserErrorCode.class
        },
        include = {
                "INVALID_REQUEST_PARAMETER",
                "USER_NOT_FOUND"
        }
)
```

Swagger에서는 HTTP 상태별로 응답 예제가 합쳐집니다.

#### API 작성 예시

```java
package framey.user.presentation;

import framey.common.exception.CommonErrorCode;
import framey.common.response.ApiResponse;
import framey.common.response.SuccessCode;
import framey.common.swagger.annotation.ApiErrorCodeExample;
import framey.user.exception.UserErrorCode;
import framey.user.presentation.response.UserResponse;
import framey.user.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(
        name = "User",
        description = "사용자 API"
)
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    @ApiErrorCodeExample(
            value = {
                    CommonErrorCode.class,
                    UserErrorCode.class
            },
            include = {
                    "INVALID_REQUEST_PARAMETER",
                    "USER_NOT_FOUND"
            }
    )
    @Operation(
            summary = "사용자 조회",
            description = "사용자 ID로 사용자를 조회합니다."
    )
    @GetMapping("/{userId}")
    public ApiResponse<UserResponse> getUser(
            @Parameter(
                    description = "사용자 ID",
                    example = "1",
                    required = true
            )
            @PathVariable final Long userId
    ) {
        return ApiResponse.success(
                SuccessCode.OK,
                userService.getUser(userId)
        );
    }
}
```
