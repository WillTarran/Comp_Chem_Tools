#!/usr/bin/perl 
use Switch;

$DEBUG = 0;
if ($#ARGV < 0)
{
  printHelp();
}
if($DEBUG) {print "Arguments: ".join(" ",@ARGV)."\n";}


#####################################################################
# Set defaults
#####################################################################

$numProc = 4;
$memory = "7GB";
$jobtype=0;
$overRideChargeMulti=0;
$functional="B3LYP";
$basis="6-31g(d)";
$TDfunc= "B3LYP";
$JOBTYPEKNOWN=0;
$optKeyword="opt";
$extraOptions="";
$solvent="water";
$solname="water";
$readSolvent=0;
$epsfile = "/CDT/shared/software/scripts/eps.txt" ;
$inffile = "/CDT/shared/software/scripts/epsinf.txt" ;
#####################################################################
# Parse arguments
#####################################################################
for($j=0; $j<=$#ARGV; $j++)
{
  switch ($ARGV[$j])
  { 
    case "-h"
    { 
      printHelp();
    }
    case (/\.com$/) 
    { 
      push(@comFiles,$ARGV[$j]);
    }
    case (/\.chk$/) 
    { 
      push(@chkFiles,$ARGV[$j]);
    }
    case "-p"
    {
      $j++; #next arg is number of processors
      $numProc  = $ARGV[$j];
      if(! $numProc =~ /\d/)           ## This is broken - needs fixing to properly catch processor issues
      {
        print "Incorrect format for number of processors. Please request a number up to 32.\n";
        exit();
      }
    }
    case "-e"
    {
      $j++; #next arg is extra keywords
      $extraOptions  = $ARGV[$j];
    }
    case "-opt"
    {
      $j++; #next arg is amount of memory
      $optKeyword  = $ARGV[$j];
      if($DEBUG) {print "Using custom opt keywords $optKeyword\n";}
    }
    case "-m"
    {
      $j++; #next arg is amount of memory
      $memory  = $ARGV[$j];
    }
    case "-j"
    {
      $j++; #next arg is job type 
      $jobtype  = $ARGV[$j];
    }
    case "-cm"
    {
      $overRideChargeMulti=1;
      $j++; #next arg is charge  
      $newCharge  = $ARGV[$j];
      $j++; #next arg is charge  
      $newMultiplicity  = $ARGV[$j];
    }
    case "-tdfunc"
    {
      $j++; #next arg is TD-DFT funcational 
      $TDfunc= $ARGV[$j];
    }
    case "-sol"
    {
      $j++; #next arg is solvent for SCRF 
      $solname = $solvent= $ARGV[$j];
      ReadEps() ; # Define Solvent hash from files
      if ( lc $solvent eq "read" )
      { 
         $readSolvent = 1;
         $solvent = "generic,read" ;
         print "[-sol read] specified; please enter solvent parameters.\n" ;
         print "Enter eps: " ;
         chomp ( $eps = <STDIN> ) ;
         print "Enter epsinf: " ;
         chomp ( $epsinf = <STDIN> ) ;
         $solname = "Custom" ;
       } 
      if ( lc $solvent eq "mix" )
      { 
         $readSolvent = 2;
         $solvent = "generic,read" ;
         ( $solname , $eps , $epsinf ) = Mix() ;
       } 
      if ($readSolvent == 0 )
      {
          my $foundentry = 0 ;
          foreach my $sol ( keys %{ $hash{$epsfile} } ) {
               lc $solvent eq lc $sol  and $foundentry = 1 ;
          }
          $foundentry == 1 or die "Can't find $solvent in Gaussian Solvents list -- exiting\n" ; 
      }
    }
    else
    {
      print "ERROR: Unknown option: $ARGV[$j]\n";
      exit(1);
    }
  }
}

#loop over input com files

foreach $inputCom (@comFiles)
{
  if($DEBUG) {print "working on $inputCom\n";}
  ($geom,$charge,$multiplicity,$CONNECTIVITY,%nOfSym)=readCom($inputCom);
  if($overRideChargeMulti) { ($charge,$multiplicity)=($newCharge,$newMultiplicity);}

  @elems=sort(keys(%nOfSym));
  print "Chemical formular of $inputCom: ";
  foreach $elem (@elems) { printf("%s%i",$elem,$nOfSym{$elem});}
  print "\n";
  if($multiplicity!="1" && $jobtype!="10") { print "\nWARNING!! Input structure is not Singlet state\n\n";}
  $jobtype == 10 || print "Charge: $charge\nMultiplicity: $multiplicity\n";

  $toPrint="";
  $chk[0]=$inputCom;
  $chk[0]=~s/.com/.chk/g;
  $toPrint=$toPrint.makeHeader($numProc,$memory,$chk[0]);
  
  if($jobtype=="0")  # SP calculation
  {
    $optKeyword="SP" ;
    ($cmd,$basisSetInput)=makeFirstGeomOptCmd(\%nOfSym,$optKeyword);
    if($CONNECTIVITY) { $cmd=$cmd." geom=connectivity ";}
    $title="\n\nSingle Point Calculation\n\n"; #blank line title blank line
    $toPrint=$toPrint.$cmd." ".$extraOptions.$title.$charge." ".$multiplicity."\n".$geom.$basisSetInput;
    $JOBTYPEKNOWN=1; 
  }
  if($jobtype=="1")  # B3LYP geom opt only
  {
    ($cmd,$basisSetInput)=makeFirstGeomOptCmd(\%nOfSym,$optKeyword);
    if($CONNECTIVITY) { $cmd=$cmd." geom=connectivity ";}
    $title="\n\nOpt\n\n"; #blank line title blank line
    $toPrint=$toPrint.$cmd." ".$extraOptions.$title.$charge." ".$multiplicity."\n".$geom.$basisSetInput;
    $JOBTYPEKNOWN=1; 
  }
  if($jobtype=="2") #B3LYP geom opt + TD-DFT calc
  { 
    ($cmd,$basisSetInput)=makeFirstGeomOptCmd(\%nOfSym,$optKeyword);
    if($CONNECTIVITY) { $cmd=$cmd." geom=connectivity ";}
    $title="\n\nOpt\n\n"; #blank line title blank line
    $toPrint=$toPrint.$cmd." ".$extraOptions.$title.$charge." ".$multiplicity."\n".$geom.$basisSetInput;

    $chk[1]=$chk[0];
    $chk[1]=~s/.chk/-TD.chk/;
    $TDsection="--Link1--\n".makeHeader($numProc,$memory,$chk[0],$chk[1]).makeTDcmdTitleAndMulti($TDfunc,$extraOptions)."\n";
    $toPrint=$toPrint.$TDsection;
    $JOBTYPEKNOWN=1; 
  }

  if($jobtype=="3") #B3LYP geom opt + TD-DFT calc + T1 opt
  { 
    ($cmd,$basisSetInput)=makeFirstGeomOptCmd(\%nOfSym,$optKeyword);
    if($CONNECTIVITY) { $cmd=$cmd." geom=connectivity ";}
    $title="\n\nOpt\n\n"; #blank line title blank line
    $toPrint=$toPrint.$cmd." ".$extraOptions.$title.$charge." ".$multiplicity."\n".$geom.$basisSetInput;

    $chk[1]=$chk[0];
    $chk[1]=~s/.chk/-TD.chk/;
    $TDsection="--Link1--\n".makeHeader($numProc,$memory,$chk[0],$chk[1]).makeTDcmdTitleAndMulti($TDfunc,$extraOptions)."\n";
    $toPrint=$toPrint.$TDsection;

    $chk[2]=$chk[0];
    $chk[2]=~s/.chk/-T1opt.chk/;
    $T1OptSection="--Link1--\n".makeHeader($numProc,$memory,$chk[0],$chk[2]).makeT1Optcmd($extraOptions)."\n";
    $toPrint=$toPrint.$T1OptSection;
 
    $JOBTYPEKNOWN=1; 
  }
  if($jobtype=="4") #AM1 geom opt + B3LYP geom opt
  { 
    if(exists($nOfSym{"Ir"})) {print "Error: Can't run AM1 on an Ir complex!\n"; exit();}
    $cmd="#p $optKeyword AM1 nosym";
    if($CONNECTIVITY) { $cmd=$cmd." geom=connectivity ";}
    $title="\n\nOptimise with AM1\n\n"; #blank line title blank line
    $toPrint=$toPrint.$cmd." ".$extraOptions.$title.$charge." ".$multiplicity."\n".$geom;

    ($cmd,$basisSetInput)=makeFirstGeomOptCmd(\%nOfSym,$optKeyword);
    $title="\n\nOpt with DFT from AM1 geom\n\n";
    $optDFTsection="--Link1--\n".makeHeader($numProc,$memory,$chk[0]).$cmd." geom=check ".$extraOptions;
    $toPrint=$toPrint.$optDFTsection.$title.$charge." ".$multiplicity."\n";
 
    $JOBTYPEKNOWN=1; 
  }
  if($jobtype=="5") #AM1 geom opt + B3LYP geom opt +TD-DFT
  { 
    if(exists($nOfSym{"Ir"})) {print "Error: Can't run AM1 on an Ir complex!\n"; exit();}
    $cmd="#p $optKeyword AM1 nosym";
    if($CONNECTIVITY) { $cmd=$cmd." geom=connectivity ";}
    $title="\n\nOptimise with AM1\n\n"; #blank line title blank line
    $toPrint=$toPrint.$cmd." ".$extraOptions.$title.$charge." ".$multiplicity."\n".$geom;

    ($cmd,$basisSetInput)=makeFirstGeomOptCmd(\%nOfSym,$optKeyword);
    $title="\n\nOpt with DFT from AM1 geom\n\n";
    $optDFTsection="--Link1--\n".makeHeader($numProc,$memory,$chk[0]).$cmd." geom=check ".$extraOptions;
    $toPrint=$toPrint.$optDFTsection.$title.$charge." ".$multiplicity."\n";

    $chk[1]=$chk[0];
    $chk[1]=~s/.chk/-TD.chk/;
    $TDsection="--Link1--\n".makeHeader($numProc,$memory,$chk[0],$chk[1]).makeTDcmdTitleAndMulti($TDfunc,$extraOptions)."\n";
    $toPrint=$toPrint.$TDsection;
 
    $JOBTYPEKNOWN=1; 
  }

  if($jobtype=="6") #AM1 geom opt + B3LYP geom opt +TD-DFT + T1 opt
  { 
    if(exists($nOfSym{"Ir"})) {print "Error: Can't run AM1 on an Ir complex!\n"; exit();}
    $cmd="#p $optKeyword AM1 nosym";
    if($CONNECTIVITY) { $cmd=$cmd." geom=connectivity ";}
    $title="\n\nOptimise with AM1\n\n"; #blank line title blank line
    $toPrint=$toPrint.$cmd." ".$extraOptions.$title.$charge." ".$multiplicity."\n".$geom;

    ($cmd,$basisSetInput)=makeFirstGeomOptCmd(\%nOfSym,$optKeyword);
    $title="\n\nOpt with DFT from AM1 geom\n\n";
    $optDFTsection="--Link1--\n".makeHeader($numProc,$memory,$chk[0]).$cmd." geom=check ".$extraOptions;
    $toPrint=$toPrint.$optDFTsection.$title.$charge." ".$multiplicity."\n";

    $chk[1]=$chk[0];
    $chk[1]=~s/.chk/-TD.chk/;
    $TDsection="--Link1--\n".makeHeader($numProc,$memory,$chk[0],$chk[1]).makeTDcmdTitleAndMulti($TDfunc,$extraOptions)."\n";
    $toPrint=$toPrint.$TDsection;

    $chk[2]=$chk[0];
    $chk[2]=~s/.chk/-T1opt.chk/;
    $T1OptSection="--Link1--\n".makeHeader($numProc,$memory,$chk[0],$chk[2]).makeT1Optcmd($extraOptions)."\n";
    $toPrint=$toPrint.$T1OptSection;
 
    $JOBTYPEKNOWN=1; 
  }
  if($jobtype=="7") #B3LYP geom opt + TD-DFT calc (B3LYP and PBE0)
  { 
    ($cmd,$basisSetInput)=makeFirstGeomOptCmd(\%nOfSym,$optKeyword);
    if($CONNECTIVITY) { $cmd=$cmd." geom=connectivity ";}
    $title="\n\nOpt\n\n"; #blank line title blank line
    $toPrint=$toPrint.$cmd." ".$extraOptions.$title.$charge." ".$multiplicity."\n".$geom.$basisSetInput;

    $chk[1]=$chk[0];
    $chk[1]=~s/.chk/-TD.chk/;
    $TDsection="--Link1--\n".makeHeader($numProc,$memory,$chk[0],$chk[1]).makeTDcmdTitleAndMulti($TDfunc,$extraOptions)."\n";
    $toPrint=$toPrint.$TDsection;

    $chk[2]=$chk[0];
    $chk[2]=~s/.chk/-PBETD.chk/;
    $PBEsection="--Link1--\n".makeHeader($numProc,$memory,$chk[0],$chk[2]).makeTDcmdTitleAndMulti("PBE1PBE",$extraOptions)."\n";
    $toPrint=$toPrint.$PBEsection;

    $JOBTYPEKNOWN=1; 
  }
  if($jobtype=="8")  # B3LYP opt freq job
  {
    ($cmd,$basisSetInput)=makeFirstGeomOptCmd(\%nOfSym,$optKeyword);
    if($CONNECTIVITY) { $cmd=$cmd." geom=connectivity ";}
    $cmd=$cmd." freq ";
    $title="\n\nOpt\n\n"; #blank line title blank line
    $toPrint=$toPrint.$cmd." ".$extraOptions.$title.$charge." ".$multiplicity."\n".$geom.$basisSetInput;
    $JOBTYPEKNOWN=1; 
  }
  if($jobtype=="9") #AM1 geom opt only
  { 
    if(exists($nOfSym{"Ir"})) {print "Error: Can't run AM1 on an Ir complex!\n"; exit();}
    $cmd="#p $optKeyword AM1 nosym";
    if($CONNECTIVITY) { $cmd=$cmd." geom=connectivity ";}
    $title="\n\nOptimise with AM1\n\n"; #blank line title blank line
    $toPrint=$toPrint.$cmd." ".$extraOptions.$title.$charge." ".$multiplicity."\n".$geom;
    $JOBTYPEKNOWN=1; 
  }
  if($jobtype=="10") #Electrochem calculation. Takes input charge / multiplicity and follows with reduced species
  {
    my $Redoxflag=0;
    ### Set up Reduced charge/multiplicity
    if ($charge=="1" && $multiplicity=="2")
    {
       $charge2="0";
       $multiplicity2="1";
       $chk1="Cation";
       $chk2="Neutral";
       $Redoxflag=1;
    }
    if ($charge=="1" && $multiplicity=="1")
    {
       $charge2="0";
       $multiplicity2="2";
       $chk1="Cation";
       $chk2="Radical";
       $Redoxflag=1;
    }
    if ($charge=="0" && $multiplicity=="1")
    {
       $charge2="-1";
       $multiplicity2="2";
       $chk1="Neutral";
       $chk2="Anion";
       $Redoxflag=1;
       print "Note: Results for anions may be significantly improved by including diffuse basis functions\n";
    }
    if ($charge=="0" && $multiplicity=="2")
    {
       $charge2="-1";
       $multiplicity2="1";
       $chk1="Radical";
       $chk2="Anion";
       $Redoxflag=1;
       print "Note: Results for anions may be significantly improved by including diffuse basis functions\n";
    }
    if ($Redoxflag==0)
    {
       print "ERROR: Can't resolve redox charge and multiplicities\n";
       exit(1);
    }
    print "Calculations for reduction of $charge $multiplicity state to $charge2 $multiplicity2\n";
    print "Solvent for SCRF corrections is $solname\n";
    ### Update initial toPrint with chk1 name
    $chk[1]=$chk[0];
    $chk[1]=~s/.chk/-$chk1.chk/;
    $toPrint=~s/$chk[0]/$chk[1]/;

    ($cmd,$basisSetInput)=makeFirstGeomOptCmd(\%nOfSym,$optKeyword);
    if($CONNECTIVITY) { $cmd=$cmd." geom=connectivity ";}
    $cmd=$cmd." freq";
    $title="\n\nOpt/Freq of $charge $multiplicity State\n\n"; #blank line title blank line
    $toPrint=$toPrint.$cmd." ".$extraOptions.$title.$charge." ".$multiplicity."\n".$geom.$basisSetInput;

    $chk[2]=$chk[1];
    $chk[2]=~s/$chk1/$chk2/;
    $title=~s/$charge $multiplicity/$charge2 $multiplicity2/;
    $Redsection="--Link1--\n".makeHeader($numProc,$memory,$chk[1],$chk[2]).makeRedoxcmd($extraOptions)."\n";
    $toPrint=$toPrint.$Redsection;

    $SCRFSection="--Link1--\n".makeHeader($numProc,$memory,$chk[1]).makeSCRFcmd($extraOptions)."\n"; # Header for solvent correction to state 1
    if ($readSolvent != 0) { $SCRFSection=$SCRFSection."solventname=$solname\neps=$eps\nepsinf=$epsinf\n\n" ;   }
    $SCRFSection=$SCRFSection."--Link1--\n".makeHeader($numProc,$memory,$chk[2]).makeSCRFcmd($extraOptions)."\n"; # Header for solvent correction to state 2
    if ($readSolvent != 0) { $SCRFSection=$SCRFSection."solventname=$solname\neps=$eps\nepsinf=$epsinf\n\n" ;   }
    $toPrint=$toPrint.$SCRFSection;

    $JOBTYPEKNOWN=1;
  }
  if($jobtype=="11") #B3LYP geom opt + TD-DFT calc for 30 singlets
  { 
    ($cmd,$basisSetInput)=makeFirstGeomOptCmd(\%nOfSym,$optKeyword);
    if($CONNECTIVITY) { $cmd=$cmd." geom=connectivity ";}
    $title="\n\nOpt\n\n"; #blank line title blank line
    $toPrint=$toPrint.$cmd." ".$extraOptions.$title.$charge." ".$multiplicity."\n".$geom.$basisSetInput;

    $chk[1]=$chk[0];
    $chk[1]=~s/.chk/-TDsinglets.chk/;
    $TDsection="--Link1--\n".makeHeader($numProc,$memory,$chk[0],$chk[1]).makeUVcmdTitleAndMulti($TDfunc,$extraOptions)."\n";
    $toPrint=$toPrint.$TDsection;
    $JOBTYPEKNOWN=1; 
  }
  if($JOBTYPEKNOWN==0)
  {
    print "ERROR: Unknown jobtype: $jobtype\n";
    exit(1);
  }

  open OUTPUT,">", $inputCom;
   $toPrint=~s/\n\n\n/\n\n/; #remove any double blank lines - g09 will fail otherwise
   print OUTPUT $toPrint; 
}

sub makeFirstGeomOptCmd()
{
  my $nOfSymRef=shift(@_);
  my $optKeyword=shift(@_);
  my $extraOptions=shift(@_);
#  if($DEBUG) {print "optkey words ".$optKeyword."\n";}
  my %nOfSym=%$nOfSymRef;
  my $cmd;
  my $basisSetInput;
  my $elemList;
  makeAtomNumHash();
  @elems=keys %nOfSym;
  my $USEECP=0;
  my @ecpElems;
  my %ecpElemHash;
  my $ecpElemsList;
  foreach $elem (@elems)
  {
    if($numOfSym{$elem}>36) #if anything bigger than krpyton
    {
      $USEECP=1;
      if($DEBUG) {print "Found an atom which needs an ECP: $elem\n";}
      push(@ecpElems,$elem);
      $ecpElemHash{$elem}="";
    }
    else
    {
      $elemList=$elemList.$elem." ";
    }
  }
  if($USEECP) 
  {
    $cmd=sprintf("#p %s B3LYP/gen pseudo=read nosym",$optKeyword);  # Functional and Basis Set Hard Coded here...
    $ecpElemList=join(' ',@ecpElems);
    print "The following elements will use the lanl2dz effective core potential: $ecpElemList\n";
    $basisSetInput="\n".$elemList."0\n6-31g(d)\n****\n".$ecpElemList." 0\nlanl2dz\n****\n\n".$ecpElemList." 0\nlanl2dz\n\n";
  }
  else
  {
    $cmd=sprintf("#p %s B3LYP/6-31g(d) nosym",$optKeyword); # Functional and Basis Set Hard Coded here...
    $basisSetInput="";
  }
  return($cmd,$basisSetInput);
}

sub makeTDcmdTitleAndMulti()
{
  my $TDfunc=shift(@_);
  my $extraOptions=shift(@_);
  my $TDcmd="#p TD=(50-50,nstates=5) $TDfunc/chkbas geom=check guess=read $extraOptions\n\nTD-DFT at previous geom (S0?) using S0 as reference state\n\n$charge $multiplicity\n";
  return  $TDcmd;
}

sub makeUVcmdTitleAndMulti()
{
  my $TDfunc=shift(@_);
  my $extraOptions=shift(@_);
  my $TDcmd="#p TD=(singlets,nstates=30) $TDfunc/chkbas geom=check guess=read $extraOptions\n\nTD-DFT for 30 singlet states at previous geom (S0?) using S0 as reference state\n\n$charge $multiplicity\n";
  return  $TDcmd;
}

sub makeT1Optcmd()
{
  my $extraOptions=shift(@_);
  my $T1Optcmd="#p opt B3LYP/chkbas geom=check SCF=(NoVarAcc,XQC) integral=grid=ultrafine $extraOptions\n\nOpt T1 from previous geom (S0?) \n\n$charge 3\n";
  return  $T1Optcmd;
}

sub makeRedoxcmd()
{
  my $extraOptions=shift(@_);
  my $Redoxcmd="#p opt B3LYP/chkbas geom=check freq $extraOptions\n\nOpt/Freq of Reduced State ($charge2 $multiplicity2) from previous geometry\n\n$charge2 $multiplicity2\n";
  return $Redoxcmd;
}

sub makeSCRFcmd()
{
  my $extraOptions=shift(@_);
  my $SCRFcmd="#p geom=allchk B3LYP/chkbas SCRF=(SMD,solvent=$solvent) $extraOptions\n";
  return $SCRFcmd;
}

sub readCom()
{
  my $infile=shift(@_);
  my @lines;
  my $oldoldline;
  my $oldline;
  my $line;
  my $nlines=0;
  my $firstLineGeom;
  my $charge;
  my $multiplicity;
  my $i;
  my $geom="";
  my $CONNECTIVITY=0; 
  open(INPUT, $infile) || die "Cannot open $infile -- $!\n";
  while(<INPUT>)
  {
    $lines[$nlines]=$_;
    $lines[$nlines]=trim($lines[$nlines])."\n";
#    if($DEBUG) {print "line $nlines: $lines[$nlines]";}
    $nlines++;
  }
  close(INPUT);

 #now look for charge and multiplicity and first line of geometry
 my $FOUNDChargeMulti=0;
 for($i=2;($i<$nlines && $FOUNDChargeMulti==0);$i++)
 {
   $oldoldline=$lines[$i-2];
   $oldline=$lines[$i-1];
   $line=$lines[$i];
   # if oldoldold line is blank, oldline is e.g. 0 1 and line starts with a character (element symbol)
   if(($oldoldline =~ m/^$/) && ($oldline=~ m/^\s*-?\d\s+\d\s*$/) && ($line=~ m/^\w/) && ($line=~ m/^\D/))
   {
     ($charge,$multiplicity) = split('\s+',($oldline));
     $firstLineGeom=$i;
     $FOUNDChargeMulti=1;
   } 
 }
 if($FOUNDChargeMulti==0) {print "Error, can't read charge and multiplicity in $infile, exiting\n"; exit();}

 #now copy geometry lines into geom variable, stopping at last line or 1st --link1-- keyword. 
 my $FOUNDLINK1=0;
 my $FOUNDBASIS=0;
 my $lastLineGeom=$firstLineGeom;
 my @splitline;
 my %nOfSym;
 while($lastLineGeom<$nlines && $FOUNDLINK1==0 && $FOUNDBASIS==0)
 {
   if(($lines[$lastLineGeom]=~ m/^\w/) && ($lines[$lastLineGeom]=~ m/^\D/)) #if line is any word, but not a digid (i.e. a-Z)
   {
     @splitline=split('\s+',($lines[$lastLineGeom]));
     @splitline=split('-',$splitline[0]); 
     $nOfSym{$splitline[0]}+=1;
   }
   $lastLineGeom++;
   if($lines[$lastLineGeom] =~ m/--Link1--/)
   {
     $FOUNDLINK1=1;
   }
   if($lines[$lastLineGeom] =~ m/\*\*\*\*/) #found basis set info at end of geom
   {
     $FOUNDBASIS=1;
     $lastLineGeom=$lastLineGeom-3; #skip this line and 2 previous
   }
   #check for connectivity info
   if($lines[$lastLineGeom] =~ m/^\d+\s+\d+\s+\d./) #eg 1 3 1.0 
   { 
     #if($DEBUG) {print "Found connectivity info!\n";}
     $CONNECTIVITY=1;
   }
 }
 for($i=$firstLineGeom;$i<$lastLineGeom;$i++)
 {
   $geom=$geom.$lines[$i];
 }
 return ($geom,$charge,$multiplicity,$CONNECTIVITY,%nOfSym); 
}

sub makeHeader()
{
  my $USEOLDCHK=0;
  if($#_==3) {$USEOLDCHK=1;}
  my $numProc=shift(@_);
  my $memory=shift(@_);
  my $header="";
  $header=$header."%nprocshared=$numProc\n";
  $header=$header."%mem=$memory\n";

  if($USEOLDCHK)
  {
    my $oldchk=shift(@_);
    $header=$header."%oldchk=$oldchk\n";
  }
  my $chk=shift(@_);
  $header=$header."%chk=$chk\n";
  return $header;
}

# Perl trim function to remove whitespace from the start and end of the string
sub trim($)
{
 my $string = shift;
 $string =~ s/^\s+//;
 $string =~ s/\s+$//;
 return $string;
}

sub checkexists()
{
  my $filename = $_[0];
  my $fileexists = 0;
  if(-s $filename)
  {
    $fileexists = 1;
#    print "FILE $filename found. \n";
  }
  else
  {
    $fileexists = 0;
#    print "File $filename does not exist, exiting \n";
#    exit();
  }
  return $fileexists;
}
sub makeAtomNumHash()
{
  
  $numOfSym{"H"}="1";		# Hydrogen
  $numOfSym{"He"}="2";		# Helium
  $numOfSym{"Li"}="3";		# Lithium
  $numOfSym{"Be"}="4";		# Beryllium
  $numOfSym{"B"}="5";		# Boron
  $numOfSym{"C"}="6";		# Carbon
  $numOfSym{"N"}="7";		# Nitrogen
  $numOfSym{"O"}="8";		# Oxygen
  $numOfSym{"F"}="9";		# Fluorine
  $numOfSym{"Ne"}="10";		# Neon
  $numOfSym{"Na"}="11";		# Sodium
  $numOfSym{"Mg"}="12";		# Magnesium
  $numOfSym{"Al"}="13";		# Aluminum, Aluminium
  $numOfSym{"Si"}="14";		# Silicon
  $numOfSym{"P"}="15";		# Phosphorus
  $numOfSym{"S"}="16";		# Sulfur
  $numOfSym{"Cl"}="17";		# Chlorine
  $numOfSym{"Ar"}="18";		# Argon
  $numOfSym{"K"}="19";		# Potassium
  $numOfSym{"Ca"}="20";		# Calcium
  $numOfSym{"Sc"}="21";		# Scandium
  $numOfSym{"Ti"}="22";		# Titanium
  $numOfSym{"V"}="23";		# Vanadium
  $numOfSym{"Cr"}="24";		# Chromium
  $numOfSym{"Mn"}="25";		# Manganese
  $numOfSym{"Fe"}="26";		# Iron
  $numOfSym{"Co"}="27";		# Cobalt
  $numOfSym{"Ni"}="28";		# Nickel
  $numOfSym{"Cu"}="29";		# Copper
  $numOfSym{"Zn"}="30";		# Zinc
  $numOfSym{"Ga"}="31";		# Gallium
  $numOfSym{"Ge"}="32";		# Germanium
  $numOfSym{"As"}="33";		# Arsenic
  $numOfSym{"Se"}="34";		# Selenium
  $numOfSym{"Br"}="35";		# Bromine
  $numOfSym{"Kr"}="36";		# Krypton
  $numOfSym{"Rb"}="37";		# Rubidium
  $numOfSym{"Sr"}="38";		# Strontium
  $numOfSym{"Y"}="39";		# Yttrium
  $numOfSym{"Zr"}="40";		# Zirconium
  $numOfSym{"Nb"}="41";		# Niobium
  $numOfSym{"Mo"}="42";		# Molybdenum
  $numOfSym{"Tc"}="43";		# Technetium
  $numOfSym{"Ru"}="44";		# Ruthenium
  $numOfSym{"Rh"}="45";		# Rhodium
  $numOfSym{"Pd"}="46";		# Palladium
  $numOfSym{"Ag"}="47";		# Silver
  $numOfSym{"Cd"}="48";		# Cadmium
  $numOfSym{"In"}="49";		# Indium
  $numOfSym{"Sn"}="50";		# Tin
  $numOfSym{"Sb"}="51";		# Antimony
  $numOfSym{"Te"}="52";		# Tellurium
  $numOfSym{"I"}="53";		# Iodine
  $numOfSym{"Xe"}="54";		# Xenon
  $numOfSym{"Cs"}="55";		# Cesium
  $numOfSym{"Ba"}="56";		# Barium
  $numOfSym{"La"}="57";		# Lanthanum
  $numOfSym{"Ce"}="58";		# Cerium
  $numOfSym{"Pr"}="59";		# Praseodymium
  $numOfSym{"Nd"}="60";		# Neodymium
  $numOfSym{"Pm"}="61";		# Promethium
  $numOfSym{"Sm"}="62";		# Samarium
  $numOfSym{"Eu"}="63";		# Europium
  $numOfSym{"Gd"}="64";		# Gadolinium
  $numOfSym{"Tb"}="65";		# Terbium
  $numOfSym{"Dy"}="66";		# Dysprosium
  $numOfSym{"Ho"}="67";		# Holmium
  $numOfSym{"Er"}="68";		# Erbium
  $numOfSym{"Tm"}="69";		# Thulium
  $numOfSym{"Yb"}="70";		# Ytterbium
  $numOfSym{"Lu"}="71";		# Lutetium
  $numOfSym{"Hf"}="72";		# Hafnium
  $numOfSym{"Ta"}="73";		# Tantalum
  $numOfSym{"W"}="74";		# Tungsten
  $numOfSym{"Re"}="75";		# Rhenium
  $numOfSym{"Os"}="76";		# Osmium
  $numOfSym{"Ir"}="77";		# Iridium
  $numOfSym{"Pt"}="78";		# Platinum
  $numOfSym{"Au"}="79";		# Gold
  $numOfSym{"Hg"}="80";		# Mercury
  $numOfSym{"Tl"}="81";		# Thallium
  $numOfSym{"Pb"}="82";		# Lead
  $numOfSym{"Bi"}="83";		# Bismuth
  $numOfSym{"Po"}="84";		# Polonium
  $numOfSym{"At"}="85";		# Astatine
  $numOfSym{"Rn"}="86";		# Radon
  $numOfSym{"Fr"}="87";		# Francium
  $numOfSym{"Ra"}="88";		# Radium
  $numOfSym{"Ac"}="89";		# Actinium
  $numOfSym{"Th"}="90";		# Thorium
  $numOfSym{"Pa"}="91";		# Protactinium
  $numOfSym{"U"}="92";		# Uranium
  $numOfSym{"Np"}="93";		# Neptunium
  $numOfSym{"Pu"}="94";		# Plutonium
  $numOfSym{"Am"}="95";		# Americium
  $numOfSym{"Cm"}="96";		# Curium
  $numOfSym{"Bk"}="97";		# Berkelium
  $numOfSym{"Cf"}="98";		# Californium
  $numOfSym{"Es"}="99";		# Einsteinium
  $numOfSym{"Fm"}="100";		# Fermium
  $numOfSym{"Md"}="101";		# Mendelevium
  $numOfSym{"No"}="102";		# Nobelium
  $numOfSym{"Lr"}="103";		# Lawrencium
  $numOfSym{"Rf"}="104";		# Rutherfordium
  $numOfSym{"Db"}="105";		# Dubnium
  $numOfSym{"Sg"}="106";		# Seaborgium
  $numOfSym{"Bh"}="107";		# Bohrium
  $numOfSym{"Hs"}="108";		# Hassium
  $numOfSym{"Mt"}="109";		# Meitnerium
  $numOfSym{"Ds"}="110";		# Darmstadtium
  $numOfSym{"Rg"}="111";		# Roentgenium
  $numOfSym{"Cn"}="112";		# Copernicium
  $numOfSym{"Uut"}="113";	# Ununtrium
  $numOfSym{"Fl"}="114";		# Flerovium
  $numOfSym{"Uup"}="115";	# Ununpentium
  $numOfSym{"Lv"}="116";		# Livermorium
  $numOfSym{"Uus"}="117";	# Ununseptium
  $numOfSym{"Uuo"}="118";		# Ununoctium

}
sub ReadEps()
{
  foreach my $file ( $epsfile , $inffile ) {
      open ( LIST , $file ) || die "Cannot open $file -- $!" ;
      while ( my $line = <LIST> ) {
           chomp $line ;
           my ( $sol , $value ) = split ' ' , $line ;
           $hash{$file}{$sol} = $value ;
           }
      close LIST ;
  }
  return 1 ;
}
sub Mix()
{
  my %output ; # hash for collecting solvent mix
  my $Vtot = 0 ;
  my $epsout = 0 ;
  my $infout = 0 ;
  my $VRs ;
  my $sols ;
  my $name = "BLANK" ;
  print "Subroutine for solvent entry for solvent=mix\nBlank solvent entry terminates and calculates result\n" ;
  print "Enter first solvent: " ;
  while ( ( my $entry = <STDIN> ) ne "\n" ) {
        chomp $entry ;
        print "[NOTE:- No spaces, please...]\n" if $entry =~ s/\s//g ;  # checks for whitespace and trims for following check
        my $foundentry = 0 ;
        foreach my $sol ( keys %{ $hash{$epsfile} } ) {
            if  ( lc $entry eq lc $sol ) {
                $foundentry = 1 ;
                $output{$sol}[0] = $hash{$epsfile}{$sol} ;
                $output{$sol}[1] = $hash{$inffile}{$sol} ;
                until ( $output{$sol}[2] ) {
                print "Found $sol, enter volume fraction: " ;
                chomp ( $output{$sol}[2] = <STDIN> ) ;
                }
                $Vtot = $Vtot + $output{$sol}[2] ;
            }
        }
        if ($foundentry == 0 ) {
            print "Sorry - can't find $entry\n" ;
            my @option ;
            my $i = 0 ;
            foreach my $sol (keys %{ $hash{$epsfile} } ) {
                if ( $sol =~ /$entry/i ) {
                   $option[$i++] = $sol ;
                }
            }
            print "Similar available solvents: @option\n" ;
        }
        print "Enter next solvent: " ;
  }
  foreach my $sol ( keys %output ) {
          $epsout = $epsout + $output{$sol}[0] * $output{$sol}[2] / $Vtot ;
          $infout = $infout + $output{$sol}[1] * $output{$sol}[2] / $Vtot ;
          $VRs = $VRs.$output{$sol}[2].":" ;
          $sols = $sols.$sol.":" ;
  }
#  print "Custom Solvent parameters:\nEps:    $epsout\nEpsinf: $infout\n" ;
  $VRs =~ s/:$// ;
  $sols =~ s/:$// ;
  $name = $VRs."-".$sols ;
  return ( $name , $epsout , $infout ) ;
}

sub printHelp()
{
  print "-------------------------------------------------------------------------------------\n";
  print "\nWelcome to fixg09inp.pl, a script written by Mike Wykes (mikewykesi\@gmail.com).\n";
  print "Version 1.2.2 - bug fixes and additions by WT (will.tarran\@gmail.com):\n";
  print "Accepts negative charge in input .com and carries through Optimisation charge/multiplicity to TD job.\n";
  print "New jobtypes 7-10 and subroutines for generating custom and standard solvent corrections in jobtype 10\n\n";
  print "This script reads in the geometry from a Gaussian input file and rewrites a new file\n"; 
  print "with Gaussian options appropriate for various job types.\n";
  print "\nThe currently-supported Job types are:\n";
  print "0) Single Point Calculation B3LYP/6-31g(d) with LanL2DZ for heavy atoms [default]\n";
  print "1) B3LYP geom opt only\n";
  print "2) B3LYP geom opt + TD-DFT calc\n";
  print "3) B3LYP geom opt + TD-DFT calc + UB3LYP T1 opt\n";
  print "4) AM1 geom opt + B3LYP geom opt \n";
  print "5) AM1 geom opt + B3LYP geom opt + TD-DFT calc \n";
  print "6) AM1 geom opt + B3LYP geom opt + TD-DFT calc + UB3LYP T1 opt\n";
  print "7) B3LYP geom opt + 2 TD-DFT calculations (B3LYP followed by PBE0)\n";
  print "8) B3LYP geom opt with frequency calculation\n";
  print "9) AM1 geom opt only \n";
  print "10) Multistage job for redox potential and SCRF solvent correction; use -sol to specify solvent";
  print "11) B3LYP geom opt + TD-DFT calc for 30 singlet states - useful for UV spectra\n";
  print "\n";
  print "\nSyntax: fixg09inp.pl -j jobtype [-p nProcs] [-m mem] [-cm charge multiplicity] [-tdfunc functional] [-e \"extra keywords\"] [-opt \"opt=(options)\"] [-sol solvent] inputFiles(s)\n\n";
  print "Optional arguments are enclosed in square brackets []\n";
  print "Solvent use in -j 10:\n";
  print "Default solvent is Water; this is overridden with [-sol solvent]\n";
  print "For solvent entries, script checks against Gaussian available solvents and exits if not found\n" ;
  print "Special cases are [-sol read] and [-sol mix]\n";
  print "-sol read: Prompts for manual entry of \"Eps\" and \"Eps(inf)\" solvent parameters\n" ;
  print "-sol mix: Prompts for entry of any number of solvents with volume fractions and calculates averaged Eps and Eps(inf) values\n" ;
  print "\nE.g.: fixg09inp.pl -j 1 -cm 0 3 -e \"SCF=QC\" -opt \"opt=(maxstep=1)\" mod001.com \n\n";
  print "-------------------------------------------------------------------------------------\n";
  exit;
}
