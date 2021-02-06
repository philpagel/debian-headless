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

I have tested this with Debian 9.5 (aka stretch) on an amd64 machine (Lenovo
Thinkcentre Tiny m600). I think this should work with other versions (probably
also ubuntu) and architectures but that is untested. If you have tested this
please let me know and/or contribute code.

At this point, this does not currently support UEFI boot! So make sure that you
system will use legacy boot, by default.


## In a nutshell

    # Get a netinst image
    wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-10.7.0-amd64-netinst.iso

    # Edit the configuration variables
    vim Makevars

    # Create and edit preseed.cfg
    cp example-preseed.cfg preseed.cfg
    vim preseed.cfg

    # Build image
    make image

    # OPTIONAL: test iso image in qemu
    make qemu

    # Write image to usb stick
    make usb

    # optional: Add a FAT32 partition on the remaining free space
    make FAT


## Dependencies

Make sure all necessary tools are installed:

    make install-depends


## Download the debian installation image

Download the Debian installation image (netinst) and put it in this folder.

https://www.debian.org/distrib/netinst


## Configure some things

Edit the makefile and set some variables to match your situation. e.g.

    SOURCE = debian-10.7.0-amd64-netinst.iso
    TARGET = debian-10.7.0-amd64-netinst-preseed.iso
    ARCH = amd
    QEMU = qemu-system-x86_64
    LABEL = debian-10.7.0-amd64-headless
    USBDEV = /dev/sdc

`ARCH` indicates the target processor architecture – `amd` or `386`
This variable is used to construct the correct folder name (`install.amd`) for
initrd. `LABEL` is the CD volume label and `USBDEV` is the device that
represents your usb stick. The latter is needed for `make usb` and `make FAT`
Be **extra careful** to set `USBDEV` correctly! If you set it incorrectly, you
may overwrite your system disk!  `QEMU` is the name of the qemu-system binary
that matches the target architecture (optional).

An `example-preseed.cfg` file for Debian buster is included. This file can also
be downloaded for other Debian releases (see Makefile). You may use
`example-preseed.cfg` as a template to create a custom configuration file. This
is also the place to configure the login password for the network installation.
For comprehensive information on preseeding study this:

<https://www.debian.org/releases/stable/amd64/apb.en.html>


## Build the ISO

    make clean
    make image


## Dry run it

This step is optional but may save you a lot of trouble later on.

    make qemu

This will fire up a QEMU session booting your new image. You can follow the
boot process in the emulator and eventually connect to the installer like this:

    ssh installer@localhost -p10022

So you can test-drive the installation before walking over to the server room.


## Write to usb stick or burn cd

If you still have a cdrom drive, use your favorite ISO burner to write the
image to cd. I can't find my old usb-cd drive and prefer using a usb stick,
anyway:

Insert a USB stick and find out its device file

    lsblk

Double check, that `USBDEV` ist set correctly in the Makefile.

**Caution:** The next two steps will write to the device configured in the
`USBDEV`. If you failed to set that correctly, you will overwrite whatever disk
happens to be associated with that device!

Write the image to the stick:

    make usb

Add a FAT partition to the stick

    make FAT

This may be useful if you need to add custom firmware files or anything else
you would like to use during installation.


## Installation

At the moment, UEFI boot is not supported so make sure you system uses
legacy boot, by default.

Insert the USB stick (or CD) in the target system and power it up. Find out the
IP address of the machine (e.g. from the router/DHCP server). Alternatively,
configure static IP in the preseed file. Once the system is up you should be
able to ping it. Now log in and complete the installation:

    ssh installer@yourmachine

The default password is `r00tme` and can be configured in the preseeding file.
Alternatively, set a host key in preseeding for passwordless login.

NOTE: The included `example-preseed.cfg` assumes that you are connected via
ethernet (as a server should be). If you want to/must use a wifi connection you
need to configure this.
