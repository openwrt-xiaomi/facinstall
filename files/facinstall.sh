#!/bin/sh
#
# Copyright (C) 2023 remittor
#

. $(dirname $0)/functions.sh

FI_LOGMODE=0

############################# /usr/libexec/validate_firmware_image
#include /lib/upgrade
#
#VALID=1
#FORCEABLE=1
#ALLOW_BACKUP=1
#[ -f /lib/upgrade/facinstall/validate_fw_image.sh ] && . /lib/upgrade/facinstall/validate_fw_image.sh "$1"   # hook
#
## Mark image as invalid but still possible to install
#notify_firmware_invalid() { 
#############################

fi_install_check_hook() {
	local hookname
	local cmd
	local xx
	hookname=$( basename $FI_CHECK_HOOK_FN )
	xx=$( grep -c -F "$hookname" "$FI_CHECK_ORIG_FN" )
	if [ "$xx" != "0" ]; then
		#filog 'File "validate_firmware_image" already patched'
		return 0
	fi
	cmd="[ -f $FI_CHECK_HOOK_FN ] && . $FI_CHECK_HOOK_FN "'"$1"'
	cmd=$( fi_sed_path "$cmd" )
	sed -i "/^ALLOW_BACKUP=1/a $cmd" $FI_CHECK_ORIG_FN
	xx=$( grep -c -F "$hookname" "$FI_CHECK_ORIG_FN" )
	if [ "$xx" = "0" ]; then
		fierr "Fail on patch file $FI_CHECK_ORIG_FN"
		return 1
	fi
	filog 'File "validate_firmware_image" successfully patched'
	return 0
}

############################# /lib/upgrade/stage2
#	do
#		local file="$(command -v "$binary" 2>/dev/null)"
#		[ -n "$file" ] && install_bin "$file"
#	done
#	install_file /lib/upgrade/facinstall/*.sh          # hook
#	install_file /etc/resolv.conf /lib/*.sh /lib/functions/*.sh
#############################

fi_install_ramfs_hook() {
	local cmd
	local dst
	local xx
	if [ ! -f "$FI_RAMFS_HOOK_FN" ]; then
		filog 'File "stage2" not found. Skip.'
		return 0
	fi
	xx=$( grep -c -F "$FI_RAMFS_HOOK_FLAG" "$FI_RAMFS_HOOK_FN" )
	if [ "$xx" != "0" ]; then
		#filog 'File "stage2" already patched'
		return 0
	fi
	cmd="install_file $FI_PROGDIR/<<STAR>>.sh"
	cmd=$( fi_sed_path "$cmd" )
	dst="install_file /etc/resolv.conf"
	dst=$( fi_sed_path "$dst" )
	sed -i "/$dst/i $cmd" $FI_RAMFS_HOOK_FN
	sed -i "s/<<STAR>>/\*/g" $FI_RAMFS_HOOK_FN
	xx=$( grep -c -F "$FI_RAMFS_HOOK_FLAG" "$FI_RAMFS_HOOK_FN" )
	if [ "$xx" = "0" ]; then
		fierr "Fail on patch file $FI_RAMFS_HOOK_FN"
		return 1
	fi
	filog 'File "stage2" successfully patched'
	return 0
}

############################# /lib/upgrade/do_stage2
#v "Performing system upgrade..."
#[ -f /lib/upgrade/facinstall/fi_do_stage2.sh ] && . /lib/upgrade/facinstall/fi_do_stage2.sh   # hook
#if type 'platform_do_upgrade' >/dev/null 2>/dev/null; then
#	platform_do_upgrade "$IMAGE"
#else
#	default_do_upgrade "$IMAGE"
#fi 
#############################

fi_install_flash_hook() {
	local hookname
	local cmd
	local xx
	hookname=$( basename $FI_FLASH_HOOK_FN )
	xx=$( grep -c -F "$hookname" "$FI_FLASH_ORIG_FN" )
	if [ "$xx" != "0" ]; then
		#filog 'File "do_stage2" already patched'
		return 0
	fi
	cmd="[ -f $FI_FLASH_HOOK_FN ] && . $FI_FLASH_HOOK_FN"
	#awk "!found && /platform_do_upgrade/ { print '$cmd'; found=1 } 1" $FI_FLASH_ORIG_FN
	cmd=$( fi_sed_path "$cmd" )
	sed -i "/'platform_do_upgrade'/i $cmd" $FI_FLASH_ORIG_FN
	xx=$( grep -c -F "$hookname" "$FI_FLASH_ORIG_FN" )
	if [ "$xx" = "0" ]; then
		fierr "Fail on patch file $FI_FLASH_ORIG_FN"
		return 1
	fi
	filog 'File "do_stage2" successfully patched'
	return 0
}

############################# /www/luci-static/resources/view/system/flash.js
#	L.env.rpctimeout = 75;                           # BUGFIX
#	return callSystemValidateFirmwareImage('/tmp/firmware.bin')
#		.then(function(res) { return [ reply, res ]; });
#
#############################
#	.catch(function(e) { ui.addNotification(null, E('p', e.message)) })
#	.finally(L.bind(function(btn) {
#		L.env.rpctimeout = 20;                       # BUGFIX
#		btn.firstChild.data = _('Flash image...');
#	}, this, ev.target));
#
#############################
#	args.push('/tmp/firmware.bin');
#	L.env.rpctimeout = 75;                           # BUGFIX
#
#	/* Currently the sysupgrade rpc call will not return, hence no promise handling */
#	fs.exec('/sbin/sysupgrade', args);
#
#############################

