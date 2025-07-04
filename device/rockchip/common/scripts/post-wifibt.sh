#!/bin/bash -e

POST_ROOTFS_ONLY=1

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/../post-hooks/post-helper}"

build_wifibt()
{
	check_config RK_KERNEL RK_WIFIBT RK_WIFIBT_MODULES || return 0
	source "$RK_SCRIPTS_DIR/kernel-helper"

	message "=========================================="
	message "          Start building wifi/BT ($RK_WIFIBT_MODULES)"
	message "=========================================="

	RKWIFIBT_DIR="$RK_SDK_DIR/external/rkwifibt"

	echo -e "\e[36m"
	if find "$RKWIFIBT_DIR"/* -not -user $RK_OWNER_UID | grep ""; then
		error "Found files owned by other users!"
		error "$RKWIFIBT_DIR is dirty for building!"
		error "Please clear it:"
		error "cd $RKWIFIBT_DIR"
		error "git add -f ."
		error "sudo git reset --hard"
		error "sudo chown -h -R $RK_OWNER:$RK_OWNER $RKWIFIBT_DIR/"
		exit 1
	fi
	echo -e "\e[0m"

	# Make sure that the kernel is ready
	if [ ! -r kernel/include/generated/asm-offsets.h ]; then
		notice "Kernel is not ready, building it for wifi/BT..."
		"$RK_SCRIPTS_DIR/mk-kernel.sh"
	fi

	# Check kernel config
	WIFI_USB=`grep "CONFIG_USB=y" kernel/.config` || true
	WIFI_SDIO=`grep "CONFIG_MMC=y" kernel/.config` || true
	WIFI_PCIE=`grep "CONFIG_PCIE_DW_ROCKCHIP=y" kernel/.config` || true
	WIFI_RFKILL=`grep "CONFIG_RFKILL=y" kernel/.config` || true
	if [ -z "WIFI_SDIO" ]; then
		echo "=== WARNNING CONFIG_MMC not set !!! ==="
	fi
	if [ -z "WIFI_RFKILL" ]; then
		echo "=== WARNNING CONFIG_USB not set !!! ==="
	fi
	if [[ "$RK_WIFIBT_MODULES" =~ "U" ]];then
		if [ -z "$WIFI_USB" ]; then
			echo "=== WARNNING CONFIG_USB not set so ABORT!!! ==="
			exit 0
		fi
	fi
	echo "kernel config: $WIFI_USB $WIFI_SDIO $WIFI_RFKILL"

	if [[ "$RK_WIFIBT_MODULES" =~ "ALL_AP" ]];then
		echo "building bcmdhd sdio"
		$KMAKE M=$RKWIFIBT_DIR/drivers/bcmdhd CONFIG_BCMDHD=m \
			CONFIG_BCMDHD_SDIO=y CONFIG_BCMDHD_PCIE=
		if [ -n "$WIFI_PCIE" ]; then
			echo "building bcmdhd pcie"
			$KMAKE M=$RKWIFIBT_DIR/drivers/bcmdhd CONFIG_BCMDHD=m \
				CONFIG_BCMDHD_PCIE=y CONFIG_BCMDHD_SDIO=
		fi

		if ! [[ "$RK_KERNEL_VERSION_RAW" = "6.1" ]];then
			if [ -n "$WIFI_USB" ]; then
				echo "building rtl8188fu usb"
				$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8188fu modules
			fi
			echo "building rtl8189fs sdio"
			$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8189fs modules
			echo "building rtl8723ds sdio"
			$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8723ds modules
			echo "building rtl8821cs sdio"
			$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8821cs modules
			echo "building rtl8822cs sdio"
			$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8822cs modules
			echo "building rtl8852bs sdio"
			$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8852bs modules \
			DRV_PATH=$RKWIFIBT_DIR/drivers/rtl8852bs
			if [ -n "$WIFI_PCIE" ]; then
				echo "building rtl8852be pcie"
				$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8852be modules \
					DRV_PATH=$RKWIFIBT_DIR/drivers/rtl8852be
			fi
		fi
	fi

	if [[ "$RK_WIFIBT_MODULES" =~ "ALL_CY" ]];then
		echo "building CYW4354"
		ln -sf chips/CYW4354_Makefile \
			$RKWIFIBT_DIR/drivers/infineon/Makefile
		$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
		echo "building CYW4373"
		ln -sf chips/CYW4373_Makefile \
			$RKWIFIBT_DIR/drivers/infineon/Makefile
		$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
		echo "building CYW43438"
		ln -sf chips/CYW43438_Makefile \
			$RKWIFIBT_DIR/drivers/infineon/Makefile
		$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
		echo "building CYW43455"
		ln -sf chips/CYW43455_Makefile \
			$RKWIFIBT_DIR/drivers/infineon/Makefile
		$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
		echo "building CYW5557X"
		ln -sf chips/CYW5557X_Makefile \
			$RKWIFIBT_DIR/drivers/infineon/Makefile
		$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
		if [ -n "$WIFI_PCIE" ]; then
			echo "building CYW5557X_PCIE"
			ln -sf chips/CYW5557X_PCIE_Makefile \
				$RKWIFIBT_DIR/drivers/infineon/Makefile
			$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
			echo "building CYW54591_PCIE"
			ln -sf chips/CYW54591_PCIE_Makefile \
				$RKWIFIBT_DIR/drivers/infineon/Makefile
			$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
		fi
		echo "building CYW54591"
		ln -sf chips/CYW54591_Makefile \
			$RKWIFIBT_DIR/drivers/infineon/Makefile
		$KMAKE M=$RKWIFIBT_DIR/drivers/infineon

		if ! [[ "$RK_KERNEL_VERSION_RAW" = "6.1" ]];then
			if [ -n "$WIFI_USB" ]; then
				echo "building rtl8188fu usb"
				$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8188fu modules
			fi
			echo "building rtl8189fs sdio"
			$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8189fs modules
			echo "building rtl8723ds sdio"
			$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8723ds modules
			echo "building rtl8821cs sdio"
			$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8821cs modules
			echo "building rtl8822cs sdio"
			$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8822cs modules
			echo "building rtl8852bs sdio"
			$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8852bs modules \
				DRV_PATH=$RKWIFIBT_DIR/drivers/rtl8852bs
			if [ -n "$WIFI_PCIE" ]; then
				echo "building rtl8852be pcie"
				$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8852be modules \
					DRV_PATH=$RKWIFIBT_DIR/drivers/rtl8852be
			fi
		fi
	fi

	if [[ "$RK_WIFIBT_MODULES" =~ "AP6" ]];then
		if [[ "$RK_WIFIBT_MODULES" = "AP6275_PCIE" ]];then
			echo "building bcmdhd pcie driver"
			$KMAKE M=$RKWIFIBT_DIR/drivers/bcmdhd CONFIG_BCMDHD=m \
				CONFIG_BCMDHD_PCIE=y CONFIG_BCMDHD_SDIO=
		else
			echo "building bcmdhd sdio driver"
			$KMAKE M=$RKWIFIBT_DIR/drivers/bcmdhd CONFIG_BCMDHD=m \
				CONFIG_BCMDHD_SDIO=y CONFIG_BCMDHD_PCIE=
		fi
	fi

	if [[ "$RK_WIFIBT_MODULES" = "CYW4354" ]];then
		echo "building CYW4354"
		ln -sf chips/CYW4354_Makefile \
			$RKWIFIBT_DIR/drivers/infineon/Makefile
		$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
	fi

	if [[ "$RK_WIFIBT_MODULES" = "CYW4373" ]];then
		echo "building CYW4373"
		ln -sf chips/CYW4373_Makefile \
			$RKWIFIBT_DIR/drivers/infineon/Makefile
		$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
	fi

	if [[ "$RK_WIFIBT_MODULES" = "RK960" ]];then
		echo "building RK960"
		$KMAKE M=$RKWIFIBT_DIR/drivers/rk960
	fi

	if [[ "$RK_WIFIBT_MODULES" = "CYW43438" ]];then
		echo "building CYW43438"
		ln -sf chips/CYW43438_Makefile \
			$RKWIFIBT_DIR/drivers/infineon/Makefile
		$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
	fi

	if [[ "$RK_WIFIBT_MODULES" = "CYW43455" ]];then
		echo "building CYW43455"
		ln -sf chips/CYW43455_Makefile \
			$RKWIFIBT_DIR/drivers/infineon/Makefile
		$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
	fi

	if [[ "$RK_WIFIBT_MODULES" = "CYW5557X" ]];then
		echo "building CYW5557X"
		ln -sf chips/CYW5557X_Makefile \
			$RKWIFIBT_DIR/drivers/infineon/Makefile
		$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
	fi

	if [[ "$RK_WIFIBT_MODULES" = "CYW5557X_PCIE" ]];then
		echo "building CYW5557X_PCIE"
		ln -sf chips/CYW5557X_PCIE_Makefile \
			$RKWIFIBT_DIR/drivers/infineon/Makefile
		$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
	fi

	if [[ "$RK_WIFIBT_MODULES" = "CYW54591" ]];then
		echo "building CYW54591"
		ln -sf chips/CYW54591_Makefile \
			$RKWIFIBT_DIR/drivers/infineon/Makefile
		$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
	fi

	if [[ "$RK_WIFIBT_MODULES" = "CYW54591_PCIE" ]];then
		echo "building CYW54591_PCIE"
		ln -sf chips/CYW54591_PCIE_Makefile \
			$RKWIFIBT_DIR/drivers/infineon/Makefile
		$KMAKE M=$RKWIFIBT_DIR/drivers/infineon
	fi

	if [[ "$RK_WIFIBT_MODULES" = "RTL8188FU" ]];then
		echo "building rtl8188fu driver"
		$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8188fu modules
	fi

	if [[ "$RK_WIFIBT_MODULES" = "RTL8189FS" ]];then
		echo "building rtl8189fs driver"
		$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8189fs modules
	fi

	if [[ "$RK_WIFIBT_MODULES" = "RTL8723DS" ]];then
		$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8723ds modules
	fi

	if [[ "$RK_WIFIBT_MODULES" = "RTL8821CS" ]];then
		$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8821cs modules
	fi

	if [[ "$RK_WIFIBT_MODULES" = "RTL8822CS" ]];then
		$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8822cs modules
	fi

	if [[ "$RK_WIFIBT_MODULES" = "RTL8852BS" ]];then
		$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8852bs modules
	fi

	if [[ "$RK_WIFIBT_MODULES" = "RTL8852BE" ]];then
		$KMAKE M=$RKWIFIBT_DIR/drivers/rtl8852be modules
	fi

	if [[ "$RK_WIFIBT_MODULES" = "AIC8800DC" ]];then
		$KMAKE M=$RKWIFIBT_DIR/drivers/aic8800/aic_btusb modules
		$KMAKE M=$RKWIFIBT_DIR/drivers/aic8800/aic8800 modules
	fi

	if ! [[ "$RK_KERNEL_VERSION_RAW" = "6.1" ]];then
		echo "building realtek bt drivers"
		$KMAKE M=$RKWIFIBT_DIR/drivers/bluetooth_uart_driver
		if [ -n "$WIFI_USB" ]; then
			$KMAKE M=$RKWIFIBT_DIR/drivers/bluetooth_usb_driver
		fi
	fi

	mkdir -p $TARGET_DIR/etc/ $TARGET_DIR/usr/bin/ \
		$TARGET_DIR/lib/modules/ $TARGET_DIR/lib/firmware/rtlbt/

	echo "create Android style dirs"
	rm -rf "$TARGET_DIR/system"
	rm -rf "$TARGET_DIR/vendor"
	mkdir -p "$TARGET_DIR/system/etc"
	ln -rsf "$TARGET_DIR/lib/firmware" "$TARGET_DIR/system/etc/firmware"
	ln -rsf "$TARGET_DIR/system" "$TARGET_DIR/vendor"

	echo "installing tools and scripts"
	ensure_tools "$TARGET_DIR/usr/bin/brcm_patchram_plus1" \
		"$TARGET_DIR/usr/bin/dhd_priv" \
		"$TARGET_DIR/usr/bin/rtk_hciattach"

	install -m 0655 $RKWIFIBT_DIR/conf/* "$TARGET_DIR/etc/"
	install -m 0755 $RKWIFIBT_DIR/scripts/* "$TARGET_DIR/usr/bin/"
	rm -f "$TARGET_DIR/usr/bin/wifibt-sleep-hook.sh"
	for b in bt-tty wifibt-info wifibt-vendor wifibt-id wifibt-bus \
		wifibt-chip wifibt-module; do
		ln -sf wifibt-util.sh "$TARGET_DIR/usr/bin/$b"
	done

	if [ "$RK_ROOTFS_PREBUILT_TOOLS" ]; then
		echo "installing prebuilt debug tools"
		install -m 0755 $RKWIFIBT_DIR/bin/arm/* "$TARGET_DIR/usr/bin/"
	fi

	if [[ "$RK_WIFIBT_MODULES" = "ALL_CY" ]];then
		echo "copy infineon/realtek firmware/nvram to rootfs"
		cp $RKWIFIBT_DIR/drivers/infineon/*.ko \
			$TARGET_DIR/lib/modules/ || true
		cp $RKWIFIBT_DIR/firmware/infineon/*/* \
			$TARGET_DIR/lib/firmware/ || true

		#reatek
		if ! [[ "$RK_KERNEL_VERSION_RAW" = "6.1" ]];then
			cp $RKWIFIBT_DIR/firmware/realtek/*/* $TARGET_DIR/lib/firmware/
			cp $RKWIFIBT_DIR/firmware/realtek/*/* \
				$TARGET_DIR/lib/firmware/rtlbt/
			cp $RKWIFIBT_DIR/drivers/bluetooth_uart_driver/hci_uart.ko \
				$TARGET_DIR/lib/modules/
			if [ -n "$WIFI_USB" ]; then
				cp $RKWIFIBT_DIR/drivers/bluetooth_usb_driver/rtk_btusb.ko \
					$TARGET_DIR/lib/modules/
			fi
		fi
	fi

	if [[ "$RK_WIFIBT_MODULES" = "ALL_AP" ]];then
		echo "copy ap6xxx firmware/nvram to rootfs"
		cp $RKWIFIBT_DIR/drivers/bcmdhd/*.ko $TARGET_DIR/lib/modules/
		cp $RKWIFIBT_DIR/firmware/broadcom/*/wifi/* \
			$TARGET_DIR/lib/firmware/ || true
		cp $RKWIFIBT_DIR/firmware/broadcom/*/bt/* \
			$TARGET_DIR/lib/firmware/ || true

		#reatek
		if ! [[ "$RK_KERNEL_VERSION_RAW" = "6.1" ]];then
			echo "copy realtek firmware/nvram to rootfs"
			cp $RKWIFIBT_DIR/drivers/rtl*/*.ko $TARGET_DIR/lib/modules/
			cp -rf $RKWIFIBT_DIR/firmware/realtek/*/* $TARGET_DIR/lib/firmware/
			cp -rf $RKWIFIBT_DIR/firmware/realtek/*/* \
				$TARGET_DIR/lib/firmware/rtlbt/
			cp $RKWIFIBT_DIR/drivers/bluetooth_uart_driver/hci_uart.ko \
				$TARGET_DIR/lib/modules/
			if [ -n "$WIFI_USB" ]; then
				cp $RKWIFIBT_DIR/drivers/bluetooth_usb_driver/rtk_btusb.ko \
					$TARGET_DIR/lib/modules/
			fi
		fi
	fi

	if [[ "$RK_WIFIBT_MODULES" =~ "RTL" ]];then
		echo "Copy RTL file to rootfs"
		if [ -d "$RKWIFIBT_DIR/firmware/realtek/$RK_WIFIBT_MODULES" ]; then
			cp $RKWIFIBT_DIR/firmware/realtek/$RK_WIFIBT_MODULES/* \
				$TARGET_DIR/lib/firmware/rtlbt/
			cp $RKWIFIBT_DIR/firmware/realtek/$RK_WIFIBT_MODULES/* \
				$TARGET_DIR/lib/firmware/
		else
			echo "INFO: $RK_WIFIBT_MODULES isn't bluetooth?"
		fi

		WIFI_KO_DIR=$(echo $RK_WIFIBT_MODULES | tr '[A-Z]' '[a-z]')

		cp $RKWIFIBT_DIR/drivers/$WIFI_KO_DIR/*.ko \
			$TARGET_DIR/lib/modules/
	fi

	if [[ "$RK_WIFIBT_MODULES" =~ "RK" ]];then
		echo "Copy Rockchip file to rootfs"
		cp $RKWIFIBT_DIR/firmware/rockchip/$RK_WIFIBT_MODULES/wifi/* \
			$TARGET_DIR/lib/firmware/
		cp $RKWIFIBT_DIR/firmware/rockchip/$RK_WIFIBT_MODULES/bt/* \
			$TARGET_DIR/lib/firmware/
		cp $RKWIFIBT_DIR/drivers/rk960/*.ko \
			$TARGET_DIR/lib/modules/
	fi

	if [[ "$RK_WIFIBT_MODULES" =~ "CYW" ]];then
		echo "Copy CYW file to rootfs"
		cp $RKWIFIBT_DIR/firmware/infineon/$RK_WIFIBT_MODULES/* \
			$TARGET_DIR/lib/firmware/
		cp $RKWIFIBT_DIR/drivers/infineon/*.ko \
			$TARGET_DIR/lib/modules/
	fi

	if [[ "$RK_WIFIBT_MODULES" =~ "AP6" ]];then
		echo "Copy AP file to rootfs"
		cp $RKWIFIBT_DIR/firmware/broadcom/$RK_WIFIBT_MODULES/wifi/* \
			$TARGET_DIR/lib/firmware/
		cp $RKWIFIBT_DIR/firmware/broadcom/$RK_WIFIBT_MODULES/bt/* \
			$TARGET_DIR/lib/firmware/
		cp $RKWIFIBT_DIR/drivers/bcmdhd/*.ko $TARGET_DIR/lib/modules/
	fi

	if [[ "$RK_WIFIBT_MODULES" =~ "AIC" ]];then
		echo "Copy AIC file to rootfs"
		cp $RKWIFIBT_DIR/drivers/aic8800/aic_btusb/*.ko $TARGET_DIR/lib/modules/
		cp $RKWIFIBT_DIR/drivers/aic8800/aic8800/aic_load_fw/*.ko $TARGET_DIR/lib/modules/
		cp $RKWIFIBT_DIR/drivers/aic8800/aic8800/aic8800_fdrv/*.ko $TARGET_DIR/lib/modules/
		cp -r $RKWIFIBT_DIR/firmware/aicsemi/aic* \
			$TARGET_DIR/lib/firmware/
	fi

	# Install boot services
	install_sysv_service $RKWIFIBT_DIR/S36wifibt-init.sh S
	install_busybox_service $RKWIFIBT_DIR/S36wifibt-init.sh
	install_systemd_service $RKWIFIBT_DIR/wifibt-init.service

	# Install suspend hook
	for hook_dir in /usr/lib/pm-utils/sleep.d /lib/systemd/system-sleep; do
		[ -d "$TARGET_DIR/$hook_dir" ] || continue
		install -m 0755 $RKWIFIBT_DIR/scripts/wifibt-sleep-hook.sh \
			"$TARGET_DIR/$hook_dir/03wifibt"
	done

	# Log collection
	mkdir -p "$TARGET_DIR/etc/generate_logs.d"
	echo -e '#!/bin/sh\nwifibt-info > ${1:-/tmp}/wifibt-info.txt' > \
		"$TARGET_DIR/etc/generate_logs.d/80-wifibt.sh"
	chmod 755 "$TARGET_DIR/etc/generate_logs.d/80-wifibt.sh"
}

message "Building Wifi/BT module and firmwares..."
cd "$RK_SDK_DIR"
build_wifibt
