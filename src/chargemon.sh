#!/system/bin/sh
#
# Dual Recovery for many Sony Xperia devices!
#
# Author:
#   [NUT]
#
# - Thanks go to DooMLoRD for the keycodes and a working example!
# - My gratitude also goes out to Androxyde for his sometimes briliant
#   ideas to simplify things while writing the scripts!
#
###########################################################################

set +x
_PATH="$PATH"
export PATH="/system/xbin:/system/bin:/sbin"

# Constants
LOGDIR="XZDualRecovery"
PREPLOG="/tmp/${LOGDIR}/preperation.log"
LOGFILE="XZDualRecovery.log"

# Nodes setup
BOOTREC_EXTERNAL_SDCARD_NODE="/dev/block/mmcblk1p1 b 179 32"
BOOTREC_EXTERNAL_SDCARD="/dev/block/mmcblk1p1"
BOOTREC_LED_RED="/sys/class/leds/$(/system/xbin/busybox ls -1 /sys/class/leds|/system/xbin/busybox grep red)/brightness"
BOOTREC_LED_GREEN="/sys/class/leds/$(/system/xbin/busybox ls -1 /sys/class/leds|/system/xbin/busybox grep green)/brightness"
BOOTREC_LED_BLUE="/sys/class/leds/$(/system/xbin/busybox ls -1 /sys/class/leds|/system/xbin/busybox grep blue)/brightness"

# Function definitions
TECHOL(){
  _TIME=`/system/xbin/busybox date +"%H:%M:%S"`
  echo "${_TIME} >> $*" >> ${PREPLOG}
  return 0
}
TEXECL(){
  _TIME=`/system/xbin/busybox date +"%H:%M:%S"`
  echo "${_TIME} >> $*" >> ${PREPLOG}
  $* 2>&1 >> ${PREPLOG}
  _RET=$?
  echo "${_TIME} >> RET=${_RET}" >> ${PREPLOG}
  return ${_RET}
}
#86|87) TEXECL mount -t ntfs ${BOOTREC_EXTERNAL_SDCARD} /storage/sdcard1; return $?;;
MOUNTSDCARD(){
	case $* in
		06|6|0B|b|0C|c|0E|e) TEXECL mount -t vfat ${BOOTREC_EXTERNAL_SDCARD} /storage/sdcard1; return $?;;
		07|7) TEXECL insmod /system/lib/modules/nls_utf8.ko;
		      TEXECL insmod /system/lib/modules/texfat.ko;
		      TEXECL mount -t texfat ${BOOTREC_EXTERNAL_SDCARD} /storage/sdcard1;
		      return $?;;
		83) PTYPE=$(/system/xbin/busybox blkid ${BOOTREC_EXTERNAL_SDCARD} | /system/xbin/busybox awk -F' ' '{ print $NF }' | /system/xbin/busybox awk -F'[\"=]' '{ print $3 }');
		    TEXECL mount -t $PTYPE ${BOOTREC_EXTERNAL_SDCARD} /storage/sdcard1;
		    return $?;;
		 *) return 1;;
	esac
	TECHOL "### MOUNTSDCARD did not run with a parameter!";
	return 1;
}
SETLED() {
	if [ "$1" = "on" ]; then

		TECHOL "Turn on LED R: $2 G: $3 B: $4"
		echo "$2" > ${BOOTREC_LED_RED}
		echo "$3" > ${BOOTREC_LED_GREEN}
		echo "$4" > ${BOOTREC_LED_BLUE}

	else
		TECHOL "Turn off LED"
		echo "0" > ${BOOTREC_LED_RED}
		echo "0" > ${BOOTREC_LED_GREEN}
		echo "0" > ${BOOTREC_LED_BLUE}
	fi
}
EXIT2CM(){
	# Turn on a red led, as a visual warning to the user
	SETLED on 255 0 0

	sleep 2

	# Turn off LED
	SETLED off

	# Ending log
	DATETIME=`/system/xbin/busybox date +"%d-%m-%Y %H:%M:%S"`
	echo "STOP Dual Recovery STAGE 1 at ${DATETIME}" >> ${PREPLOG}

	umount -l /storage/sdcard1

	export PATH="${_PATH}"

	exec /system/bin/chargemon.stock
	exit 0
}
DRGETPROP() {

	# If it's empty, see if what was requested was a XZDR.prop value!
	PROP=`grep "$*" ${DRPATH}/XZDR.prop | awk -F'=' '{ print $NF }'`

	if [ "$PROP" = "" ]; then

		# If it still is empty, try to get it from the build.prop
		PROP=`grep "$*" /system/build.prop | awk -F'=' '{ print $NF }'`

	fi

	echo $PROP

}

