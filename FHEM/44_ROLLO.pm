########################################################################################
# $Id: 44_ROLLO.pm 1202 2018-07-23 08:38:00Z                                         $ #
# Modul zur einfacheren Rolladensteuerung   										   #
#  																					   #
# Thomas Ramm, 2016                                                                    #
# Tim Horenkamp, 2018                                                                  #
# Markus Moises, 2016                                                                  #
# Mirko Lindner, 2018                                                                  #
# KernSani, 2017																	   #
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

my $version = "1.400";

my %sets = (
    "open"      => "noArg",
    "closed"    => "noArg",
    "up"        => "noArg",
    "down"      => "noArg",
    "half"      => "noArg",
    "stop"      => "noArg",
    "blocked"   => "noArg",
    "unblocked" => "noArg",
    "pct"       => "0,10,20,30,40,50,60,70,80,90,100",
    "reset"     => "open,closed",
    "extern"    => "open,closed,stop",
    "drive"     => "textField"
);

my %pcts = (
    "open"   => 0,
    "closed" => 100,
    "half"   => 50
);

my %gets = ( "version:noArg" => "V" );

############################################################ INITIALIZE #####
sub ROLLO_Initialize($) {
    my ($hash) = @_;
    my $name = $hash->{NAME};

    $hash->{DefFn}   = "ROLLO_Define";
    $hash->{UndefFn} = "ROLLO_Undef";
    $hash->{SetFn}   = "ROLLO_Set";
    $hash->{GetFn}   = "ROLLO_Get";
    $hash->{AttrFn}  = "ROLLO_Attr";

    $hash->{AttrList} =
        " secondsDown"
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
	  . " disable:0,1"
      . " forceDrive:0,1"
      . " noSetPosBlocked:0,1" . " "
      . $readingFnAttributes;

    $hash->{stoptime} = 0;

    return undef;
}

