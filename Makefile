
include config.txt

TMP = isofiles
ISOLINUX.CFG = isolinux.cfg


help:
	@echo "Usage:"
	@echo
	@echo "make all        Build the ISO"
	@echo "make usb        Write ISO to USB device"
	@echo "make FAT        Add a FAT partition ot the USB stick"
	@echo "make qemu       Boot ISO in quemu for testing"
	@echo "make clean      Cleanup all temporary files and folders"
	@echo "make mrproper   like make clean but also remove the output ISO"
	@echo
	@echo "For details consult the readme.md file"
	@echo

all: clean unpack isolinux preseed md5 iso

unpack:
	mkdir ${TMP}
	# Unpack the image to the folder
	bsdtar -C ${TMP} -xf ${SOURCE}
	# Set write permissions
	chmod -R +w ${TMP}

isolinux:
	# Create a minimal isolinux config
	# no menu, no prompt
	cp ${ISOLINUX.CFG} ${TMP}/isolinux/ 

preseed:
	# write the preseed file to initrd
	gunzip ${TMP}/install.${ARCH}/initrd.gz
	echo ${PRESEED} | cpio -H newc -o -A -F ${TMP}/install.${ARCH}/initrd
	gzip ${TMP}/install.${ARCH}/initrd

md5:
	# recreate the MD5 sums of all files
	#find ${TMP}/ -follow -type f -exec md5sum {} \; > ${TMP}/md5sum.txt
	find ${TMP}/ -type f -exec md5sum {} \; > ${TMP}/md5sum.txt

iso:
	# create iso
	genisoimage -V ${LABEL} \
		-r -J -b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		-o ${TARGET} ${TMP}
	# fix MBR
	isohybrid ${TARGET}

qemu: ${TARGET}
	@echo "\nOnce the installer is in network console you can log in:"
	@echo "    ssh installer@localhost -p10022\n"
	# run qemu with forwarded ssh port
	${QEMU} -m 1024 \
		-net user,hostfwd=tcp::10022-:22 \
		-net nic \
		-cdrom ${TARGET}

usb:
	# write the image to usb stick
	# this may require root permissions
	dd if=${TARGET} of=${USBDEV} bs=4k
	sync

FAT:
	# add a FAT partition in the remaining free space 
	# e.g. for driver files
	# this may require root permissions
	echo " , , 0xb" | sfdisk ${USBDEV} -N 2


clean:
	rm -rf ${TMP}

mrproper: clean
	rm -f ${TARGET}


# EOF