# Find the gpio-keys node, to listen on the right input event
gpioKeysSearch() {
	TECHOL "Trying to find the gpio-keys event node."
	for INPUTUEVENT in `${BUSYBOX} find /sys/devices \( -path "*gpio*" -path "*keys*" -a -path "*input?*" -a -path "*event?*" -a -name "uevent" \)`; do

		INPUTDEV=$(${BUSYBOX} grep "DEVNAME=" ${INPUTUEVENT} | ${BUSYBOX} sed 's/DEVNAME=//')

		if [ -e "/dev/$INPUTDEV" -a "$INPUTDEV" != "" ]; then
			TECHOL "Found and will be using /dev/${INPUTDEV}!"
			echo "/dev/${INPUTDEV}"
			break
		fi

	done
}

# Find the power key node, to listen on the right input event
pwrkeySearch() {
	TECHOL "Trying to find the power key event node."
	# pm8xxx (xperia Z and similar)
	for INPUTUEVENT in `${BUSYBOX} find /sys/devices \( -path "*pm8xxx*" -path "*pwrkey*" -a -path "*input?*" -a -path "*event?*" -a -name "uevent" \)`; do

		INPUTDEV=$(${BUSYBOX} grep "DEVNAME=" ${INPUTUEVENT} | ${BUSYBOX} sed 's/DEVNAME=//')

		if [ -e "/dev/$INPUTDEV" -a "$INPUTDEV" != "" ]; then
			TECHOL "Found and will be monitoring /dev/${INPUTDEV}!"
			echo "/dev/${INPUTDEV}"
			break
		fi

	done
	# qpnp_pon (xperia Z1 and similar)
	for INPUTUEVENT in `find $(find /sys/devices/ -name "name" -exec grep -l "qpnp_pon" {} \; | awk -F '/' 'sub(FS $NF,x)') \( -path "*input?*" -a -path "*event?*" -a -name "uevent" \)`; do

		INPUTDEV=$(${BUSYBOX} grep "DEVNAME=" ${INPUTUEVENT} | ${BUSYBOX} sed 's/DEVNAME=//')

		if [ -e "/dev/$INPUTDEV" -a "$INPUTDEV" != "" ]; then
			TECHOL "Found and will be monitoring /dev/${INPUTDEV}!"
			echo "/dev/${INPUTDEV}"
			break
		fi

	done
}

# Busybox setup, chosing the one that supports lzcat, as it is vital for this recovery setup!
if [ -x "/system/xbin/busybox" -a ! -n "${BUSYBOX}" ]; then
	CHECK=`/system/xbin/busybox --list | /system/xbin/busybox grep lzcat | /system/xbin/busybox wc -l`
	if [ "$CHECK" -gt "0" ]; then
 		BUSYBOX="/system/xbin/busybox"
	fi
fi
# Fallback to the one in /system/bin, but only if it supports lzcat...
if [ -x "/system/bin/busybox" ]; then
	CHECK=`/system/bin/busybox --list | /system/bin/busybox grep lzcat | /system/bin/busybox wc -l`
	if [ "$CHECK" -gt "0" ]; then
		BUSYBOX="/system/bin/busybox"
	fi
fi

# We can actually safely asume a busybox exists in /system/xbin (as XZDualRecovery installs one there)
${BUSYBOX} mount -o remount,rw rootfs /
if [ ! -d "/tmp" ]; then
	mkdir /tmp
	${BUSYBOX} mount -t tmpfs tmpfs /tmp
fi
${BUSYBOX} mkdir /tmp/XZDualRecovery
${BUSYBOX} mount -o remount,ro rootfs /

# Kickstarting log
DATETIME=`${BUSYBOX} date +"%d-%m-%Y %H:%M:%S"`
echo "START Dual Recovery at ${DATETIME}: STAGE 1." > ${PREPLOG}

# The function to check if the found busybox is usable, if not, it will log that and exit this script
if [ ! -n "${BUSYBOX}" ]; then

	if [ "${BUSYBOX}" = "/system/xbin/busybox" ]; then
		echo "The busybox inside /system/xbin does not support lzcat!" >> ${PREPLOG}
		/system/xbin/busybox 2>&1 >> ${PREPLOG}
	elif [ "${BUSYBOX}" = "/system/bin/busybox" ]; then
		echo "The busybox inside /system/bin does not support lzcat!" >> ${PREPLOG}
		/system/bin/busybox 2>&1 >> ${PREPLOG}
	else
		echo "No busybox found at all!" >> ${PREPLOG}
	fi
	EXIT2CM

