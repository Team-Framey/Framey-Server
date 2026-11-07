package framey.member.domain.member;

import framey.common.exception.BusinessException;
import framey.common.jpa.BaseEntity;
import framey.member.exception.MemberErrorCode;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Column;
import jakarta.persistence.Enumerated;
import jakarta.persistence.EnumType;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Entity
@Table(
    uniqueConstraints = {
        @UniqueConstraint(name = "uk_member_provider", columnNames = {"provider", "provider_id"}),
        @UniqueConstraint(name = "uk_member_nickname", columnNames = {"nickname"}),
        @UniqueConstraint(name = "uk_member_email", columnNames = {"email"}),
    }
)
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@Getter
public class Member extends BaseEntity {
    public static final int MAX_NICKNAME_LENGTH = 10;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long memberId;

    @Column(updatable = false, nullable = false)
    private String email;

    @Column(length = MAX_NICKNAME_LENGTH, nullable = false)
    private String nickname;

    @Column(updatable = false, unique = true, nullable = false)
    private UUID entityId;

    @Column(length = 2048, nullable = false)
    private String profileImageUrl;

    @Column(updatable = false, nullable = false)
    private String providerId;

    @Enumerated(EnumType.STRING)
    @Column(updatable = false, nullable = false)
    private Provider provider;

    public static Member signUp(
        String email,
        String nickname,
        String profileImageUrl,
        String providerId,
        Provider provider
    ) {
        Member member = new Member();
        member.email = email;
        member.nickname = validateNickname(nickname);
        member.profileImageUrl = profileImageUrl;
        member.providerId = providerId;
        member.provider = provider;
        member.entityId = UUID.randomUUID();

        return member;
    }

    private static String validateNickname(String nickname) {
        if (nickname == null || nickname.isBlank()) {
            throw new BusinessException(MemberErrorCode.NICKNAME_REQUIRED);
        }

        String stripedNickname = nickname.strip();

        // NOTE: 이모지를 1글자로 처리하기 위해 codePointCount 사용
        if (stripedNickname.codePointCount(0, stripedNickname.length()) > MAX_NICKNAME_LENGTH) {
            throw new BusinessException(MemberErrorCode.MAX_NICKNAME_LENGTH);
        }

        return stripedNickname;
    }
}
