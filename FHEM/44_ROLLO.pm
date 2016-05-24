########################################################################################
#
# ROLLO.pm
#
# Modul zur einfacheren Rolladensteuerung
#
# Thomas Ramm, 2016
# Tim Horenkamp, 2016 (Fehlerbehebung und kleinigkeiten)
# 
# $Id: 44_ROLLO.pm 2016-05 - HoTi $
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
use Data::Dumper; #Zum Entwickeln und Debuggen, gibt ganze Arrays im Log aus!

#-- globals on start
my $version = "1.0beta11";

#***** Rolladen-positionen die im klartext auf der Oberflaeche benutzt werden sollen
# alle Positionen die keinen wert haben (noArg) muessen in dem zweiten Hash mit einer
# absoluten Position zwischen 0 (offen) und 100 (geschlossen) versehen werden.
# floatwerte sind erlaubt. Als Beispiel ist "meinePosition" eingefuegt und auskommentiert
my %sets = (
  "offen" => "noArg",
  "geschlossen" => "noArg",
  "schlitz" => "noArg",
  "stop" => "noArg",
  #"meinePosition" => "noArg",
  "position" => "0,10,20,30,40,50,60,70,80,90,100",
  "toggle" => "noArg",
  "extern" => "offen,geschlossen,stop",
  "reset" => "offen,geschlossen");

# die Positionen der "Klartexte"
my %position = (
  "offen" => 0,
  "geschlossen" => 100,
  #"meinePosition" => 22,
  "schlitz" => 90);

#***** GET wir f�r Modulinformationen genutzt
my %gets = (
#  "write_hash_to_log" => "write");
  "version:noArg"   => "V"
  );
############################################################ INITIALIZE #####
# Die Funktion wird von Fhem.pl nach dem Laden des Moduls 
# aufgerufen und bekommt einen Hash fuer das Modul als zentrale 
# Datenstruktur uebergeben.
sub ROLLO_Initialize($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  Log3 "global",4,"ROLLO (?) >> Initialize";

  $hash->{DefFn}    = "ROLLO_Define";
  $hash->{UndefFn}  = "ROLLO_Undef";
  $hash->{SetFn}    = "ROLLO_Set";
  $hash->{GetFn}    = "ROLLO_Get";
  $hash->{AttrFn}   = "ROLLO_Attr";

  $hash->{AttrList} = " drive-down-time-to-100"
    . " drive-up-time-to-100"
    . " automatic-enabled:on,off"
    . " automatic-delay:5,10,15,20,30,45,60"
    . " funktionsweise:Typ1,Typ2,Typ3,Typ4,FS20rsu,Typ5,Typ6"
    . " device kanal1 kanal2 kanal3"
	. " Zeitaddition_Endanschlag";
 
  Log3 "global",4,"ROLLO (?) << Initialize";
}

