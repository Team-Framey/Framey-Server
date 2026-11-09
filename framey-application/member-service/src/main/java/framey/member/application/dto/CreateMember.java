package framey.member.application.dto;

import framey.member.domain.model.Member;

public record CreateMember(
    String nickname,
    String email,
    String profileImageUrl
) {
    public static CreateMember from(final Member member) {
        return new CreateMember(
            member.getNickname(),
            member.getEmail(),
            member.getProfileImageUrl()
        );
    }
}
