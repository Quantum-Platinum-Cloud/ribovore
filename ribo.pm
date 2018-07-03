#!/usr/bin/perl
#
# ribo.pm
# Eric Nawrocki
# EPN, Fri May 12 09:48:21 2017
# 
# Perl module used by ribotyper.pl, ribosensor-wrapper.pl and
# ribolengthchecker.pl which contains subroutines called by 
# those scripts.
#
# Functions for output: 
# ribo_OutputBanner:             output the banner with info on the script and options used
# ribo_OutputProgressPrior:     output routine for a step, prior to running the step
# ribo_OutputProgressComplete:  output routine for a step, after the running the step

# Miscellaneous functions:
# ribo_RunCommand:              run a command using system()
# ribo_ValidateExecutableHash: validate executables exist and are executable
# ribo_SecondsSinceEpoch:      number of seconds since the epoch, for timings
use strict;
use warnings;

#####################################################################
# Subroutine: ribo_OutputBanner()
# Incept:     EPN, Thu Oct 30 09:43:56 2014 (rnavore)
# 
# Purpose:    Output the banner with info on the script, input arguments
#             and options used.
#
# Arguments: 
#    $FH:                file handle to print to
#    $package_name:      name of package to output (e.g. 'ribotyper' or 'ribosensor')
#    $version:           version of dnaorg
#    $releasedate:       month/year of version (e.g. "Feb 2016")
#    $synopsis:          string reporting the date
#    $date:              date information to print
#
# Returns:    Nothing, if it returns, everything is valid.
# 
# Dies: never
####################################################################
sub ribo_OutputBanner {
  my $nargs_expected = 6;
  my $sub_name = "ribo_OutputBanner()";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($FH, $package_name, $version, $releasedate, $synopsis, $date) = @_;

  print $FH ("\# $synopsis\n");
  print $FH ("\# $package_name $version ($releasedate)\n");
#  print $FH ("\# Copyright (C) 2014 HHMI Janelia Research Campus\n");
#  print $FH ("\# Freely distributed under the GNU General Public License (GPLv3)\n");
  print $FH ("\# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n");
  if(defined $date)    { print $FH ("# date:    $date\n"); }
  printf $FH ("#\n");

  return;
}

#################################################################
# Subroutine : ribo_OutputProgressPrior()
# Incept:      EPN, Fri Feb 12 17:22:24 2016 [dnaorg.pm]
#
# Purpose:      Output to $FH1 (and possibly $FH2) a message indicating
#               that we're about to do 'something' as explained in
#               $outstr.  
#
#               Caller should call *this* function, then do
#               the 'something', then call output_progress_complete().
#
#               We return the number of seconds since the epoch, which
#               should be passed into the downstream
#               output_progress_complete() call if caller wants to
#               output running time.
#
# Arguments: 
#   $outstr:     string to print to $FH
#   $progress_w: width of progress messages
#   $FH1:        file handle to print to, can be undef
#   $FH2:        another file handle to print to, can be undef
# 
# Returns:     Number of seconds and microseconds since the epoch.
#
################################################################# 
sub ribo_OutputProgressPrior { 
  my $nargs_expected = 4;
  my $sub_name = "ribo_OutputprogressPrior()";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($outstr, $progress_w, $FH1, $FH2) = @_;

  if(defined $FH1) { printf $FH1 ("# %-*s ... ", $progress_w, $outstr); }
  if(defined $FH2) { printf $FH2 ("# %-*s ... ", $progress_w, $outstr); }

  return ribo_SecondsSinceEpoch();
}

