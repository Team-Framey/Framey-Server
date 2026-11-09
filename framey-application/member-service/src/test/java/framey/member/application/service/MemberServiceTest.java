package framey.member.application.service;

import framey.common.exception.BusinessException;
import framey.member.application.dto.CreateMember;
import framey.member.domain.constant.NicknameConstant;
import framey.member.domain.exception.MemberErrorCode;
import framey.member.domain.model.Member;
import framey.member.domain.repository.MemberRepository;
import org.assertj.core.api.Assertions;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;

@ExtendWith(MockitoExtension.class)
class MemberServiceTest {
    @Mock
    private MemberRepository memberRepository;

    @InjectMocks
    private MemberService memberService;

    @Test
    @DisplayName("소셜 닉네임이 사용 중이 아니면 해당 닉네임을 그대로 사용한다")
    void useSocialNicknameWhenNotDuplicated() {
        given(memberRepository.existsByNickname("프레이미")).willReturn(false);
        given(memberRepository.save(any(Member.class))).willAnswer(inv -> inv.getArgument(0));

        CreateMember member = new CreateMember("프레이미", "framey@exam.com", "");

        Member newMember = memberService.createMember(member);

        Assertions.assertThat(newMember.getNickname()).isEqualTo("프레이미");
    }

    @Test
    @DisplayName("소셜 닉네임이 사용 중이라면, 기존 닉네임 뒤에 10자리를 맞춰 임의 숫자를 넣어 사용한다")
    void useAppendSuffixNicknameWhenDuplicated() {
        given(memberRepository.existsByNickname("프레이미")).willReturn(true);
        given(memberRepository.save(any(Member.class))).willAnswer(inv -> inv.getArgument(0));

        CreateMember member = new CreateMember("프레이미", "framey@exam.com", "");

        Member newMember = memberService.createMember(member);

        Assertions.assertThat(newMember.getNickname()).matches("^프레이미\\d{6}");
    }

    @Test
    @DisplayName("소셜 닉네임이 기본 닉네임과 같으면 뒤에 임의 숫자를 붙인다")
    void appendSuffixWhenNicknameEqualsBaseNickname() {
        given(memberRepository.save(any(Member.class))).willAnswer(inv -> inv.getArgument(0));

        CreateMember member = new CreateMember("framey", "framey@exam.com", "");

        Member newMember = memberService.createMember(member);

        Assertions.assertThat(newMember.getNickname()).matches("^framey\\d{4}");
        then(memberRepository).should(never()).existsByNickname("framey");
    }

    @ParameterizedTest
    @ValueSource(strings = {" ", "\u3000", "\u00A0"})
    @NullAndEmptySource
    @DisplayName("소셜 닉네임이 없으면 기본 닉네임에 임의 숫자를 붙인다")
    void useBaseNicknameWithSuffixWhenNicknameIsBlank(String nickname) {
        given(memberRepository.save(any(Member.class))).willAnswer(inv -> inv.getArgument(0));
        CreateMember member = new CreateMember(nickname, "framey@exam.com", "");

        Member newMember = memberService.createMember(member);

        Assertions.assertThat(newMember.getNickname()).matches("^framey\\d{4}");
        then(memberRepository).should(never()).existsByNickname("framey");
    }

    @Test
    @DisplayName("임의 숫자를 붙인 닉네임도 모두 사용 중이면 닉네임 생성에 실패한다")
    void failWhenAllGeneratedNicknamesAreDuplicated() {
        given(memberRepository.existsByNickname(anyString())).willReturn(true);

        CreateMember member = new CreateMember("프레이미", "framey@exam.com", "");

        Assertions.assertThatThrownBy(() -> memberService.createMember(member))
            .isInstanceOf(BusinessException.class)
            .extracting("errorCode")
            .isEqualTo(MemberErrorCode.NICKNAME_GENERATION_FAILED);

        then(memberRepository).should(never()).save(any());
        then(memberRepository).should(times(1 + NicknameConstant.MAX_RETRY_COUNT)).existsByNickname(anyString());
    }

    @Test
    @DisplayName("임의 숫자를 붙인 닉네임도 사용 중이라면 새 숫자를 붙여 다시 시도한다")
    void retryWithNewSuffixWhenGeneratedNicknameIsDuplicated() {
        given(memberRepository.existsByNickname(anyString())).willReturn(true, true, false);
        given(memberRepository.save(any(Member.class))).willAnswer(inv -> inv.getArgument(0));

        CreateMember member = new CreateMember("프레이미", "framey@exam.com", "");

        Member newMember = memberService.createMember(member);

        Assertions.assertThat(newMember.getNickname()).matches("^프레이미\\d{6}");
        then(memberRepository).should(times(3)).existsByNickname(anyString());
    }
}
