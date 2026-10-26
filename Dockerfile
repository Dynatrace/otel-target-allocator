FROM alpine:3.24@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a AS certificates

RUN apk --no-cache add ca-certificates

FROM scratch

USER 65532:65532

WORKDIR /

COPY --from=certificates /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY target-allocator ./target-allocator

ENTRYPOINT ["./target-allocator"]