function fi_patch_flash_js_bugfix
{
	local cmd
	local trg
	if [ ! -f "$FI_FLASH_JAVA_FN" ]; then
		return 0
	fi
	if grep -qF "L.env.rpctimeout = " $FI_FLASH_JAVA_FN ; then
		#filog 'File "flash.js" already patched'
		return 0
	fi
	trg="return callSystemValidateFirmwareImage("
	cmd="\n L.env.rpctimeout = 75; \n $trg"
	sed -i "s/$trg/$cmd/g" $FI_FLASH_JAVA_FN

	trg=".finally(L.bind(function(btn){"
	cmd="$trg\n L.env.rpctimeout = 20; \n"
	sed -i "s/$trg/$cmd/g" $FI_FLASH_JAVA_FN

	trg=".push('/tmp/firmware.bin');"
	cmd="$trg\n L.env.rpctimeout = 75; \n"
	sed -i "s#$trg#$cmd#g" $FI_FLASH_JAVA_FN
	
	return 0
}

############################# /www/luci-static/resources/view/system/flash.js
#var cntbtn = E('button', {
#	'class': 'btn cbi-button-action important',
#	'click': ui.createHandlerFn(this, 'handleSysupgradeConfirm', btn, opts),
#},[_('Continue')]);
#<<HOOK>>
#
#############################

fi_patch_flash_js() {
	local cmd
	local dst
	local xx
	if [ ! -f "$FI_FLASH_JAVA_FN" ]; then
		filog 'File "flash.js" not found. Skip.'
		return 0
	fi
	xx=$( grep -c -F "$FI_FLASH_JAVA_FLAG" "$FI_FLASH_JAVA_FN" )
	if [ "$xx" != "0" ]; then
		#filog 'File "flash.js" already patched'
		return 0
	fi
	cmd=" if (res[1].hasOwnProperty('$FI_FLASH_JAVA_FLAG')) {
	        if (is_valid) {
	          body.push(E('p',{'class':'alert-message info'},
	            ['$FI_FLASH_JAVA_FLAG: ',res[2].stderr?res[2].stderr:'']
	          ));
	          body.push(E('hr'));
	        } else {
	          cntbtn.disabled=true;
	        }
	      };"
	cmd=$( echo -n "$cmd" | tr '\n' ' ' )
	cmd=$( echo -n "$cmd" | tr '\t' ' ' )
	cmd=$( fi_sed_path "$cmd" )
	dst="},[_('Continue')]);"
	dst=$( fi_sed_path "$dst" )
	sed -i "s/$dst/$dst\n\n$cmd\n\n/g" $FI_FLASH_JAVA_FN
	xx=$( grep -c -F "$FI_FLASH_JAVA_FLAG" "$FI_FLASH_JAVA_FN" )
	if [ "$xx" = "0" ]; then
		fierr "Fail on patch file $FI_FLASH_JAVA_FN"
		return 1
	fi
	fi_patch_flash_js_bugfix
	filog 'File "flash.js" successfully patched'
	rm -f /tmp/luci-index*
	rm -rf /tmp/luci-modulecache
	[ -f "/sbin/luci-reload" ] && /sbin/luci-reload
	return 0
}

fi_remove_all_hooks() {
	local hookname
	
	hookname=$( basename  $FI_CHECK_HOOK_FN )
	sed -i "/$hookname/d" $FI_CHECK_ORIG_FN

	sed -i "/$FI_RAMFS_HOOK_FLAG/d" $FI_RAMFS_HOOK_FN
	
	hookname=$( basename  $FI_FLASH_HOOK_FN )
	sed -i "/$hookname/d" $FI_FLASH_ORIG_FN
	
	sed -i "/$FI_FLASH_JAVA_FLAG/d" $FI_FLASH_JAVA_FN
	sed -i "/L.env.rpctimeout = /d" $FI_FLASH_JAVA_FN
	sed -i "s/\n\n\n\n/\n/g"  $FI_FLASH_JAVA_FN
}

fi_install_upgrade_hooks() {
	filog "install_upgrade_hooks (version: $FI_VERSION)"
	if fi_install_check_hook ; then
		if fi_install_ramfs_hook ; then
			if fi_install_flash_hook ; then
				fi_patch_flash_js
				filog "all files successfully patched!"
				return 0
			fi
		fi
	fi
	fi_remove_all_hooks
	return 1
}

fi_remove_upgrade_hooks() {
	filog "remove_upgrade_hooks (version: $FI_VERSION)"
	fi_remove_all_hooks
	return 0
}

# ===================================================================

usage() {
	cat << EOF

Usage:
 $FI_PROGNAME [options] -- command

Commands:
start         install upgrade patch
stop          remove upgrade patch

Parameters:
 -h           show this help and exit
 -d           show debug messages
EOF
}

usage_err() {
	printf %s\\n "$FI_PROGNAME: $@" >&2
	usage >&2
	exit 1
}

while getopts ":hd" OPT; do
	case "$OPT" in
		h)	usage; exit 0;;
		d)	FI_DEBUG=1;;
		:)	usage_err "option -$OPTARG missing argument";;
		\?)	usage_err "invalid option -$OPTARG";;
		*)	usage_err "unhandled option -$OPT $OPTARG";;
	esac
done
shift $((OPTIND - 1 ))	# OPTIND is 1 based

case "$1" in
	boot)
		filog "boot"
		fi_install_upgrade_hooks
		exit 0
		;;
	start)
		filog "start"
		fi_install_upgrade_hooks
		exit 0
		;;
	stop)
		filog "stop"
		fi_remove_upgrade_hooks
		exit 0
		;;
	reload)
		filog "reload"
		exit 0
		;;
	*)
		usage_err "unknown command - $1";;
esac
