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

# Script to create fake pmaps from binary gapmap volume files and normalized maps of them
# based on data in the folder '$inbasepath/maps'

### >>>
use strict;
use Getopt::Long;
use File::Basename;
use POSIX qw/floor/;
use List::Util qw[min];
use Term::ANSIColor;

### >>>
die "FATAL ERROR: Missing global path variable HITHOME linked to HICoreTools." unless ( defined($ENV{HITHOME}) );
use lib $ENV{HITHOME}."/src/perl";
use hitperl;
use hitperl::database;
use hitperl::mpmtool;
use hitperl::ontology;

### >>>
my $DATABASEPATH = $ENV{DATABASEPATH};
printfatalerror "FATAL ERROR: Invalid database path '".$DATABASEPATH."': $!" unless ( -d $DATABASEPATH );
my $ONTOLOGYPATH = "../../ontology";
printfatalerror "FATAL ERROR: Invalid ontology path '".$ONTOLOGYPATH."': $!" unless ( -d $ONTOLOGYPATH );
my $CONTOURRECON = "../../contourrecon";
printfatalerror "FATAL ERROR: Invalid contourrecon path '".$CONTOURRECON."': $!" unless ( -d $CONTOURRECON );

### >>>
my $help = 0;
my $verbose = 1;
my $debuglevel = 0;
my $overwrite = 0;
my $fdim = 1.5;
my $release = "22.0";
my $reference = "colin27";
my $hostname = "localhost";
my $accessfile = "login.dat";
my $inbasepath = "../data";
my $ontologyversion = undef;
my $version = undef;

### >>>
sub printusage {
 my $errortext = shift;
 if ( defined($errortext) ) {
  print color('red');
  print "error:\n ".$errortext.".\n";
  print color('reset');
 }
 print "usage:\n ".basename($0)." [--help][(-v|--verbose)][(-d|--debug)][--overwrite][--reference <BRAIN>][--access <filename>][--fwhm <value=$fdim>]\n";
 print "\t[--release <number=$release>][--inpath <PATHNAME>] --version <Public|Internal> --ontology <VERSION>\n";
 print "default parameters:\n";
 print " referenc brain................. ".$reference."\n";
 print " input data path................ '".$inbasepath."'\n";
 print " contourrecon path.............. '".$CONTOURRECON."'\n";
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
  'overwrite+' => \$overwrite,
  'fwhm=s' => \$fdim,
  'release=s' => \$release,
  'inpath=s' => \$inbasepath,
  'reference=s' => \$reference,
  'access=s' => \$accessfile,
  'ontologyversion=s' => \$ontologyversion,
  'version=s' => \$version) ||
 printusage();
}
printusage() if $help;
printusage("Missing input parameter(s)") if ( !defined($version) || !defined($ontologyversion) );
printusage("Invalid version. Use Public or Internal") if ( !($version =~ m/^Public$/) && !($version =~ m/^Internal$/) );

### >>>
my $inpath = $inbasepath."/maps";
printfatalerror "FATAL ERROR: Invalid input data path '".$inpath."': $!" unless ( -d $inpath );
my $outpath = createOutputPath($inbasepath."/pmaps");
my $mpmpath = createOutputPath($inbasepath."/mpm");

### >>>
my @executables = ("hitConverter","hitOverlay","hitFilter","hitGaussFilter");
my $nfails = checkExecutables($verbose,@executables);
printfatalerror "FATAL ERROR: Missing ".$nfails." executable(s). Cannot run script '".$0."'!" if ( $nfails>0 );

