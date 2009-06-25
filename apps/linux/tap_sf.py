#!/usr/bin/python
from __future__ import division ## default to floating points
import re
import random
import time
import struct
import sys
import os
import math
from gnuradio import gr
#tos stuff
from tinyos.message import *
from tinyos.message.Message import *
from TapSerialMsg import *
from tinyos.message.SerialPacket import *
from tinyos.packet.Serial import Serial
#needed to decode the packets received from linux
import impacket
from impacket.ImpactDecoder import *
from impacket import ImpactDecoder, ImpactPacket
import scapy
# Linux specific...
# TUNSETIFF ifr flags from <linux/tun_if.h>

IFF_TUN		= 0x0001   # tunnel IP packets
IFF_TAP		= 0x0002   # tunnel ethernet frames
IFF_NO_PI	= 0x1000   # don't pass extra packet info
IFF_ONE_QUEUE	= 0x2000   # beats me ;)

#TOS FLAGS
#MSG_HEADER_LENGTH	= 8
LINUX_GROUP_TYPE	= 44
NET_ADDR 		= '192.168.200'
file_out = open('tap_sf_out.txt','w')

def open_tun_interface(tun_device_filename):
    from fcntl import ioctl
    
    mode = IFF_TAP | IFF_NO_PI
    TUNSETIFF = 0x400454ca

    tun = os.open(tun_device_filename, os.O_RDWR)
    ifs = ioctl(tun, TUNSETIFF, struct.pack("16sH", "gr%d", mode))
    ifname = ifs[:16].strip("\x00")
    return (tun, ifname)
    

class os_read(object):
    def __init__(self, tun_fd, verbose=True):
        self.tun_fd = tun_fd       # file descriptor for TUN/TAP interface
        self.verbose = verbose

	self.write_count = 0
	self.read_count = 0
	#create MoteIF, add a listener (when message comes function receive is called), and get handle of source using port 9003 (to send to)
        self.mif = MoteIF.MoteIF()
	self.tos_source = self.mif.addSource("sf@localhost:9003")
	self.mif.addListener(self, TapSerialMsg)


    def receive(self, src, msg): #received from TOSSIM not from radio, need to send to Linux
	#1) get data from the message
	#2) chop of the header
	#3) record statistics to file
	payload = msg.dataGet()
	payload = payload[8:len(payload)]
	self.write_count += 1
	file_out.write("writing to linux: " + str(self.write_count) + "\n")
	file_out.write(str(map(lambda (x): hex(ord(x)), payload)))
	file_out.flush()
	os.write(self.tun_fd, payload)

    def send_to_tos(self, payload):
    	#keeping statistics
	self.read_count += 1
	file_out.write("read from linux: " + str(self.read_count) + "\n")
	file_out.write(str(map(lambda (x): hex(ord(x)), payload)))
	file_out.flush()
	b = scapy.Ether(payload)
	try:
		des =  b.payload.dst #get the destiation address
		src = b.payload.src #get the source address
		#switching dest and source and they need to switch back in tinyos code
		dest = int(src[src.rfind('.')+1:len(src)]) #get last octet of source address
		src = int(des[des.rfind('.')+1:len(des)]) #get last octet of dest address
	except:
		#print b.show() #nice function showing extensive packet information 
		des =  b.payload.pdst #get the destiation address
		src = b.payload.psrc #get the source address
		#switching dest and source and they need to switch back in tinyos code
		dest = int(src[src.rfind('.')+1:len(src)]) #get last octet of source address
		src = int(des[des.rfind('.')+1:len(des)]) #get last octet of dest address
	if (src > 254):
		src = 0xff
	if (des.startswith(NET_ADDR)):
		self.write_packet(dest, src,LINUX_GROUP_TYPE, payload)
	
        #self.mif.sendMsg(self.tos_source, 0, 137, 0,t)

    def write_packet(self, dest, src, type, payload):
	msg = SerialPacket(None)
	#using set_header info to set header contents
	msg.set_header_dest(dest)
	msg.set_header_src(src)
	msg.set_header_group(type)
	msg.set_header_type(type) 
	msg.set_header_length(len(payload)) #might need to be payload + header length
	data = chr(Serial.TOS_SERIAL_ACTIVE_MESSAGE_ID) #it is a serial message
	data += msg.dataGet()[0:msg.offset_data(0)] #header info
	data += payload
	self.tos_source.writePacket(data) #write that all

    def main_loop(self):
	counter = 0
        while 1:
	    #now we need to get the payload from OS
	    #need to send to TOS 10*1024 is max length of the read 
	    #although one should explicity set MTU to less than 248
	    payload = os.read(self.tun_fd, 10*1024)
	    #from_linux.write(str( map(lambda (x): hex(ord(x)), payload)))
            if not payload:
                break
	    self.send_to_tos(payload)




# /////////////////////////////////////////////////////////////////////////////
#                                   main
# /////////////////////////////////////////////////////////////////////////////

def main():

    # open the TUN/TAP interface
    (tun_fd, tun_ifname) = open_tun_interface("/dev/net/tun")

    r = gr.enable_realtime_scheduling()
    if r == gr.RT_OK:
        realtime = True
    else:
        realtime = False
        print "Note: failed to enable realtime scheduling"


    to_tos = os_read(tun_fd, verbose=True)
    to_tos.main_loop()    # don't expect this to return...
                

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