################################################################ DEFINE #####
# Die Define-Funktion eines Moduls wird von Fhem aufgerufen wenn 
# der Define-Befehl fuer ein Geraete ausgefuehrt wird und das Modul 
# bereits geladen und mit der Initialize-Funktion initialisiert ist
sub ROLLO_Define($$) {
  my ($hash,$def) = @_;
  my $name = $hash->{NAME};
  Log3 $name,4,"ROLLO ($name) >> Define";

  my @a = split( "[ \t][ \t]*", $def );

  #Parameter1: Name des Geraets das die Ausgaenge schaltet
  if ($a[2] ne "-") {
      $hash->{device} = $a[2];
  } else {
    $hash->{device} = " ";   
  }

  #ALTE DEFINITION  
  if (defined($a[4])) {
    #Parameter2: Adresse des Rollo Pin
    $attr{$name}{"kanal1"} = $a[3];
  
    #Parameter3: Adresse des Rollo Gruppe-Ab Pin
    $attr{$name}{"kanal2"} = $a[4];

    #Parameter4: Optional! Art der Kanaladressierung
    my $Typ = "Typ1";
    $Typ = $a[5] if defined $a[5];
    $attr{$name}{"funktionsweise"} = $Typ;
}

#  als Ausgangswert gehe ich davon aus das das Rollo offen ist
#  readingsBeginUpdate($hash);
#  readingsBulkUpdate($hash,"state","offen");
#  readingsBulkUpdate($hash,"position",0);
#  readingsEndUpdate($hash,0);

  #Als Vorgabe einige Attribute definieren, das macht weniger Arbeit als sie
  #bei jedem Rollo komplett neu zu erfassen
  $attr{$name}{"funktionsweise"} = "Typ1";
  $attr{$name}{"automatic-enabled"} = "on";
  $attr{$name}{"drive-down-time-to-100"} = 20;
  $attr{$name}{"drive-up-time-to-100"} = 20;
  $attr{$name}{"webCmd"} = "offen:geschlossen:schlitz:position";
  $attr{$name}{"devStateIcon"} = 'offen:fts_shutter_10:geschlossen geschlossen:fts_shutter_100:offen schlitz:fts_shutter_80:geschlossen drive-up:fts_shutter_up@red:stop drive-down:fts_shutter_down@red:stop position-100:fts_shutter_100:offen position-90:fts_shutter_80:geschlossen position-80:fts_shutter_80:geschlossen position-70:fts_shutter_70:geschlossen position-60:fts_shutter_60:geschlossen position-50:fts_shutter_50:geschlossen position-40:fts_shutter_40:offen position-30:fts_shutter_30:offen position-20:fts_shutter_20:offen position-10:fts_shutter_10:offen position-0:fts_shutter_10:geschlossen';
  $attr{$name}{"Zeitaddition_Endanschlag"} = 5;
  
  #AssignIoPort($hash);
  #IOWrite schreibt spaeter
  Log3 $name,4,"ROLLO ($name) << Define";
}

################################################################# UNDEF #####
# wird aufgerufen wenn ein Geraet mit delete geloescht wird oder bei 
# der Abarbeitung des Befehls rereadcfg, der ebenfalls alle Geraete 
# loescht und danach das Konfigurationsfile neu abarbeitet.
sub ROLLO_Undef($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  Log3 $name,4,"ROLLO ($name) >> Undef";

  RemoveInternalTimer($hash);

  Log3 $name,4,"ROLLO ($name) << Undef";
}

#################################################################### SET #####
# Sie ist dafuer gedacht, Werte zum physischen Geraet zu schicken. 
# also das Rollo fahren zu lassen.
# Falls nur interne Werte im Modul gesetzt werden sollen, so sollte 
# statt Set die Attr-Funktion verwendet werden. 
sub ROLLO_Set($@) {
  my ($hash,@a) = @_;
  my $name = $hash->{NAME};
  Log3 $name,4,"ROLLO ($name) >> Set";
 
  #FEHLERHAFTE PARAMETER ABFRAGEN
  if ( @a < 2 ) {
    Log3 $name,3,"\"set ROLLO\" needs at least an argument";
    Log3 $name,4,"ROLLO ($name) << Set";
    return "\"set ROLLO\" needs at least an argument";
  }
  my $opt =  $a[1]; 
  my $value = "";
  $value = $a[2] if defined $a[2]; 

  my $value2 = "";
  $value2 = $a[3] if defined $a[3];

  Log3 $name,5,"ROLLO_Set Befehl=$opt:$value $value2";

  ##### dummy-Modus, nur Status aktualisieren #####
  if ($opt eq "extern") {
    readingsSingleUpdate($hash,"extern","extern",0);
    $opt = $value;
    $value = $value2
  ##### Korrektur-Modus, nur Ist-Status korrigieren
  } elsif ($opt eq "reset") {
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash,"state",$value);
    readingsBulkUpdate($hash,"position",$position{$value});
    readingsEndUpdate($hash,1);
    return;
  }  

  #moegliche Set Eigenschaften und erlaubte Werte zurueckgeben wenn ein unbekannter
  #Befehl kommt, dann wird das auch automatisch in die Oberflaecheche �bernommen
  if(!defined($sets{$opt})) {
    my $param = "";
    foreach my $val (keys %sets) {
        $param .= " $val:$sets{$val}";
    }
    if ($opt ne "?") {
      Log3 $name,3,"Unknown argument $opt, choose one of $param";
    }
    Log3 $name,4,"ROLLO ($name) << Set";
    return "Unknown argument $opt, choose one of $param";
  }


  ##### toggle auswerten und in 'bekannte' Befehle umwandeln #####
  if ($opt eq "toggle" ) {
    if (index(ReadingsVal($name,"state",""), 'drive') != -1) {
      RemoveInternalTimer($hash);
      ROLLO_Stop($hash);
    }
    my $Fahrtrichtung =  ReadingsVal($name,"letzte_fahrt","drive-up");
    $opt = ($Fahrtrichtung eq "drive-up")? "geschlossen" : "offen";
  }

  #die Parameter werden jetzt im Hash zwischengespeichert.
  #das ist notwendig damit das setzen auch per Timer funktioniert
  #dem kann man naemlich keine Parameter uebergeben
  $opt = $opt ."-". $value if ($opt eq "position"); 
  readingsSingleUpdate($hash,"ziel_state",$opt,1);

  #das eigentliche fahren des Rollos uebernimmt diese Funktion:
  ROLLO_Start($hash);
  Log3 $name,4,"ROLLO ($name) << Set";
}

