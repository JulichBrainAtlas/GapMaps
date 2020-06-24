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

# Build topology plots

### >>>
use strict;
use Getopt::Long;
use File::Basename;
use Term::ANSIColor;

### >>>
die "FATAL ERROR: Missing global path variable HITHOME linked to HICoreTools." unless ( defined($ENV{HITHOME}) );
use lib $ENV{HITHOME}."/src/perl";
use hitperl;

### >>>
my $ONTOLOGYPATH = "../../ontology";
printfatalerror "FATAL ERROR: Invalid ontology path '".$ONTOLOGYPATH."': $!" unless ( -d $ONTOLOGYPATH );

### >>>
my $help = 0;
my $verbose = 0;
my $debuglevel = 0;
my $reference = "colin27";
my $inpath = "../data";
my $version = undef;
my $ontologyversion = undef;

### >>>
sub printusage {
 my $errortext = shift;
 if ( defined($errortext) ) {
  print color('red');
  print "error:\n ".$errortext.".\n";
  print color('reset');
 }
 print "usage:\n ".basename($0)." [--help][(-v|--verbose)][(-d|--debug)][--reference <BRAIN>][--inpath <PATHNAME>] --version <Public|Internal> --ontology <VERSION>\n";
 print "default parameters:\n";
 print " referenc brain................. ".$reference."\n";
 print " input data path................ '".$inpath."'\n";
 print " ontology path.................. '".$ONTOLOGYPATH."'\n";
 print " last call...................... '".getLastProgramLogMessage($0)."'\n";
 exit(1);
}
if ( @ARGV>0 ) {
 GetOptions(
  'help+' => \$help,
  'debug|d+' => \$debuglevel,
  'verbose|v+' => \$verbose,
  'reference=s' => \$reference,
  'inpath=s' => \$inpath,
  'ontologyversion=s' => \$ontologyversion,
  'version=s' => \$version) ||
 printusage();
}
printusage() if $help;
printusage("Missing input parameter(s)") if ( !defined($version) || !defined($ontologyversion) );
printusage("Invalid version. Use Public or Internal") if ( !($version =~ m/^Public$/) && !($version =~ m/^Internal$/) );

#### >>>
my $binpath = "../../mpmatlas/scripts";
printfatalerror "FATAL ERROR: Invalid path for requird binaries '".$binpath."': $!" unless ( -d $binpath );

#### >>>
my $ontologyfile = "Zyto_Projektliste_".$ontologyversion.".csv";
my $ontologyfilename = $ONTOLOGYPATH."/data/tables/".$ontologyfile;
printfatalerror "FATAL ERROR: Invalid ontology file '".$ontologyfilename."': $!" unless ( -e $ontologyfilename );

### >>>
my @sides = ("left","right");
foreach my $side (@sides) {
 my $sidec = substr($side,0,1);
 my $infile = $inpath."/";
 $infile .= ($version =~ m/public/i)?"raw":"orig";
 $infile .= "/GapMap".$version."_Atlas_".$sidec."_N10_nlin2Std".$reference."_mpm.dat";
 if ( -e $infile ) {
  my $outfile = $inpath."/topo/GapMap_fullatlas_".lc($version)."_".$sidec."h.json";
  print "Processing input file '".$infile."'...\n" if ( $verbose );
  my $infilename = $infile;
  my $outfilename = $outfile;
  ssystem("perl $binpath/createtopologydata.pl -i $infilename --side $side --ontology $ontologyfile -o $outfilename -v",$debuglevel);
  print " + created output file '".$outfile."'.\n" if ( $verbose );
 } else {
  printwarning "WARNING: Cannot find input file '".$infile."'.\n";
 }
}
