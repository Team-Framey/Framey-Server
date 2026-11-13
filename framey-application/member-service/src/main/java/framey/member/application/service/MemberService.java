package framey.member.application.service;

import framey.common.exception.BusinessException;
import framey.member.application.dto.CreateMember;
import framey.member.config.MemberProperties;
import framey.member.domain.constant.NicknameConstant;
import framey.member.domain.constant.ProfileImageConstant;
import framey.member.domain.constant.Provider;
import framey.member.domain.exception.MemberErrorCode;
import framey.member.domain.model.Member;
import framey.member.domain.model.NicknameGenerator;
import framey.member.domain.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URI;
import java.net.URISyntaxException;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MemberService {
    private final MemberRepository memberRepository;
    private final MemberProperties memberProperties;

    @Transactional
    public Member createMember(CreateMember createMember) {
        // TODO: 추후 AuthService와 같은 createMember를 처리하는 쪽에서 Transaction 재시도 로직 추가

        Member member = Member.signUp(
            createMember.email(),
            resolveNickname(createMember.nickname()),
            resolveProfileImageUrl(createMember.profileImageUrl()),
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

    private String resolveProfileImageUrl(String profileImageUrl) {
        if (!isValidProfileImageUrl(profileImageUrl)) {
            return memberProperties.defaultProfileImageUrl();
        }

        return profileImageUrl;
    }

    private boolean isValidProfileImageUrl(String url) {
        if (url == null || url.isBlank() || url.length() > ProfileImageConstant.MAX_PROFILE_IMAGE_URL_LENGTH) {
            return false;
        }

        try {
            URI uri = new URI(url);
            return "https".equalsIgnoreCase(uri.getScheme()) && uri.getHost() != null;
        } catch (URISyntaxException e) {
            return false;
        }
    }
}
