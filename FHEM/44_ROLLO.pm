########################################################################################
# $Id: 44_ROLLO.pm 1202 2016-08-29 19:14:00Z                                         $ #
# Modul zur einfacheren Rolladensteuerung                                              #
#                                                                                      #
# Thomas Ramm, 2016                                                                    #
# Tim Horenkamp, 2016                                                                  #
# Markus Moises, 2016																   #
#                                                                                      #
########################################################################################
#
#  This programm is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
########################################################################################
package main;

use strict;
use warnings;
use Data::Dumper;

my $version = "1.201";

my %sets = (
  "open" => "noArg",
  "closed" => "noArg",
  "half" => "noArg",
  "stop" => "noArg",
  "blocked" => "noArg",
  "unblocked" => "noArg",
  "position" => "0,10,20,30,40,50,60,70,80,90,100",
  "reset" => "open,closed",
  "extern" => "open,closed,stop");

my %positions = (
  "open" => 0,
  "closed" => 100,
  "half" => 50);

my %gets = (
   "version:noArg" => "V"
  );

############################################################ INITIALIZE #####
sub ROLLO_Initialize($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  $hash->{DefFn}    = "ROLLO_Define";
  $hash->{UndefFn}  = "ROLLO_Undef";
  $hash->{SetFn}    = "ROLLO_Set";
  $hash->{GetFn}    = "ROLLO_Get";
  $hash->{AttrFn}   = "ROLLO_Attr";

  $hash->{AttrList} = " secondsDown"
    . " secondsUp"
    . " excessTop"
    . " excessBottom"
    . " switchTime"
	. " resetTime"
    . " reactionTime"
    . " blockMode:blocked,force-open,force-closed,only-up,only-down,half-up,half-down,none"
    . " commandUp commandUp2 commandUp3"
    . " commandDown commandDown2 commandDown3"
    . " commandStop commandStopDown commandStopUp"
    . " automatic-enabled:on,off"
	. " automatic-delay"
    . " autoStop:1,0"
	. " type:normal,HomeKit"
	. " " . $readingFnAttributes;

  $hash->{stoptime} = 0;

  return undef;
}

################################################################ DEFINE #####
sub ROLLO_Define($$) {
  my ($hash,$def) = @_;
  my $name = $hash->{NAME};
  Log3 $name,5,"ROLLO ($name) >> Define";

  my @a = split( "[ \t][ \t]*", $def );

  $attr{$name}{"secondsDown"} = 30;
  $attr{$name}{"secondsUp"} = 30;
  $attr{$name}{"excessTop"} = 4;
  $attr{$name}{"excessBottom"} = 2;
  $attr{$name}{"switchTime"} = 1;
  $attr{$name}{"resetTime"} = 0;
  $attr{$name}{"autoStop"} = 0; #neue Attribute sollten als default keine Änderung an der Funktionsweise bewirken.
  $attr{$name}{"devStateIcon"} = 'open:fts_shutter_10:closed closed:fts_shutter_100:open half:fts_shutter_50:closed drive-up:fts_shutter_up@red:stop drive-down:fts_shutter_down@red:stop position-100:fts_shutter_100:open position-90:fts_shutter_80:closed position-80:fts_shutter_80:closed position-70:fts_shutter_70:closed position-60:fts_shutter_60:closed position-50:fts_shutter_50:closed position-40:fts_shutter_40:open position-30:fts_shutter_30:open position-20:fts_shutter_20:open position-10:fts_shutter_10:open position-0:fts_shutter_10:closed';
  $attr{$name}{"type"} = "normal"; #neue Attribute sollten als default keine Änderung an der Funktionsweise bewirken.
 # $attr{$name}{"blockMode"} = "none";
  $attr{$name}{"webCmd"} = "open:closed:half:stop:position";
  # $attr{$name}{"devStateIcon"} #wird jetzt abhängig von Attribut type definiert!
  return undef;
}

################################################################# UNDEF #####
sub ROLLO_Undef($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  RemoveInternalTimer($hash);
  return undef;
}