#################################################################
# Subroutine : ribo_OutputProgressComplete()
# Incept:      EPN, Fri Feb 12 17:28:19 2016 [dnaorg.pm]
#
# Purpose:     Output to $FH1 (and possibly $FH2) a 
#              message indicating that we've completed 
#              'something'.
#
#              Caller should call *this* function,
#              after both a call to output_progress_prior()
#              and doing the 'something'.
#
#              If $start_secs is defined, we determine the number
#              of seconds the step took, output it, and 
#              return it.
#
# Arguments: 
#   $start_secs:    number of seconds either the step took
#                   (if $secs_is_total) or since the epoch
#                   (if !$secs_is_total)
#   $extra_desc:    extra description text to put after timing
#   $FH1:           file handle to print to, can be undef
#   $FH2:           another file handle to print to, can be undef
# 
# Returns:     Number of seconds the step took (if $secs is defined,
#              else 0)
#
################################################################# 
sub ribo_OutputProgressComplete { 
  my $nargs_expected = 4;
  my $sub_name = "ribo_OutputProgressComplete()";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($start_secs, $extra_desc, $FH1, $FH2) = @_;

  my $total_secs = undef;
  if(defined $start_secs) { 
    $total_secs = ribo_SecondsSinceEpoch() - $start_secs;
  }

  if(defined $FH1) { printf $FH1 ("done."); }
  if(defined $FH2) { printf $FH2 ("done."); }

  if(defined $total_secs || defined $extra_desc) { 
    if(defined $FH1) { printf $FH1 (" ["); }
    if(defined $FH2) { printf $FH2 (" ["); }
  }
  if(defined $total_secs) { 
    if(defined $FH1) { printf $FH1 (sprintf("%.1f seconds%s", $total_secs, (defined $extra_desc) ? ", " : "")); }
    if(defined $FH2) { printf $FH2 (sprintf("%.1f seconds%s", $total_secs, (defined $extra_desc) ? ", " : "")); }
  }
  if(defined $extra_desc) { 
    if(defined $FH1) { printf $FH1 $extra_desc };
    if(defined $FH2) { printf $FH2 $extra_desc };
  }
  if(defined $total_secs || defined $extra_desc) { 
    if(defined $FH1) { printf $FH1 ("]"); }
    if(defined $FH2) { printf $FH2 ("]"); }
  }

  if(defined $FH1) { printf $FH1 ("\n"); }
  if(defined $FH2) { printf $FH2 ("\n"); }
  
  return (defined $total_secs) ? $total_secs : 0.;
}

#################################################################
# Subroutine:  old_ribo_RunCommand()
# Incept:      EPN, Mon Dec 19 10:43:45 2016
#
# Purpose:     Runs a command using system() and exits in error 
#              if the command fails. If $be_verbose, outputs
#              the command to stdout. If $FH_HR->{"cmd"} is
#              defined, outputs command to that file handle.
#
# Arguments:
#   $cmd:         command to run, with a "system" command;
#   $be_verbose:  '1' to output command to stdout before we run it, '0' not to
#
# Returns:    amount of time the command took, in seconds
#
# Dies:       if $cmd fails
#################################################################
sub old_ribo_RunCommand {
  my $sub_name = "ribo_RunCommand()";
  my $nargs_expected = 2;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($cmd, $be_verbose) = @_;
  
  if($be_verbose) { 
    print ("Running cmd: $cmd\n"); 
  }

  my ($seconds, $microseconds) = gettimeofday();
  my $start_time = ($seconds + ($microseconds / 1000000.));

  system($cmd);

  ($seconds, $microseconds) = gettimeofday();
  my $stop_time = ($seconds + ($microseconds / 1000000.));

  if($? != 0) { 
    die "ERROR in $sub_name, the following command failed:\n$cmd\n";
  }

  return ($stop_time - $start_time);
}

