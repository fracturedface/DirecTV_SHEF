#!/usr/bin/perl
#
# Copyright (c) 2011 Paul Sands <usg990a at cebridge.net >
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# directv_http.pl: Network control of a DirecTV unit via http
# Based upon the directv.pl script maintained by David Gesswein < djg at pdp8online.com >
#  at http://www.pdp8online.com/directv/directv.shtml
# Technical Reference: DTV-MD-0359-DIRECTV SHEF Public Beta Command Set-V1.0.pdf
#
# I take no responsibility for any damage this script might cause.
# Feel free to modify and redistribute this as you see fit, but please retain
# the comments above.
#
# The dtv's "info/getOptions" URL shows the supported query strings,
# including all the supported fields for each.

use Switch;
use LWP::UserAgent;
use JSON;
# use Data::Dumper;  # Only used for debugging.

# Set script version number
$version = "1.1";

# Set client addr
#$clientaddr="XXXXXXXXXXXX";
$clientaddr="";
# Using "/info/getLocations" it would be possible to specify the
# client addresses using the client box names, e.g.,
# clientAddr="BEDROOM".

# The IP address of the dtv.  Default to no ip provided unless explicitly set on command line.
$dtv_ip = "";

# Define a new session and initialize it.
$ua = LWP::UserAgent->new;
$ua->agent("$0/0.1 " . $ua->agent);

# Set default timeout to 2 seconds (stops slow response if DirecTV Receiver is off)
$ua->timeout(2);

# Map commands to function to execute.
# last_param is handled in main routine.
%cmds=("on" => \&on,
      "off" => \&off,
      "reboot" => \&reboot,
      "ip" => \&ip,
      "get_channel" => \&get_channel,
      "get_signal" => \&get_signal,
      "get_systemtime" => \&get_systemtime,
      "get_systemversion" => \&get_systemversion,
      "key" => \&key,
      "serial" => \&serial,
      "delay" => \&delay,
      "version" => \&version,
      "usage" => \&usage,
      );

# Define the keys the script supports
%keymap =
        (power => "power",
       poweron => "poweron",
      poweroff => "poweroff",
        format => "format",
         pause => "pause",
           rew => "rew",
        replay => "replay",
          stop => "stop",
       advance => "advance",
          ffwd => "ffwd",
        record => "record",
          play => "play",
         guide => "guide",
        active => "active",
          list => "list",
          exit => "exit",
          back => "back",
          menu => "menu",
          info => "info",
            up => "up",
          down => "down",
          left => "left",
         right => "right",
        select => "select",
           red => "red",
         green => "green",
        yellow => "yellow",
          blue => "blue",
         ch_up => "chanup",
         ch_dn => "chandown",
          prev => "prev",
             0 => "0",
             1 => "1",
             2 => "2",
             3 => "3",
             4 => "4",
             5 => "5",
             6 => "6",
             7 => "7",
             8 => "8",
             9 => "9",
          dash => "dash",
           "-" => "dash",
         enter => "enter"
        );
