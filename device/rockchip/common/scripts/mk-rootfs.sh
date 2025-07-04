#!/bin/bash -e

build_buildroot()
{
	check_config RK_BUILDROOT || false

	IMAGE_DIR="${1:-$RK_OUTDIR/buildroot}"

	BUILDROOT_VERSION=$(grep "export BR2_VERSION := " \
		"$RK_SDK_DIR/buildroot/Makefile" | xargs -n 1 | tail -n 1)

	message "=========================================="
	message "          Start building buildroot($BUILDROOT_VERSION)"
	message "=========================================="

	"$RK_SCRIPTS_DIR/mk-buildroot.sh" $RK_BUILDROOT_CFG "$IMAGE_DIR"

	if [ -r "$RK_LOG_DIR/post-rootfs.log" ]; then
		cat "$RK_LOG_DIR/post-rootfs.log"
	else
		warning "Building without post-rootfs stage!"
	fi

	[ -z "$RK_SECURITY" ] || "$RK_SCRIPTS_DIR/mk-security.sh" system \
		$RK_SECURITY_CHECK_METHOD $IMAGE_DIR/rootfs.$RK_ROOTFS_TYPE

	finish_build build_buildroot $@
}

build_yocto()
{
	check_config RK_YOCTO || false

	IMAGE_DIR="${1:-$RK_OUTDIR/yocto}"

	"$RK_SCRIPTS_DIR/check-yocto.sh"

	cd yocto

	if [ "$RK_YOCTO_CFG_CUSTOM" ]; then
		if [ -r "$RK_CHIP_DIR/$RK_YOCTO_CFG" ]; then
			ln -rsf "$RK_CHIP_DIR/$RK_YOCTO_CFG" \
				build/conf/local.conf
		elif [ -r "build/conf/$RK_YOCTO_CFG" ]; then
			if [ "$RK_YOCTO_CFG" != local.conf ]; then
				rm -f build/conf/local.conf
				ln -sf "$RK_YOCTO_CFG" build/conf/local.conf
			fi
		else
			error "yocto/build/conf/$RK_YOCTO_CFG not exist!"
			return 1
		fi

		message "=========================================="
		message "          Start building for $RK_YOCTO_CFG"
		message "=========================================="
	else
		rm -f build/conf/local.conf
		{
			echo "include include/common.conf"
			echo "include include/debug.conf"
			echo "include include/display.conf"
			echo "include include/multimedia.conf"
			echo "include include/audio.conf"

			if [ "$RK_WIFIBT" ]; then
				echo "include include/wifibt.conf"
			fi

			if [ "$RK_CHIP_HAS_GPU" ]; then
				if [ "$RK_YOCTO_CHROMIUM" ]; then
					echo "include include/browser.conf"
				fi
			elif [ "$RK_YOCTO_DISPLAY_PLATFORM" = wayland ]; then
				echo "PACKAGECONFIG:append:pn-weston-init = \" use-pixman\""
			fi

			echo
			echo "DISPLAY_PLATFORM := \"$RK_YOCTO_DISPLAY_PLATFORM\""

			echo
			echo "MACHINE = \"$RK_YOCTO_MACHINE\""
		} > build/conf/local.conf

		message "=========================================="
		message "          Start building for machine($RK_YOCTO_MACHINE)"
		message "=========================================="
	fi

	if [ "$RK_YOCTO_EXTRA_CFG" ]; then
		message "=========================================="
		message "          With extra config:($RK_YOCTO_EXTRA_CFG)"
		message "=========================================="
	fi

	{
		echo "include include/rksdk.conf"
		echo

		echo "PREFERRED_PROVIDER_virtual/kernel := \"linux-dummy\""
		echo "LINUXLIBCVERSION := \"$RK_KERNEL_VERSION_RAW-custom%\""
		echo "OLDEST_KERNEL := \"$RK_KERNEL_VERSION_RAW\""
		echo "USE_DEPMOD := \"0\""
		case "$RK_CHIP_FAMILY" in
			px30|rk3326|rk3562|rk3566_rk3568|rk3576|rk3588)
				echo "MALI_VERSION := \"g24p0\"" ;;
		esac
	} > build/conf/rksdk_override.conf

	source oe-init-build-env build

	set -x
	LANG=en_US.UTF-8 LANGUAGE=en_US.en LC_ALL=en_US.UTF-8 \
		bitbake core-image-minimal -C rootfs \
		-R conf/rksdk_override.conf \
		${RK_YOCTO_EXTRA_CFG:+-R $RK_CHIP_DIR/$RK_YOCTO_EXTRA_CFG}
	set x

	ln -rsf "$PWD/latest/rootfs.img" "$IMAGE_DIR/rootfs.ext4"

	if [ -r "$RK_LOG_DIR/post-rootfs.log" ]; then
		cat "$RK_LOG_DIR/post-rootfs.log"
	else
		warning "Building without post-rootfs stage!"
	fi

	finish_build build_yocto $@
}

