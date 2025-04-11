# Build the manager binary
FROM repo.dso.jet.msk.su/service/base/go:1.22.10 as builder

ARG GIT_PRIVATE=gitlab.jet.su
ARG PRIVATE_REPO_LOGIN
ARG PRIVATE_REPO_TOKEN

WORKDIR /workspace
COPY . .

# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
# for local build
RUN go env -w GOPRIVATE=${GIT_PRIVATE}
RUN echo -e "machine ${GIT_PRIVATE} login ${PRIVATE_REPO_LOGIN} password ${PRIVATE_REPO_TOKEN}" > ~/.netrc

RUN go env -w GOCACHE=/root/.cache/go-build

RUN --mount=type=cache,target=/go/pkg/mod/
# Build
RUN --mount=type=cache,target=/root/.cache/go-build \
GOPROXY=${BUILDER_GOPROXY} GOPRIVATE=gitlab.jet.su CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GO111MODULE=on go build -a -o helm-drift main.go

# Use distroless as minimal base image to package the manager binary
# Refer to https://github.com/GoogleContainerTools/distroless for more details
FROM repo.dso.jet.msk.su/service/alpine:3.21.3
WORKDIR /
RUN apk update && apk add --no-cache bash helm kubectl git
COPY --from=builder /workspace/helm-drift /root/.local/share/helm/plugins/helm-drift/bin/
COPY --from=builder /workspace/plugin.yaml /root/.local/share/helm/plugins/helm-drift/

