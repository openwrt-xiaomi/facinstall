#!/bin/sh
#
# Copyright (C) 2023 remittor
#

. /lib/functions.sh

if [ -z "$FI_DEBUG" ]; then
	export FI_DEBUG=0
	export FI_LOGMODE=0
	export FI_STAGE=
	export FI_SCRIPT=
fi

FI_PROGNAME="facinstall"
FI_PROGDIR="/lib/upgrade/$FI_PROGNAME"
FI_LOGPREF=$FI_PROGNAME

FI_CHECK_ORIG_FN="/usr/libexec/validate_firmware_image"
FI_CHECK_HOOK_FN="$FI_PROGDIR/validate_fw_image.sh"

FI_RAMFS_HOOK_FN="/lib/upgrade/stage2"
FI_RAMFS_HOOK_FLAG=$FI_PROGNAME

FI_FLASH_ORIG_FN="/lib/upgrade/do_stage2"
FI_FLASH_HOOK_FN="$FI_PROGDIR/fi_do_stage2.sh"

FI_FLASH_JAVA_FN="/www/luci-static/resources/view/system/flash.js"
FI_FLASH_JAVA_FLAG=$FI_PROGNAME

FI_PLATFORM=
FI_BOARD=$( board_name )
FI_UIMAGE_SUPPORT=
FI_HOOK_TARSYSUPG=
FI_PAGESIZE=2048
FI_IMAGE=
FI_IMAGE_SIZE=
FI_IMAGE_MAGIC=

FI_MAGIC_SYSUPG="7379737570677261"  # TAR "sysupgrade"
FI_MAGIC_UIMAGE="27051956"          # uImage header
FI_MAGIC_FIT="d00dfeed"             # FIT header
FI_MAGIC_UBI="55424923"             # "UBI#"
FI_MAGIC_UBIFS="31181006"
FI_MAGIC_HSQS="68737173"            # "hsqs"


. $FI_PROGDIR/fi_boards.sh


filog() {
	if [ -e /dev/kmsg -a "$FI_STAGE" != "2" ] ; then
		echo "$FI_LOGPREF: $*" > /dev/kmsg
	else
		logger -t $FI_LOGPREF "$@" &> /dev/null
	fi
	[ "$FI_LOGMODE" = "1" ] && echo "$* " >&1
	[ "$FI_LOGMODE" = "2" ] && echo "$*. " >&2
}
 
fierr() {
	if [ -e /dev/kmsg -a "$FI_STAGE" != "2" ]; then
		echo "$FI_LOGPREF: ERROR: $*" > /dev/kmsg
	else
		logger -t $FI_LOGPREF -p err "$@" &> /dev/null
	fi
	[ "$FI_LOGMODE" = "1" ] && echo "ERROR: $* " >&2
	[ "$FI_LOGMODE" = "2" ] && echo "ERROR: $*. " >&2
}

fidie() {
	FI_LOGMODE=2
	fierr "$@"
	echo "========================================================="
	sleep 1
	exit 1
}

fi_sed_path() {
	local str=$( ( echo $1|sed -r 's/([\$\.\*\/\[\\^])/\\\1/g'|sed 's/[]]/\\]/g' )>&1 )
	echo "$str"
}

fi_set_image() {
	FI_IMAGE=$1
	FI_IMAGE_SIZE=$( wc -c "$FI_IMAGE" 2> /dev/null | awk '{print $1}' )
	FI_IMAGE_MAGIC=
	[ -z "$FI_IMAGE_SIZE" ] && return 1
	[ "$FI_IMAGE_SIZE" -lt 1000000 ] && return 1
	FI_IMAGE_MAGIC=$( fi_get_hexdump_at 0 4 )
	local magic8
	magic8=$( fi_get_hexdump_at 0 8 )
	if [ "$magic8" = $FI_MAGIC_SYSUPG ]; then
		FI_IMAGE_MAGIC="$magic8"
	fi
	return 0
} 

fi_get_uint8_at() {
	local offset=$1
	local filename=$2
	local filesize
	local hex
	if [ -z "$filename" ]; then
		filename=$FI_IMAGE
		filesize=$FI_IMAGE_SIZE
	else
		filesize=$( wc -c "$filename" 2> /dev/null | awk '{print $1}' )
	fi
	[ $(( offset + 1 )) -gt "$filesize" ] && { echo ""; return; }
	hex=$( dd if="$filename" skip="$offset" bs=1 count=1 2>/dev/null \
		| hexdump -v -e '"%02x"' )
	printf "%d" 0x"$hex"
}

