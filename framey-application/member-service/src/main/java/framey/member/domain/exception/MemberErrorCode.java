package framey.member.domain.exception;

import framey.common.response.ErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum MemberErrorCode implements ErrorCode {
    NICKNAME_REQUIRED("MB-001", "닉네임을 입력해 주세요.", HttpStatus.BAD_REQUEST),
    MAX_NICKNAME_LENGTH("MB-002", "닉네임은 10자 이내로 입력해 주세요.", HttpStatus.BAD_REQUEST);

    private final String value;
    private final String message;
    private final HttpStatus httpStatus;
}
