#!/bin/sh
#
# Copyright (C) 2023 remittor
#

FI_UBIPART=
FI_KERNPART=
FI_ROOTPART=
FI_KERN_UBIPART=
FI_ROOT_UBIPART=

fi_init_board() {
	local mtdidx
	
	FI_SCRIPT=
	
	case "$FI_BOARD" in
	asus,rt-ax52|\
	asus,rt-ax57m|\
	asus,rt-ax59u|\
	asus,rt-ax89x|\
	asus,tuf-ax4200|\
	asus,tuf-ax6000|\
	asus,zenwifi-bt8)
		FI_SCRIPT="asus.sh"
		;;
	xiaomi,mi-router-3-pro|\
	xiaomi,mi-router-3g|\
	xiaomi,mi-router-4|\
	xiaomi,mi-router-ac2100|\
	xiaomi,redmi-router-ac2100|\
	xiaomi,mi-router-hd|\
	xiaomi,r3d|\
	xiaomi,redmi-router-ax6s|\
	xiaomi,mi-router-wr30u|\
	xiaomi,mi-router-wr30u-stock|\
	xiaomi,mi-router-ax3000t|\
	xiaomi,mi-router-ax3000t-stock|\
	xiaomi,redmi-router-ax6000|\
	xiaomi,redmi-router-ax6000-stock)
		FI_SCRIPT="xiaomi.sh"
		;;
	*)
		# board not supported
		return 1
		;;
	esac

	. $FI_PROGDIR/$FI_SCRIPT
	
	case "$FI_BOARD" in
	asus,rt-ax52|\
	asus,rt-ax57m|\
	asus,rt-ax59u|\
	asus,tuf-ax4200|\
	asus,tuf-ax6000|\
	asus,zenwifi-bt8)
		FI_UBIPART="UBI_DEV"
		FI_KERNPART="linux"
		FI_ROOTPART="rootfs"
		;;
	asus,rt-ax89x)
		FI_UBIPART="UBI_DEV"
		FI_KERNPART="linux"
		FI_ROOTPART="jffs2"
		;;
	xiaomi,mi-router-3-pro|\
	xiaomi,mi-router-3g|\
	xiaomi,mi-router-4|\
	xiaomi,mi-router-ac2100|\
	xiaomi,redmi-router-ac2100|\
	xiaomi,mi-router-hd|\
	xiaomi,r3d)
		FI_KERNPART="kernel"
		FI_UBIPART="ubi"
		FI_KERNEL2_NAMES="kernel_stock|kernel_dup"
		FI_HOOK_TARSYSUPG="true"
		FI_UIMAGE_SUPPORT="true"
		;;
	xiaomi,redmi-router-ax6s)
		mtdidx=$( find_mtd_index "ubi-loader" )
		if [ -z "$mtdidx" ]; then
			FI_KERNPART="kernel"
			FI_UBIPART="ubi"
		else
			FI_KERNPART="ubi-loader"
			FI_UBIPART="ubi"
		fi
		;;
	xiaomi,mi-router-wr30u|\
	xiaomi,mi-router-wr30u-stock|\
	xiaomi,mi-router-ax3000t|\
	xiaomi,mi-router-ax3000t-stock|\
	xiaomi,redmi-router-ax6000|\
	xiaomi,redmi-router-ax6000-stock)
		FI_KERN_UBIPART="ubi_kernel"
		FI_ROOT_UBIPART="ubi"
		;;
	*)
		;;
	esac

	case "$FI_BOARD" in
	asus,rt-ax52)
		FI_HW_MODEL="RT-AX52"
		FI_KERNEL_SIZE=0x45fe000
		FI_DEL_TRX_HEADER=1
		;;
	asus,rt-ax57m)
		FI_HW_MODEL="RT-AX57M"
		FI_KERNEL_SIZE=0x45fe000
		FI_DEL_TRX_HEADER=1
		;;
	asus,rt-ax59u)
		FI_HW_MODEL="RT-AX59U"
		FI_KERNEL_SIZE=0x45fe000
		FI_DEL_TRX_HEADER=1
		;;
	asus,rt-ax89x)
		FI_HW_MODEL="RT-AX89U"
		FI_KERNEL_SIZE=0x6406000
		;;
	asus,tuf-ax4200)
		FI_HW_MODEL="TUF-AX4200"
		FI_KERNEL_SIZE=0x45fe000
		FI_DEL_TRX_HEADER=1
		;;
	asus,tuf-ax6000)
		FI_HW_MODEL="TUF-AX6000"
		FI_KERNEL_SIZE=0x45fe000
		FI_DEL_TRX_HEADER=1
		;;
	asus,zenwifi-bt8)
		FI_HW_MODEL="BT8"
		FI_KERNEL_SIZE=0x40e8000
		FI_DEL_TRX_HEADER=1
		;;
	xiaomi,mi-router-3-pro)
		FI_HDR_MODEL_ID=10
		FI_ROOTFS_PARTSIZE=0x2800000
		;;
	xiaomi,mi-router-3g)
		FI_HDR_MODEL_ID=13
		FI_ROOTFS_PARTSIZE=0x2000000
		;;
	xiaomi,mi-router-4)
		FI_HDR_MODEL_ID=14
		FI_ROOTFS_PARTSIZE=0x1a00000
		;;
	xiaomi,mi-router-ac2100)
		FI_HDR_MODEL_ID=22
		FI_ROOTFS_PARTSIZE=0x1a00000
		;;
	xiaomi,redmi-router-ac2100)
		FI_HDR_MODEL_ID=23
		FI_ROOTFS_PARTSIZE=0x1a00000
		;;
	xiaomi,mi-router-hd|\
	xiaomi,r3d)
		FI_HDR_MODEL_ID=8
		FI_ROOTFS_PARTSIZE=0x2800000
		;;
	xiaomi,redmi-router-ax6s)
		FI_HDR_MODEL_ID=50,51
		# ubi size: 0x020c0000 - 0x002c0000 = 0x01e00000
		FI_ROOTFS_PARTSIZE=0x1e00000
		FI_RESTORE_NVRAM="fw_setenv boot_fw1 'run boot_rd_img2;bootm'"
		;;
	xiaomi,mi-router-wr30u|\
	xiaomi,mi-router-wr30u-stock)
		FI_HDR_MODEL_ID=72
		FI_RESTORE_NVRAM="fw_setenv boot_fw1 'run boot_rd_img2;bootm'"
		;;
	xiaomi,mi-router-ax3000t|\
	xiaomi,mi-router-ax3000t-stock)
		FI_HDR_MODEL_ID=75,88
		FI_RESTORE_NVRAM="fw_setenv boot_fw1 'run boot_rd_img2;bootm'"
		;;
	xiaomi,redmi-router-ax6000|\
	xiaomi,redmi-router-ax6000-stock)
		FI_HDR_MODEL_ID=61
		FI_RESTORE_NVRAM="fw_setenv boot_fw1 'run boot_rd_img2;bootm'"
		;;
	*)
		;;
	esac
	
	return 0
}


