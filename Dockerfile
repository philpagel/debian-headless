FROM debian:bookworm-slim

VOLUME /output

RUN apt-get update \
	&& apt-get install -y \
	libarchive-tools syslinux syslinux-utils cpio genisoimage \
	coreutils qemu-system qemu-system-x86 qemu-utils util-linux \
	make ca-certificates wget vim nano\
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

COPY ./ /app

WORKDIR /app

RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
