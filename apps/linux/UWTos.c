#include <tossim.h>
#include <SerialForwarder.h>
#include <Throttle.h>
#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <sstream>
using namespace std;
/* This file controls the TOSSIM simulation and takes
 * one command line argument which is the node ID.
 *
 * If using UANT for runnning Linux applications using
 * a throttle (simulation time matches wall time) performace
 * will be hurt.
 *
 * However for running TinyOS applications it will most likely
 * be necessary to use a throttle and uncomment out the 
 * appropriate lines below
 */

int main(int argc, char *argv[]) {
	if (argc != 2)
	{
		cout << "usage: "<< argv[0] << " <node ID>\n";
	}
	else
	{
		int node_id;
		stringstream ss(argv[1]);
		ss>>node_id;
		Tossim* t = new Tossim(NULL);
		Radio* r = t->radio();
		SerialForwarder* tapsf = new SerialForwarder(9003);
		//UNCOMMENT TWO LINES BELOW FOR THROTTLE
		Throttle* throt = new Throttle(t, 10);
		throt->initialize();
		//
		//add or remove channels as necessary for debugging purposes
		t->addChannel("Serial", stdout);
		t->addChannel("RadioCountToLedsC", stdout);
		t->addChannel("MAC", stdout);
		t->addChannel("control", stdout);
		//expecting node id from command line
		Mote* m = t->getNode(node_id);
		m->bootAtTime(1);
		/*
		
		for (int i = 200; i < 221; i++)
		{
			if(i != node_id)
			{
				m = t->getNode(i);
				m->bootAtTime(i*(20.0/100.0));
			}
		}*/
		while(1) {
			t->runNextEvent();
			tapsf->process();
			//microsleep is used only if there is no throttle
			//it prevents the CPU from using 100% in this 
			//infinite loop
			//usleep(2000);
			//UNCOMMENT LINE BELOW FOR THROTTLE
			throt->checkThrottle();
		}
	}
}

