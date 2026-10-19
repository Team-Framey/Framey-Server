FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY . .
RUN chmod +x ./gradlew
RUN --mount=type=cache,target=/root/.gradle,sharing=locked \
    ./gradlew :framey-application:collage-service:bootJar --no-daemon
# Runtime Stage
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build \
    /app/framey-application/collage-service/build/libs/*.jar \
    app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "app.jar"]