#################################################################### SET #####
sub ROLLO_Set($@) {
  my ($hash,@a) = @_;
  my $name = $hash->{NAME};

  #allgemeine Fehler in der Parameterübergabe abfangen
  if ( @a < 2 ) {
    Log3 $name,2,"ERROR: \"set ROLLO\" needs at least one argument";
    return "\"ROLLO_Set\" needs at least one argument";
  }
  my $cmd =  $a[1];
  my $arg = "";
  $arg = $a[2] if defined $a[2];
  Log3 $name,5,"ROLLO ($name) >> Set ($cmd,$arg)" if ($cmd ne "?");

  my @positionsets = ("0","10","20","30","40","50","60","70","80","90","100");

  if(!defined($sets{$cmd}) && $cmd !~ @positionsets) {
    my $param = "";
    foreach my $val (keys %sets) {
        $param .= " $val:$sets{$val}";
    }
    if ($cmd ne "?") {
      Log3 $name,2,"ERROR: Unknown command $cmd, choose one of $param";
    }
    return "Unknown argument $cmd, choose one of $param";
  }

  if (($cmd eq "stop") && (ReadingsVal($name,"state",'') !~ /drive/))
  {
    Log3 $name,3,"WARNING: command is stop but shutter is not driving!";
    RemoveInternalTimer($hash);
	ROLLO_Stop($hash);
    return undef;
  } 
  if ($cmd eq "extern") {
    readingsSingleUpdate($hash,"drive-type","extern",1);
    $cmd = $arg;
  } elsif ($cmd eq "reset") {
	my $reset_position = $positions{$arg};
	if (AttrVal($name,"type","normal") eq "HomeKit") {
		$reset_position = 100-$reset_position;
	}
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash,"state",$arg);
    readingsBulkUpdate($hash,"desired_position",$reset_position);
    readingsBulkUpdate($hash,"position",$reset_position);
    readingsEndUpdate($hash,1);
    return undef;
  } 
  if ($cmd eq "blocked") {
    ROLLO_Stop($hash);
    readingsSingleUpdate($hash,"blocked","1",1);
    return if(AttrVal($name,"blockMode","none") eq "blocked");
  } elsif ($cmd eq "unblocked") {
    ROLLO_Stop($hash);
    readingsSingleUpdate($hash,"blocked","0",1);
    ROLLO_Start($hash);
    fhem( "deletereading $name blocked");
    return;
  }
  my $desiredPos = $cmd;
  my $typ = AttrVal($name,"type","normal");
  if ( grep /^$arg$/, @positionsets )
  {
	if ($cmd eq "position") { 
	  if ($typ eq "HomeKit"){
		Log3 $name,4,"invert Position from $arg to (100-$arg)";
		$arg = 100-$arg
	  }
      $cmd = "position-". $arg;
      $desiredPos = $arg;
	} else {
	  if ($typ eq "HomeKit"){
		$cmd = 100-$cmd
	  }
	  $cmd = "position-". $cmd;
      $desiredPos = $cmd;
	}
  }
  else 
  {
    $desiredPos = $positions{$cmd}
  }

  #wenn ich gerade am fahren bin und eine neue Zielposition angefahren werden soll,
  # muss ich jetzt erst mal meine aktuelle Position berechnen und updaten
  # bevor ich die desired-position überschreibe!
  if ((ReadingsVal($name,"state","") =~ /drive-/))
  {
	my $position = ROLLO_calculatePosition($hash,$name);
	readingsSingleUpdate($hash,"position",$position,1);
  }
  readingsBeginUpdate($hash);
  readingsBulkUpdate($hash,"command",$cmd);
  readingsBulkUpdate($hash,"desired_position",$desiredPos) if($cmd ne "blocked") && ($cmd ne "stop");
  readingsEndUpdate($hash,1);

  ROLLO_Start($hash);
  return undef;
}

