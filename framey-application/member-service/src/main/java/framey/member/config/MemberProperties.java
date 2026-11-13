package framey.member.config;

import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@Validated
@ConfigurationProperties(prefix = "member")
public record MemberProperties(@NotBlank String defaultProfileImageUrl) {
}