fi_get_uint32_at() {
	local offset=$1
	local endianness=$2
	local filename=$3
	local filesize
	local hex
	if [ -z "$filename" ]; then
		filename=$FI_IMAGE
		filesize=$FI_IMAGE_SIZE
	else
		filesize=$( wc -c "$filename" 2> /dev/null | awk '{print $1}' )
	fi
	[ $(( offset + 4 )) -gt "$filesize" ] && { echo ""; return; }
	if [ "$endianness" = "be" ]; then
		hex=$( dd if="$filename" skip="$offset" bs=1 count=4 2>/dev/null \
			| hexdump -v -n 4 -e '1/1 "%02x"' )
	else
		hex=$( dd if="$filename" skip="$offset" bs=1 count=4 2>/dev/null \
			| hexdump -v -e '1/4 "%02x"' )
	fi
	printf "%d" 0x"$hex"
}

fi_get_hexdump_at() {
	local offset=$1
	local size=$2
	local filename=$3
	local filesize
	if [ -z "$filename" ]; then
		filename=$FI_IMAGE
		filesize=$FI_IMAGE_SIZE
	else
		filesize=$( wc -c "$filename" 2> /dev/null | awk '{print $1}' )
	fi
	[ $(( offset + size )) -gt "$filesize" ] && { echo ""; return; }
	dd if="$filename" skip="$offset" bs=1 count="$size" 2>/dev/null \
		| hexdump -v -n "$size" -e '1/1 "%02x"'
}

fi_get_round_up() {
	local value=$1
	local base=$2
	local pad=0
	if [ -z "$base" ]; then
		base=$FI_PAGESIZE
	else
		base=$( printf "%d" "$base" )
	fi
	if [ $(( value % base )) != 0 ]; then
		pad=$(( base - value % base ))
	fi
	echo $(( value + pad ))
}

fi_get_file_crc32() {
	local filename=$1
	local offset=$2
	local length=$3
	local filesize
	local count
	[ -z "$offset" ] && offset=0
	filesize=$( wc -c "$filename" 2> /dev/null | awk '{print $1}' )
	offset=$( printf "%d" "$offset" )
	if [ -z "$length" ]; then
		length=$(( filesize - offset ))
	else
		length=$( printf "%d" "$length" )
	fi
	[ "$length" -gt $(( filesize - offset )) ] && { echo ""; return 1; }
	dd if="$filename" iflag=skip_bytes,count_bytes skip=$offset bs=2048 count=$length 2>/dev/null | \
		gzip -1 -c | tail -c8 | hexdump -v -n4 -e '1/4 "%08x"'
	return 0
}

fi_check_uimage_crc() {
	local filename=$1
	local offset=$2
	local filesize
	local data_size  total_size
	local data_crc_orig  data_crc_calc
	local hdr_crc_orig   hdr_crc_calc
	local imghdrfn
	[ -z "$offset" ] && offset=0
	filesize=$( wc -c "$filename" 2> /dev/null | awk '{print $1}' )
	offset=$( printf "%d" "$offset" )
	data_size=$( fi_get_uint32_at $(( offset + 12 )) "be" "$filename" )
	total_size=$(( 64 + data_size ))
	if [ "$total_size" -gt "$filesize" ]; then
		echo "Incorrect uImage data size";
		return 1;
	fi
	data_crc_orig=$( fi_get_hexdump_at 24 4 "$filename" )
	data_crc_calc=$( fi_get_file_crc32 "$filename" 64 $data_size )
	if [ "$data_crc_orig" != "$data_crc_calc" ]; then
		echo "uImage has incorrect CRC32 checksum"
		return 1
	fi
	imghdrfn="/tmp/$( basename "$filename" ).uimage.hdr"
	rm -f "$imghdrfn"
	dd if="$filename" iflag=skip_bytes skip=$offset bs=4 count=1 2>/dev/null > "$imghdrfn"
	echo -en "\x00\x00\x00\x00" >> "$imghdrfn"
	dd if="$filename" iflag=skip_bytes skip=$(( offset + 8 )) bs=56 count=1 2>/dev/null >> "$imghdrfn"
	hdr_crc_orig=$( fi_get_hexdump_at $(( offset + 4 )) 4 "$filename" )
	hdr_crc_calc=$( fi_get_file_crc32 "$imghdrfn" )
	if [ "$hdr_crc_orig" != "$hdr_crc_calc" ]; then
		echo "uImage header has incorrect CRC32 checksum"
		return 1
	fi
	echo ""
	return 0
}

fi_get_part_size() {
	local part_name=$1
	local part
	local mtd_size_hex
	part=$( cat /proc/mtd | grep "\"$part_name\"" 2>/dev/null )
	if [ -z "$part" ]; then
		mtd_size_hex=0
	else
		mtd_size_hex=$( echo "$part" | awk '{print "0x"$2}' )
	fi
	printf "%d" "$mtd_size_hex"
}

fi_check_sizes() {
	local part_name=$1
	local img_offset=$2
	local img_size=$3
	local mtd_size
	local img_end

	mtd_size=$( fi_get_part_size "$part_name" )
	if [ "$mtd_size" = "0" ]; then
		echo "cannot find mtd partition with name '$part_name'"
		return 1
	fi	
	img_end=$(( img_offset + img_size ))
	if [ $img_end -gt "$FI_IMAGE_SIZE" ]; then
		echo "incorrect image size (part: '$part_name')"
		return 1
	fi
	if [ "$img_size" -gt "$mtd_size" ]; then
		echo "image is greater than partition '$part_name'"
		return 1
	fi
	echo ""
	return 0
}