### >>>
sub getGapMapIdent {
 my $filename = shift;
 my %GapMapIds = (
  "500" => "Frontal-I",
  "501" => "Frontal-II",
  "502" => "Frontal-to-Temporal",
  "503" => "Temporal-to-Parietal",
  "504" => "Frontal-to-Occipital"
 );
 while ( my ($id,$name) = each(%GapMapIds) ) {
  return $id if ( $filename =~ m/\_${name}\_/ );
 }
 printwarning "WARNING: No valid GapMap id found for '".$filename."'.\n";
 return -1;
}
sub getStructureIdentsFromDatFile {
 my ($filename,$verbose) = @_;
 print "getStructureIdentsFromDatFile(): Loading dat file '".$filename."'...\n" if ( $verbose );
 open(FPin,"<$filename") || printfatalerror "FATAL ERROR: Cannot open file '".$filename."': $!";
  while ( <FPin> ) {
   if ( $_ =~ m/^names/ ) {
    chomp($_);
    my @idents = ();
    my @names = split(/ /,$_);
    for ( my $i=0 ; $i<$names[1] ; $i++ ) {
     my $dataline = <FPin>;
     chomp($dataline);
     my @elements = split(/ /,$dataline);
     push(@idents,$elements[0]) if ( $elements[0]<500 );
    }
    return @idents;
   }
  }
 close(FPin);
 return ();
}
sub getProjectStructureIdent {
 my ($dbh,$tbPrjLabel,$verbose,$debug) = @_;
 my @names = split(/\_/,$tbPrjLabel);
 my $prjDBIdent = fetchFromAtlasDatabase($dbh,"SELECT id FROM atlas.projects WHERE name='$names[0]'");
 if ( $prjDBIdent>0 ) {
  return fetchFromAtlasDatabase($dbh,"SELECT id FROM atlas.structures WHERE name='$names[1]' AND projectId='$prjDBIdent'");
 }
 return 0;
}

### loading original JuBrain data file to get incorporated structure idents
my $gapmappath = ($version =~ m/public/i)?"raw":"orig";
my @usedModelIdents = getStructureIdentsFromDatFile("../data/".$gapmappath."/GapMap".$version."_Atlas_l_N10_nlin2Std".$reference."_mpm.dat",$verbose);
push(@usedModelIdents,getStructureIdentsFromDatFile("../data/".$gapmappath."/GapMap".$version."_Atlas_r_N10_nlin2Std".$reference."_mpm.dat",$verbose));
my @usedNModelIdents = removeDoubleEntriesFromArray(@usedModelIdents);
my $idlist = join(",",sort {$a <=> $b} @usedNModelIdents);
print " + got ".scalar(@usedNModelIdents)." ".lc($version)." model structure ids=(".$idlist.").\n";

### with public or internal gapmap areas
my $leftmpmdatafile = $mpmpath."/".$reference."_fgpmaps_datatable_atlaswithgapmaps_".lc($version)."_left.dat";
my $rightmpmdatafile = $mpmpath."/".$reference."_fgpmaps_datatable_atlaswithgapmaps_".lc($version)."_right.dat";

