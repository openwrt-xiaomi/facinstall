#!/bin/sh
#
# Copyright (C) 2023 remittor
#

. /lib/upgrade/facinstall/functions.sh

FI_IMAGE=$IMAGE
export FI_LOGMODE=2
export FI_STAGE=2
filog "call: fi_do_stage2.sh $FI_IMAGE"
fi_set_image $FI_IMAGE

fi_after_flash() {
	v "Upgrade completed"
	sleep 1
	v "Rebooting system..."
	umount -a
	reboot -f
	sleep 5
	echo b 2>/dev/null >/proc/sysrq-trigger
	exit 0
}

if ! fi_init_board; then
	FI_IMAGE=
fi
if [ "$FI_IMAGE_MAGIC" = "$FI_MAGIC_SYSUPG" ] && [ "$FI_HOOK_TARSYSUPG" != "true" ]; then
	FI_IMAGE=
fi
if [ $FI_IMAGE_OPENWRT_SIGN != 0 ]; then
	FI_IMAGE=
fi

if [ -f "$FI_IMAGE" ] && [ -n "$FI_SCRIPT" ]; then
	filog "call: fi_do_stage2.sh for $FI_BOARD"
	export FI_LOGMODE=2
	type 'fi_platform_do_upgrade' >/dev/null 2>/dev/null
	if [ $? != 0 ]; then
		fidie "Function 'fi_platform_do_upgrade' not found"
	fi
	fi_platform_do_upgrade
	fi_after_flash
fi