#################################################################### START #####
sub ROLLO_Start($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  Log3 $name,5,"ROLLO ($name) >> Start";

  my $command = ReadingsVal($name,"command","stop");
  my $desired_position = ReadingsVal($name,"desired_position",100);
  my $position = ReadingsVal($name,"position",0);
  my $state = ReadingsVal($name,"state","open");

  Log3 $name,4,"ROLLO ($name) drive from $position to $desired_position. command: $command. state: $state";

  if(ReadingsVal($name,"blocked","0") eq "1" && $command ne "stop")
  {
    my $blockmode = AttrVal($name,"blockMode","none");
    Log3 $name,4,"block mode: $blockmode - $position to $desired_position?";

    if($blockmode eq "blocked")
    {
      readingsSingleUpdate($hash,"state","blocked",1);
      return;
    }
    elsif($blockmode eq "force-open")
    {
      $desired_position = 0;
    }
    elsif($blockmode eq "force-closed")
    {
      $desired_position = 100;
    }
    elsif($blockmode eq "only-up" && $position <= $desired_position)
    {
      readingsSingleUpdate($hash,"state","blocked",1);
      return;
    }
    elsif($blockmode eq "only-down" && $position >= $desired_position)
    {
      readingsSingleUpdate($hash,"state","blocked",1);
      return;
    }
    elsif($blockmode eq "half-up" && $desired_position < 50)
    {
      $desired_position = 50;
    }
    elsif($blockmode eq "half-up" && $desired_position == 50)
    {
      readingsSingleUpdate($hash,"state","blocked",1);
      return;
    }
    elsif($blockmode eq "half-down" && $desired_position > 50)
    {
      $desired_position = 50;
    }
    elsif($blockmode eq "half-down" && $desired_position == 50)
    {
      readingsSingleUpdate($hash,"state","blocked",1);
      return;
    }
  }

  my $direction = "down";
  $direction = "up" if ($position > $desired_position || $desired_position == 0);
  Log3 $name,4,"ROLLO ($name) position: $position -> $desired_position / direction: $direction";

  #Ich fahre ja gerade...wo bin ich aktuell?
  if ($state =~ /drive-/)
  {
    #das muss weg.. verschoben in set!
	#$position = ROLLO_calculatePosition($hash,$name);

    if ($command eq "stop")
    {
	  ROLLO_Stop($hash);
      return;
    }

    $direction = "down";
    $direction = "up" if ($position > $desired_position || $desired_position == 0);
    if ( (($state eq "drive-down") && ($direction eq "up")) || (($state eq "drive-up") && ($direction eq "down")) )
    {
      Log3 $name,3,"driving into wrong direction. stop and change driving direction";
      ROLLO_Stop($hash);
      InternalTimer(int(gettimeofday())+AttrVal($name,'switchTime',0) , "ROLLO_Start", $hash, 0);
      return;
    }
  }
  
  RemoveInternalTimer($hash);
  my $time = ROLLO_calculateDriveTime($name,$position,$desired_position,$direction);
  if ($time > 0)
  {
    my ($command1,$command2,$command3);
    if($direction eq "down") {
      $command1 = AttrVal($name,'commandDown',"");
      $command2 = AttrVal($name,'commandDown2',"");
      $command3 = AttrVal($name,'commandDown3',"");
    } else {
      $command1 = AttrVal($name,'commandUp',"");
      $command2 = AttrVal($name,'commandUp2',"");
      $command3 = AttrVal($name,'commandUp3',"");
    }
	
	$command = "drive-" . $direction;
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash,"last_drive",$command);
    readingsBulkUpdate($hash,"state",$command);
    readingsEndUpdate($hash,1);
	
    #***** ROLLO NICHT LOSFAHREN WENN SCHON EXTERN GESTARTET *****#
    if (ReadingsVal($name,"drive-type","undef") ne "extern") {
	  Log3 $name,4,"ROLLO ($name) execute following commands: $command1; $command2; $command3";
	  readingsSingleUpdate($hash,"drive-type","modul",1);
      fhem("$command1") if ($command1 ne "");
      fhem("$command2") if ($command2 ne "");
      fhem("$command3") if ($command3 ne "");
    } else {
      #readingsSingleUpdate($hash,"drive-type","extern",1);
      Log3 $name,4,"ROLLO ($name) drive-type is extern, not executing driving commands";
    }

    $hash->{stoptime} = int(gettimeofday()+$time);
    InternalTimer($hash->{stoptime}, "ROLLO_Timer", $hash, 1);
    Log3 $name,4,"ROLLO ($name) stop in $time seconds.";
  }
  return undef;
}
sub ROLLO_Timer($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  Log3 $name,5,"ROLLO ($name) >> Timer";
  
  my $position = ReadingsVal($name,"desired_position",0);
  readingsSingleUpdate($hash,"position",$position,0);
  ROLLO_Stop($hash);
  return undef;
}