fi_mtd_write() {
	local part_name=$1
	local img_offset=$2
	local img_size=$3
	local part_skip=$4
	local err
	local count

	img_size=$( fi_get_round_up "$img_size" )
	err=$( fi_check_sizes "$part_name" "$img_offset" "$img_size" )
	if [ -n "$err" ]; then
		fierr "$err"
		return 1
	fi
	count=$(( img_size / FI_PAGESIZE ))
	if [ -n "$part_skip" ]; then
		dd if="$FI_IMAGE" iflag=skip_bytes skip="$img_offset" bs="$FI_PAGESIZE" count="$count" \
			| mtd -f -p "$part_skip" write - "$part_name"
	else
		dd if="$FI_IMAGE" iflag=skip_bytes skip="$img_offset" bs="$FI_PAGESIZE" count="$count" \
			| mtd -f write - "$part_name"
	fi
	if [ "$( echo -n $? )" -ne 0 ]; then
		fierr "Failed to flash '$part_name'"
		return 1
	fi
	return 0
}

fi_check_ubi_header() {
	local offset=$1
	local magic
	local magic_ubi2="55424921"  # "UBI!"

	magic=$( fi_get_hexdump_at "$offset" 4 )
	[ "$magic" != $FI_MAGIC_UBI ] && { echo ""; return 1; }

	offset=$(( offset + FI_PAGESIZE ))
	magic=$( fi_get_hexdump_at "$offset" 4 )
	[ "$magic" != "$magic_ubi2" ] && { echo ""; return 1; }

	echo "true"
	return 0
}

fi_get_rootfs_offset() {
	local start=$1
	local pos
	local offset
	local align
	local end

	for offset in 0 1 2 3 4; do
		pos=$(( start + offset ))
		[ -n "$( fi_check_ubi_header "$pos" )" ] && { echo "$pos"; return 0; }
	done

	for align in 4 8 16 32 64 128 256 512 1024 2048 4096; do
		pos=$( fi_get_round_up "$start" "$align" )
		[ -n "$( fi_check_ubi_header "$pos" )" ] && { echo "$pos"; return 0; }
	done

	align=65536
	pos=$( fi_get_round_up "$start" "$align" )
	end=$(( pos + 3000000 ))
	while true; do
		[ $(( pos + 150000 )) -gt "$FI_IMAGE_SIZE" ] && break
		[ -n "$( fi_check_ubi_header "$pos" )" ] && { echo "$pos"; return 0; }
		pos=$(( pos + align ))
		[ "$pos" -ge "$end" ] && break
	done

	echo ""
	return 1
}

fi_check_tar() {
	local tar_file=$1
	local magic
	local board_dir
	local control_len  kernel_len  rootfs_len

	if [ -z "$tar_file" ]; then
		tar_file=$FI_IMAGE
	fi
	magic=$( fi_get_hexdump_at 0 8 "$tar_file" )
	if [ "$magic" != $FI_MAGIC_SYSUPG ]; then
		fierr "incorrect TAR-image!"
		return 1
	fi	
	board_dir=$( tar tf "$tar_file" | grep -m 1 '^sysupgrade-.*/$' )
	[ -z "$board_dir" ] && {
		fierr "incorrect TAR-image! (board dir not found)"
		return 1
	}
	board_dir=${board_dir%/}

	control_len=$( (tar xf "$tar_file" "$board_dir/CONTROL" -O | wc -c) 2> /dev/null)
	if [ "$control_len" -lt 3 ]; then
		fierr "incorrect TAR-image! (CONTROL not found)"
		return 1
	fi
	kernel_len=$( (tar xf "$tar_file" "$board_dir/kernel" -O | wc -c) 2> /dev/null)
	if [ "$kernel_len" -lt 1000000 ]; then
		fierr "incorrect TAR-image! (kernel not found)"
		return 1
	fi
	rootfs_len=$( (tar xf "$tar_file" "$board_dir/root" -O | wc -c) 2> /dev/null)
	if [ "$rootfs_len" -lt 1000000 ]; then
		fierr "incorrect TAR-image! (rootfs not found)"
		return 1
	fi
	return 0
}

function get_parent_proc_cmdline
{
	local pid=$$
	local ppid=$( cut -d' ' -f4  /proc/$pid/stat )
	local cmdline=$( cat /proc/$ppid/cmdline | /bin/busybox tr '\0' ' ' )
	echo -n "$cmdline"
}

function is_sysupgrade_test
{
	local parent_cmdline=$( get_parent_proc_cmdline )
	if echo "$parent_cmdline" | grep -q '/sbin/sysupgrade ' ; then
		if echo "$parent_cmdline" | grep -q ' --test' ; then
			return 0
		fi
	fi
	return 1
}