else

	TECHOL "Using ${BUSYBOX}"

	TEXECL mount -o remount,rw rootfs /
	TEXECL mount -o remount,rw /system

	if [ -f "/system/xbin/disableric" ]; then
		TEXECL mount -t securityfs -o nosuid,nodev,noexec securityfs /sys/kernel/security
		TEXECL mkdir -p /sys/kernel/security/sony_ric
		TEXECL chmod 755 /sys/kernel/security/sony_ric
		TEXECL echo "0" > /sys/kernel/security/sony_ric/enable
	fi

	if [ -x "${BUSYBOX}" -a -x "/system/bin/dualrecovery.sh" ]; then

		TECHOL "Install busybox to /sbin..."
		${BUSYBOX} cp ${BUSYBOX} /sbin/

		if [ ! -f "/system/etc/.xzdrbusybox" ]; then

			TECHOL "Creating symlinks in /system/xbin to all functions of busybox."
			# Create a symlink for each of the supported commands
			for sym in `${BUSYBOX} --list`; do
				TECHOL "Linking ${BUSYBOX} to /system/xbin/$sym"
				${BUSYBOX} ln -sf ${BUSYBOX} /system/xbin/$sym
			done

			${BUSYBOX} touch /system/etc/.xzdrbusybox

		else

			TECHOL "Skipping creation of busybox symlinks."

		fi

		export PATH="/system/xbin"

		TECHOL "Copying recovery files to /sbin"
		TEXECL cp /system/bin/dualrecovery.sh /sbin/init.sh
		TEXECL chmod 755 /sbin/init.sh

	else

		TECHOL "Key files missing, exitting!"

		EXIT2CM

	fi

	TEXECL mount -o remount,ro rootfs /
	TEXECL mount -o remount,ro /system

fi

# Checking if we can mount an external storage
# The external storage is prefered, cache will now only be used if its absent.

# Create device node if it doesn't exist
if [ ! -b ${BOOTREC_EXTERNAL_SDCARD} ]; then
	TEXECL mknod -m 660 ${BOOTREC_EXTERNAL_SDCARD_NODE}
fi

# Create mountpoint if it doesn't exist
if [ ! -d /storage/sdcard1 ]; then
	TEXECL mount -o remount,rw rootfs /
	TEXECL mkdir -p /storage/sdcard1
	TEXECL mount -o remount,ro rootfs /
fi

# Mount external storage
if [ -b ${BOOTREC_EXTERNAL_SDCARD} ]; then

	# Testing if bootflag is set, that changes the location of the fs type code.
	BOOT=`fdisk -l /dev/block/mmcblk1 | grep "/dev/block/mmcblk1p1" | awk '{print $2}'`
	if [ "${BOOT}" = "*" ]; then
		FSTYPE=`fdisk -l /dev/block/mmcblk1 | grep "/dev/block/mmcblk1p1" | awk '{print $6}'`
		TXTFSTYPE=`fdisk -l /dev/block/mmcblk1 | grep "/dev/block/mmcblk1p1" | awk '{for(i=7;i<=NF;++i) printf("%s ", $i)}'`
		TECHOL "### SDCard1 FS found: ${TXTFSTYPE} with code '${FSTYPE}', bootflag was set.";
	else
		FSTYPE=`fdisk -l /dev/block/mmcblk1 | grep "/dev/block/mmcblk1p1" | awk '{print $5}'`
		TXTFSTYPE=`fdisk -l /dev/block/mmcblk1 | grep "/dev/block/mmcblk1p1" | awk '{for(i=6;i<=NF;++i) printf("%s ", $i)}'`
		TECHOL "### SDCard1 FS found: ${TXTFSTYPE} with code '${FSTYPE}'.";
	fi

	MOUNTSDCARD ${FSTYPE}
	if [ "$?" -eq "0" ]; then

		# We can! Lets do it, this will keep recovery working even if cache is somehow destroyed.
		TECHOL "### Mounted SDCard1!"
		# Cleanup old chargemon directories
		if [ -d "/cache/${LOGDIR}" ]; then
			TEXECL rm -rf /cache/chargemon
			TEXECL rm -rf /cache/${LOGDIR}
		fi

		DRPATH="/storage/sdcard1/${LOGDIR}"

		if [ ! -d "${DRPATH}" ]; then
			TECHOL "Creating the ${LOGDIR} directory on SDCard1."
			TEXECL mkdir ${DRPATH}
		else
			TECHOL "Removing old chargemon logs..."
			TEXECL rm -f ${DRPATH}/chargemon*
		fi

	else

		TECHOL "### Not mounting SDCard1!";
		DRPATH="/cache/${LOGDIR}"

		if [ ! -d "${DRPATH}" ]; then
			TECHOL "Creating the ${LOGDIR} directory in /cache."
			TEXECL mkdir ${DRPATH}
		fi

	fi