################################################################ DEFINE #####
sub ROLLO_Define($$) {
    my ( $hash, $def ) = @_;
    my $name = $hash->{NAME};
    Log3 $name, 5, "ROLLO ($name) >> Define";

    my @a = split( "[ \t][ \t]*", $def );

    $attr{$name}{"secondsDown"}  = 30;
    $attr{$name}{"secondsUp"}    = 30;
    $attr{$name}{"excessTop"}    = 4;
    $attr{$name}{"excessBottom"} = 2;
    $attr{$name}{"switchTime"}   = 1;
    $attr{$name}{"resetTime"}    = 0;
    $attr{$name}{"autoStop"} = 0;    #neue Attribute sollten als default keine Änderung an der Funktionsweise bewirken.
    $attr{$name}{"devStateIcon"} =
'open:fts_shutter_10:closed closed:fts_shutter_100:open half:fts_shutter_50:closed drive-up:fts_shutter_up@red:stop drive-down:fts_shutter_down@red:stop pct-100:fts_shutter_100:open pct-90:fts_shutter_80:closed pct-80:fts_shutter_80:closed pct-70:fts_shutter_70:closed pct-60:fts_shutter_60:closed pct-50:fts_shutter_50:closed pct-40:fts_shutter_40:open pct-30:fts_shutter_30:open pct-20:fts_shutter_20:open pct-10:fts_shutter_10:open pct-0:fts_shutter_10:closed';
    $attr{$name}{"type"} = "normal"; #neue Attribute sollten als default keine Änderung an der Funktionsweise bewirken.

    #	$attr{$name}{"blockMode"} = "none";
	
	if (IsDisabled($name) ) {
        $hash->{STATE} = "inactive";
        $hash->{helper}{DISABLED} = 1;
    }
	
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
    my ( $hash, @a ) = @_;
    my $name = $hash->{NAME};
	
	return undef if IsDisabled($name);
	
    $attr{$name}{"webCmd"} = "open:closed:half:stop:pct";
	if (ReadingsVal($name,"position","exists") ne "exists") {
		#Log3 $name,1, "ROLLO ($name) Readings position and desired_position aren't used anymore. Execute \"deletereading $name position\" and \"deletereading $name desired_position\" to remove them";
	}

    #allgemeine Fehler in der Parameterübergabe abfangen
    if ( @a < 2 ) {
        Log3 $name, 2, "ERROR: \"set ROLLO\" needs at least one argument";
        return "\"ROLLO_Set\" needs at least one argument";
    }
    my $cmd = $a[1];

	# Keep command "position" for a while
    if ($cmd eq "position" ) {
        $cmd = "pct";
        Log3 $name, 1, "ROLLO ($name) Set command \"position\" is deprecated. Please change your definitions to \"pct\"";
    }
	
    my $arg = "";
    $arg = $a[2] if defined $a[2];
    my $arg2 = "";
    $arg2 = $a[3] if defined $a[3];

    Log3 $name, 5, "ROLLO ($name) >> Set ($cmd,$arg)" if ( $cmd ne "?" );

    my @pctsets = ( "0", "10", "20", "30", "40", "50", "60", "70", "80", "90", "100" );

    if ( !defined( $sets{$cmd} ) && $cmd !~ @pctsets ) {
        my $param = "";
        foreach my $val ( keys %sets ) {
            $param .= " $val:$sets{$val}";
        }

        Log3 $name, 2, "ERROR: Unknown command $cmd, choose one of $param" if ( $cmd ne "?" );
        return "Unknown argument $cmd, choose one of $param";
    }
	
	
	#### Stop if not driving - do we need that? 
    if ( ( $cmd eq "stop" ) && ( ReadingsVal( $name, "state", '' ) !~ /drive/ ) ) {
        Log3 $name, 3, "WARNING: command is stop but shutter is not driving!";
        RemoveInternalTimer($hash);
        ROLLO_Stop($hash);
        return undef;
    }

	
	##### Commands without IO
    if ( $cmd eq "extern" ) {
        readingsSingleUpdate( $hash, "drive-type", "extern", 1 );
        $cmd = $arg;
    }
    elsif ( $cmd eq "reset" ) {
        my $reset_pct = $pcts{$arg};
        $reset_pct = 100 - $reset_pct if ( AttrVal( $name, "type", "normal" ) eq "HomeKit" );

        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, "state",       $arg );
        readingsBulkUpdate( $hash, "desired_pct", $reset_pct );
        readingsBulkUpdate( $hash, "pct",         $reset_pct );
        readingsEndUpdate( $hash, 1 );
        return undef;
    }

	##### Block commands
    if ( $cmd eq "blocked" ) {
        ROLLO_Stop($hash);
        readingsSingleUpdate( $hash, "blocked", "1", 1 );
        return if ( AttrVal( $name, "blockMode", "none" ) eq "blocked" );
    }
    elsif ( $cmd eq "unblocked" ) {

        # Wenn blocked=1 wird in Rollo_Stop der state auf "blocked" gesetzt
        # daher erst blocked auf 0 (Stop ist m.E. an dieser Stelle eigentlich nicht notwendig)
        #ROLLO_Stop($hash); 							#delete KernSani
        readingsSingleUpdate( $hash, "blocked", "0", 1 );
        ROLLO_Stop($hash);    #add KernSani
        ROLLO_Start($hash);
		#avoid the deletereading mesage in Log  - KernSani 30.12.2018
        #fhem("deletereading $name blocked");   
		readingsDelete($hash, "blocked");
        return;
    }
	
	##### Drive for Seconds - Basic Implementation (doesn't consider block mode, Homekit, ...) 
    if ( $cmd eq "drive" ) {
		return "Drive needs two arguments, the direction and the time in seconds" if (!$arg2);
        my $direction = $arg;
        $arg = undef;
        my $time = $arg2;
		$hash->{driveTime} = $time;
		$hash->{driveDir} = $direction;
		my $dpct = ROLLO_calculateDesiredPosition($hash,$name);
		readingsSingleUpdate($hash,"desired_pct",$dpct,1);
        Log3 $name, 3, "ROLLO ($name) DRIVE Command drive $direction for $time seconds. ";
        ROLLO_Stop($hash);
        ROLLO_Drive( $hash, $time, $direction, $cmd );
        return undef;
    }

	##### now do the real drive stuff
	
    my $desiredPos = $cmd;
    Log3 $name, 5, "ROLLO ($name) DesiredPos set to $desiredPos, ($arg) ";
    my $typ = AttrVal( $name, "type", "normal" );

    # Allow all positions
    #if ( grep /^$arg$/, @pctsets )
	#Log3 $name, 5, "ROLLO ($name) Arg is $arg";
      #change sequence to avoid "is not numeric" warning
    #if ($arg && $arg =~ /^[0-9,.E]*$/ && $arg >= 0 && $arg <= 100 )
    if ($arg >= 0 && $arg <= 100 )
    {
        if ( $cmd eq "pct" ) {
            if ( $typ eq "HomeKit" ) {
                Log3 $name, 4, "ROLLO ($name) invert pct from $arg to (100-$arg)";
                $arg = 100 - $arg;
            }
            $cmd        = "pct-" . $arg;
            $desiredPos = $arg;
            Log3 $name, 5, "ROLLO ($name) DesiredPos now $desiredPos, $arg";
        }
        else { #I think this shouldn't happen... 
            if ( $typ eq "HomeKit" ) {
                $cmd = 100 - $cmd;
            }
            $cmd        = "pct-" . $cmd;
            $desiredPos = $cmd;
			Log3 $name, 5, "ROLLO ($name) There is an arg $arg, but command is $cmd";
        }
    }
    else {
        if ( $cmd eq "down" || $cmd eq "up" ) {

            # Recalculate the desired pct
            my $posin = ReadingsVal( $name, "pct", 0 );
            $posin = 100 - $posin if ( $typ eq "HomeKit" );
            $desiredPos = int( ( $posin - 10 ) / 10 + 0.5 ) * 10;
            $desiredPos = int( ( $posin + 10 ) / 10 + 0.5 ) * 10 if $cmd eq "down";
            $desiredPos = 100 if $desiredPos > 100;
            $desiredPos = 0   if $desiredPos < 0;
        }
        else {
            $desiredPos = $pcts{$cmd};
        }
		
		# Ich verstehe nicht wann nachfolgender Zustand eintreten kann, das Coding führt aber dazu, dass pct 0 (open) auf "none" gesetzt wird 
        #$desiredPos = "none" if !$desiredPos || $desiredPos eq "";  
    }
    Log3 $name, 5, "ROLLO ($name) DesiredPos now $desiredPos, $cmd";

    #wenn ich gerade am fahren bin und eine neue Zielposition angefahren werden soll,
    # muss ich jetzt erst mal meine aktuelle Position berechnen und updaten
    # bevor ich die desired-position überschreibe!

    if ( ( ReadingsVal( $name, "state", "" ) =~ /drive-/ ) ) {
        my $pct = ROLLO_calculatepct( $hash, $name );
        readingsSingleUpdate( $hash, "pct", $pct, 1 );

        # Desired-position sollte auf aktuelle position gesetzt werden, wenn explizit gestoppt wird.
        readingsSingleUpdate( $hash, "desired_pct", $pct, 1 )
          if ( ( $cmd eq "stop" || $cmd eq "blocked" ) && $pct > 0 && $pct < 100 );
    }
    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, "command", $cmd );

    # desired position sollte nicht gesetzt werden, wenn ein unerlaubter Befehl (wenn Rollladen geblockt ist)
    # gesendet wird. Sonst rennt er direkt nach dem "unblock" los
    # readingsBulkUpdate($hash,"desired_position",$desiredPos) if($cmd ne "blocked") && ($cmd ne "stop")
    readingsBulkUpdate( $hash, "desired_pct", $desiredPos )
      if ( $cmd ne "blocked" ) && ( $cmd ne "stop" ) && ROLLO_isAllowed( $hash, $cmd, $desiredPos );
    readingsEndUpdate( $hash, 1 );

    ROLLO_Start($hash);
    return undef;
}
#################################################################### isAllowed #####
sub ROLLO_isAllowed($$$) {
    my ( $hash, $cmd, $desired_pct ) = @_;
    my $name = $hash->{NAME};

    if ( ReadingsVal( $name, "blocked", "0" ) ne "1" or AttrVal( $name, "noSetPosBlocked", 0 ) == 0 ) {
        return 1;
    }
    my $pct = ReadingsVal( $name, "pct", undef );
	$pct = 100 - $pct if ( AttrVal( $name, "type", "normal" ) eq "HomeKit" );   # KernSani 30.12.2018
    my $blockmode = AttrVal( $name, "blockMode", "none" );
    Log3 $name, 3, "ROLLO ($name) >> Blockmode:$blockmode $pct-->$desired_pct";
    if (   $blockmode eq "blocked"
        || ( $blockmode eq "only-up"   && $pct <= $desired_pct )
        || ( $blockmode eq "only-down" && $pct >= $desired_pct ) )
    {
        return undef;
    }
    return 1;
}

