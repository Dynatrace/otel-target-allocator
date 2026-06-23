FROM alpine:3.23@sha256:fd791d74b68913cbb027c6546007b3f0d3bc45125f797758156952bc2d6daf40 AS certificates

RUN apk --no-cache add ca-certificates

FROM scratch

USER 65532:65532

WORKDIR /

COPY --from=certificates /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY target-allocator ./target-allocator

ENTRYPOINT ["./target-allocator"]
