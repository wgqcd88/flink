# syntax=docker/dockerfile:1.7
#     Flink 1.x 镜像 (1.19.3 / 1.20.4 / 1.20.5)
#   - WITH_LAKE=1  : 装 Iceberg + Paimon + Hive catalog + Hadoop 补充 jar 
#   - WITH_PYFLINK=1: apt 装 python3 + pip 装 apache-flink==<PYFLINK_VER>
#  docker buildx build --platform linux/amd64,linux/arm64 -t wgqacr.azurecr.io/flink:1.19.3-pyflink-lakes-20260717 --push . -f flink.dockerfile \
#    --build-arg FLINK_VERSION=1.19.3 --build-arg JAVA_VERSION=17 --build-arg WITH_LAKE=1 --build-arg WITH_PYFLINK=1
ARG FLINK_VERSION=1.19.3
ARG JAVA_VERSION=17
FROM eclipse-temurin:${JAVA_VERSION}-jdk AS jdk-builder

FROM flink:${FLINK_VERSION}-scala_2.12-java${JAVA_VERSION} AS pyflink-builder
ARG FLINK_VERSION
ARG TARGETARCH
USER root
COPY --from=jdk-builder /opt/java/openjdk /opt/java/openjdk
RUN set -eux; \
    mkdir -p /opt/pyflink; \
    if [ "$TARGETARCH" = "arm64" ]; then \
      apt-get update; \
      apt-get install -y --no-install-recommends python3 python3-pip python3-dev build-essential; \
      pip3 install --no-cache-dir --target=/opt/pyflink "setuptools<81" "apache-flink==${FLINK_VERSION}"; \
      rm -rf /var/lib/apt/lists/*; \
    fi

FROM flink:${FLINK_VERSION}-scala_2.12-java${JAVA_VERSION}

ARG FLINK_VERSION
ARG TARGETARCH

ARG WITH_LAKE=1
ARG WITH_PYFLINK=1

ARG ICEBERG_VER="1.10.2"        # Flink 1.19：1.6.0、1.6.1、1.7.0、1.7.1、1.7.2、1.8.0、1.8.1、1.9.0、1.9.1、1.9.2、1.10.0、1.10.1、1.10.2
# Flink 1.20：1.7.0、1.7.1、1.7.2、1.8.0、1.8.1、1.9.0、1.9.1、1.9.2、1.10.0、1.10.1、1.10.2、1.11.0
ARG PAIMON_VER="1.4.2"         # Flink 1.19：0.8.0、0.8.1、0.8.2、0.9.0、1.0.0、1.0.1、1.1.0、1.1.1、1.2.0、1.3.1、1.3.2、1.4.1、1.4.2
# Flink 1.20：0.9.0、1.0.0、1.0.1、1.1.0、1.1.1、1.2.0、1.3.1、1.3.2、1.4.1、1.4.2
ARG HADOOP_VER="3.4.2"    # 如 3.4.2 (hdfs-client + mapreduce-client-core)

ARG GH=https://github.com/wgqcd88/flink-azure-fs-hadoop/releases/download/hadoop-3.4.2
ARG MVN=https://repo1.maven.org/maven2

USER root
RUN set -eux; \
    FLINK_MINOR="${FLINK_VERSION%.*}"; \
    cd /opt/flink/lib; \
    dl() { [ -z "$1" ] && return 0; echo ">>> $1"; curl -fSL --retry 3 --retry-delay 2 -O "$1"; }; \
    dl "${FLINK_VERSION:+$GH/flink-azure-fs-hadoop-${FLINK_VERSION}.jar}"; \
    if [ "$WITH_LAKE" = "1" ]; then \
        if [ "${FLINK_VERSION%%.*}" != "2" ]; then \
            dl "${ICEBERG_VER:+$MVN/org/apache/iceberg/iceberg-flink-runtime-${FLINK_MINOR}/${ICEBERG_VER}/iceberg-flink-runtime-${FLINK_MINOR}-${ICEBERG_VER}.jar}"; \
            dl "${FLINK_VERSION:+$MVN/org/apache/flink/flink-sql-connector-hive-3.1.3_2.12/${FLINK_VERSION}/flink-sql-connector-hive-3.1.3_2.12-${FLINK_VERSION}.jar}"; \
            dl "${HADOOP_VER:+$MVN/org/apache/hadoop/hadoop-hdfs-client/${HADOOP_VER}/hadoop-hdfs-client-${HADOOP_VER}.jar}"; \
            dl "${HADOOP_VER:+$MVN/org/apache/hadoop/hadoop-mapreduce-client-core/${HADOOP_VER}/hadoop-mapreduce-client-core-${HADOOP_VER}.jar}"; \
        fi; \
        dl "${PAIMON_VER:+$MVN/org/apache/paimon/paimon-flink-${FLINK_MINOR}/${PAIMON_VER}/paimon-flink-${FLINK_MINOR}-${PAIMON_VER}.jar}"; \
    fi; \
    chmod 644 /opt/flink/lib/*.jar

RUN --mount=type=bind,from=jdk-builder,source=/opt/java/openjdk,target=/jdk,ro \
    --mount=type=bind,from=pyflink-builder,source=/opt/pyflink,target=/pyflink,ro \
    set -eux; \
    if [ "$WITH_PYFLINK" = "1" ]; then \
        apt-get update; \
        if [ "$TARGETARCH" = "arm64" ]; then \
            apt-get install -y --no-install-recommends python3; \
            rm -rf /opt/java/openjdk; \
            mkdir -p /opt/java; \
            cp -a /jdk /opt/java/openjdk; \
            cp -a /pyflink /opt/pyflink; \
            else \
            apt-get install -y --no-install-recommends python3 python3-pip; \
            pip3 install --no-cache-dir "apache-flink==${FLINK_VERSION}"; \
        fi; \
        ln -sf /usr/bin/python3 /usr/bin/python; \
        rm -rf /var/lib/apt/lists/*; \
    fi
ENV PYTHONPATH=/opt/pyflink
USER flink
