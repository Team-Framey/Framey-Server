package framey.member.domain.member;

import lombok.AccessLevel;
import lombok.NoArgsConstructor;

import java.util.Random;

import static framey.member.domain.member.Member.MAX_NICKNAME_LENGTH;

@NoArgsConstructor(access = AccessLevel.PRIVATE)
public class NicknameGenerator {
    private static final String NICKNAME_BASE = "프레이미";
    private static final int MIN_SUFFIX_DIGITS = 5;

    public static String generate(String nickname) {
        boolean hasNickname = nickname != null && !nickname.isBlank();

        String baseNickname = hasNickname ? nickname.strip() : NICKNAME_BASE;

        int baseLength = baseNickname.codePointCount(0, baseNickname.length());
        int suffixLength = Math.max(MIN_SUFFIX_DIGITS, MAX_NICKNAME_LENGTH - baseLength);
        int keepLength = MAX_NICKNAME_LENGTH - suffixLength;

        if (baseLength > keepLength) {
            baseNickname = baseNickname.substring(0, baseNickname.offsetByCodePoints(0, keepLength));
        }

        StringBuilder base = new StringBuilder(baseNickname);

        for (int i = 0; i < suffixLength; i++) {
            int randomNumber = new Random().nextInt(10);
            base.append(randomNumber);
        }

        return base.toString();
    }
}