build_debian()
{
	check_config RK_DEBIAN || false

	IMAGE_DIR="${1:-$RK_OUTDIR/debian}"
	ARCH=${RK_DEBIAN_ARCH:-armhf}

	"$RK_SCRIPTS_DIR/check-debian.sh"

	message "=========================================="
	message "          Start building $RK_DEBIAN_VERSION($ARCH)"
	message "=========================================="

	cd debian
	if [ ! -f linaro-$RK_DEBIAN_VERSION-alip-*.tar.gz ]; then
		RELEASE=$RK_DEBIAN_VERSION TARGET=desktop ARCH=$ARCH \
			./mk-base-debian.sh
		ln -sf linaro-$RK_DEBIAN_VERSION-alip-*.tar.gz \
			linaro-$RK_DEBIAN_VERSION-$ARCH.tar.gz
	fi

	DEBIAN_SCRIPT=mk-rootfs-$RK_DEBIAN_VERSION.sh

	if [ "$RK_DEBIAN_MIRROR" ]; then
		notice "Using mirror source $RK_DEBIAN_MIRROR in $DEBIAN_SCRIPT..."
		sed -i "s#\(http://\)[^/]*#\1$RK_DEBIAN_MIRROR#" "$DEBIAN_SCRIPT"
	fi

	VERSION=debug ARCH=$ARCH ./$DEBIAN_SCRIPT
	./mk-image.sh

	if ! [ -r "$RK_LOG_DIR/post-rootfs.log" ]; then
		warning "Building without post-rootfs stage!"
	fi

	ln -rsf "$PWD/linaro-rootfs.img" "$IMAGE_DIR/rootfs.ext4"

	finish_build build_debian $@
}

# Hooks

usage_hook()
{
	usage_oneline "buildroot-config[:<config>]" "modify buildroot defconfig"
	usage_oneline "bconfig[:<config>]" "alias of buildroot-config"
	usage_oneline "buildroot-make[:<arg1>:<arg2>]" "run buildroot make"
	usage_oneline "bmake[:<arg1>:<arg2>]" "alias of buildroot-make"
	usage_oneline "rootfs[:<rootfs type>]" "build default rootfs"
	usage_oneline "buildroot" "build buildroot rootfs"
	usage_oneline "yocto" "build yocto rootfs"
	usage_oneline "debian" "build debian rootfs"
}

