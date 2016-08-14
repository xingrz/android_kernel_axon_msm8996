#!/bin/bash
# ZTE msm8996 build script by jcadduono

################### BEFORE STARTING ################
#
# download a working toolchain and extract it somewhere and configure this
# file to point to the toolchain's root directory.
#
# once you've set up the config section how you like it, you can simply run
# ./build.sh [VARIANT]
#
##################### DEVICES ######################
#
# ailsa_ii = ZTE Axon 7 (A2017)
# aviva    = ???

###################### CONFIG ######################

# root directory of ZTE msm8996 git repo (default is this script's location)
RDIR=$(pwd)

[ "$VER" ] ||
# version number
VER=$(cat "$RDIR/VERSION")

# directory containing cross-compile arm64 toolchain
TOOLCHAIN=$HOME/build/toolchain/gcc-linaro-4.9-2016.02-x86_64_aarch64-linux-gnu

# amount of cpu threads to use in kernel make process
THREADS=5

############## SCARY NO-TOUCHY STUFF ###############

ABORT()
{
	[ "$1" ] && echo "Error: $*"
	exit 1
}

export ARCH=arm64
export CROSS_COMPILE=$TOOLCHAIN/bin/aarch64-linux-gnu-

[ -x "${CROSS_COMPILE}gcc" ] ||
ABORT "Unable to find gcc cross-compiler at location: ${CROSS_COMPILE}gcc"

[ "$1" ] && DEVICE=$1
[ "$DEVICE" ] || DEVICE=ailsa_ii
[ "$TARGET" ] || TARGET=zte

DEFCONFIG=${TARGET}_defconfig
DEVICE_DEFCONFIG=device_${DEVICE}

[ -f "$RDIR/arch/$ARCH/configs/${DEFCONFIG}" ] ||
ABORT "Config $DEFCONFIG not found in $ARCH configs!"

[ -f "$RDIR/arch/$ARCH/configs/${DEVICE_DEFCONFIG}" ] ||
ABORT "Device config $DEVICE_DEFCONFIG not found in $ARCH configs!"

export LOCALVERSION="$TARGET-$DEVICE-$VER"
KDIR=$RDIR/build/arch/$ARCH/boot

ABORT()
{
	echo "Error: $*"
	exit 1
}

CLEAN_BUILD()
{
	echo "Cleaning build..."
	cd "$RDIR"
	rm -rf build
}

SETUP_BUILD()
{
	echo "Creating kernel config for $LOCALVERSION..."
	cd "$RDIR"
	mkdir -p build
	make -C "$RDIR" O=build "$DEFCONFIG" \
		DEVICE_DEFCONFIG="$DEVICE_DEFCONFIG" \
		|| ABORT "Failed to set up build"
}

BUILD_KERNEL()
{
	echo "Starting build for $LOCALVERSION..."
	while ! make -C "$RDIR" O=build -j"$THREADS"; do
		read -p "Build failed. Retry? " do_retry
		case $do_retry in
			Y|y) continue ;;
			*) return 1 ;;
		esac
	done
}

STRIP_MODULES()
{
	mkdir "$KDIR/modules"
	cd "$KDIR/modules"
	while IFS= read -r module; do
		echo "=> Stripping: $(basename "$module")"
		"${CROSS_COMPILE}strip" -g "$module"
		mv "$module" ./
	done < <(find "$RDIR/build" -name "*.ko")
}

BUILD_DTB()
{
	echo "Generating dtb.img..."
	cd "$RDIR"
	"$RDIR/dtbgen.sh" "$DEVICE" || ABORT "Failed to generate dtb.img!"
}

CLEAN_BUILD && SETUP_BUILD && BUILD_KERNEL && STRIP_MODULES && BUILD_DTB && echo "Finished building $LOCALVERSION!"
