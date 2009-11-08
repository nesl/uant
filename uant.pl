#!/usr/bin/perl
#use strict;
use warnings;

use Tk;
use Time::HiRes qw(usleep);
use Getopt::Long;
use Sys::Hostname;
if ($> != 0)
{
    print "you must be root to run\nUSAGE:\n\$ sudo su\n# source uant_vars\n# ./uant.pl [OPTIONS]\n";
    exit 0;
}
####get options
$gui = 1;
my @phy_def = ('10k', '16000', '25k');
my @mac_def = ('500', '1000', '3');
my @phy = ('Rate (b/s)', 'Amplitude (0-32k)', 'Center Freq (Hz)');
my @mac = ('Min backoff (ms)', 'Max backoff (ms)', 'max transmit attempts');
my @mod = ('gmsk','cpm', 'd8psk', 'qam8', 'dbpsk', 'dqpsk');
my @apps = ('linux', 'UWTosRadioCount');
our $mod = $mod[0];
our $app_to_use = $apps[0];
our @misc = ('Node ID', 'MTU Size (< 245)', '');
our @misc_def = ('1', '240', '');
our $net_add = '192.168.200.';
$linux_app = 1;
GetOptions("gui!" => \$gui,
        "f|freq=s" => \$phy_def[2],
        "r|rate=s" => \$phy_def[0],
        "a|amplitude=s" => \$phy_def[1],
        "min=s" => \$mac_def[0],
        "max=s" => \$mac_def[1],
        "transmit=s" => \$mac_def[2],
        "n|node=s" => \$misc_def[0],
        "stop" => \$stop,
        "mtu=s" => \$misc_def[1]);

if ($stop) ##if user just wants to stop, kill everything and exit
{
    $gui = 0; #if stop is called there should be no gui
    &stop;
    exit(0);
}

if($gui)
{
    our $window = MainWindow->new;
    $top = $window->Frame();
    #$window->Frame()->
    $lower = $window->Frame();
    $right = $window->Frame();
    $left = $window->Frame();
    $info = $window->Frame(-relief => 'ridge', -borderwidth => 4);
    
    $window->optionAdd("*font", "-*-arial-normal-r-*-*-*-120-*-*-*-*-*-*");
    $window->optionAdd("*Entry.width", "11");
    #$window->optionAdd("*borderWidth", 1);
    
    
    #add a title
    $top->Label(-text => 'UANT Parameters', -relief => 'raised', -font => '-*-arial-bold-r-*-*-*-240-*-*-*-*-*-*', -bg => '#f3f48a')->pack(-fill => 'x');
    $top->pack(-side => 'top', -expand =>1, -fill => 'x');
    #end title
    #
    #variables needed
    ##SETTING UP BOTTOM FRAME containing buttons
    $lower->Button(-text => "Reset Defaults", -command => \&reset)->grid(-row => 0, -column => 0);
    $start = $lower->Button(-text => "Start", -command => \&start)->grid(-row => 0, -column => 1);
    $stop = $lower->Button(-text => "Stop", -command => \&stop, -state => 'disabled')->grid(-row => 0, -column => 2);
    $exit = $lower->Button(-text => "Exit", -command => sub {exit})->grid(-row => 0, -column => 3);
    $lower->pack(-side => 'bottom', -fill=> 'x', -expand => 1);
    ##end bottom frame
    #
    #
    #SET UP Left Frame which contains MAC and PHY options
    $left->Label(-text => 'PHY OPTIONS:', -relief => 'ridge', -fg => 'blue')->grid(-columnspan => 2, -sticky => 'we', -pady => 4);
    
    $left->Label(-text => 'Modulation:', -fg => 'black')->grid();
    my $mod_menu = $left->Optionmenu(-command => sub {$mod = shift}, -options => \@mod, -textvariable => \$mod[0] )->grid(-column => 1, -row => 1, -sticky => 'we');
    $count =0;
    foreach (@phy)
    {
        $label = $left->Label(-text => $_);
        $entry = $left->Entry(-textvariable => \$phy_def[$count], -bg => 'white');
        $label -> grid($entry);
        $count++;
    }
    #empty label to create space, then a label specifying its mac options
    $left->Label(-text => ' ')->grid(-columnspan => 2);
    $left->Label(-text => 'MAC OPTIONS:', -relief => 'ridge', -fg => 'blue')->grid(-columnspan => 2, -sticky => 'we', -pady => 4);
    
    $count =0;
    foreach (@mac)
    {
        $label_mac = $left->Label(-text => $_);
        $entry_mac = $left->Entry(-textvariable => \$mac_def[$count], -bg => 'white');
        $label_mac -> grid($entry_mac);
        $count++;
    }
    #pack to main window these will be left side anchored to the top (north)
    $left->pack(-side => 'left', -anchor => 'n', -expand => 1);
    #########Left is complete
    
    #BEGIN Right
    
    #check box for running application
    $right->Label(-text => 'Application:', -fg => 'black')->grid();
    my $app_menu = $right->Optionmenu(-command => \&set_app, -options => \@apps, -textvariable => \$apps[0] )->grid(-column => 1, -row => 0, -sticky => 'we');
    $cb = $right->Checkbutton(-variable => \$linux_app, -command => \&set_ip);
    $cb->select;
    $cb->configure(-state => 'disabled');
    $right->Label(-text => 'Use Linux Apps:', -fg => 'black')->grid($cb);
    
    #node id entry
    
    #set the nodeID, validation is used for correcting the IP address label more than actual validation
    #everytime the entry loses focus ip will be reset if it is visble
    $entry = $right->Entry(-textvariable => \$misc_def[0], -bg => 'white', -validate => 'focusout', -vcmd => \&set_ip);
    $right->Label(-textvariable => \$misc[0] , -fg => 'black')->grid($entry);
    #set the mtu size entry
    $entry = $right->Entry(-textvariable => \$misc_def[1], -bg => 'white');
    $right->Label(-textvariable => \$misc[1] , -fg => 'black')->grid($entry);
    #mtu size entry
    
    #IP Address
    $entry = $right->Label(-textvariable => \$misc_def[2]);
    $right->Label(-textvariable => \$misc[2] , -fg => 'black')->grid($entry);
    $right->pack();
    ###END Right panel
    
    #SETTing up info panel
    $info->Label(-text => 'NESL', -font => '-*-arial-bold-r-*-*-*-240-*-*-*-*-*-*', -fg => '#000000008888')->pack();
    $info->Label(-text => hostname(), -font => '-*-arial-bold-r-*-*-*-240-*-*-*-*-*-*', -fg => '#0000AA')->pack();
    $info->Label(-text => 'Modulation schemes depend on')->pack();
    $info->Label(-text => 'your GNU Radio Version. Please')->pack();
    $info->Label(-text => 'make sure GNU Radio is current.')->pack();
    $info->pack(-fill => 'both', -expand => 1);
    ##end infor panel
    
    MainLoop;
    #############################################################
}
else
{
    &start;
}
sub set_ip
{
    if($linux_app)
    {
        $misc[2] = "IP Address";
        $misc_def[2] = $net_add.$misc_def[0];
    }
    else
    {
        $misc[2] = '';
        $misc_def[2] = '';
    }
    return 1;
}

