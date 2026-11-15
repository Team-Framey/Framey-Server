// framey-common/src/test/java/framey//response/ApiResponseTest.java
package framey.common;

import framey.common.response.ApiResponse;
import framey.common.response.SuccessCode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class ApiResponseTest {

    private final SuccessCode successCode = SuccessCode.values()[0];

    @Test
    @DisplayName("success는_data_없이_코드와_메시지만_담는다")
    void successNoDataWithCodeAndMessage() {
        ApiResponse<Void> response = ApiResponse.success(successCode);

        assertEquals(successCode.getValue(), response.getCode());
        assertEquals(successCode.getMessage(), response.getMessage());
        assertNull(response.getData());
    }

    @Test
    @DisplayName("successWithData는 data와 함께 담는다")
    void successWithData() {
        ApiResponse<String> response = ApiResponse.successWithData(successCode, "payload");

        assertEquals(successCode.getValue(), response.getCode());
        assertEquals(successCode.getMessage(), response.getMessage());
        assertEquals("payload", response.getData());
    }
}
