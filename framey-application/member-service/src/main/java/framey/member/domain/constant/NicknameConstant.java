package framey.member.domain.constant;

import java.util.regex.Pattern;

public class NicknameConstant {
    public static final int MAX_NICKNAME_LENGTH = 10;
    public static final Pattern EDGE_WHITESPACE = Pattern.compile(
        "^[\\p{javaWhitespace}\\p{IsWhite_Space}]+|[\\p{javaWhitespace}\\p{IsWhite_Space}]+$"
    );
    public static final String BASE_NICKNAME = "프레이미";
    public static final int MIN_SUFFIX_DIGITS = 4;
}
