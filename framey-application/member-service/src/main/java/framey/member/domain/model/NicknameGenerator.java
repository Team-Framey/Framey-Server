package framey.member.domain.model;

import lombok.AccessLevel;
import lombok.NoArgsConstructor;

import java.util.Random;

import static framey.member.domain.constant.NicknameConstant.BASE_NICKNAME;
import static framey.member.domain.constant.NicknameConstant.EDGE_WHITESPACE;
import static framey.member.domain.constant.NicknameConstant.MAX_NICKNAME_LENGTH;
import static framey.member.domain.constant.NicknameConstant.MIN_SUFFIX_DIGITS;

@NoArgsConstructor(access = AccessLevel.PRIVATE)
public class NicknameGenerator {
    public static String normalize(String nickname) {
        if (nickname == null) {
            return BASE_NICKNAME;
        }

        String stripedNickname = EDGE_WHITESPACE.matcher(nickname).replaceAll("");

        if (stripedNickname.isEmpty()) {
            return BASE_NICKNAME;
        }

        return truncate(stripedNickname, MAX_NICKNAME_LENGTH);
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
