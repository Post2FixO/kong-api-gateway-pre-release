FROM kong:2.8.1-alpine

LABEL description="Alpine + Kong + kong-oidc plugin"

USER root

RUN apk update \
    && apk add --no-cache curl git gcc musl-dev \
    && luarocks install luaossl OPENSSL_DIR=/usr/local/kong CRYPTO_DIR=/usr/local/kong \
    && luarocks install --pin lua-resty-jwt \
    && luarocks install kong-oidc

USER kong