#****************************************************************************
#* Faehrt das Rollo in die entsprechende richtung.
#* Bei Bedarf wird er vorher gestoppt und 1 sec spaeter in die andere
#* Richtung gefahren
sub ROLLO_Start($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  Log3 $name,4,"ROLLO ($name) >> Start";

  #***** Auftrag lesen ******#
  my $opt = ReadingsVal($name,"ziel_state","undef");
  Log3 $name,5,"Auftrag:$opt";

  #***** Start Position *****#
  my $position_alt = ReadingsVal($name,"position",0);

  #***** Ziel Position ******#
  my $position_neu;
    if ($opt eq "stop") {
    $position_neu = $position_alt;
  } elsif (index($opt,"position") == -1) {
    $position_neu = $position{$opt};
  } else {
    $position_neu = substr $opt, 9; 
  }
  #***** Richtung ***********#
  my $ab = "off";
  $ab = "on" if ($position_alt < $position_neu);
  Log3 $name,5,"Position: $position_alt -> $position_neu | Abwaerts: $ab";
  
  #***** pruefen ob der rolladen gerade faehrt *****#
  if (index(ReadingsVal($name,"state","undef"), 'drive') != -1) {

    #***** aktuelle Position berechnen *****#
    RemoveInternalTimer($hash);
    my $restzeit = ReadingsVal($name,"stop",0) - gettimeofday();
    my ($zeit, $pos);
    if (ReadingsVal($name,"state","undef") eq "drive-down") {
      $zeit = AttrVal($name,'drive-down-time-to-100',undef);
      $pos = ReadingsVal($name,"position",0)-(100/$zeit*$restzeit);
    } else {
      $zeit = AttrVal($name,'drive-up-time-to-100',undef);
      $pos = ReadingsVal($name,"position",0)+(100/$zeit*$restzeit)
    }
    #***** aktuelle Position speichern *****#
    readingsSingleUpdate($hash,"position",$pos,1);
    $position_alt = $pos;
    Log3 $name,5,"Rollo faehrt noch zur gespeicherten Startposition. Restzeit: $restzeit, aktuelle Position: $pos";

    #***** soll Rollo gestoppt werden, dann ist hier schluss *****#
    if ($opt eq "stop") {
      readingsSingleUpdate($hash,"position", int($pos/10+0.5)*10, 1);
      ROLLO_Stop($hash);
      Log3 $name,4,"ROLLO ($name) << Start";
      return;
    }

    #Richtung nochmal neu berechnen, evtl. bin ich ja schon zu weit gefahren
    #da ich ja nun einen neuen Auftrag bekommen habe.
    my $ab = "off";
    $ab = "on" if ($position_alt < $position_neu);
    my $status = ReadingsVal($name,"state","undef");
    #***** Richtungswechsel? *****#
    if (   (($status eq "drive-down") && ($ab eq "off")) 
        || (($status eq "drive-up") && ($ab eq "on")) ) {
      Log3 $name,5,"Rollo faehrt gerade in die falsche Richtung!";

      #***** Stoppen und dann in 1 sec Richtungswechsel *****#
      ROLLO_Stop($hash);
      InternalTimer(gettimeofday()+1, "ROLLO_Start", $hash, 0);

      Log3 $name,4,"ROLLO ($name) << Start";
      return;
    }
  }
  #wie lange muss der Rolladen (noch) fahren um in die Position zu kommen
  my $time = calculateDriveTime($name,$position_alt,$position_neu,$ab);

  if ($time > 0) {
    my $befehl1 = "";
    my $befehl2 = "";
    my $typ = AttrVal($name,"funktionsweise","Typ1");
    my $kanal1 = AttrVal($name,"kanal1",undef);
    my $kanal2 = AttrVal($name,"kanal2",undef);
    my $kanal3 = AttrVal($name,"kanal3",undef);

    my $device = AttrVal($name,"device","");
    #der Befehl zum Fahren des Rolladen
    #========= Typ1 ========================================#
    if ($typ eq "Typ1") {
      $befehl1 = "set $device $kanal2 $ab";
      $befehl2 = "set $device $kanal1 on";

    #========= Typ2 ======================================#
    } elsif ($typ eq "Typ2") {
      if ($ab eq "on") {
        $befehl1 = "set $device $kanal2 on";
        $befehl2 = "";
      } else {
        $befehl1 = "set $device $kanal1 on";
        $befehl2 = "";
      }
    #========= Typ3 ========================================#
    } elsif ($typ eq "Typ3") {
      if ($ab eq "on") {
        $befehl1 = "set $device $kanal1 on";
        $befehl2 = "";
      } else {
        $befehl1 = "set $device $kanal1 off";
        $befehl2 = "";
      }
    #========= FS20rsu =====================================#
    } elsif ($typ eq "FS20rsu") {
      if ($ab eq "on") {
        $befehl1 = "set $device $kanal1 off";
        $befehl2 = "";
      } else {
        $befehl1 = "set $device $kanal1 on"; 
        $befehl2 = "";
      }
    #========= Typ4 ========================================#
    } elsif ($typ eq "Typ4") {
      if ($ab eq "on") {
        $befehl1 = "set $device $kanal2 on-for-timer 1";
		$befehl2 = "";
      } else {
        $befehl1 = "set $device $kanal1 on-for-timer 1";
		$befehl2 = "";
      }
    #========= Typ5 ========================================#
	} elsif ($typ eq "Typ5") {
      if ($ab eq "on") {
        $befehl1 = "set $device $kanal1 off";
		$befehl2 = "set $device $kanal2 on";
      } else {
        $befehl1 = "set $device $kanal2 off";
        $befehl2 = "set $device $kanal1 on";
      }
    #========= FEHLER ======================================#
    } else {
      Log3 $name,1,"FEHLER: Funktionsweise '". AttrVal($name,"funktionsweise","Typ1") ."' unbekannt!";
    }
    Log3 $name,3,"ROLLO sendet: $befehl1";
    Log3 $name,3,"ROLLO sendet: $befehl2";
    my $wert = ($ab eq "on")? "drive-down" : "drive-up";
    readingsSingleUpdate($hash,"letzte_fahrt",$wert,1); 

	#setzen des Status (was mache ich gerade)
	readingsBeginUpdate($hash);
	readingsBulkUpdate($hash,"letzte_fahrt",$wert);
	readingsBulkUpdate($hash,"state",$wert);
	readingsBulkUpdate($hash,"position",$position_neu);
	readingsEndUpdate($hash,1);
	
    #***** ROLLO LOSFAHREN WENN NICHT SCHON EXTERN GESTARTET *****#
    if (ReadingsVal($name,"extern","undef") ne "extern") {
      fhem("$befehl1"); 
      fhem("$befehl2") if ($befehl2 ne ""); 
      readingsSingleUpdate($hash,"extern","no",0);
      Log3 $name,5,"Befehl1: $befehl1 \nBefehl2: $befehl2";
    } else {
    Log3 $name,5,"Befehle nicht ausgefuehrt da extern getriggert: $befehl1 \nBefehl2: $befehl2";
    }

  }   
  #***** ROLLO STOPPEN *****#
  RemoveInternalTimer($hash);
  #wenn ich bis zum Ende fahre, noch etwas Zeit drauf geben
  #um sicher zu sein das das Rollo wirklich am Ende ankommt falls die
  #Zeiten zu knapp hinterlegt sind
  readingsSingleUpdate($hash,"stop",gettimeofday()+$time,0);  
  if (($opt eq "geschlossen") || ($opt eq "offen")) {
   my $addition = AttrVal($name,'Zeitaddition_Endanschlag',undef);
   $time = $time+$addition;
  }
  InternalTimer(gettimeofday()+$time, "ROLLO_Stop", $hash, 1);
  Log3 $name,5,"Rollo wird gestoppt in $time sekunden.";

  Log3 $name,4,"ROLLO ($name) << Start";
}

