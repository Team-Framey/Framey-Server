package framey.member.domain.member;

import org.assertj.core.api.Assertions;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

import static framey.member.domain.model.NicknameGenerator.appendSuffix;
import static framey.member.domain.model.NicknameGenerator.normalize;

class NicknameGeneratorTest {
    @ParameterizedTest
    @ValueSource(strings = {" ", "\u3000", "\u00A0"})
    @NullAndEmptySource
    @DisplayName("닉네임이 비어있을 경우 기본 닉네임을 사용한다")
    void useDefaultNicknameWhenNicknameIsBlank(String nickname) {
        String generatedNickname = appendSuffix(normalize(nickname));

        Assertions.assertThat(generatedNickname).matches("^framey\\d{4}$");
    }

    @ParameterizedTest
    @ValueSource(strings = { " 프레이미 ", " 프레이미", "프레이미 ", "\u3000프레이미\u3000"})
    @DisplayName("닉네임의 앞 뒤 공백을 제거한다.")
    void stripsNicknameWhiteSpaces(String nickname) {
        String generatedNickname = normalize(nickname);

        Assertions.assertThat(generatedNickname).isEqualTo("프레이미");
    }

    @Test
    @DisplayName("닉네임이 10자를 넘어가면 10자에 맞게 자른다")
    void truncateNicknameWhenLengthOver10() {
        String nickname = "가나다라마바사아자차카타파";
        String generatedNickname = normalize(nickname);

        Assertions.assertThat(generatedNickname.codePointCount(0, generatedNickname.length())).isEqualTo(10);
    }

    @Test
    @DisplayName("중복 방지용 임의 숫자를 붙일 때, 닉네임이 길면 앞부분을 잘라 최소 4자리를 확보한다")
    void truncateBaseToKeepMinimumSuffixDigits() {
        String nickname = "가나다라마바사아자차";
        String result = appendSuffix(normalize(nickname));

        Assertions.assertThat(result).matches("^가나다라마바\\d{4}");
    }

    @Test
    @DisplayName("짧은 닉네임은 전체 10자가 되도록 숫자를 채운다")
    void fillSuffixToMaxLengthWhenBaseIsShort() {
        String nickname = "가나";
        String result = appendSuffix(normalize(nickname));

        Assertions.assertThat(result).matches("^가나\\d{8}");
    }

    @Test
    @DisplayName("이모지가 포함된 닉네임은 깨지지 않도록 코드 포인트 기준으로 10자까지 자른다")
    void truncateNicknameByCodePoint() {
        String nickname = "🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂";
        String result = normalize(nickname);

        Assertions.assertThat(result).isEqualTo("🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂");
        Assertions.assertThat(result.codePointCount(0, result.length())).isEqualTo(10);
    }

    @Test
    @DisplayName("이모지 닉네임에 숫자를 붙일 때 깨지지 않도록 앞부분을 자른다")
    void truncateEmojiBaseByCodePointWhenAppendingSuffix() {
        String nickname = "🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂";
        String result = appendSuffix(normalize(nickname));

        Assertions.assertThat(result).matches("^🙂🙂🙂🙂🙂🙂\\d{4}");
    }

    @Test
    @DisplayName("닉네임 중간의 공백은 제거하지 않는다")
    void keepWhitespaceInsideNickname() {
        String nickname = "프 레 이 미";
        String result = normalize(nickname);

        Assertions.assertThat(result).isEqualTo("프 레 이 미");
    }
}
