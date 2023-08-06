include Makevars
.PHONY: help install-depends config download image unpack bootconfig preseed md5 iso qemu-bios qemu-uefi usb FAT clean maintainer-clean

help:
	@echo
	@echo "Usage:"
	@echo
	@echo "  make install-depends       Install dependencies"
	@echo "  make config                Edit configuration (Makevars)"
	@echo "  make download              download *latest* Debian netinst image"
	@echo "  make example-preseed.cfg   download example-preseed.cfg from Debian"
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

install-depends:
	sudo apt-get install \
		libarchive-tools syslinux syslinux-utils cpio genisoimage \
		coreutils qemu-system qemu-system-x86 qemu-utils util-linux

config:
	"$(if $(EDITOR),$(EDITOR),editor)" Makevars

.ONESHELL:
download:
	set -e
	TMPFILE=`mktemp -p ./`
	wget -O $$TMPFILE https://www.debian.org/CD/netinst/
	IMGURL=`grep -o -P -e "https://cdimage.debian.org/debian-cd/current/${ARCH}/iso-cd/debian.*?netinst.iso" $$TMPFILE | head -n1`
	wget -N $$IMGURL
	rm -f $$TMPFILE

example-preseed.cfg:
	wget -N -O $@ https://www.debian.org/releases/stable/example-preseed.txt

image: unpack bootconfig preseed md5sums iso 

unpack:
	# Unpack the image to the folder and set write permissions.
	rm -rf ${TMP}
	mkdir ${TMP}
	bsdtar -C ${TMP} -xf ${SOURCE}
	chmod -R +w ${TMP}

bootconfig: 
	# Create a minimal boot config – no menu, no prompt
	# isolinux (BIOS)
	sed -e "s/<ARCH>/${ARCHFOLDER}/g" \
		-e "s/<CONSOLE>/console=${CONSOLE}/g" \
		${ISOLINUX_CFG_TEMPLATE} > ${TMP}/isolinux/isolinux.cfg
	# grub (UEFI)
	sed -e "s/<ARCH>/${ARCHFOLDER}/g" \
		-e "s/<CONSOLE>/console=${CONSOLE}/g" \
		${GRUB_CFG_TEMPLATE} > ${TMP}/boot/grub/grub.cfg

preseed: preseed.cfg
	# Write the preseed file to initrd.
	gunzip ${TMP}/install.${ARCHFOLDER}/initrd.gz
	echo preseed.cfg | cpio -H newc -o -A -F ${TMP}/install.${ARCHFOLDER}/initrd
	gzip ${TMP}/install.${ARCHFOLDER}/initrd

md5sums:
	# Recreate the MD5 sums of all files.
	find ${TMP}/ -type f -exec md5sum {} \; > ${TMP}/md5sum.txt


iso: ${TMP}
	# Create ISO and fix MBR for USB boot.
	genisoimage -V ${LABEL} \
		-r -J -b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		-eltorito-alt-boot \
		-e ${tmp} boot/grub/efi.img \
		-no-emul-boot \
		-o ${TARGET} ${TMP}
	isohybrid --uefi ${TARGET}

qemu-bios: image.qcow
	# boot image in qemu (BIOS mode)
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
		-cdrom ${TARGET}

qemu-uefi: image.qcow
	# boot image in qemu (UEFI mode)
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
		-cdrom ${TARGET}

image.qcow:
	# Create a virtual disk for QEMU.
	qemu-img create -f qcow2 $@ 10G

usb:
	# Write the image to usb stick.
	@echo "This will overwrite all data on ${USBDEV}!"
	@read -p "Type 'yes' if you really want to do this: " proceed; \
	if [ $$proceed = "yes" ] ; then \
		echo "writing image to ${USBDEV}"; \
		sudo dd if=${TARGET} of=${USBDEV} bs=4k ; \
		sync ; \
	else \
		echo "Aborting" ; \
	fi

FAT:
	# Add a FAT partition in the remaining free space (e.g. for driver files).
	@echo "This will overwrite ${USBDEV}!"
	@read -p "Type 'yes' if you really want to do this: " proceed; \
	if [ $$proceed = "yes" ] ; then \
	echo " , , 0xb" | sudo sfdisk ${USBDEV} -N 3 ;\
		sudo mkfs.vfat ${USBDEV}3 ;\
		sync ;\
	else \
		echo "Aborting" ; \
	fi

clean:
	rm -rf ${TMP}
	rm -f image.qcow

maintainer-clean: clean
	rm -f ${TARGET}
	rm -f example-preseed.cfg