#****************************************************************************
#* Stopt das Rollo, wird x Sekunden nach Anfahren eines Rollos aufgerufen
sub ROLLO_Stop($) {
  my ($hash) = @_;
  my $name = $hash->{NAME};
  Log3 $name,4,"ROLLO ($name) >> Stop";
  my $richtung = ReadingsVal($name,"state","undef");
  my $device = AttrVal($name,"device","");
  my $kanal1 = AttrVal($name,"kanal1","");
  my $kanal2 = AttrVal($name,"kanal2","");
  my $kanal3 = AttrVal($name,"kanal3","");
  my $typ = AttrVal($name,"funktionsweise","Typ1");
  if (index($richtung,"drive")!=-1) {
    readingsSingleUpdate($hash,"letzte_fahrt",$richtung,0);
  }
  #Status aktualisieren
  my $position = ReadingsVal($name,"position",0);
  #Position sollte nie < 0, > 100 sein
  $position = 0 if $position < 0;
  $position = 100 if $position > 100;
  my $status = "position-$position";

  my %rhash = reverse %position;
  if (defined($rhash{$position})) {
    $status = $rhash{$position};
  }
  Log3 $name,5,"Rollo wird gestoppt, neue Position:$position = $status";
  readingsSingleUpdate($hash,"state",$status,1);
  
  #Rollo STOP
   Log3 $name,5,"Stop-Parameter: richtung=$richtung, typ=$typ, device=$device, kanal1=$kanal1, kanal2=$kanal2, kanal3=$kanal3";
   #========== DUMMY-MODUS, das starten wurde bereits extern vorgenommen ==#
   if (ReadingsVal($name,"extern","undef") eq "extern") {
     readingsSingleUpdate($hash,"extern","no",0);
     Log3 $name,5,"Rollo extern gestoppt";
   #========== Typ1 + (default) =====================================#
   } elsif ($typ eq "Typ1") {
     if ($richtung eq "drive-down") {
       fhem("set $device $kanal1 off");
       fhem("set $device $kanal2 off");
       Log3 $name,5,"Rollo gestoppt: set $device $kanal1 off, set ${device} $kanal2 off";
     } else {
       fhem("set $device $kanal1 off");
       Log3 $name,5,"Rollo gestoppt: set $device $kanal1 off";
     }
   #========== Typ2 =================================================#
   } elsif ($typ eq "Typ2") {
     if ($richtung eq "drive-down") {
       fhem("set $device $kanal2 off");
       Log3 $name,5,"Rollo gestoppt: set $device $kanal2 off";
     } else {
       fhem("set $device $kanal1 off");
       Log3 $name,5,"Rollo gestoppt: set $device $kanal1 off";
     }
   #========== Typ3 =================================================#
   } elsif ($typ eq "Typ3") {
     fhem("set $device $kanal2 on");
     Log3 $name,5,"Rollo gestoppt: set $device $kanal2 on";
   #========== FS20rsu ==============================================#
   } elsif ($typ eq "FS20rsu") {
     if ($richtung eq "drive-down") {
      fhem("set $device $kanal1 off");
      Log3 $name,5,"Rollo gestoppt: set $device $kanal1 off";
     } else {
   #   fhem("set $device $kanal1 on");
   #   Log3 $name,5,"Rollo gestoppt: set $device $kanal1 on";
     }
   #========== Typ 4 =================================================#
   } elsif ($typ eq "Typ4") {
    fhem("set $device $kanal3 on-for-timer 1");
    Log3 $name,5,"Rollo gestoppt: set $device $kanal3 on-for-timer 1";
   #========== Typ 5 =================================================#
   } elsif ($typ eq "Typ5") {
     if ($richtung eq "drive-down") {
       fhem("set $device $kanal2 off");
       Log3 $name,5,"Rollo gestoppt: set $device $kanal2 off";
     } else {
       fhem("set $device $kanal1 off");
       Log3 $name,5,"Rollo gestoppt: set $device $kanal1 off";
     }   
   #========== Typ 6 =================================================#
   } elsif ($typ eq "Typ6") {
     fhem("set $device $kanal1 stop");
     Log3 $name,5,"Rollo gestoppt: set $device $kanal1 stop";   
   #========== UNDEF =================================================#
   } else {
     Log3 $name,1,"Funktionsweise unbekannt: $typ";
   }

  Log3 $name,4,"ROLLO ($name) << Stop";
}