#****************************************************************************
sub ROLLO_Drive {
    my ( $hash, $time, $direction, $command ) = @_;
    my $name = $hash->{NAME};
    my ( $command1, $command2, $command3 );
    if ( $direction eq "down" ) {
        $command1 = AttrVal( $name, 'commandDown',  "" );
        $command2 = AttrVal( $name, 'commandDown2', "" );
        $command3 = AttrVal( $name, 'commandDown3', "" );
    }
    else {
        $command1 = AttrVal( $name, 'commandUp',  "" );
        $command2 = AttrVal( $name, 'commandUp2', "" );
        $command3 = AttrVal( $name, 'commandUp3', "" );
    }

    $command = "drive-" . $direction;
    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, "last_drive", $command );
    readingsBulkUpdate( $hash, "state",      $command );
    readingsEndUpdate( $hash, 1 );

    #***** ROLLO NICHT LOSFAHREN WENN SCHON EXTERN GESTARTET *****#
    if ( ReadingsVal( $name, "drive-type", "undef" ) ne "extern" ) {
        Log3 $name, 4, "ROLLO ($name) execute following commands: $command1; $command2; $command3";
        readingsSingleUpdate( $hash, "drive-type", "modul", 1 );
        fhem("$command1") if ( $command1 ne "" );
        fhem("$command2") if ( $command2 ne "" );
        fhem("$command3") if ( $command3 ne "" );
    }
    else {
        #readingsSingleUpdate($hash,"drive-type","extern",1);
        readingsSingleUpdate( $hash, "drive-type", "na", 1 );
        Log3 $name, 4, "ROLLO ($name) drive-type is extern, not executing driving commands";
    }

    $hash->{stoptime} = int( gettimeofday() + $time );
    InternalTimer( $hash->{stoptime}, "ROLLO_Timer", $hash, 1 );
    Log3 $name, 4, "ROLLO ($name) stop in $time seconds.";
}

#################################################################### START #####
sub ROLLO_Start($) {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    Log3 $name, 5, "ROLLO ($name) >> Start";

    my $command     = ReadingsVal( $name, "command",     "stop" );
    my $desired_pct = ReadingsVal( $name, "desired_pct", 100 );
    my $pct         = ReadingsVal( $name, "pct",         0 );
    $pct = 100 - $pct if ( AttrVal( $name, "type", "normal" ) eq "HomeKit" );
    my $state = ReadingsVal( $name, "state", "open" );

    Log3 $name, 4, "ROLLO ($name) drive from $pct to $desired_pct. command: $command. state: $state";

    if ( ReadingsVal( $name, "blocked", "0" ) eq "1" && $command ne "stop" ) {
        my $blockmode = AttrVal( $name, "blockMode", "none" );
        Log3 $name, 4, "ROLLO ($name) block mode: $blockmode - $pct to $desired_pct?";

        if ( $blockmode eq "blocked" ) {
            readingsSingleUpdate( $hash, "state", "blocked", 1 );
            return;
        }
        elsif ( $blockmode eq "force-open" ) {
            $desired_pct = 0;
        }
        elsif ( $blockmode eq "force-closed" ) {
            $desired_pct = 100;
        }
        elsif ( $blockmode eq "only-up" && $pct <= $desired_pct ) {
            readingsSingleUpdate( $hash, "state", "blocked", 1 );
            return;
        }
        elsif ( $blockmode eq "only-down" && $pct >= $desired_pct ) {
            readingsSingleUpdate( $hash, "state", "blocked", 1 );
            return;
        }
        elsif ( $blockmode eq "half-up" && $desired_pct < 50 ) {
            $desired_pct = 50;
        }
        elsif ( $blockmode eq "half-up" && $desired_pct == 50 ) {
            readingsSingleUpdate( $hash, "state", "blocked", 1 );
            return;
        }
        elsif ( $blockmode eq "half-down" && $desired_pct > 50 ) {
            $desired_pct = 50;
        }
        elsif ( $blockmode eq "half-down" && $desired_pct == 50 ) {
            readingsSingleUpdate( $hash, "state", "blocked", 1 );
            return;
        }
		#desired_pct has to be updated - KernSani 30.12.2018
		readingsSingleUpdate( $hash, "desired_pct", $desired_pct, 1 );
    }

    my $direction = "down";
    $direction = "up" if ( $pct > $desired_pct || $desired_pct == 0 );
    #if ( $hash->{driveDir} ) { $direction = $hash->{driveDir} }
    Log3 $name, 4, "ROLLO ($name) pct: $pct -> $desired_pct / direction: $direction";

    #Ich fahre ja gerade...wo bin ich aktuell?
    if ( $state =~ /drive-/ ) {

        #$pct = ROLLO_calculatepct($hash,$name); #das muss weg.. verschoben in set!

        if ( $command eq "stop" ) {
            ROLLO_Stop($hash);
            return;
        }

        #$direction = "down";
        #$direction = "up" if ($pct > $desired_pct || $desired_pct == 0);
        if (   ( ( $state eq "drive-down" ) && ( $direction eq "up" ) )
            || ( ( $state eq "drive-up" ) && ( $direction eq "down" ) ) )
        {
            Log3 $name, 3, "driving into wrong direction. stop and change driving direction";
            ROLLO_Stop($hash);
            InternalTimer( int( gettimeofday() ) + AttrVal( $name, 'switchTime', 0 ), "ROLLO_Start", $hash, 0 );
            return;
        }
    }

    my $time = 0;

    RemoveInternalTimer($hash);

    $time = ROLLO_calculateDriveTime( $name, $pct, $desired_pct, $direction );

    if ( $time > 0 ) {
        ROLLO_Drive( $hash, $time, $direction, $command );
    }

    return undef;
}

