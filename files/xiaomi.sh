#!/bin/sh
#
# Copyright (C) 2023 remittor
#

. /lib/functions.sh

MAGIC_XIAOMI_HDR1="48445231"     # "HDR1" - xiaomi image header
MAGIC_XIAOMI_BLK="beba0000"      # head of block with data

FI_IMG_MODEL=
FI_HDR_MODEL_ID=
FI_FIT_IMG=
FI_UBI_IMG=
FI_KERNEL_PART="kernel"
FI_KERNEL2_PART=""
FI_KERNEL2_NAMES=
FI_ROOTFS_PART="ubi"
FI_ROOTFS_PARTSIZE=

FI_RESTORE_ROOTFS2=
FI_RESTORE_UBIFS2=
FI_RESTORE_NVRAM=


fi_flash_images() {
	local kernel_offset=$1
	local kernel_size=$2
	local rootfs_offset=$3
	local rootfs_size=$4
	local fitubi_offset=0
	local fitubi_size=0
	local err
	local part_skip=0
	local ksize
	local mtd_size
	local kernel_name  rootfs_name

	if [ "$FI_RESTORE_ROOTFS2" = "true" ] && [ "$FI_FIT_IMG" = "true" ]; then
		fitubi_offset="$kernel_offset"
		fitubi_size="$kernel_size"
		kernel_size=$( fi_get_part_size "$FI_KERNEL_PART" )
		rootfs_offset=$(( fitubi_offset + kernel_size ))
		rootfs_size=$(( fitubi_size - kernel_size ))
		rootfs_size=$( fi_get_round_up "$rootfs_size" )
	else
		kernel_size=$( fi_get_round_up "$kernel_size" )
		rootfs_size=$( fi_get_round_up "$rootfs_size" )
	fi

	err=$( fi_check_sizes "$FI_KERNEL_PART" "$kernel_offset" "$kernel_size" )
	[ -n "$err" ] && { fierr "$err"; return 1; }

	if [ -n "$FI_KERNEL2_PART" ]; then
		err=$( fi_check_sizes "$FI_KERNEL2_PART" "$kernel_offset" "$kernel_size" )
		[ -n "$err" ] && { fierr "$err"; return 1; }
	fi

	if [ "$rootfs_size" -gt 0 ]; then
		err=$( fi_check_sizes "$FI_ROOTFS_PART" "$rootfs_offset" "$rootfs_size" )
		[ -n "$err" ] && { fierr "$err"; return 1; }
	fi

	if [ "$FI_RESTORE_ROOTFS2" = "true" ] && [ -n "$FI_ROOTFS_PARTSIZE" ]; then
		part_skip=$( printf "%d" "$FI_ROOTFS_PARTSIZE" )
		if [ "$FI_FIT_IMG" = "true" ]; then
			part_skip=$(( part_skip - kernel_size ))
		fi
		if [ "$part_skip" -lt 1000000 ]; then
			part_skip=0
		fi
	fi

	if [ "$part_skip" -gt 0 ]; then
		if [ "$FI_FIT_IMG" = "true" ]; then
			ksize=$(( part_skip + fitubi_size ))
		else
			ksize=$(( part_skip + rootfs_size ))
		fi
		mtd_size=$( fi_get_part_size "$FI_ROOTFS_PART" )
		if [ "$ksize" -gt "$mtd_size" ]; then
			fierr "double rootfs is greater than partition '$FI_ROOTFS_PART'"
			return 1
		fi
	fi

	kernel_name="Kernel"
	rootfs_name="Rootfs"

	mtd erase "$FI_ROOTFS_PART" || {
		fierr "Failed to erase partition '$FI_ROOTFS_PART'"
		return 1
	}
	if [ "$FI_UBI_IMG" = "true" ]; then
		mtd erase "$FI_KERNEL_PART" || {
			fierr "Failed to erase partition '$FI_KERNEL_PART'"
			return 1
		}
		kernel_name="UbiFs0"
		rootfs_name="UbiFs1"
		rootfs_offset=$kernel_offset
		rootfs_size=$kernel_size
		if [ "$FI_RESTORE_UBIFS2" != "true" ]; then
			rootfs_name=
			rootfs_size=0
		fi
	fi

	if [ "$FI_RESTORE_ROOTFS2" = "true" ] && [ -n "$FI_RESTORE_NVRAM" ]; then
		eval "$FI_RESTORE_NVRAM"
	fi
	if [ "$FI_RESTORE_UBIFS2" = "true" ]; then
		eval "$FI_RESTORE_NVRAM"
	fi

	fi_mtd_write "$FI_KERNEL_PART" "$kernel_offset" "$kernel_size" || {
		fierr "Failed flash data to '$FI_KERNEL_PART' partition"
		return 1
	}
	filog "$kernel_name image flashed to '$FI_KERNEL_PART'"

	if [ -n "$FI_KERNEL2_PART" ]; then
		fi_mtd_write "$FI_KERNEL2_PART" "$kernel_offset" "$kernel_size" || {
			fierr "Failed flash data to '$FI_KERNEL2_PART' partition"
			return 1
		}
		filog "$kernel_name image flashed to '$FI_KERNEL2_PART'"
	fi

	if [ -n "$rootfs_name" ]; then
		fi_mtd_write "$FI_ROOTFS_PART" "$rootfs_offset" "$rootfs_size" || {
			fierr "Failed flash data to '$FI_ROOTFS_PART' partition"
			return 1
		}
		filog "$rootfs_name image flashed to '$FI_ROOTFS_PART'!"
	fi
	
	if [ "$part_skip" -gt 0 ]; then
		if [ "$FI_FIT_IMG" = "true" ]; then
			rootfs_offset=$fitubi_offset
			rootfs_size=$fitubi_size
		fi
		fi_mtd_write "$FI_ROOTFS_PART" "$rootfs_offset" "$rootfs_size" "$part_skip" || {
			fierr "Failed flash data to '$FI_ROOTFS_PART' partition (2)"
			return 1
		}
		filog "$rootfs_name image flashed to '$FI_ROOTFS_PART':$FI_ROOTFS_PARTSIZE"
	fi

	filog "Firmware write successful! Reboot..."
	filog "==================================================="
	sync
	umount -a
	reboot -f
	sleep 5
	exit 0
}

