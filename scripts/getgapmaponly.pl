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

# Script to extract all gap map areas

### >>>
use strict;
use File::Basename;
use Getopt::Long;

### >>>
use lib $ENV{HITHOME}."/src/perl";
use hitperl;

### >>>
my $help = 0;
my $verbose = 0;
my $debuglevel = 0;
my $outlabels = "";
my $nGapMapLabels = 0;
my $nvertices = 0;
my %gapmapids = ();
my %gapmapcolors = ();
my $filename = undef;

### >>>
sub printusage {
 my $errortext = shift;
 print "error:\n ".$errortext.".\n" if ( defined($errortext) );
 print "usage:\n ".basename($0)." [--help][(-v|--verbose)][(-d|--debug)] (-i|--input) <filename>\n";
 print "default parameters:\n";
 print " last call...................... '".getLastProgramLogMessage($0)."'\n";
 exit(1);
}
if ( @ARGV>0 ) {
 GetOptions(
  'help+' => \$help,
  'debug|d+' => \$debuglevel,
  'verbose|v+' => \$verbose,
  'input|i=s' => \$filename) ||
 printusage();
}
printusage() if $help;
printusage("Missing input parameter") if ( !defined($filename) );

### >>>
open(FPin,"<$filename") || printfatalerror "FATAL ERROR: Cannot open file '".$filename."': $!";
while ( <FPin> ) {
 next if ( $_ =~ m/^#/ );
 chomp($_);
 if ( $_ =~ m/^nvertices/ ) {
  my @elements = split(/ /,$_);
  $nvertices = $elements[1];
 } elsif ( $_ =~ m/^names/ ) {
  my @elements = split(/ /,$_);
  my $nnames = $elements[1];
  # print "names[".$nnames."]=$_\n";
  for ( my $i=0 ; $i<$nnames ; $i++ ) {
   my $dataline = <FPin>;
   chomp($dataline);
   my @elements = split(/ /,$dataline);
   if ( $elements[1] =~ m/GapMap/ ) {
    print "DEBUG: Found GapMap: name=".$elements[1].", id=".$elements[0]."\n" if ( $debuglevel );
    $gapmapids{$elements[0]} = $elements[1];
   }
  }
 } elsif ( $_ =~ m/^colors/ ) {
  my @elements = split(/ /,$_);
  my $ncolors = $elements[1];
  # print "ncolors = $ncolors\n";
  for ( my $i=0 ; $i<$ncolors ; $i++ ) {
   my $dataline = <FPin>;
   chomp($dataline);
   my @elements = split(/ /,$dataline);
   if ( exists($gapmapids{$elements[0]}) ) {
    print "DEBUG: Found color for label ".$gapmapids{$elements[0]}.": $dataline\n" if ( $debuglevel );
    $gapmapcolors{$elements[0]} = $dataline;
   }
  }
 } elsif ( $_ =~ m/^labels/ ) {
  my @elements = split(/ /,$_);
  my $nlabels = $elements[1];
  for ( my $i=0 ; $i<$nlabels ; $i++ ) {
   my $dataline = <FPin>;
   chomp($dataline);
   my @elements = split(/ /,$dataline);
   if ( exists($gapmapids{$elements[1]}) ) {
    $outlabels .= $dataline."\n";
    $nGapMapLabels += 1;
   }
  }
 }
}
close(FPin);

### >>>
print "# automatically created by $0\n";
print "# infile=".$filename."\n";
print "nvertices ".$nvertices."\n";
print "# >>>\n";
print "names ".scalar(keys(%gapmapids))."\n";
while ( my ($key,$name)=each(%gapmapids) ) {
 print $key." ".$name."\n";
}
print "# >>>\n";
print "colors ".scalar(keys(%gapmapcolors))."\n";
while ( my ($key,$colstring)=each(%gapmapcolors) ) {
 print $colstring."\n";
}
print "# >>>\n";
print "labels ".$nGapMapLabels."\n";
print $outlabels;