#****************************************************************************
#* Sekunden berechnen wie lange der Rolladen fahren soll
sub calculateDriveTime(@) {
  my ($name,$alt,$neu,$ab) = @_; 
  Log3 $name,4,"ROLLO ($name) >> calculateDriveTime";
  my ($zeit, $schritte);
  if ($ab eq "on") {
    $zeit = AttrVal($name,'drive-down-time-to-100',undef);
    $schritte = $neu-$alt;
  } else {
    $zeit = AttrVal($name,'drive-up-time-to-100',undef);
    $schritte = $alt-$neu;
  }
  if ($schritte == 0) {
    Log3 $name,3,"Position start + ziel sind identisch";
    Log3 $name,4,"ROLLO ($name) << calculateDriveTime";
    return 0;
  }
  if(!defined($zeit)) {
    Log3 $name,3,"ROLLO FEHLER: Attribute drive-??-time-to-100 nicht gesetzt!";
    Log3 $name,4,"ROLLO ($name) << calculateDriveTime";
    return 30;
  }
  my $Fahrzeit = $zeit*$schritte/100;
  Log3 $name,5,"Parameter: Position=$alt,Ziel=$neu,Abwaerts=$ab,FahrzeitGesamt=$zeit,Schritte=$schritte,FahrzeitBerechnet=$Fahrzeit";
  Log3 $name,4,"ROLLO ($name) << calculateDriveTime";
  return $Fahrzeit;
}

