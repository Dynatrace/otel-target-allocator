FROM alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6 AS certificates

RUN apk --no-cache add ca-certificates

FROM scratch

USER 65532:65532

WORKDIR /

COPY --from=certificates /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY target-allocator ./target-allocator

ENTRYPOINT ["./target-allocator"]
