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
# Render (plan gratuito) da 512 MB: limitamos el heap y usamos un GC liviano.
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70 -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -Xss512k -Duser.timezone=UTC"
# Arranque más rápido al despertar en Render (plan gratuito): el jar se
# desempaqueta y se "entrena" una caché de clases (CDS) que la JVM reutiliza en
# cada arranque. El entrenamiento levanta el contexto de Spring SIN base de
# datos (sin Flyway ni conexión) y se detiene al terminar de crearlo.
RUN java -Djarmode=tools -jar app.jar extract --destination extraido && rm app.jar  && java -XX:ArchiveClassesAtExit=extraido/app.jsa -Dspring.context.exit=onRefresh       -Dspring.flyway.enabled=false       -Dspring.jpa.hibernate.ddl-auto=none       -Dspring.jpa.properties.hibernate.boot.allow_jdbc_metadata_access=false       -Dspring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect       -Dspring.datasource.hikari.initialization-fail-timeout=-1       -Dapp.seguridad.jwt-secreto=solo-para-entrenar-la-cache-de-clases-0123456789       -jar extraido/app.jar  && test -s extraido/app.jsa
USER app
EXPOSE 8080
ENTRYPOINT ["java", "-XX:SharedArchiveFile=extraido/app.jsa", "-jar", "extraido/app.jar"]
