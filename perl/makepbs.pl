#!/usr/bin/perl 
#############################################################################
#  makeg09pbs
#  mike wykes
#  mikewykes\@gmail.com
#  a script to make a pbs file for g09 using torque PBS. 
#  Various updates buy WT
# Get options
use Switch;

#####################################################################
# If no arguments, print welcome message and instructions
#####################################################################
if ($#ARGV < 0 || $ARGV[0] eq "--help" || $ARGV[0] eq "-h") 
{
  print "\nWelcome to makepbs.pl written by mike wykes (mikewykes\@gmail.com),\n"; 
  print "a script to make a pbs file for a g09 .com input file or an Ampac .dat input file.\n\n";
  print "Use:\nmakepbs.pl input.com/input.dat [-q queuename] [-here] [-FC second inputfile] [-sub]\n\n";
  print "If you provide multiple input files or e.g. *.com, I will make a seperate pbs file for each one.\n";
  print "-here causes chk and log files to be written here instead of on scratch (slows down network)\n\n";
  print "Functionality additions:\n";
  print " -FC is designed for secondary jobs following a frequency calculation; e.g. for second state calculation for Franck-Condon spectra\n";
  print "second input file is submitted only if frequency calculation shows no negative frequencies (WT)\n";
  print " -sub automatically submits all generated .pbs files\n";
  print " -SAS renames points.off to input.off when generating solvent surface plots\n";
  exit;
}

#####################################################################
# Set defaults
#####################################################################

$numProc = 1;
$memory = "1gb";
$queue  = "mainqueue";
$CPOLDCHK=0;
$SCRATCH=1;
$defaultScratch="/CDT/scratch/";
#####################################################################
# Parse arguments
#####################################################################
for($j=0; $j<=$#ARGV; $j++)
{
  switch ($ARGV[$j])
  { 
    case (/\.com$/) 
    { 
      push(@comFiles,$ARGV[$j]);
    }
    case (/\.dat$/) 
    { 
      push(@datFiles,$ARGV[$j]);
    }
    case "-here"
    {
      $SCRATCH = 0;
    }
    case "-q"
    {
      $j++; #next arg is amount of memory
      $queue  = $ARGV[$j];
    }
    case "-FC"
    {
      $freqtest = 1;
      $j++; #next arg is secondary .com file
      $com2  = $ARGV[$j];
      if( $com2 !~ /\.com$/)
      {
        print "ERROR: Secondary file must be .com!\n";
        exit(1);
      }
      print "$com2 will be added as secondary job...\n";
    }
    case "-sub"
    {
      $submit = 1;
    }
    case "-SAS"
    {
      $SAS = 1;
    }
    else
    {
      print "ERROR: Unknown option: $ARGV[$j]\n";
      exit(1);
    }
  }
}

######## Usage Warnings  ########
if($freqtest && $#comFiles != 0)
{
  print "WARNING: $com2 submission will be added to multiple jobs!\n";
}

foreach $inputFile (@comFiles)
{
  
  #####################################################################
  #read com file to find out how many processors, memory and any chkfiles that should be copied
  #####################################################################
  open(INPUT, $inputFile) || die "Cannot open $inputFile -- $!\n";
  $toPrint="";
  $reachedLink0=0; #switch to tell if we have reached link0 of 1st calc
  while(<INPUT>)
  {
    if(/%nprocshared=/)
    {
      $numProc=$_;
      $numProc=trim($numProc);;
      $numProc=~s/%nprocshared=//;
    }
    if(/mem=/)
    {
      $memory=$_;
      $memory=trim($memory);
      $memory=~s/%mem=//;
    }
    if(/#/)
    {
      $reachedLink0=1;
      $link0=$_;
    }
    if(/%oldchk/ && $reachedLink0==0) # the first calculation will read from oldchk, so we need to copy it to scratch! 
    {
      $CPOLDCHK=1;
      $oldchk=$_;
      $oldchk=trim($oldchk);
      $oldchk=~s/%oldchk=//; 
    }
    if(/%chk/ && $reachedLink0==0) # the first calculation might read from chk, so we might need to copy it to scratch! 
    {
      $chk=$_;
      $chk=trim($chk);
      $chk=~s/%chk=//; 
      if(checkexists($chk))
      {
        $CPCHK=1;
      }
    }
    if(/FCHT/) # Franck-Condon jobs require additional checkpoint - trigger warning!
    {
      print "Warning: FC or FCHT jobs require checkpoint file.\nPlease add appropriate cp to .pbs manually!\n"
    }
  }


  #####################################################################
  #open pbs file for writing, name will be same as input file, but with .pbs extension. 
  #####################################################################
  $name = $inputFile;
  $name=~s/\.com//;
  $pbsfile = $name.".pbs";
  
  #####################################################################
  #write pbs file
  #####################################################################
  open OUTPUT,">", $pbsfile;
  
  print OUTPUT "#!/bin/bash\n"; 
  print OUTPUT sprintf("\#\$ -S /bin/bash\t\t\t\t# Select bash as interpreter of this script \n");
  print OUTPUT sprintf("\#\$ -q %s\t\t\t\t# Select the queue\n",$queue);
  print OUTPUT sprintf("\#\$ -cwd\t\t\t\t\t# Change to current working directory\n");
  print OUTPUT sprintf("\#\$ -V\t\t\t\t\t# Export current environment variables to job\n");
  print OUTPUT sprintf("\#\$ -pe smp %s\t\t\t\t# Select the number of processors\n",$numProc);
  print OUTPUT sprintf("\#\$ -j y \t\t\t\t# Option to merge standard error and out\n\n\n");

  print OUTPUT "export GAUSS_SCRDIR=\$TMPDIR\n\n";


  if($SCRATCH)
  {
    $statusScript=$pbsfile;
    $statusScript=~s/.pbs/.jobinfo/;
    print OUTPUT "echo \"#Job running on \${HOSTNAME}:\$TMPDIR-results\" >$statusScript\n";
    print OUTPUT "echo \"ssh \$HOSTNAME \\\"cp \$TMPDIR-results/* \$SGE_O_WORKDIR\\\"\" >>$statusScript\n\n"; 
    print OUTPUT "mkdir \$TMPDIR-results\n";
    print OUTPUT "cp $name.com \$TMPDIR-results\n";
    if($CPOLDCHK)
    {
      print OUTPUT "cp $oldchk \$TMPDIR-results\n";
      $CPOLDCHK = 0;
    } 
    if($CPCHK)
    {
      print OUTPUT "cp $chk \$TMPDIR-results\n";
      $CPCHK = 0;
    } 
    if($freqtest)
    {
      print OUTPUT "cp $com2 \$TMPDIR-results\n";
    }
    print OUTPUT "cd \$TMPDIR-results\n\n";
  }  

  print OUTPUT "g09 $name.com \n\n";

  if($freqtest)
  {
    print OUTPUT "frequency=`grep -m 1 \"Frequencies --\" $name.log | awk '{ split (\$3, array, \".\") ; print array[1] }'`\n";
    print OUTPUT "if [[ \"\$frequency\" -gt \"0\" ]]\n  then g09 $com2\nfi\n\n";
  }
  if ($SAS)
  {
    print OUTPUT "mv points.off $name.off\n" ;
  }
  if($SCRATCH)
  {
    print OUTPUT "cp *.* \$SGE_O_WORKDIR && rm -rf \$TMPDIR-results && rm -rf \$SGE_O_WORKDIR/$statusScript\n";
    print OUTPUT "echo \"\$SGE_O_WORKDIR/$pbsfile complete at `date`\" >> /CDT/shared/qc/\$USER.jobs\n";
  }    
  close(OUTPUT);
  print "\nWritten pbs file to $pbsfile \n\n";
  push @output , $pbsfile;
}

foreach $inputFile (@datFiles)
{
  $queue="ampac"; 
  #####################################################################
  #Ampac is not parallel, so use with only one processor 
  #####################################################################
  $numProc=1;

  #####################################################################
  #open pbs file for writing, name will be same as input file, but with .pbs extension. 
  #####################################################################
  $name = $inputFile;
  $name=~s/\.dat//;
  $pbsfile = $name.".pbs";
  
  #####################################################################
  #write pbs file
  #####################################################################
  open OUTPUT,">", $pbsfile;
  
  print OUTPUT "#!/bin/bash\n"; 
  print OUTPUT sprintf("\#\$ -S /bin/bash\t\t\t\t# Select bash as interpreter of this script \n");
  print OUTPUT sprintf("\#\$ -q %s\t\t\t\t# Select the queue\n",$queue);
  print OUTPUT sprintf("\#\$ -cwd\t\t\t\t\t# Change to current working directory\n");
  print OUTPUT sprintf("\#\$ -V\t\t\t\t\t# Export current environment variables to job\n");
  print OUTPUT sprintf("\#\$ -pe smp %s\t\t\t\t# Select the number of processors\n",$numProc);
  print OUTPUT sprintf("\#\$ -j y \t\t\t\t# Option to merge standard error and out\n\n\n");

  if($SCRATCH)
  {
    $statusScript=$pbsfile;
    $statusScript=~s/.pbs/.jobinfo/;
    print OUTPUT "echo \"#Job running on \${HOSTNAME}:\$TMPDIR-results\" >$statusScript\n";
    print OUTPUT "echo \"ssh \$HOSTNAME \\\"cp \$TMPDIR-results/* \$SGE_O_WORKDIR\\\"\" >>$statusScript\n\n"; 
    print OUTPUT "mkdir \$TMPDIR-results\n";
    print OUTPUT "cp $name.dat \$TMPDIR-results\n";
    print OUTPUT "cd \$TMPDIR-results\n\n";
  }  
  print OUTPUT "ampac -fg $name.dat \n\n";

  if($SCRATCH)
  {
    print OUTPUT "cp *.* \$SGE_O_WORKDIR && rm -rf \$TMPDIR-results && rm -rf \$SGE_O_WORKDIR/$statusScript\n";
    print OUTPUT "echo \"\$SGE_O_WORKDIR/$pbsfile complete at `date`\" >> /CDT/shared/qc/\$USER.jobs\n";
  }    
  close(OUTPUT);
  print "\nWritten pbs file to $pbsfile \n\n";
  push @output , $pbsfile;
}

###### Submission of files with -sub ########

if ($submit)
  {
    foreach $sub (@output)
    {
      print "Submitting $sub...\n";
      system("qsub", "$sub");
    }
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

