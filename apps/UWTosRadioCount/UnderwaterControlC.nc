
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
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

#include "Timer.h"
#include "Serial.h"
//#include "RadioCountToLeds.h"
#include "AM.h"
void GRSendFromQueue();
module UnderwaterControlC {
  provides{
    interface AMSend as SendApp;
    interface Receive as ReceiveApp;
  }
  uses {
    interface SplitControl as TapControl;
    interface SplitControl as GRControl;
    interface Queue<message_t> as TapQueue;
    interface Queue<message_t> as GRQueue; //queue packets going out to GNU Radio
    interface Boot;
    interface Receive as GRReceive;
    interface Receive as TapReceive;
    interface Packet as GRPacket;
    interface Packet as TapPacket;
    interface AMPacket as GRAMPacket;
    interface AMPacket as TapAMPacket;
    interface Timer<TMilli> as tapTimer;

    //interface AMSend as LinuxAppSend;
    //interface Receive as LinuxAppReceive;

    interface Timer<TMilli> as MilliTimer;
    interface AMSend as GRSend;
    interface AMSend as TapSend;
  }
}
implementation {

  serial_packet_t* packet_payload;
  message_t tap_msg;
  message_t gr_msg;
  uint8_t i;
  uint8_t temp_dest;
  bool grlocked = FALSE;
  bool taplocked = FALSE;
  am_addr_t dest;
  message_t buf;
  message_t* gr_packet = &buf;
  error_t send_error;
 


  event void Boot.booted() {
    //packet_payload = (serial_packet_t*)call Packet.getPayload(&packet, sizeof(serial_packet_t));
    call GRControl.start();
  }
  
  event void MilliTimer.fired() {
    dbg("counter", "timer fired");
  }

  command error_t SendApp.send(am_addr_t addr, message_t* msg, uint8_t len)
  {
	//need to add to sending queue
	//sendDone goes through GRSendDone and then the next message is
	//taken from the queue
    	call GRQueue.enqueue(*msg);
    	if (grlocked) {
      		dbg("control", "queued message\n");
    	}
	else {
		gr_msg = call GRQueue.dequeue();
		//send_error = call GRSend.send(0x7e00,&gr_msg ,call GRPacket.payloadLength(&gr_msg));
		//send_error = call GRSend.send(0x3,&gr_msg , sizeof(radio_count_msg_t));
		send_error = call GRSend.send(call GRAMPacket.destination(&gr_msg),&gr_msg , sizeof(radio_count_msg_t));
		if(send_error  == SUCCESS){
			grlocked = TRUE;
			dbg("control","sent from queue1\n");
		}
		else
		{
			dbg("control","COULD NOT SEND!!!\n");
		}
		return send_error;
	}
	return SUCCESS;
  }


  //we have just received something from gnuradio
  //and now it should be sent up to linux if 
  //it is for us
  //send ACK
  event message_t* GRReceive.receive(message_t* msg, 
				   void* payload, uint8_t len) {

	if(call GRAMPacket.group(msg) == AM_TAP_SERIAL_MSG)
	{
		call TapQueue.enqueue(*msg);
		if (taplocked) {
	    		dbg("tap", "added one to queue %x\n", len);
	    	}
		else{
			
			tap_msg = call TapQueue.dequeue();
			call tapTimer.startOneShot(TAP_WATCHDOG_TIMER);
			if (call TapSend.send(AM_BROADCAST_ADDR, &tap_msg, call TapPacket.payloadLength(&tap_msg)) == SUCCESS) {
				taplocked = TRUE;
				dbg("tap","sent to linux\n");
			}
		      	else{
				dbg("tap", "could not send to linux\n");
			}
		}
		return msg;
	}
	else
	{
		return signal ReceiveApp.receive(msg,payload,len);
	}
  }

  //received from linux---need to send over USRP through water
  event message_t* TapReceive.receive(message_t* msg, 
				   void* payload, uint8_t len) {
      *gr_packet = *msg;
      dbg("control", "RECEIVED FROM LINUX\n");
      //need to swap src and dest
      temp_dest = gr_packet->header[3];
      gr_packet->header[3] = gr_packet->header[1];
      gr_packet->header[1] = temp_dest;	

	
    //trying to always add from that and then just take from queue
    call GRQueue.enqueue(*gr_packet);
      
    if (grlocked) {//do nothing
    }
    else {
  	if(call GRQueue.empty() == FALSE){
		gr_msg = call GRQueue.dequeue();
		if( call GRSend.send(call GRAMPacket.destination(&gr_msg),&gr_msg ,call GRPacket.payloadLength(&gr_msg)) == SUCCESS){
			grlocked = TRUE;
			dbg("receive","sent from queue\n");
		}
		else
		{
			dbg("receive","COULD NOT SEND!!!\n");
		}
	}
	else {
		grlocked = FALSE;
	}
    }

     return msg;
  }



  event void GRSend.sendDone(message_t* msg, error_t error) {
	//if error is SUCCESS then the messaged was acked 
	//if FAIL the message was not acked within maximum number of attempts
	//currently either wat just grab the next message and send it
  	if(call GRQueue.empty() == FALSE){
		dbg("receive","Getting Ready To Send Again\n");
		gr_msg = call GRQueue.dequeue();
		if( call GRSend.send(call GRAMPacket.destination(&gr_msg),&gr_msg ,call GRPacket.payloadLength(&gr_msg)) == SUCCESS){
			grlocked = TRUE;
			dbg("receive","sent from queue\n");
		}
		else
		{
			dbg("receive","COULD NOT SEND!!!\n");
		}
	}
	else {
		dbg("receive","grlocked is false\n");
		signal SendApp.sendDone(msg, error);
		grlocked = FALSE;
	}
  }

  event void GRControl.startDone(error_t err) {}

 
  event void GRControl.stopDone(error_t err) {}

  event void TapControl.startDone(error_t err) {}
  event void TapControl.stopDone(error_t err) {}

  //when finished sending, check for more messages on the queue
  event void TapSend.sendDone(message_t* msg, error_t error) {
	call tapTimer.stop();
	dbg("receive","TAP SEND DONE SIGNALED\n");
  	if(call TapQueue.empty() == FALSE){
		tap_msg = call TapQueue.dequeue();
		dest = AM_BROADCAST_ADDR; //clearly we want all listeners to get it (although just one is needed)
		//dbg("receive","queuemsg size %x\n", call Packet.payloadLength(&tap_msg));
		call tapTimer.startOneShot(TAP_WATCHDOG_TIMER);
		if(call TapSend.send(dest, &tap_msg,call TapPacket.payloadLength(&tap_msg)) == SUCCESS){
			dbg("tap","sent\n");
		}
	}
	else {
		taplocked = FALSE;
	}
		
  }
  
  event void tapTimer.fired(){
  	dbg("tap", "TAP TIMER FIRED!!!!!\n");
  	if(call TapQueue.empty() == FALSE){
		tap_msg = call TapQueue.dequeue();
		dest = AM_BROADCAST_ADDR; //clearly we want all listeners to get it (although just one is needed)
		dbg("tap", "Destination %x\n", dest);
		//dbg("receive","queuemsg size %x\n", call Packet.payloadLength(&tap_msg));
		call tapTimer.startOneShot(TAP_WATCHDOG_TIMER);
		if(call TapSend.send(dest, &tap_msg,call TapPacket.payloadLength(&tap_msg)) == SUCCESS){
			dbg("tap","sent\n");
		}
	}
	else {
		taplocked = FALSE;
	}
  }
  command void* SendApp.getPayload(message_t* m, uint8_t len)
  {
  	return call GRSend.getPayload(m, len);
  }
  
  command uint8_t SendApp.maxPayloadLength() {
  	return call GRSend.maxPayloadLength();
  }
  
  command error_t SendApp.cancel(message_t* msg)
  {	
  	return call GRSend.cancel(msg);
  }

}
