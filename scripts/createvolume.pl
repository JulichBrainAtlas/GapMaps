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

# Script to create volume files from dat file, original file in meshpainter/data/gapmap: 'volume.pl'
# Produces in addition the mpm label dat and jubrain files

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
my $help = 0;
my $debuglevel = 0;
my $verbose = 0;
my $extractareas = 0;
my $overwrite = 0;
my $gapmapIds = 500;
my $reference = "colin27";
my $dataversion = undef;
my $basepath = "../data";

### checking executables
my @executables = ("label2volume","jubrainc2onverter","hitThreshold");
my $nfails = checkExecutables($verbose,@executables);

### >>>
sub printusage {
 my $errortext = shift;
 if ( defined($errortext) ) {
  print color('red');
  print "error:\n ".$errortext.".\n";
  print color('reset');
 }
 print "usage:\n ".basename($0)." [--help][(-v|--verbose)][(-d|--debug)][--reference <BRAIN>][--extract-areas][--inpath <PATHNAME>] --version <Public|Internal>\n";
 print "default parameters:\n";
 print " referenc brain................. ".$reference."\n";
 print " input data path................ '".$basepath."'\n";
 print " last call...................... '".getLastProgramLogMessage($0)."'\n";
 exit(1);
}
if ( @ARGV>0 ) {
 GetOptions(
  'help+' => \$help,
  'debug|d+' => \$debuglevel,
  'verbose|v+' => \$verbose,
  'inpath=s' => \$basepath,
  'reference=s' => \$reference,
  'extract-areas+' => \$extractareas,
  'version=s' => \$dataversion) ||
 printusage();
}
printusage() if $help;
if ( $nfails>0 ) {
 printusage("Missing required executables. See https://github.com/JulichBrainAtlas/GapMap for details");
}
printusage("Missing input parameter") if ( !defined($dataversion) );
printusage("Invalid version. Use Public or Internal") if ( !($dataversion =~ m/^Public$/) && !($dataversion =~ m/^Internal$/) );