# Replace argument last_param with last parameter on the command line.
# The last parameter is then removed.
for ($i = 0; $i < $#ARGV; $i++) {
   if ($ARGV[$i] eq "last_param") {
      $ARGV[$i] = $ARGV[$#ARGV];
      $#ARGV = $#ARGV - 1;
      last;
   }
}

if ($#ARGV < 0) {
   usage();
}

# Loop through each arguement passed on the commandline
while ($#ARGV >= 0) {
   if (defined($sub = $cmds{$ARGV[0]})) {
      shift @ARGV;
      &$sub;
   } else {
      if ($ARGV[0] == 0) {
         usage();
         die "\nCommand $ARGV[0] not found\n"
      }
      change_channel($ARGV[0]);
      shift @ARGV;
   }
}

exit 0;

# Give the user the syntax for using the script
sub usage {
   print "Usage: $0 ip x.x.x.x command ...\n";
   print "Commands:\n";
   print "  version         - display program version\n";
   print "  ip x.x.x.x      - IP address of box - REQUIRED\n";
   print "                     must be the first command\n";
   print "  on              - turn box on\n";
   print "  off             - turn box off\n";
   print "  reboot          - hard reboot (reset) - WARNING Requires MANUAL reactivation of network control\n";
   print "  delay number    - wait for number seconds. Floating point is valid \n";
   print "  number{-number} - change to specified channel-subchannel\n";
   print "                     must be the last command\n";
   print "\n";
   print "  get_channel     - print current channel\n";
   print "  get_systemtime  - print date and time (add epoch to return in epoch format)\n";
   print "  get_signal      - print signal strength\n";
   print "  key {key}       - send key to receiver\n";
   print "                           enter "; print chr(34); print"key help"; print chr(34); print " for list of available keys\n";
   print "  serial          - process hex coded serial command (hex only; no need for 0x)\n";
   print "\n";
}

# Provide help text for the keys the script supports
sub keyhelp {
   print "Usage: $0 ip x.x.x.x key {key}\n";
   print "\n";
   print "                             Valid Keys:\n";
   print "Receiver Power             - power, poweron, poweroff\n";
   print "Change Output Format       - format\n";
   print "Live TV / DVR Playback     - pause, rew, replay, stop, advance, ffwd, record, play\n";
   print "Interactive TV             - guide, active, list\n";
   print "Navigation                 - up, down, left, right, back, menu, exit, info, select\n";
   print "Favorites                  - red, green, yellow, blue\n";
   print "Channel                    - chanup, chandown, prev\n";
   print "Numbers                    - 0-9, dash (or -), enter\n";
   print "\n";
}

sub on {
    require_ip();
    my $url = 'http://'.$dtv_ip.':8080/remote/processKey?key=poweron'.client_addr('&');
    $status = send_req($url);
    #my $key_rcv = $json_text->{key} if ($status == 0);
    #print "$key_rcv\n" if ($status == 0);
    exit $status
}

sub off {
    require_ip();
    my $url = 'http://'.$dtv_ip.':8080/remote/processKey?key=poweroff'.client_addr('&');
    $status = send_req($url);
    #my $key_rcv = $json_text->{key} if ($status == 0);
    #print "$key_rcv\n" if ($status == 0);
    exit $status
}

sub reboot {
    require_ip();
    my $url = 'http://'.$dtv_ip.':8080/serial/processCommand?cmd=0xf7'.client_addr('&');
    $status = send_req($url);
    # Command executes with no response back to the script
    exit $status
}

sub ip {
   $dtv_ip = $ARGV[0];
   shift @ARGV;
}

sub get_channel {
   require_ip();
   my $url = 'http://'.$dtv_ip.':8080/tv/getTuned'.client_addr('?');
   $status = send_req($url);
   my $chan = $json_text->{major} if ($status == 0);
   if ($status == 0) {
       print "$chan\n";
   } else {
       print "When access is denied, on your DTV try: Menu->System Setup->Whole-Home->External Device, set 'Current Program' to 'Allow'.\n";
   }
   exit $status
}

sub serial {
   require_ip();
   my $url = 'http://'.$dtv_ip.':8080/serial/processCommand?cmd=FA'.$ARGV[0].client_addr('&');
   $status = send_req($url);
   my $ser = $json_text->{return}->{data} if ($status == 0);
   print "$ser\n" if ($status == 0);
   print "$url\n" if ($status == 1);
   exit $status
}

sub get_signal {
   require_ip();
   my $url = 'http://'.$dtv_ip.':8080/serial/processCommand?cmd=FA90'.client_addr('&');
   $status = send_req($url);
   my $signal = $json_text->{return}->{data}  if ($status == 0); $signal = hex($signal)  if ($status == 0);
   print "$signal\n" if ($status == 0);
   exit $status
}

sub get_systemtime() {
   require_ip();
   # Assume we don't want to return time from epoch unless given commandline override
   my $epoch = $ARGV[0] eq "epoch";
   # According to "/info/getOptions" on the H24, clientAddr is not a legal field for "getVersion".
   my $url = 'http://'.$dtv_ip.':8080/info/getVersion'; #.client_addr('?');
   $status = send_req($url);
   my $systime = $json_text->{systemTime}; if (!$epoch == 1 ) { $systime = scalar localtime($systime)};
   print "$systime\n" if ($status == 0);
   exit $status
}

sub get_systemversion() {
   require_ip();
   # According to "/info/getOptions" on the H24, clientAddr is not a legal field for "getVersion".
   my $url = 'http://'.$dtv_ip.':8080/info/getVersion'; #.client_addr('?');
   $status = send_req($url);
   my $sysversion = $json_text->{version} if ($status == 0);
   print "$sysversion\n" if ($status == 0);
   exit $status
}

sub key () {
   #if (shift(@ARGV) eq "help") {
   if (@ARGV =~ /help/) {
      keyhelp();
   } else {
   send_key(shift(@ARGV));
   }
}

sub delay {
   select(undef, undef, undef, $ARGV[0]);
   shift @ARGV;
}

sub version {
   print "Script Version $version\n";
}

sub change_channel () {
   require_ip();
   my ($chan_major,$chan_sub)= split /-/,@_[0];
   my $url = 'http://'.$dtv_ip.':8080/tv/tune?major='.$chan_major.client_addr('&');
   $url = $url . '&minor='.$chan_sub if ($chan_sub ne "");
   $status = send_req($url);
   if ($status != 0) {
       print "When access is denied, on your DTV try: Menu->System Setup->Whole-Home->External Device, set 'External Access' to 'Allow'.\n";
   }
   exit $status
}

sub send_key () {
   require_ip();
   my $url;
   my $ky;
   my @keys = split / /,@_[0];
   foreach $ky (@keys)
   {
      my $key = $keymap{$ky};
      die "Unknown key $ky\n" if (!defined($key));
      $url = 'http://'.$dtv_ip.':8080/remote/processKey?key='.$key.client_addr('&');
      $status = send_req($url);
   }
}

sub send_req () {
      my ($url) = @_;
#      print $url."\n";
      my $parent = ( caller(1) )[3];
      $parent =~ s/main:://g;
      $req = HTTP::Request->new(GET => $url);
      $req->header('Accept' => 'text/html');
      $res = $ua->request($req);
#      print "\n".Dumper($res);
      #sleep $delay_sec if ($delay > 0);
      if ($res->is_success)
      {
         $json = new JSON;
         $json_text = $json->decode($res->content);
         $check_ok = $json_text->{status}->{msg};
         if(($check_ok eq "OK.") || ($check_ok eq "OK"))
         {
            return 0;
            #}
         } else {
            print "Failed!\n";
            return 1;
         }
      } else {
         print "Failed!\n";
        return 1;
      }
}

# Return a string to specify the clientAddr URL field.
# seperator should be either "?" if clientAddr is the first URL field, otherwise "&".
sub client_addr() {
    my ($seperator) = @_;

    # If clientaddr is blank, then don't include the field at all.
    return "" if ($clientaddr == "");
    return $seperator . "clientAddr=" . $clientaddr;
}

# Exit with an error if the IP address has not been specified.
sub require_ip() {
    return if $dtv_ip ne "";
    usage();
    print "No IP Address given\n";
    exit 1;
}
