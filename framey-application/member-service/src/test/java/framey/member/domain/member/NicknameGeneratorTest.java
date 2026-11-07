package framey.member.domain.member;

import org.assertj.core.api.Assertions;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

import static framey.member.domain.model.NicknameGenerator.appendSuffix;
import static framey.member.domain.model.NicknameGenerator.normalize;

class NicknameGeneratorTest {
    @ParameterizedTest
    @ValueSource(strings = {" ", "\u3000"})
    @NullAndEmptySource
    @DisplayName("닉네임이 비어있을 경우 기본 닉네임을 사용한다")
    void useDefaultNicknameWhenNicknameIsBlank(String nickname) {
        String generatedNickname = appendSuffix(normalize(nickname));

        Assertions.assertThat(generatedNickname).isNotBlank();
        Assertions.assertThat(generatedNickname).matches("^프레이미\\d{6}$");
    }

    @ParameterizedTest
    @ValueSource(strings = { " 프레이미 ", " 프레이미", "프레이미 ", "\u3000프레이미\u3000"})
    @DisplayName("닉네임의 공백을 제거한다.")
    void stripsNicknameWhiteSpaces(String nickname) {
        String generatedNickname = normalize(nickname);

        Assertions.assertThat(generatedNickname).isNotBlank();
        Assertions.assertThat(generatedNickname).isEqualTo("프레이미");
    }

}
