FROM registry.redhat.io/ubi9:9.0.0-1576
LABEL maintainer="redis-tester"

WORKDIR /app
# COPY config/app-config.properties ./config/app-config.properties
COPY bin/redis-tester .
CMD ["/app/redis-tester", "--read"]