################################################################### GET #####
#
sub ROLLO_Get($@) {
  my ($hash, @a) = @_;
  my $name = $hash->{NAME};
  Log3 $name,4,"ROLLO ($name) >> Get";

  #-- get version
  if( $a[1] eq "version") {
    return "$name.version => $version";
  }

  if ( @a < 2 ) {
    Log3 $name,3, "\"get ROLLO\" needs at least one argument";
    Log3 $name,4,"ROLLO ($name) << Get";
    return "\"get ROLLO\" needs at least one argument";
  }

  #existiert die abzufragende Eigenschaft in der Liste %gets (Am Anfang)
  #die Oberflaeche liest hier auch die moeglichen Parameter aus indem sie
  #die Funktion mit dem Parameter ? aufruft
  my $opt = $a[1];
  if(!$gets{$opt}) {
    my @cList = keys %gets;
    Log3 $name,3,"Unknown argument $opt, choose one of " . join(" ", @cList) if ($opt ne "?");
    Log3 $name,4,"ROLLO ($name) << Get";
    return "Unknown argument $opt, choose one of " . join(" ", @cList);
  }
  my $val = "";
  if (@a > 2) {
    $val = $a[2];
  }
  Log3 $name,5,"ROLLO_Get -> $opt:$val";

#  if ($opt eq "write_hash_to_log") {
#    Log3 $name,1,"----- Write Hash to Log START -----";
#    Log3 $name,1,Dumper($hash);
#    Log3 $name,1,"----- Write Hash to Log END -------"
#  }

  Log3 $name,4,"ROLLO ($name) << Get";
}

################################################################## ATTR #####
#
sub ROLLO_Attr(@) {
  my ($cmd,$name,$aName,$aVal) = @_;
  Log3 $name,4,"ROLLO ($name) >> Attr";  
  # $cmd can be "del" or "set"
  # aName and aVal are Attribute name and value
  if ($cmd eq "set") {
    if ($aName eq "Regex") {
      eval { qr/$aVal/ };
      if ($@) {
        Log3 $name, 3, "ROLLO: Invalid regex in attr $name $aName $aVal: $@";
	return "Invalid Regex $aVal";
      }
    }
  }
  Log3 $name,4,"ROLLO ($name) << Attr";
  return undef;
}

