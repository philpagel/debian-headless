FROM debian:trixie

RUN apt-get update && apt-get install -y \
  make wget libarchive-tools syslinux syslinux-utils cpio genisoimage \
  coreutils util-linux \
  && rm -rf /var/lib/apt/lists/*
