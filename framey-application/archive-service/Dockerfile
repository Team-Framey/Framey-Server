FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY . .
RUN chmod +x ./gradlew
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew :framey-application:archive-service:bootJar --no-daemon

# Runtime Stage
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build \
    /app/framey-application/archive-service/build/libs/*.jar \
    app.jar
EXPOSE 8083
ENTRYPOINT ["java", "-jar", "app.jar"]
