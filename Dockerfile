# Modify from https://github.com/jrasanen/writefreely-docker
# Maintainer deyigifts.com

ARG GOLANG_VERSION=1.22
ARG ALPINE_VERSION=3.19

# Build image
FROM golang:${GOLANG_VERSION}-alpine as build

ENV WRITEFREELY_BRANCH=main
ENV WRITEFREELY_FORK=deyigifts/writefreely
LABEL org.opencontainers.image.source="https://github.com/deyigifts/writefreely"
LABEL org.opencontainers.image.description="WriteFreely is a clean, minimalist publishing platform made for writers. Start a blog, share knowledge within your organization, or build a community around the shared act of writing."

RUN sed -i 's#https\?://dl-cdn.alpinelinux.org/alpine#https://mirrors.tuna.tsinghua.edu.cn/alpine#g' /etc/apk/repositories

RUN apk -U upgrade \
    && apk add --no-cache nodejs npm make g++ sqlite-dev \
    && npm config set registry https://mirrors.huaweicloud.com/repository/npm/ \
    && npm install -g less less-plugin-clean-css \
    && mkdir -p /go/src/github.com/${WRITEFREELY_FORK}


WORKDIR /go/src/github.com/${WRITEFREELY_FORK}

COPY . .
RUN cat ossl_legacy.cnf > /etc/ssl/openssl.cnf

ENV GO111MODULE=on
ENV NODE_OPTIONS=--openssl-legacy-provider

RUN go env -w GOPROXY=https://goproxy.cn,direct

RUN make build && \
    make ui && \
    mkdir /stage && \
    cp -R /go/bin \
    /go/src/github.com/${WRITEFREELY_FORK}/templates \
    /go/src/github.com/${WRITEFREELY_FORK}/static \
    /go/src/github.com/${WRITEFREELY_FORK}/pages \
    /go/src/github.com/${WRITEFREELY_FORK}/keys \
    /go/src/github.com/${WRITEFREELY_FORK}/cmd \
    /go/src/github.com/${WRITEFREELY_FORK}/scripts \
    /stage

# Final image
FROM alpine:${ALPINE_VERSION}

ENV USER_ID=1000
ENV GROUP_ID=1000

RUN addgroup -g ${GROUP_ID} -S wf && \
  adduser -u ${USER_ID} -S -G wf wf

COPY --from=build --chown=wf:wf /stage /writefreely

WORKDIR /writefreely
VOLUME /data
USER wf
EXPOSE 8080

ENTRYPOINT ["/writefreely/scripts/entrypoint.sh"]
HEALTHCHECK --start-period=60s --interval=120s --timeout=15s \
  CMD curl -fSs http://localhost:8080/ || exit 1
