# Build the manager binary
FROM golang:1.24.2 AS builder

# Build-time args
ARG BUILDER_GOPROXY
ARG VERSION=dev
ARG ENV=production

WORKDIR /workspace
COPY . .

# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
# for local build
RUN go env -w GOCACHE=/root/.cache/go-build

RUN --mount=type=cache,target=/go/pkg/mod/
# Build
RUN --mount=type=cache,target=/root/.cache/go-build \
    GOPROXY=${BUILDER_GOPROXY} CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GO111MODULE=on go build -a -o helm-drift \
    -ldflags "-X 'github.com/nikhilsbhat/helm-drift/version.Version=${VERSION}' -X 'github.com/nikhilsbhat/helm-drift/version.Env=${ENV}'" \
    main.go

# Use distroless as minimal base image to package the manager binary
# Refer to https://github.com/GoogleContainerTools/distroless for more details
FROM alpine:3.22.1

WORKDIR /

RUN apk add --no-cache bash helm kubectl git ca-certificates jq

COPY --from=builder /workspace/helm-drift /root/.local/share/helm/plugins/helm-drift/bin/
COPY --from=builder /workspace/plugin.yaml /root/.local/share/helm/plugins/helm-drift/
COPY --from=builder /workspace/certs/* /usr/local/share/ca-certificates/

RUN cat /usr/local/share/ca-certificates/* >> /etc/ssl/certs/ca-certificates.crt && \
    apk update && \
    apk upgrade --available && \
    update-ca-certificates


