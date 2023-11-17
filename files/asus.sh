#!/bin/sh
#
# Copyright (C) 2023 remittor
#

. /lib/functions.sh

FI_MAGIC_TRX=$FI_MAGIC_UIMAGE       # uImage header (TRX)

FI_INITRAMFS_MODE=
FI_HW_MODEL=
FI_UBI_DEV=
FI_UBIFS_PART="UBI_DEV"
FI_KERNEL_VOL="linux"
FI_ROOTFS_VOL="rootfs"
FI_KERNEL_SIZE=


fi_get_vol_id_by_name() {
	local vol_name=$1
	/usr/sbin/ubinfo "$FI_UBI_DEV" -N "$vol_name" 2>/dev/null | awk 'NR==1 {print $3}'
}

fi_get_ubi_vol_dev() {
	local vol_name=$1
	local ubivoldir
	local ubidevdir="/sys/class/ubi/"
	if [ -d "$ubidevdir" ]; then
		for ubivoldir in "$ubidevdir"/"$FI_UBI_DEV"_*; do
			if [ -d "$ubivoldir" ]; then
				if [ "$( cat $ubivoldir/name )" = "$vol_name" ]; then
					basename $ubivoldir
					return 0
				fi
			fi
		done
	fi
	return 1
}

fi_platform_do_upgrade() {
	local fit_offset=0
	local kernel_vol_dev
	local skip_size=0

	if ! fi_platform_check_image; then
		fidie "Image file '$FI_IMAGE' is incorrect!"
	fi
	
	if [ "$FI_IMAGE_MAGIC" = "$FI_MAGIC_TRX" ] || [ "$FI_IMAGE_MAGIC" = "$FI_MAGIC_FIT" ]; then
		FI_UBI_DEV=$( nand_find_ubi $FI_UBIFS_PART )
		if [ -z "$FI_UBI_DEV" ]; then
			fidie "cannot detect ubi device for '$FI_UBIFS_PART'"
		fi

		kernel_vol_dev=$( fi_get_ubi_vol_dev "$FI_KERNEL_VOL" )
		if [ -z "$kernel_vol_dev" ]; then
			fidie "cannot found ubi volume with name '$FI_KERNEL_VOL'"
		fi

		ubirmvol /dev/ubi0 -N "$FI_ROOTFS_VOL" 2> /dev/null
		ubirmvol /dev/ubi0 -N rootfs_data      2> /dev/null
		
		if [ "$FI_IMAGE_MAGIC" = "$FI_MAGIC_TRX" ]; then
			# for revert to stock firmware
			ubirmvol /dev/ubi0 -N jffs2
			ubirmvol /dev/ubi0 -N "$FI_KERNEL_VOL"
			ubimkvol /dev/ubi0 -N "$FI_KERNEL_VOL" -s "$FI_KERNEL_SIZE"
		else
			# for install initramfs image
			ubirmvol /dev/ubi0 -N "$FI_KERNEL_VOL"
			ubimkvol /dev/ubi0 -N "$FI_KERNEL_VOL" -s "$FI_IMAGE_SIZE"
		fi

		kernel_vol_dev=$( fi_get_ubi_vol_dev "$FI_KERNEL_VOL" )
		if [ -z "$kernel_vol_dev" ]; then
			fidie "cannot found ubi volume with name '$FI_KERNEL_VOL'"
		fi

		skip_size=0
		if [ "$FI_IMAGE_MAGIC" = "$FI_MAGIC_TRX" ]; then
			skip_size=64
		fi
		
		filog "Flash data to '$FI_KERNEL_VOL' (dev: $kernel_vol_dev)..."
		ubiupdatevol /dev/$kernel_vol_dev --skip=$skip_size "$FI_IMAGE"
		if [ "$( echo -n $? )" -ne 0 ]; then
			fierr "Failed to flash '$FI_KERNEL_VOL'"
			return 1
		fi
		filog "FIT image flashed to '$FI_KERNEL_VOL'"
		filog "Image write successful! Reboot..."
		filog "==================================================="
		sync
		umount -a
		reboot -f
		sleep 5
		exit 0
	fi

	fidie "Incorrect image header"
	return 1
}