#################################################################
# Subroutine:  ribo_RunCommand()
# Incept:      EPN, Mon Dec 19 10:43:45 2016
#
# Purpose:     Runs a command using system() and exits in error 
#              if the command fails. If $be_verbose, outputs
#              the command to stdout. If $FH_HR->{"cmd"} is
#              defined, outputs command to that file handle.
#
# Arguments:
#   $cmd:         command to run, with a "system" command;
#   $be_verbose:  '1' to output command to stdout before we run it, '0' not to
#   $FH_HR:       REF to hash of file handles, including "cmd"
#
# Returns:    amount of time the command took, in seconds
#
# Dies:       if $cmd fails
#################################################################
sub ribo_RunCommand {
  my $sub_name = "ribo_RunCommand()";
  my $nargs_expected = 3;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($cmd, $be_verbose, $FH_HR) = @_;
  
  my $cmd_FH = undef;
  if(defined $FH_HR && defined $FH_HR->{"cmd"}) { 
    $cmd_FH = $FH_HR->{"cmd"};
  }

  if($be_verbose) { 
    print ("Running cmd: $cmd\n"); 
  }

  if(defined $cmd_FH) { 
    print $cmd_FH ("$cmd\n");
  }

  my ($seconds, $microseconds) = gettimeofday();
  my $start_time = ($seconds + ($microseconds / 1000000.));

  system($cmd);

  ($seconds, $microseconds) = gettimeofday();
  my $stop_time = ($seconds + ($microseconds / 1000000.));

  if($? != 0) { 
    ofile_FAIL("ERROR in $sub_name, the following command failed:\n$cmd\n", "RIBO", $?, $FH_HR);
  }

  return ($stop_time - $start_time);
}

#################################################################
# Subroutine : ribo_ValidateExecutableHash()
# Incept:      EPN, Sat Feb 13 06:27:51 2016
#
# Purpose:     Given a reference to a hash in which the 
#              values are paths to executables, validate
#              those files are executable.
#
# Arguments: 
#   $execs_HR: REF to hash, keys are short names to executable
#              e.g. "cmbuild", values are full paths to that
#              executable, e.g. "/usr/local/infernal/1.1.1/bin/cmbuild"
# 
# Returns:     void
#
# Dies:        if one or more executables does not exist#
#
################################################################# 
sub ribo_ValidateExecutableHash { 
  my $nargs_expected = 1;
  my $sub_name = "ribo_ValidateExecutableHash()";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($execs_HR) = (@_);

  my $fail_str = undef;
  foreach my $key (sort keys %{$execs_HR}) { 
    if(! -e $execs_HR->{$key}) { 
      $fail_str .= "\t$execs_HR->{$key} does not exist.\n"; 
    }
    elsif(! -x $execs_HR->{$key}) { 
      $fail_str .= "\t$execs_HR->{$key} exists but is not an executable file.\n"; 
    }
  }
  
  if(defined $fail_str) { 
    die "ERROR in $sub_name(),\n$fail_str"; 
  }

  return;
}

#################################################################
# Subroutine : ribo_ProcessSequenceFile()
# Incept:      EPN, Fri May 12 10:08:47 2017
#
# Purpose:     Use esl-seqstat to get the lengths of all sequences in a
#              FASTA or Stockholm formatted sequence file and fill
#              %{$seqidx_HR} and %{$seqlen_HR} where key is sequence
#              name, and value is index in file or sequence
#              length. Also update %{$width_HR} with maximum length of
#              sequence name (key: "target"), index (key: "index") and
#              length (key: "length").
#              
# Arguments: 
#   $seqstat_exec: path to esl-seqstat executable
#   $seq_file:     sequence file to process
#   $seqstat_file: path to esl-seqstat output to create
#   $seqidx_HR:    ref to hash of sequence indices to fill here
#   $seqlen_HR:    ref to hash of sequence lengths to fill here
#   $width_HR:     ref to hash to fill with max widths (see Purpose), can be undef
#   $opt_HHR:      reference to 2D hash of cmdline options
#   $FH_HR:        REF to hash of file handles, including "cmd"
# 
# Returns:     total number of nucleotides in all sequences read, 
#              fills %{$seqidx_HR}, %{$seqlen_HR}, and 
#              %{$width_HR} (partially)
#
# Dies:        If the sequence file has two sequences with identical names.
#              Error message will list all duplicates.
#              If no sequences were read.
#
################################################################# 
sub ribo_ProcessSequenceFile { 
  my $nargs_expected = 8;
  my $sub_name = "ribo_ProcessSequenceFile()";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($seqstat_exec, $seq_file, $seqstat_file, $seqidx_HR, $seqlen_HR, $width_HR, $opt_HHR, $FH_HR) = (@_);

  ribo_RunCommand($seqstat_exec . " --dna -a $seq_file > $seqstat_file", opt_Get("-v", $opt_HHR), $FH_HR);

  # parse esl-seqstat file to get lengths
  my $max_targetname_length = length("target"); # maximum length of any target name
  my $max_length_length     = length("length"); # maximum length of the string-ized length of any target
  my $nseq                  = 0; # number of sequences read
  my $tot_length = ribo_ParseSeqstatFile($seqstat_file, \$max_targetname_length, \$max_length_length, \$nseq, $seqidx_HR, $seqlen_HR); 

  if(defined $width_HR) { 
    $width_HR->{"target"} = $max_targetname_length;
    $width_HR->{"length"} = $max_length_length;
    $width_HR->{"index"}  = length($nseq);
    if($width_HR->{"index"} < length("#idx")) { $width_HR->{"index"} = length("#idx"); }
  }

  return $tot_length;
}