### >>>
sub extractDataOfLabel {
 my ($filename,$labelId,$isGapMap) = @_;
 print "extractDataOfLabel(): filename=$filename, labelId=$labelId, isGapMap=$isGapMap\n";
 my $nvertices = 0;
 my $outlabels = "";
 my %gapmapids = ();
 my %gapmapcolors = ();
 my $nGapMapLabels = 0;
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
   ## print "names[".$nnames."]=$_\n";
   if ( $isGapMap ) {
    for ( my $i=0 ; $i<$nnames ; $i++ ) {
     my $dataline = <FPin>;
     chomp($dataline);
     my @elements = split(/ /,$dataline);
     if ( $elements[1] =~ m/GapMap/ && $elements[0]==$labelId ) {
      ## print " + Found: name=".$elements[1].", id=".$elements[0]."\n";
      $gapmapids{$elements[0]} = $elements[1];
     }
    }
   } else {
    for ( my $i=0 ; $i<$nnames ; $i++ ) {
     my $dataline = <FPin>;
     chomp($dataline);
     my @elements = split(/ /,$dataline);
     if ( $elements[0]==$labelId ) {
      ## print " + Found: name=".$elements[1].", id=".$elements[0]."\n";
      $gapmapids{$elements[0]} = $elements[1];
     }
    }
   }
  } elsif ( $_ =~ m/^colors/ ) {
   my @elements = split(/ /,$_);
   my $ncolors = $elements[1];
   ### print "ncolors = $ncolors\n";
   for ( my $i=0 ; $i<$ncolors ; $i++ ) {
    my $dataline = <FPin>;
    chomp($dataline);
    my @elements = split(/ /,$dataline);
    if ( exists($gapmapids{$elements[0]}) ) {
     ## print " + found color for label ".$gapmapids{$elements[0]}.": $dataline\n";
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
 my $finalstr = "# automatically created by ".$0."\n";
 $finalstr .= "# infile=".$filename."\n";
 $finalstr .= "nvertices ".$nvertices."\n";
 $finalstr .= "# >>>\n";
 $finalstr .= "names ".scalar(keys(%gapmapids))."\n";
 while ( my ($key,$name)=each(%gapmapids) ) {
  $finalstr .= $key." ".$name."\n";
 }
 $finalstr .= "# >>>\n";
 $finalstr .= "colors ".scalar(keys(%gapmapcolors))."\n";
 while ( my ($key,$colstring)=each(%gapmapcolors) ) {
  $finalstr .= $colstring."\n";
 }
 $finalstr .= "# >>>\n";
 $finalstr .= "labels ".$nGapMapLabels."\n";
 $finalstr .= $outlabels;
 return $finalstr;
}

### >>>
sub getArealNameInfos {
 my ($filename,$verbose) = @_;
 my %areanames = ();
 open(FPin,"<$filename") || printfatalerror "FATAL ERROR: Cannot open '".$filename."' for reading: $!";
  while ( <FPin> ) {
   if ( $_ =~ m/^names/ ) {
    chomp($_);
    my @names = split(/ /,$_);
    my $nnames = $names[1];
    print " + parsing $nnames area names...\n";
    for ( my $k=0 ; $k<$nnames ; $k++ ) {
     my $nameline = <FPin>;
     chomp($nameline);
     my @anames = split(/ /,$nameline);
     $areanames{$anames[0]} = $anames[1] if ( scalar(@anames)==2 );
    }
    close(FPin);
    return %areanames;
   }
  }
 close(FPin);
 return %areanames;
}

### >>>
my $outpath = $basepath."/maps";
my $opts = "--overwrite --verbose";
$opts .= " --reference ".$reference;
my @sides = ("left","right");

### checking executables
my @executables = ("label2volume","jubrainconverter","hitThreshold");
my $nfails = checkExecutables($verbose,@executables);
printfatalerror "FATAL ERROR: Missing ".$nfails." executable(s). Cannot run script '".$0."'. See https://github.com/JulichBrainAtlas/GapMap for details!" if ( $nfails>0 );

### >>>
my $inpath = ($dataversion =~ m/internal/i)?$basepath."/orig":$basepath."/raw";
printfatalerror("FATAL ERROR: Invalid input path '".$inpath."': $!") unless ( -d $inpath );
if ( $extractareas ) {
 my $outpath = createOutputPath($basepath."/areas/".lc($dataversion));
 foreach my $side (@sides) {
  my $sidec = substr($side,0,1);
  my $sideopt = "--side ".$sidec;
  my $gapmapfile = $inpath."/GapMap".$dataversion."_Atlas_".$sidec."_N10_nlin2Std".$reference."_mpm.dat";
  if ( -e $gapmapfile ) {
   print "Processing gapmap file '".$gapmapfile."'...\n";
   my $volfile = $outpath."/".basename($gapmapfile);
   $volfile =~ s/\.dat/\.itxt/;
   my $volfilename = $volfile;
   $volfilename =~ s/\.itxt/\.nii\.gz/;
   my $sideopt = "--side ".$sidec;
   if ( ! -e $volfile || $overwrite ) {
    ssystem("label2volume $opts -i $gapmapfile --out ".$volfile." $sideopt --surftype n",$debuglevel) unless ( -e $volfilename );
    print " + created volume file '".$volfilename."'.\n" if ( $verbose );
   }
   my $nArea = 0;
   my %arealnames = getArealNameInfos($gapmapfile,$verbose);
   while ( my ($areaid,$areaname) = each(%arealnames) ) {
    if ( $areaid<$gapmapIds ) {
     $nArea += 1;
     my $areafilename = $outpath."/".basename($gapmapfile);
     $areafilename =~ s/Atlas/$areaname/;
     ### create mpm dat and jubd surf file
     if ( ! -e $areafilename || $overwrite ) {
      print "  + processing area [".$nArea."](name=$areaname,id=$areaid), outfilename='".$areafilename."'...\n" if ( $verbose );
      my $mpmdatastr = extractDataOfLabel($gapmapfile,$areaid,0);
      open(FPout,">$areafilename") || printfatalerror "FATAL ERROR: Cannot create area file '".$areafilename."': $!";
       print FPout $mpmdatastr;
      close(FPout);
      print "   + saved area label file '".$areafilename."'.\n" if ( $verbose );
      my $areajubdfilename = $areafilename;
      $areajubdfilename =~ s/\.dat//;
      ssystem("jubrainconverter -i ".$areafilename." -out ".$areajubdfilename." --hint binary -v --debug --like colin",$debuglevel);
      print "   + saved jubd area label file '".$areajubdfilename."'.\n";
     }
     ### create pmaps
     my $pmapfile = $outpath."/GapMap".$dataversion."_".$areaname."_".$sidec."_N10_nlin2Std".$reference."_pmap.dat";
     if ( ! -e $pmapfile || $overwrite ) {
      ssystem("label2volume $opts -i $gapmapfile --out ".$pmapfile." $sideopt --surftype n --pmap $areaid",$debuglevel);
     }
     my $gapmapfile = $pmapfile;
     $gapmapfile =~ s/_left_/_l_/ if ( $gapmapfile =~ m/_left_/ );
     $gapmapfile =~ s/_right_/_r_/ if ( $gapmapfile =~ m/_right_/ );
     $gapmapfile =~ s/_pmap.dat/_pmap/;
     if ( ! -e $gapmapfile || $overwrite ) {
      print "  + computing JulichBrain label file '".$gapmapfile."'...\n" if ( $verbose );
      ssystem("jubrainconverter -i ".$pmapfile." -out ".$gapmapfile." --hint binary -v --debug --ispmap --like ".$reference,$debuglevel);
     }
     print "  + thresholding label $areaname at threshold $areaid...\n";
     my $labelfilename = $outpath."/GapMap".$dataversion."_".$areaname."_".$sidec."_N10_nlin2Std".$reference."_mpm.nii.gz";
     ssystem("hitThreshold -i $volfilename -g $areaid -o $labelfilename -b 255 -v -f",$debuglevel);
    } else {
     print "  - skipping GapMap area (name=$areaname,id=$areaid)\n" if ( $verbose );
    }
   }
  } else {
   printwarning "WARNING: Cannot find GapMap file '".$gapmapfile."'.\n";
  }
 }
 exit(1);
}
my $fill = 1;
if ( $fill ) {
 my %thresholds_masks = (
  "500" => "Frontal-I",
  "501" => "Frontal-II",
  "502" => "Frontal-to-Temporal",
  "503" => "Temporal-to-Parietal",
  "504" => "Frontal-to-Occipital",
  "998" => "CorpusCallosumMask"
 );
 my %thresholds = (
  "500" => "Frontal-I",
  "501" => "Frontal-II",
  "502" => "Frontal-to-Temporal",
  "503" => "Temporal-to-Parietal",
  "504" => "Frontal-to-Occipital"
 );
 my %thresholds_frontalonly = (
  "500" => "Frontal-I",
  "501" => "Frontal-II",
  "502" => "Frontal-to-Temporal",
 );
 $opts .= " --fill";
 foreach my $side (@sides) {
  my $sidec = substr($side,0,1);
  my $gapmapfile = $inpath."/GapMap".$dataversion."_GapMaps_".$sidec."_N10_nlin2Std".$reference."_mpm.dat";
  if ( -e $gapmapfile ) {
   my $volfile = $outpath."/".basename($gapmapfile);
   $volfile =~ s/\.dat/\.itxt/;
   my $volfilename = $volfile;
   $volfilename =~ s/\.itxt/\.nii\.gz/;
   my $sideopt = "--side ".$sidec;
   if ( ! -e $volfile || $overwrite ) {
    ssystem("label2volume $opts -i $gapmapfile --out ".$volfile." $sideopt --surftype n",$debuglevel) unless ( -e $volfilename );
   }
   while ( my ($threshold,$name) = each(%thresholds) ) {
    print " + computing mpm data sets for label ".$name."...\n" if ( $verbose );
    # mpm stuff
    my $mpmlabeloutfilename = $outpath."/".basename($gapmapfile);
    $mpmlabeloutfilename =~ s/_GapMaps_/_${name}_/;
    if ( ! -e $mpmlabeloutfilename || $overwrite ) {
     print "  + extracting mpm of labe[$threshold]=".$name." from '".$gapmapfile."'...\n";
     my $mpmdatastr = extractDataOfLabel($gapmapfile,$threshold,1);
     open(FPout,">$mpmlabeloutfilename") || printfatalerror "FATAL ERROR: Cannot create output file '".$mpmlabeloutfilename."': $!";
      print FPout $mpmdatastr;
     close(FPout);
     print "   + saved gapmap label file '".$mpmlabeloutfilename."'.\n" if ( $verbose );
    }
    if ( -e $mpmlabeloutfilename ) {
     my $mpmjubrainlabeloutfilename = $mpmlabeloutfilename;
     $mpmjubrainlabeloutfilename =~ s/\.dat//;
     if ( ! -e $mpmjubrainlabeloutfilename || fileIsNewer($mpmlabeloutfilename,$mpmjubrainlabeloutfilename) || $overwrite ) {
      ssystem("jubrainconverter -i ".$mpmlabeloutfilename." -out ".$mpmjubrainlabeloutfilename." --hint binary -v --debug --like colin",$debuglevel);
     }
    } else {
     printwarning " - missing mpm labelfile '".$mpmlabeloutfilename."'.\n";
    }
    # pmap stuff
    my $pmapfile = $outpath."/GapMap".$dataversion."_".$name."_".$sidec."_N10_nlin2Std".$reference."_pmap.dat";
    if ( ! -e $pmapfile || $overwrite ) {
     ssystem("label2volume $opts -i $gapmapfile --out ".$pmapfile." $sideopt --surftype n --pmap $threshold",$debuglevel);
    }
    my $gapmapfile = $pmapfile;
    $gapmapfile =~ s/_left_/_l_/ if ( $gapmapfile =~ m/_left_/ );
    $gapmapfile =~ s/_right_/_r_/ if ( $gapmapfile =~ m/_right_/ );
    $gapmapfile =~ s/_pmap.dat/_pmap/;
    if ( ! -e $gapmapfile || $overwrite ) {
     print "  + computing JulichBrain label file '".$gapmapfile."'...\n" if ( $verbose );
     ssystem("jubrainconverter -i ".$pmapfile." -out ".$gapmapfile." --hint binary -v --debug --ispmap --like ".$reference,$debuglevel);
    }
    print "  + thresholding label $name at threshold $threshold...\n";
    my $labelfilename = $outpath."/GapMap".$dataversion."_".$name."_".$sidec."_N10_nlin2Std".$reference."_mpm.nii.gz";
    ssystem("hitThreshold -i $volfilename -g $threshold -o $labelfilename -b 255 -v -f",$debuglevel);
   }
  } else {
   printwarning "WARNING: Cannot find input gapmap file '".$gapmapfile."'.\n";
  }
 }
} else {
 $opts .= " --binary --oversampling 1 --dynamic";
 foreach my $side (@sides) {
  my $sidec = substr($side,0,1);
  my $gapmapfile = $inpath."/GapMap".$dataversion."_".$sidec."_N10_nlin2Std".$reference."_mpm_publicatlas5edited.dat";
  my $distfilename = $reference."T1_distancemap_".$sidec.".dat";
  my $volfile = $outpath."/GapMap".$dataversion."_".$sidec."_N10_nlin2Std".$reference."_mpm_publicatlas5edited";
  my $sideopt = "--side ".$sidec;
  ssystem("label2volume $opts -i $gapmapfile --distancemap ".$distfilename." $sideopt",$debuglevel) unless( -e $distfilename );
  #ssystem("label2volume $opts -i $gapmapfile --out ".$volfile."_smoothwm.itxt $sideopt --surftype m",$debug);
  #ssystem("label2volume $opts -i $gapmapfile --out ".$volfile."_pial.itxt $sideopt --surftype n",$debug);
  #ssystem("label2volume $opts -i $gapmapfile --out ".$volfile."_inner.itxt $sideopt --inner",$debug);
 }
}