clean_hook()
{
	rm -rf yocto/build/tmp yocto/build/*cache
	rm -rf debian/binary

	if check_config RK_BUILDROOT &>/dev/null; then
		rm -rf buildroot/output/$RK_BUILDROOT_CFG
	fi

	if check_config RK_UBUNTU &>/dev/null; then
		if [ -f kernel/zboot.img ]; then
			rm -rf kernel/zboot.img
		fi

		if [ -f u-boot/fit/u-boot.its ]; then
			rm -rf u-boot/fit/u-boot.its
		fi

		if [ -f u-boot/fit/uboot.itb ]; then
			rm -rf u-boot/fit/uboot.itb
		fi
	fi

	rm -rf "$RK_OUTDIR/buildroot"
	rm -rf "$RK_OUTDIR/yocto"
	rm -rf "$RK_OUTDIR/debian"
	rm -rf "$RK_OUTDIR/rootfs"
	rm -rf "$RK_FIRMWARE_DIR/rootfs.img"
}

INIT_CMDS="default buildroot debian yocto"
init_hook()
{
	load_config RK_ROOTFS
	check_config RK_ROOTFS &>/dev/null || return 0

	# Priority: cmdline > custom env
	if [ "$1" != default ]; then
		export RK_ROOTFS_SYSTEM=$1
		notice "Using rootfs system($RK_ROOTFS_SYSTEM) from cmdline"
	elif [ "$RK_ROOTFS_SYSTEM" ]; then
		export RK_ROOTFS_SYSTEM=${RK_ROOTFS_SYSTEM//\"/}
		notice "Using rootfs system($RK_ROOTFS_SYSTEM) from environment"
	else
		return 0
	fi

	ROOTFS_CONFIG="RK_ROOTFS_SYSTEM=\"$RK_ROOTFS_SYSTEM\""
	ROOTFS_UPPER=$(echo $RK_ROOTFS_SYSTEM | tr 'a-z' 'A-Z')
	ROOTFS_CHOICE="RK_ROOTFS_SYSTEM_$ROOTFS_UPPER"
	if ! grep -q "^$ROOTFS_CONFIG$" "$RK_CONFIG"; then
		if ! grep -wq "$ROOTFS_CHOICE" "$RK_CONFIG"; then
			error "$RK_ROOTFS_SYSTEM not supported!"
			return 1
		fi

		sed -i -e "/RK_ROOTFS_SYSTEM/d" "$RK_CONFIG"
		echo "$ROOTFS_CONFIG" >> "$RK_CONFIG"
		echo "$ROOTFS_CHOICE=y" >> "$RK_CONFIG"
		"$RK_SCRIPTS_DIR/mk-config.sh" olddefconfig &>/dev/null
	fi
}

PRE_BUILD_CMDS="buildroot-config bconfig buildroot-make bmake"
pre_build_hook()
{
	check_config RK_ROOTFS || false

	case "$1" in
		buildroot-make | bmake)
			check_config RK_BUILDROOT || false

			shift
			"$RK_SCRIPTS_DIR/mk-buildroot.sh" \
				$RK_BUILDROOT_CFG make $@
			finish_build buildroot-make $@
			;;
		buildroot-config | bconfig)
			BUILDROOT_BOARD="${2:-"$RK_BUILDROOT_CFG"}"

			[ "$BUILDROOT_BOARD" ] || return 0

			TEMP_DIR=$(mktemp -d)
			unset BUILDROOT_OUTPUT_DIR
			make -C "$RK_SDK_DIR/buildroot" O="$TEMP_DIR" \
				"${BUILDROOT_BOARD}_defconfig" menuconfig
			"$RK_SDK_DIR/buildroot/scripts/update_defconfig.sh" \
				"$BUILDROOT_BOARD" "$TEMP_DIR"
			rm -rf "$TEMP_DIR"

			finish_build $@
			;;
	esac
}

BUILD_CMDS="rootfs buildroot debian yocto"
build_hook()
{
	check_config RK_ROOTFS || false

	if [ -z "$1" -o "$1" = rootfs ]; then
		ROOTFS=${RK_ROOTFS_SYSTEM:-buildroot}
	else
		ROOTFS=$1
	fi

	ROOTFS_IMG=rootfs.${RK_ROOTFS_TYPE}
	ROOTFS_DIR="$RK_OUTDIR/$ROOTFS"
	IMAGE_DIR="$ROOTFS_DIR/images"

	message "=========================================="
	message "          Start building rootfs($ROOTFS)"
	message "=========================================="

	case "$ROOTFS" in
		yocto | debian | buildroot ) ;;
		*) usage ;;
	esac

	rm -rf "$ROOTFS_DIR" "$RK_OUTDIR/rootfs"
	mkdir -p "$IMAGE_DIR"
	ln -rsf "$ROOTFS_DIR" "$RK_OUTDIR/rootfs"

	touch "$ROOTFS_DIR/.stamp_build_start"
	case "$ROOTFS" in
		yocto) build_yocto "$IMAGE_DIR" ;;
		debian) build_debian "$IMAGE_DIR" ;;
		buildroot) build_buildroot "$IMAGE_DIR" ;;
	esac
	touch "$ROOTFS_DIR/.stamp_build_finish"

	if [ ! -f "$IMAGE_DIR/$ROOTFS_IMG" ]; then
		error "There's no $ROOTFS_IMG generated..."
		exit 1
	fi

	if [ "$RK_ROOTFS_INITRD" ]; then
		"$RK_SCRIPTS_DIR/mk-ramboot.sh" "$ROOTFS_DIR" \
			"$IMAGE_DIR/$ROOTFS_IMG" "$RK_BOOT_FIT_ITS"
		ln -rsf "$ROOTFS_DIR/ramboot.img" "$RK_FIRMWARE_DIR/boot.img"
	elif [ "$RK_SECURITY_CHECK_SYSTEM_ENCRYPTION" -o \
		"$RK_SECURITY_CHECK_SYSTEM_VERITY" ]; then
		ln -rsf "$IMAGE_DIR/security_system.img" \
			"$RK_FIRMWARE_DIR/rootfs.img"
	else
		ln -rsf "$IMAGE_DIR/$ROOTFS_IMG" "$RK_FIRMWARE_DIR/rootfs.img"
	fi

	finish_build build_rootfs $@
}

source "${RK_BUILD_HELPER:-$(dirname "$(realpath "$0")")/../build-hooks/build-helper}"

case "${1:-rootfs}" in
	buildroot-config | bconfig | buildroot-make | bmake) pre_build_hook $@ ;;
	buildroot | debian | yocto ) init_hook $@ ;&
	*) build_hook $@ ;;
esac
