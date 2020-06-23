FROM debian:stretch-slim

# Configure users
RUN groupadd -r bitglob && useradd -r -m -g bitglob bitglob

# Add packages
RUN set -ex \
	&& apt-get update \
	&& apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu dnsutils gpg wget \
	&& rm -rf /var/lib/apt/lists/*

# Copy and move
WORKDIR /opt
COPY . .
COPY ./docker-entrypoint.sh /entrypoint.sh

# Required configs
ARG GITHUB_TOKEN=""
ARG GITHUB_USER=""
ARG BITCOIN_VERSION="master"

# Install Bitcoin Global
RUN ./install-node.sh -v $BITCOIN_VERSION -d /bitcoin-global -t /opt
ENV PATH="/opt/bitcoin-global/src:${PATH}"

# Expose
ENV BITGLOB_DATA=/bitcoin-global
VOLUME ["/bitcoin-global"]
EXPOSE 8333 8332 8222 18333 18332 18222

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bitglobd"]