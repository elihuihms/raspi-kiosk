
# Raspberry Pi Kiosk Script

Very basic kiosk script to display a slide show from an inserted USB stick or use Chromium in kiosk mode to view a URL.

## Raspbian setup
1. Install raspbian 10 (Buster) w/ GUI.
2. Enable SSH via `raspi-config` if desired.
3. Enable autologin to GUI (option B4) via `raspi-config`.
4. Change pi password to something secure.

```
$ ssh pi@raspberrypi.local
...
$ sudo apt-get clean
$ sudo apt-get autoremove -y
$ sudo apt-get update
$ sudo apt-get upgrade
$ sudo apt-get install feh xdotool unclutter
```

## Install kiosk.sh

```
sudo mkdir /kiosk
cd /kiosk
sudo curl -o kiosk.sh https://raw.githubusercontent.com/elihuihms/raspi-kiosk/master/kiosk.sh
sudo curl -o config.ini https://raw.githubusercontent.com/elihuihms/raspi-kiosk/master/config.ini
sudo chmod 700 kiosk.sh
sudo chmod 600 config.ini
```

## Configure startup

```
sudo echo "@bash /kiosk/kiosk.sh" >> /etc/xdg/lxsession/LXDE-pi/autostart
```

Or

```
sudo curl -o /lib/systemd/system/kiosk.service https://raw.githubusercontent.com/elihuihms/raspi-kiosk/master/kiosk.service
sudo systemctl enable kiosk.service
sudo systemctl start kiosk.service
```

You may need to edit the `Environment=DISPLAY=:0.0` line of the kiosk.service file to match whatever your root $DISPLAY is.

## Usage

The config.ini file can be used as a template for USB drives. Simply copy the file and put it in the base directory of the drive. If using the slideshow mode, also copy desired .pngs, .jpgs, etc to the drive. If no USB drive is connected, the values in `/kiosk/config.ini` are used.

Config parameters:
* `quiet` : Set to "1" to disable printing of debug information. If you're running the kiosk script as a service, you can see the log entries via `sudo journalctl -u kiosk.service`
* `action` : Set to "browser" or "slideshow", any other directive will cause the kiosk script to do nothing.
* `timer` (slideshow mode only): The delay (in seconds) between automatically changing slides.
* `url` (browser mode only): The URL to show in Chromium.
* `ondie` : If set to anything other than "restart", will cause the kiosk script to exit when the config changes.
* `repoll` : Time (in seconds) between repolling for new configurations.
* `ssid` : SSID of the wireless network to connect to.
* `password` : Password to use for authentication for the SSID.


## Compatibility notes

* `chromium-browser` on versions of Raspbian (Raspberry OS) greater than Buster don't work on the Raspberry Pi Zero W (they're compiled for a higher ARM version).

## Acknowledgements / further reading

* https://pimylifeup.com/raspberry-pi-kiosk/
* https://desertbot.io/blog/raspberry-pi-touchscreen-kiosk-setup