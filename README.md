# Debian headless/remote installation

Installing Debian is easy enough – but what if you have no physical access to the 
target machine? Stock images require at least a few keyboard interactions before
you can continue the installation, remotely.

This little tool will remaster a stock Debian image for 100% remote installation
via ssh or serial console.

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

    # Write image to usb stick
    make usb


## Motivation

I wanted to install Debian on a server remotely – i.e. without any keyboard
access or the chance to peek at a temporarily connected screen. I found plenty
of information on the net but none of the tutorials really worked for me. Some
included preseeding the image but failed to automatically start the
installation without a key press, others seemed to customize a zillion things
but ended up getting stuck in some error message or other.  The problem with
ssh remote installation with stock images is that they still require some
initial human interaction to select the desired menu option and some basic
setup before the network is configured. That makes the whole point of remote
installation moot...

So I read my way through lots of tutorials and put together a slim working
solution – at least working for me. So here is my minimal and lazy solution to
Debian headless installation image building.  I mostly documented it for myself
but maybe it's useful for someone out there.

My main intent was to connect to the ssh-server of the Debian installer.
Another possible route for headless installation is via serial console. That
can either be a physical RS-232 cable or a virtual serial port provided by a
remote management module/software such as HPEs iLO or something similar.


## Known problems

I didn't have much luck with booting i386 images via UEFI – neither the stock
Debian images nor the remastered ones. But maybe it's just my particular
machine/BIOS...


## Dependencies

Make sure all necessary tools are installed:

    make install-depends


## Configuration

Edit `Makevars` and set the variables to match your situation. You can use 

    make config

to do so. 

### Image

At the very minimum you need to set the following variables – e.g.:

    RELEASE_NO = 11.2.0
    ARCH = amd64
    USBDEV = /dev/sdc

Please set `RELEASE_NO` for the Debian release you want to install. This is used to 
download the `example-preseed.cfg` file that matches your release and to construct
the correct image filenames. 

`ARCH` indicates the target processor architecture – `amd64` or `i386` (other
architectures like AMD are not supported).  This variable is used to construct
the correct Debian image name, identify the installation folder in the image
(`install.amd`) and download the correct preseeding example file for your
OS version. `LABEL` is the CD volume label and `USBDEV` is the device that
represents your usb stick. The latter is needed for `make usb` and `make FAT`
Be **extra careful** to set `USBDEV` correctly! If you set it incorrectly, you
may overwrite your system disk!  `QEMU` is the name of the qemu-system binary
that matches the target architecture (optional).

### Console parameters

While the main goal of this project was to allow installation via `ssh`, a serial 
console is an alternative in some cases.

The following default config for the serial console device should work most of
the time:

    CONSOLE = ttyS0,115200n8

When the serial console is active, *all output* is redirected to the serial
interface and you will not see boot messages or the installer on a connected
screen after that point. Accordingly, normal local installation will not work.
If you want your image to allow local installations, instead, you may set

    CONSOLE = tty0

## Preseeding

A `minimal-preseed.cfg` file is included. That file configures the bare minimum
to get past the installer questions before the ssh connection becomes
available. To get a full `example-preeed.cfg` file directly from Debian, `make
example-preseed.cfg`. Use any of these files as a template to create a custom
configuration file. This is also the place to configure the login password for
the network installation. For comprehensive information on preseeding, study
this:

<https://www.debian.org/releases/stable/amd64/apb.en.html>

You can override the automatic generation of source/target file names and image
label by setting the respective variables in the config file. 

For installation via serial console, preseeding is not really necessary but
this Makefile expects a preseeding file so you need to supply something.


## Download the Debian installation image

Download a Debian `netinst` installation image:

    make download

If you want to start off an image other than Debian netinst, you can provide it
yourself and set the `SOURCE` variable in the config file (`make config`)
accordingly.


## Building the ISO

    make clean
    make image


## Manual modifications to the image

For experts, only! If you know what you are doing, you can now enter the `tmp`
folder and add packages, edit files etc. You can find some information on what
you can do [here](https://wiki.debian.org/DebianInstaller/Modify/CD). But you
don't need to manually follow the steps for re-creating md5 sums and assembling
the image.

To pack your changes into the image just run

    make image

again.


## Dry run it

This step is optional but may save you a lot of trouble later.

    make qemu-bios
    make qemu-uefi

This will fire up a QEMU session booting your new image.


You can follow the
boot process in the emulator and eventually connect to the installer like this:

    ssh installer@localhost -p22222

Or via serial console:

    telnet localhost 33333

So you can test-drive the installation before trying it on a real server.  The
default password is `r00tme` – please change it in the preseeding file.

And here a little screenshot of what that looks like in qemu. The two bottom
panels show the local screen (left) and the serial console (right):

![](screenshot.png)


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


## Remote Installation via ssh

Insert the USB stick (or CD) in the target system and power it up. Wait a few
minutes for the installer to boot and bring up the network. Find out the IP
address of the machine (e.g. from the router/DHCP server). Alternatively,
configure static IP in the preseed file. Once the system is up you should be
able to ping it. Now log in and complete the installation remotely:

    ssh installer@yourmachine

The default password is `r00tme`; it can (and should!) be configured in the
preseeding file.  Alternatively, set a host key in preseeding for passwordless
login.

NOTE: The included `minimal-preseed.cfg` assumes that you are connected via
ethernet (as a server should be). If you want to/must use a wifi connection you
need to configure this.


## Remote installation via serial console

If the serial interface was configured correctly, you should be able to connect
through a terminal program (`cu`, `minicom`, etc.) via serial interface.  E.g.

    cu -l /dev/ttyUSB0 -s 115200 

or

    screen /dev/ttyUSB0 115200

Where `/dev/ttyUSB0` is the serial interface on your local computer which is
connected to the server.

In the case of a virtual serial interface in iLO (or similar), please refer to
the manufacturers instructions on how to connect to it.


## Random notes

Just because it took me a while to realize: The Debian remote-installer uses
`screen` to provide multiple virtual consoles. You can switch between them with
`CTRL-a TAB`. See `man screen` for more information.

It shouldn't be too hard to adapt this to other distributions such as
Ubuntu. However, I don't feel like doing that – mostly because it will make
things more complex but also because, in my view, Ubuntu is mostly a desktop
distribution and desktops have keyboards and screens, by definition.