#################################################################
# Subroutine : ribo_CountAmbiguousNucleotidesInSequenceFile()
# Incept:      EPN, Tue May 29 14:51:35 2018
#
# Purpose:     Use esl-seqstat to determine the number of ambiguous
#              nucleotides in each sequence in a sequence file.
#              
# Arguments: 
#   $seqstat_exec: path to esl-seqstat executable
#   $seq_file:     sequence file to process
#   $seqstat_file: path to esl-seqstat output to create
#   $seqnambig_HR: ref to hash of number of ambiguous nucleotides per sequence, filled here
#   $opt_HHR:      reference to 2D hash of cmdline options
#   $FH_HR:        REF to hash of file handles, including "cmd"
# 
# Returns:     number of sequences with 1 or more ambiguous nucleotides
#              fills %{$seqnambig_HR}.
#
# Dies:        If esl-seqstat call fails
#
################################################################# 
sub ribo_CountAmbiguousNucleotidesInSequenceFile { 
  my $nargs_expected = 6;
  my $sub_name = "ribo_CountAmbiguousNucleotidesInSequenceFile()";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($seqstat_exec, $seq_file, $seqstat_file, $seqnambig_HR, $opt_HHR, $FH_HR) = (@_);

  ribo_RunCommand($seqstat_exec . " --dna --comptbl $seq_file > $seqstat_file", opt_Get("-v", $opt_HHR), $FH_HR);

  # parse esl-seqstat file to get lengths
  return ribo_ParseSeqstatCompTblFile($seqstat_file, $seqnambig_HR);
}


