############################################################
# $Id: 44_ROLLO.pm 1100 2016-06-08 20:00:00Z             $ #
# Modul zur einfacheren Rolladensteuerung
#
# Thomas Ramm, 2016
# Tim Horenkamp, 2016
#
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

my $version = "1.101";

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
    . " resetTime"
    . " reactionTime"
    . " blockMode:blocked,force-open,force-closed,only-up,only-down,half-up,half-down,none"
    . " commandUp commandUp2 commandUp3"
    . " commandDown commandDown2 commandDown3"
    . " commandStop commandStopDown commandStopUp "
    . " automatic-enabled:on,off automatic-delay ".
    $readingFnAttributes;

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
  $attr{$name}{"resetTime"} = 1;
 # $attr{$name}{"blockMode"} = "none";
  $attr{$name}{"webCmd"} = "open:closed:half:stop:position";
  $attr{$name}{"devStateIcon"} = 'open:fts_shutter_10:closed closed:fts_shutter_100:open schlitz:fts_shutter_80:closed drive-up:fts_shutter_up@red:stop drive-down:fts_shutter_down@red:stop position-100:fts_shutter_100:open position-90:fts_shutter_80:closed position-80:fts_shutter_80:closed position-70:fts_shutter_70:closed position-60:fts_shutter_60:closed position-50:fts_shutter_50:closed position-40:fts_shutter_40:open position-30:fts_shutter_30:open position-20:fts_shutter_20:open position-10:fts_shutter_10:open position-0:fts_shutter_10:closed';
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
    Log3 $name,3,"\"set ROLLO\" needs at least one argument";
    return "\"ROLLO_Set\" needs at least one argument";
  }
  my $cmd =  $a[1];
  my $arg = "";
  $arg = $a[2] if defined $a[2];

  Log3 $name,4,"ROLLO_Set $cmd:$arg";

  my @positionsets = ("0","10","20","30","40","50","60","70","80","90","100");

  if(!defined($sets{$cmd}) && $cmd !~ @positionsets) {
    my $param = "";
    foreach my $val (keys %sets) {
        $param .= " $val:$sets{$val}";
    }
    if ($cmd ne "?") {
      Log3 $name,3,"Unknown command $cmd, choose one of $param";
    }
    return "Unknown argument $cmd, choose one of $param";
  }
#allgemeine Fehler ENDE
  Log3 $name,1,"cmd:$cmd | arg:$arg";


  if (($cmd eq "stop") && (ReadingsVal($name,"state",'') !~ /drive/))
  {
    Log3 $name,1,"FEHLER: WARUM BIN ICH HIER?";
    RemoveInternalTimer($hash);
    Log3 $name,3,"Stopaufruf 1";
	ROLLO_Stop($hash);
    return undef;
  } elsif ($cmd eq "extern") {
    readingsSingleUpdate($hash,"extern","extern",0);
    $cmd = $arg;
  } elsif ($cmd eq "reset") {
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash,"state",$arg);
    readingsBulkUpdate($hash,"desired_position",$positions{$arg});
    readingsBulkUpdate($hash,"position",$positions{$arg});
    readingsEndUpdate($hash,1);
    return undef;
  } elsif ($cmd eq "blocked") {
	Log3 $name,3,"Stopaufruf 2";
    ROLLO_Stop($hash);
    readingsSingleUpdate($hash,"blocked","1",1);
    return if(AttrVal($name,"blockMode","none") eq "blocked");
  } elsif ($cmd eq "unblocked") {
  	Log3 $name,3,"Stopaufruf 3";
    ROLLO_Stop($hash);
    readingsSingleUpdate($hash,"blocked","0",1);
    ROLLO_Start($hash);
    fhem( "deletereading $name blocked");
    return;
  }
  my $desiredPos = $cmd;
  if ($cmd eq "position" && $arg ~~ @positionsets)
  {
    $cmd = "position-". $arg;
    $desiredPos = $arg;
  }
  elsif ($cmd ~~ @positionsets)
  {
    $cmd = "position-". $cmd;
    $desiredPos = $cmd;
  } else {
    $desiredPos = $positions{$cmd}
  }

  Log3 $name,1,"desired_position = $desiredPos" if($cmd ne "blocked") && ($cmd ne "stop");
  readingsSingleUpdate($hash,"command",$cmd,1);
  readingsSingleUpdate($hash,"desired_position",$desiredPos,1) if($cmd ne "blocked") && ($cmd ne "stop");

  ROLLO_Start($hash);
  return undef;
}

