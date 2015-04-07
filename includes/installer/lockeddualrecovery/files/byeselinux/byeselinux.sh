#!/data/local/tmp/recovery/busybox sh
######
#
# Part of byeselinux, created originally by zxz0O0, modified for use in XZDualRecovery by [NUT]
#

BUSYBOX="/data/local/tmp/recovery/busybox"

if [ ! -f /data/local/tmp/recovery/byeselinux.ko ]; then
	echo "Error patching kernel module. File not found."
	exit 1
fi

if [ ! -f /data/local/tmp/recovery/modulecrcpatch ]; then
	echo "Error: modulecrcpatch not found"
	exit 1
fi

$BUSYBOX chmod 777 /data/local/tmp/recovery/modulecrcpatch
/data/local/tmp/recovery/modulecrcpatch /data/local/tmp/recovery/byeselinux.ko /data/local/tmp/recovery/byeselinux.ko 1> /dev/null

$BUSYBOX mount -o remount,rw /system
if [ "$?" != "0" ]; then
        echo "Remount R/W failed, installing byeselinux aborted!"
        exit 1
fi

$BUSYBOX cp /data/local/tmp/recovery/byeselinux.ko /system/lib/modules/byeselinux.ko
$BUSYBOX chmod 644 /system/lib/modules/byeselinux.ko

exit 0