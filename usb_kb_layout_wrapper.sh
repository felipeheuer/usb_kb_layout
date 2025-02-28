#!/bin/bash

# this is a wrapper script so udev can call the main script non-blocking
# https://github.com/felipeheuer/usb_kb_layout

/opt/usb_kb_layout/usb_kb_layout.sh &
