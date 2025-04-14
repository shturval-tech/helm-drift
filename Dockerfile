# Build the manager binary
FROM golang:1.24.2 as builder

WORKDIR /workspace
COPY . .

# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
# for local build
RUN go env -w GOCACHE=/root/.cache/go-build

RUN --mount=type=cache,target=/go/pkg/mod/
# Build
RUN --mount=type=cache,target=/root/.cache/go-build \
GOPROXY=${BUILDER_GOPROXY} CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GO111MODULE=on go build -a -o helm-drift main.go

# Use distroless as minimal base image to package the manager binary
# Refer to https://github.com/GoogleContainerTools/distroless for more details
FROM alpine:3.21.3
WORKDIR /
RUN apk update && apk add --no-cache bash helm kubectl git
COPY --from=builder /workspace/helm-drift /root/.local/share/helm/plugins/helm-drift/bin/
COPY --from=builder /workspace/plugin.yaml /root/.local/share/helm/plugins/helm-drift/

