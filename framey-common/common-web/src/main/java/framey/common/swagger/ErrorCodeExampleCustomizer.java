package framey.common.swagger;

import framey.common.response.ApiResponse;
import framey.common.response.ErrorCode;
import framey.common.swagger.annotation.ApiErrorCodeExample;
import framey.common.swagger.annotation.PublicApi;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.examples.Example;
import io.swagger.v3.oas.models.media.Content;
import io.swagger.v3.oas.models.media.MediaType;
import io.swagger.v3.oas.models.responses.ApiResponses;
import org.springdoc.core.customizers.OperationCustomizer;
import org.springframework.web.method.HandlerMethod;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

public class ErrorCodeExampleCustomizer implements OperationCustomizer {

    private static final String APPLICATION_JSON = "application/json";

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

        List<String> includes = Arrays.asList(annotation.include());

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

        addExamplesToResponses(
                responses,
                examplesByStatus
        );
    }

    private List<ErrorCode> getErrorCodes(
            Class<? extends ErrorCode> type
    ) {
        Object[] constants = type.getEnumConstants();

        if (constants == null) {
            throw new IllegalArgumentException(
                    "ErrorCode 구현체는 enum이어야 합니다: "
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
                    "ErrorCode 구현체는 enum이어야 합니다."
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
                ApiResponse.fail(errorCode)
        );

        return example;
    }

    private void addExamplesToResponses(
            ApiResponses responses,
            Map<Integer, List<ExampleHolder>> examplesByStatus
    ) {
        examplesByStatus.forEach((status, exampleHolders) -> {
            String statusCode = String.valueOf(status);

            io.swagger.v3.oas.models.responses.ApiResponse response =
                    responses.computeIfAbsent(
                            statusCode,
                            key -> new io.swagger.v3.oas.models.responses.ApiResponse()
                                    .description("Error Response")
                    );

            if (response.getContent() == null) {
                response.setContent(new Content());
            }

            MediaType mediaType = response.getContent().get(APPLICATION_JSON);

            if (mediaType == null) {
                mediaType = new MediaType();
                response.getContent().addMediaType(APPLICATION_JSON, mediaType);
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