#****************************************************************************
sub ROLLO_Timer($) {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    Log3 $name, 5, "ROLLO ($name) >> Timer";

    my $pct = ReadingsVal( $name, "desired_pct", 0 );
    $pct = 100 - $pct if ( AttrVal( $name, "type", "normal" ) eq "HomeKit" );

    readingsSingleUpdate( $hash, "pct", $pct, 1 );
    ROLLO_Stop($hash);

    return undef;
}

#****************************************************************************
sub ROLLO_Stop($) {
    my ($hash) = @_;
    my $name = $hash->{NAME};

    #my $command = ReadingsVal($name,"command","stop");

    Log3 $name, 5, "ROLLO ($name) >> Stop";

    RemoveInternalTimer($hash);
    my $pct = ReadingsVal( $name, "pct", 0 );
    $pct = 100 - $pct if ( AttrVal( $name, "type", "normal" ) eq "HomeKit" );
    my $state = ReadingsVal( $name, "state", "" );

    Log3 $name, 4, "ROLLO ($name) stops from $state at pct $pct";

    #wenn autostop=1 und pct <> 0+100 und rollo fährt, dann kein stopbefehl ausführen...
    if ( ( $state =~ /drive-/ && $pct >= 0 && $pct <= 100 ) || AttrVal( $name, "autoStop", 0 ) ne 1 ) {
        my $command = AttrVal( $name, 'commandStop', "" );
        $command = AttrVal( $name, 'commandStopUp', "" ) if ( defined( $attr{$name}{commandStopUp} ) );
        $command = AttrVal( $name, 'commandStopDown', "" )
          if ( defined( $attr{$name}{commandStopDown} ) && $state eq "drive-down" );

        # NUR WENN NICHT BEREITS EXTERN GESTOPPT
        if ( ReadingsVal( $name, "drive-type", "undef" ) ne "extern" ) {
            fhem("$command") if ( $command ne "" );
            Log3 $name, 4, "ROLLO ($name) stopped by excuting the command: $command";
        }
        else {
            readingsSingleUpdate( $hash, "drive-type", "na", 1 );
            Log3 $name, 4, "ROLLO ($name) is in drive-type extern";
        }
    }
    else {
        Log3 $name, 4, "ROLLO ($name) drives to end pct and autostop is enabled. No stop command executed";
    }

    if ( ReadingsVal( $name, "blocked", "0" ) eq "1" && AttrVal( $name, "blockMode", "none" ) ne "none" ) {
        readingsSingleUpdate( $hash, "state", "blocked", 1 );
    }
    else {
        #Runden der pct auf volle 10%-Schritte für das Icon
        my $newpos = int( $pct / 10 + 0.5 ) * 10;
        $newpos = 0   if ( $newpos < 0 );
        $newpos = 100 if ( $newpos > 100 );

        my $state;

        #pct in text umwandeln
        my %rhash = reverse %pcts;

        if ( defined( $rhash{$newpos} ) ) {

            #ich kenne keinen Text für die pct, also als pct-nn anzeigen
            $state = $rhash{$newpos};
        }
        else {
            $newpos = 100 - $newpos if ( AttrVal( $name, "type", "normal" ) eq "HomeKit" );
            $state = "pct-$newpos";
        }

        readingsSingleUpdate( $hash, "state", $state, 1 );
    }

    return undef;
}

#****************************************************************************
sub ROLLO_calculatepct(@) {
    my ( $hash, $name ) = @_;
    my ($pct);
    Log3 $name, 5, "ROLLO ($name) >> calculatepct";

    my $type = AttrVal( $name, "type", "normal" );
    my $start = ReadingsVal( $name, "pct", 100 );
    $start = 100 - $start if $type eq "HomeKit";

    my $end = ReadingsVal( $name, "desired_pct", 0 );
    my $drivetime_rest = int( $hash->{stoptime} - gettimeofday() );    #die noch zu fahrenden Sekunden
    my $drivetime_total =
      ( $start < $end ) ? AttrVal( $name, 'secondsDown', undef ) : AttrVal( $name, 'secondsUp', undef );

    # bsp: die fahrzeit von 0->100 ist 26sec. ich habe noch 6sec. zu fahren...was bedeutet das?
    # excessTop    = 5sec
    # driveTimeDown=20sec -> hier wird von 0->100 gezählt, also pro sekunde 5 Schritte
    # excessBottom = 1sec
    # aktuelle pct = 6sec-1sec=5sec pctsfahrzeit=25steps=pct75

    #Frage1: habe ich noch "tote" Sekunden vor mir wegen endpct?
    my $resetTime = AttrVal( $name, 'resetTime', 0 );
    $drivetime_rest -= ( AttrVal( $name, 'excessTop',    0 ) + $resetTime ) if ( $end == 0 );
    $drivetime_rest -= ( AttrVal( $name, 'excessBottom', 0 ) + $resetTime ) if ( $end == 100 );

  #wenn ich schon in der nachlaufzeit war, setze ich die pct auf 99, dann kann man nochmal für die nachlaufzeit starten
    if ( $start == $end ) {
        $pct = $end;
    }
    elsif ( $drivetime_rest < 0 ) {
        $pct = ( $start < $end ) ? 99 : 1;
    }
    else {
        $pct = $drivetime_rest / $drivetime_total * 100;
        $pct = ( $start < $end ) ? $end - $pct : $end + $pct;
        $pct = 0 if ( $pct < 0 );
        $pct = 100 if ( $pct > 100 );
    }

    #aktuelle pct aktualisieren und zurückgeben
    Log3 $name, 4, "ROLLO ($name) calculated pct is $pct; rest drivetime is $drivetime_rest";
    my $savepos = $pct;
    $savepos = 100 - $pct if $type eq "HomeKit";
    readingsSingleUpdate( $hash, "pct", $savepos, 100 );

    return $pct;
}

