package framey.member.domain.model;

import lombok.AccessLevel;
import lombok.NoArgsConstructor;

import java.util.Random;

import static framey.member.domain.model.Member.MAX_NICKNAME_LENGTH;

@NoArgsConstructor(access = AccessLevel.PRIVATE)
public class NicknameGenerator {
    private static final String BASE_NICKNAME = "프레이미";
    private static final int MIN_SUFFIX_DIGITS = 4;

    public static String normalize(String nickname) {
        if (nickname == null || nickname.isBlank()) {
            return BASE_NICKNAME;
        }

        return truncate(nickname.strip(), MAX_NICKNAME_LENGTH);
    }

    public static String appendSuffix(String base) {
        int baseLength = base.codePointCount(0, base.length());
        int suffixLength = Math.max(MIN_SUFFIX_DIGITS, MAX_NICKNAME_LENGTH - baseLength);

        StringBuilder nickname = new StringBuilder(truncate(base, MAX_NICKNAME_LENGTH - suffixLength));
        for (int i = 0; i < suffixLength; i++) {
            nickname.append(new Random().nextInt(10));
        }
        return nickname.toString();
    }

    private static String truncate(String value, int maxLength) {
        if (value.codePointCount(0, value.length()) <= maxLength) {
            return value;
        }
        return value.substring(0, value.offsetByCodePoints(0, maxLength));
    }
}