#################################################################
# Subroutine : ribo_ParseSeqstatFile()
# Incept:      EPN, Wed Dec 14 16:16:22 2016
#
# Purpose:     Parse an esl-seqstat -a output file.
#              
# Arguments: 
#   $seqstat_file:            file to parse
#   $max_targetname_length_R: REF to the maximum length of any target name, updated here
#   $max_length_length_R:     REF to the maximum length of string-ized length of any target seq, updated here
#   $nseq_R:                  REF to the number of sequences read, updated here
#   $seqidx_HR:               REF to hash of sequence indices to fill here
#   $seqlen_HR:               REF to hash of sequence lengths to fill here
#
# Returns:     Total number of nucleotides read (summed length of all sequences). 
#              Fills %{$seqidx_HR} and %{$seqlen_HR} and updates 
#              $$max_targetname_length_R, $$max_length_length_R, and $$nseq_R.
# 
# Dies:        If the sequence file has two sequences with identical names.
#              Error message will list all duplicates.
#              If no sequences were read.
#
################################################################# 
sub ribo_ParseSeqstatFile { 
  my $nargs_expected = 6;
  my $sub_name = "ribo_ParseSeqstatFile";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($seqstat_file, $max_targetname_length_R, $max_length_length_R, $nseq_R, $seqidx_HR, $seqlen_HR) = @_;

  open(IN, $seqstat_file) || die "ERROR unable to open esl-seqstat file $seqstat_file for reading";

  my $nread = 0;            # number of sequences read
  my $tot_length = 0;       # summed length of all sequences
  my $targetname_length;    # length of a target name
  my $seqlength_length;     # length (number of digits) of a sequence length
  my $targetname;           # a target name
  my $length;               # length of a target
  my %seqdups_H = ();       # key is a sequence name that exists more than once in seq file, value is number of occurences
  my $at_least_one_dup = 0; # set to 1 if we find any duplicate sequence names

  # parse the seqstat -a output 
  # sequences must have non-empty names (else esl-seqstat call would have failed)
  # lengths must be >= 0 (lengths of 0 are okay)
  while(my $line = <IN>) { 
    # = lcl|dna_BP331_0.3k:467     1232 
    # = lcl|dna_BP331_0.3k:10     1397 
    # = lcl|dna_BP331_0.3k:1052     1414 
    chomp $line;
    #print $line . "\n";
    if($line =~ /^\=\s+(\S+)\s+(\d+)/) { 
      $nread++;
      ($targetname, $length) = ($1, $2);
      if(exists($seqidx_HR->{$targetname})) { 
        if(exists($seqdups_H{$targetname})) { 
          $seqdups_H{$targetname}++;
        }
        else { 
          $seqdups_H{$targetname} = 2;
        }
        $at_least_one_dup = 1;
      }
        
      $seqidx_HR->{$targetname} = $nread;
      $seqlen_HR->{$targetname} = $length;
      $tot_length += $length;

      $targetname_length = length($targetname);
      if($targetname_length > $$max_targetname_length_R) { 
        $$max_targetname_length_R = $targetname_length;
      }

      $seqlength_length  = length($length);
      if($seqlength_length > $$max_length_length_R) { 
        $$max_length_length_R = $seqlength_length;
      }

    }
  }
  close(IN);
  if($nread == 0) { 
    die "ERROR did not read any sequence lengths in esl-seqstat file $seqstat_file, did you use -a option with esl-seqstat";
  }
  if($at_least_one_dup) { 
    my $i = 1;
    my $die_string = "\nERROR, not all sequences in input sequence file have a unique name. They must.\nList of sequences that occur more than once, with number of occurrences:\n";
    foreach $targetname (sort keys %seqdups_H) { 
      $die_string .= "\t($i) $targetname $seqdups_H{$targetname}\n";
      $i++;
    }
    $die_string .= "\n";
    die $die_string;
  }

  $$nseq_R = $nread;

  return $tot_length;
}

#################################################################
# Subroutine : ribo_ParseSeqstatCompTblFile()
# Incept:      EPN, Tue May 29 14:55:18 2018
#
# Purpose:     Parse an esl-seqstat --comptbl output file.
#              
# Arguments: 
#   $seqstat_file:  file to parse
#   $seqnambig_HR:  REF to hash of number of ambiguities in each sequence, to fill here 
#
# Returns:     Total number of sequences with >= 1 ambiguous nucleotide.
# 
# Dies:        Never
#
################################################################# 
sub ribo_ParseSeqstatCompTblFile { 
  my $nargs_expected = 2;
  my $sub_name = "ribo_ParseSeqstatCompTblFile";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($seqstat_file, $seqnambig_HR) = @_;

  open(IN, $seqstat_file) || die "ERROR unable to open esl-seqstat file $seqstat_file for reading";

  my $nread = 0;            # number of sequences read
  my $nread_w_ambig = 0;    # summed length of all sequences
  my $seqname = undef;      # a sequence name
  my $nA;                   # number of As
  my $nC;                   # number of Cs
  my $nG;                   # number of Gs
  my $nT;                   # number of Ts
  my $L;                    # length of the sequence
  my $nambig;               # number of ambiguities           
  my %seqdups_H = ();       # key is a sequence name that exists more than once in seq file, value is number of occurences
  my $at_least_one_dup = 0; # set to 1 if we find any duplicate sequence names

  # parse the seqstat --comptbl output 
  while(my $line = <IN>) { 
    ## Sequence name                Length      A      C      G      T
    ##----------------------------- ------ ------ ------ ------ ------
    #gi|675602128|gb|KJ925573.1|       500    148     98    112    142
    #gi|219812015|gb|FJ552229.1|       796    193    209    244    150
    #gi|675602352|gb|KJ925797.1|       500    149    103    126    122

    chomp $line;
    #print $line . "\n";
    if($line =~ /^(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)$/) { 
      $nread++;
      ($seqname, $L, $nA, $nC, $nG, $nT) = ($1, $2, $3, $4, $5, $6);
      $nambig = $L - ($nA + $nC + $nG + $nT);
      if($nambig > 0) { $nread_w_ambig++; }
      $seqnambig_HR->{$seqname} = $nambig;
    }
    elsif($line !~ m/^\#/) { 
      die "ERROR unable to parse esl-seqstat --comptbl line $line from file $seqstat_file";
    }
  }
  close(IN);

  return $nread_w_ambig;
}