if ( ! -e $leftmpmdatafile || ! -e $rightmpmdatafile ) {
 print "Computing global normalized mpm dat files ...\n" if ( $verbose );
 ### loading mpm data tables for global normalization
 my $srcpath = $CONTOURRECON."/scripts/data/mpm/to".ucfirst($reference)."F";
 printfatalerror "FATAL ERROR: Invalid input data path '".$srcpath."': $!" unless ( -d $srcpath );
 my %gndata = ();
 %{$gndata{"l"}} = loadMPMDataTable($srcpath."/".$reference."_fgpmaps_datatable_orig_left.dat",$verbose,$debuglevel);
 %{$gndata{"r"}} = loadMPMDataTable($srcpath."/".$reference."_fgpmaps_datatable_orig_right.dat",$verbose,$debuglevel);
 my $volopts = "-in:size 256 256 256 -out:compress true";
 ### get data data
 my @mpmStructureIds = getStructureIdentsFromMPMDataTable(\%{$gndata{"l"}});
 push(@mpmStructureIds,getStructureIdentsFromMPMDataTable(\%{$gndata{"r"}}));
 my @mpmNStructureIds = removeDoubleEntriesFromArray(@mpmStructureIds);
 print " + got ".scalar(@mpmNStructureIds)." structure ids=(".join(",",@mpmStructureIds).").\n" if ( $verbose );

 ### >>>
 print "Starting GapMap main computation...\n" if ( $verbose );
 my @infiles = getDirent($inpath);
 foreach my $infile (@infiles) {
  next unless ( $infile =~ m/_mpm.nii.gz/ );
  next unless ( $infile =~ m/GapMap$version/ );
  my @names = split(/\_/,$infile);
  next unless ( scalar(@names)==6 );
  ### >>>
  my $infilename = $inpath."/".$infile;
  my $outfilename = $outpath."/".$infile;
  my $side = $names[2];
  my $ident = getGapMapIdent($infile);
  next if ( $ident<0 );
  $outfilename =~ s/_mpm/_pmap/;
  $outfilename =~ s/_left_/_l_/;
  $outfilename =~ s/_right_/_r_/;
  if ( ! -e $outfilename || $overwrite ) {
   if ( $verbose ) {
    print " + processing /".scalar(@names)."/ '".$infile."': name=".$names[1].", side=".$side.", ident=".$ident."\n";
    print "  + infilename='".$infilename."', outfilename='".$outfilename."'\n";
   }
   # build volume file
   if ( ! -e $outfilename ) {
    print "  + computing gapmap volume file...\n" if ( $verbose );
    ssystem("hitConverter -f -i ".$infilename." -o test.vff.gz -out:format uchar -r DIRECT",$debuglevel);
    ssystem("hitGaussFilter -in test.vff.gz -out testgf.vff.gz -F $fdim",$debuglevel);
    ssystem("hitFilter -in test.vff.gz -out testd.vff.gz -f DILATE",$debuglevel);
    ssystem("hitOverlay -f -src1 testgf.vff.gz -src2 testd.vff.gz -o MASK -out testgff.vff.gz",$debuglevel);
    ssystem("hitConverter -f -i testgff.vff.gz -o ".$outfilename,$debuglevel);
    unlink("test.vff.gz") if ( -e "test.vff.gz" );
    unlink("testd.vff.gz") if ( -e "testd.vff.gz" );
    unlink("testgf.vff.gz") if ( -e "testgf.vff.gz" );
    unlink("testgff.vff.gz") if ( -e "testgff.vff.gz" );
    print "  + created gapmap pmap file '".$outfilename."'.\n" if ( $verbose );
   } else {
    print "  - skipped computation of gapmap volume file\n" if ( $verbose );
   }
   # normalize volume with used cerebral cortex structures
   print "  + normalizing gapmap data...\n" if ( $verbose );
   my $noutfilename = $outfilename;
   $noutfilename =~ s/pmap.nii.gz/npmap.nii.gz/;
   my @gfnames = split(/\_/,basename($infile));
   my $indexfile = "tmpIndexFile_".$gfnames[0]."_".$gfnames[1]."_".$gfnames[2].".itxt";
   my $vfffilename = "tmpVFFFileForMPMnormalization.vff.gz";
   ssystem("hitConverter -in $outfilename -out $vfffilename",$debuglevel);
   ssystem("hitConverter -f -in $vfffilename -out $indexfile -out:compress false",$debuglevel);
   unlink($vfffilename) if ( -e $vfffilename );
   my %mpmdatatable = addStructureValuesFromIndexFileToMPMDataTable(\%{$gndata{$side}},$indexfile,$ident,$verbose,$debuglevel) unless ( $debuglevel );
   unlink($indexfile) if ( -e $indexfile );
   #### >>>
   if ( ! -e $noutfilename ) {
    print "  + local normalizing of gapmap data...\n" if ( $verbose );
    my %datatable = %{$mpmdatatable{"data"}};
    my %indexvalues = ();
    while ( my ($key,$value)=each(%datatable) ) {
     my @datavalues = @{$value};
     for ( my $i=0 ; $i<scalar(@datavalues) ; $i+=2 ) {
      if ( $datavalues[$i]==$ident ) {
       my $gapMapValue = $datavalues[$i+1];
       my $tProb = 0.0;
       for ( my $j=0 ; $j<scalar(@datavalues) ; $j+=2 ) {
        if ( $i!=$j && isInArray($datavalues[$j],\@usedNModelIdents) ) {
         $tProb += $datavalues[$j+1];
        }
       }
       if ( $tProb<1.0 ) {
        my $nGapMapValue = min($gapMapValue,(1.0-$tProb));
        $indexvalues{$key} = $nGapMapValue;
       }
      }
     }
    }
    my $tmpindexfilename = "tmpPMapStructureDatatable__".$side.".itxt";
    my $tmpvffoutfile = "tmpFinalVFFFile.vff.gz";
    savePValuesAs(\%indexvalues,$tmpindexfilename,$verbose,$debuglevel);
    ssystem("hitConverter -f $volopts -in:format float -out:world no -out:mniworld -in $tmpindexfilename -out $tmpvffoutfile",$debuglevel);
    ssystem("hitConverter -f -i $tmpvffoutfile -o $noutfilename",$debuglevel);
    unlink($tmpvffoutfile) if ( -e $tmpvffoutfile );
    unlink($tmpindexfilename) if ( -e $tmpindexfilename );
    print "  + created normalized gapmap file '".$noutfilename.".\n" if ( $verbose );
   } else {
    print "  - skipped local normalization of gapmap data\n" if ( $verbose );
   }
   %{$gndata{$side}} = %mpmdatatable;
  } else {
   print " outfile '".$outfilename."' exists.\n" if ( $verbose );
  }
  ### >>>
 }
 ### saving final internal mpm data table (raw data, no normalization applied to the data)
 saveMPMDataTable(\%{$gndata{"l"}},$leftmpmdatafile,$verbose,$debuglevel);
 saveMPMDataTable(\%{$gndata{"r"}},$rightmpmdatafile,$verbose,$debuglevel);
} else {
 print "Have globaly normalized ".lc($version)." mpm dat files.\n" if ( $verbose );
}

