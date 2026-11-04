package framey.member.domain.member;

import framey.common.exception.BusinessException;
import framey.member.exception.MemberErrorCode;
import org.assertj.core.api.Assertions;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;

class MemberTest {

    @ParameterizedTest
    @ValueSource(strings = {" ", "    ", "\u3000"})
    @NullAndEmptySource
    @DisplayName("닉네임이 비어 있거나 null이면 가입할 수 없다")
    void signUpFailWhenNicknameIsBlank(String nickname) {
        Assertions.assertThatThrownBy(() ->
                Member.signUp("framey@test.com", nickname, "", "test-1", Provider.GOOGLE)
            )
            .isInstanceOf(BusinessException.class)
            .extracting("errorCode")
            .isEqualTo(MemberErrorCode.NICKNAME_REQUIRED);
    }

    @ParameterizedTest
    @ValueSource(strings = {" Framey ", "\u3000Framey\u3000"})
    @DisplayName("닉네임에 공백(유니코드 공백 포함)이 있으면 제거된다")
    void signUpStripsNicknameWhitespace(String nickname) {
        Member member = Member.signUp("framey@test.com", nickname, "", "test-1", Provider.GOOGLE);

        Assertions.assertThat(member.getEntityId()).isNotNull();
        Assertions.assertThat(member.getNickname()).isEqualTo(nickname.strip());
    }

    @Test
    @DisplayName("닉네임이 10자 이내면 가입할 수 있다")
    void signUpSuccessWhenNicknameIsWithinMaxLength() {
        String nickname = "0123456789";
        Member member = Member.signUp("framey@test.com", nickname, "", "test-1", Provider.GOOGLE);

        Assertions.assertThat(nickname.length()).isEqualTo(10);
        Assertions.assertThat(member.getNickname()).isEqualTo(nickname);
        Assertions.assertThat(member.getNickname()).isEqualTo(nickname);
        Assertions.assertThat(member.getEntityId()).isNotNull();
    }

    @Test
    @DisplayName("닉네임의 이모지는 1글자로 센다")
    void signUpCountsEmojiAsOneChar() {
        String nickname = "🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂";
        Member member = Member.signUp("framey@test.com", nickname, "", "test-1", Provider.GOOGLE);

        Assertions.assertThat(nickname.codePointCount(0, nickname.length())).isEqualTo(10);
        Assertions.assertThat(member.getNickname()).isEqualTo(nickname);
        Assertions.assertThat(member.getNickname()).isEqualTo(nickname);
        Assertions.assertThat(member.getEntityId()).isNotNull();
    }

    @ParameterizedTest
    @ValueSource(strings = {"01234567890", "🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂"})
    @DisplayName("닉네임 길이는 10자를 초과할 수 없다")
    void signUpFailWhenNicknameOverMaxLength(String nickname) {
        Assertions.assertThat(nickname.codePointCount(0, nickname.length())).isEqualTo(11);
        Assertions.assertThatThrownBy(() ->
                Member.signUp("framey@test.com", nickname, "", "test-1", Provider.GOOGLE)
            )
            .isInstanceOf(BusinessException.class)
            .extracting("errorCode")
            .isEqualTo(MemberErrorCode.MAX_NICKNAME_LENGTH);
    }
}
