#!/bin/bash

#Collect Private Data
read -p 'Clock Name: ' place
read -p 'Clock Latitude: ' lat
read -p 'Clock Longitude: ' lon
read -p 'Clock Altitude: ' alt
read -p 'Use ZeroTier? (y/n) ' use_zerotier
if [ "$use_zerotier" != "${use_zerotier#[Yy]}" ] ;then
    read -p 'ZeroTier IP Range: ' zerotier_ip_range
    read -p 'ZeroTier Network ID: ' zerotier_network_id
    read -p 'Local DNS Server for ZeroTier forwarded traffic (Leave blank to skip): ' zerotier_dns_server
fi

#Drop resolution to something with an aspect ratio identical to the screen say 800X400
#From <https://learn.adafruit.com/adafruit-5-800x480-tft-hdmi-monitor-touchscreen-backpack/raspberry-pi-config> 
cat <<EOF | sudo tee -a /boot/config.txt

# uncomment if hdmi display is not detected and composite is being output
hdmi_force_hotplug=1

# uncomment to force a specific HDMI mode (here we are forcing 800x480!)
hdmi_group=2
hdmi_mode=87
hdmi_cvt=800 400 60 6 0 0 0
hdmi_drive=1
EOF
#set aside 3rd processor for LED Screen
sudo sed -i -e 's/rootwait/rootwait isolcpus=3 /g' /boot/cmdline.txt


#Kill sound (From <https://github.com/hzeller/rpi-rgb-led-matrix>)
cat <<EOF | sudo tee /etc/modprobe.d/blacklist-rgb-matrix.conf
blacklist snd_bcm2835
EOF
sudo update-initramfs -u

#Install LED Panel Prereqs
#Required for installing APT Keys
sudo apt-get install dirmngr -y

if [ "$use_zerotier" != "${use_zerotier#[Yy]}" ] ;then
    #Install ZeroTier
    sudo apt-key adv --recv-key --keyserver keyserver.ubuntu.com 1657198823E52A61
    echo "deb https://download.zerotier.com/debian/stretch stretch main" | sudo tee -a /etc/apt/sources.list
    #ZeroTier (From <http://blog.mxard.com/persistent-iptables-on-raspberry-pi-raspbian>)
    sudo apt-get update
    sudo apt-get install -y iptables-persistent zerotier-one

    #Setup zerotier
    #sudo ./zerotier-one -d
    sudo zerotier-cli join $zerotier_network_id 

    #Log into my.zerotier.com and enable account

    #Setup forwarding and firewall for forwarding of ZeroTier Traffic (From <https://support.zerotier.com/knowledgebase.php?article=ZWFhNWMyMTZjODY1ODcwNmFhZmJjYmRhN2I5MjRhOGQ_>)
    sudo sed -i -e 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

cat <<EOF | sudo tee /etc/iptables/rules.v4
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s $zerotier_ip_range -o wlan0 -j MASQUERADE
COMMIT
*filter
:INPUT ACCEPT [0:0]
:FORWARD DROP [0:0]
-A FORWARD -i zt+ -s $zerotier_ip_range -d 0.0.0.0/0 -j ACCEPT
-A FORWARD -i wlan0 -s 0.0.0.0/0 -d $zerotier_ip_range -j ACCEPT
:OUTPUT ACCEPT [0:0]
COMMIT
EOF

    if [ "$zerotier_dns_server" != "" ] ;then
        #DNS workaround 
        sudo sed -i -e "s/\:PREROUTING ACCEPT \[0\:0\]/\:PREROUTING ACCEPT [0\:0]\n-A PREROUTING -dport 53 -j DNAT --to-destination $zerotier_dns_server/g" /etc/iptables/rules.v4
        #-A PREROUTING -dport 53 -j DNAT --to-destination $zerotier_dns_server
    fi
    #sudo reboot
    #In case of trouble check routing table https://unix.stackexchange.com/questions/180553/proper-syntax-to-delete-default-route-for-a-particular-interface

    #On Machine you want to enable full tunnel run 
    #sudo zerotier-cli set $zerotier_network_id allowDefault=true
fi

#Install screen clone (rpi-fb-matrix) (From <https://github.com/adafruit/rpi-fb-matrix>)
#RPI-fb-matrix (From <https://github.com/adafruit/rpi-fb-matrix>)
sudo apt-get install -y git build-essential libconfig++-dev

git clone --recursive https://github.com/antgiant/rpi-fb-matrix.git
cd rpi-fb-matrix/rpi-rgb-led-matrix/
git checkout master
git pull
cd ..
sudo sed -i -e 's/HARDWARE_DESC=adafruit-hat/HARDWARE_DESC=adafruit-hat-pwm/g' ~/rpi-fb-matrix/Makefile
sudo sed -i -e 's/export USER_DEFINES=-DRGB_SLOWDOWN_GPIO=1/export USER_DEFINES=-DRGB_SLOWDOWN_GPIO=2/g' ~/rpi-fb-matrix/Makefile
#nano Makefile 
#(-pwm and 2)
sudo sed -i -e 's/#DEFINES+=-DFIXED_FRAME_MICROSECONDS=5000/DEFINES+=-DFIXED_FRAME_MICROSECONDS=5000/g' ~/rpi-fb-matrix/rpi-rgb-led-matrix/lib/Makefile
#nano ~/rpi-fb-matrix/rpi-rgb-led-matrix/lib/Makefile
#Uncomment “DEFINES+=-DFIXED_FRAME_MICROSECONDS=5000”
make 