#################################################################
# Subroutine : ribo_CheckIfFileExistsAndIsNonEmpty()
# Incept:      EPN, Thu May  4 09:30:32 2017 [dnaorg.pm:validateFileExistsAndIsNonEmpty]
#
# Purpose:     Check if a file exists and is non-empty. 
#
# Arguments: 
#   $filename:         file that we are checking on
#   $filedesc:         description of file
#   $calling_sub_name: name of calling subroutine (can be undef)
#   $do_die:           '1' if we should die if it does not exist.  
# 
# Returns:     Return '1' if it does and is non empty, '0' if it does
#              not exist, or '-1' if it exists but is empty.
#
# Dies:        If file does not exist or is empty and $do_die is 1.
# 
################################################################# 
sub ribo_CheckIfFileExistsAndIsNonEmpty { 
  my $nargs_expected = 4;
  my $sub_name = "ribo_CheckIfFileExistsAndIsNonEmpty()";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($filename, $filedesc, $calling_sub_name, $do_die) = @_;

  if(! -e $filename) { 
    if($do_die) { 
      die sprintf("ERROR in $sub_name, %sfile $filename%s does not exist.", 
                  (defined $calling_sub_name ? "called by $calling_sub_name," : ""),
                  (defined $filedesc         ? " ($filedesc)" : "")); 
    }
    return 0;
  }
  elsif(! -s $filename) { 
    if($do_die) { 
      die sprintf("ERROR in $sub_name, %sfile $filename%s exists but is empty.", 
                  (defined $calling_sub_name ? "called by $calling_sub_name," : ""),
                  (defined $filedesc         ? " ($filedesc)" : "")); 
    }
    return -1;
  }
  
  return 1;
}

#################################################################
# Subroutine : ribo_SecondsSinceEpoch()
# Incept:      EPN, Sat Feb 13 06:17:03 2016
#
# Purpose:     Return the seconds and microseconds since the 
#              Unix epoch (Jan 1, 1970) using 
#              Time::HiRes::gettimeofday().
#
# Arguments:   NONE
# 
# Returns:     Number of seconds and microseconds
#              since the epoch.
#
################################################################# 
sub ribo_SecondsSinceEpoch { 
  my $nargs_expected = 0;
  my $sub_name = "ribo_SecondsSinceEpoch()";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($seconds, $microseconds) = gettimeofday();
  return ($seconds + ($microseconds / 1000000.));
}

#################################################################
# Subroutine: ribo_GetMonoCharacterString()
# Incept:     EPN, Thu Mar 10 21:02:35 2016 [dnaorg.pm]
#
# Purpose:    Return a string of length $len of repeated instances
#             of the character $char.
#
# Arguments:
#   $len:   desired length of the string to return
#   $char:  desired character
#
# Returns:  A string of $char repeated $len times.
# 
# Dies:     if $len is not a positive integer
#
#################################################################
sub ribo_GetMonoCharacterString {
  my $sub_name = "ribo_GetMonoCharacterString";
  my $nargs_expected = 2;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($len, $char) = @_;

  if(! verify_integer($len)) { 
    die "ERROR in $sub_name, passed in length ($len) is not a non-negative integer";
  }
  if($len < 0) { 
    die "ERROR in $sub_name, passed in length ($len) is a negative integer";
  }
    
  my $ret_str = "";
  for(my $i = 0; $i < $len; $i++) { 
    $ret_str .= $char;
  }

  return $ret_str;
}

