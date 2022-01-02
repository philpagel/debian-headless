# Debian headless/remote installation

I wanted to do a headless (remote) installation for a server – i.e. without any
keyboard access or the chance to peek at a temporarily connected screen. I
found plenty of information on the net but none of the tutorials really worked
for me. Some included preseeding the image but failed to automatically start
the installation without a key press, others seemed to customize a zillion
things but ended up getting stuck in some error message or other.

So I read my way through all of them and put together a slim working solution –
at least working for me. So here is my minimal and lazy solution to Debian
headless installation image building.  I mostly documented it for myself but
maybe it's useful for someone out there.


## In a nutshell

    # Edit the configuration variables
    make config

    # Get a netinst image
    make download

    # Create and adapt preseed.cfg
    cp minimal-preseed.cfg preseed.cfg

    vim preseed.cfg

    # Build image
    make image

    # OPTIONAL: test iso image in qemu
    make qemu-bios
    make qemu-uefi

    # Write image to usb stick
    make usb

    # optional: Add a FAT32 partition on the remaining free space
    make FAT


## Dependencies

Make sure all necessary tools are installed:

    make install-depends


## Configure some things

Edit `Makevars` and set the variables to match your situation. You can use 

    make config

to do so. At the very minimum you need to set the following variables - e.g.:

    RELEASE_NO = 11.2.0
    ARCH = amd64
    USBDEV = /dev/sdc

Please set `RELEASE_NO` for the Debian release you want to install. This is used to 
download the `example-preseed.cfg` file that matches your release and to construct
the correct image filenames. 

`ARCH` indicates the target processor architecture – `amd64` or `i386`.  This
variable is used to construct the correct Debian image name, identify the
installation folder in the image (`install.amd`) and download the correct
preseeding example file for your OS version. `LABEL` is the CD volume label and

`USBDEV` is the device that represents your usb stick. The latter is needed for
`make usb` and `make FAT` Be **extra careful** to set `USBDEV` correctly! If
you set it incorrectly, you may overwrite your system disk!  `QEMU` is the name
of the qemu-system binary that matches the target architecture (optional).

A `minimal-preseed.cfg` file is included. That file configures the bare minimum
to get past the installer questions before the ssh connection becomes
available. To get a full `example-preeed.cfg` file directly from Debian, `make
example-preseed.cfg`. Use any of these files as a template to create a custom
configuration file. This is also the place to configure the login password for
the network installation. For comprehensive information on preseeding, study
this:

<https://www.debian.org/releases/stable/amd64/apb.en.html>

You can override the automatic generation of source/target file names and image label
by setting the respective variables in the config file.

## Download the Debian installation image

Download the Debian installation image (netinst):

    make download

If you want to start off an image other than the latest DEBIAN netinst, you
have to download it yourself and set the `SOURCE` variable in the config file
(`make config`).


## Build the ISO

    make clean
    make image


## Dry run it

This step is optional but may save you a lot of trouble later.  As of writing,
the Debian ovmf package that provides UEFI firmawre for QEMU only supports
`amd64` but not `i386`. So only the first of the follwing comands will work for 
`i386` images:

    make qemu-bios
    make qemu-uefi

This will fire up a QEMU session booting your new image. You can follow the
boot process in the emulator and eventually connect to the installer like this:

    ssh installer@localhost -p22222

So you can test-drive the installation before walking over to the server room.


## Write to usb stick or burn cd

If you still have a cdrom drive, use your favorite ISO burner to write the
image to cd. I can't find my old usb-cd drive and prefer using a usb stick,
anyway:

Insert a USB stick and find out its device file

    lsblk

**Double check**, that `USBDEV` is set correctly in `Makevars`.

**Caution:** The next two steps will write to the device configured in the
`USBDEV`. If you failed to set that correctly, you will overwrite whatever disk
happens to be associated with that device!

Write the image to the stick:

    make usb

Add a FAT partition to the stick:

    make FAT

This may be useful if you need to add custom firmware files or anything else
you would like to use during installation.


## Remote Installation

Insert the USB stick (or CD) in the target system and power it up. Wait for a moment
for the installer to boot and bring up the network. Find out the
IP address of the machine (e.g. from the router/DHCP server). Alternatively,
configure static IP in the preseed file. Once the system is up you should be
able to ping it. Now log in and complete the installation remotely:

    ssh installer@yourmachine

The default password is `r00tme`; it can (and should!) be configured in the
preseeding file.  Alternatively, set a host key in preseeding for passwordless
login.

NOTE: The included `minimal-preseed.cfg` assumes that you are connected via
ethernet (as a server should be). If you want to/must use a wifi connection you
need to configure this.

And just because it took me a while to realize: The Debian remote-installer
uses `screen` to provide multiple virtual consoles. You can switch between them
with `CTRL-a TAB`. See `man screen` for more information.

