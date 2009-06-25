#!/bin/sh
#mig python -target=null -python-classname=TapSerialMsg TapSerial.h serial_packet -o TapSerialMsg.py
mig python -target=null -python-classname=AlohaMsg Aloha.h aloha_packet -I/usr/local/src/t2/t2_4_1_09/tinyos-2.x/tos -o AlohaMsg.py
