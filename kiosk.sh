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

# Initialize variables.
VERBOSE="1"
ONDIE="restart"
MEDIA_CONFIG=""
MEDIA_DRIVE=""

# Find a config file and directory.
get_setup () {

	# Reset any chromium errors.
	sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /home/pi/.config/chromium/Default/Preferences
	sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' /home/pi/.config/chromium/Default/Preferences

	NEW_CONFIG="/kiosk/config.ini"
	NEW_DRIVE="/kiosk/"

	for DRIVE in /media/pi/*
	do
		for FILE in $DRIVE/*
		do
			if [[ "${FILE##*/}" == "config.ini" ]]; then
				NEW_CONFIG="$FILE"
				NEW_DRIVE="$DRIVE"
				break;
			fi
		done
	done

	if [[ "$NEW_CONFIG" == "$MEDIA_CONFIG" && "$NEW_DRIVE" == "$MEDIA_DRIVE" ]]; then
		return
	else
		MEDIA_CONFIG="$NEW_CONFIG"
		MEDIA_DRIVE="$NEW_DRIVE"
	fi

	# Kill all existing child processes.
	pkill -P $$

	# Hide cursor.
	unclutter -idle 0.5 -root 2>/dev/null &

	# Parse config file for options.
	QUIET=$(awk -F "=" '/quiet/ {print tolower($2)}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')
	ACTION=$(awk -F "=" '/action/ {print tolower($2)}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')
	TIMER=$(awk -F "=" '/timer/ {print $2}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')
	URL=$(awk -F "=" '/url/ {print $2}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')
	ONDIE=$(awk -F "=" '/ondie/ {print $2}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')
	REPOLL=$(awk -F "=" '/repoll/ {print $2}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')
	SSID=$(awk -F "=" '/ssid/ {print $2}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')
	PASSWORD=$(awk -F "=" '/password/ {print $2}' "$MEDIA_CONFIG" | tr -d ' \t\n\r')

	# Set defaults
	if [[ -z "$QUIET" ]]; then QUIET="0"; fi
	if [[ -z "$ACTION" ]]; then ACTION="none"; fi
	if [[ -z "$TIMER" ]]; then TIMER=300; fi
	if [[ -z "$ONDIE" ]]; then ONDIE="restart"; fi
	if [[ -z "$REPOLL" ]]; then REPOLL=10; fi

	if [[ "$QUIET" == "1" ]]; then VERBOSE=""; fi
	if [[ ! -z "$VERBOSE" ]]; then
		echo "Config found: $MEDIA_CONFIG"
		echo "Config drive: $MEDIA_DRIVE"
		echo "Config action: $ACTION"
		echo "Config timer: $TIMER"
		echo "Config URL: $URL"
		echo "Config repoll: $REPOLL"
		echo "Config SSID: $SSID"
	fi

	# Check to see if the wifi settings need updating.
	if [[ -f "$SUPPLICANT_CONF" ]]; then
		OLD_SSID=$(awk -F "=" '/ssid/ {print $2}' "$SUPPLICANT_CONF" | tr -d '1' | tr -d ' \t\n\r' | tr -d "\"" )
		if [[ "$OLD_SSID" == "$SSID" ]]; then
			return
		elif [[ ! -z "$VERBOSE" ]]; then
			echo "WiFi reconfiguring..."
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

	if [[ ! -z "$VERBOSE" ]]; then
		echo "WiFi reconfigure complete."
	fi
}

while [[ "$ONDIE" == "restart" ]]
do
	get_setup

	# Display the requested function.
	if [[ "$ACTION" == "slideshow" ]]; then
		if [[ ! -z "$VERBOSE" ]]; then
			echo "Starting feh."
		fi
		runuser $DEFAULT_USER -c "feh --quiet --auto-zoom --randomize --recursive --fullscreen --slideshow-delay $TIMER --hide-pointer --auto-rotate $MEDIA_DRIVE" &
		ACTION="started"
	elif [[ "$ACTION" == "browser" ]]; then
		if [[ ! -z "$VERBOSE" ]]; then
			echo "Starting chromium-browser."
		fi
		runuser $DEFAULT_USER -c "chromium-browser --noerrdialogs --disable-infobars --kiosk $URL" &
		ACTION="started"
	fi

	if [[ ! -z "$VERBOSE" ]]; then
		echo "Sleeping $REPOLL seconds."
	fi

	sleep $REPOLL

done