fi_do_factory_upgrade() {
	local err
	local magic
	local kernel_offset  kernel_size
	local rootfs_offset  rootfs_size
	local kernel_mtd

	kernel_mtd=$( find_mtd_index "$FI_KERNEL_PART" )
	if [ -z "$kernel_mtd" ]; then
		fidie "partition '$FI_KERNEL_PART' not found"
	fi
	filog "Forced factory upgrade..."

	kernel_offset=0
	if [ "$FI_UBI_IMG" = "true" ]; then
		kernel_size=$FI_IMAGE_SIZE
	elif [ "$FI_FIT_IMG" = "true" ]; then
		kernel_size=$( fi_get_uint32_at 4 "be" )
	else
		kernel_size=$( fi_get_uint32_at 12 "be" )
		kernel_size=$(( kernel_size + 64 ))
	fi

	if [ "$FI_UBI_IMG" = "true" ]; then
		rootfs_offset=$kernel_offset
		rootfs_size=$kernel_size
		FI_RESTORE_UBIFS2=true
	else
		rootfs_offset=$( fi_get_rootfs_offset "$kernel_size" )
		if [ -z "$rootfs_offset" ]; then
			fidie "can't find ubinized rootfs in the firmware image"
		fi
		rootfs_size=$(( FI_IMAGE_SIZE - rootfs_offset ))
	fi
	#local rootfs_end=$(( rootfs_offset + rootfs_size ))

	FI_RESTORE_ROOTFS2=false
	fi_flash_images "$kernel_offset" "$kernel_size" "$rootfs_offset" "$rootfs_size" || {
		fidie "can't flash factory image"
	}
	filog "================================================="
	exit 0
}

