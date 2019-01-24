#!/usr/bin/perl
use Switch;

if ($#ARGV < 0)
{
  printHelp();
}

####################################
#  Parse argumemts
####################################

for($j=0; $j<=$#ARGV; $j++)
{
  switch ($ARGV[$j])
  {
     case (/\.log$/)
     {
       push(@logfiles,$ARGV[$j]);
     }
     else 
     {
        print "Error: Unknown option: $ARGV[$j]\n";
        exit(1);
     }
   }
}

#################################################
####### Find Spectrum and remove remainder ######
#################################################

foreach $input (@logfiles)
{
  print "Reading $input\n";
  $nline=0;
  open (INPUT, $input) or die("Cannot open $input : $!");
  while (<INPUT>)
  {
    $file[$nline]=$_;
    $nline++;
  }
  close (INPUT) || warn "Cannot close file: $!";

  ### Check for Spectrum section ###
  if ( "@file" !~ /Final Spectrum/ )
  {
    print "No Spectrum Found!\n";
    printHelp();
  }
  ### Ditch Leader elements up to Spectrum ######
  $switch=0;
  while ( $switch==0 )
  {
    if ( $file[0] !~ /Final Spectrum/ )
    {
      shift @file;
    }
    else
    {
      $switch=1;
    }
   }

  ### Ditch Tail elements Back to Density Matrix ######

  if ( "@file" =~ /Tau Prime/ )
  {
     while ( $switch==1 )
     {
       if ( $file[$#file] !~ /Tau Prime/ )
       {
         pop @file;
       }
       else
       {
         pop @file;
         pop @file;
         pop @file;
         $switch=2;
       }
      }
   }
   else
   {
   print "Warning: End of spectrum block not found.  Tail not ditched\n";
   }

  ##### Exchange 0.000000D+00 format for 0.000000E+00 #####

  for($j=0; $j<=$#file; $j++)
  { if ( $file[$j] =~ /D[+-]\d\d$/)
    {
      $file[$j] =~ s/D/E/ ;
    }
  }

  ##### Print to file ######

  $output=$input;
  $output=~s/\.log/-spectrum\.txt/g;
  print "Writing $output\n";
  open (OUTPUT, ">", $output);
  unshift @file, "Data pulled from $input\n";
  print OUTPUT @file;
  close (OUTPUT) || warn "close failed: $!";
}

exit(0);

sub printHelp()
{
  print "\nThis script retrieves Absoption or emission spectrum from a Gaussian09 .log file\n";
  print "and outputs a .txt file with this data.\n\n";
  print "Note: This data is only present in freq=FC or freq=(FC,emission) jobs\n";
  exit(0);
}