#****************************************************************************
sub ROLLO_calculateDesiredPosition(@) {
    my ( $hash, $name ) = @_;
    my ($pct);
    Log3 $name, 5, "ROLLO ($name) >> calculateDesiredPosition";

    my $start     = 0;
    my $dtime     = $hash->{driveTime};
    my $direction = $hash->{driveDir};
    Log3 $name, 4, "ROLLO ($name) drive $direction for $dtime";
    my ( $time, $steps );
    if ( $direction eq "up" ) {
        $time = AttrVal( $name, 'secondsUp', undef );
        $start = 100;
    }
    else {
        $time = AttrVal( $name, 'secondsDown', undef );
        $start = 0;
    }

    my $startPos = ReadingsVal( $name, "pct", 100 );

    $time += AttrVal( $name, 'reactionTime', 0 );

    #$time += AttrVal($name,'excessTop',0) if($startPos == 0);
    #$time += AttrVal($name,'excessBottom',0) if($startPos == 100);
    #$time += AttrVal($name,'resetTime', 0) if($startPos == 0 or $startPos == 100);

    $steps = $dtime / $time * 100;
    Log3 $name, 4, "ROLLO ($name) total time = $time, we're intending to drive $steps steps";
    if ( $direction eq "up" ) {
        $pct = $startPos - $steps;
    }
    else {
        $pct = $startPos + $steps;
    }
    $pct = 100 if ( $pct > 100 );
    $pct = 0   if ( $pct < 0 );

    Log3 $name, 4, "ROLLO ($name) Target pct is $pct";
    return int($pct);
}

#****************************************************************************
sub ROLLO_calculateDriveTime(@) {
    my ( $name, $oldpos, $newpos, $direction ) = @_;
    Log3 $name, 5, "ROLLO ($name) >> calculateDriveTime | going $direction: from $oldpos to $newpos";

    my ( $time, $steps );
    if ( $direction eq "up" ) {
        $time = AttrVal( $name, 'secondsUp', undef );
        $steps = $oldpos - $newpos;
    }
    else {
        $time = AttrVal( $name, 'secondsDown', undef );
        $steps = $newpos - $oldpos;
    }
    if ( $steps == 0 ) {
        Log3 $name, 4, "ROLLO ($name) already at position!";

        # Wenn force-Drive gesetzt ist fahren wir immer 100% (wenn "open" oder "closed")
        if ( AttrVal( $name, "forceDrive", undef ) == 1 && ( $oldpos == 0 || $oldpos == 100 ) ) {
            Log3 $name, 4, "ROLLO ($name): forceDrive set, driving $direction";
            $steps = 100;
        }
    }

    if ( !defined($time) ) {
        Log3 $name, 2, "ROLLO ($name) ERROR: missing attribute secondsUp or secondsDown";
        $time = 60;
    }

    my $drivetime = $time * $steps / 100;

    # reactionTime etc... sollten nur hinzugefügt werden, wenn auch gefahren wird...
    if ( $drivetime > 0 ) {
        $drivetime += AttrVal( $name, 'reactionTime', 0 ) if ( $time > 0 && $steps > 0 );

        $drivetime += AttrVal( $name, 'excessTop',    0 ) if ( $oldpos == 0   or $newpos == 0 );
        $drivetime += AttrVal( $name, 'excessBottom', 0 ) if ( $oldpos == 100 or $newpos == 100 );
        $drivetime += AttrVal( $name, 'resetTime',    0 ) if ( $newpos == 0   or $newpos == 100 );
        Log3 $name, 4,
"ROLLO ($name) calculateDriveTime: oldpos=$oldpos,newpos=$newpos,direction=$direction,time=$time,steps=$steps,drivetime=$drivetime";

    }
    return $drivetime;
}

################################################################### GET #####
sub ROLLO_Get($@) {
    my ( $hash, @a ) = @_;
    my $name = $hash->{NAME};
    Log3 $name, 5, "ROLLO ($name) >> Get";

    #-- get version
    if ( $a[1] eq "version" ) {
        return "$name.version => $version";
    }
    if ( @a < 2 ) {
        Log3 $name, 2, "ROLLO ($name) ERROR: \"get ROLLO\" needs at least one argument";
        return "\"get ROLLO\" needs at least one argument";
    }

    my $cmd = $a[1];
    if ( !$gets{$cmd} ) {
        my @cList = keys %gets;
        Log3 $name, 3, "ERROR: Unknown argument $cmd, choose one of " . join( " ", @cList ) if ( $cmd ne "?" );
        return "Unknown argument $cmd, choose one of " . join( " ", @cList );
    }

    my $val = "";
    $val = $a[2] if ( @a > 2 );
    Log3 $name, 4, "ROLLO ($name) command: $cmd, value: $val";
}

################################################################## ATTR #####
sub ROLLO_Attr(@) {
    my ( $cmd, $name, $aName, $aVal ) = @_;
    Log3 $name, 5, "ROLLO ($name) >> Attr";
	my $hash = $defs{$name};
	
    if ( $cmd eq "set" ) {
        if ( $aName eq "Regex" ) {
            eval { qr/$aVal/ };
            if ($@) {
                Log3 $name, 2, "ROLLO ($name):ERROR Invalid regex in attr $name $aName $aVal: $@";
                return "Invalid Regex $aVal";
            }
        }

        #Auswertung von HomeKit und dem Logo
        if ( $aName eq "type" ) {

     #auslesen des aktuellen Icon, wenn es nicht gesetzt ist, oder dem default entspricht, dann neue Zuweisung vornehmen
            my $iconNormal =
'open:fts_shutter_10:closed closed:fts_shutter_100:open half:fts_shutter_50:closed drive-up:fts_shutter_up@red:stop drive-down:fts_shutter_down@red:stop pct-100:fts_shutter_100:open pct-90:fts_shutter_80:closed pct-80:fts_shutter_80:closed pct-70:fts_shutter_70:closed pct-60:fts_shutter_60:closed pct-50:fts_shutter_50:closed pct-40:fts_shutter_40:open pct-30:fts_shutter_30:open pct-20:fts_shutter_20:open pct-10:fts_shutter_10:open pct-0:fts_shutter_10:closed';
            my $iconHomeKit =
'open:fts_shutter_10:closed closed:fts_shutter_100:open half:fts_shutter_50:closed drive-up:fts_shutter_up@red:stop drive-down:fts_shutter_down@red:stop pct-100:fts_shutter_10:open pct-90:fts_shutter_10:closed pct-80:fts_shutter_20:closed pct-70:fts_shutter_30:closed pct-60:fts_shutter_40:closed pct-50:fts_shutter_50:closed pct-40:fts_shutter_60:open pct-30:fts_shutter_70:open pct-20:fts_shutter_80:open pct-10:fts_shutter_90:open pct-0:fts_shutter_100:closed';
            my $iconAktuell = AttrVal( $name, "devStateIcon", "kein" );

            fhem("attr $name devStateIcon $iconHomeKit")
              if ( ( $aVal eq "HomeKit" ) && ( ( $iconAktuell eq $iconNormal ) || ( $iconAktuell eq "kein" ) ) );
            fhem("attr $name devStateIcon $iconNormal")
              if ( ( $aVal eq "normal" ) && ( ( $iconAktuell eq $iconHomeKit ) || ( $iconAktuell eq "kein" ) ) );
        }
		 elsif ( $aName eq "disable" ) {
            if ( $aVal == 1 ) {
                RemoveInternalTimer($hash);
                readingsSingleUpdate( $hash, "state", "inactive", 1 );
                $hash->{helper}{DISABLED} = 1;
            }
            elsif ( $aVal == 0 ) {
				readingsSingleUpdate( $hash, "state", "Initialized", 1 );
				$hash->{helper}{DISABLED} = 1;
            }

        }
    }
    return undef;
}