#####################################################################
# Subroutine: ribo_GetTimeString()
# Incept:     EPN, Tue May  9 11:09:12 2017 
#             EPN, Tue Jun 16 08:52:08 2009 [ssu-align:ssu.pm:PrintTiming]
# 
# Purpose:    Print a timing in hhhh:mm:ss format.
# 
# Arguments:
# $inseconds: number of seconds
#
# Returns:    Nothing.
# 
####################################################################
sub ribo_GetTimeString { 
    my $nargs_expected = 1;
    my $sub_name = "ribo_GetTimeString()";
    if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
    
    my ($inseconds) = @_;

    my ($i, $hours, $minutes, $seconds, $thours, $tminutes, $tseconds, $ndig_hours);

    $hours = int($inseconds / 3600);
    $inseconds -= ($hours * 3600);
    $minutes = int($inseconds / 60);
    $inseconds -= ($minutes * 60);
    $seconds = $inseconds;
    $thours   = sprintf("%02d", $hours);
    $tminutes = sprintf("%02d", $minutes);
    $ndig_hours = ribo_NumberOfDigits($hours);
    if($ndig_hours < 2) { $ndig_hours = 2; }
    $tseconds = sprintf("%05.2f", $seconds);

    return sprintf("%*s:%2s:%5s  (hh:mm:ss)", $ndig_hours, $thours, $tminutes, $tseconds);
}

#################################################################
# Subroutine : ribo_NumberOfDigits()
# Incept:      EPN, Tue May  9 11:33:50 2017
#              EPN, Fri Nov 13 06:17:25 2009 [ssu-align:ssu.pm:NumberOfDigits()]
# 
# Purpose:     Return the number of digits in a number before
#              the decimal point. (ex: 1234.56 would return 4).
# Arguments:
# $num:        the number
# 
# Returns:     the number of digits before the decimal point
#
################################################################# 
sub ribo_NumberOfDigits { 
    my $nargs_expected = 1;
    my $sub_name = "ribo_NumberOfDigits()";
    if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

    my ($num) = (@_);

    my $ndig = 1; 
    while($num > 10) { $ndig++; $num /= 10.; }

    return $ndig;
}

#################################################################
# Subroutine : ribo_VerifyEnvVariableIsValidDir()
# Incept:      EPN, Wed Oct 25 10:09:28 2017
#
# Purpose:     Verify that the environment variable $envvar exists 
#              and that it is a valid directory. Return directory path.
#              
# Arguments: 
#   $envvar:  environment variable
#
# Returns:    directory path $ENV{'$envvar'}
#
################################################################# 
sub ribo_VerifyEnvVariableIsValidDir
{
  my $nargs_expected = 1;
  my $sub_name = "ribo_VerifyEnvVariableIsValidDir()";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($envvar) = $_[0];

  if(! exists($ENV{"$envvar"})) { 
    die "ERROR, the environment variable $envvar is not set";
  }
  my $envdir = $ENV{"$envvar"};
  if(! (-d $envdir)) { 
    die "ERROR, the directory specified by your environment variable $envvar does not exist.\n"; 
  }    

  return $envdir
}

#################################################################
# Subroutine : ribo_RemoveDirPath()
# Incept:      EPN, Mon Nov  9 14:30:59 2009 [ssu-align]
#
# Purpose:     Given a full path of a file remove the directory path.
#              For example: "foodir/foodir2/foo.stk" becomes "foo.stk".
#
# Arguments: 
#   $fullpath: name of original file
# 
# Returns:     The string $fullpath with dir path removed.
#
################################################################# 
sub ribo_RemoveDirPath {
  my $sub_name = "ribo_RemoveDirPath()";
  my $nargs_expected = 1;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my $fullpath = $_[0];
  
  $fullpath =~ s/^.+\///;

  return $fullpath;
}


