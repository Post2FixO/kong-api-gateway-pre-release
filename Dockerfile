FROM kong:2.8.1-alpine

LABEL description="Alpine + Kong + kong-oidc plugin"

USER root  # Switch to the root user for package installations

RUN apk update \  # Update the package repositories
    && apk add --no-cache curl git gcc musl-dev \  # Install necessary dependencies
    && luarocks install luaossl OPENSSL_DIR=/usr/local/kong CRYPTO_DIR=/usr/local/kong \  # Install Lua module for OpenSSL
    && luarocks install --pin lua-resty-jwt \  # Install Lua module for JWT
    && luarocks install kong-oidc  # Install Kong OIDC plugin

USER kong  # Switch back to the kong user for the final image

# The final image will contain Kong and the installed kong-oidc plugin

# luarocks install commands assume necessary dependencies / development tools are available in base kong image. 
    # If you encounter issues during the build process, adding additional package installations before running luarocks install commands might help
