package framey.member.domain.exception;

import framey.common.response.ErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum MemberErrorCode implements ErrorCode {
    NICKNAME_REQUIRED("MB-001", "닉네임을 입력해 주세요.", HttpStatus.BAD_REQUEST),
    MAX_NICKNAME_LENGTH("MB-002", "닉네임은 10자 이내로 입력해 주세요.", HttpStatus.BAD_REQUEST),
    NICKNAME_GENERATION_FAILED("MB-003", "닉네임 생성에 실패했습니다. 다시 시도해 주세요.", HttpStatus.INTERNAL_SERVER_ERROR);

    private final String value;
    private final String message;
    private final HttpStatus httpStatus;
}
