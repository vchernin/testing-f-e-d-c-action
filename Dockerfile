
FROM ghcr.io/vchernin/flatpak-external-data-checker:latest

RUN apt-get update && \
    apt-get install -y parallel && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ADD gh-ls-org /usr/local/bin/gh-ls-org
ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]