package framey.common.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.Objects;

@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ApiResponse<T> {

    private String code;
    private String message;

    @JsonInclude(JsonInclude.Include.NON_NULL)
    private T data;

    //공통
    public static ApiResponse<Void> success(
            final SuccessCode successCode
    ) {
        return new ApiResponse<>(
                successCode.getValue(),
                successCode.getMessage(),
                null
        );
    }

    //data
    public static <T> ApiResponse<T> successWithData(
            final SuccessCode successCode,
            final T data
    ) {
        return new ApiResponse<>(
                successCode.getValue(), //code
               successCode.getMessage(), //message
                //null 비허용
                Objects.requireNonNull(data, "응답 데이터 Null 일수 없습니다.")
        );
    }

    public static ApiResponse<Void> fail(final ErrorCode errorCode) {
        return new ApiResponse<>(
                errorCode.getValue(),
                errorCode.getMessage(),
                null
        );
    }

    public static <T> ApiResponse<T> fail(
            final ErrorCode errorCode,
            final T data
    ) {
        return new ApiResponse<>(
                errorCode.getValue(),
                errorCode.getMessage(),
                data
        );
    }

    private ApiResponse(
            final String code,
            final String message,
            final T data
    ) {
        this.code = code;
        this.message = message;
        this.data = data;
    }
}