#****************************************************************************
sub ROLLO_Stop($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  Log3 $name,5,"ROLLO ($name) >> Stop";

  RemoveInternalTimer($hash);

  my $position = ReadingsVal($name,"position",0);
  my $state = ReadingsVal($name,"state","");

  Log3 $name,4,"ROLLO ($name): stops from $state at position $position";

  #wenn autostop=1 und position <> 0+100 und rollo fährt, dann kein stopbefehl ausführen...
  if( ($state =~ /drive-/ && $position > 0 && $position < 100 ) || AttrVal($name, "autoStop", 0) ne 1)
  {
    my $command = AttrVal($name,'commandStop',"");
    $command = AttrVal($name,'commandStopUp',"") if(defined($attr{$name}{commandStopUp}));
    $command = AttrVal($name,'commandStopDown',"") if(defined($attr{$name}{commandStopDown}) && $state eq "drive-down");

    # NUR WENN NICHT BEREITS EXTERN GESTOPPT
    if (ReadingsVal($name,"drive-type","undef") ne "extern") {
      fhem("$command") if ($command ne "");
	  Log3 $name,4,"ROLLO ($name) stopped by excute the command: $command";
    } else {
      readingsSingleUpdate($hash,"drive-type","na",1);
      Log3 $name,4,"ROLLO ($name) is in drive-type extern";
    }
  } else {
    Log3 $name,4,"ROLLO ($name) drives to end position and autostop is enabled. No stop command executed";
  }

  if(ReadingsVal($name,"blocked","0") eq "1" && AttrVal($name,"blockMode","none") ne "none")
  {
    readingsSingleUpdate($hash,"state","blocked",1);
  }
  else
  {
    #Runden der Position auf volle 10%-Schritte für das Icon
    my $newpos = int($position/10+0.5)*10;
    $newpos = 0 if($newpos < 0);
    $newpos = 100 if ($newpos > 100);
	my $state;
	#position in text umwandeln
	my %rhash = reverse %positions;
    if (defined($rhash{$newpos}))
    {
      $state = $rhash{$newpos};
	#ich kenne keinen Text für die Position, also als position-nn anzeigen
	} else {
		#wenn ich die Position als Zahl anzeige muss ich sie bei HomeKit noch schnell umwandeln
		if (AttrVal($name,"type","normal") eq "HomeKit"){
			$newpos = 100-$newpos
		}
		$state = "position-$newpos";
	}
    readingsSingleUpdate($hash,"state",$state,1);
  }

  return undef;
}
#****************************************************************************
sub ROLLO_calculatePosition(@) {
  my ($hash,$name) = @_;
  my ($position);
  Log3 $name,5,"ROLLO ($name) >> calculatePosition";

  my $start = ReadingsVal($name,"position",100);
  my $end   = ReadingsVal($name,"desired_position",0);
  my $drivetime_rest  = int($hash->{stoptime}-gettimeofday()); #die noch zu fahrenden Sekunden
  my $drivetime_total = ($start < $end) ? AttrVal($name,'secondsDown',undef) : AttrVal($name,'secondsUp',undef);

  # bsp: die fahrzeit von 0->100 ist 26sec. ich habe noch 6sec. zu fahren...was bedeutet das?
  # excessTop    = 5sec
  # driveTimeDown=20sec -> hier wird von 0->100 gezählt, also pro sekunde 5 Schritte
  # excessBottom = 1sec  
  # aktuelle Position = 6sec-1sec=5sec positionsfahrzeit=25steps=Position75

  #Frage1: habe ich noch "tote" Sekunden vor mir wegen endposition?
  my $resetTime = AttrVal($name,'resetTime',0);
  $drivetime_rest -= (AttrVal($name,'excessTop',0) + $resetTime)  if($end == 0);
  $drivetime_rest -= (AttrVal($name,'excessBottom',0) + $resetTime) if($end == 100);
  #wenn ich schon in der nachlaufzeit war, setze ich die Position auf 99, dann kann man nochmal für die nachlaufzeit starten
  if ($start == $end) {
	 $position = $end;
  } elsif ($drivetime_rest < 0) {
     $position = ($start < $end) ? 99 : 1;
  } else {
    $position = $drivetime_rest/$drivetime_total*100;
    $position = ($start < $end) ? $end-$position : $end+$position;
    $position = 0 if($position < 0);
    $position = 100 if($position > 100);
  }
  Log3 $name,4,"ROLLO ($name) calculated Position is $position; rest drivetime is $drivetime_rest";
  #aktuelle Position aktualisieren und zurückgeben
  readingsSingleUpdate($hash,"position",$position,100);
  return $position;
}
#****************************************************************************
sub ROLLO_calculateDriveTime(@) {
  my ($name,$oldpos,$newpos,$direction) = @_;
  Log3 $name,5,"ROLLO ($name) >> calculateDriveTime | going $direction: from $oldpos to $newpos";

  my ($time, $steps);
  if ($direction eq "up") {
    $time = AttrVal($name,'secondsUp',undef);
    $steps = $oldpos-$newpos;
  } else {
    $time = AttrVal($name,'secondsDown',undef);
    $steps = $newpos-$oldpos;
  }
  if ($steps == 0) {
    Log3 $name,4,"already at position!";
  }

  if(!defined($time)) {
    Log3 $name,2,"ERROR: missing attribute secondsUp or secondsDown";
    $time = 60;
  }

  my $drivetime = $time*$steps/100;
  $drivetime += AttrVal($name,'reactionTime',0) if($time > 0 && $steps > 0);

  $drivetime += AttrVal($name,'excessTop',0) if($oldpos == 0 or $newpos == 0);
  $drivetime += AttrVal($name,'excessBottom',0) if($oldpos == 100 or $newpos == 100);
  $drivetime += AttrVal($name,'resetTime', 0) if($newpos == 0 or $newpos == 100);

  Log3 $name,4,"ROLLO ($name) calculateDriveTime: oldpos=$oldpos,newpos=$newpos,direction=$direction,time=$time,steps=$steps,drivetime=$drivetime";
  return $drivetime;
}

################################################################### GET #####
#
sub ROLLO_Get($@) {
  my ($hash, @a) = @_;
  my $name = $hash->{NAME};
  Log3 $name,5,"ROLLO ($name) >> Get";

  #-- get version
  if( $a[1] eq "version") {
    return "$name.version => $version";
  }
  if ( @a < 2 ) {
    Log3 $name,2, "ERROR: \"get ROLLO\" needs at least one argument";
    return "\"get ROLLO\" needs at least one argument";
  }

  my $cmd = $a[1];
  if(!$gets{$cmd}) {
    my @cList = keys %gets;
    Log3 $name,3,"ERROR: Unknown argument $cmd, choose one of " . join(" ", @cList) if ($cmd ne "?");
    return "Unknown argument $cmd, choose one of " . join(" ", @cList);
  }
  my $val = "";
  if (@a > 2) {
    $val = $a[2];
  }
  Log3 $name,4,"ROLLO ($name) command: $cmd, value: $val";
}

