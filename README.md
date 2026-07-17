# flink
```
export FLINK_VERSION=1.19.3
docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/wgqcd88/flink:${FLINK_VERSION}-pyflink-lakes-20260717 --push . --provenance=false --sbom=false -f flink.dockerfile  \
  --build-arg FLINK_VERSION=${FLINK_VERSION} --build-arg JAVA_VERSION=17 --build-arg WITH_LAKE=1 --build-arg WITH_PYFLINK=1

```
