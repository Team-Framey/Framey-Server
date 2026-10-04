package framey.common.config;

import framey.common.swagger.ErrorCodeExampleCustomizer;
import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springdoc.core.customizers.OperationCustomizer;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;

@AutoConfiguration
@ConditionalOnProperty(
        name = "springdoc.api-docs.enabled",
        havingValue = "true"
)
public class SwaggerConfig {

    private static final String SECURITY_SCHEME_NAME = "bearerAuth";

    @Bean
    public OpenAPI frameyOpenAPI() {
        return new OpenAPI()
                .info(apiInfo())
                .components(
                        new Components()
                                .addSecuritySchemes(
                                        SECURITY_SCHEME_NAME,
                                        bearerSecurityScheme()
                                )
                )
                .addSecurityItem(
                        new SecurityRequirement()
                                .addList(SECURITY_SCHEME_NAME)
                );
    }

    @Bean
    public OperationCustomizer errorCodeExampleCustomizer() {
        return new ErrorCodeExampleCustomizer();
    }

    private Info apiInfo() {
        return new Info()
                .title("Framey API")
                .description("Framey Backend API Documentation")
                .version("1.0.0");
    }

    private SecurityScheme bearerSecurityScheme() {
        return new SecurityScheme()
                .type(SecurityScheme.Type.HTTP)
                .scheme("bearer")
                .bearerFormat("JWT")
                .description("JWT Access Token");
    }
}
