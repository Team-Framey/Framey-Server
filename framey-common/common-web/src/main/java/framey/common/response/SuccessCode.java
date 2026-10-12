package framey.common.response;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum SuccessCode {

    OK("SC-001", "요청이 정상적으로 처리되었습니다."),
    CREATED("SC-002", "정상적으로 생성되었습니다."),
    UPDATED("SC-003", "정상적으로 수정되었습니다."),
    DELETED("SC-004", "정상적으로 삭제되었습니다.");

    private final String value;
    private final String message;
}
