package framey.member.application.service;

import framey.common.exception.BusinessException;
import framey.member.application.dto.CreateMember;
import framey.member.domain.constant.NicknameConstant;
import framey.member.domain.constant.Provider;
import framey.member.domain.exception.MemberErrorCode;
import framey.member.domain.model.Member;
import framey.member.domain.model.NicknameGenerator;
import framey.member.domain.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MemberService {
    private final MemberRepository memberRepository;

    @Transactional
    public Member createMember(CreateMember createMember) {
        // TODO: provider 및 providerId 검증
        Member member = Member.signUp(
            createMember.email(),
            resolveNickname(createMember.nickname()),
            createMember.profileImageUrl(),
            "123", // TODO: 임시 providerId
            Provider.GOOGLE // TODO: 임시 provider
        );

        return memberRepository.save(member);
    }

    private String resolveNickname(String nickname) {
        String baseNickname = NicknameGenerator.normalize(nickname);

        if (!baseNickname.equals(NicknameConstant.BASE_NICKNAME) && !memberRepository.existsByNickname(baseNickname)) {
            return baseNickname;
        }

        for (int i = 0; i < NicknameConstant.MAX_RETRY_COUNT; i++) {
            String generatedNickname = NicknameGenerator.appendSuffix(baseNickname);

            if (!memberRepository.existsByNickname(generatedNickname)) {
                return generatedNickname;
            }
        }

        throw new BusinessException(MemberErrorCode.NICKNAME_GENERATION_FAILED);
    }
}