1;

=pod
=item helper
=item summary Universal module to precisely control shutters/blinds which support only open/close/stop
=item summary_DE Universelles Modul um Rollladen die nur open/close/stop unterstützen päzise zu steuern
=begin html

<a name="ROLLO"></a>
<h3>ROLLO</h3>
<ul>
<p>The module ROLLO offers an easy away to control shutters with one or two relays and to stop them exactly. <br>
			The current position (in %) will be displayed in fhem. It doesn't matter which hardware is used to control the shutters as long as they are working with FHEM. <br />
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
				<li><a name="open">open</a>
						<code>set &lt;Rollo-Device&gt; open</code><br />
						opens the shutter (pct 0) </li>
				<li><a name="closed">closed</a>
						<code>set &lt;Rollo-Device&gt; closed</code><br />
						close the shutter (pct 100) </li>
				<li><a name="up">up</a>
						<code>set &lt;Rollo-Device&gt; up</code><br />
						opens the shutter one step (pct +10) </li>
				<li><a name="down">down</a>
						<code>set &lt;Rollo-Device&gt; down</code><br />
						close the shutter one step (pct -10) </li>
				<li><a name="half">half</a>
						<code>set &lt;Rollo-Device&gt; half</code><br />
						drive the shutter to half open (pct 50) </li>
				<li><a name="stop">stop</a>
						<code>set &lt;Rollo-Device&gt; stop</code><br />
						stop a driving shutter</li>
				<li><a name="drive">drive</a>
						<code>set &lt;Rollo-Device&gt; drive up 5</code><br />
						Drives the shutter in the specified direction for the specified time (in seconds)</li>
				<li><a name="blocked">blocked</a>
						<code>set &lt;Rollo-Device&gt; blocked</code><br />
						when activated, the shutter can move only restricted. See attribute block_mode for further details.</li>
				<li><a name="unblocked">unblocked</a>
						<code>set &lt;Rollo-Device&gt; unblocked</code><br />
						unblock the shutter, so you can drive the shutter</li>
				<li><a name="pct">pct</a>
						<code>set &lt;Rollo-Device&gt; pct &lt;value&gt;</code><br />
						drive the shutter to exact pct from 0 (open) to 100 (closed) </li>
				<li><a name="reset">reset</a>
						<code>set &lt;Rollo-Device&gt; reset &lt;value&gt;</code><br />
						set the modul to real pct if the shutter pct changed outside from fhem</li>
				<li><a name="extern">extern</a>
						<code>set &lt;Rollo-Device&gt; extern &lt;value&gt;</code><br />
						if the shutter is started/stopped externaly, you can inform the module so it can calculate the current pct</li>
			</ul>
			<a name="ROLLO_Get"></a>
			<h4>Get</h4>
			<ul>
				<li><a name="version">version</a>
						<code>get &lt;Rollo-Device&gt; version</code>
					<br /> Returns the version number of the FHEM ROLLO module</li>
			</ul>
			<a name="ROLLO_Attr"></a>
			<h4>Attributes</h4>
			<ul>
				<li><a name="type">type</a>
					<br />Type differentiation to support different hardware. Depending on the selected type, the direction of which the pct is expected to set:<BR/>
							normal = pct 0 means open, pct 100 means closed<BR/>
							HomeKit = pct 100 means open, pct 0 means closed</li>
				<li><a name="secondsDown">secondsDown</a><code>attr &lt;Rollo-Device&gt; secondsDown	&lt;number&gt;</code>
					<br />time in seconds needed to drive the shutter down</li>
				<li><a name="secondsUp">secondsUp</a><code>attr &lt;Rollo-Device&gt; secondsUp	&lt;number&gt;</code>
					<br />time in seconds needed to drive the shutter up</li>
				<li><a name="excessTop">excessTop</a><code>attr &lt;Rollo-Device&gt; excessTop	&lt;number&gt;</code>
					<br />additional time the shutter need from last visible top pct to the end pct</li>
				<li><a name="excessBottom">excessBottom</a><code>attr &lt;Rollo-Device&gt; excessBottom &lt;number&gt;</code>
					<br />additional time the shutter need from visible closed pct to the end pct</li>
				<li><a name="switchTime">switchTime</a><code>attr &lt;Rollo-Device&gt; switchTime &lt;number&gt;</code>
					<br />time for the shutter to switch from one driving direction to other driving direction</li>
				<li><a name="resetTime">resetTime</a><code>attr &lt;Rollo-Device&gt; resetTime	&lt;number&gt;</code>
					<br />additional time the shutter remains in driving state if driving to final pcts (open, closed), to ensure that the final pct was really reached. So difference in the pct calculation can be corrected.</li>
				<li><a name="reactionTime">reactionTime</a><code>attr &lt;Rollo-Device&gt; reactionTime &lt;number&gt;</code>
					<br />additional time the shutter needs to start (from start command to really starting the motor)</li>
				<li><a name="autoStop">autoStop</a><code>attr &lt;Rollo-Device&gt; autoStop [0|1]</code>
					<br />No stop command should be sent, the shutter stops by itself.</li>
				<li><a name="commandUp">commandUp</a><code>attr &lt;Rollo-Device&gt; commandUp &lt;string&gt;</code>
					<br />Up to three commands you have to send to drive the shutter up</li>
				<li><a name="commandDown">commandDown</a><code>attr &lt;Rollo-Device&gt; commandDown &lt;string&gt;</code>
					<br />Up to three commands you have to send to drive the shutter down</li>
				<li><a name="commandStop">commandStop1</a><code>attr &lt;Rollo-Device&gt; commandStop &lt;string&gt;</code>
					<br />command to stop a driving shutter</li>
				<li><a name="commandStopDown">commandStopDown</a><code>attr &lt;Rollo-Device&gt; commandStopDown &lt;string&gt;</code>
					<br />command to stop a down driving shutter, if not set commandStop is executed</li>
				<li><a name="commandStopUp">commandStopUp</a><code>attr &lt;Rollo-Device&gt; commandStopUp &lt;string&gt;</code>
					<br />command to stop a up driving shutter, if not set commandStop is executed</li>
				<li><a name="blockMode">blockMode</a><code>attr &lt;Rollo-Device&gt; blockMode [blocked|force-open|force-closed|only-up|only-down|half-up|half-down|none]</code>
					<br />the possibilities of the shutter in blocked mode:<br>
							blocked = shutter can't drive<br>
							force-open = drive the shutter up if a drive command is send<br>
							force-closed = drive the shutter down if a drive command is send<br>
							only-up = only drive up commands are executed<br>
							only-down =only drive down commands are executed<br>
							half-up = only drive to pcts above half-up<br>
							half-down = only drive to pcts below half-down<br>
							none = blockmode is disabled</li>
				<li><a name="automatic-enabled">automatic-enabled</a><code>attr &lt;Rollo-Device&gt; automatic-enabled [yes|no]</code>
					<br />if disabled the additional module ROLLO_AUTOMATIC doesn't drive the shutter</li>
				<li><a name="automatic-delay">automatic-delay</a><code>attr &lt;Rollo-Device&gt; automatic-delay	&lt;number&gt;</code>
					<br />if set any ROLLO_AUTOMATIC commands are executed delayed (in minutes)<br></li>
				<li><a name="forceDrive">forceDrive</a><code>attr &lt;Rollo-Device&gt; forceDrive [0|1]</code>
					<br />force open/closed even if device is already in target position<br></li>
				<li><a name="noSetPosBlocked">noSetPosBlocked</a><code>attr &lt;Rollo-Device&gt; noSetPosBlocked [0|1]</code>
					<br />if disabled positions may be set even if device is blocked. After unblocking it will drive to the position.<br></li>
				<li><a href="#readingFnAttributes">readingFnAttributes</a></li>
			</ul>
