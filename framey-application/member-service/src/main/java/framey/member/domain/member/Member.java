package framey.member.domain.member;

import framey.common.jpa.BaseEntity;
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
import lombok.NoArgsConstructor;

import java.time.LocalDate;
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
public class Member extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long memberId;

    @Column(updatable = false, nullable = false)
    private String email;

    @Column(length = 10, nullable = false)
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

    private LocalDate birthDate;

    @Enumerated(EnumType.STRING)
    private Gender gender;

    public static Member signUp(
        String email,
        String nickname,
        String profileImageUrl,
        String providerId,
        Provider provider,
        LocalDate birthDate,
        Gender gender
    ) {
        Member member = new Member();
        member.email = email;
        member.nickname = normalizeNickname(nickname);
        member.profileImageUrl = profileImageUrl;
        member.providerId = providerId;
        member.provider = provider;
        member.entityId = UUID.randomUUID();
        member.birthDate = birthDate;
        member.gender = gender;

        return member;
    }

    private static String normalizeNickname(String nickname) {
        // TODO: normalizing
        return nickname;
    }
}