1;

=pod
=begin html

<a name="ROLLO"></a>
<h3>ROLLO</h3>
<p>The module SHADE offers easy away to steer the shutter with one or two relays and to stop point-exactly. <br> 
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
				<li><a name="rollo_geschlossen">
						<code>set &lt;Rollo-Device&gt; geschlossen </code></a><br />
						If the shade completely goes down (position 100)</li>
				<li><a name="rollo_offen">
						<code>set &lt;Rollo-Device&gt; offen</code></a><br />
						If the shade goes completely upwards (position 0)</li>
				<li><a name="rollo_schlitz">
						<code>set &lt;Rollo-Device&gt; schlitz</code></a><br />
						If the shade goes down, shade slits are open (position 90)</li>
				<li><a name="rollo_position">
						<code>set &lt;Rollo-Device&gt; position &lt;value&gt;</code></a><br />
						If the shade on any position goes between 0 (open) - 100 (close))  </li>             
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
				<li><a name="rollo_kanal1"><code>attr &lt;Rollo-Device&gt; kanal1
							&lt;string&gt;</code></a>
					<br />Name of the fhem device of control canal 1</li>
				<li><a name="rollo_kanal2"><code>attr &lt;Rollo-Device&gt; kanal2
							&lt;string&gt;</code></a>
					<br />Name of the fhem device of control canal 2 provided that for own configuration inevitably</li>
				<li><a name="rollo_kanal3"><code>attr &lt;Rollo-Device&gt; kanal3
							&lt;string&gt;</code></a>
					<br />Name of the fhem device of control canal 2 provided that for own configuration inevitably</li>
				<li><a name="rollo_funktionsweise"><code>attr &lt;Rollo-Device&gt; funktionsweise
							 [Typ1|Typ2|Typ3|Typ4|Typ5|Typ6|FS20ru]</code></a>
					<br />Kind of the canal control. The next area contains a listing of the functionality.</li>
				<li><a name="rollo_device"><code>attr &lt;Rollo-Device&gt; device
							&lt;string&gt;</code></a>
					<br />If this attribute is put on, the canals are not interpreted 1-3 as a Reading this given devices, as independent devices.</li>
				<li><a name="rollo_drive-down-time-to-100"><code>attr &lt;Rollo-Device&gt; 
							&lt;Ganzzahl&gt;</code></a>
					<br />Time in seconds them the shade from open to the closed state needs .</li>
				<li><a name="rollo_drive-up-time-to-100"><code>attr &lt;Rollo-Device&gt; drive-up-time-to-100
							&lt;Ganzzahl&gt;</code></a>
					<br />Time in the seconds which the shade from closed needs to the open state (mostly slightly higher than drive-down-time-to-100).</li>
				<li><a name="rollo_automatic-enabled"><code>attr &lt;Rollo-Device&gt; automatic-enabled
							[on|off]</code></a>
					<br />This attribute is required only for the module enlargement 44_ROLLADEN_Automatic.</li>
				<li><a name="rollo_automatic-delay"><code>attr &lt;Rollo-Device&gt; automatic-delay
							[0|5|10|15|20|30|45|60]</code></a>
					<br />This attribute is required only for the module enlargement 44_ROLLADEN_Automatic.<br>
					Herewith can be put einge Zeitverzoegerund for the shutter, are brought down the shutter by Automatic, this is brought down around the given minutes later.</li>  
				<li><a name="rollo_Zeitaddition_Endanschlag"><code>attr &lt;Rollo-Device&gt; Zeitaddition_Endanschlag
							&lt;Ganzzahl&gt;</code></a>
					<br />Time in the seconds for which it should be given on it around certainly to to be the shade really at the end comes if the times are too scarcely deposited.</li> 					
				<li><a href="#readingFnAttributes">readingFnAttributes</a></li>
			</ul>

=end html

=begin html_DE

