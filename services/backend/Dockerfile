# syntax=docker/dockerfile:1
FROM eclipse-temurin:17-jdk AS build
WORKDIR /src
COPY . .
RUN sed -i 's/\r$//' apps/android/gradlew \
    && chmod +x apps/android/gradlew \
    && ./apps/android/gradlew -p services/backend installDist --no-daemon

FROM gcr.io/distroless/java21-debian12:nonroot
WORKDIR /app
COPY --from=build /src/services/backend/build/install/hopa-backend/ /app/
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-cp", "/app/lib/*", "com.hopa.backend.MainKt"]
