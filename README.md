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
sudo echo "@bash /kiosk/kiosk.sh" >> /etc/xdg/lxsession/LXDE-pi/autostart
```