<a name="ROLLO"></a>
<h3>ROLLO</h3>
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
				<li><a name="rollo_geschlossen">
						<code>set &lt;Rollo-Device&gt; geschlossen </code></a><br />
						Faehrt das Rollo komplett herunter (Position 100) </li>
				<li><a name="rollo_offen">
						<code>set &lt;Rollo-Device&gt; offen</code></a><br />
						Faehrt das Rollo komplett nach oben (Position 0)  </li>
				<li><a name="rollo_schlitz">
						<code>set &lt;Rollo-Device&gt; schlitz</code></a><br />
						Faehrt das Rollo soweit herunter das nur die Rolloschlitze offen sind (Position 90)  </li>
				<li><a name="rollo_position">
						<code>set &lt;Rollo-Device&gt; position &lt;value&gt;</code></a><br />
						Faehrt das Rollo auf eine beliebige Position zwischen 0 (offen) - 100 (geschlossen) </li>             
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
				<li><a name="rollo_kanal1"><code>attr &lt;Rollo-Device&gt; kanal1
							&lt;string&gt;</code></a>
					<br />Name des fhem Geraets von Steuerungskanal1</li>
				<li><a name="rollo_kanal2"><code>attr &lt;Rollo-Device&gt; kanal2
							&lt;string&gt;</code></a>
					<br />Name des zweiten fhem Geraets fuer Kanal 2, sofern fuer die eigene Konfiguration notwendig </li>
				<li><a name="rollo_kanal3"><code>attr &lt;Rollo-Device&gt; kanal3
							&lt;string&gt;</code></a>
					<br />Name des dritten Kanals, sofern fuer die eigene Konfiguration notwendig </li>
				<li><a name="rollo_funktionsweise"><code>attr &lt;Rollo-Device&gt; funktionsweise
							 [Typ1|Typ2|Typ3|Typ4|Typ5|Typ6|FS20ru]</code></a>
					<br />Art der Kanalsteuerung. Eine Auflistung der Funktionsweise enthaelt der naechste Bereich.</li>
				<li><a name="rollo_device"><code>attr &lt;Rollo-Device&gt; device
							&lt;string&gt;</code></a>
					<br />wird dieses Attribut angelegt, werden die Kanaele 1-3 als Reading dieses angegebenen devices interpretiert, nicht als eigenstaendige devices.</li>
				<li><a name="rollo_drive-down-time-to-100"><code>attr &lt;Rollo-Device&gt; rollo_drive-down-time-to-100
							&lt;Ganzzahl&gt;</code></a> 
					<br />Zeit in Sekunden die das Rollo vom offenen zum geschlossenen Zustand benoetigt.</li>
				<li><a name="rollo_drive-up-time-to-100"><code>attr &lt;Rollo-Device&gt; drive-up-time-to-100
							&lt;Ganzzahl&gt;</code></a>
					<br />Zeit in Sekunden, die das Rollo vom geschlossenen zum offenen Zustand benoetigt (meist geringfuegig hoeher als drive-down-time-to-100).</li>
				<li><a name="rollo_automatic-enabled"><code>attr &lt;Rollo-Device&gt; automatic-enabled
							[on|off]</code></a>
					<br />Dieses Attribut wird nur fuer die Modulerweiterung 44_ROLLADEN_Automatic benoetigt.</li>
				<li><a name="rollo_automatic-delay"><code>attr &lt;Rollo-Device&gt; automatic-delay
							[0|5|10|15|20|30|45|60]</code></a>
					<br />Dieses Attribut wird nur fuer die Modulerweiterung ROLLADEN_Automatic benoetigt.<br>
					Hiermit kann einge Zeitverzoegerund fuer den Rolladen eingestellt werden, werden die Rolladen per Automatic heruntergefahren, so wird dieser um die angegebenen minuten spaeter heruntergefahren. 
					</li>
				<li><a name="rollo_Zeitaddition_Endanschlag"><code>attr &lt;Rollo-Device&gt; Zeitaddition_Endanschlag
							&lt;Ganzzahl&gt;</code></a>
					<br />Zeit in Sekunden, fuer die zeit die drauf gegeben werden soll um sicher zu sein das das Rollo wirklich am Ende ankommt falls die Zeiten zu knapp hinterlegt sind.</li>
				<li><a href="#readingFnAttributes">readingFnAttributes</a></li>
			</ul>
=end html_DE
=cut
