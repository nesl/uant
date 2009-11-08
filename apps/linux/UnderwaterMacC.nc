#include "Serial.h"
#include "AM.h"
#include "Aloha.h"
module UnderwaterMacC
{
    provides 
    {
        interface AMSend as SendGR;
        interface Receive as ReceiveGR;
    }
    uses 
    {
        //interface SerialActiveMessageC as AM;
        interface SplitControl as MACControl;
        interface Receive as GRReceive;
        interface AMSend as GRSend;
        interface Receive as MACReceive;
        interface AMSend as MACSend;
        interface AMPacket as Packet;
            interface Timer<TMilli> as macTimer;
        interface Random as rand;
    }
}
implementation 
{
    aloha_packet_t ack;
    message_t mac_packet;
    //current message
    message_t* current_msg;
    uint8_t current_len;
    am_addr_t current_addr;
    bool been_acked = FALSE;
    uint16_t acks_sent = 0;
    uint16_t msg_sent = 0;
    uint8_t attempts = 0;


    event message_t* GRReceive.receive(message_t* msg, 
                   void* payload, uint8_t len) {
        aloha_packet_t* buf = (aloha_packet_t*)call MACSend.getPayload(&mac_packet, sizeof(aloha_packet_t));
        //need to send an ACK to Dest
        //note in GnuRadio a CRC check is done, so if it has made it
        //this far there is not an error, so we can just send ACK with confidence
        if(call Packet.source(msg) != TOS_NODE_ID)
        {
            acks_sent++;
            dbg("MAC", "SENDING ACK\n");
            buf -> src = TOS_NODE_ID;
            buf -> dst = call Packet.source(msg);
            buf -> control = ALOHA_ACK;
            dbg("MAC", "ACKS SENT: %u\n", acks_sent);
            call MACSend.send((buf -> dst), &mac_packet, sizeof(aloha_packet_t));
            return signal ReceiveGR.receive(msg, payload, len);
        }
        return msg;
    }   
    event void macTimer.fired(){
        if(been_acked){
            //do nothing
            dbg("MAC", "Attempts: %u\n", attempts);
        }
        else if(attempts >= ALOHA_ATTEMPTS){
            signal SendGR.sendDone(current_msg, FAIL);
        }
        else{
            msg_sent++;
            attempts++;
            dbg("MAC", "MSGS SENT: %u\n", msg_sent);
            dbg("MAC", "Attempts: %u\n", attempts);
            call GRSend.send(current_addr, current_msg, current_len);
            call macTimer.startOneShot((call rand.rand16() % ALOHA_MAX_BACKOFF) + ALOHA_MIN_BACKOFF);
        }
    }
    command error_t SendGR.send(am_addr_t addr, message_t* msg, uint8_t len)
    {
        msg_sent++;
        current_addr = addr;
        current_msg = msg;
        current_len = len;
        been_acked = FALSE;
        attempts = 1;
        dbg("MAC", "MSGS SENT: %u\n", msg_sent);
        dbg("MAC", "Sent message to GNU Radio\n");
        call macTimer.startOneShot((call rand.rand16() % ALOHA_MAX_BACKOFF) + ALOHA_MIN_BACKOFF);
        return call GRSend.send(addr, msg, len);
    }

    //Received Control Message from MAC
    event message_t* MACReceive.receive(message_t* msg, void* payload, uint8_t len)
    {
        aloha_packet_t* macmsg = (aloha_packet_t*) payload;
        dbg("MAC", "RECEIVED ACK\n");
        call macTimer.stop();
        if (macmsg -> control == ALOHA_ACK && macmsg -> dst == TOS_NODE_ID){    
            //we have received an ACK, signal senddone to control
            been_acked = TRUE;
            signal SendGR.sendDone(current_msg, FAIL);
        }
        else
        {
            //dont need to do anything since ack is not for this node
        }
        return msg;
    }


    //dont do anything because a send done is generated when the ack is received
    event void GRSend.sendDone(message_t* msg, error_t result){
            dbg("MAC", "SEND DONE\n");
            //signal SendGR.sendDone(msg, SUCCESS);
    }
    //dont do anything here either
    event void MACSend.sendDone(message_t* msg, error_t result){}

    command void* SendGR.getPayload(message_t* m, uint8_t len)
    {
        return call GRSend.getPayload(m, len);
    }

    command uint8_t SendGR.maxPayloadLength() {
        return call GRSend.maxPayloadLength();
    }

    command error_t SendGR.cancel(message_t* msg)
    {   
        return call GRSend.cancel(msg);
    }
    event void MACControl.startDone(error_t err) {}
    event void MACControl.stopDone(error_t err) {}

}