#Raspbian GUI  (From <https://lb.raspberrypi.org/forums/viewtopic.php?f=66&t=133691>)
sudo apt-get install -y raspberrypi-ui-mods
#sudo apt-get install --no-install-recommends xserver-xorg
#sudo apt-get install --no-install-recommends xinit

#(Optional full GUI) 
#sudo apt-get install raspberrypi-ui-mods
#sudo apt-get install lightdm

#(Optional minimal GUI)
#sudo apt-get install --no-install-recommends raspberrypi-ui-mods lxsession

#Install stellarium 
sudo apt-get install -y stellarium

#Update to version in Debian Repo
#Add Debian Mirrors (From <https://packages.debian.org/sid/armhf/stellarium/download>)
echo "deb http://ftp.de.debian.org/debian sid main" | sudo tee -a /etc/apt/sources.list

#Fix missing Keys (From <https://blog.sleeplessbeastie.eu/2017/11/02/how-to-fix-missing-dirmngr/>)
#sudo apt-key adv --recv-key --keyserver keyserver.ubuntu.com  [Insert here your missing key ID]
sudo apt-key adv --recv-key --keyserver keyserver.ubuntu.com 8B48AD6246925553
sudo apt-key adv --recv-key --keyserver keyserver.ubuntu.com 7638D0442B90D010
				 
#gpg -a --export [Insert here your missing key ID] | sudo apt-key add - (From <https://raspberrypi.stackexchange.com/a/56305>)
sudo apt-get update

#----------------------------------------------
#sudo apt-get install --only-upgrade stellarium
#sudo apt-get install stellarium
#----------------------------------------------

#When that doesn't work compile it
#Install prerequisites (https://github.com/Stellarium/stellarium/wiki/Linux-build-dependencies)
#sudo apt-get install build-essential cmake zlib1g-dev libgl1-mesa-dev gcc g++ graphviz doxygen gettext git qtscript5-dev libqt5svg5-dev qttools5-dev-tools qttools5-dev libqt5opengl5-dev qtmultimedia5-dev libqt5multimedia5-plugins libqt5serialport5 libqt5serialport5-dev qtpositioning5-dev libgps-dev libqt5positioning5 libqt5positioning5-plugins

#sudo vi /etc/apt/sources.list 
#Comment out this line
#deb http://ftp.de.debian.org/debian sid main 
sudo sed -i -e 's/deb http:\/\/ftp.de.debian.org\/debian sid main/#deb http:\/\/ftp.de.debian.org\/debian sid main/g' /etc/apt/sources.list

sudo apt-get update

#Install Stellarium Clock Script and set it to update once a day
mkdir ~/.stellarium
cd ~/.stellarium
git clone https://github.com/antgiant/stellarium_clock.git scripts
cd scripts
cat <<EOF | tee location.js
lat = $lat;
lon = $lon;
alt = $alt;
place = "$place";
EOF
#nano location.js
#Add required data

#Update Clock Script Once a Day
(crontab -l ; echo "0 1 * * * git -C ~/.stellarium/scripts/ pull")| crontab -
#crontab -e
#0 1 * * * git -C ~/.stellarium/scripts/ pull

#Set system to reboot once a day at 2 am just for good measure
(sudo crontab -l ; echo "0 2 * * * /sbin/reboot")| sudo crontab -
#sudo crontab -e
#0 2 * * * /sbin/reboot

#Set Stellarium to autostart
: <<'END'
cat <<EOF | tee -a ~/.xinitrc
xset s off     # don't activate screensaver
xset -dpms     # disable DPMS (Energy Star) features.
xset s noblank # don't blank the video device
stellarium --startup-script=clock.ssc
EOF
END
#nano .xinitrc
#	xset s off     # don't activate screensaver
#	xset -dpms     # disable DPMS (Energy Star) features.
#	xset s noblank # don't blank the video device
#	stellarium --startup-script=clock.ssc

#Set LED Screen & Stellarium to autostart
sed -i -e 's/@xscreensaver/sudo \/home\/pi\/rpi-fb-matrix\/rpi-fb-matrix --led-chain=2 --led-brightness=100 --led-daemon --led-pwm-dither-bits=1\
@xset s off     # do not activate screensaver\
@xset -dpms     # disable DPMS (Energy Star) features.\
@xset s noblank # do not blank the video device\
stellarium --startup-script=clock.ssc\
@xscreensaver/g' /home/pi/.config/lxsession/LXDE-pi/autostart

#Set X to Autostart
: <<'END'
cat <<EOF | tee -a ~/.bashrc
startx
EOF
END
#nano .bashrc
#   startx