fi_do_revert_stock() {
	local err
	local magic
	local blk  blkpos  blk_magic  offset  file_size
	local kernel_offset
	local kernel_size=0
	local rootfs_offset
	local rootfs_size=0
	local fitubi_offset
	local fitubi_size=0
	local kernel_mtd

	kernel_mtd=$( find_mtd_index "$FI_KERNEL_PART" )
	if [ -z "$kernel_mtd" ]; then
		fierr "partition '$FI_KERNEL_PART' not found"
		return 1
	fi
	filog "Forced revert to stock firmware..."

	for blk in 16 20 24 28 32 36; do
		blkpos=$( fi_get_uint32_at $blk )
		[ -z "$blkpos" ] && continue
		[ "$blkpos" -lt 48 ] && continue
		blk_magic=$( fi_get_hexdump_at "$blkpos" 4 )
		[ "$blk_magic" != "$MAGIC_XIAOMI_BLK" ] && continue
		offset=$(( blkpos + 8 ))
		file_size=$( fi_get_uint32_at "$offset" 4 )
		[ -z "$file_size" ] && continue
		[ "$file_size" -lt 1800000 ] && continue
		offset=$(( blkpos + 48 ))
		magic=$( fi_get_hexdump_at "$offset" 4 )
		if [ "$magic" = $FI_MAGIC_UIMAGE ]; then
			kernel_size=$file_size
			kernel_offset=$offset
		fi
		if [ "$magic" = $FI_MAGIC_UBI ] || [ "$magic" = $FI_MAGIC_HSQS ]; then
			rootfs_size=$file_size
			rootfs_offset=$offset
		fi
		if [ "$magic" = $FI_MAGIC_FIT ]; then
			FI_FIT_IMG="true"
			fitubi_size=$file_size
			fitubi_offset=$offset
		fi
	done
	if [ "$FI_UBI_IMG" = "true" ]; then
		if [ "$rootfs_size" -eq 0 ]; then
			fierr "incorrect stock firmware image (ubifs not found)"
			return 1
		fi
		kernel_offset=$rootfs_offset
		kernel_size=$rootfs_size
		FI_RESTORE_UBIFS2=true
	elif [ "$FI_FIT_IMG" = "true" ]; then
		if [ "$fitubi_size" -eq 0 ]; then
			fidie "incorrect stock firmware FIT image"
		fi
		if [ $(( fitubi_size % FI_PAGESIZE )) = 4 ]; then
			# Remove DEADCODE footer
			fitubi_size=$(( fitubi_size - 4 ))
		fi
		kernel_size=$fitubi_size
		kernel_offset=$fitubi_offset
		rootfs_size=$fitubi_size
		rootfs_offset=$fitubi_offset
		FI_RESTORE_ROOTFS2=true
	else
		if [ "$kernel_size" -eq 0 ]; then
			fierr "incorrect stock firmware image (kernel not found)"
			return 1
		fi
		if [ "$rootfs_size" -eq 0 ]; then
			fierr "incorrect stock firmware image (rootfs not found)"
			return 1
		fi
		if [ $(( rootfs_size % FI_PAGESIZE )) = 4 ]; then
			# Remove DEADCODE footer
			rootfs_size=$(( rootfs_size - 4 ))
		fi
		FI_RESTORE_ROOTFS2=true
	fi
	fi_flash_images "$kernel_offset" "$kernel_size" "$rootfs_offset" "$rootfs_size" || {
		fidie "can't revert to stock firmware"
	}
	filog "================================================="
	exit 0
}

fi_platform_do_upgrade() {
	local kernel_mtd
	local kernel2_mtd
	local rootfs_mtd
	local kernel2_part_list
	local part_name

	if ! fi_platform_check_image; then
		fidie "Image file '$FI_IMAGE' is incorrect!"
	fi

	kernel_mtd=$( find_mtd_index "$FI_KERNEL_PART" )
	if [ -z "$kernel_mtd" ]; then
		fidie "cannot find mtd partition for '$FI_KERNEL_PART'"
	fi
	kernel2_part_list=$( echo "$FI_KERNEL2_NAMES" | sed 's/|/\n/g' )
	for part_name in $kernel2_part_list; do
		kernel2_mtd=$( find_mtd_index "$part_name" )
		if [ -n "$kernel2_mtd" ]; then
			FI_KERNEL2_PART="$part_name"
			filog "Found alt kernel partition '$FI_KERNEL2_PART'"
			break
		fi
	done
	rootfs_mtd=$( find_mtd_index "$FI_ROOTFS_PART" )
	if [ -z "$rootfs_mtd" ]; then
		fidie "cannot find mtd partition for '$FI_ROOTFS_PART'"
	fi

	# Flash factory image (uImage header)
	if [ "$FI_IMAGE_MAGIC" = $FI_MAGIC_UIMAGE ]; then
		FI_ROOTFS_PARTSIZE=
		fi_do_factory_upgrade
		exit $?
	fi

	# Flash factory image (FIT header)
	if [ "$FI_IMAGE_MAGIC" = $FI_MAGIC_FIT ]; then
		FI_FIT_IMG="true"
		FI_ROOTFS_PARTSIZE=		
		fi_do_factory_upgrade
		exit $?
	fi

	# Flash factory/initramfs image (UBI header)
	if [ "$FI_IMAGE_MAGIC" = $FI_MAGIC_UBI ]; then
		FI_UBI_IMG="true"
		FI_ROOTFS_PARTSIZE=		
		fi_do_factory_upgrade
		exit $?
	fi

	# Revert to stock firmware ("HDR1" header)
	if [ "$FI_IMAGE_MAGIC" = $MAGIC_XIAOMI_HDR1 ]; then
		fi_do_revert_stock
		exit $?
	fi

	# Install TAR-sysupgrade image
	if [ "$FI_IMAGE_MAGIC" = $FI_MAGIC_SYSUPG ]; then
		if [ "$FI_HOOK_TARSYSUPG" != "true" ]; then
			# use standard scheme
			return 0
		fi
		filog "Check TAR-image..."
		fi_check_tar $FI_IMAGE || fidie "Incorrect TAR-sysupgrade image!"
		filog "SysUpgrade start..."
		if [ -n "$FI_KERNEL2_PART" ]; then
			tar Oxf "$tar_file" "$board_dir/kernel" | mtd -f write - "$FI_KERNEL2_PART"
			if [ $? != 0 ]; then
				fidie "cannot flash partition '$FI_KERNEL2_PART'"
			fi
			filog "Kernel image flashed to '$FI_KERNEL2_PART'"
		fi
		# use standard scheme
		nand_do_upgrade "$FI_IMAGE"
	fi
	
	fidie "Incorrect image header"
	return 1
}

