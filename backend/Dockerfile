# ---- Etapa 1: compilación ----
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /workspace
# Primero solo los archivos de Gradle para aprovechar la caché de dependencias
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle gradle
RUN chmod +x gradlew && ./gradlew dependencies --no-daemon -q > /dev/null
COPY src src
# Las pruebas corren en CI (necesitan Docker); aquí solo se empaqueta.
RUN ./gradlew bootJar --no-daemon -x test -x spotlessCheck

# ---- Etapa 2: ejecución ----
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -S app && adduser -S app -G app
COPY --from=build /workspace/build/libs/*.jar app.jar
USER app
# Render (plan gratuito) da 512 MB: limitamos el heap y usamos un GC liviano.
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70 -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -Xss512k -Duser.timezone=UTC"
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
