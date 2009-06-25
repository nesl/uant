#ifndef ALOHA_H
#define ALOHA_H
enum {
  AM_ALOHA_PACKET = 43,
  ALOHA_ACK = 30,
  //a random number will be generated between min and max backoff
  ALOHA_MAX_BACKOFF = 1000,
  ALOHA_MIN_BACKOFF = 500,
  ALOHA_ATTEMPTS = 3,
};

typedef nx_struct aloha_packet {
  nx_uint8_t src;
  nx_uint8_t dst;
  nx_uint8_t control;
} aloha_packet_t;

    
#endif
