#OTEL AGENT
ARG GRAFANA_OPENTELEMETRY_VERSION=2.15.0
FROM us-docker.pkg.dev/grafanalabs-global/docker-grafana-opentelemetry-java-prod/grafana-opentelemetry-java:$GRAFANA_OPENTELEMETRY_VERSION AS agent

# Build stage
FROM eclipse-temurin:17-jdk-jammy AS build
WORKDIR /app
COPY --from=agent /javaagent.jar /app/javaagent.jar
COPY .mvn/ .mvn
COPY mvnw pom.xml ./
RUN ./mvnw dependency:go-offline
COPY src ./src
RUN ./mvnw package -DskipTests

# Run stage
FROM eclipse-temurin:17-jre-jammy

WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
COPY --from=build /app/javaagent.jar /app/javaagent.jar
ENV JAVA_TOOL_OPTIONS="-javaagent:/app/javaagent.jar"
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"] 