sub set_app
{
    $app_to_use = shift;
    if ($app_to_use eq 'linux')
    {   
        $cb->select;    
        $cb->configure(-state => 'disabled');
        set_ip();
    }
    else
    {
        $cb->configure(-state => 'normal');
        $cb->deselect;  
        set_ip();
    }
}   

sub reset
{
    @def_phy = ('10k', '16000', '25k');
    @def_mac = ('500', '1000', '3');
    @def_misc = ('1', '240', '');
    for ($i = 0; $i < scalar(@def_phy); $i++)
    {
        $phy_def[$i] = $def_phy[$i];
    }

    for ($i = 0; $i < scalar(@def_mac); $i++)
    {
        $mac_def[$i] = $def_mac[$i];
    }
    for ($i = 0; $i < scalar(@def_misc); $i++)
    {
        $misc_def[$i] = $def_misc[$i];
    }
    
}

sub start
{
    if($gui)
    {
        $start->configure(-state => 'disabled');
        $exit->configure(-state => 'disabled');
    }
    $path_to_uwtos = '';
    $os_driver = $path_to_uwtos.'apps/'.$app_to_use.'/UWTos '.$misc_def[0].' &';
    $tap_sf = $path_to_uwtos.'apps/'.$app_to_use.'/tap_sf.py &';
    $usrp_tos = $path_to_uwtos.'digital/usrp_tos.py --rx-gain=0 -f '.$phy_def[2].' -r '.$phy_def[0].' --tx-amplitude='.$phy_def[1].' -m '.$mod.' -n '.$misc_def[0].' &';
    $aloha_gen = $path_to_uwtos.'apps/'.$app_to_use.'/aloha_gen.pl '.$mac_def[0].' '.$mac_def[1].' '.$mac_def[2].' '.$path_to_uwtos.'apps/'.$app_to_use.'; make -C '.$path_to_uwtos.'apps/'.$app_to_use.' all';
    `$aloha_gen`;
    $addr = $net_add.$misc_def[0];
    system $os_driver;
    system $usrp_tos;
    sleep(2);
    while(`ps -A | grep python` eq '')
    {
        system $usrp_tos;
        sleep(2);
    }
    if($linux_app)
    {
        system $tap_sf;
        sleep(2);
        `sudo ifconfig gr0 $addr mtu $misc_def[1] `;
    }
    if($gui)
    {
        $stop->configure(-state => 'normal');
    }
}

sub stop
{
    if($gui)
    {
        $stop->configure(-state => 'disabled');
    }
    `sudo killall python`;
    `sudo killall UWTos`;
    `sudo killall tap_sf.py`;
    if($gui)
    {
        $start->configure(-state => 'normal');
        $exit->configure(-state => 'normal');
    }
}
