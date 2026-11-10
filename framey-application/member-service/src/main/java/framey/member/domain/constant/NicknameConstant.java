package framey.member.domain.constant;

import lombok.AccessLevel;
import lombok.NoArgsConstructor;

import java.util.regex.Pattern;

@NoArgsConstructor(access = AccessLevel.PRIVATE)
public final class NicknameConstant {
    public static final int MAX_NICKNAME_LENGTH = 10;
    public static final Pattern EDGE_WHITESPACE = Pattern.compile(
        "^[\\p{javaWhitespace}\\p{IsWhite_Space}]+|[\\p{javaWhitespace}\\p{IsWhite_Space}]+$"
    );
    public static final String BASE_NICKNAME = "framey";
    public static final int SUFFIX_DIGITS = 4;
}
