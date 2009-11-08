#!/usr/bin/env python
#
# Copyright 2005,2006 Free Software Foundation, Inc.
# 
# This file is part of GNU Radio
# 
# GNU Radio is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
# 
# GNU Radio is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with GNU Radio; see the file COPYING.  If not, write to
# the Free Software Foundation, Inc., 51 Franklin Street,
# Boston, MA 02110-1301, USA.
# 


# /////////////////////////////////////////////////////////////////////////////
#
#    This code sets up up a virtual ethernet interface (typically gr0),
#    and relays packets between the interface and the GNU Radio PHY+MAC
#
#    What this means in plain language, is that if you've got a couple
#    of USRPs on different machines, and if you run this code on those
#    machines, you can talk between them using normal TCP/IP networking.
#
# /////////////////////////////////////////////////////////////////////////////


from gnuradio import gr, gru, modulation_utils, packet_utils
from gnuradio import usrp
from gnuradio import eng_notation
from gnuradio.eng_option import eng_option
from optparse import OptionParser

import random
import time
import struct
import sys
import os

#tos stuff
from GRSerialMsg import *
from AlohaMsg import *
from RadioCountMsg import *
from tinyos.message import *
from tinyos.packet.Serial import Serial

# from current dir
from transmit_path import transmit_path
from receive_path import receive_path
import fusb_options


# /////////////////////////////////////////////////////////////////////////////
#                             the flow graph
# /////////////////////////////////////////////////////////////////////////////

class my_top_block(gr.top_block):

    def __init__(self, mod_class, demod_class,
                 rx_callback, options):

        gr.top_block.__init__(self)
        self.node_id = options.nodeid
        self.txpath = transmit_path(mod_class, options)
        self.rxpath = receive_path(demod_class, rx_callback, options)

        self.connect(self.txpath);
        self.connect(self.rxpath);
        
    def send_pkt(self, payload='', eof=False):
        return self.txpath.send_pkt(payload, eof)


# /////////////////////////////////////////////////////////////////////////////
#                           Carrier Sense MAC
# /////////////////////////////////////////////////////////////////////////////

class cs_mac(object):
    """
    Reads packets from TinyOS, and sends them to the PHY.
    Receives packets from the PHY via phy_rx_callback, and sends them to TinyOS.
    """
    #removed tun_tap
    def __init__(self, verbose=False):
        self.verbose = verbose
        self.tb = None             # top block (access to PHY)

        self.mif = MoteIF.MoteIF()
        self.tos_source = self.mif.addSource("sf@localhost:9003")
        #listen for all of these messages
        self.mif.addListener(self, RadioCountMsg)
        self.mif.addListener(self, GRSerialMsg)
        self.mif.addListener(self, AlohaMsg)


    def receive(self, src, msg): #received from TOS not from radio, need to send out to radio
        print "received from tos, sending to GR"
        #print map(lambda (x): hex(ord(x)), msg.dataGet())
        self.tb.send_pkt(msg.dataGet())

    def send_to_tos(self, payload):
        data = chr(Serial.TOS_SERIAL_ACTIVE_MESSAGE_ID) #it is a serial message
        data += chr(0)
        #data += chr(self.tb.node_id)
        if int(ord(payload[2])) == 255:
                data += chr(self.tb.node_id)
        else:
                data += payload[2]
        data += payload[3:len(payload)]
        #print map(lambda (x): hex(ord(x)), data)
        self.tos_source.writePacket(data) #write that all

    def set_top_block(self, tb):
        self.tb = tb

    def phy_rx_callback(self, ok, payload):
        """
        Invoked by thread associated with PHY to pass received packet up.

        @param ok: bool indicating whether payload CRC was OK
        @param payload: contents of the packet (string)
        """
        
        if self.verbose:
            print "Rx: ok = %r  len(payload) = %4d" % (ok, len(payload))
        if ok: #need to actually write to serial out
            self.send_to_tos(payload)



