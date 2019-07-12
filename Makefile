include config.txt

TMP = tmp
ISOLINUX.CFG.TEMPLATE = isolinux.cfg.template


help:
	@echo
	@echo "Edit config.txt, first."
	@echo "Then use the Makefile."
	@echo
	@echo "Usage:"
	@echo
	@echo "  make install-depends	install all dependencies"
	@echo "  make image             Build the ISO image"
	@echo "  make qemu              Boot ISO image in qemu for testing (optional)"
	@echo "  make usb               Write ISO to USB device"
	@echo "  make FAT               Add a FAT partition ot the USB stick (optiona)"
	@echo "  make clean             Clean up temp files and folders"
	@echo "  make mrproper          make clean + remove the output ISO"
	@echo
	@echo "For details consult the readme.md file"
	@echo


install-depends:
	# install all dependencies
	sudo apt-get install bsdtar syslinux syslinux-utils cpio genisoimage coreutils qemu-system qemu-system-x86 util-linux

image: clean unpack isolinux preseed md5 iso

unpack:
	mkdir ${TMP}
	# Unpack the image to the folder
	bsdtar -C ${TMP} -xf ${SOURCE}
	# Set write permissions
	chmod -R +w ${TMP}

isolinux:
	# Create a minimal isolinux config. no menu, no prompt
	sed "s/ARCH/${ARCH}/" ${ISOLINUX.CFG.TEMPLATE} > ${TMP}/isolinux/isolinux.cfg

preseed:
	# write the preseed file to initrd
	gunzip ${TMP}/install.${ARCH}/initrd.gz
	cp ${PRESEED} ${TMP}/preseed.cfg
	cd ${TMP}; echo preseed.cfg | cpio -H newc -o -A -F install.${ARCH}/initrd
	gzip ${TMP}/install.${ARCH}/initrd
	rm ${TMP}/preseed.cfg

md5:
	# recreate the MD5 sums of all files
	find ${TMP}/ -type f -exec md5sum {} \; > ${TMP}/md5sum.txt

iso:
	# create iso
	genisoimage -V ${LABEL} \
		-r -J -b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		-o ${TARGET} ${TMP}
	# fix MBR for USB boot
	isohybrid ${TARGET}

qemu: ${TARGET}
	@echo
	@echo "\nOnce the installer is in network console you can log in:"
	@echo "    ssh installer@localhost -p10022\n"
	# run qemu with forwarded ssh port
	${QEMU} -m 1024 \
		-net user,hostfwd=tcp::10022-:22 \
		-net nic \
		-cdrom ${TARGET}

usb:
	# write the image to usb stick
	@echo "This will overwrite all data on ${USBDEV}!"
	@read -p "type 'YES' if you really want me to do this:" proceed; \
	if [ $$proceed = "YES" ] ; then \
		sudo dd if=${TARGET} of=${USBDEV} bs=4k ; \
		sync ; \
	else \
		echo "Aborting" ; \
	fi

FAT:
	# add a FAT partition in the remaining free space 
	# e.g. for driver files
	@echo "This will overwrite ${USBDEV}!"
	@read -p "type 'YES' if you really want me to do this:" proceed; \
	if [ $$proceed = "YES" ] ; then \
		echo " , , 0xb" | sudo sfdisk ${USBDEV} -N 2 ;\
		sudo mkfs.vfat ${USBDEV}2 ;\
		sync ;\
	else \
		echo "Aborting" ; \
	fi


clean:
	rm -rf ${TMP}

mrproper: clean
	rm -f ${TARGET}


# EOF
