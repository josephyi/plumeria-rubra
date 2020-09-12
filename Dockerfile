# syntax=docker/dockerfile:experimental
ARG JAVA_VERSION="14"
ARG OPENJDK_JDK_TAG="14-jdk-hotspot-bionic"
ARG OPENJDK_JRE_TAG="14-jre-hotspot-bionic"

FROM adoptopenjdk:${OPENJDK_JDK_TAG} as jdk-base
FROM adoptopenjdk:${OPENJDK_JRE_TAG} as jre-base

FROM jdk-base as gradle
WORKDIR /workspace
COPY gradle ./gradle
COPY gradlew ./gradlew
RUN ./gradlew --no-daemon

FROM gradle as deps
WORKDIR /workspace
COPY build.gradle ./build.gradle
COPY src ./src
RUN --mount=type=cache,target=/root/.gradle ./gradlew dependencies -q --parallel --no-daemon

FROM deps as builder
WORKDIR /workspace
COPY src ./src
RUN ./gradlew bootJar -q --parallel --no-daemon \
    && java -Djarmode=layertools -jar build/libs/app.jar extract --destination build/layers

FROM jre-base
WORKDIR /workspace
RUN useradd -r -s /sbin/nologin appuser && chown appuser:appuser /workspace
COPY --from=builder --chown=appuser:appuser /workspace/build/layers/application ./
COPY --from=builder --chown=appuser:appuser /workspace/build/layers/dependencies ./
COPY --from=builder --chown=appuser:appuser /workspace/build/layers/snapshot-dependencies ./
COPY --from=builder --chown=appuser:appuser /workspace/build/layers/spring-boot-loader ./
USER appuser
ENTRYPOINT [ "java", "org.springframework.boot.loader.JarLauncher"]