fi

# As a precaution, give users a way out. This works best if the user has an external sdcard.
if [ -f "${DRPATH}/donotrun" ]; then

	TECHOL "Exitting by DNR file.";

	EXIT2CM

fi

if [ ! -d "/system/etc/init.d" ]; then
	TECHOL "No init.d directory found, creating it now!"
	TECHOL "To enable init.d support, set dr.enable.initd to true in XZDR.prop!"
	mkdir /system/etc/init.d
fi

# Initial setup of the XZDR.prop file, only once or whenever the file was removed
if [ ! -f "${DRPATH}/XZDR.prop" ]; then
	TECHOL "Creating XZDR.prop file."
	if [ -f "${DRPATH}/default" -a "`cat ${DRPATH}/default`" = "twrp" ]; then
		TECHOL "dr.recovery.boot will be set to TWRP"
		echo "dr.recovery.boot=twrp" > ${DRPATH}/XZDR.prop
		rm -f ${DRPATH}/default
	else
		TECHOL "dr.recovery.boot will be set to PhilZ (default)"
		echo "dr.recovery.boot=philz" > ${DRPATH}/XZDR.prop
	fi
	TECHOL "dr.initd.active will be set to false (default)"
	echo "dr.initd.active=false" >> ${DRPATH}/XZDR.prop
	TECHOL "dr.ramdisk.boot will be set to false (default)"
	echo "dr.ramdisk.boot=false" >> ${DRPATH}/XZDR.prop
	if [ -f "/system/bin/ramdisk.stock.cpio.lzma" ]; then
		TECHOL "dr.ramdisk.path will /system/bin/ramdisk.stock.cpio.lzma"
		echo "dr.ramdisk.path=/system/bin/ramdisk.stock.cpio.lzma" >> ${DRPATH}/XZDR.prop
	else
		TECHOL "dr.ramdisk.path will be empty (default)"
		echo "dr.ramdisk.path=" >> ${DRPATH}/XZDR.prop
	fi
	echo "dr.gpiokeys.node=$(gpioKeysSearch)" >> ${DRPATH}/XZDR.prop
	echo "dr.pwrkey.node=$(pwrkeySearch)" >> ${DRPATH}/XZDR.prop
fi

# Initial button setup for existing XZDR.prop files which do not have the input nodes defined.
if [ "$(DRGETPROP dr.gpiokeys.node)" = "" -a "$(DRGETPROP dr.pwrkey.node)" = "" ]; then
	echo "" >> ${DRPATH}/XZDR.prop
	echo "dr.gpiokeys.node=$(gpioKeysSearch)" >> ${DRPATH}/XZDR.prop
	echo "dr.pwrkey.node=$(pwrkeySearch)" >> ${DRPATH}/XZDR.prop
fi

# Debugging substitution, for ease of use in debugging specific user problems
if [ -e "${DRPATH}/drdebug.sh" ]; then

	# Turn on a blue led, as a visual warning to the user
	SETLED on 0 0 255

	TECHOL "Found debugging script, copying it in place of /sbin/init.sh!"
	TEXECL mount -o remount,rw rootfs /
	cp ${DRPATH}/drdebug.sh /sbin/init.sh
	TEXECL mount -o remount,ro rootfs /
	LOGFILE="XZDebug.log"

	sleep 2

	SETLED off

fi

# Logfile rotation
TECHOL "Logfile rotation..."
if [ -f ${DRPATH}/${LOGFILE} ];then
	TEXECL mv ${DRPATH}/${LOGFILE} ${DRPATH}/${LOGFILE}.old
fi
TEXECL touch ${DRPATH}/${LOGFILE}
TEXECL chmod 660 ${DRPATH}/${LOGFILE}

if [ -e "/sbin/init.sh" -a "$EVENTNODE" != "none" ]; then
	echo "Will be calling /sbin/init.sh with arguments '$EVENTNODE', '$POWERNODE', '$DRPATH', '$LOGFILE'" >> ${PREPLOG}
fi

# Ending log
DATETIME=`${BUSYBOX} date +"%d-%m-%Y %H:%M:%S"`
echo "STOP Dual Recovery STAGE 1 at ${DATETIME}, starting stage 2!" >> ${PREPLOG}

# Copy the preperation log to the main log directory, easy to find for the noobish users...
cp ${PREPLOG} ${DRPATH}/

########
#
#
# Preperations all done, lets continue to recovery!
#
#
#######################################################################

# One last failsafe...
if [ -e "/sbin/init.sh" -a "$EVENTNODE" != "none" ]; then

	export PATH="${_PATH}"

	exec /sbin/init.sh $DRPATH $LOGFILE

else

	EXIT2CM

fi