#################################################################
# Subroutine : ribo_ConvertFetchedNameToAccVersion()
# Incept:      EPN, Tue May 29 11:12:58 2018
#
# Purpose:     Given a 'fetched' GenBank sequence name, e.g.
#              gi|675602128|gb|KJ925573.1|, convert it to 
#              just accession version.
#
# Arguments: 
#   $fetched_name: name of sequence
#   $do_die:       '1' to die if the $fetch_name doesn't match the 
#                  expected format
#
# Returns: $accver_name: accession version format of the name
#          or $fetched_name if $fetched_name doesn't match 
#          expected format and $do_die is '0'.
# 
# Dies: if $do_die and expected name doesn't match the expected format
#
################################################################# 
sub ribo_ConvertFetchedNameToAccVersion {
  my $sub_name = "ribo_ConvertFetchedNameToAccVersion()";
  my $nargs_expected = 2;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($fetched_name, $do_die) = (@_);
  
  # example: gi|675602128|gb|KJ925573.1|
  my $accver_name = undef;
  if($fetched_name =~ /^gi\|\d+\|\S+\|(\S+\.\d+)\|.*/) { 
    $accver_name = $1;
  }
  else { 
    if($do_die) { 
      die "ERROR, in $sub_name, $fetched_name did not match the expected format for a fetched sequence, expect something like: gi|675602128|gb|KJ925573.1|"; 
    }
    $accver_name = $fetched_name;
  }
     
  return $accver_name;
}

#################################################################
# Subroutine : ribo_ParseRLCModelinfoFile()
# Incept:      EPN, Fri Oct 20 14:17:53 2017
#
# Purpose:     Parse a ribolengthchecker.pl modelinfo file, and 
#              fill information in @{$family_order_AR}, %{$family_modelname_HR}.
# 
#              
# Arguments: 
#   $modelinfo_file:       file to parse
#   $env_ribo_dir:         directory in which CM files should be found, if undef, should be full path
#   $family_order_AR:      reference to array of family names, in order read from file, FILLED HERE
#   $family_modelfile_HR:  reference to hash, key is family name, value is path to model, FILLED HERE 
#   $family_modellen_HR:   reference to hash, key is family name, value is consensus model length, FILLED HERE
#   $family_rtname_HAR     reference to hash, key is family name, value is array of ribotyper model 
#                          names to align with this model, FILLED HERE
# Returns:     void; 
#
################################################################# 
sub ribo_ParseRLCModelinfoFile { 
  my $nargs_expected = 6;
  my $sub_name = "ribo_ParseModelinfoFile";
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($modelinfo_file, $env_ribo_dir, $family_order_AR, $family_modelfile_HR, $family_modellen_HR, $family_rtname_HAR) = @_;

  open(IN, $modelinfo_file) || die "ERROR unable to open model info file $modelinfo_file for reading";

  while(my $line = <IN>) { 
    ## each line has information on 1 family and at least 4 tokens: 
    ## token 1: Name for output files for this family
    ## token 2: CM file name for this familyn
    ## token 3: integer, consensus length for the CM for this family
    ## token 4 to N: names of ribotyper models (e.g. SSU_rRNA_archaea) for which we'll use this model to align
    #SSU.Archaea RF01959.cm SSU_rRNA_archaea
    #SSU.Bacteria RF00177.cm SSU_rRNA_bacteria SSU_rRNA_cyanobacteria
    chomp $line; 
    if($line !~ /^\#/ && $line =~ m/\w/) { 
      $line =~ s/^\s+//; # remove leading whitespace
      $line =~ s/\s+$//; # remove trailing whitespace
      my @el_A = split(/\s+/, $line);
      if(scalar(@el_A) < 4) { 
        die "ERROR in $sub_name, less than 4 tokens found on line $line of $modelinfo_file";  
      }
      my $family    = $el_A[0];
      my $modelfile = $el_A[1];
      my $modellen  = $el_A[2];
      my @rtname_A = ();
      for(my $i = 3; $i < scalar(@el_A); $i++) { 
        push(@rtname_A, $el_A[$i]);
      }
      push(@{$family_order_AR}, $family);
      $family_modelfile_HR->{$family}  = $env_ribo_dir . "/" . $modelfile;
      $family_modellen_HR->{$family}   = $modellen;
      @{$family_rtname_HAR->{$family}} = (@rtname_A);
    }
  }
  close(IN);

  return;
}

###########################################################################
# the next line is critical, a perl module must return a true value
return 1;
###########################################################################

