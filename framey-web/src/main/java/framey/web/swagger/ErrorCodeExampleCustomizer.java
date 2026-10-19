package framey.web.swagger;

import framey.common.response.ErrorCode;
import framey.web.swagger.annotation.ApiErrorCodeExample;
import framey.web.swagger.annotation.PublicApi;

import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.examples.Example;
import io.swagger.v3.oas.models.media.Content;
import io.swagger.v3.oas.models.media.MediaType;
import io.swagger.v3.oas.models.responses.ApiResponse;
import io.swagger.v3.oas.models.responses.ApiResponses;
import org.springdoc.core.customizers.OperationCustomizer;
import org.springframework.web.method.HandlerMethod;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

public class ErrorCodeExampleCustomizer implements OperationCustomizer {

    private static final String APPLICATION_JSON = "application/json";
    private static final String ENUM_TYPE_REQUIRED_MESSAGE = "ErrorCode 구현체는 enum 타입이어야 합니다.";

    @Override
    public Operation customize(
            Operation operation,
            HandlerMethod handlerMethod
    ) {
        handlePublicApi(operation, handlerMethod);
        handleErrorCodeExamples(operation, handlerMethod);

        return operation;
    }

    private void handlePublicApi(
            Operation operation,
            HandlerMethod handlerMethod
    ) {
        boolean publicMethod =
                handlerMethod.hasMethodAnnotation(PublicApi.class);

        boolean publicController =
                handlerMethod.getBeanType().isAnnotationPresent(PublicApi.class);

        if (publicMethod || publicController) {
            operation.setSecurity(new ArrayList<>());
        }
    }

    private void handleErrorCodeExamples(
            Operation operation,
            HandlerMethod handlerMethod
    ) {
        ApiErrorCodeExample annotation =
                handlerMethod.getMethodAnnotation(ApiErrorCodeExample.class);

        if (annotation == null) {
            return;
        }

        Set<String> includes = Set.of(annotation.include());

        List<ExampleHolder> exampleHolders =
                Arrays.stream(annotation.value())
                        .flatMap(type -> getErrorCodes(type).stream())
                        .filter(errorCode ->
                                includes.isEmpty()
                                        || includes.contains(getEnumName(errorCode))
                        )
                        .map(this::createExampleHolder)
                        .toList();

        Map<Integer, List<ExampleHolder>> examplesByStatus =
                exampleHolders.stream()
                        .collect(
                                Collectors.groupingBy(
                                        ExampleHolder::getStatus
                                )
                        );

        ApiResponses responses = operation.getResponses();

        if (responses == null) {
            responses = new ApiResponses();
            operation.setResponses(responses);
        }

        addExamplesToResponses(responses, examplesByStatus);
    }

    private List<ErrorCode> getErrorCodes(
            Class<? extends ErrorCode> type
    ) {
        Object[] constants = type.getEnumConstants();

        if (constants == null) {
            throw new IllegalArgumentException(
                    ENUM_TYPE_REQUIRED_MESSAGE
                            + " type="
                            + type.getName()
            );
        }

        return Arrays.stream(constants)
                .map(ErrorCode.class::cast)
                .toList();
    }

    private String getEnumName(ErrorCode errorCode) {
        if (!(errorCode instanceof Enum<?> enumValue)) {
            throw new IllegalArgumentException(
                    ENUM_TYPE_REQUIRED_MESSAGE
            );
        }

        return enumValue.name();
    }

    private ExampleHolder createExampleHolder(
            ErrorCode errorCode
    ) {
        return ExampleHolder.builder()
                .name(getEnumName(errorCode) + "_" + errorCode.getValue())
                .status(errorCode.getHttpStatus().value())
                .holder(createExample(errorCode))
                .build();
    }

    private Example createExample(ErrorCode errorCode) {
        Example example = new Example();

        example.setValue(
                framey.common.response.ApiResponse.fail(errorCode)
        );

        return example;
    }

    private void addExamplesToResponses(
            ApiResponses responses,
            Map<Integer, List<ExampleHolder>> examplesByStatus
    ) {
        examplesByStatus.forEach((status, exampleHolders) -> {
            String statusCode = String.valueOf(status);

            ApiResponse response =
                    responses.computeIfAbsent(
                            statusCode,
                            key -> new ApiResponse()
                                    .description("Error Response")
                    );

            if (response.getContent() == null) {
                response.setContent(new Content());
            }

            MediaType mediaType = response.getContent().get(APPLICATION_JSON);

            if (mediaType == null) {
                mediaType = new MediaType();
                response.getContent()
                        .addMediaType(APPLICATION_JSON, mediaType);
            }

            for (ExampleHolder exampleHolder : exampleHolders) {
                mediaType.addExamples(
                        exampleHolder.getName(),
                        exampleHolder.getHolder()
                );
            }
        });
    }
}
