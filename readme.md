# Debian headless/remote installation

I wanted to do a headless installation for a server – i.e. without any keyboard
access or the chance to peek at a temporarily connected screen. I found plenty
of information on the net but none of the tutorials really worked for me. Some
included preseeding the image but failed to automatically start the
installation without a key press, others seemed to customize a zillion things
but ended up getting stuck in some error message or other.

So I read my way through all of them and put together a slim working solution –
at least working for me. So here is my minimal and lazy solution to debian
headless installation image building.  I mostly documented it for myself but
maybe it's useful for someone out there.

I have tested this with debian 9.5 (aka stretch) on a amd64 machine. I think
this should work with other versions (probably also ubuntu) and architectures
but that is untested. If you have tested this please let me know and/or
contribute code.

## In a nutshell

    # Get a netinst image 
    wget https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/debian-9.5.0-arm64-netinst.iso
    # Edit Makefile (first couple of lines)
    vim Makefile
    # Build image
    make
    # Write image to usb stick
    sudo make usb
    sudo make part


## Download the debian installation image

Download the debian installation image (netinst) and put it in this folder.

https://www.debian.org/distrib/netinst


## Configure some things

Edit the makefile and set SOURCE and TARGET to match your image. e.g.

    SOURCE = debian-9.5.0-amd64-netinst.iso
    TARGET = debian-9.5.0-amd64-netinst-preseed.iso
    ARCH = amd

`ARCH` indicates the target processor architecture – e.g. `arm`, `amd`, ...
This variable is used to construct the correct folder name (`install.amd`) for initrd.

This script comes with a `preseed.cfg` file that contains the bare minimum for
a headless installation. Feel free to modify it to your taste. For
comprehensive information on preseeding study this:
https://www.debian.org/releases/stable/i386/apb.html


## Build the ISO

    make clean
    make

## Dry run it

    make qemu

## Write to usb stick or burn cd

If you still have a cdrom drive, use your favorite ISO burner to write the
image to cd. I can't find my old usb-cd drive and prefer using a usb stick,
anyway:

Insert a USB stick and find out its device file

    lsblk

Write the image to the stick:

    sudo make usb

Add a FAT partition to the stick

    sudo make FAT