fi_check_fw_model() {
	local filename="$1"
	local model_name="$2"
	local xx
	xx=$( grep -c -F "$model_name" "$filename" )
	if [ "$xx" -lt 1 ]; then
		xx=$( grep -c -F "$FI_BOARD" "$filename" )
	fi
	[ "$xx" -lt 1 ] && return 1
	return 0
}

fi_platform_init() {
	FI_UBIFS_PART=$CI_UBIPART
	FI_KERNEL_VOL=$CI_KERNPART
	FI_ROOTFS_VOL=$CI_ROOTPART
	FI_INITRAMFS_MODE=
	[ -z "$FI_IMAGE_SIZE" ] && return 1
	[ "$FI_IMAGE_SIZE" -lt 1000000 ] && return 1
	if [ "$(rootfs_type)" = "tmpfs" ]; then
		FI_INITRAMFS_MODE=1
	fi
	return 0
}

fi_platform_check_image() {
	local image
	local err
	local xx
	
	if ! fi_platform_init; then
		fierr "Image file '$FI_IMAGE' is incorrect!"
		return 1
	fi
	if [ -z "$FI_IMAGE_SIZE" ]; then
		fierr "File '$FI_IMAGE' not found!"
		return 1
	fi
	if [ "$FI_IMAGE_SIZE" -lt 1000000 ]; then
		fierr "File '$FI_IMAGE' is incorrect"
		return 1
	fi
	image=$FI_IMAGE
	if [ "$FI_IMAGE_MAGIC" = "$FI_MAGIC_TRX" ]; then
		image="$FI_IMAGE.hdr"
		dd if="$FI_IMAGE" bs=64 count=1 of="$image" 2>/dev/null
	fi
	fi_check_fw_model "$image" "$FI_HW_MODEL" || {
		fierr "Incorrect image! Model not found!"
		return 1
	}

	if [ "$FI_IMAGE_MAGIC" = "$FI_MAGIC_FIT" ]; then
		xx=$( grep -c -F "initrd-1" "$FI_IMAGE" )
		if [ "$xx" != "0" ]; then
			fierr "Incorrect fit image! Found 'initrd-1' part!"
			return 1
		fi
		xx=$( grep -c -F "rootfs-1" "$FI_IMAGE" )
		if [ "$xx" != "0" ]; then
			fierr "Incorrect fit image! Found 'rootfs-1' part!"
			return 1
		fi
		FI_LOGMODE=2
		filog "Detect FIT initramfs image"
		return 0
	fi

	if [ "$FI_IMAGE_MAGIC" = "$FI_MAGIC_TRX" ]; then
		xx=$( fi_get_hexdump_at 64 4 )
		if [ "$xx" != "$FI_MAGIC_FIT" ]; then
			fierr "Incorrect stock firmware! FIT image not found!"
			return 1
		fi
		#if [ "$FI_INITRAMFS_MODE" != "1" ]; then
		#	fierr "TRX images can only be flashed in InitRamFs mode!"
		#	return 1
		#fi
		xx=$( grep -c -F "rootfs-1" "$FI_IMAGE" )
		if [ "$xx" == "0" ]; then
			fierr "Incorrect TRX image! Part 'rootfs-1' not found!"
			return 1
		fi
		if [ "$FI_STAGE" != "2" ]; then 
			err=$( fi_check_uimage_crc $FI_IMAGE 0 )
			if [ -n "$err" ]; then
				fierr "$err"
				return 1
			fi
		fi
		FI_LOGMODE=2
		filog "Detect TRX stock image"
		return 0
	fi

	fierr "Incorrect image header"
	return 1
}