</ul>
=end html

=begin html_DE

<a name="ROLLO"></a>
<h3>ROLLO</h3>
<ul>
			<p>Das Modul ROLLO bietet eine einfache Moeglichkeit, mit ein bis zwei Relais den Hoch-/Runterlauf eines Rolladen zu steuern und punktgenau anzuhalten.<br>
			Ausserdem wird die aktuelle Position in FHEM dargestellt. Ueber welche Hardware/Module die Ausgaenge angesprochen werden ist dabei egal.<br /><h4>Example</h4>
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
				<li><a name="open">open</a>
						<code>set &lt;Rollo-Device&gt; open</code><br />
						Faehrt das Rollo komplett auf (pct 0) </li>
				<li><a name="closed">closed</a>
						<code>set &lt;Rollo-Device&gt; closed</code><br />
						Faehrt das Rollo komplett zu (pct 100) </li>
				<li><a name="up">up</a>
						<code>set &lt;Rollo-Device&gt; up</code><br />
						Faehrt das Rollo um 10 auf (pct +10) </li>
				<li><a name="down">down</a>
						<code>set &lt;Rollo-Device&gt; down</code><br />
						Faehrt das Rollo um 10 zu (pct -10) </li>
				<li><a name="half">half</a>
						<code>set &lt;Rollo-Device&gt; half</code><br />
						Faehrt das Rollo zur haelfte runter bzw. hoch (pct 50) </li>
				<li><a name="stop">stop</a>
						<code>set &lt;Rollo-Device&gt; stop</code><br />
						Stoppt das Rollo</li>
				<li><a name="drive">drive</a>
						<code>set &lt;Rollo-Device&gt; drive up 5</code><br />
						Fährt das Rollo in die angegebene Richtung für die angegebene Zeit (in Sekunden)</li>
				<li><a name="blocked">blocked</a>
						<code>set &lt;Rollo-Device&gt; blocked</code></a><br />
						wenn aktiviert, kann der ROLLO nur noch eingeschränkt gesteuert werden. Siehe Attribut block_mode für Details.</li>
				<li><a name="unblocked">unblocked</a>
						<code>set &lt;Rollo-Device&gt; unblocked</code><br />
						Aktiviert einen geblockten ROLLO wieder für die normale Benutzung</li>
				<li><a name="pct">pct</a>
						<code>set &lt;Rollo-Device&gt; pct &lt;value&gt;</code><br />
						Faehrt das Rollo auf eine beliebige pct zwischen 0 (offen) - 100 (geschlossen) </li>
				<li><a name="reset">reset</a>
						<code>set &lt;Rollo-Device&gt; reset &lt;value&gt;</code><br />
						Sagt dem Modul in welcher pct sich der Rollo befindet</li>
				<li><a name="extern">extern</a>
						<code>set &lt;Rollo-Device&gt; extern &lt;value&gt;</code></a><br />
						Der Software mitteilen dass gerade Befehl X bereits ausgeführt wurde und nun z.B,. das berechnen der aktuellen pct gestartet werden soll</li>
			</ul>
			<a name="ROLLO_Get"></a>
			<h4>Get</h4>
			<ul>
				<li><a name="version">version</a>
						<code>get &lt;Rollo-Device&gt; version</code>
					<br />Gibt die version des Modul Rollos aus</li>
			</ul>
			<h4>Attributes</h4>
			<ul>
				<li><a name="type">type</a><code>attr &lt;Rollo-Device&gt; type [normal|HomeKit]</code>
					<br />Typunterscheidung zur unterstützung verschiedener Hardware. Abhängig vom gewählten Typ wird die Richtung von der die pct gerechnet wird festgelegt:<BR/>
							normal = pct 0 ist offen, pct 100 ist geschlossen<BR/>
							HomeKit = pct 100 ist offen, pct 0 ist geschlossen</li>
				<li><a name="secondsDown">secondsDown<code>attr &lt;Rollo-Device&gt; secondsDown	&lt;number&gt;</code>
					<br />Sekunden zum hochfahren</li>
				<li><a name="secondsUp">secondsUp</a><code>attr &lt;Rollo-Device&gt; secondsUp	&lt;number&gt;</code>
					<br />Sekunden zum herunterfahren</li>
				<li><a name="excessTop">excessTop</a><code>attr &lt;Rollo-Device&gt; excessTop	&lt;number&gt;</code>
					<br />Zeit die mein Rollo Fahren muss ohne das sich die Rollo-pct ändert (bei mir fährt der Rollo noch in die Wand, ohne das man es am Fenster sieht, die pct ist also schon bei 0%)</li>
				<li><a name="excessBottom">excessBottom</a><code>attr &lt;Rollo-Device&gt; excessBottom &lt;number&gt;</code>
					<br />(siehe excessTop)</li>
				<li><a name="switchTime">switchTime</a><code>attr &lt;Rollo-Device&gt; switchTime &lt;number&gt;</code>
					<br />Zeit die zwischen 2 gegensätzlichen Laufbefehlen pausiert werden soll, also wenn der Rollo z.B. gerade runter fährt und ich den Befehl gebe hoch zu fahren, dann soll 1 sekunde gewartet werden bis der Motor wirklich zum stillstand kommt, bevor es wieder in die andere Richtung weiter geht. Dies ist die einzige Zeit die nichts mit der eigentlichen Laufzeit des Motors zu tun hat, sondern ein timer zwischen den Laufzeiten.</li>
				<li><a name="resetTime">resetTime</a><code>attr &lt;Rollo-Device&gt; resetTime	&lt;number&gt;</code>
					<br />Zeit die beim Anfahren von Endpcten (offen,geschlossen) der Motor zusätzlich an bleiben soll um sicherzustellen das die Endpct wirklich angefahren wurde. Dadurch können Differenzen in der pctsberechnung korrigiert werden.</li>
				<li><a name="reactionTime">reactionTime</a><code>attr &lt;Rollo-Device&gt; reactionTime &lt;number&gt;</code>
					<br />Zeit für den Motor zum reagieren</li>
				<li><a name="autoStop">autoStop</a><code>attr &lt;Rollo-Device&gt; autoStop [0|1]</code>
					<br />Es muss kein Stop-Befehl ausgeführt werden, das Rollo stoppt von selbst.</li>
				<li><a name="commandUp">commandUp</a><code>attr &lt;Rollo-Device&gt; commandUp	&lt;string&gt;</code>
					<br />Es werden bis zu 3 beliebige Befehle zum hochfahren ausgeführt</li>
				<li><a name="commandDown">commandDown</a><code>attr &lt;Rollo-Device&gt; commandDown	&lt;string&gt;</code>
					<br />Es werden bis zu 3 beliebige Befehle zum runterfahren ausgeführt</li>
				<li><a name="commandStop">commandStop</a><code>attr &lt;Rollo-Device&gt; commandStop	&lt;string&gt;</code>
					<br />Befehl der zum Stoppen ausgeführt wird, sofern nicht commandStopDown bzw. commandStopUp definiert sind</li>
				<li><a name="commandStopDown">commandStopDown</a><code>attr &lt;Rollo-Device&gt; commandStopDown	&lt;string&gt;</code>
					<br />Befehl der zum stoppen ausgeführt wird, wenn der Rollo gerade herunterfährt. Wenn nicht definiert wird commandStop ausgeführt</li>
				<li><a name="commandStopUp">commandStopUp</a><code>attr &lt;Rollo-Device&gt; commandStopUp	&lt;string&gt;</code>
					<br />Befehl der zum Stoppen ausgeführt wird,wenn der Rollo gerade hochfährt. Wenn nicht definiert wird commandStop ausgeführt</li>
				<li><a name="blockMode">blockMode</a><code>attr &lt;Rollo-Device&gt; blockMode [blocked|force-open|force-closed|only-up|only-down|half-up|half-down|none]</code>
					<br />wenn ich den Befehl blocked ausführe, dann wird aufgrund der blockMode-Art festgelegt wie mein Rollo reagieren soll:<br>
							blocked = Rollo lässt sich nicht mehr bewegen<br>
							force-open = bei einem beliebigen Fahrbefehl wird Rollo hochgefahren<br>
							force-closed = bei einem beliebigen Fahrbefehl wird Rollo runtergefahren<br>
							only-up = Befehle zum runterfahren werden ignoriert<br>
							only-down = Befehle zum hochfahren werden ignoriert<br>
							half-up = es werden nur die pcten 50-100 angefahren, bei pct <50 wird pct 50% angefahren,<br>
							half-down = es werden nur die pcten 0-50 angefahren, bei pct >50 wird pct 50 angefahren<br>
							none = block-Modus ist deaktiviert</li>
				<li><a name="automatic-enabled">automatic-enabled</a><code>attr &lt;Rollo-Device&gt; automatic-enabled	[on|off]</code>
					<br />Wenn auf off gestellt, haben Befehle über Modul ROLLO_Automatic keine Auswirkungen auf diesen Rollo</li>
				<li><a name="automatic-delay">automatic-delay</a><code>attr &lt;Rollo-Device&gt; automatic-delay	&lt;number&gt;</code>
					<br />Dieses Attribut wird nur fuer die Modulerweiterung ROLLADEN_Automatic benoetigt.<br>
					Hiermit kann einge Zeitverzoegerund fuer den Rolladen eingestellt werden, werden die Rolladen per Automatic heruntergefahren, so wird dieser um die angegebenen minuten spaeter heruntergefahren.
					</li>
				<li><a name="forceDrive">forceDrive</a><code>attr &lt;Rollo-Device&gt; forceDrive [0|1]</code>
					<br />open/closed wird ausgeführt, auch wenn das ROLLO bereits in der Zielposition ist<br></li>
				<li><a name="noSetPosBlocked">noSetPosBlocked</a><code>attr &lt;Rollo-Device&gt; noSetPosBlocked [0|1]</code>
					<br />Wenn deaktiviert, können Positionsn (pct) auch gesetzt werden, wenn der ROLLO geblockt ist. Nach dem unblocken wird die entsprechende Position angefahren.<br></li>

				<li><a href="#readingFnAttributes">readingFnAttributes</a></li>
			</ul>
</ul>
=end html_DE
=cut
