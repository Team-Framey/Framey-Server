## Framey Server Repository

> 사진 선택만으로 인스타그램 스토리에 최적화된 콜라주를 자동으로 완성해주는 서비스 Framey 서버 레포지토리 입니다.

### 🛠️ Tech Stack

![Java](https://img.shields.io/badge/Java-21-007396?logo=openjdk&logoColor=white)
![Spring Boot](https://img.shields.io/badge/Spring%20Boot-4.1.0-6DB33F?logo=springboot&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white)
<br>
![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?logo=nginx&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?logo=githubactions&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20RDS%20%7C%20S3%20%7C%20ECR-232F3E?logo=amazonwebservices&logoColor=white)
<br>
![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-F46800?logo=grafana&logoColor=white)
![k6](https://img.shields.io/badge/k6-7D64FF?logo=k6&logoColor=white)

### 🧑🏻‍💻 Contributors - Developers

| <a href="https://github.com/young0311"><img src="https://github.com/young0311.png" width="100" height="100"></a> | <a href="https://github.com/nimuseel"><img src="https://github.com/nimuseel.png" width="100" height="100"></a> | <a href="https://github.com/hwannn123"><img src="https://github.com/hwannn123.png" width="100" height="100"></a> |
|:---:|:---:|:---:|
| **양화영 (Lead)** | **이수민** | **김환희** |

### Claude Architecture
> Claude Code를 단순 코드 생성 도구가 아닌 팀의 코드 품질 루프에 통합된 에이전트로 운영합니다
<p align="center">
  <img
    src="https://github.com/user-attachments/assets/ddc8eaf3-9d18-4c49-9116-9fcbe79f183c"
    alt="Claude Architecture Review"
    width="800"
  />
</p>

| 레이어 | 구성 요소 | 역할 |
| --- | --- | --- |
| 기준/규칙 | `CLAUDE.md` | 프로젝트 컨벤션, 금지 패턴, 아키텍처 규칙을 Claude가 세션 시작 시 참조 |
| 실행 | Skills (`.claude/skills/*`) / Commands (`.claude/commands/*`) | Skills: API·도메인·영속성·서비스 간 통신 설계 규칙. Commands: `new-api`, `add-error-code`, `deploy-check`, `pr-verify` 등 실행형 작업 |
| 로컬 Harness | `.githooks/pre-commit` · `pre-push` | pre-commit: staged Java 모듈 Checkstyle 검증. pre-push: dev/main 대상 `clean check` 전체 실행. 위반 시 push 차단 |
| Remote Harness (PR 단계) | GitHub Actions `pr-ci` · CodeRabbit | `gradle build`(Checkstyle · ArchUnit · 테스트 · Jacoco) + Sonar Quality Gate. 병합 전 차단 가능 |
| Review-Feedback Loop (병합 후) | `claude-architecture-review` | 병합 커밋 기준 아키텍처 사후 검증 → `.claude/reviews/pr-[N]-review.md` 커밋 + `claude-review` Issue 자동 개시(dedup marker로 중복 방지). 배포는 막지 않음 |
| Compounding Layer | `@claude compound` · `verify-compound.sh` | 해결 기록(`claude-review-docs/solutions`)을 남기고, 재사용 가능한 규칙을 `CLAUDE.md` / `SKILL.md`로 승격해 다음 판단에 반영 |

#### 

### 🧱 Module Structure

```
framey-server
├── framey-common                  # 공통 응답/예외 (ApiResponse, BusinessException, ErrorCode), Checkstyle 규칙
├── framey-web                     # Web/Validation/Swagger, 공통 예외 핸들러
├── framey-monitoring              # Actuator 기반 모니터링 공통 설정
├── framey-application
│   ├── member-service             # 회원 서비스 (독립 실행 Spring Boot 앱, 8081)
│   ├── collage-service            # 콜라주 서비스 (독립 실행 Spring Boot 앱, 8082)
│   └── archive-service            # 아카이브 서비스 (독립 실행 Spring Boot 앱, 8083)
└── framey-infrastructure          # 배포 인프라 (Docker Compose, Nginx, Swagger, systemd, 배포 스크립트)
```

#### 의존 방향

```
member-service  ──┐
collage-service ──┼──▶ framey-web        ──▶ framey-common
archive-service ──┤
                  └──▶ framey-monitoring
```
### CI/CD
| Workflow | Trigger | Description |
|---|---|---|
| CI | PR → dev | Build + Test + Checkstyle + SonarCloud |
| CD (dev)| Push → dev | 변경된 서비스만 Docker Compose 배포 → 헬스체크 → 검증 |

#### Dev 환경 배포 흐름 (선택적 배포)
```
dev push
  └── 변경 파일 분석 (마지막 성공 SHA 기준)
        └── 변경된 서비스만 Build & Deploy (member / collage / archive / swagger / nginx)
              └── Spring Boot 헬스체크 통과 확인
                    └── Nginx 설정 검증 후 reload → HTTPS · OpenAPI 문서 검증
```
> 변경된 서비스만 빌드해 배포하고, 헬스체크와 외부 접속 검증을 통과해야 배포 SHA를 기록합니다. 공통 모듈(`framey-common`, `framey-web`) 변경 시 전체 서비스를 배포합니다.

### 📐 Team Rules
- [Git & Code Convention](https://github.com/Team-Framey/Framey-Server/wiki/Git-Convention-&-Code-Quality)
- [Framey Server AI Tool](https://github.com/Team-Framey/Framey-Server/wiki/Framey-Server-AI-Tool)
