package framey.common.exception;

import framey.common.response.ErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum CommonErrorCode implements ErrorCode {

    INVALID_REQUEST("CM-001", "요청 값이 올바르지 않습니다.", HttpStatus.BAD_REQUEST),
    METHOD_NOT_ALLOWED("CM-002", "지원하지 않는 HTTP 메서드입니다.", HttpStatus.METHOD_NOT_ALLOWED),
    INTERNAL_SERVER_ERROR("CM-003", "서버 내부 오류가 발생했습니다.", HttpStatus.INTERNAL_SERVER_ERROR),
    NOT_FOUND("CM-004", "리소스를 찾을 수 없습니다.", HttpStatus.NOT_FOUND),
    INVALID_REQUEST_PARAMETER("CM-005", "요청 파라미터가 올바르지 않습니다.", HttpStatus.BAD_REQUEST),
    AUTHENTICATION_REQUIRED("CM-006", "인증이 필요합니다.", HttpStatus.UNAUTHORIZED),
    SERVICE_UNAVAILABLE("CM-007", "서비스를 사용할 수 없습니다.", HttpStatus.SERVICE_UNAVAILABLE);

    private final String value;
    private final String message;
    private final HttpStatus httpStatus;
}