### connect to database
my $accessfilename = $DATABASEPATH."/scripts/data/".$accessfile;
my @accessdata = getAtlasDatabaseAccessData($accessfilename);
printfatalerror "FATAL ERROR: Malfunction in 'getAtlasDatabaseAccessData($accessfilename)'." if ( @accessdata!=2 );
my $dbh = connectToDatabase($hostname,$accessdata[0],$accessdata[1],"jubrain");
printfatalerror "FATAL ERROR: Cannot connect to database: $!" unless ( defined($dbh) );

### using ontology file info
my $ontologypath = $ONTOLOGYPATH."/data/tables";
my $ontologyfile = "Zyto_Projektliste_".$ontologyversion.".csv";
my $ontologyfilename = $ontologypath."/".$ontologyfile;
printfatalerror "FATAL ERROR: Cannot open ontology file '".$ontologyfilename."': $!" unless ( -e $ontologyfilename );
print " + loading ontology file '".$ontologyfilename."'...\n" if ( $verbose );
my %structureHBPNames = ();
my %csvdata = loadCSVFile($ontologyfilename,$verbose,0);
my @datalines = @{$csvdata{"data"}};
my $n = 0;
my %idents = ();
if ( $version =~ m/public/i ) {
 foreach my $dataline (@datalines) {
  my @elements = split(/\;/,$dataline);
  my $status = $elements[15];
  if ( $status =~ m/^$version/i ) {
   my $psname = $elements[16];
   my $id = getProjectStructureIdent($dbh,$psname,$verbose,0);
   $idents{$id} = 1;
   $n += 1;
  }
 }
} else {
 foreach my $dataline (@datalines) {
  my @elements = split(/\;/,$dataline);
  my $status = $elements[15];
  if ( $status =~ m/public/i || $status =~ m/internal/i ) {
   my $psname = $elements[16];
   my $id = getProjectStructureIdent($dbh,$psname,$verbose,0);
   $idents{$id} = 1;
   $n += 1;
  }
 }
}
@usedNModelIdents = keys(%idents);

### >>>
push(@usedNModelIdents,(500,501,502,503,504));
$idlist = join(",",sort {$a <=> $b} @usedNModelIdents);
my $opts = "--default-mac --volume --atlas --ontology Zyto_Projektliste_".$ontologyversion.".csv --only ".$idlist;
my $leftmpmniftifile = "../data/mpm/JulichBrain_Atlas_l_N10_nlin2Std".$reference."_".$release."_".lc($version)."DOI.nii.gz";
ssystem("perl $CONTOURRECON/scripts/creatempm.pl $opts --project $leftmpmdatafile --out $leftmpmniftifile",$debuglevel);
my $rightmpmniftifile = "../data/mpm/JulichBrain_Atlas_r_N10_nlin2Std".$reference."_".$release."_".lc($version)."DOI.nii.gz";
ssystem("perl $CONTOURRECON/scripts/creatempm.pl $opts --project $rightmpmdatafile --out $rightmpmniftifile",$debuglevel);

### >>>
$dbh->disconnect() if ( defined($dbh) );
