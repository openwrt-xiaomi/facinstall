#!/bin/sh
#
# Copyright (C) 2023 remittor
#

. /lib/upgrade/facinstall/functions.sh

FI_IMAGE=$1
FI_LOGMODE=0
FI_STAGE=0
filog "call: validate_fw_image.sh $FI_IMAGE"
fi_set_image $FI_IMAGE

if [ "$FI_IMAGE_MAGIC" = $FI_MAGIC_SYSUPG ]; then
	FI_IMAGE=
else
	if ! fi_init_board; then
		FI_IMAGE=
	fi
fi

if [ -f "$FI_IMAGE" -a -n "$FI_SCRIPT" ]; then
	FI_STAGE=1
	filog "call: validate_fw_image.sh for $FI_BOARD"

	VALID=0
	FORCEABLE=0
	ALLOW_BACKUP=0

	json_set_namespace validate_firmware_image old_ns
	json_init
		json_add_object "tests"
			json_add_boolean fwtool_signature 1
			json_add_boolean fwtool_device_match 1
			json_set_namespace $old_ns
			FI_LOGMODE=1
			type 'fi_platform_check_image' >/dev/null 2>/dev/null
			if [ $? != 0 ]; then
				fierr "Function 'fi_platform_check_image' not found"
			else
				fi_platform_check_image >&2 && VALID=1
			fi
			FI_LOGMODE=0
			json_set_namespace validate_firmware_image old_ns
		json_close_object
		json_add_boolean $FI_FLASH_JAVA_FLAG 1
		json_add_boolean valid "$VALID"
		json_add_boolean forceable "$FORCEABLE"
		json_add_boolean allow_backup "$ALLOW_BACKUP"
	json_dump -i
	json_set_namespace $old_ns
	exit 0
fi
