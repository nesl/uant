// $Id: TestSerialAppC.nc,v 1.5 2006/12/12 18:22:50 vlahan Exp $

/*									tab:4
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2005 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

/**
 * Application to test that the TinyOS java toolchain can communicate
 * with motes over the serial port. The application sends packets to
 * the serial port at 1Hz: the packet contains an incrementing
 * counter. When the application receives a counter packet, it
 * displays the bottom three bits on its LEDs. This application is
 * very similar to RadioCountToLeds, except that it operates over the
 * serial port. There is Java application for testing the mote
 * application: run TestSerial to print out the received packets and
 * send packets to the mote.
 *
 *  @author Gilman Tolle
 *  @author Philip Levis
 *  
 *  @date   Aug 12 2005
 *
 **/

#include "Serial.h"
#include "UWTosConstants.h" 
#include "RadioCountToLeds.h" 

configuration UnderwaterAppC {}
implementation {
  components UnderwaterMacC as Mac;
 
  components UnderwaterControlC as Con, MainC, LedsC;
  components RadioCountToLedsC as App;
  components SerialActiveMessageC as TapAM;
  components ActiveMessageC as GRAM;
  components ActiveMessageC as GR;
  components SerialActiveMessageC as MAC;
  components ActiveMessageC as RadioAM;
  components RandomC as AlohaRand;

  components new QueueC(message_t, QUEUE_SIZE) as GRQueue;
  components new QueueC(message_t, QUEUE_SIZE) as TapQueue;
  components new TimerMilliC();
  components new TimerMilliC() as RadioTime;
  components new TimerMilliC() as MacTime;
  components new TimerMilliC() as TapTime;
 

  Con.Boot -> MainC.Boot;
  

  //Con.MACReceive -> MAC.Receive[AM_MAC_MSG];
  //Con.MACSend -> MAC.AMSend[AM_MAC_MSG];
  
  App.Boot -> MainC.Boot;
  
  App.Receive -> Con.ReceiveApp;
  App.AMSend -> Con.SendApp;
  App.AMControl -> RadioAM;
  App.Leds -> LedsC;
  App.MilliTimer -> RadioTime;
  App.Packet -> RadioAM;
  
  Mac.GRReceive -> MAC.Receive[6];
  Mac.GRSend -> MAC.AMSend[6];
  //Mac.GRReceive -> MAC.Receive[45];
  //Mac.GRSend -> MAC.AMSend[45];

  Mac.MACReceive -> MAC.Receive[AM_ALOHA_PACKET];
  Mac.MACSend -> MAC.AMSend[AM_ALOHA_PACKET];
  Mac.macTimer -> MacTime;
  Mac.rand -> AlohaRand;

  Mac.MACControl -> MAC;
  Mac.Packet -> MAC;
  

  Con.GRControl -> GRAM;
  Con.GRReceive -> Mac.ReceiveGR;
  Con.GRSend -> Mac.SendGR;
  Con.GRPacket -> GRAM;
  Con.GRAMPacket -> GRAM;
  Con.GRQueue -> GRQueue;
  Con.tapTimer -> TapTime;

  Con.TapControl -> TapAM;
  Con.TapReceive -> TapAM.Receive[AM_TAP_SERIAL_MSG];
  Con.TapSend -> TapAM.AMSend[AM_TAP_SERIAL_MSG];
  Con.TapPacket -> TapAM;
  Con.TapAMPacket -> TapAM;
  Con.TapQueue -> TapQueue;

  Con.MilliTimer -> TimerMilliC;
}