################################################################## ATTR #####
#
sub ROLLO_Attr(@) {
  my ($cmd,$name,$aName,$aVal) = @_;
  Log3 $name,5,"ROLLO ($name) >> Attr";

  if ($cmd eq "set") {
    if ($aName eq "Regex") {
      eval { qr/$aVal/ };
      if ($@) {
        Log3 $name, 2, "ROLLO ($name):ERROR Invalid regex in attr $name $aName $aVal: $@";
	return "Invalid Regex $aVal";
      }
    }
	#Auswertung von HomeKit und dem Logo
	if ($aName eq "type")
	{
		#auslesen des aktuellen Icon, wenn es nicht gesetzt ist, oder dem default entspricht, dann neue Zuweisung vornehmen
		my $iconNormal  = 'open:fts_shutter_10:closed closed:fts_shutter_100:open half:fts_shutter_50:closed drive-up:fts_shutter_up@red:stop drive-down:fts_shutter_down@red:stop position-100:fts_shutter_100:open position-90:fts_shutter_80:closed position-80:fts_shutter_80:closed position-70:fts_shutter_70:closed position-60:fts_shutter_60:closed position-50:fts_shutter_50:closed position-40:fts_shutter_40:open position-30:fts_shutter_30:open position-20:fts_shutter_20:open position-10:fts_shutter_10:open position-0:fts_shutter_10:closed';
		my $iconHomeKit = 'open:fts_shutter_10:closed closed:fts_shutter_100:open half:fts_shutter_50:closed drive-up:fts_shutter_up@red:stop drive-down:fts_shutter_down@red:stop position-100:fts_shutter_10:open position-90:fts_shutter_10:closed position-80:fts_shutter_20:closed position-70:fts_shutter_30:closed position-60:fts_shutter_40:closed position-50:fts_shutter_50:closed position-40:fts_shutter_60:open position-30:fts_shutter_70:open position-20:fts_shutter_80:open position-10:fts_shutter_90:open position-0:fts_shutter_100:closed';
		my $iconAktuell = AttrVal($name,"devStateIcon","kein");
		if (($aVal eq "HomeKit") && (($iconAktuell eq $iconNormal) || ($iconAktuell eq "kein"))) {
			fhem("attr $name devStateIcon $iconHomeKit");
		}
		if (($aVal eq "normal") && (($iconAktuell eq $iconHomeKit) || ($iconAktuell eq "kein"))) {
			fhem("attr $name devStateIcon $iconNormal");
		}
	}

  }
  return undef;
}

1;

=pod
=begin html

