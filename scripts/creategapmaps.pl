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

### >>>
use strict;
use Getopt::Long;
use File::Basename;
use File::Copy;
use File::Path;
use Term::ANSIColor;

### >>>
die "FATAL ERROR: Missing global path variable HITHOME linked to HICoreTools." unless ( defined($ENV{HITHOME}) );
use lib $ENV{HITHOME}."/src/perl";
use hitperl;
use hitperl::git;

### >>>
my $help = 0;
my $verbose = 0;
my $debuglevel = 0;
my $cleanfolders = 0;
my $reference = "colin27";
my @sides = ("l","r");
my $revision = undef;
my $inpath = "../data/orig";
my $inbasepath = "../data";
my $outbasepath = "../data";
my $version = undef;
my $ontologyversion = undef;

### check whether external executables have been installed
my @executables = ("hitConverter","hitOverlay","hitFilter","hitGaussFilter","hitThreshold");
push(@executables,("jubrainconverter"));
my $nfails = checkExecutables($verbose,@executables);
### check dependencies
my %cRDlog = checkGITRepositoryDependencies($0,"dependencies.txt");
if ( scalar(keys(%cRDlog))>0 ) {
 print color('red');
  print "Serious warning:\n";
  print " Dependencies may no longer up-to-date. Please visit 'https://github.com/JulichBrainAtlas' and install if necessary current version!\n";
  while ( my ($repos,$infostr)=each(%cRDlog) ) {
   print "  ".$repos.": ".$infostr.".\n";
  }
 print color('reset');
}
### >>>
if ( !isGITRepositoryUpToDate() ) {
 print color('red');
 print "Serious warning:\n";
 print " Software is not up-to-date. Please visit 'https://github.com/JulichBrainAtlas/GapMap' and install current version!\n";
 print color('reset');
}

### >>>
sub printusage {
 my $errortext = shift;
 if ( defined($errortext) ) {
  print color('red');
  print "Error:\n ".$errortext.".\n";
  print color('reset');
 }
 print "Usage:\n ".basename($0)." [--help][(-v|--verbose)][(-d|--debug)][--cleanfolders][--reference <BRAIN>][--inpath <PATHNAME>][--outpath <PATHNAME>][--revision <NAME>] --version <Public|Internal> --ontology <VERSION>\n";
 print "Default parameters:\n";
 print " version........................ ".getGITRepositoryVersion()."\n";
 print " referenc brain................. ".$reference."\n";
 print " input base path................ '".$inbasepath."'\n";
 print " output base path............... '".$outbasepath."'\n";
 print " last call...................... '".getLastProgramLogMessage($0)."'\n";
 exit(1);
}
if ( @ARGV>0 ) {
 GetOptions(
  'help+' => \$help,
  'debug|d+' => \$debuglevel,
  'verbose|v+' => \$verbose,
  'cleanfolders+' => \$cleanfolders,
  'inpath=s' => \$inbasepath,
  'outpath=s' => \$outbasepath,
  'revision=s' => \$revision,
  'reference=s' => \$reference,
  'ontology=s' => \$ontologyversion,
  'version=s' => \$version) ||
 printusage();
}
printusage() if $help;
printusage("Missing required executables. See https://github.com/JulichBrainAtlas/GapMap for details") if ( $nfails>0 );
printusage("Missing input parameters") if ( !defined($version) && !defined($ontologyversion) );
printusage("Invalid version. Use Public or Internal") if ( !($version =~ m/^Public$/) && !($version =~ m/^Internal$/) );

### setup folders
my $outpath = $outbasepath."/raw";
my %outpaths = ();
@{$outpaths{$outbasepath."/raw"}} = (".dat","_mpm");
@{$outpaths{$outbasepath."/maps"}} = (".dat","_mpm",".nii.gz");
@{$outpaths{$outbasepath."/pmaps"}} = (".nii.gz");
@{$outpaths{$outbasepath."/col/VERSION:-"}} = (".png");
@{$outpaths{$outbasepath."/col"}} = (".png");
@{$outpaths{$outbasepath."/topo"}} = (".json");
@{$outpaths{$outbasepath."/mpm"}} = (".dat");

### clean output folders
if ( $cleanfolders ) {
 print "Cleaning output folders in '".$outbasepath."'...\n" if ( $verbose );
 my $cversion = lc($version);
 while ( my ($outpath,$suffices_ptr)=each(%outpaths) ) {
  my @suffices = @{$suffices_ptr};
  ## print " outpath=$outpath -> ".join(",",@suffices)."\n";
  $outpath =~ s/VERSION/$cversion/ if ( $outpath =~ m/VERSION/ );
  my $withVersionCheck = (split(":",$outpath))[1];
  $withVersionCheck = (defined($withVersionCheck) && $withVersionCheck eq "-")?0:1;
  $outpath = (split(":",$outpath))[0];
  if ( -d $outpath ) {
   print " + cleaning folder '".$outpath."', withVersionCheck=".$withVersionCheck."...\n" if ( $verbose );
   my @infiles = getDirent($outpath);
   foreach my $infile (@infiles) {
    if ( $withVersionCheck ) { next unless ( $infile =~ m/$version/i ); }
    my $filename = $outpath."/".$infile;
    foreach my $validsuffix (@suffices) {
     if ( $withVersionCheck ) { next unless ( $infile =~ m/$version/i ); }
     if ( $infile =~ m/$validsuffix$/ ) {
      print "  + removing file '".$filename."', valid suffices=(".join(",",@suffices).")...\n" if ( $verbose );
      unlink($filename) || printfatalerror "FATAL ERROR: Cannot remove file '".$filename."': $!";
     }
    }
   }
  } else {
   printwarning " - Cannot find folder '".$outpath."'.\n";
  }
 }
}

