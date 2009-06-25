#!/usr/bin/perl
use strict;
use warnings;
my $min = $ARGV[0];
my $max = $ARGV[1];
my $retransmit = $ARGV[2];
if($ARGV[3])
{
	open (OUT, ">$ARGV[3]/Aloha.h");
}
else
{
	open (OUT, ">Aloha.h");
}
print OUT '#ifndef ALOHA_H'."\n";
print OUT '#define ALOHA_H'."\n";
print OUT 'enum {'."\n";
print OUT '  AM_ALOHA_PACKET = 43,'."\n";
print OUT '  ALOHA_ACK = 30,'."\n";
print OUT '  //a random number will be generated between min and max backoff'."\n";
print OUT '  ALOHA_MAX_BACKOFF = '.$max.','."\n";
print OUT '  ALOHA_MIN_BACKOFF = '.$min.','."\n";
print OUT '  ALOHA_ATTEMPTS = '.$retransmit.','."\n";
print OUT '};'."\n";
print OUT ''."\n";
print OUT 'typedef nx_struct aloha_packet {'."\n";
print OUT '  nx_uint8_t src;'."\n";
print OUT '  nx_uint8_t dst;'."\n";
print OUT '  nx_uint8_t control;'."\n";
print OUT '} aloha_packet_t;'."\n";
print OUT ''."\n";
print OUT '    '."\n";
print OUT '#endif'."\n";
close (OUT);

