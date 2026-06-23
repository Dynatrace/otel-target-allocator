FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b AS certificates

RUN apk --no-cache add ca-certificates

FROM scratch

USER 65532:65532

WORKDIR /

COPY --from=certificates /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY target-allocator ./target-allocator

ENTRYPOINT ["./target-allocator"]
