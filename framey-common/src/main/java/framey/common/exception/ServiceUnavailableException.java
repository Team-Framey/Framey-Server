package framey.common.exception;

import framey.common.response.ErrorCode;

public class ServiceUnavailableException extends BusinessException {

    public ServiceUnavailableException(final ErrorCode errorCode) {
        super(errorCode);
    }

    public ServiceUnavailableException(final ErrorCode errorCode, final String message) {
        super(errorCode, message);
    }
}
