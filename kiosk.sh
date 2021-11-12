#!/bin/bash

#
# A basic slideshow / Chromium kiosk script with automatic USB drive polling. To enable, a file named "kiosk" must be present in the Pi's root directory with a valid config.ini file.
#

# System variables
DEFAULT_USER="pi"
SUPPLICANT_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root."
	exit 1
fi

# Check dependencies
command -v feh >/dev/null 2>&1 || { echo >&2 "Script requires feh but it's not installed. Aborting."; exit 1; }
command -v chromium-browser >/dev/null 2>&1 || { echo >&2 "Script requires chromium-browser but it's not installed. Aborting."; exit 1; }
command -v xdotool >/dev/null 2>&1 || { echo >&2 "Script requires xdotool but it's not installed. Aborting."; exit 1; }
command -v unclutter >/dev/null 2>&1 || { echo >&2 "Script requires unclutter but it's not installed. Aborting."; exit 1; }

if [[ ! -d "/kiosk" ]]; then
	echo "Kiosk mode not enabled."
	exit 0
fi
if [[ ! -f "/kiosk/config.ini" ]]; then
	echo "Default config file not found."
	exit 1
fi

# Set sleep conditions
xset s noblank
xset s off
xset -dpms

# Reset any chromium errors.
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /home/pi/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' /home/pi/.config/chromium/Default/Preferences

# Hide cursor.
unclutter -idle 0.5 -root &

# Find a config file and directory.
find_setup () {
	MEDIA_CONFIG="/kiosk/config.ini"
	MEDIA_DRIVE="/kiosk/"

	for MEDIA_DRIVE in /media/pi/*/
	do
		for FILE in $MEDIA_DRIVE*
		do
			if [[ "${FILE##*/}" == "config.ini" ]]; then
				MEDIA_CONFIG="$FILE"
				break;
			fi
		done
		if [[ "$MEDIA_CONFIG" != "/kiosk/config.ini" ]]; then
			break;
		fi
	done

	# Parse config file for options.
	ACTION=$(awk -F "=" '/action/ {print tolower($2)}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')
	TIMER=$(awk -F "=" '/timer/ {print $2}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')
	URL=$(awk -F "=" '/url/ {print $2}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')
	ONDIE=$(awk -F "=" '/ondie/ {print $2}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')
	REPOLL=$(awk -F "=" '/repoll/ {print $2}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')
	SSID=$(awk -F "=" '/ssid/ {print $2}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')
	PASSWORD=$(awk -F "=" '/password/ {print $2}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')

	# Set defaults
	if [[ -z "$ACTION" ]]; then ACTION="slideshow"; fi
	if [[ -z "$TIMER" ]]; then TIMER=300; fi
	if [[ -z "$ONDIE" ]]; then ONDIE="restart"; fi
	if [[ -z "$REPOLL" ]]; then REPOLL=10; fi

	# Check to see if the wifi settings need updating.
	if [[ -f "$SUPPLICANT_CONF" ]]; then
		OLD_SSID=$(awk -F "=" '/ssid/ {print $2}' "$SUPPLICANT_CONF" | tr -d '1' | tr -d ' \t\n\r' | tr -d "\"" )
		if [[ "$OLD_SSID" == "$SSID" ]]; then
			return
		fi
	fi

	# Reset wifi settings to default.
	echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev" >  "$SUPPLICANT_CONF"
	echo "update_config=1" >> "$SUPPLICANT_CONF"
	echo "country=US" >> "$SUPPLICANT_CONF"

	# Update wifi settings (if provided).
	if [[ -n "$SSID" ]]; then
		echo "network={" >> "$SUPPLICANT_CONF"
		echo "	ssid=\"$SSID\"" >> "$SUPPLICANT_CONF"
		echo "	scan_ssid=1" >> "$SUPPLICANT_CONF"
		if [[ -n "$SSID" ]]; then
			echo "	psk=\"$PASSWORD\"" >> "$SUPPLICANT_CONF"
		else
			echo "	key_mgmt=NONE" >> "$SUPPLICANT_CONF"
		fi
		echo "}" >> "$SUPPLICANT_CONF"
	fi

	# Force reload of wifi settings.
	wpa_cli -i wlan0 reconfigure
}

ONDIE="restart"
while [[ "$ONDIE" == "restart" ]]
do
	find_setup

	# If it's the default config file, sleep until we get a valid config file from an inserted drive.
	if [[ "$MEDIA_CONFIG" == "/kiosk/config.ini" ]]; then
		sleep $REPOLL
	else
		# Display the requested function.
		if [[ "$ACTION" == "slideshow" ]]; then
			runuser $DEFAULT_USER -c "feh --quiet --auto-zoom --randomize --recursive --fullscreen --slideshow-delay $TIMER --hide-pointer --auto-rotate $MEDIA_DRIVE"
		elif [[ "$ACTION" == "browser" ]] || [[ -n "$URL" ]]; then
			runuser $DEFAULT_USER -c "chromium-browser --noerrdialogs --disable-infobars --kiosk $URL"
		fi

		# If the drive was forcibly umounted, click to dismiss the warning message.
		xdotool mousemove 0 100 click 1
	fi
done

