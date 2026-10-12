package framey.common.advice;

import framey.common.exception.BusinessException;
import framey.common.exception.CommonErrorCode;
import framey.common.exception.ServiceUnavailableException;
import framey.common.response.ApiResponse;
import jakarta.validation.ConstraintViolationException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.HandlerMethodValidationException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import static framey.common.response.ApiResponse.fail;

@Slf4j
@RestControllerAdvice
public class CommonExceptionHandler {

    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiResponse<Void>> handleNoResourceFoundException(final NoResourceFoundException e) {
        log.warn("{} 발생!", e.getClass().getSimpleName(), e);
        return ResponseEntity.status(CommonErrorCode.NOT_FOUND.getHttpStatus())
                .body(fail(CommonErrorCode.NOT_FOUND));
    }

    @ExceptionHandler({
            MethodArgumentNotValidException.class,
            HandlerMethodValidationException.class
    })
    public ResponseEntity<ApiResponse<Void>> handleValidationException(final Exception e) {
        log.warn("{} 발생!", e.getClass().getSimpleName(), e);
        return ResponseEntity.badRequest()
                .body(fail(CommonErrorCode.INVALID_REQUEST_PARAMETER));
    }

    @ExceptionHandler(ServiceUnavailableException.class)
    public ResponseEntity<ApiResponse<Void>> handleServiceUnavailableException(final ServiceUnavailableException e) {
        log.warn("{} 발생! errorCode = {}", e.getClass().getSimpleName(), e.getErrorCode().getValue(), e);

        return ResponseEntity.status(e.getErrorCode().getHttpStatus())
                .body(fail(e.getErrorCode()));
    }

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Void>> handleBusinessException(
            final BusinessException e
    ) {
        log.warn(
                "{} 발생! errorCode={}",
                e.getClass().getSimpleName(),
                e.getErrorCode().getValue(),
                e
        );
        return ResponseEntity.status(e.getErrorCode().getHttpStatus())
                .body(fail(e.getErrorCode()));
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiResponse<Void>> handleConstraintViolationException(final ConstraintViolationException e) {
        log.warn("{} 발생!", e.getClass().getSimpleName(), e);
        return ResponseEntity.badRequest()
                .body(fail(CommonErrorCode.INVALID_REQUEST_PARAMETER));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleException(final Exception e) {
        log.error("{} 발생!", e.getClass().getSimpleName(), e);
        return ResponseEntity.internalServerError()
                .body(fail(CommonErrorCode.INTERNAL_SERVER_ERROR));
    }
}
