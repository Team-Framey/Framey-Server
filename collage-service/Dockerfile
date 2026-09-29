# 빌드 컨텍스트는 레포 루트(docker build -f collage-service/Dockerfile .)를 전제로 한다.
# 새 서비스를 추가할 때는 이 파일을 <새 서비스>/Dockerfile로 복사해서 COPY 경로만 바꾸면 된다.

# 베이스 이미지: JDK가 아닌 JRE만 사용해 이미지 용량을 줄임 (실행만 하면 되므로)
FROM eclipse-temurin:21-jre

# 타임존을 Asia/Seoul로 고정 (로그 타임스탬프 등 시간 기준 통일)
ENV TZ=Asia/Seoul

# tzdata 설치 후 /etc/localtime, /etc/timezone을 TZ 값으로 맞추고 apt 캐시는 정리
RUN apt-get update \
	&& apt-get install -y --no-install-recommends tzdata \
	&& ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
	&& echo $TZ > /etc/timezone \
	&& rm -rf /var/lib/apt/lists/*

# 컨테이너를 root로 실행하지 않기 위한 전용 그룹/사용자 생성
RUN groupadd --system framey && useradd --system --gid framey --no-create-home framey

# 앱 파일을 담을 작업 디렉터리
WORKDIR /app

# GitHub Actions에서 미리 빌드해 둔 bootJar만 복사 (컨테이너 안에서 Gradle 빌드 안 함)
COPY collage-service/build/libs/collage-service.jar app.jar

# 실행 파일 소유권을 non-root 사용자에게 이전
RUN chown framey:framey app.jar

# 이후 프로세스를 non-root 사용자 권한으로 실행
USER framey

# 컨테이너 내부 포트는 항상 8080 고정 (Blue/Green 전환은 호스트 포트 매핑으로 처리)
EXPOSE 8080

# 힙 등 JVM 메모리를 컨테이너 메모리 제한 비율로 자동 산정 (docker run -e 로 덮어쓰기 가능)
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0"

# exec 형식 ENTRYPOINT: 컨테이너가 받는 종료 시그널(SIGTERM)이 JVM에 바로 전달되어 graceful shutdown 가능
ENTRYPOINT ["java", "-jar", "app.jar"]