### creating paths
print "Creating output folders...\n" if ( $verbose );
my $cversion = lc($version);
while ( my ($outpath,$suffices_ptr)=each(%outpaths) ) {
 $outpath =~ s/VERSION/$cversion/ if ( $outpath =~ m/VERSION/ );
 $outpath = (split(":",$outpath))[0];
 if ( ! -d $outpath ) {
  print " + creating folder '".$outpath."'...\n" if ( $verbose );
  mkpath($outpath) || printfatalerror "FATAL ERROR: Cannot create output folder '".$outpath."': $!";
 }
}

### >>>
my $dversion = "";

### >>>
if ( $version =~ m/public/i ) {
 $dversion = "Public";
 print "Processing ".$dversion." version...\n" if ( $verbose );
 if ( !defined($revision) ) {
  print " Which revision? ";
  $revision = <STDIN>;
  chomp($revision);
 }
 foreach my $side (@sides) {
  my $outfilename = $outpath."/GapMap".$dversion."_Atlas_".$side."_N10_nlin2Std".$reference."_mpm.dat";
  if ( ! -e $outfilename ) {
   my $origfilename = $inpath."/GapMap".$dversion."_Atlas_".$side."_N10_nlin2Std".$reference."_mpm.dat";
   if ( ! -e $origfilename ) {
    print " + no original file '".$origfilename."'. Creating from internal...\n" if ( $verbose );
    my $infilename = $inpath."/GapMap".$dversion."_".$side."h_N10_nlin2Std".$reference."_mpm";
    $infilename .= "_".$revision if ( length($revision)>0 );
    $infilename .= ".dat";
    if ( -e $infilename ) {
     ssystem("perl internal2public.pl --input $infilename > $outfilename",$debuglevel);
     print "  + created file '".$outfilename."'.\n" if ( $verbose );
    } else {
     printfatalerror "FATAL ERROR: Cannot find input file '".$infilename."'.\n";
    }
   } else {
    copy($origfilename,$outfilename) || printfatalerror "FATAL ERROR: Copy failure: $!";
   }
  }
  if ( -e $outfilename ) {
   my $jubdoutfilename = $outfilename;
   $jubdoutfilename =~ s/\.dat//;
   ssystem("jubrainconverter -i $outfilename -o $jubdoutfilename --hint binary",$debuglevel);
   print "  + created file '".$jubdoutfilename."'.\n" if ( $verbose );
   my $goutfilename = $outfilename;
   $goutfilename =~ s/Atlas/GapMaps/;
   ssystem("perl getgapmaponly.pl --input $outfilename > $goutfilename",$debuglevel);
   print "  + created file '".$goutfilename."'.\n" if ( $verbose );
   my $jubd2outfilename = $goutfilename;
   $jubd2outfilename =~ s/\.dat//;
   ssystem("jubrainconverter -i $goutfilename -o $jubd2outfilename --hint binary",$debuglevel);
   print "  + created file '".$jubd2outfilename."'.\n" if ( $verbose );
  } else {
   printfatalerror "FATAL ERROR: No output file '".$outfilename."' $!";
  }
 }
} elsif ( $version =~ m/internal/i ) {
 $dversion = "Internal";
 print "Processing ".$dversion." version...\n" if ( $verbose );
 foreach my $side (@sides) {
  my $infilename = $inpath."/GapMap".$dversion."_Atlas_".$side."_N10_nlin2Std".$reference."_mpm.dat";
  if ( -e $infilename ) {
   print " + processing file '".$infilename."'...\n" if ( $verbose );
   my $jubdinfilename = $infilename;
   $jubdinfilename =~ s/orig/raw/;
   $jubdinfilename =~ s/\.dat//;
   ssystem("jubrainconverter -i $infilename -o $jubdinfilename --hint binary",$debuglevel);
   print "  + created file '".$jubdinfilename."'\n" if ( $verbose );
   my $goutfilename = $infilename;
   $goutfilename =~ s/orig/raw/;
   $goutfilename =~ s/Atlas/GapMaps/;
   ssystem("perl getgapmaponly.pl $infilename > $goutfilename",$debuglevel);
   print "  + created file '".$goutfilename."'\n" if ( $verbose );
   my $jubd2outfilename = $goutfilename;
   $jubd2outfilename =~ s/\.dat//;
   ssystem("jubrainconverter -i $goutfilename -o $jubd2outfilename --hint binary",$debuglevel);
   print "  + created file '".$jubd2outfilename."'\n" if ( $verbose );
  } else {
   printfatalerror "FATAL ERROR: Cannot find input file '".$infilename."'.\n";
  }
 }
} else {
 printfatalerror "FATAL ERROR: Invalid version '".$version."'. Use 'Public' or 'Internal'.\n";
}

### for both
print "Executing data processing steps...\n" if ( $verbose );
my $options = "--inpath ".$outbasepath;
$options .= " --verbose" if ( $verbose );
ssystem("perl createvolume.pl $options --version $dversion",$debuglevel);
ssystem("perl fakemaps.pl $options --version $dversion",$debuglevel);
ssystem("perl colorbar.pl $options --version $dversion --ontology $ontologyversion",$debuglevel);
ssystem("perl topology.pl $options --version $dversion --ontology $ontologyversion",$debuglevel);