<a name="ROLLO"></a>
<h3>ROLLO</h3>
<ul>
<p>The module ROLLO offers easy away to steer the shutter with one or two relays and to stop point-exactly. <br> 
			Moreover, the topical position is illustrated in fhem. About which hardware the exits are appealed, besides, makes no difference. <br />
			<h4>Example</h4>
			<p>
				<code>define TestRollo ROLLO</code>
				<br />
			</p><a name="ROLLO_Define"></a>
			<h4>Define</h4>
			<p>
				<code>define &lt;Rollo-Device&gt; ROLLO</code> 
				<br /><br /> Define a ROLLO instance.<br />
			</p>
			 <a name="ROLLO_Set"></a>
	 <h4>Set</h4>
			<ul>
				<li><a name="rollo_open">
						<code>set &lt;Rollo-Device&gt; open</code></a><br />
						opens the shutter (Position 0) </li>
				<li><a name="rollo_closed">
						<code>set &lt;Rollo-Device&gt; closed</code></a><br />
						close the shutter (Position 100) </li>		
				<li><a name="rollo_half">
						<code>set &lt;Rollo-Device&gt; half</code></a><br />
						drive the shutter to half open (Position 50) </li>						
				<li><a name="rollo_stop">
						<code>set &lt;Rollo-Device&gt; stop</code></a><br />
						stop a driving shutter</li>						
				<li><a name="rollo_blocked">
						<code>set &lt;Rollo-Device&gt; blocked</code></a><br />
						when activated, the shutter can moved only restricted. See attribute block_mode for further details.</li>
				<li><a name="rollo_unblocked">
						<code>set &lt;Rollo-Device&gt; unblocked</code></a><br />
						unblock the shutter, so you can drive the shutter</li>
				<li><a name="rollo_position">
						<code>set &lt;Rollo-Device&gt; position &lt;value&gt;</code></a><br />
						drive the shutter to exact position from 0 (open) to 100 (closed) </li> 
				<li><a name="rollo_reset">
						<code>set &lt;Rollo-Device&gt; reset &lt;value&gt;</code></a><br />
						set the modul to real position if the shutter position changed outside from fhem</li> 
				<li><a name="rollo_extern">
						<code>set &lt;Rollo-Device&gt; extern &lt;value&gt;</code></a><br />
						if the shutter is started/stopped externaly, you can inform the modul so it can calculate the current position</li> 
			</ul>
			<a name="ROLLO_Get"></a>
			<h4>Get</h4>
			<ul>
				<li><a name="rollo_version">
						<code>get &lt;Rollo-Device&gt; version</code></a>
					<br /> Returns the version number of the FHEM ROLLO module</li>
			</ul>
			<h4>Attributes</h4>
			<ul>
				<li><a name="rollo_type"><code>attr &lt;Rollo-Device&gt; type [normal|HomeKit]</code></a>
					<br />Type differentiation to support different hardware. Depending on the selected type, the direction of which the position is expected to set:<BR/>
							normal = position 0 means open, position 100 means closed<BR/>
							HomeKit = position 100 means open, position 0 means closed</li>
				<li><a name="rollo_secondsDown"><code>attr &lt;Rollo-Device&gt; secondsDown	&lt;number&gt;</code></a>
					<br />time in seconds needed to drive the shutter down</li>
				<li><a name="rollo_secondsUp"><code>attr &lt;Rollo-Device&gt; secondsUp	&lt;number&gt;</code></a>
					<br />time in seconds needed to drive the shutter up</li>
				<li><a name="rollo_excessTop"><code>attr &lt;Rollo-Device&gt; excessTop	&lt;number&gt;</code></a>
					<br />additional time the shutter need from last visible top position to the end position</li>
				<li><a name="rollo_excessBottom"><code>attr &lt;Rollo-Device&gt; excessBottom &lt;number&gt;</code></a>
					<br />additional time the shutter need from visible closed position to the end position</li>
				<li><a name="rollo_switchTime"><code>attr &lt;Rollo-Device&gt; switchTime &lt;number&gt;</code></a>
					<br />time for the shutter to switch from one driving direction to other driving direction</li>
				<li><a name="rollo_resetTime"><code>attr &lt;Rollo-Device&gt; resetTime	&lt;number&gt;</code></a>
					<br />additional time the shutter remain in driving state if driving to final positions (open, closed), to ensure that the final position was really approached. So difference in the position calculation can be corrected.</li>
				<li><a name="rollo_reactionTime"><code>attr &lt;Rollo-Device&gt; reactionTime &lt;number&gt;</code></a> 
					<br />additional time the shutter need to start (from start command to realy starting the motor)</li>
				<li><a name="rollo_autoStop"><code>attr &lt;Rollo-Device&gt; autoStop [0|1]</code></a>
					<br />It must be carried out no stop command, the shutter stops by itself.</li>
				<li><a name="rollo_commandUp"><code>attr &lt;Rollo-Device&gt; commandUp &lt;string&gt;</code></a>
					<br />Up to three commands you have to send to drive the shutter up</li>
				<li><a name="rollo_commandDown"><code>attr &lt;Rollo-Device&gt; commandDown &lt;string&gt;</code></a>
					<br />Up to three commandy you have to send to drive the shutter down</li>					
				<li><a name="rollo_commandStop"><code>attr &lt;Rollo-Device&gt; commandStop &lt;string&gt;</code></a>
					<br />command to stop a driving shutter</li>					
				<li><a name="rollo_commandStopDown"><code>attr &lt;Rollo-Device&gt; commandStopDown &lt;string&gt;</code></a>
					<br />command to stop a down driving shutter, if not set commandStop is executed</li>					
				<li><a name="rollo_commandStopUp"><code>attr &lt;Rollo-Device&gt; commandStopUp &lt;string&gt;</code></a>
					<br />command to stop a up driving shutter, if not set commandStop is executed</li>
				<li><a name="rollo_blockMode"><code>attr &lt;Rollo-Device&gt; blockMode [blocked|force-open|force-closed|only-up|only-down|half-up|half-down|none]</code></a>
					<br />the possibility of the shutter in blocked mode:<br>
							blocked = shutter can't drive<br>
							force-open = drive the shutter up if a drive command is send<br>
							force-closed = drive the shutter down if a drive command is send<br>
							only-up = only drive up commands are executed<br>
							only-down =only drive down commands are executed<br>
							half-up = only drive to positions above half-up<br>
							half-down = only drive to positions below half-down<br>
							none = blockmode is disabled</li>
				<li><a name="rollo_automatic-enabled"><code>attr &lt;Rollo-Device&gt; automatic-enabled [yes|no]</code></a>
					<br />if disabled the additional module ROLLO_AUTOMATIC don't drive the shutter</li>
				<li><a name="rollo_automatic-delay"><code>attr &lt;Rollo-Device&gt; automatic-delay	&lt;number&gt;</code></a>
					<br />if set any ROLLO_AUTOMATIC  commandy are executed delayed (in minutes)<br></li>
				<li><a href="#readingFnAttributes">readingFnAttributes</a></li>
			</ul>
