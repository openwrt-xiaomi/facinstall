#!/bin/sh
#
# Copyright (C) 2023 remittor
#

fi_init_board() {
	FI_SCRIPT=
	
	case "$FI_BOARD" in
	asus,rt-ax52|\
	asus,rt-ax59u|\
	asus,rt-ax89x|\
	asus,tuf-ax4200|\
	asus,tuf-ax6000)
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
	asus,rt-ax59u|\
	asus,rt-ax89x|\
	asus,tuf-ax4200|\
	asus,tuf-ax6000)
		CI_UBIPART="UBI_DEV"
		CI_KERNPART="linux"
		CI_ROOTPART="rootfs"
		;;
	xiaomi,mi-router-3-pro|\
	xiaomi,mi-router-3g|\
	xiaomi,mi-router-4|\
	xiaomi,mi-router-ac2100|\
	xiaomi,redmi-router-ac2100|\
	xiaomi,mi-router-hd|\
	xiaomi,r3d)
		CI_KERNPART="kernel"
		CI_UBIPART="ubi"
		FI_KERNEL2_NAMES="kernel_stock|kernel_dup"
		FI_HOOK_TARSYSUPG="true"
		FI_UIMAGE_SUPPORT="true"
		;;
	xiaomi,redmi-router-ax6s)
		CI_KERNPART="kernel"
		CI_UBIPART="ubi"
		;;
	xiaomi,mi-router-wr30u|\
	xiaomi,mi-router-wr30u-stock|\
	xiaomi,mi-router-ax3000t|\
	xiaomi,mi-router-ax3000t-stock|\
	xiaomi,redmi-router-ax6000|\
	xiaomi,redmi-router-ax6000-stock)
		CI_KERN_UBIPART="ubi_kernel"
		CI_ROOT_UBIPART="ubi"
		;;
	*)
		;;
	esac

	case "$FI_BOARD" in
	asus,rt-ax52)
		FI_HW_MODEL="RT-AX52"
		FI_KERNEL_SIZE=0x45fe000
		;;
	asus,rt-ax59u)
		FI_HW_MODEL="RT-AX59U"
		FI_KERNEL_SIZE=0x45fe000
		;;
	asus,rt-ax89x)
		FI_HW_MODEL="RT-AX89U"
		FI_KERNEL_SIZE=0x6406000
		;;
	asus,tuf-ax4200)
		FI_HW_MODEL="TUF-AX4200"
		FI_KERNEL_SIZE=0x45fe000
		;;
	asus,tuf-ax6000)
		FI_HW_MODEL="TUF-AX6000"
		FI_KERNEL_SIZE=0x45fe000
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
		FI_HDR_MODEL_ID=75
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


