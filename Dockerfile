FROM alpine:3.23 AS certificates

RUN apk --no-cache add ca-certificates

FROM scratch

USER 65532:65532

WORKDIR /

COPY --from=certificates /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY target-allocator ./target-allocator

ENTRYPOINT ["./target-allocator"]