</ul>
=end html

=begin html_DE

<a name="ROLLO"></a>
<h3>ROLLO</h3>
<ul>
			<p>Das Modul ROLLO bietet eine einfache Moeglichkeit, mit ein bis zwei Relais den Hoch-/Runterlauf eines Rolladen zu steuern und punktgenau anzuhalten.<br> 
			Ausserdem wird die aktuelle Position in fhem abgebildet. Ueber welche Hardware/Module die Ausgaenge angesprochen werden ist dabei egal.<br /><h4>Example</h4>
			<p>
				<code>define TestRollo ROLLO</code>
				<br />
			</p><a name="ROLLO_Define"></a>
			<h4>Define</h4>
			<p>
				<code>define &lt;Rollo-Device&gt; ROLLO</code> 
				<br /><br /> Defination eines Rollos.<br />
			</p>
			 <a name="ROLLO_Set"></a>
	 <h4>Set</h4>
			<ul>
				<li><a name="rollo_open">
						<code>set &lt;Rollo-Device&gt; open</code></a><br />
						Faehrt das Rollo komplett auf (Position 0) </li>
				<li><a name="rollo_closed">
						<code>set &lt;Rollo-Device&gt; closed</code></a><br />
						Faehrt das Rollo komplett zu (Position 100) </li>		
				<li><a name="rollo_half">
						<code>set &lt;Rollo-Device&gt; half</code></a><br />
						Faehrt das Rollo zur haelfte runter bzw. hoch (Position 50) </li>						
				<li><a name="rollo_stop">
						<code>set &lt;Rollo-Device&gt; stop</code></a><br />
						Stoppt das Rollo</li>						
				<li><a name="rollo_blocked">
						<code>set &lt;Rollo-Device&gt; blocked</code></a><br />
						Erklaerung folgt</li>
				<li><a name="rollo_unblocked">
						<code>set &lt;Rollo-Device&gt; unblocked</code></a><br />
						Erklaerung folgt</li>
				<li><a name="rollo_position">
						<code>set &lt;Rollo-Device&gt; position &lt;value&gt;</code></a><br />
						Faehrt das Rollo auf eine beliebige Position zwischen 0 (offen) - 100 (geschlossen) </li> 
				<li><a name="rollo_reset">
						<code>set &lt;Rollo-Device&gt; reset &lt;value&gt;</code></a><br />
						Sagt dem Modul in welcher Position sich der Rollo befindet</li> 
				<li><a name="rollo_extern">
						<code>set &lt;Rollo-Device&gt; extern &lt;value&gt;</code></a><br />
						Der Software mitteilen das gerade Befehl X bereits ausgeführt wurde und nun z.B,. das berechnen der aktuellen Position gestartet werden soll</li> 
			</ul>
			<a name="ROLLO_Get"></a>
			<h4>Get</h4>
			<ul>
				<li><a name="rollo_version">
						<code>get &lt;Rollo-Device&gt; version</code></a>
					<br />Gibt die version des Modul Rollos aus</li>
			</ul>
			<h4>Attributes</h4>
			<ul>
				<li><a name="rollo_type"><code>attr &lt;Rollo-Device&gt; type [normal|HomeKit]</code></a>
					<br />Typunterscheidung zur unterstützung verschiedener Hardware. Abhängig vom gewählten Typ wird die Richtung von der die Position gerechnet wird festgelegt:<BR/>
							normal = Position 0 ist offen, Position 100 ist geschlossen<BR/>
							HomeKit = Position 100 ist offen, Position 0 ist geschlossen</li>
				<li><a name="rollo_secondsDown"><code>attr &lt;Rollo-Device&gt; secondsDown	&lt;number&gt;</code></a>
					<br />Sekunden zum hochfahren</li>
				<li><a name="rollo_secondsUp"><code>attr &lt;Rollo-Device&gt; secondsUp	&lt;number&gt;</code></a>
					<br />Sekunden zum herunterfahren</li>
				<li><a name="rollo_excessTop"><code>attr &lt;Rollo-Device&gt; excessTop	&lt;number&gt;</code></a>
					<br />Zeit die mein Rollo Fahren muss ohne das sich die Rollo-Position ändert (bei mir fährt der Rollo noch in die Wand, ohne das man es am Fenster sieht, die Position ist also schon bei 0%)</li>
				<li><a name="rollo_excessBottom"><code>attr &lt;Rollo-Device&gt; excessBottom &lt;number&gt;</code></a>
					<br />(siehe excessTop)</li>
				<li><a name="rollo_switchTime"><code>attr &lt;Rollo-Device&gt; switchTime &lt;number&gt;</code></a>
					<br />Zeit die zwischen 2 gegensätzlichen Laufbefehlen pausiert werden soll, also wenn der Rollo z.B. gerade runter fährt und ich den Befehl gebe hoch zu fahren, dann soll 1 sekunde gewartet werden bis der Motor wirklich zum stillstand kommt, bevor es wieder in die andere Richtung weiter geht. Dies ist die einzige Zeit die nichts mit der eigentlichen Laufzeit des Motors zu tun hat, sondern ein timer zwischen den Laufzeiten.</li>
				<li><a name="rollo_resetTime"><code>attr &lt;Rollo-Device&gt; resetTime	&lt;number&gt;</code></a>
					<br />Zeit die beim Anfahren von Endpositionen (offen,geschlossen) der Motor zusätzlich an bleiben soll um sicherzustellen das die Endposition wirklich angefahren wurde. Dadurch können Differenzen in der Positionsberechnung korrigiert werden.</li>
				<li><a name="rollo_reactionTime"><code>attr &lt;Rollo-Device&gt; reactionTime &lt;number&gt;</code></a> 
					<br />Zeit für den Motor zum reagieren</li>
				<li><a name="rollo_autoStop"><code>attr &lt;Rollo-Device&gt; autoStop [0|1]</code></a>
					<br />Es muss kein Stop-Befehl ausgeführt werden, das Rollo stoppt von selbst.</li>
				<li><a name="rollo_commandUp"><code>attr &lt;Rollo-Device&gt; commandUp	&lt;string&gt;</code></a>
					<br />Es werden bis zu 3 beliebige Befehle zum hochfahren ausgeführt</li>
				<li><a name="rollo_commandDown"><code>attr &lt;Rollo-Device&gt; commandDown	&lt;string&gt;</code></a>
					<br />Es werden bis zu 3 beliebige Befehle zum runterfahren ausgeführt</li>					
				<li><a name="rollo_commandStop"><code>attr &lt;Rollo-Device&gt; commandStop	&lt;string&gt;</code></a>
					<br />Befehl der zum Stoppen ausgeführt wird, sofern nicht commandStopDown bzw. commandStopUp definiert sind</li>					
				<li><a name="rollo_commandStopDown"><code>attr &lt;Rollo-Device&gt; commandStopDown	&lt;string&gt;</code></a>
					<br />Befehl der zum stoppen ausgeführt wird, wenn der Rollo gerade herunterfährt. Wenn nicht definiert wird commandStop ausgeführt</li>					
				<li><a name="rollo_commandStopUp"><code>attr &lt;Rollo-Device&gt; commandStopUp	&lt;string&gt;</code></a>
					<br />Befehl der zum Stoppen ausgeführt wird,wenn der Rollo gerade hochfährt. Wenn nicht definiert wird commandStop ausgeführt</li>
				<li><a name="rollo_blockMode"><code>attr &lt;Rollo-Device&gt; blockMode [blocked|force-open|force-closed|only-up|only-down|half-up|half-down|none]</code></a>
					<br />wenn ich den Befehl blocked ausführe, dann wird aufgrund der blockMode-Art festgelegt wie mein Rollo reagieren soll:<br>
							blocked = Rollo lässt sich nicht mehr bewegen<br>
							force-open = bei einem beliebigen Fahrbefehl wird Rollo hochgefahren<br>
							force-closed = bei einem beliebigen Fahrbefehl wird Rollo runtergefahren<br>
							only-up = Befehle zum runterfahren werden ignoriert<br>
							only-down = Befehle zum hochfahren werden ignoriert<br>
							half-up = es werden nur die Positionen 50-100 angefahren, bei Position <50 wird Position 50% angefahren,<br>
							half-down = es werden nur die Positionen 0-50 angefahren, bei Position >50 wird Position 50 angefahren<br>
							none = block-Modus ist deaktiviert</li>
				<li><a name="rollo_automatic-enabled"><code>attr &lt;Rollo-Device&gt; automatic-enabled	[on|off]</code></a>
					<br />Wenn auf off gestellt, haben Befehle über Modul ROLLO_Automatic keine Auswirkungen auf diesen Rollo</li>
				<li><a name="rollo_automatic-delay"><code>attr &lt;Rollo-Device&gt; automatic-delay	&lt;number&gt;</code></a>
					<br />Dieses Attribut wird nur fuer die Modulerweiterung ROLLADEN_Automatic benoetigt.<br>
					Hiermit kann einge Zeitverzoegerund fuer den Rolladen eingestellt werden, werden die Rolladen per Automatic heruntergefahren, so wird dieser um die angegebenen minuten spaeter heruntergefahren. 
					</li>
				<li><a href="#readingFnAttributes">readingFnAttributes</a></li>
			</ul>
</ul>
=end html_DE
=cut
