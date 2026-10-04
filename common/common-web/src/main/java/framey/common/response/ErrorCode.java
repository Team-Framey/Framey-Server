package framey.common.response;

import org.springframework.http.HttpStatus;

public interface ErrorCode {

    String getValue();

    String getMessage();

    HttpStatus getHttpStatus();
}
