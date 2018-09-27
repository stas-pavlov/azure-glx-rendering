#!/bin/bash 

sudo nvidia-xconfig --busid `nvidia-xconfig --query-gpu-info | grep BusID | sed 's/PCI BusID : PCI:/PCI:/'`
sudo sed -i 's/console/anybody/g'  /etc/X11/Xwrapper.config