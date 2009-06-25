COMPONENT=UnderwaterAppC
#BUILD_EXTRA_DEPS += TestSerial.class
#CLEAN_EXTRA = *.class TestSerialMsg.java
PFLAGS += -DTOSH_DATA_LENGTH=248
CFLAGS += -I$(TOSDIR)/lib/T2Hack

include $(MAKERULES)
all:
	make micaz sim-sf
	g++ -g -c -o UWTos.o UWTos.c -I$(TOSDIR)/lib/tossim/ -I/$(TOSDIR)/lib/tossim/sf
	g++ -o UWTos UWTos.o simbuild/micaz/tossim.o simbuild/micaz/sim.o simbuild/micaz/c-support.o simbuild/micaz/c-sf.o simbuild/micaz/sf.o simbuild/micaz/throttle.o

#all:
#	make micaz sim-sf
#	mig python -target=null -python-classname=GRSerialMsg GRSerial.h serial_packet_msg -o GRSerialMsg.py
#	mig python -target=null -python-classname=TapSerialMsg TapSerial.h serial_packet_msg -o TapSerialMsg.py

#TestSerial.class: $(wildcard *.java) TestSerialMsg.java
#	javac -target 1.4 -source 1.4 *.java

#TestSerialMsg.java:
#	mig java -target=null $(CFLAGS) -java-classname=TestSerialMsg TestSerial.h test_serial_msg -o $@



