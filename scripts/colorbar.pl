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

# Create color map data, in particular the colormap overview table
# WARNING: Does not clean automatically the '../data/col/VERSION' folder

### >>>
use strict;
use File::Basename;
use Getopt::Long;
use POSIX qw/ceil/;
use Term::ANSIColor;

### >>>
die "FATAL ERROR: Missing global path variable HITHOME linked to HICoreTools." unless ( defined($ENV{HITHOME}) );
use lib $ENV{HITHOME}."/src/perl";
use hitperl;
use hitperl::database;
use hitperl::ontology;

### >>>
my $DATABASEPATH = $ENV{DATABASEPATH};
printfatalerror "FATAL ERROR: Invalid database path '".$DATABASEPATH."': $!" unless ( -d $DATABASEPATH );
my $ONTOLOGYPATH = "../../ontology";
printfatalerror "FATAL ERROR: Invalid ontology path '".$ONTOLOGYPATH."': $!" unless ( -d $ONTOLOGYPATH );

### >>>
my $help = 0;
my $verbose = 1;
my $debuglevel = 0;
my $ncolumns = 6;
my $hostname = "localhost";
my $accessfile = "login.dat";
my $reference = "colin27";
my $version = undef;
my $ignores = undef;
my $inpath = "../data";
my $ontologyversion = $ARGV[1];

### >>>
sub printusage {
 my $errortext = shift;
 if ( defined($errortext) ) {
  print color('red');
  print "error:\n ".$errortext.".\n";
  print color('reset');
 }
 print "usage:\n ".basename($0)." [--help][(-v|--verbose)][(-d|--debug)][--access <filename>][--ignore <list of ids>][--reference <BRAIN>]\n";
 print "\t[--columns <number=$ncolumns>][--inpath <PATHNAME>] --version <Public|Internal> --ontology <VERSION>\n";
 print "default parameters:\n";
 print " referenc brain................. ".$reference."\n";
 print " input data path................ '".$inpath."'\n";
 print " database path.................. '".$DATABASEPATH."'\n";
 print " ontology path.................. '".$ONTOLOGYPATH."'\n";
 print " last call...................... '".getLastProgramLogMessage($0)."'\n";
 exit(1);
}
if ( @ARGV>0 ) {
 GetOptions(
  'help+' => \$help,
  'debug|d+' => \$debuglevel,
  'verbose|v+' => \$verbose,
  'columns=i' => \$ncolumns,
  'access=s' => \$accessfile,
  'hostname=s' => \$hostname,
  'inpath=s' => \$inpath,
  'ignore=s' => \$ignores,
  'reference=s' => \$reference,
  'ontology=s' => \$ontologyversion,
  'version=s' => \$version) ||
 printusage();
}
printusage() if $help;
printusage("Missing input parameters") if ( !defined($version) && !defined($ontologyversion) );
printusage("Invalid version. Use Public or Internal") if ( !($version =~ m/^Public$/) && !($version =~ m/^Internal$/) );

### >>>
my $accessfilename = $DATABASEPATH."/scripts/data/".$accessfile;
my @accessdata = getAtlasDatabaseAccessData($accessfilename);
printfatalerror "FATAL ERROR: Malfunction in 'getAtlasDatabaseAccessData(".$accessfile.")'." if ( @accessdata!=2 );
my $dbh = connectToAtlasDatabase($hostname,$accessdata[0],$accessdata[1]);
printfatalerror "FATAL ERROR: Cannot connect to atlas database: $!" unless ( defined($dbh) );

### >>>
my $infilename = $inpath;
$infilename .= ($version =~ m/public/i)?"raw":"orig";
$infilename .= "/GapMap".$version."_Atlas_l_N10_nlin2Std".$reference."_mpm.dat";
printfatalerror "FATAL ERROR: Invalid input file '".$infilename."': $!" unless ( -e $infilename );

### >>>
my @executables = ("convert","montage");
my $nfails = checkExecutables($verbose,@executables);
printfatalerror "FATAL ERROR: Missing ".$nfails." executable(s). Cannot run script '".$0."'!" if ( $nfails>0 );