#################################################################### START #####
sub ROLLO_Start($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  my $command = ReadingsVal($name,"command","stop");
  my $desired_position = ReadingsVal($name,"desired_position",100);
  my $position = ReadingsVal($name,"position",0);
  my $state = ReadingsVal($name,"state","open");

  Log3 $name,4,"ROLLO_Start: $name drive from $position to $desired_position. command: $command. state: $state";

  if(ReadingsVal($name,"blocked","0") eq "1" && $command ne "stop")
  {
    my $blockmode = AttrVal($name,"blockMode","none");
    Log3 $name,3,"block mode: $blockmode - $position to $desired_position?";

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
  Log3 $name,5,"$name position: $position -> $desired_position / direction: $direction";

  #Ich fahre ja gerade...wo bin ich aktuell?
  if ($state =~ /drive-/)
  {

		$position = ROLLO_calculatePosition($hash,$name);

    if ($command eq "stop")
    {
      #readingsSingleUpdate($hash,"position",$position,0);
      Log3 $name,3,"Stopaufruf 4";
	  ROLLO_Stop($hash);
      return;
    }

    $direction = "down";
    $direction = "up" if ($position > $desired_position || $desired_position == 0);
    if ( (($state eq "drive-down") && ($direction eq "up")) || (($state eq "drive-up") && ($direction eq "down")) )
    {
      Log3 $name,2,"wrong direction";
	Log3 $name,3,"Stopaufruf 5";
      ROLLO_Stop($hash);
      InternalTimer(int(gettimeofday())+AttrVal($name,'resetTime',0) , "ROLLO_Start", $hash, 0);
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
    if (ReadingsVal($name,"extern","undef") ne "extern") {
	  Log3 $name,4,"ROLLO sends: $command1   $command2   $command3";
      fhem("$command1") if ($command1 ne "");
      fhem("$command2") if ($command2 ne "");
      fhem("$command3") if ($command3 ne "");
    } else {
      fhem("deletereading $name extern");
      Log3 $name,5,"Befehle nicht ausgeführt da extern getriggert: $command1 | $command2 | $command3";
    }

    $hash->{stoptime} = int(gettimeofday()+$time);
    InternalTimer($hash->{stoptime}, "ROLLO_Timer", $hash, 1);
    Log3 $name,5,"stops in $time seconds.";


  }
  Log3 $name,5,"ROLLO ($name) << Start";
  return undef;
}
sub ROLLO_Timer($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  Log3 $name,5,"ROLLO ($name) >> Timer abgelaufen";
  my $position = ReadingsVal($name,"desired_position",0);
  readingsSingleUpdate($hash,"position",$position,0);
  Log3 $name,3,"Stopaufruf 6";
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

  Log3 $name,4,"ROLLO_Stop: stops from $state at position $position";

  if( ($state =~ /drive-/ && $position > 0 && $position < 100 ) || AttrVal($name, "autoStop", 0) ne 1)
  {
    my $command = AttrVal($name,'commandStop',"");
    $command = AttrVal($name,'commandStopUp',"") if(defined($attr{$name}{commandStopUp}));
    $command = AttrVal($name,'commandStopDown',"") if(defined($attr{$name}{commandStopDown}) && $state eq "drive-down");

    # NUR WENN NICHT BEREITS EXTERN GESTOPPT
    if (ReadingsVal($name,"extern","undef") ne "extern") {
      fhem("$command") if ($command ne "");
    } else {
      fhem("deletereading $name extern");
      Log3 $name,5,"Rollo extern gestoppt";
    }
    Log3 $name,5,"ROLLO stop command: $command";
  }

  if(ReadingsVal($name,"blocked","0") eq "1" && AttrVal($name,"blockMode","none") ne "none")
  {
    readingsSingleUpdate($hash,"state","blocked",1);
  }
  else
  {
    my $newpos = int($position/10+0.5)*10;
    $newpos = 0 if($newpos < 0);
    $newpos = 100 if ($newpos > 100);

    my $state = "position-$newpos";
    my %rhash = reverse %positions;
    if (defined($rhash{$newpos}))
    {
      $state = $rhash{$newpos};
    }
    readingsSingleUpdate($hash,"state",$state,1);
  }

  Log3 $name,5,"ROLLO ($name) << Stop";
  return undef;
}
#****************************************************************************
sub ROLLO_calculatePosition(@) {
  my ($hash,$name) = @_;
  my ($position);
  Log3 $name,4,"calculate position for $name";

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
  $drivetime_rest -= AttrVal($name,'excessTop',0) if($end == 0);
  $drivetime_rest -= AttrVal($name,'excessBottom',0) if($end == 100);
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
  Log3 $name,4,"calculated Position is $position (drivetime_rest is $drivetime_rest)";
  #aktuelle Position aktualisieren und zurückgeben
  readingsSingleUpdate($hash,"position",$position,100);
  return $position;
}
#****************************************************************************
sub ROLLO_calculateDriveTime(@) {
  my ($name,$oldpos,$newpos,$direction) = @_;
  Log3 $name,4,"ROLLO going $direction: $oldpos > $newpos";

  my ($time, $steps);
  if ($direction eq "up") {
    $time = AttrVal($name,'secondsUp',undef);
    $steps = $oldpos-$newpos;
  } else {
    $time = AttrVal($name,'secondsDown',undef);
    $steps = $newpos-$oldpos;
  }
  if ($steps == 0) {
    Log3 $name,3,"already at position!";
  }

  if(!defined($time)) {
    Log3 $name,1,"ROLLO ERROR: missing attribute secondsUp or secondsDown";
    $time = 60;
  }

  my $drivetime = $time*$steps/100;
  $drivetime += AttrVal($name,'reactionTime',0) if($time > 0 && $steps > 0);

  $drivetime += AttrVal($name,'excessTop',0) if($oldpos == 0 or $newpos == 0);
  $drivetime += AttrVal($name,'excessBottom',0) if($oldpos == 100 or $newpos == 100);

  Log3 $name,5,"drivetime: oldpos=$oldpos,newpos=$newpos,direction=$direction,time=$time,steps=$steps,drivetime=$drivetime";
  return $drivetime;
}

################################################################### GET #####
#
sub ROLLO_Get($@) {
  my ($hash, @a) = @_;
  my $name = $hash->{NAME};

  #-- get version
  if( $a[1] eq "version") {
    return "$name.version => $version";
  }
  if ( @a < 2 ) {
    Log3 $name,3, "\"get ROLLO\" needs at least one argument";
    return "\"get ROLLO\" needs at least one argument";
  }

  my $cmd = $a[1];
  if(!$gets{$cmd}) {
    my @cList = keys %gets;
    Log3 $name,3,"Unknown argument $cmd, choose one of " . join(" ", @cList) if ($cmd ne "?");
    return "Unknown argument $cmd, choose one of " . join(" ", @cList);
  }
  my $val = "";
  if (@a > 2) {
    $val = $a[2];
  }
  Log3 $name,5,"ROLLO_Get -> $cmd:$val";

#  if ($cmd eq "write_hash_to_log") {
#    Log3 $name,1,"----- Write Hash to Log START -----";
#    Log3 $name,1,Dumper($hash);
#    Log3 $name,1,"----- Write Hash to Log END -------"
#  }

}

################################################################## ATTR #####
#
sub ROLLO_Attr(@) {
  my ($cmd,$name,$aName,$aVal) = @_;

  if ($cmd eq "set") {
    if ($aName eq "Regex") {
      eval { qr/$aVal/ };
      if ($@) {
        Log3 $name, 3, "ROLLO: Invalid regex in attr $name $aName $aVal: $@";
	return "Invalid Regex $aVal";
      }
    }
  }
  return undef;
}

1;


=pod
=begin html

<a name="ROLLOneu"></a>
<h3>ROLLOneu</h3>
<p>The module SHADE offers easy away to steer the shutter with one or two relays and to stop point-exactly. <br> 
			Moreover, the topical position is illustrated in fhem. About which hardware the exits are appealed, besides, makes no difference. <br />
			<h4>Example</h4>
			<p>
				<code>define TestRollo ROLLOneu</code>
				<br />
			</p><a name="ROLLOneu_Define"></a>
			<h4>Define</h4>
			<p>
				<code>define &lt;Rollo-Device&gt; ROLLOneu</code> 
				<br /><br /> Define a ROLLOneu instance.<br />
			</p>
			 <a name="ROLLOneu_Set"></a>
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
			<a name="ROLLOneu_Get"></a>
			<h4>Get</h4>
			<ul>
				<li><a name="rollo_version">
						<code>get &lt;Rollo-Device&gt; version</code></a>
					<br /> Returns the version number of the FHEM ROLLOneu module</li>
			</ul>
			<h4>Attributes</h4>
			<ul>
				<li><a name="rollo_secondsDown"><code>attr &lt;Rollo-Device&gt; secondsDown
							&lt;string&gt;</code></a>
					<br />Sekunden zum hochfahren</li>
				<li><a name="rollo_secondsUp"><code>attr &lt;Rollo-Device&gt; secondsUp
							&lt;string&gt;</code></a>
					<br />Sekunden zum herunterfahren</li>
				<li><a name="rollo_excessTop"><code>attr &lt;Rollo-Device&gt; excessTop
							&lt;string&gt;</code></a>
					<br />Zeit die mein Rollo Fahren muss ohne das sich die Rollo-Position ändert (bei mir fährt der Rollo noch in die Wand, ohne das man es am Fenster sieht, die Position ist also schon bei 0%)</li>
				<li><a name="rollo_excessBottom"><code>attr &lt;Rollo-Device&gt; excessBottom
							&lt;string&gt;</code></a>
					<br />(siehe excessTop)</li>
				<li><a name="rollo_resetTime"><code>attr &lt;Rollo-Device&gt; resetTime
							&lt;string&gt;</code></a>
					<br />Zeit die zwischen 2 gegensätzlichen Laufbefehlen pausiert werden soll, also wenn der Rollo z.B. gerade runter fährt und ich den Befehl gebe hoch zu fahren, dann soll 1 sekunde gewartet werden bis der Motor wirklich zum stillstand kommt, bevor es wieder in die andere Richtung weiter geht. Dies ist die einzige Zeit die nichts mit der eigentlichen Laufzeit des Motors zu tun hat, sondern ein timer zwischen den Laufzeiten.</li>
				<li><a name="rollo_reactionTime"><code>attr &lt;Rollo-Device&gt; reactionTime
							&lt;string&gt;</code></a> 
					<br />Zeit für den Motor zum reagieren</li>
				<li><a name="rollo_commandUp"><code>attr &lt;Rollo-Device&gt; commandUp
							&lt;string&gt;</code></a>
					<br />Es werden bis zu 3 beliebige Befehle zum hochfahren ausgeführt</li>
				<li><a name="rollo_commandDown"><code>attr &lt;Rollo-Device&gt; commandDown
							&lt;string&gt;</code></a>
					<br />Es werden bis zu 3 beliebige Befehle zum runterfahren ausgeführt</li>					
				<li><a name="rollo_commandStop"><code>attr &lt;Rollo-Device&gt; commandStop
							&lt;string&gt;</code></a>
					<br />Befehl der zum Stoppen ausgeführt wird, sofern nicht commandStopDown bzw. commandStopUp definiert sind</li>					
				<li><a name="rollo_commandStopDown"><code>attr &lt;Rollo-Device&gt; commandStopDown
							&lt;string&gt;</code></a>
					<br />Befehl der zum stoppen ausgeführt wird, wenn der Rollo gerade herunterfährt. Wenn nicht definiert wird commandStop ausgeführt</li>					
				<li><a name="rollo_commandStopUp"><code>attr &lt;Rollo-Device&gt; commandStopUp
							&lt;string&gt;</code></a>
					<br />Befehl der zum Stoppen ausgeführt wird,wenn der Rollo gerade hochfährt. Wenn nicht definiert wird commandStop ausgeführt</li>
				<li><a name="rollo_blockMode"><code>attr &lt;Rollo-Device&gt; blockMode
							 [blocked|force-open|force-closed|only-up|only-down|half-up|half-down|none]</code></a>
					<br />wenn ich den Befehl blocked ausführe, dann wird aufgrund der blockMode-Art festgelegt wie mein Rollo reagieren soll:<br>
							blocked = Rollo lässt sich nicht mehr bewegen<br>
							force-open = bei einem beliebigen Fahrbefehl wird Rollo hochgefahren<br>
							force-closed = bei einem beliebigen Fahrbefehl wird Rollo runtergefahren<br>
							only-up = Befehle zum runterfahren werden ignoriert<br>
							only-down = Befehle zum hochfahren werden ignoriert<br>
							half-up = es werden nur die Positionen 50-100 angefahren, bei Position <50 wird Position 50% angefahren,<br>
							half-down = es werden nur die Positionen 0-50 angefahren, bei Position >50 wird Position 50 angefahren<br>
							none = block-Modus ist deaktiviert</li>
				<li><a name="rollo_automatic-enabled"><code>attr &lt;Rollo-Device&gt; automatic-enabled
							&lt;string&gt;]</code></a>
					<br />Wenn auf off gestellt, haben Befehle über Modul ROLLOneu_Automatic keine Auswirkungen auf diesen Rollo</li>
				<li><a name="rollo_automatic-delay"><code>attr &lt;Rollo-Device&gt; automatic-delay
							&lt;string&gt;</code></a>
					<br />Dieses Attribut wird nur fuer die Modulerweiterung ROLLADEN_Automatic benoetigt.<br>
					Hiermit kann einge Zeitverzoegerund fuer den Rolladen eingestellt werden, werden die Rolladen per Automatic heruntergefahren, so wird dieser um die angegebenen minuten spaeter heruntergefahren. 
					</li>
				<li><a name="rollo_Zeitaddition_Endanschlag"><code>attr &lt;Rollo-Device&gt; Zeitaddition_Endanschlag
							&lt;string&gt;</code></a>
					<br />Zeit in Sekunden, fuer die zeit die drauf gegeben werden soll um sicher zu sein das das Rollo wirklich am Ende ankommt falls die Zeiten zu knapp hinterlegt sind.</li>
				<li><a href="#readingFnAttributes">readingFnAttributes</a></li>
			</ul>
=end html

=begin html_DE

<a name="ROLLOneu"></a>
<h3>ROLLOneu</h3>
			<p>Das Modul ROLLOneu bietet eine einfache Moeglichkeit, mit ein bis zwei Relais den Hoch-/Runterlauf eines Rolladen zu steuern und punktgenau anzuhalten.<br> 
			Ausserdem wird die aktuelle Position in fhem abgebildet. Ueber welche Hardware/Module die Ausgaenge angesprochen werden ist dabei egal.<br /><h4>Example</h4>
			<p>
				<code>define TestRollo ROLLOneu</code>
				<br />
			</p><a name="ROLLOneu_Define"></a>
			<h4>Define</h4>
			<p>
				<code>define &lt;Rollo-Device&gt; ROLLOneu</code> 
				<br /><br /> Defination eines Rollos.<br />
			</p>
			 <a name="ROLLOneu_Set"></a>
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
			<a name="ROLLOneu_Get"></a>
			<h4>Get</h4>
			<ul>
				<li><a name="rollo_version">
						<code>get &lt;Rollo-Device&gt; version</code></a>
					<br />Gibt die version des Modul Rollos aus</li>
			</ul>
			<h4>Attributes</h4>
			<ul>
				<li><a name="rollo_secondsDown"><code>attr &lt;Rollo-Device&gt; secondsDown
							&lt;string&gt;</code></a>
					<br />Sekunden zum hochfahren</li>
				<li><a name="rollo_secondsUp"><code>attr &lt;Rollo-Device&gt; secondsUp
							&lt;string&gt;</code></a>
					<br />Sekunden zum herunterfahren</li>
				<li><a name="rollo_excessTop"><code>attr &lt;Rollo-Device&gt; excessTop
							&lt;string&gt;</code></a>
					<br />Zeit die mein Rollo Fahren muss ohne das sich die Rollo-Position ändert (bei mir fährt der Rollo noch in die Wand, ohne das man es am Fenster sieht, die Position ist also schon bei 0%)</li>
				<li><a name="rollo_excessBottom"><code>attr &lt;Rollo-Device&gt; excessBottom
							&lt;string&gt;</code></a>
					<br />(siehe excessTop)</li>
				<li><a name="rollo_resetTime"><code>attr &lt;Rollo-Device&gt; resetTime
							&lt;string&gt;</code></a>
					<br />Zeit die zwischen 2 gegensätzlichen Laufbefehlen pausiert werden soll, also wenn der Rollo z.B. gerade runter fährt und ich den Befehl gebe hoch zu fahren, dann soll 1 sekunde gewartet werden bis der Motor wirklich zum stillstand kommt, bevor es wieder in die andere Richtung weiter geht. Dies ist die einzige Zeit die nichts mit der eigentlichen Laufzeit des Motors zu tun hat, sondern ein timer zwischen den Laufzeiten.</li>
				<li><a name="rollo_reactionTime"><code>attr &lt;Rollo-Device&gt; reactionTime
							&lt;string&gt;</code></a> 
					<br />Zeit für den Motor zum reagieren</li>
				<li><a name="rollo_commandUp"><code>attr &lt;Rollo-Device&gt; commandUp
							&lt;string&gt;</code></a>
					<br />Es werden bis zu 3 beliebige Befehle zum hochfahren ausgeführt</li>
				<li><a name="rollo_commandDown"><code>attr &lt;Rollo-Device&gt; commandDown
							&lt;string&gt;</code></a>
					<br />Es werden bis zu 3 beliebige Befehle zum runterfahren ausgeführt</li>					
				<li><a name="rollo_commandStop"><code>attr &lt;Rollo-Device&gt; commandStop
							&lt;string&gt;</code></a>
					<br />Befehl der zum Stoppen ausgeführt wird, sofern nicht commandStopDown bzw. commandStopUp definiert sind</li>					
				<li><a name="rollo_commandStopDown"><code>attr &lt;Rollo-Device&gt; commandStopDown
							&lt;string&gt;</code></a>
					<br />Befehl der zum stoppen ausgeführt wird, wenn der Rollo gerade herunterfährt. Wenn nicht definiert wird commandStop ausgeführt</li>					
				<li><a name="rollo_commandStopUp"><code>attr &lt;Rollo-Device&gt; commandStopUp
							&lt;string&gt;</code></a>
					<br />Befehl der zum Stoppen ausgeführt wird,wenn der Rollo gerade hochfährt. Wenn nicht definiert wird commandStop ausgeführt</li>
				<li><a name="rollo_blockMode"><code>attr &lt;Rollo-Device&gt; blockMode
							 [blocked|force-open|force-closed|only-up|only-down|half-up|half-down|none]</code></a>
					<br />wenn ich den Befehl blocked ausführe, dann wird aufgrund der blockMode-Art festgelegt wie mein Rollo reagieren soll:<br>
							blocked = Rollo lässt sich nicht mehr bewegen<br>
							force-open = bei einem beliebigen Fahrbefehl wird Rollo hochgefahren<br>
							force-closed = bei einem beliebigen Fahrbefehl wird Rollo runtergefahren<br>
							only-up = Befehle zum runterfahren werden ignoriert<br>
							only-down = Befehle zum hochfahren werden ignoriert<br>
							half-up = es werden nur die Positionen 50-100 angefahren, bei Position <50 wird Position 50% angefahren,<br>
							half-down = es werden nur die Positionen 0-50 angefahren, bei Position >50 wird Position 50 angefahren<br>
							none = block-Modus ist deaktiviert</li>
				<li><a name="rollo_automatic-enabled"><code>attr &lt;Rollo-Device&gt; automatic-enabled
							&lt;string&gt;]</code></a>
					<br />Wenn auf off gestellt, haben Befehle über Modul ROLLOneu_Automatic keine Auswirkungen auf diesen Rollo</li>
				<li><a name="rollo_automatic-delay"><code>attr &lt;Rollo-Device&gt; automatic-delay
							&lt;string&gt;</code></a>
					<br />Dieses Attribut wird nur fuer die Modulerweiterung ROLLADEN_Automatic benoetigt.<br>
					Hiermit kann einge Zeitverzoegerund fuer den Rolladen eingestellt werden, werden die Rolladen per Automatic heruntergefahren, so wird dieser um die angegebenen minuten spaeter heruntergefahren. 
					</li>
				<li><a name="rollo_Zeitaddition_Endanschlag"><code>attr &lt;Rollo-Device&gt; Zeitaddition_Endanschlag
							&lt;string&gt;</code></a>
					<br />Zeit in Sekunden, fuer die zeit die drauf gegeben werden soll um sicher zu sein das das Rollo wirklich am Ende ankommt falls die Zeiten zu knapp hinterlegt sind.</li>
				<li><a href="#readingFnAttributes">readingFnAttributes</a></li>
			</ul>

=end html_DE
=cut
