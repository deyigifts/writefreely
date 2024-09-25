# Modify from https://github.com/jrasanen/writefreely-docker
# Maintainer deyigifts.com

ARG GOLANG_VERSION=1.22
ARG ALPINE_VERSION=3.19

# Build image
FROM golang:${GOLANG_VERSION}-alpine AS build

ARG WRITEFREELY_FORK=deyigifts/writefreely
ARG BUILD_REGION

RUN if [[ "${BUILD_REGION}" == "CN" ]] ; then sed -i \
  's#https\?://dl-cdn.alpinelinux.org/alpine#https://mirrors.tuna.tsinghua.edu.cn/alpine#g' /etc/apk/repositories; fi

RUN apk -U upgrade \
    && apk add --no-cache nodejs npm make g++ sqlite-dev \
    &&  if [[ "${BUILD_REGION}" == "CN" ]] ; then \
        npm config set registry https://mirrors.huaweicloud.com/repository/npm/; fi \
    && npm install -g less less-plugin-clean-css \
    && mkdir -p /go/src/github.com/${WRITEFREELY_FORK}


WORKDIR /go/src/github.com/${WRITEFREELY_FORK}

COPY . .
RUN cat ossl_legacy.cnf > /etc/ssl/openssl.cnf

ENV GO111MODULE=on
ENV NODE_OPTIONS=--openssl-legacy-provider

RUN if [[ "${BUILD_REGION}" == "CN" ]] ; then \
  go env -w GOPROXY=https://goproxy.cn,direct; fi

RUN make deps

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

ARG WRITEFREELY_FORK=deyigifts/writefreely
ARG BUILD_REGION
ENV USER_ID=1000
ENV GROUP_ID=1000

LABEL org.opencontainers.image.source="https://github.com/${WRITEFREELY_FORK}"
LABEL org.opencontainers.image.description="WriteFreely is a clean, minimalist publishing platform made for writers. deyigifts.com maintains a user media upload fork under same license."

RUN addgroup -g ${GROUP_ID} -S wf && \
  adduser -u ${USER_ID} -S -G wf wf

RUN if [[ "${BUILD_REGION}" == "CN" ]] ; then sed -i \
  's#https\?://dl-cdn.alpinelinux.org/alpine#https://mirrors.tuna.tsinghua.edu.cn/alpine#g' /etc/apk/repositories; fi

RUN apk -U upgrade \
    && apk add --no-cache curl

COPY --from=build --chown=wf:wf /stage /writefreely

WORKDIR /writefreely
VOLUME /data
USER wf
EXPOSE 8080

ENTRYPOINT ["/writefreely/scripts/entrypoint.sh"]
HEALTHCHECK --start-period=60s --interval=120s --timeout=15s \
  CMD curl -fSs http://127.0.0.1:8080/ || exit 1
