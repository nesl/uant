#!/usr/bin/python
# Copyright (c) 2007 Toilers Research Group - Colorado School of Mines
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# - Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the
#   distribution.
# - Neither the name of Toilers Research Group - Colorado School of 
#   Mines  nor the names of its contributors may be used to endorse 
#   or promote products derived from this software without specific
#   prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL STANFORD
# UNIVERSITY OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
#*
# Author: Chad Metcalf
# Date: July 9, 2007
#
# A simple TOSSIM driver for the TestSerial application that utilizes 
# TOSSIM Live extensions.
#
import sys
import time
import curses
import curses.ascii
from TOSSIM import *
from tinyos.tossim.TossimApp import *

t = Tossim([])
m = t.mac()
r = t.radio()
tapsf = SerialForwarder(9003)
throttle = Throttle(t, 10)

#t.addChannel("counter", sys.stdout);
#t.addChannel("receive", sys.stdout);
#t.addChannel("tap", sys.stdout);
#t.addChannel("gr", sys.stdout);
#t.addChannel("RadioCountToLedsC", sys.stdout);
#t.addChannel("SimMoteP", sys.stdout);
#t.addChannel("Serial", sys.stdout);
#t.addChannel("MAC", sys.stdout);
#t.addChannel("control", sys.stdout);


m = t.getNode(3)
time.sleep(5);
m.bootAtTime(0)
tapsf.process();
throttle.initialize();

while(1):
  throttle.checkThrottle();
  t.runNextEvent();
  tapsf.process();

#throttle.printStatistics()
