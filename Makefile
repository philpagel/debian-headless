include Makevars

help:
	@echo
	@echo "Usage:"
	@echo
	@echo "  make config                Edit configuration (Makevars)"
	@echo "  make install-depends       Install dependencies"
	@echo "  make download              download latest Debian netinst image"
	@echo "  make example-preseed.cfg   download preseed.cfg from Debian"
	@echo "  make image                 Build the ISO image"
	@echo "  make qemu-bios             Boot ISO image in QEMU (BIOS mode)"
	@echo "  make qemu-uefi             Boot ISO image in QEMU (UEFI boot)"
	@echo "  make usb                   Write ISO to USB device"
	@echo "  make FAT                   Add a FAT partition ot the USB stick"
	@echo "  make clean                 Clean up temporary files and folders"
	@echo "  make maintainer-clean      Make clean and remove the output ISO"
	@echo
	@echo "See README.md for details"
	@echo


.PHONY: install-depends
install-depends:
	sudo apt-get install \
		libarchive-tools syslinux syslinux-utils cpio genisoimage \
		coreutils qemu-system qemu-system-x86 qemu-utils util-linux

example-preseed.cfg:
	wget -N -O $@ https://www.debian.org/releases/$(RELEASE_NAME)/example-preseed.txt


.PHONY: download
.ONESHELL:
download:
	set -e
	TMPFILE=`mktemp -p ./`
	wget -O $$TMPFILE https://www.debian.org/download
	IMGURL=`grep -o -P -e "https://cdimage.debian.org/.*?netinst.iso" $$TMPFILE | head -n1`
	wget -N $$IMGURL
	rm -f $$TMPFILE

.PHONY: config
config:
	edit Makevars

.PHONY: image
image: ${TARGET}

# Create ISO and fix MBR for USB boot.
${TARGET}: ${TMP} \
           ${TMP}/isolinux/isolinux.cfg \
		   ${TMP}/boot/grub/grub.cfg \
           ${TMP}/install.${ARCHFOLDER}/initrd.gz \
           ${TMP}/md5sum.txt \
		   Makevars

	genisoimage -V ${LABEL} \
		-r -J -b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		-eltorito-alt-boot \
		-e ${tmp} boot/grub/efi.img \
		-no-emul-boot \
		-o $@ ${TMP}
	isohybrid --uefi $@

# Unpack the image to the folder and set write permissions.
${TMP}: ${SOURCE}
	mkdir $@
	bsdtar -C $@ -xf $<
	chmod -R +w $@

# Create a minimal isolinux config. no menu, no prompt.
.PHONY: ${TMP}/isolinux/isolinux.cfg
.ONESHELL:
${TMP}/isolinux/isolinux.cfg: ${ISOLINUX_CFG_TEMPLATE}
	sed -e "s/<ARCH>/${ARCHFOLDER}/g" \
		-e "s/<CONSOLE>/console=${CONSOLE}/g" \
		$< > $@

.PHONY: ${TMP}/boot/grub/grub.cfg
${TMP}/boot/grub/grub.cfg: ${GRUB_CFG_TEMPLATE}
	sed -e "s/<ARCH>/${ARCHFOLDER}/g" \
		-e "s/<CONSOLE>/console=${CONSOLE}/g" \
		$< > $@

# Write the preseed file to initrd.
.PHONY: ${TMP}/install.${ARCHFOLDER}/initrd.gz
${TMP}/install.${ARCHFOLDER}/initrd.gz: ${PRESEED}
	gunzip ${TMP}/install.${ARCHFOLDER}/initrd.gz
	echo ${PRESEED} | cpio -H newc -o -A -F ${TMP}/install.${ARCHFOLDER}/initrd
	gzip ${TMP}/install.${ARCHFOLDER}/initrd

# Recreate the MD5 sums of all files.
.PHONY: ${TMP}/md5sum.txt
${TMP}/md5sum.txt: ${TMP} ${TMP}/isolinux/isolinux.cfg ${TMP}/install.${ARCHFOLDER}/initrd.gz
	find ${TMP}/ -type f -exec md5sum {} \; > $@

# boot image in qemu (BIOS mode)
.PHONY: qemu-bios
qemu-bios: ${TARGET} image.qcow
	@echo
	@echo "Once the installer has launched networking you can log in:\n"
	@echo "    ssh installer@localhost -p22222\n"
	@echo "It may take a few minutes for the installer to get to that point.\n"
	@echo "Alternatively connect to the serial console:\n"
	@echo "    telnet localhost 33333\n"
	${QEMU} -m 1024 \
		-net user,hostfwd=tcp::22222-:22 \
		-net nic \
		-hda image.qcow \
		-serial telnet:localhost:33333,server,nowait \
		-cdrom $<

# boot image in qemu (UEFI mode)
.PHONY: qemu-uefi
qemu-uefi: ${TARGET} image.qcow
	@echo
	@echo "Once the installer has launched networking you can log in:\n"
	@echo "    ssh installer@localhost -p22222\n"
	@echo "It may take a few minutes for the installer to get to that point.\n"
	@echo "Alternatively connect to the serial console:\n"
	@echo "    telnet localhost 33333\n"
	${QEMU} -m 1024 \
		-net user,hostfwd=tcp::22222-:22 \
		-bios /usr/share/ovmf/OVMF.fd \
		-net nic \
		-hda image.qcow \
		-serial telnet:localhost:33333,server,nowait \
		-cdrom $<

# Create a virtual disk for QEMU.
image.qcow:
	qemu-img create -f qcow2 $@ 10G

# Write the image to usb stick.
.PHONY: usb
usb:
	@echo "This will overwrite all data on ${USBDEV}!"
	@read -p "Type 'yes' if you really want to do this: " proceed; \
	if [ $$proceed = "yes" ] ; then \
		echo "writing image to ${USBDEV}"; \
		sudo dd if=${TARGET} of=${USBDEV} bs=4k ; \
		sync ; \
	else \
		echo "Aborting" ; \
	fi

# Add a FAT partition in the remaining free space (e.g. for driver files).
.PHONY: FAT
FAT:
	@echo "This will overwrite ${USBDEV}!"
	@read -p "Type 'yes' if you really want to do this: " proceed; \
	if [ $$proceed = "yes" ] ; then \
	echo " , , 0xb" | sudo sfdisk ${USBDEV} -N 3 ;\
		sudo mkfs.vfat ${USBDEV}3 ;\
		sync ;\
	else \
		echo "Aborting" ; \
	fi

.PHONY: clean
clean:
	rm -rf ${TMP}
	rm -f image.qcow
	rm -f example-preseed.cfg

.PHONY: maintainer-clean
maintainer-clean: clean
	rm -f ${TARGET}