fi_platform_init() {
	FI_FIT_IMG=
	FI_UBI_IMG=
	FI_KERNEL_PART=$CI_KERNPART
	FI_ROOTFS_PART=$CI_UBIPART
	if [ -n "$CI_KERN_UBIPART" ]; then
		FI_KERNEL_PART=$CI_KERN_UBIPART
		FI_UBI_IMG=true
	fi
	if [ -n "$CI_ROOT_UBIPART" ]; then
		FI_ROOTFS_PART=$CI_ROOT_UBIPART
	fi
	[ -z "$FI_IMAGE_SIZE" ] && return 1
	[ "$FI_IMAGE_SIZE" -lt 1000000 ] && return 1
	FI_IMG_MODEL=$( fi_get_uint8_at 14 )
	return 0
}

fi_platform_check_image() {
	local modelid_list
	local modelid
	local kernel_size
	local rootfs_offset
	local img_crc_orig  img_crc_calc
	local xx
	local err
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

	if [ "$FI_IMAGE_MAGIC" = "$FI_MAGIC_UIMAGE" ]; then
		if [ "$FI_UIMAGE_SUPPORT" != "true" ]; then
			fierr "Legacy uImage not supported"
			return 1
		fi
		if [ "$FI_STAGE" != "2" ]; then 
			err=$( fi_check_uimage_crc $FI_IMAGE 0 )
			if [ -n "$err" ]; then
				fierr "$err"
				return 1
			fi
		fi
		kernel_size=$( fi_get_uint32_at 12 "be" )
		kernel_size=$(( kernel_size + 64 ))
		rootfs_offset=$( fi_get_rootfs_offset "$kernel_size" )
		if [ -z "$rootfs_offset" ]; then
			fierr "Cannot find ubinized rootfs in the firmware image"
			return 1
		fi
		FI_LOGMODE=2
		filog "Detect uImage with ubinized rootfs"
		return 0
	fi

	if [ "$FI_IMAGE_MAGIC" = "$FI_MAGIC_FIT" ]; then
		if [ "$FI_UBI_IMG" = "true" ]; then
			fierr "Device not support flashing FIT images!"
			return 1
		fi
		xx=$( grep -c -F "$FI_BOARD" "$FI_IMAGE" )
		if [ "$xx" -lt 1 ]; then
			fierr "Incorrect FIT-image! Model not found!" 
			return 1
		fi
		FI_LOGMODE=2
		filog "Detect FIT-image"
		return 0
	fi

	if [ "$FI_IMAGE_MAGIC" = "$FI_MAGIC_UBI" ]; then
		if [ "$FI_UBI_IMG" != "true" ]; then
			fierr "UBInized images not supported!"
			return 1
		fi
		xx=$( grep -c -F "$FI_BOARD" "$FI_IMAGE" )
		if [ "$xx" -lt 1 ]; then
			fierr "Incorrect UBI-image! Model not found!" 
			return 1
		fi
		FI_LOGMODE=2
		filog "Detect UBI-image"
		return 0
	fi

	if [ "$FI_IMAGE_MAGIC" = "$MAGIC_XIAOMI_HDR1" ]; then
		err="Incorrect stock firmware! Bad model number!"
		modelid_list=$( echo "$FI_HDR_MODEL_ID" | sed 's/,/\n/g' )
		for modelid in $modelid_list; do
			[ "$FI_IMG_MODEL" = "$modelid" ] && err=""
		done
		if [ -z "$modelid_list" ]; then
			err=""
		fi
		if [ -n "$err" ]; then
			fierr "$err"
			return 1
		fi
		if [ "$FI_STAGE" != "2" ]; then 
			img_crc_orig=$( fi_get_uint32_at 8 )
			img_crc_orig=$( printf '%08x' "$(( img_crc_orig ^ 0xFFFFFFFF ))" )
			img_crc_calc=$( fi_get_file_crc32 "$FI_IMAGE" 12 )
			if [ "$img_crc_orig" != "$img_crc_calc" ]; then
				fierr "HDR1 image has incorrect CRC32 checksum"
				return 1
			fi
		fi
		FI_LOGMODE=2
		filog "Detect HDR1-image"
		return 0
	fi

	fierr "Incorrect image header"
	return 1
}
