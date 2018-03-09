FROM debian:latest
MAINTAINER "David Patawaran <david.patawaran@gmail.com>"

# set environment variable defaults, override with docker run ... -e VAR=VALUE

ENV ARCHITECTURES all,amd64,arm64
ENV COMPONENT     main
ENV DISTRIBUTION  testing
ENV GNUPGHOME     /.gnupg
ENV GPG_ID        ""
ENV GPG_PASS      ""
ENV REPO_NAME     l4fame

# install necessary packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y pinentry-curses aptly xz-utils nginx gpg && \
    apt-get clean

ADD init_repo.sh /init_repo.sh
ENTRYPOINT ["/init_repo.sh"]
