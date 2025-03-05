#!/bin/bash

# this is a startup script so your keyboard gets updated on boot
# https://github.com/felipeheuer/usb_kb_layout

if [ -f /opt/usb_kb_layout/usb_kb_layout_wrapper.sh ]; then
  . /opt/usb_kb_layout/usb_kb_layout_wrapper.sh
fi
