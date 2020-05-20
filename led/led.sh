#! /vendor/bin/sh

# set act-led trigger function
cmdline=$(cat /proc/cmdline)
storage=`echo $cmdline|awk '{print match($0,"storagemedia=emmc")}'`;

if [ $storage -gt 0 ]; then
    #emmc
    echo mmc1 > /sys/class/leds/act-led/trigger
else
    #sdcard
    echo mmc0 > /sys/class/leds/act-led/trigger
fi