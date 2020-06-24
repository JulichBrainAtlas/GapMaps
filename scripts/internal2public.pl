# Copyright 2020 Forschungszentrum Jülich
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# IMPORTANT:
#   Unusable output if debug=TRUE
#   To work correctly this file needs an up-to-date file of '$ONTOLOGYPATH/data/lists/publicXids_DATE.txt'
#   Create it with 'parseontology.pl --default-mac --input Zyto_Projektliste_<ONTOLOYGVERSION>.csv --status publicP,publicDOI --ids --silent --output internal_ids.txt'

### >>>
use strict;
use File::Basename;
use Getopt::Long;

### >>>
use lib $ENV{HITHOME}."/src/perl";
use hitperl;

### >>>
my $ONTOLOGYPATH = "../../ontology";
printfatalerror "FATAL ERROR: Invalid ontology path '".$ONTOLOGYPATH."': $!" unless ( -d $ONTOLOGYPATH );

### >>>
sub trim {
 my $string = shift;
 $string =~ s/^\s+|\s+$//g;
 return $string;
}

### >>>
my $help = 0;
my $verbose = 0;
my $debuglevel = 0;
my $outlabels = "";
my $nTotalLabels = 0;
my $nvertices = 0;
my %validids = ();
my %missingids = ();
my $missingId = 600;
my %validcolors = ();
my %histogram = ();
my $printinfo = 0;
my $ontologyversion = "20200325";
my $filename = undef;

### >>>
sub printusage {
 my $errortext = shift;
 print "error:\n ".$errortext.".\n" if ( defined($errortext) );
 print "usage:\n ".basename($0)." [--help][(-v|--verbose)][(-d|--debug)][--ontologyversion <version=$ontologyversion>] (-i|--input) <filename>\n";
 print "default parameters:\n";
 print " ontology path.................. '".$ONTOLOGYPATH."'\n";
 print " last call...................... '".getLastProgramLogMessage($0)."'\n";
 exit(1);
}
if ( @ARGV>0 ) {
 GetOptions(
  'help+' => \$help,
  'debug|d+' => \$debuglevel,
  'verbose|v+' => \$verbose,
  'ontologyversion=s' => \$ontologyversion,
  'input|i=s' => \$filename) ||
 printusage();
}
printusage() if $help;
printusage("Missing input parameter") if ( !defined($filename) );

### >>>
my %areastatus = ();
my $statusinfofile = $ONTOLOGYPATH."/data/lists/publicXids_".$ontologyversion.".txt";
open(FPin,"<$statusinfofile") || printfatalerror "FATAL ERROR: Cannot open status info file '".$statusinfofile."': $!";
 while ( <FPin> ) {
  next if ( $_ =~ m/^#/ );
  chomp($_);
  my @elements = split(/#/,$_);
  $areastatus{trim($elements[0])} = trim($elements[1]);
  # print " adding positive status for id $elements[0]\n";
 }
close(FPin);

### >>>
# 500 -> Frontal I
# 501 -> Frontal II
# 502 -> Frontal III
# 503 -> Tempoparietal
# 504 -> Occipital
my %conversionIds = ();
my $conversionfile = "data/conversionlist.txt";
if ( -e $conversionfile ) {
 open(FPin,"<$conversionfile") || printfatalerror "FATAL ERROR: Cannot open conversion file for reading '".$conversionfile."': $!";
  while ( <FPin> ) {
   next if ( $_ =~ m/^#/ );
   chomp($_);
   my @elements = split(/ /,$_);
   $conversionIds{$elements[0]} = $elements[1];
  }
 close(FPin);
}

### >>>
open(FPin,"<$filename") || printfatalerror "FATAL ERROR: Cannot open file '".$filename."' for reading: $!";
while ( <FPin> ) {
 next if ( $_ =~ m/^#/ );
 chomp($_);
 if ( $_ =~ m/^nvertices/ ) {
  my @elements = split(/ /,$_);
  $nvertices = $elements[1];
 } elsif ( $_ =~ m/^names/ ) {
  my @elements = split(/ /,$_);
  my $nnames = $elements[1];
  print "DEBUG: names[".$nnames."]=$_\n" if ( $debuglevel );
  for ( my $i=0 ; $i<$nnames ; $i++ ) {
   my $dataline = <FPin>;
   chomp($dataline);
   my @elements = split(/ /,$dataline);
   if ( exists($areastatus{$elements[0]}) || $elements[1] =~ m/GapMap/i || $elements[1] =~ m/Mask$/ ) {
    $validids{$elements[0]} = $elements[1];
   } else {
    $missingids{$elements[0]} = $elements[1];
   }
  }
 } elsif ( $_ =~ m/^colors/ ) {
  my @elements = split(/ /,$_);
  my $ncolors = $elements[1];
  print "DEBUG: ncolors=$ncolors\n" if ( $debuglevel );
  for ( my $i=0 ; $i<$ncolors ; $i++ ) {
   my $dataline = <FPin>;
   chomp($dataline);
   my @elements = split(/ /,$dataline);
   if ( exists($validids{$elements[0]}) ) {
    print "DEBUG: Found color for label ".$validids{$elements[0]}.": $dataline\n" if ( $debuglevel );
    $validcolors{$elements[0]} = $dataline;
   }
  }
 } elsif ( $_ =~ m/^labels/ ) {
  my @elements = split(/ /,$_);
  my $nlabels = $elements[1];
  for ( my $i=0 ; $i<$nlabels ; $i++ ) {
   my $dataline = <FPin>;
   chomp($dataline);
   my @elements = split(/ /,$dataline);
   $histogram{$elements[1]} = 0 unless ( exists($histogram{$elements[1]}) );
   $histogram{$elements[1]} += 1;
   if ( exists($validids{$elements[1]}) ) {
    $outlabels .= $dataline."\n";
   } else {
    if ( exists($conversionIds{$elements[1]}) ) {
     $outlabels .= $elements[0]." ".$conversionIds{$elements[1]}."\n";
    } else {
     $outlabels .= $elements[0]." ".$missingId."\n"; 
    }
   }
   $nTotalLabels += 1;
  }
 }
}
close(FPin);

### >>>
if ( $printinfo ) {
 my $n = 0;
 while ( my ($key,$value)=each(%missingids) ) {
  if ( exists($histogram{$key}) ) {
   print "DEBUG: $n $key $value -> ".$histogram{$key}." -> ".(exists($conversionIds{$key})?"+":"-")."\n" if ( $debuglevel );
   $n += 1;
  }
 }
 printfatalerror "FATAL ERROR: nmissings=$n, nvalidkeys=".scalar(keys(%validids))."\n";
 exit(1);
}

### >>>
print "# automatically created by $0\n";
print "# infile=".$filename."\n";
print "nvertices ".$nvertices."\n";
print "# >>>\n";
print "names ".(scalar(keys(%validids))+1)."\n";
while ( my ($key,$name)=each(%validids) ) {
 print $key." ".$name."\n";
}
print $missingId." GapMap-InternalArea\n";
print "# >>>\n";
print "colors ".(scalar(keys(%validcolors))+1)."\n";
while ( my ($key,$colstring)=each(%validcolors) ) {
 print $colstring."\n";
}
print $missingId." 255 0 0\n";
print "# >>>\n";
print "labels ".$nTotalLabels."\n";
print $outlabels;