### >>>
sub getDisplayName {
 my ($structurename,$status) = @_;
 my $name = (split(/\(/,$structurename))[0];
 $name =~ s/^\s+|\s+$//g;
 return "p".$name if ( $status =~ m/public/i );
 return "i".$name if ( $status =~ m/internal/i );
 return "m".$name;
}

### >>>
my %officialnames = ();
my %tablepositions = ();
my %sortednames = ();
my $ontologyfilename = $ONTOLOGYPATH."/data/tables/Zyto_Projektliste_".$ontologyversion.".csv";
printfatalerror "FATAL ERROR: Invalid ontology file '".$ontologyfilename."': $!" unless ( -e $ontologyfilename );
print "Loading ontology file '".$ontologyfilename."'...\n" if ( $verbose );
my $n = 0;
my %csvdata = loadCSVFile($ontologyfilename,$verbose,$debuglevel);
my @datalines = @{$csvdata{"data"}};
foreach my $dataline (@datalines) {
 chomp($dataline);
 my @elements = split(/\;/,$dataline);
 my $status = $elements[15];
 if ( $status =~ m/public/i || $status =~ m/internal/i || $status =~ m/progeweress/i) {
  my $lobe = $elements[2];
  %{$sortednames{$lobe}} = () unless ( exists($sortednames{$lobe}) );
  if ( length($elements[7])>0 ) {
   my $prjname = $elements[8]."_".$elements[9];
   $officialnames{$prjname} = getDisplayName($elements[19],$status) if ( length($elements[19])>0 );
   $tablepositions{$prjname} = $n;
   my $level4string = $elements[19]."|".$status."|".$prjname."|>".getDisplayName($elements[19]);
   $n += 1;
  }
  $elements[16] =~ s/\s+$//;
  my $level4string = $elements[19]."|".$status."|".$elements[16]."|>".getDisplayName($elements[19]);
  $officialnames{$elements[16]} = getDisplayName($elements[19],$status) if ( length($elements[19])>0 );
  my $dspname = getDisplayName($elements[19]);
  $dspname = substr($dspname,1,length($dspname)-1);
  $tablepositions{$dspname} = $n;
  ${$sortednames{$lobe}}{$dspname} = $n;
  print "[".$n."|".$lobe."|".$elements[16]."] ||".$level4string."||\n";
  $n += 1;
 }
}
my $sortLabels = 1;
if ( $sortLabels ) {
 my @lobes = (
  "frontal lobe","insula","limbic lobe","occiptal lobe","parietal lobe",
  "temporal lobe","amygdala","ventral striatum","basal ganglia","dorsal thalamus",
  "midbrain","cerebellar nuclei"
 );
 my %ntablepositions = ();
 my $nn = 0;
 foreach my $lobe (@lobes) {
  if ( exists($sortednames{$lobe}) ) {
   print "Sorting lobe=".$lobe."\n";
   my %datas = %{$sortednames{$lobe}};
   foreach my $name (sort keys %datas) {
    my $num = $datas{$name};
    print " + name[".$num."]=$name\n";
    $ntablepositions{$name} = $nn;
    $nn += 1;
   }
  } else {
   printwarning "WARNING: Cannot find any data for lobe '".$lobe."'\n";
  }
 }
 %tablepositions = %ntablepositions;
}

foreach my $name (keys %tablepositions) {
 print ">".$name."<\n";
}

### >>>
sub getProjectNameFromDB {
 my ($dbh,$structureId) = @_;
 if ( $structureId<500 ) {
  my $prjIdent = fetchFromAtlasDatabase($dbh,"SELECT projectId FROM atlas.structures WHERE id='".$structureId."'");
  if ( $prjIdent ) {
   return fetchFromAtlasDatabase($dbh,"SELECT name FROM atlas.projects WHERE id='".$prjIdent."'");
  }
  return "unknown";
 }
 return "Misc";
}

### >>>
my $width = 48;
my $height = 16;
my $textwidth = 182;
my $txtorient = "west";

### >>>
my @ignoreIds = ();
@ignoreIds = split(/\,/,$ignores) if ( defined($ignores) );

### >>>
my %structurenames = ();
my %structurecolors = ();

### >>>
print "Parsing input file '".$infilename."'...\n" if ( $verbose );
open(FPin,"<$infilename") || printfatalerror "FATAL ERROR: Cannot open file '".$infilename."': $!";
 while ( <FPin> ) {
  if ( $_ =~ m/names/ ) {
   chomp($_);
   my $nnames = (split(/ /,$_))[1];
   print " + found headerline for $nnames names: $_\n";
   for ( my $n=0 ; $n<$nnames ; $n++ ) {
    my $nameline = <FPin>;
    chomp($nameline);
    my @elements = split(/ /,$nameline);
    my $projectname = getProjectNameFromDB($dbh,$elements[0]);
    $structurenames{$elements[0]} = $projectname."_".$elements[1];
    my $outname = $officialnames{$structurenames{$elements[0]}};
    print " + structure: id=".$elements[0].", internal_name=".$elements[1].", project=".$projectname.", outname=".$outname."\n" if ( $verbose );
   }
  } elsif ( $_ =~ m/colors/ ) {
   chomp($_);
   my $ncolors = (split(/ /,$_))[1];
   print " + found headerline for $ncolors colors: $_\n" if ( $verbose );
   for ( my $n=0 ; $n<$ncolors ; $n++ ) {
    my $colorline = <FPin>;
    chomp($colorline);
    my @elements = split(/ /,$colorline);
    my $red = $elements[1];
    my $green = $elements[2];
    my $blue = $elements[3];
    @{$structurecolors{$elements[0]}} = ($red,$green,$blue);
   }
  }
 }
close(FPin);

### >>>
my $n = 1;
my $m = 0;
foreach (sort { $a <=> $b } keys(%structurenames) ) {
 $m += 1 if ( $_<600 && !isInArray($_,\@ignoreIds) );
}
my $nesi = ($m-5)%$ncolumns;
$nesi = $ncolumns-$nesi if ( $nesi>0 );
my $coloutpath = createOutputPath("../data/col/".lc($version));
print "Color list of ".scalar(keys(%structurenames))."|".$nesi." input file '".$infilename."'...\n" if ( $verbose );
my $colormapstr = "";
my $n = 1;
foreach (sort { $a <=> $b } keys(%structurenames) ) {
 if ( $_<600 && !isInArray($_,\@ignoreIds) ) {
  my $countname = sprintf("%03d",$n);
  my @rgb = @{$structurecolors{$_}};
  print "DEBUG: structure[".$countname."]: id=".$_.", name=".$structurenames{$_}.", color=(".$rgb[0].":".$rgb[1].":".$rgb[2].")\n" if ( $debuglevel );
  $colormapstr .= $structurenames{$_}." ". $rgb[0]." ".$rgb[1]." ".$rgb[2]."\n";
  my $prjstrucname = $structurenames{$_};
  # >>>
   # creating color field
   my $colorfield = "tmpColorField_".$countname.".png";
   ssystem("convert -size ".$width."x".$height." xc:rgb\\\(".$rgb[0].",".$rgb[1].",".$rgb[2]."\\\) $colorfield",$debuglevel);
   # creating text field
   my $namefield = "tmpNameField_".$countname.".png";
   my $outname = (split(/\_/,$structurenames{$_}))[1];
   $outname = $officialnames{$prjstrucname} if ( exists($officialnames{$prjstrucname}) );
   $outname =~ s/GapMap/GM/ if ( $outname =~ m/^GapMap/ );
   $outname =~ s/HC/Hippocampus/ if ( $outname =~ m/HC/ );
   $outname =~ s/Mask// if ( $outname =~ m/Mask/ );
   my $status = ($outname =~ m/^p/ || $outname =~ m/^i/ || $outname =~ m/^m/)?substr($outname,0,1):"u";
   $outname = substr($outname,1,length($outname)-1) unless ( $status eq "u" );
   $outname =~ s/'/\\'/;
   print "DEBUG: outname[".$prjstrucname."]=$outname, status=$status\n" if ( $debuglevel );
   my $countId = exists($tablepositions{$outname})?$tablepositions{$outname}:($_<500?$n:$_);
   my $colfilename = $coloutpath."/id".sprintf("%03d",$countId)."_".(split(/\_/,$structurenames{$_}))[1].".png";
   print "DEBUG: structure[".$countId."][".$countname."]: id=".$_.", name=".$structurenames{$_}.", color=(".$rgb[0].":".$rgb[1].":".$rgb[2].") = ".$outname." -> ".$colfilename."\n" if ( $debuglevel );
   if ( $status eq "m" ) {
    ssystem("convert -size ".$textwidth."x".$height." xc:white -pointsize 16 -gravity $txtorient -fill red -draw \"text 0,0 '".$outname."'\" $namefield",$debuglevel);
   } elsif ( $status eq "i" ) {
    ssystem("convert -size ".$textwidth."x".$height." xc:white -pointsize 16 -gravity $txtorient -fill gray -draw \"text 0,0 '".$outname."'\" $namefield",$debuglevel);
   } else {
    ssystem("convert -size ".$textwidth."x".$height." xc:white -pointsize 16 -gravity $txtorient -draw \"text 0,0 '".$outname."'\" $namefield",$debuglevel);
   }
   # combining both fields
   ssystem("montage $colorfield $namefield -tile 2x1 -geometry +1+1 $colfilename",$debuglevel);
   unlink($colorfield) if ( -e $colorfield );
   unlink($namefield) if ( -e $namefield );
  # >>>
  $n += 1;
 }
}

### >>>
for ( my $k=1 ; $k<=$nesi ; $k++ ) {
 my $kk = 500-$k;
 my $colfilename = $coloutpath."/id".sprintf("%03d",$kk)."_EmptyFillImage".$kk.".png";
 ssystem("convert -size ".($width+$textwidth)."x".$height." xc:white $colfilename",$debuglevel);
}
my $colormapsfile = $inpath."/col/ColorField".$version."_".$ontologyversion.".png";
my $nrows = ceil($n/$ncolumns);
ssystem("montage ".$coloutpath."/id\*.png -tile ".$ncolumns."x".$nrows." -geometry +1+1 $colormapsfile",$debuglevel);
print "+ created colormap file '".$colormapsfile."'.\n" if ( $verbose );

### >>>
$dbh->disconnect() if ( defined($dbh) );
