package framey.member.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "member")
public record MemberProperties(String defaultProfileImageUrl) {
}