# /////////////////////////////////////////////////////////////////////////////
#                                   main
# /////////////////////////////////////////////////////////////////////////////

def main():

    mods = modulation_utils.type_1_mods()
    demods = modulation_utils.type_1_demods()

    parser = OptionParser (option_class=eng_option, conflict_handler="resolve")
    expert_grp = parser.add_option_group("Expert")

    parser.add_option("-m", "--modulation", type="choice", choices=mods.keys(),
                      default='gmsk',
                      help="Select modulation from: %s [default=%%default]"
                            % (', '.join(mods.keys()),))

    parser.add_option("-v","--verbose", action="store_true", default=False)
    parser.add_option("-n", "--nodeid", type="int", default=None,
                              help="specify node ID")
    expert_grp.add_option("-c", "--carrier-threshold", type="eng_float", default=30,
                          help="set carrier detect threshold (dB) [default=%default]")
    expert_grp.add_option("","--tun-device-filename", default="/dev/net/tun",
                          help="path to tun device file [default=%default]")

    transmit_path.add_options(parser, expert_grp)
    receive_path.add_options(parser, expert_grp)

    for mod in mods.values():
        mod.add_options(expert_grp)

    for demod in demods.values():
        demod.add_options(expert_grp)

    fusb_options.add_options(expert_grp)

    (options, args) = parser.parse_args ()
    if len(args) != 0:
        parser.print_help(sys.stderr)
        sys.exit(1)

    if options.rx_freq is None or options.tx_freq is None:
        sys.stderr.write("You must specify -f FREQ or --freq FREQ\n")
        parser.print_help(sys.stderr)
        sys.exit(1)

    # open the TUN/TAP interface
    #(tun_fd, tun_ifname) = open_tun_interface(options.tun_device_filename)

    # Attempt to enable realtime scheduling
    r = gr.enable_realtime_scheduling()
    if r == gr.RT_OK:
        realtime = True
    else:
        realtime = False
        print "Note: failed to enable realtime scheduling"


    # If the user hasn't set the fusb_* parameters on the command line,
    # pick some values that will reduce latency.

    if options.fusb_block_size == 0 and options.fusb_nblocks == 0:
        if realtime:                        # be more aggressive
            options.fusb_block_size = gr.prefs().get_long('fusb', 'rt_block_size', 1024)
            options.fusb_nblocks    = gr.prefs().get_long('fusb', 'rt_nblocks', 16)
        else:
            options.fusb_block_size = gr.prefs().get_long('fusb', 'block_size', 4096)
            options.fusb_nblocks    = gr.prefs().get_long('fusb', 'nblocks', 16)
    
    #print "fusb_block_size =", options.fusb_block_size
    #print "fusb_nblocks    =", options.fusb_nblocks

    # instantiate the MAC
    mac = cs_mac(verbose=False)

    # build the graph (PHY)
    tb = my_top_block(mods[options.modulation],
                      demods[options.modulation],
                      mac.phy_rx_callback,
                      options)

    mac.set_top_block(tb)    # give the MAC a handle for the PHY

    if tb.txpath.bitrate() != tb.rxpath.bitrate():
        print "WARNING: Transmit bitrate = %sb/sec, Receive bitrate = %sb/sec" % (
            eng_notation.num_to_str(tb.txpath.bitrate()),
            eng_notation.num_to_str(tb.rxpath.bitrate()))
             
    print "modulation:     %s"   % (options.modulation,)
    print "freq:           %s"      % (eng_notation.num_to_str(options.tx_freq))
    print "bitrate:        %sb/sec" % (eng_notation.num_to_str(tb.txpath.bitrate()),)
    print "samples/symbol: %3d" % (tb.txpath.samples_per_symbol(),)
    #print "interp:         %3d" % (tb.txpath.interp(),)
    #print "decim:          %3d" % (tb.rxpath.decim(),)

    tb.rxpath.set_carrier_threshold(options.carrier_threshold)


    tb.start()    # Start executing the flow graph (runs in separate threads)

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
