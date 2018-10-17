#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use Time::HiRes qw(gettimeofday);

require "epn-options.pm";
require "epn-ofile.pm";
require "ribo.pm";

# make sure the RIBODIR and RIBOEASEL variables are set, others we will wait to see
# if they are required first
my $env_ribotyper_dir     = ribo_VerifyEnvVariableIsValidDir("RIBODIR");
my $env_riboeasel_dir     = ribo_VerifyEnvVariableIsValidDir("RIBOEASELDIR");
my $env_vecplus_dir       = undef;
my $env_ribotax_dir       = undef;
my $env_riboblast_dir     = undef;
my $df_model_dir          = $env_ribotyper_dir . "/models/";

#########################################################
# Command line and option processing using epn-options.pm
#
# opt_HH: 2D hash:
#         1D key: option name (e.g. "-h")
#         2D key: string denoting type of information 
#                 (one of "type", "default", "group", "requires", "incompatible", "preamble", "help")
#         value:  string explaining 2D key:
#                 "type":         "boolean", "string", "integer" or "real"
#                 "default":      default value for option
#                 "group":        integer denoting group number this option belongs to
#                 "requires":     string of 0 or more other options this option requires to work, each separated by a ','
#                 "incompatible": string of 0 or more other options this option is incompatible with, each separated by a ','
#                 "preamble":     string describing option for preamble section (beginning of output from script)
#                 "help":         string describing option for help section (printed if -h used)
#                 "setby":        '1' if option set by the user, else 'undef'
#                 "value":        value for option, can be undef if default is undef
#
# opt_order_A: array of options in the order they should be processed
# 
# opt_group_desc_H: key: group number (integer), value: description of group for help output
my %opt_HH = ();      
my @opt_order_A = (); 
my %opt_group_desc_H = ();
my $g = 0;
# Add all options to %opt_HH and @opt_order_A.
# This section needs to be kept in sync (manually) with the &GetOptions call below
$opt_group_desc_H{++$g} = "basic options";
#     option            type       default               group   requires incompat     preamble-output                                              help-output    
opt_Add("-h",           "boolean", 0,                        0,    undef, undef,       undef,                                                       "display this help",                                            \%opt_HH, \@opt_order_A);
opt_Add("-f",           "boolean", 0,                       $g,    undef, undef,       "forcing directory overwrite",                               "force; if <output directory> exists, overwrite it",            \%opt_HH, \@opt_order_A);
opt_Add("-v",           "boolean", 0,                       $g,    undef, undef,       "be verbose",                                                "be verbose; output commands to stdout as they're run",         \%opt_HH, \@opt_order_A);
opt_Add("-n",           "integer", 1,                       $g,    undef, "-p",        "use <n> CPUs",                                              "use <n> CPUs",                                                 \%opt_HH, \@opt_order_A);
opt_Add("--keep",       "boolean", 0,                       $g,    undef, undef,       "keep all intermediate files",                               "keep all intermediate files that are removed by default",      \%opt_HH, \@opt_order_A);
opt_Add("--special",    "string",  undef,                   $g,    undef, undef,       "read list of special species taxids from <s>",              "read list of special species taxids from <s>",                 \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "options for skipping stages";
#               option  type       default               group   requires                incompat   preamble-output                                                     help-output    
opt_Add("--skipfambig", "boolean", 0,                       $g,    undef,                   undef,  "skip stage that filters based on ambiguous nucleotides",           "skip stage that filters based on ambiguous nucleotides",           \%opt_HH, \@opt_order_A);
opt_Add("--skipftaxid", "boolean", 0,                       $g,    undef,                   undef,  "skip stage that filters by taxid",                                 "skip stage that filters by taxid",                                 \%opt_HH, \@opt_order_A);
opt_Add("--skipfvecsc", "boolean", 0,                       $g,    undef,                   undef,  "skip stage that filters based on VecScreen",                       "skip stage that filters based on VecScreen",                       \%opt_HH, \@opt_order_A);
opt_Add("--skipfblast", "boolean", 0,                       $g,    undef,                   undef,  "skip stage that filters based on BLAST hits to self",              "skip stage that filters based on BLAST hits to self",              \%opt_HH, \@opt_order_A);
opt_Add("--skipfribo1", "boolean", 0,                       $g,    undef,                   undef,  "skip 1st stage that filters based on ribotyper",                   "skip 1st stage that filters based on ribotyper",                   \%opt_HH, \@opt_order_A);
opt_Add("--skipfribo2", "boolean", 0,                       $g,"--skipfmspan,--skipingrup,--skipclustr", undef,  "skip 2nd stage that filters based on ribotyper/riboaligner", "skip 2nd stage that filters based on ribotyper/riboaligner", \%opt_HH, \@opt_order_A);
opt_Add("--skipfmspan", "boolean", 0,                       $g,    undef,                   undef,  "skip stage that filters based on model span of hits",              "skip stage that filters based on model span of hits",              \%opt_HH, \@opt_order_A);
opt_Add("--skipingrup", "boolean", 0,                       $g,    undef,                   undef,  "skip stage that filters based on ingroup analysis",                "skip stage that performs ingroup analysis",                        \%opt_HH, \@opt_order_A);
opt_Add("--skipclustr", "boolean", 0,                       $g,    undef,                   undef,  "skip stage that clusters surviving sequences",                     "skip stage that clusters sequences surviving all filters",         \%opt_HH, \@opt_order_A);
opt_Add("--skiplistms", "boolean", 0,                       $g,    undef,                   undef,  "skip stage that lists missing taxids",                             "skip stage that lists missing taxids",                             \%opt_HH, \@opt_order_A);
opt_Add("--skipmstbl",  "boolean", 0,                       $g,    undef,                   undef,  "skip stage that outputs model span tables",                        "skip stage that outputs model span tables",                         \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "options for controlling the stage that filters based on ambiguous nucleotides";
#              option   type       default               group  requires incompat      preamble-output                                            help-output    
opt_Add("--famaxn",  "integer", 5,                       $g,    undef,"--skipfambig",  "set maximum number of allowed ambiguous nts to <n>",      "set maximum number of allowed ambiguous nts to <n>",           \%opt_HH, \@opt_order_A);
opt_Add("--famaxf",  "real",    0.005,                   $g,    undef,"--skipfambig",  "set maximum fraction of of allowed ambiguous nts to <x>", "set maximum fraction of allowed ambiguous nts to <x>",         \%opt_HH, \@opt_order_A);
opt_Add("--faonlyn", "boolean",    0,                    $g,    undef,"--skipfambig,--famaxf,--faonlyf", "enforce only max number of ambiguous nts",        "enforce only max number of ambiguous nts",        \%opt_HH, \@opt_order_A);
opt_Add("--faonlyf", "boolean",    0,                    $g,    undef,"--skipfambig,--famaxn,--faonlyn", "enforce only max fraction of ambiguous nts",      "enforce only max fraction of ambiguous nts",        \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "options for controlling the stage that filters by taxid";
#              option   type       default               group  requires incompat         preamble-output                                                       help-output    
opt_Add("--ftstrict",   "boolean", 0,                       $g,    undef,"--skipftaxid",  "require all taxids for sequences exist in input NCBI taxonomy tree", "require all taxids for sequences exist in input NCBI taxonomy tree", \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "options for controlling the stage that filters based on self-BLAST hits";
#              option    type        default  group requires     incompat              preamble-output                                                  help-output    
opt_Add("--fbcsize",    "integer",   20,        $g, undef, "--skipfblast",             "set num seqs for each BLAST run to <n>",                      "set num seqs for each BLAST run to <n>",                          \%opt_HH, \@opt_order_A);
opt_Add("--fbcall",     "boolean",   0,         $g, undef, "--skipfblast",             "do single BLAST run with all N seqs",                         "do single BLAST run with all N seqs (CAUTION: slow for large N)", \%opt_HH, \@opt_order_A);
opt_Add("--fbword",     "integer",   20,        $g, undef, "--skipfblast",             "set word_size for BLAST to <n>",                              "set word_size for BLAST to <n>",                                  \%opt_HH, \@opt_order_A);
opt_Add("--fbevalue",   "real",      1,         $g, undef, "--skipfblast",             "set BLAST E-value cutoff to <x>",                             "set BLAST E-value cutoff to <x>",                                 \%opt_HH, \@opt_order_A);
opt_Add("--fbdbsize",   "integer",   200000000, $g, undef, "--skipfblast",             "set BLAST dbsize value to <n>",                               "set BLAST dbsize value to <n>",                                   \%opt_HH, \@opt_order_A);
opt_Add("--fbnominus",  "boolean",   0,         $g, undef, "--skipfblast",             "do not consider BLAST self hits to minus strand",             "do not consider BLAST self hits to minus strand",                 \%opt_HH, \@opt_order_A);
opt_Add("--fbmdiagok",  "boolean",   0,         $g, undef, "--skipfblast,--fbnominus", "consider on-diagonal BLAST self hits to minus strand",        "consider on-diagonal BLAST self hits to minus strand",            \%opt_HH, \@opt_order_A);
opt_Add("--fbminuslen", "integer",   50,        $g, undef, "--skipfblast,--fbnominus", "minimum length of BLAST self hit to minus strand is <n>",     "minimum length of BLAST self hit to minus strand is <n>",         \%opt_HH, \@opt_order_A);
opt_Add("--fbminuspid", "real",      95.0,      $g, undef, "--skipfblast,--fbnominus", "minimum percent id of BLAST self hit to minus strand is <x>", "minimum percent id of BLAST self hit to minus strand is <x>",     \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "options for controlling both ribotyper/riboaligner stages";
#       option          type       default               group  requires  incompat        preamble-output                                                 help-output    
opt_Add("--model",      "string",  undef,                   $g,    undef, undef,          "model to use is <s>",                                          "model to use is <s> (e.g. SSU.Eukarya)",                       \%opt_HH, \@opt_order_A);
opt_Add("--noscfail",   "boolean", 0,                       $g,    undef, undef,          "do not fail sequences in ribotyper with low scores",           "do not fail sequences in ribotyper with low scores", \%opt_HH, \@opt_order_A);
opt_Add("--lowppossc",  "real",    0.50,                    $g,    undef, undef,          "set --lowppossc <x> option for ribotyper to <x>",               "set --lowppossc <x> option for ribotyper to <x>", \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "options for controlling the first stage that filters based on ribotyper";
#       option          type       default               group  requires  incompat        preamble-output                                                 help-output    
opt_Add("--riboopts1",  "string",  undef,                   $g,    undef, "--skipfribo1", "use ribotyper options listed in <s> for round 1",              "use ribotyper options listed in <s>", \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "options for controlling the second stage that filters based on ribotyper/riboaligner";
#       option          type       default        group       requires incompat         preamble-output                                                 help-output    
opt_Add("--rainfo",    "string",  undef,            $g,        undef, "--skipfribo2",   "use ra model info file <s> instead of default",               "use riboaligner.pl model info file <s> instead of default", \%opt_HH, \@opt_order_A);
opt_Add("--nomultfail", "boolean", 0,                $g,        undef, "--skipfribo2",  "do not fail sequences in ribotyper with multiple hits",        "do not fail sequences in ribotyper with multiple hits", \%opt_HH, \@opt_order_A);
opt_Add("--nocovfail",  "boolean", 0,                $g,        undef, "--skipfribo2",  "do not fail sequences in ribotyper with low coverage",         "do not fail sequences in ribotyper with low coverage", \%opt_HH, \@opt_order_A);
opt_Add("--nodifffail", "boolean", 0,                $g,        undef, "--skipfribo2",  "do not fail sequences in ribotyper with low score difference", "do not fail sequences in ribotyper with low score difference", \%opt_HH, \@opt_order_A);
opt_Add("--tcov",       "real",    0.99,             $g,        undef, "--skipfribo2",  "set --tcov <x> option for ribotyper to <x>",                    "set --tcov <x> option for ribotyper to <x>", \%opt_HH, \@opt_order_A);
opt_Add("--ribo2hmm",   "boolean", 0,                $g,"--skipfribo1", "--skipfribo2", "run ribotyper stage 2 in HMM-only mode (do not use --2slow)",  "run ribotyper stage 2 in HMM-only mode (do not use --2slow)", \%opt_HH, \@opt_order_A);
opt_Add("--riboopts2",  "string",  undef,            $g,        undef, "--skipfribo2",  "use ribotyper options listed in <s>",                          "use ribotyper options listed in <s>", \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "options for controlling the stage that filters based on model span of hits:";
#       option           type        default             group  requires  incompat                 preamble-output                                          help-output    
opt_Add("--fmpos",       "integer",  60,                   $g,    undef, "--skipfmspan",           "aligned sequences must span from <n> to L - <n> + 1",   "aligned sequences must span from <n> to L - <n> + 1 for model of length L", \%opt_HH, \@opt_order_A);
opt_Add("--fmlpos",      "integer",  undef,                $g,  "--fmrpos","--skipfmspan,--fmpos", "aligned sequences must begin at or 5' of position <n>", "aligned sequences must begin at or 5' of position <n>", \%opt_HH, \@opt_order_A);
opt_Add("--fmrpos",      "integer",  undef,                $g,  "--fmlpos","--skipfmspan,--fmpos", "aligned sequences must end at or 3' of position <n>",   "aligned sequences must end at or 3' of position <n>", \%opt_HH, \@opt_order_A);
opt_Add("--fmnogap",     "boolean",  0,                    $g,    undef, "--skipfmspan",           "require sequences do not have a gap at lpos and rpos",  "require sequences do not have a gap at lpos and rpos", \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "options for controlling clustering stage:";
#       option           type        default             group  requires  incompat                   preamble-output                                     help-output    
opt_Add("--cfid",        "real",     0.97,                  $g,    undef, "--skipclustr",            "set esl-cluster fractional identity to cluster at to <x>", "set esl-cluster fractional identity to cluster at to <x>", \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "options that affect the alignment from which percent identities are calculated:";
#            option         type   default            group   requires  incompat              preamble-output                                                 help-output    
opt_Add("--fullaln",   "boolean",  0,                    $g,     undef, undef,                "do not trim alnment to min reqd span before pid calcs",        "do not trim alignment to minimum required span before pid calculations", \%opt_HH, \@opt_order_A);
opt_Add("--noprob",    "boolean",  0,                    $g,    undef,  undef,                "do not trim alnment based on post probs before pid calcs",     "do not trim alignment based on post probs before pid calculations", \%opt_HH, \@opt_order_A);
opt_Add("--pthresh",   "real",     0.95,                 $g,    undef,"--noprob",             "posterior probability threshold for alnment trimming is <x>",  "posterior probability threshold for alnment trimming is <x>", \%opt_HH, \@opt_order_A);
opt_Add("--pfract",   "real",      0.95,                 $g,    undef,"--noprob",             "seq fraction threshold for post prob alnment trimming is <x>", "seq fraction threshold for post prob alnment trimming is <x>", \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "options for reducing the number of passing sequences per taxid:";
#       option           type        default             group  requires  incompat              preamble-output                                               help-output    
opt_Add("--fione",       "boolean",  0,                     $g,    undef, "--skipingrup",       "only allow 1 sequence per (species) taxid to survive ingroup filter",  "only allow 1 sequence per (species) taxid to survive ingroup filter", \%opt_HH, \@opt_order_A);
opt_Add("--fimin",       "integer",  1,                     $g,"--fione", "--skipingrup",       "w/--fione, remove all sequences from species with < <n> sequences",    "w/--fione, remove all sequences from species with < <n> sequences", \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "options for controlling model span survival table output file:";
#       option          type       default        group       requires incompat                            preamble-output                                                 help-output    
opt_Add("--msstep",     "integer", 10,            $g,         undef, "--skipfribo2,--skipmstbl",           "for model span output table, set step size to <n>",            "for model span output table, set step size to <n>", \%opt_HH, \@opt_order_A);
opt_Add("--msminlen",   "integer", 200,           $g,         undef, "--skipfribo2,--skipmstbl",           "for model span output table, set min length span to <n>",      "for model span output table, set min length span to <n>", \%opt_HH, \@opt_order_A);
opt_Add("--msminstart", "integer", undef,         $g,         undef, "--skipfribo2,--skipmstbl",           "for model span output table, set min start position to <n>",   "for model span output table, set min start position to <n>", \%opt_HH, \@opt_order_A);
opt_Add("--msmaxstart", "integer", undef,         $g,         undef, "--skipfribo2,--skipmstbl",           "for model span output table, set max start position to <n>",   "for model span output table, set max start position to <n>", \%opt_HH, \@opt_order_A);
opt_Add("--msminstop",  "integer", undef,         $g,         undef, "--skipfribo2,--skipmstbl",           "for model span output table, set min stop position to <n>",    "for model span output table, set min stop position to <n>", \%opt_HH, \@opt_order_A);
opt_Add("--msmaxstop",  "integer", undef,         $g,         undef, "--skipfribo2,--skipmstbl",           "for model span output table, set max stop position to <n>",    "for model span output table, set max stop position to <n>", \%opt_HH, \@opt_order_A);
opt_Add("--mslist",     "string",  undef,         $g,         undef, "--skipfribo2,--skipmstbl",           "re-sort model span table to prioritize taxids in file <s>",    "re-sort model span table to prioritize taxids (orders) in file <s>", \%opt_HH, \@opt_order_A);
opt_Add("--msclass",    "boolean", 0,             $g,    "--mslist", "--skipfribo2,--skipmstbl",           "w/--mslist, taxids in --mslist file are classes not orders",   "w/--mslist, taxids in --mslist file are classes not orders", \%opt_HH, \@opt_order_A);
opt_Add("--msphylum",   "boolean", 0,             $g,    "--mslist", "--skipfribo2,--skipmstbl,--msclass", "w/--mslist, taxids in --mslist file are phyla not orders",     "w/--mslist, taxids in --mslist file are phyla not orders", \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "options for changing sequence descriptions (deflines):";
#       option           type        default             group  requires  incompat              preamble-output                                     help-output    
opt_Add("--def",         "boolean",  0,                     $g, undef, "--skipftaxid,--skipfribo2,--prvcmd", "standardize sequence descriptions/deflines",       "standardize sequence descriptions/deflines", \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "options for parallelizing ribotyper/riboaligner's calls to cmsearch and cmalign on a compute farm";
#     option            type       default                group   requires incompat    preamble-output                                                help-output    
opt_Add("-p",           "boolean", 0,                        $g,    undef, undef,      "parallelize cmsearch/cmalign on a compute farm",              "parallelize cmsearch on a compute farm",    \%opt_HH, \@opt_order_A);
opt_Add("-q",           "string",  undef,                    $g,     "-p", undef,      "use qsub info file <s> instead of default",                   "use qsub info file <s> instead of default", \%opt_HH, \@opt_order_A);
opt_Add("--nkb",        "integer", 10,                       $g,     "-p", undef,      "number of KB of seq for each farm job is <n>",                "number of KB of sequence for each farm job is <n>",  \%opt_HH, \@opt_order_A);
opt_Add("--wait",       "integer", 1440,                     $g,     "-p", undef,      "allow <n> minutes for jobs on farm",                          "allow <n> wall-clock minutes for jobs on farm to finish, including queueing time", \%opt_HH, \@opt_order_A);
opt_Add("--errcheck",   "boolean", 0,                        $g,     "-p", undef,      "consider any farm stderr output as indicating a job failure", "consider any farm stderr output as indicating a job failure", \%opt_HH, \@opt_order_A);

$opt_group_desc_H{++$g} = "advanced options for debugging and testing:";
#       option           type        default             group  requires  incompat              preamble-output                                                      help-output    
opt_Add("--prvcmd",      "boolean",  0,                     $g,    undef, "-f,-p",              "do not execute commands; use output from previous run",             "do not execute commands; use output from previous run", \%opt_HH, \@opt_order_A);

# This section needs to be kept in sync (manually) with the opt_Add() section above
my %GetOptions_H = ();
my $usage    = "Usage: ribodbmaker.pl [-options] <input fasta sequence file> <output directory>\n";
$usage      .= "\n";
my $synopsis = "ribodbmaker.pl :: create representative database of ribosomal RNA sequences";
my $options_okay = 
    &GetOptions('h'            => \$GetOptions_H{"-h"}, 
                'f'            => \$GetOptions_H{"-f"},
                'n=s'          => \$GetOptions_H{"-n"},
                'v'            => \$GetOptions_H{"-v"},
                'fasta=s'      => \$GetOptions_H{"--fasta"},
                'keep'         => \$GetOptions_H{"--keep"},
                'special=s'    => \$GetOptions_H{"--special"},
                'skipftaxid'   => \$GetOptions_H{"--skipftaxid"},
                'skipfambig'   => \$GetOptions_H{"--skipfambig"},
                'skipfvecsc'   => \$GetOptions_H{"--skipfvecsc"},
                'skipfblast'   => \$GetOptions_H{"--skipfblast"},
                'skipfribo1'   => \$GetOptions_H{"--skipfribo1"},
                'skipfribo2'   => \$GetOptions_H{"--skipfribo2"},
                'skipfmspan'   => \$GetOptions_H{"--skipfmspan"},
                'skipingrup'   => \$GetOptions_H{"--skipingrup"},
                'skipclustr'   => \$GetOptions_H{"--skipclustr"},
                'skiplistms'   => \$GetOptions_H{"--skiplistms"},
                'skipmstbl'    => \$GetOptions_H{"--skipmstbl"},
                'famaxn=s'     => \$GetOptions_H{"--famaxn"},
                'famaxf=s'     => \$GetOptions_H{"--famaxf"},
                'faonlyn'      => \$GetOptions_H{"--faonlyn"},
                'faonlyf'      => \$GetOptions_H{"--faonlyf"},
                'ftstrict'     => \$GetOptions_H{"--ftstrict"},
                'fbcsize=s'    => \$GetOptions_H{"--fbcsize"},
                'fbcall'       => \$GetOptions_H{"--fbcall"},
                'fbword=s'     => \$GetOptions_H{"--fbword"},
                'fbevalue=s'   => \$GetOptions_H{"--fbevalue"},
                'fbdbsize=s'   => \$GetOptions_H{"--fbdbsize"},
                'fbnominus'    => \$GetOptions_H{"--fbnominus"},
                'fbmdiagok'    => \$GetOptions_H{"--fbmdiagok"},
                'fbminuslen=s' => \$GetOptions_H{"--fbminuslen"},
                'fbminuspid=s' => \$GetOptions_H{"--fbminuspid"},
                'model=s'      => \$GetOptions_H{"--model"},
                'nomultfail'   => \$GetOptions_H{"--nomultfail"},
                'noscfail'     => \$GetOptions_H{"--noscfail"},
                'nocovfail'    => \$GetOptions_H{"--nocovfail"},
                'nodifffail'   => \$GetOptions_H{"--nodifffail"},
                'lowpposs=s'   => \$GetOptions_H{"--lowppossc"},
                'tcov=s'       => \$GetOptions_H{"--tcov"},
                'riboopts1=s'  => \$GetOptions_H{"--riboopts1"},
                'rainfo=s'     => \$GetOptions_H{"--rainfo"},
                'ribo2hmm'     => \$GetOptions_H{"--ribo2hmm"},
                'riboopts2=s'  => \$GetOptions_H{"--riboopts2"},
                'cfid'         => \$GetOptions_H{"--cfid"},
                "fullaln"      => \$GetOptions_H{"--fullaln"},
                "noprob"       => \$GetOptions_H{"--noprob"},
                "pthresh=s"    => \$GetOptions_H{"--pthresh"},
                "pfract=s"     => \$GetOptions_H{"--pfract"},
                'fmpos=s'      => \$GetOptions_H{"--fmpos"},
                'fmlpos=s'     => \$GetOptions_H{"--fmlpos"},
                'fmrpos=s'     => \$GetOptions_H{"--fmrpos"},
                'fmnogap'      => \$GetOptions_H{"--fmnogap"},
                'fione'        => \$GetOptions_H{"--fione"},
                'fimin'        => \$GetOptions_H{"--fimin"},
                'msstep=s'     => \$GetOptions_H{"--msstep"},
                'msminlen=s'   => \$GetOptions_H{"--msminlen"},
                'msminstart=s' => \$GetOptions_H{"--msminstart"},
                'msmaxstart=s' => \$GetOptions_H{"--msmaxstart"},
                'msminstop=s'  => \$GetOptions_H{"--msminstop"},
                'msmaxstop=s'  => \$GetOptions_H{"--msmaxstop"},
                'mslist=s'     => \$GetOptions_H{"--mslist"},
                'msclass'      => \$GetOptions_H{"--msclass"},
                'msphylum'     => \$GetOptions_H{"--msphylum"},
                'def'          => \$GetOptions_H{"--def"},
# options for parallelization
                'p'            => \$GetOptions_H{"-p"},
                'q=s'          => \$GetOptions_H{"-q"},
                'nkb=s'        => \$GetOptions_H{"--nkb"},
                'wait=s'       => \$GetOptions_H{"--wait"},
                'errcheck'     => \$GetOptions_H{"--errcheck"},
                'prvcmd'       => \$GetOptions_H{"--prvcmd"}); 


my $total_seconds     = -1 * ribo_SecondsSinceEpoch(); # by multiplying by -1, we can just add another ribo_SecondsSinceEpoch call at end to get total time
my $executable        = $0;
my $date              = scalar localtime();
my $version           = "0.30";
my $riboaligner_model_version_str = "0p15"; 
my $releasedate       = "Oct 2018";
my $package_name      = "ribotyper";
my $pkgstr            = "RIBO";

# make *STDOUT file handle 'hot' so it automatically flushes whenever we print to it
select *STDOUT;
$| = 1;

# print help and exit if necessary
if((! $options_okay) || ($GetOptions_H{"-h"})) { 
  ofile_OutputBanner(*STDOUT, $package_name, $version, $releasedate, $synopsis, $date, undef);
  opt_OutputHelp(*STDOUT, $usage, \%opt_HH, \@opt_order_A, \%opt_group_desc_H);
  if(! $options_okay) { die "ERROR, unrecognized option;"; }
  else                { exit 0; } # -h, exit with 0 status
}

# check that number of command line args is correct
if(scalar(@ARGV) != 2) {   
  print "Incorrect number of command line arguments.\n";
  print $usage;
  print "\nTo see more help on available options, enter 'ribodbmaker.pl -h'\n\n";
  exit(1);
}
my ($in_fasta_file, $dir) = (@ARGV);

# set options in opt_HH
opt_SetFromUserHash(\%GetOptions_H, \%opt_HH);

# validate options (check for conflicts)
opt_ValidateSet(\%opt_HH, \@opt_order_A);

# define taxonomic level we will work at for output file that lists levels lost, including for the ingroup analysis, if we do that step, default is order
my @level_A = ("phylum", "class", "order");
my $level;
my %full_level_ct_HH = ();         # key 1 is $level, key 2 is $level taxid, value is number of sequences in full set (input) for that taxid
my %surv_filters_level_ct_HH = (); # key 1 is $level, key 2 is $level taxid, value is number of sequences that survive all filters for that taxid
my %surv_ingrup_level_ct_HH = ();  # key 1 is $level, key 2 is $level taxid, value is number of sequences that survive ingrup analysis for that taxid
my %surv_clustr_level_ct_HH = ();  # key 1 is $level, key 2 is $level taxid, value is number of sequences that survive clustering for that taxid
my %all_gtaxid_HA = (); # 1D key is taxonomic level, array is all tax ids in that level
foreach $level (@level_A) {
  %{$full_level_ct_HH{$level}} = ();          
  %{$surv_filters_level_ct_HH{$level}} = ();  
  %{$surv_ingrup_level_ct_HH{$level}}  = ();  
  %{$surv_clustr_level_ct_HH{$level}}  = ();  
  @{$all_gtaxid_HA{$level}} = ();
}

# determine what stages we are going to do:
my $do_ftaxid = opt_Get("--skipftaxid", \%opt_HH) ? 0 : 1;
my $do_fambig = opt_Get("--skipfambig", \%opt_HH) ? 0 : 1;
my $do_fvecsc = opt_Get("--skipfvecsc", \%opt_HH) ? 0 : 1;
my $do_fblast = opt_Get("--skipfblast", \%opt_HH) ? 0 : 1;
my $do_fribo1 = opt_Get("--skipfribo1", \%opt_HH) ? 0 : 1;
my $do_fribo2 = opt_Get("--skipfribo2", \%opt_HH) ? 0 : 1;
my $do_fmspan = opt_Get("--skipfmspan", \%opt_HH) ? 0 : 1;
my $do_ingrup = opt_Get("--skipingrup",  \%opt_HH) ? 0 : 1;
my $do_clustr = opt_Get("--skipclustr", \%opt_HH) ? 0 : 1;
my $do_listms = opt_Get("--skiplistms", \%opt_HH) ? 0 : 1;
my $do_mstbl  = opt_Get("--skipmstbl",  \%opt_HH) ? 0 : 1;
my $do_prvcmd = opt_Get("--prvcmd",     \%opt_HH) ? 1 : 0;
my $do_keep   = opt_Get("--keep",       \%opt_HH) ? 1 : 0;
my $do_special= opt_IsUsed("--special", \%opt_HH) ? 1 : 0;
my $do_def    = opt_Get("--def",        \%opt_HH) ? 1 : 0;

# and related options
my $do_fmspan_nogap = opt_Get("--fmnogap", \%opt_HH) ? 1 : 0;

my $did_ingrup  = 0; # set to true if we fill %surv_ingrup_level_ct_HH
my $did_clustr  = 0; # set to true if we fill %surv_clustr_level_ct_HH

# do checks that are too sophisticated for epn-options.pm
# if we are skipping both ribotyper stages, make sure none of the ribotyper options related to both were used
if((! $do_fribo1) && (! $do_fribo2)) { 
  if(opt_IsUsed("--model",      \%opt_HH)) { die "ERROR, --model does not make sense in combination with --skipfribo1 and --skipfribo2"; }
  if(opt_IsUsed("--noscfail",   \%opt_HH)) { die "ERROR, --noscfail does not make sense in combination with --skipfribo1 and --skipfribo2"; }
  if(opt_IsUsed("--lowppossc",  \%opt_HH)) { die "ERROR, --lowppossc does not make sense in combination with --skipfribo1 and --skipfribo2"; }
  if(opt_IsUsed("-p",           \%opt_HH)) { die "ERROR, -p does not make sense in combination with --skipfribo1 and --skipfribo2"; }
  if(opt_IsUsed("-q",           \%opt_HH)) { die "ERROR, -q does not make sense in combination with --skipfribo1 and --skipfribo2"; }
  if(opt_IsUsed("--nkb",        \%opt_HH)) { die "ERROR, --nkb does not make sense in combination with --skipfribo1 and --skipfribo2"; }
  if(opt_IsUsed("--wait",       \%opt_HH)) { die "ERROR, --wait does not make sense in combination with --skipfribo1 and --skipfribo2"; }
  if(opt_IsUsed("--errcheck",   \%opt_HH)) { die "ERROR, --errcheck does not make sense in combination with --skipfribo1 and --skipfribo2"; }
}

if(opt_IsUsed("--cfid", \%opt_HH) && 
   ((opt_Get("--cfid", \%opt_HH) < 0.) || (opt_Get("--cfid", \%opt_HH) > 1.))) { 
  die "ERROR, with --cfid <f>, <f> must be >= 0. and <= 1"; 
}

# we don't allow user to skip ALL filter stages, they need to do at least one. 
# You might think it should be okay to skip all filter stages if they want to 
# do ingroup analysis or just clustering but both of those require the riboaligner 
# step because they require an alignment
if((! $do_ftaxid) && (! $do_fambig) && (! $do_fvecsc) && (! $do_fblast) && (! $do_fribo1) && (! $do_fribo2) && (! $do_fmspan)) { 
  die "ERROR, at least one of the following filter stages *must* not be skipped: ftaxid, fambig, fvecsc, fblast, fribo2"; 
}  

my $in_special_file = opt_Get("--special", \%opt_HH); # this will be undefined unless --special used on the command line
# verify required files exist
if(defined $in_fasta_file) { 
  ribo_CheckIfFileExistsAndIsNonEmpty($in_fasta_file, "<input fasta sequence file> command line argument", undef, 1, undef); 
}
if(defined $in_special_file) { 
  ribo_CheckIfFileExistsAndIsNonEmpty($in_special_file, "--special argument", undef, 1, undef); 
}
# a more sophisticated check for --mslist arg, make sure we can parse it
if(opt_IsUsed("--mslist", \%opt_HH)) { 
  my $mslist_file = opt_Get("--mslist", \%opt_HH);
  my %tmp_H = ();
  ribo_CheckIfFileExistsAndIsNonEmpty($mslist_file, "--mslist argument", undef, 1, undef); 
  # further make sure it contains 1 or more lines that is an integer
  open(IN, $mslist_file) || die "ERROR unable to open $mslist_file from --mslist <s>"; 
  my $line_ctr = 0;
  while(my $line = <IN>) { 
    if($line !~ m/^\#/ && $line =~ m/\w/) { 
      chomp $line;
      if($line =~ m/^\d+$/) { 
        if(exists $tmp_H{$line}) { die "ERROR, read $line twice in input file $mslist_file"; }
        $tmp_H{$line} = 1;
        $line_ctr++;
      }
      else { 
        die "ERROR, in list file $mslist_file, expected one taxid per line, read $line";
      }
    }
  }
  close(IN);
  if($line_ctr == 0) { die "ERROR, didn't read any taxid lines in $mslist_file"; }
}
# options that affect alignment prior to pid calcs don't work in combination with *both* --skipingrup and --skipclustr
if((opt_IsUsed("--skipingrup", \%opt_HH)) && (opt_IsUsed("--skipclustr", \%opt_HH))) { 
  if(opt_IsUsed("--fullaln",  \%opt_HH)) { 
    die "ERROR, --fullaln doesn't make sense in combination with both --skipingrup and --skipclustr";
  }
  if(opt_IsUsed("--noprob",  \%opt_HH)) { 
    die "ERROR, --noprob doesn't make sense in combination with both --skipingrup and --skipclustr";
  }
  if(opt_IsUsed("--pthresh",  \%opt_HH)) { 
    die "ERROR, --pthresh doesn't make sense in combination with both --skipingrup and --skipclustr";
  }
  if(opt_IsUsed("--pfract",  \%opt_HH)) { 
    die "ERROR, --pfract doesn't make sense in combination with both --skipingrup and --skipclustr";
  }
}
# --skipfmspan requires --fullaln UNLESS both --skipingrup and --skipclustr also used
if(opt_IsUsed("--skipfmspan", \%opt_HH)) { 
  if((! opt_IsUsed("--fullaln", \%opt_HH)) && 
     ((! opt_IsUsed("--skipingrup", \%opt_HH)) ||
      (! opt_IsUsed("--skipclustr", \%opt_HH)))) { 
    die "ERROR, --fullaln is required if --skipfmspan is used unless --skipingrup and --skipclustr are also used";
  }
}

# enforce <n> >= 1 for all of --msminstart, --msmaxstart, --msminstop, --msmaxstop
if((opt_IsUsed("--msminstart", \%opt_HH)) && (opt_Get("--msminstart", \%opt_HH) < 1)) { 
    die "ERROR, with --msminstart <n1>, <n1> must be >= 1";
}
if((opt_IsUsed("--msmaxstart", \%opt_HH)) && (opt_Get("--msmaxstart", \%opt_HH) < 1)) { 
    die "ERROR, with --msmaxstart <n1>, <n1> must be >= 1";
}
if((opt_IsUsed("--msminstop", \%opt_HH)) && (opt_Get("--msminstop", \%opt_HH) < 1)) { 
    die "ERROR, with --msminstop <n1>, <n1> must be >= 1";
}
if((opt_IsUsed("--msmaxstop", \%opt_HH)) && (opt_Get("--msmaxstop", \%opt_HH) < 1)) { 
    die "ERROR, with --msmaxstop <n1>, <n1> must be >= 1";
}
# with --msminstart <n1> and --msmaxstart <n2>, enforce <n1> <= <n2>
if((opt_IsUsed("--msminstart", \%opt_HH)) && (opt_IsUsed("--msmaxstart", \%opt_HH))) { 
  if((opt_Get("--msminstart", \%opt_HH)) > (opt_Get("--msmaxstart", \%opt_HH))) { 
    die "ERROR, with --msminstart <n1> and --msmaxstart <n2>, <n2> must be >= <n1>";
  }
}
# with --msminstop <n1> and --msmaxstop <n2>, enforce <n1> <= <n2>
if((opt_IsUsed("--msminstop", \%opt_HH)) && (opt_IsUsed("--msmaxstop", \%opt_HH))) { 
  if((opt_Get("--msminstop", \%opt_HH)) > (opt_Get("--msmaxstop", \%opt_HH))) { 
    die "ERROR, with --msminstop <n1> and --msmaxstop <n2>, <n2> must be >= <n1>";
  }
}
# with --msminstart <n1> and --msmaxstop <n2>, enforce <n1> <= <n2>
if((opt_IsUsed("--msminstart", \%opt_HH)) && (opt_IsUsed("--msmaxstop", \%opt_HH))) { 
  if((opt_Get("--msminstart", \%opt_HH)) > (opt_Get("--msmaxstop", \%opt_HH))) { 
    die "ERROR, with --msminstart <n1> and --msmaxstop <n2>, <n2> must be >= <n1>";
  }
}
# we do more sophisticated tests for these --ms{min,max}{start,stop} options later
# after we know $family_modellen

# now that we know what steps we are doing, make sure that:
# - required ENV variables are set and point to valid dirs
# - required executables exist and are executable
# - required files exist
# we do this for each stage individually

my $in_riboopts1_file = undef;
my $in_riboopts2_file = undef;
my $df_ra_modelinfo_file = $df_model_dir . "riboaligner." . $riboaligner_model_version_str . ".all.modelinfo";
my $ra_modelinfo_file = undef;
my %execs_H = (); # key is name of program, value is path to the executable
my $taxonomy_tree_six_column_file = undef;

# we always require easel miniapps
$execs_H{"esl-sfetch"}   = $env_riboeasel_dir    . "/esl-sfetch";
$execs_H{"esl-seqstat"}  = $env_riboeasel_dir    . "/esl-seqstat";
$execs_H{"esl-alimanip"} = $env_riboeasel_dir    . "/esl-alimanip";
$execs_H{"esl-alimerge"} = $env_riboeasel_dir    . "/esl-alimerge";
$execs_H{"esl-alimask"}  = $env_riboeasel_dir    . "/esl-alimask";
$execs_H{"esl-alipid"}   = $env_riboeasel_dir    . "/esl-alipid";
$execs_H{"esl-alistat"}  = $env_riboeasel_dir    . "/esl-alistat";
$execs_H{"esl-cluster"}  = $env_riboeasel_dir    . "/esl-cluster";

if($do_ftaxid || $do_ingrup || $do_fvecsc || $do_special || $do_def) { 
  $env_vecplus_dir = ribo_VerifyEnvVariableIsValidDir("VECPLUSDIR");
  if($do_fvecsc) { 
    $execs_H{"vecscreen"}            = $env_vecplus_dir    . "/scripts/vecscreen"; 
    $execs_H{"parse_vecscreen.pl"}   = $env_vecplus_dir    . "/scripts/parse_vecscreen.pl";
    $execs_H{"combine_summaries.pl"} = $env_vecplus_dir    . "/scripts/combine_summaries.pl";
  }
}
if($do_ftaxid || $do_ingrup || $do_special || $do_def) { 
  $execs_H{"srcchk"} = $env_vecplus_dir . "/scripts/srcchk";
    
  $env_ribotax_dir = ribo_VerifyEnvVariableIsValidDir("RIBOTAXDIR");
  $taxonomy_tree_six_column_file = $env_ribotax_dir . "/taxonomy_tree_ribodbmaker.txt";
  ribo_CheckIfFileExistsAndIsNonEmpty($taxonomy_tree_six_column_file, "taxonomy tree file with taxonomic levels and specified species", undef, 1, undef); # 1 says: die if it doesn't exist or is empty

  $execs_H{"find_taxonomy_ancestors.pl"} = $env_vecplus_dir . "/scripts/find_taxonomy_ancestors.pl";
  $execs_H{"alipid-taxinfo-analyze.pl"}  = $env_ribotyper_dir . "/alipid-taxinfo-analyze.pl";
  $execs_H{"ali-apos-to-uapos.pl"}       = $env_ribotyper_dir . "/ali-apos-to-uapos.pl";
}

if($do_fblast) { 
  $env_riboblast_dir = ribo_VerifyEnvVariableIsValidDir("RIBOBLASTDIR");
  $execs_H{"blastn"} = $env_riboblast_dir  . "/blastn";
}

if($do_fribo1) { 
  # make sure model exists
  if(! opt_IsUsed("--model", \%opt_HH)) { 
    die "ERROR, --model is a required option, unless --skipfribo1 and --skipfribo2 are both used";
  }
  # make sure the riboopts1 file exists if --riboopts1 used
  if(opt_IsUsed("--riboopts1", \%opt_HH)) {
    $in_riboopts1_file = opt_Get("--riboopts1", \%opt_HH);
    ribo_CheckIfFileExistsAndIsNonEmpty($in_riboopts1_file, "riboopts file specified with --riboopts1", undef, 1, undef); # last argument as 1 says: die if it doesn't exist or is empty
  }
}

if($do_fribo1 || $do_fribo2) { 
  # make sure model exists
  if(! opt_IsUsed("--model", \%opt_HH)) { 
    die "ERROR, --model is a required option, unless --skipfribo1 and --skipfribo2 are both used";
  }

  # make sure the riboopts2 file exists if --riboopts2 used
  if(opt_IsUsed("--riboopts2", \%opt_HH)) {
    $in_riboopts2_file = opt_Get("--riboopts2", \%opt_HH);
    ribo_CheckIfFileExistsAndIsNonEmpty($in_riboopts2_file, "riboopts file specified with --riboopts2", undef, 1, undef); # last argument as 1 says: die if it doesn't exist or is empty
  }

  # make sure the riboaligner modelinfo files exists
  if(! opt_IsUsed("--rainfo", \%opt_HH)) { 
    $ra_modelinfo_file = $df_ra_modelinfo_file;  
    ribo_CheckIfFileExistsAndIsNonEmpty($ra_modelinfo_file, "default riboaligner model info file", undef, 1, undef); # 1 says: die if it doesn't exist or is empty
  }
  else { # --rainfo used
    $ra_modelinfo_file = opt_Get("--rainfo", \%opt_HH); }
  if(! opt_IsUsed("--rainfo", \%opt_HH)) {
    ribo_CheckIfFileExistsAndIsNonEmpty($ra_modelinfo_file, "riboaligner model info file specified with --rainfo", undef, 1, undef); # 1 says: die if it doesn't exist or is empty
  }

  $execs_H{"ribotyper"}         = $env_ribotyper_dir  . "/ribotyper.pl";
  $execs_H{"riboaligner"} = $env_ribotyper_dir  . "/riboaligner.pl";
}
if(opt_IsUsed("--mslist", \%opt_HH)) { 
  $execs_H{"mdlspan-survtbl-sort.pl"} = $env_ribotyper_dir . "/mdlspan-survtbl-sort.pl";
}

ribo_ValidateExecutableHash(\%execs_H);

#############################
# create the output directory
#############################
my $cmd;              # a command to run with runCommand()
my @early_cmd_A = (); # array of commands we run before our log file is opened
if($dir !~ m/\/$/) { $dir =~ s/\/$//; } # remove final '/' if it exists
                
if(-d $dir) { 
  $cmd = "rm -rf $dir";
  if(opt_Get("-f", \%opt_HH)) { 
    ribo_RunCommand($cmd, opt_Get("-v", \%opt_HH), undef); push(@early_cmd_A, $cmd); 
  }
  else { # $dir directory exists but -f not used
    if(! $do_prvcmd) { 
      die "ERROR directory named $dir already exists. Remove it, or use -f to overwrite it."; 
    }
  }
}
elsif(-e $dir) { 
  $cmd = "rm $dir";
  if(opt_Get("-f", \%opt_HH)) { 
    ribo_RunCommand($cmd, opt_Get("-v", \%opt_HH), undef); push(@early_cmd_A, $cmd); 
  }
  else { # $dir file exists but -f not used
    die "ERROR a file named $dir already exists. Remove it, or use -f to overwrite it."; 
  }
}

# create the dir
$cmd = "mkdir $dir";
if(! $do_prvcmd) { 
  ribo_RunCommand($cmd, opt_Get("-v", \%opt_HH), undef);
  push(@early_cmd_A, $cmd);
}

my $dir_tail = $dir;
$dir_tail =~ s/^.+\///; # remove all but last dir
my $out_root = $dir . "/" . $dir_tail . ".ribodbmaker";

# checkpoint related variables:
# 'filters' (filters) checkpoint, after fribo2 stage
my $npass_filters = 0; # number of seqs that pass all filter stages
my $nfail_filters = 0; # number of seqs that pass all filter stages
# 'ingrup' (ingroup) checkpoint, after ingrup stage
my $npass_ingrup = 0; # number of seqs that pass ingroup stage 
my $nfail_ingrup = 0; # number of seqs that pass ingroup stage
# 'clustr' (cluster) checkpoint, after clustering stage
my $npass_clustr = 0; # number of seqs that pass clustering
my $nfail_clustr = 0; # number of seqs that pass clustering

#############################################
# output program banner and open output files
#############################################
# output preamble
my @arg_desc_A = ("input sequence file", "output directory name");
my @arg_A      = ($in_fasta_file, $dir);
my %extra_H    = ();
$extra_H{"\$RIBODIR"}      = $env_ribotyper_dir;
$extra_H{"\$RIBOEASELDIR"} = $env_riboeasel_dir;
if(defined $env_vecplus_dir)    { $extra_H{"\$VECPLUSDIR"}    = $env_vecplus_dir; }
if(defined $env_ribotax_dir)    { $extra_H{"\$RIBOTAXDIR"}    = $env_ribotax_dir; }
if(defined $env_riboblast_dir)  { $extra_H{"\$RIBOBLASTDIR"}  = $env_riboblast_dir; }
ofile_OutputBanner(*STDOUT, $package_name, $version, $releasedate, $synopsis, $date, \%extra_H);
opt_OutputPreamble(*STDOUT, \@arg_desc_A, \@arg_A, \%opt_HH, \@opt_order_A);

# open the list, log and command files:
# set output file names and file handles, and open those file handles
my %ofile_info_HH = ();  # hash of information on output files we created,
                         # 1D keys: 
                         #  "fullpath":  full path to the file
                         #  "nodirpath": file name, full path minus all directories
                         #  "desc":      short description of the file
                         #  "FH":        file handle to output to for this file, maybe undef
                         # 2D keys:
                         #  "log": log file of what's output to stdout
                         #  "cmd": command file with list of all commands executed

# open the log and command files 
ofile_OpenAndAddFileToOutputInfo(\%ofile_info_HH, $pkgstr, "log",  $out_root . ".log",  1, "Output printed to screen");
ofile_OpenAndAddFileToOutputInfo(\%ofile_info_HH, $pkgstr, "cmd",  $out_root . ".cmd",  1, "List of executed commands");
ofile_OpenAndAddFileToOutputInfo(\%ofile_info_HH, $pkgstr, "list", $out_root . ".list", 1, "List and description of all output files");
my $log_FH = $ofile_info_HH{"FH"}{"log"};
my $cmd_FH = $ofile_info_HH{"FH"}{"cmd"};
# output files are all open, if we exit after this point, we'll need
# to close these first.

# now we have the log file open, output the banner there too
ofile_OutputBanner($log_FH, $pkgstr, $version, $releasedate, $synopsis, $date, \%extra_H);
opt_OutputPreamble($log_FH, \@arg_desc_A, \@arg_A, \%opt_HH, \@opt_order_A);

# output any commands we already executed to $log_FH
foreach $cmd (@early_cmd_A) { 
  print $cmd_FH $cmd . "\n";
}

###########################################################################
# Preliminary stage: Parse/validate input files
# We do this first, so we can die quickly if anything goes wrong
# as opposed to waiting until we get to the relevant stage.
###########################################################################
my $progress_w = 80; # the width of the left hand column in our progress output, hard-coded
my $start_secs;
$start_secs = ofile_OutputProgressPrior("[Stage: prelim] Validating input files", $progress_w, $log_FH, *STDOUT);

# parse the modelinfo file, this tells us where the CM files are
my @tmp_family_order_A     = (); # family name, in order, temporary because we enforce that there is only 1 before continuing
my %tmp_family_modelfile_H = (); # key is family name (e.g. "SSU.Archaea") from @tmp_family_order_A, value is CM file for that family
my %tmp_family_modellen_H  = (); # key is family name (e.g. "SSU.Archaea") from @tmp_family_order_A, value is consensus length for that family
my %tmp_family_rtname_HA   = (); # key is family name (e.g. "SSU.Archaea") from @family_order_A, value is array of ribotyper models to align with this family
my $family           = undef;
my $family_modelfile = undef;
my $family_modellen  = undef;
my $family_fail_str  = "";
my $ribotyper_options; # string of options for ribotyper 1 stage
my $local_ra_riboopts_file = $out_root . ".ra.riboopts";   # riboopts file for fribo2 step
my $local_ra_modelinfo_file = $out_root . ".ra.modelinfo"; # model info file for fribo2 step

if($do_fribo1 || $do_fribo2) { 
  # make sure that the model specified with --model exists
  ribo_ParseRAModelinfoFile($ra_modelinfo_file, $df_model_dir, \@tmp_family_order_A, \%tmp_family_modelfile_H, \%tmp_family_modellen_H, \%tmp_family_rtname_HA, $ofile_info_HH{"FH"});
  $family = opt_Get("--model", \%opt_HH);
  if(! exists $tmp_family_modelfile_H{$family}) { 
    foreach my $tmp_family (@tmp_family_order_A) { $family_fail_str .= $tmp_family. "\n"; }
    ofile_FAIL("ERROR, model $family specified with --model not listed in $ra_modelinfo_file.\nValid options are:\n$family_fail_str", $pkgstr, $!, $ofile_info_HH{"FH"}); 
  }
  $family_modelfile = $tmp_family_modelfile_H{$family};
  $family_modellen  = $tmp_family_modellen_H{$family};
  if(! -s $family_modelfile) { 
    ofile_FAIL("ERROR, model file $family_modelfile specified in $ra_modelinfo_file does not exist or is empty", $pkgstr, $!, $ofile_info_HH{"FH"});
  }
  # create the riboaligner info file for $family
  open(RAINFO, ">", $local_ra_modelinfo_file) || ofile_FileOpenFailure($local_ra_modelinfo_file,  "RIBO", "ribodbmaker.pl::main()", $!, "writing", $ofile_info_HH{"FH"});
  my $local_family_modelfile = ribo_RemoveDirPath($family_modelfile);
  printf RAINFO ("%s %s %s", $family, $local_family_modelfile, $family_modellen);
  foreach my $rtname (@{$tmp_family_rtname_HA{$family}}) { 
    printf RAINFO (" %s", $rtname);
  }
  print RAINFO ("\n");
  close(RAINFO);

  # create the riboopts1 string for ribotyper stage 1, unless --riboopts1 <s> provided in which case we read that
  if(opt_IsUsed("--riboopts1", \%opt_HH)) { 
    open(OPTS1, $in_riboopts1_file) || ofile_FileOpenFailure($in_riboopts1_file,  "RIBO", "ribodbmaker.pl::main()", $!, "writing", $ofile_info_HH{"FH"});
    $ribotyper_options = <OPTS1>;
    chomp $ribotyper_options;
    close(OPTS1);
  }
  else { 
    $ribotyper_options = sprintf("--minusfail --lowppossc %s ", opt_Get("--lowppossc", \%opt_HH));
    if(! opt_IsUsed("--noscfail",    \%opt_HH)) { $ribotyper_options .= "--scfail "; }
    # --2slow doesn't apply here
  }

  # create the riboopts2 file to supply to riboaligner, unless --riboopts2 <s> provided in which case use <s>
  if(opt_IsUsed("--riboopts2", \%opt_HH)) { 
    my $cp_command = sprintf("cp %s $local_ra_riboopts_file", opt_Get("--riboopts2", \%opt_HH));
    ribo_RunCommand($cp_command, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"});
  }
  else { 
    open(RIBOOPTS2, ">", $local_ra_riboopts_file) || ofile_FileOpenFailure($local_ra_riboopts_file,  "RIBO", "ribodbmaker.pl::main()", $!, "writing", $ofile_info_HH{"FH"});
    my $riboopts_str = sprintf("--lowppossc %s --tcov %s", opt_Get("--lowppossc", \%opt_HH), opt_Get("--tcov", \%opt_HH));
    if(! opt_IsUsed("--nodifffail", \%opt_HH)) { $riboopts_str .= " --difffail"; }
    if(! opt_IsUsed("--nomultfail", \%opt_HH)) { $riboopts_str .= " --multfail"; }
    if(! opt_IsUsed("--ribo2hmm",   \%opt_HH)) { $riboopts_str .= " --2slow"; }
    printf RIBOOPTS2 ($riboopts_str . "\n"); 
    close(RIBOOPTS2);
  }

  # now that we know $family_modellen, check that the --ms{min,max}{start,stop} options still make make sense
  # note that we already checked that --msminstart <= --msmaxstart, --msminstop <= --msmaxstop, and --msminstart <= --msmaxstop above

  # first, make sure that all values are now less than or equal to modellen
  if((opt_IsUsed("--msminstart", \%opt_HH)) && (opt_Get("--msminstart", \%opt_HH) < 1)) { 
    ofile_FAIL("ERROR, with --msminstart <n1>, <n1> must be >= 1", "RIBO", $!, $ofile_info_HH{"FH"});
  }
  if((opt_IsUsed("--msmaxstart", \%opt_HH)) && (opt_Get("--msmaxstart", \%opt_HH) < 1)) { 
    ofile_FAIL("ERROR, with --msmaxstart <n1>, <n1> must be >= 1", "RIBO", $!, $ofile_info_HH{"FH"});
  }
  if((opt_IsUsed("--msminstop", \%opt_HH)) && (opt_Get("--msminstop", \%opt_HH) < 1)) { 
    ofile_FAIL("ERROR, with --msminstop <n1>, <n1> must be >= 1", "RIBO", $!, $ofile_info_HH{"FH"});
  }
  if((opt_IsUsed("--msmaxstop", \%opt_HH)) && (opt_Get("--msmaxstop", \%opt_HH) < 1)) { 
    ofile_FAIL("ERROR, with --msmaxstop <n1>, <n1> must be >= 1", "RIBO", $!, $ofile_info_HH{"FH"});
  }
  # second, make sure there's at least one bin we're going to have
  # this only relies on --msminstart and --msmaxstop
  if(opt_IsUsed("--msminstart", \%opt_HH) || opt_IsUsed("--msmaxstop", \%opt_HH)) { 
    my $tmp_minstart = opt_IsUsed("--msminstart", \%opt_HH) ? opt_Get("--msminstart", \%opt_HH) : 1;
    my $tmp_maxstop  = opt_IsUsed("--msmaxstop",  \%opt_HH) ? opt_Get("--msmaxstop",  \%opt_HH) : $family_modellen;
    my $tmp_step     = opt_Get("--msstep",  \%opt_HH);
    my $tmp_msminlen = opt_Get("--msminlen",  \%opt_HH);
    my $tmp_minlen   = ($tmp_step > $tmp_msminlen) ? $tmp_step : $tmp_msminlen;
    # don't think this check is actually necessary, but I'm leaving it
    if($tmp_minstart > $tmp_maxstop) { 
      ofile_FAIL("ERROR, with --msminstart <n1> and --msmaxstop <n2>, <n2> must be >= <n1> (<n1> is $tmp_minstart, <n2> is $tmp_maxstop)", "RIBO", $!, $ofile_info_HH{"FH"});
    }
    # enforce <n1> <= <n2> and (<n2> - <n1> + 1) >= MAX($tmp_minlen, $tmp_step)
    if(($tmp_maxstop - $tmp_minstart + 1) < $tmp_minlen) { 
      ofile_FAIL("ERROR, with --msminstart <n1> and --msmaxstop <n2>, <n2> - <n1> + 1 must be must be >= $tmp_minlen (<n1> is $tmp_minstart, <n2> is $tmp_maxstop)", "RIBO", $!, $ofile_info_HH{"FH"});
    }
  }
}

my %taxid_is_special_H = (); # key is taxid (species level), value is '1' if listed in $in_special_file, does not exist otherwise
my $line;
if($do_special) { 
  open(IN, $in_special_file)  || ofile_FileOpenFailure($in_special_file,  "RIBO", "ribodbmaker.pl::main()", $!, "reading", $ofile_info_HH{"FH"});
  while($line = <IN>) { 
    chomp $line;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    if($line !~ m/^\d+$/) { 
      ofile_FAIL("ERROR reading $in_special_file, expected only single integers on each line, got $line", $pkgstr, $!, $ofile_info_HH{"FH"}); 
    }
    $taxid_is_special_H{$line} = 1; 
  }
  close(IN);
}
ofile_OutputProgressComplete($start_secs, undef, $log_FH, *STDOUT);

###########################################################################################
# Preliminary stage: Copy the fasta file (if --fasta)
###########################################################################################
my $raw_fasta_file = $out_root . ".raw.fa";
my $full_fasta_file = $out_root . ".full.fa";
$start_secs = ofile_OutputProgressPrior("[Stage: prelim] Copying input fasta file ", $progress_w, $log_FH, *STDOUT);
my $cp_command .= "cp $in_fasta_file $raw_fasta_file";
if(! $do_prvcmd) { ribo_RunCommand($cp_command, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
ofile_OutputProgressComplete($start_secs, undef, $log_FH, *STDOUT);

# reformat the names of the sequences, if necessary
# gi|675602128|gb|KJ925573.1| becomes KJ925573.1
$start_secs = ofile_OutputProgressPrior("[Stage: prelim] Reformatting names of sequences ", $progress_w, $log_FH, *STDOUT);
reformat_sequence_names_in_fasta_file($raw_fasta_file, $full_fasta_file, $ofile_info_HH{"FH"});
ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "fullfa", "$full_fasta_file", 0, "fasta file with names possibly updated to accession.version");
ofile_OutputProgressComplete($start_secs, undef, $log_FH, *STDOUT);

# get lengths of all seqs and create a list of all sequences
my $seqstat_file = $out_root . ".full.seqstat";
my $comptbl_file = $out_root . ".full.comptbl";
my %seqidx_H = (); # key: sequence name, value: index of sequence in original input sequence file (1..$nseq)
my %seqlen_H = (); # key: sequence name, value: length of sequence, 
                   # value multiplied by -1 after we output info for this sequence
                   # in round 1. Multiplied by -1 again after we output info 
                   # for this sequence in round 2. We do this so that we know
                   # that 'we output this sequence already', so if we 
                   # see it again before the next round, then we know the 
                   # tbl file was not sorted properly. That shouldn't happen,
                   # but if somehow it does then we want to know about it.
my %seqnambig_H  = (); # number of ambiguous nucleotides per sequence
my %seqtaxid_H   = (); # taxid, from srcchk of each sequence, remains empty if srcchk does not need to be run
my %seqorgn_H    = (); # organism field, from srcchk of each sequence, filled only if defline redefinition option (--def) is used
my %seqstrain_H  = (); # strain field, from srcchk of each sequence, filled only if defline redefinition option (--def) is used
my %seqgtaxid_HH = (); # %seqtaxid_HH{$level}: group taxid at taxonomic level $level for each sequence, remains empty if srcchk does not need to be run
my %seqlpos_H    = (); # key: sequence name, value is unaligned position that aligns to left model position we care about
my %seqrpos_H    = (); # key: sequence name, value is unaligned position that aligns to right model position we care about
my %seqlenclass_H= (); # key: sequence name, value is length class from riboaligner
my @seqorder_A   = (); # array of sequence names in order they appeared in the file
my %is_centroid_H = (); # key is sequence name, value is 1 if sequence is a centroid, 0 if it is not, key does not exist if sequence did not survive to clustering
my %not_centroid_H = (); # key is sequence name, value is 1 if sequence is NOT a centroid, "" if it is, key does not exist if sequence did not survive to clustering
my %in_cluster_H   = (); # key is sequence name, value is cluster index this sequence belongs to
my %cluster_size_H = (); # key is a cluster index (value from %in_cluster_H), value is number of sequences in that cluster
my %width_H       = (); # hash with max widths of "target", "length", "index"
my $nseq = 0;
my $full_list_file = $out_root . ".full.seqlist";
my $have_taxids = 0;

$start_secs = ofile_OutputProgressPrior("[Stage: prelim] Determining target sequence lengths", $progress_w, $log_FH, *STDOUT);
ribo_ProcessSequenceFile($execs_H{"esl-seqstat"}, $full_fasta_file, $seqstat_file, \@seqorder_A, \%seqidx_H, \%seqlen_H, \%width_H, \%opt_HH, \%ofile_info_HH);
$nseq = scalar(keys %seqidx_H);
ribo_CountAmbiguousNucleotidesInSequenceFile($execs_H{"esl-seqstat"}, $full_fasta_file, $comptbl_file, \%seqnambig_H, \%opt_HH, $ofile_info_HH{"FH"});
if(! $do_prvcmd) { ribo_RunCommand("grep ^\= $seqstat_file | awk '{ print \$2 }' > $full_list_file", opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "fulllist", "$full_list_file", 0, "file with list of all $nseq input sequences");
ofile_OutputProgressComplete($start_secs, undef, $log_FH, *STDOUT);

# index the sequence file
if(! $do_prvcmd) { ribo_RunCommand($execs_H{"esl-sfetch"} . " --index $full_fasta_file > /dev/null", opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "fullssi", $full_fasta_file . ".ssi", 0, ".ssi index file for full fasta file");

######################################################################################################
# Preliminary stage: Run srcchk, if necessary (if $do_ftaxid || $do_ingrup || $do_special || $do_def)
######################################################################################################
my $full_srcchk_file = undef;
my %taxinfo_wlevel_file_H = ();
foreach $level (@level_A) { 
  $taxinfo_wlevel_file_H{$level} = $out_root . ".taxinfo_w" . $level. ".txt";
  %{$seqgtaxid_HH{$level}} = ();
}

if($do_ftaxid || $do_ingrup || $do_special || $do_def) { 
  $start_secs = ofile_OutputProgressPrior("[Stage: prelim] Running srcchk for all sequences ", $progress_w, $log_FH, *STDOUT);
  $full_srcchk_file = $out_root . ".full.srcchk";
  if(! $do_prvcmd) { ribo_RunCommand($execs_H{"srcchk"} . " -i $full_list_file -f \'taxid,organism,strain\' > $full_srcchk_file", opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
  ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "fullsrcchk", "$full_srcchk_file", 0, "srcchk output for all $nseq input sequences");

  # parse srcchk output to fill %seqtaxid_H, and possibly %seq_orgn_H
  parse_srcchk_file($full_srcchk_file, $taxonomy_tree_six_column_file, \%seqtaxid_H, 
                    ($do_def ? \%seqorgn_H   : undef), 
                    ($do_def ? \%seqstrain_H : undef), 
                    \@seqorder_A, \%ofile_info_HH);
  $have_taxids = 1;

  # get taxonomy file with taxonomic levels
  foreach $level (@level_A) { 
    my $find_tax_cmd = $execs_H{"find_taxonomy_ancestors.pl"} . " --input_summary $full_srcchk_file --input_tax $taxonomy_tree_six_column_file --input_level $level --outfile " . $taxinfo_wlevel_file_H{$level};
    if(! $do_prvcmd) { ribo_RunCommand($find_tax_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
    ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "taxinfo.$level", $taxinfo_wlevel_file_H{$level}, 0, "taxinfo file with $level");
    # parse tax_level file to fill %full_level_ct_HH
    parse_tax_level_file($taxinfo_wlevel_file_H{$level}, undef, $seqgtaxid_HH{$level}, $full_level_ct_HH{$level}, $ofile_info_HH{"FH"});
    # now fill @all_gtaxid_HA
    @{$all_gtaxid_HA{$level}} = (sort {$a <=> $b} keys %{$full_level_ct_HH{$level}});
  }
  ofile_OutputProgressComplete($start_secs, undef, $log_FH, *STDOUT);
}

####################
# FILTERING STAGES #
####################

my %seqfailstr_H = (); # hash that keeps track of failure strings for each sequence, will be "" for a passing sequence
my %curfailstr_H = (); # hash that keeps track of failure string for current stage only, will be "" for a passing sequence
my $seqname;
my $npass = 0;
ribo_InitializeHashToEmptyString(\%curfailstr_H, \@seqorder_A);
ribo_InitializeHashToEmptyString(\%seqfailstr_H, \@seqorder_A);
my $stage_key = undef;

########################################################
# 'fambig' stage: filter based on ambiguous nucleotides
########################################################
if($do_fambig) { 
  $stage_key = "fambig";
  $start_secs = ofile_OutputProgressPrior("[Stage: $stage_key] Filtering based on ambiguous nucleotides ", $progress_w, $log_FH, *STDOUT);
  my $do_num_ambig   = opt_Get("--faonlyf", \%opt_HH) ? 0 : 1;
  my $do_fract_ambig = opt_Get("--faonlyn", \%opt_HH) ? 0 : 1;
  my $maxnambig      = opt_Get("--famaxn", \%opt_HH);
  my $maxfambig      = opt_Get("--famaxf", \%opt_HH);
  my $cur_maxnambig  = 0; # maximum number of ambiguous nucleotides for current sequence
  foreach $seqname (keys %seqnambig_H) { 
    # determine maximum number of ambiguous nucleotides for this sequence
    $cur_maxnambig = undef;
    if($do_fract_ambig) { 
      $cur_maxnambig = $maxfambig * $seqlen_H{$seqname}; 
    }
    if($do_num_ambig) {
      if((! defined $cur_maxnambig) || ($maxnambig < $cur_maxnambig)) {
        $cur_maxnambig = $maxnambig;
      }
    }
    if($seqnambig_H{$seqname} > $cur_maxnambig) { 
      $curfailstr_H{$seqname} = "ambig[" . $seqnambig_H{$seqname} . ">" . $cur_maxnambig . "];;"; 
    }
    else { 
      $curfailstr_H{$seqname} = "";
    }
  }
  $npass = update_and_output_pass_fails(\%curfailstr_H, \%seqfailstr_H, \@seqorder_A, 0, $out_root, $stage_key, \%ofile_info_HH); # 0: do not output description of pass/fail lists to log file
  ofile_OutputProgressComplete($start_secs, sprintf("%6d pass; %6d fail;", $npass, $nseq-$npass), $log_FH, *STDOUT);
}

###############################################
# 'ftaxid' stage: filter for specified species
###############################################
if($do_ftaxid) { 
  $stage_key = "ftaxid";
  $start_secs = ofile_OutputProgressPrior("[Stage: $stage_key] Filtering for specified species ", $progress_w, $log_FH, *STDOUT);
  $npass = parse_srcchk_and_tax_files_for_specified_species($full_srcchk_file, $taxonomy_tree_six_column_file, \%seqtaxid_H, \%seqfailstr_H, \@seqorder_A, $out_root, \%opt_HH, \%ofile_info_HH);
  ofile_OutputProgressComplete($start_secs, sprintf("%6d pass; %6d fail;", $npass, $nseq-$npass), $log_FH, *STDOUT);
}
  
#########################################################
# 'fvecscr' stage: filter for non-weak VecScreen matches 
#########################################################
$stage_key = "fvecsc";
my $parse_vecscreen_terminal_file = $out_root . "." . $stage_key . ".terminal.parse_vecscreen";
my $parse_vecscreen_internal_file = $out_root . "." . $stage_key . ".internal.parse_vecscreen";
my $parse_vecscreen_combined_file = $out_root . "." . $stage_key . ".combined.parse_vecscreen";
if($do_fvecsc) { 
  $start_secs = ofile_OutputProgressPrior("[Stage: $stage_key] Identifying vector sequences with VecScreen", $progress_w, $log_FH, *STDOUT);
  my $vecscreen_output_file = $out_root . ".vecscreen";
  my $vecscreen_cmd  = $execs_H{"vecscreen"} . " -text_output -query $full_fasta_file > $vecscreen_output_file";
  if(! $do_prvcmd) { ribo_RunCommand($vecscreen_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
  ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "vecout", "$vecscreen_output_file", 0, "vecscreen output file");

  # parse vecscreen 
  my $parse_vecscreen_cmd   = $execs_H{"parse_vecscreen.pl"} . " --verbose --input $vecscreen_output_file --outfile_terminal $parse_vecscreen_terminal_file --outfile_internal $parse_vecscreen_internal_file";
  my $combine_summaries_cmd = $execs_H{"combine_summaries.pl"} . " --input_internal $parse_vecscreen_internal_file --input_terminal $parse_vecscreen_terminal_file --outfile $parse_vecscreen_combined_file";
  if(! $do_prvcmd) { ribo_RunCommand($parse_vecscreen_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
  ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "parsevecterm", "$parse_vecscreen_terminal_file", 0, "parse_vecscreen.pl terminal output file");
  ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "parsevecint",  "$parse_vecscreen_internal_file", 0, "parse_vecscreen.pl internal output file");
  
  if(! $do_prvcmd) { ribo_RunCommand($combine_summaries_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"});}
  ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "parseveccombined", "$parse_vecscreen_combined_file", 0, "combined parse_vecscreen.pl output file");

  # get list of accessions in combined parse_vecscreen output that have non-Weak matches
  $npass = parse_parse_vecscreen_combined_file($parse_vecscreen_combined_file, \%seqfailstr_H, \@seqorder_A, $out_root, \%opt_HH, \%ofile_info_HH);

  ofile_OutputProgressComplete($start_secs, sprintf("%6d pass; %6d fail;", $npass, $nseq-$npass), $log_FH, *STDOUT);
}

###################################################################
# 'fblast' stage: self-blast all sequences to find tandem repeats
###################################################################
if($do_fblast) { 
  $stage_key = "fblast";
  $start_secs = ofile_OutputProgressPrior("[Stage: $stage_key] Identifying repeats by BLASTing against self", $progress_w, $log_FH, *STDOUT);
  $npass = fblast_stage(\%execs_H, \%seqfailstr_H, \@seqorder_A, $out_root, \%opt_HH, \%ofile_info_HH);
  ofile_OutputProgressComplete($start_secs, sprintf("%6d pass; %6d fail;", $npass, $nseq-$npass), $log_FH, *STDOUT);
}

##########################################################
# 'fribo1' stage: stage that filters based on ribotyper.pl
##########################################################
my $rt_opt_p_sum_cpu_secs = 0; # seconds spent in parallel in ribotyper call, filled only if -p
if($do_fribo1) { 
  $stage_key = "fribo1";
  $start_secs = ofile_OutputProgressPrior("[Stage: $stage_key] Running ribotyper.pl", $progress_w, $log_FH, *STDOUT);
  
  my $ribotyper_accept_file  = $out_root . ".ribotyper.accept";
  my $ribotyper_outdir       = $out_root . "-rt";
  my $ribotyper_outdir_tail  = $dir_tail . ".ribodbmaker-rt";
  my $ribotyper_outfile      = $out_root . ".ribotyper.out";
  my $ribotyper_short_file   = $ribotyper_outdir . "/" . $ribotyper_outdir_tail . ".ribotyper.short.out";
  my $ribotyper_long_file    = $ribotyper_outdir . "/" . $ribotyper_outdir_tail . ".ribotyper.long.out";
  my $ribotyper_log_file     = $ribotyper_outdir . "/" . $ribotyper_outdir_tail . ".ribotyper.log";

  # first we need to create the acceptable models file
  ribo_WriteAcceptFile($tmp_family_rtname_HA{$family}, $ribotyper_accept_file, $ofile_info_HH{"FH"});
  ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, "RIBO", "accept", $ribotyper_accept_file, 0, "accept input file for ribotyper");

  $ribotyper_options .= " -f --inaccept $ribotyper_accept_file "; 
  if(opt_IsUsed("-n",            \%opt_HH)) { $ribotyper_options .= " -n " . opt_Get("-n", \%opt_HH); }
  if(opt_IsUsed("-p",            \%opt_HH)) { $ribotyper_options .= " -p"; }
  if(opt_IsUsed("-q",            \%opt_HH)) { $ribotyper_options .= " -q " . opt_Get("-q", \%opt_HH); }
  if(opt_IsUsed("--nkb",         \%opt_HH)) { $ribotyper_options .= " --nkb " . opt_Get("--nkb", \%opt_HH); }
  if(opt_IsUsed("--wait",        \%opt_HH)) { $ribotyper_options .= " --wait " . opt_Get("--wait", \%opt_HH); }
  if(opt_IsUsed("--errcheck",    \%opt_HH)) { $ribotyper_options .= " --errcheck"; }
  if(opt_IsUsed("--keep",        \%opt_HH)) { $ribotyper_options .= " --keep"; }

  my $ribotyper_command = $execs_H{"ribotyper"} . " $ribotyper_options $full_fasta_file $ribotyper_outdir > $ribotyper_outfile";
  if(! $do_prvcmd) { ribo_RunCommand($ribotyper_command, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
  ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "rtout", "$ribotyper_outfile", 0, "output of ribotyper");
  
  # if -p: parse the ribotyper log file to get CPU+wait time for parallel
  if(opt_Get("-p", \%opt_HH)) { 
    $rt_opt_p_sum_cpu_secs = ribo_ParseLogFileForParallelTime($ribotyper_log_file, $ofile_info_HH{"FH"});
  }

  # parse ribotyper short file
  $npass = parse_ribotyper_short_file($ribotyper_short_file, \%seqfailstr_H, \@seqorder_A, \%opt_HH, \%ofile_info_HH);
  my $extra_desc = undef;
  if((opt_Get("-p", \%opt_HH)) && ($rt_opt_p_sum_cpu_secs > 0.)) { 
    $extra_desc = sprintf("%6d pass; %6d fail; (%.1f summed elapsed seconds for all jobs)", $npass, $nseq-$npass, $rt_opt_p_sum_cpu_secs);
  }
  else { 
    $extra_desc = sprintf("%6d pass; %6d fail;", $npass, $nseq-$npass);
  }
  ofile_OutputProgressComplete($start_secs, $extra_desc, $log_FH, *STDOUT);
}

###################################################################
# 'fribo2' stage: stage that filters based on riboaligner.pl
###################################################################
my @rapass_seqorder_A = (); # order of sequences that pass rapass stage
my $ra_outdir = $out_root . "-ra";
my ($max_lpos, $min_rpos) = determine_riboaligner_lpos_rpos($family_modellen, \%opt_HH);
my $ra_full_stk_file = undef;
my $ra_tbl_out_file  = undef;
my %ignorems_seqfailstr_H = (); # copy of %seqfailstr_H as it existed after the mdlspan stage with mdlspan errors
                                        # removed. We use this to determine the set of PASSing seqs for the PASS mdlspan tbl 
my $ra_opt_p_sum_cpu_secs = 0; # seconds spent in parallel in riboaligner call, filled only if -p

if($do_fribo2) { 
  $stage_key = "fribo2";
  $start_secs = ofile_OutputProgressPrior("[Stage: $stage_key] Running riboaligner.pl", $progress_w, $log_FH, *STDOUT);
    
  my $ra_options = " -i $local_ra_modelinfo_file ";
  if(opt_IsUsed("-n",            \%opt_HH)) { $ra_options .= " -n " . opt_Get("-n", \%opt_HH); }
  if(opt_IsUsed("--noscfail",    \%opt_HH)) { $ra_options .= " --noscfail "; }
  if(opt_IsUsed("--nocovfail",   \%opt_HH)) { $ra_options .= " --nocovfail "; }
  if(opt_IsUsed("-p",            \%opt_HH)) { $ra_options .= " -p"; }
  if(opt_IsUsed("-q",            \%opt_HH)) { $ra_options .= " -q " . opt_Get("-q", \%opt_HH); }
  if(opt_IsUsed("--nkb",         \%opt_HH)) { $ra_options .= " --nkb " . opt_Get("--nkb", \%opt_HH); }
  if(opt_IsUsed("--wait",        \%opt_HH)) { $ra_options .= " --wait " . opt_Get("--wait", \%opt_HH); }
  if(opt_IsUsed("--errcheck",    \%opt_HH)) { $ra_options .= " --errcheck"; }
  my $ra_outdir_tail   = $dir_tail . ".ribodbmaker-ra";
  my $ra_out_file      = $out_root . ".riboaligner.out";
  $ra_full_stk_file = $ra_outdir . "/" . $ra_outdir_tail . ".riboaligner." . $family . ".cmalign.stk";
  $ra_tbl_out_file  = $ra_outdir . "/" . $ra_outdir_tail . ".riboaligner.tbl";
  $ra_full_stk_file = $ra_outdir . "/" . $ra_outdir_tail . ".riboaligner." . $family . ".cmalign.stk";  my $ra_uapos_lpos_tbl_file = $out_root . "." . $stage_key . ".uapos.lpos.tbl";
  my $ra_log_file  = $ra_outdir . "/" . $ra_outdir_tail . ".riboaligner.log";
  my $ra_uapos_rpos_tbl_file = $out_root . "." . $stage_key . ".uapos.rpos.tbl";
  my $ra_uapos_tbl_file      = $out_root . "." . $stage_key . ".uapos.tbl";
  my $uapos_lpos_cmd  = $execs_H{"ali-apos-to-uapos.pl"} . " --easeldir $env_riboeasel_dir $ra_full_stk_file $max_lpos > $ra_uapos_lpos_tbl_file";
  my $uapos_rpos_cmd  = $execs_H{"ali-apos-to-uapos.pl"} . " --easeldir $env_riboeasel_dir --after $ra_full_stk_file $min_rpos > $ra_uapos_rpos_tbl_file";

  my $ra_command = $execs_H{"riboaligner"} . " $ra_options --riboopts $local_ra_riboopts_file $full_fasta_file $ra_outdir > $ra_out_file";
  if(! $do_prvcmd) { ribo_RunCommand($ra_command, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
  ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "raout", "$ra_out_file", 0, "output of riboaligner");

  # if -p: parse the ribotyper log file to get CPU+wait time for parallel
  if(opt_Get("-p", \%opt_HH)) { 
    $ra_opt_p_sum_cpu_secs = ribo_ParseLogFileForParallelTime($ra_log_file, $ofile_info_HH{"FH"});
  }

  if(! $do_prvcmd) { ribo_RunCommand($uapos_lpos_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
  if(! $do_prvcmd) { ribo_RunCommand($uapos_rpos_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
  ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "ralpos", "$ra_uapos_lpos_tbl_file", 0, "unaligned position info that align at model position $max_lpos");
  ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "rarpos", "$ra_uapos_rpos_tbl_file", 0, "unaligned position info that align at model position $min_rpos");
  ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "rauapos", "$ra_uapos_tbl_file", 0, "unaligned position info that align at model positions $max_lpos and $min_rpos");

  # parse riboaligner tbl file
  my ($rt2_npass, $ra_npass, $ms_npass) = parse_riboaligner_tbl_and_uapos_files($ra_tbl_out_file, $ra_uapos_lpos_tbl_file, $ra_uapos_rpos_tbl_file, $ra_uapos_tbl_file, $do_fmspan, $do_fmspan_nogap, $family_modellen, \%seqfailstr_H, \@seqorder_A, \@rapass_seqorder_A, \%seqlpos_H, \%seqrpos_H, \%seqlenclass_H, \%opt_HH, \%ofile_info_HH);
  my $extra_desc = undef;
  if((opt_Get("-p", \%opt_HH)) && ($ra_opt_p_sum_cpu_secs > 0.)) { 
    $extra_desc = sprintf("%6d pass; %6d fail; (%.1f summed elapsed seconds for all jobs)", $rt2_npass, $nseq-$rt2_npass, $ra_opt_p_sum_cpu_secs);
  }
  else { 
    $extra_desc = sprintf("%6d pass; %6d fail;", $rt2_npass, $nseq-$rt2_npass);
  }
  ofile_OutputProgressComplete($start_secs, $extra_desc, $log_FH, *STDOUT);
    
  $start_secs = ofile_OutputProgressPrior("[Stage: $stage_key] Filtering out seqs riboaligner identified as too long", $progress_w, $log_FH, *STDOUT);
  ofile_OutputProgressComplete($start_secs, sprintf("%6d pass; %6d fail;", $ra_npass, $rt2_npass-$ra_npass), $log_FH, *STDOUT);

  # copy %seqfailstr_H here and remove any errors that are mdlspan errors,
  # we use this later when outputting the mdlspan survival PASS table we want
  # to consider all seqs that only failed due to mdlspan
  %ignorems_seqfailstr_H = %seqfailstr_H;
  if($do_fmspan) { 
    foreach my $target (sort keys %ignorems_seqfailstr_H) { 
      if($ignorems_seqfailstr_H{$target} ne "") { 
        my @err_str_A = split(";;", $ignorems_seqfailstr_H{$target});
        if((scalar(@err_str_A) == 1) && ($err_str_A[0] =~ m/^mdlspan/)) { 
          # only error is a mdlspan error, 
          $ignorems_seqfailstr_H{$target} = "";
        }
      }
    }
  }
  
  $stage_key = "fmspan";
  if($do_fmspan) { 
    $start_secs = ofile_OutputProgressPrior("[Stage: $stage_key] Filtering out seqs based on model span", $progress_w, $log_FH, *STDOUT);
    ofile_OutputProgressComplete($start_secs, sprintf("%6d pass; %6d fail;", $ms_npass, $ra_npass-$ms_npass), $log_FH, *STDOUT);
  }
}
else { # skipping riboaligner stage
  @rapass_seqorder_A = @seqorder_A; # since riboaligner stage was skipped, all sequences 'survive' it
}

# determine how many sequences at for each taxonomic group at level $level are still left
if($do_ftaxid || $do_ingrup || $do_special) { 
  foreach $level (@level_A) {
    parse_tax_level_file($taxinfo_wlevel_file_H{$level}, \%seqfailstr_H, undef, $surv_filters_level_ct_HH{$level}, $ofile_info_HH{"FH"});
  }
}
# end of filter stages

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# CHECKPOINT: save any sequences that survived all filter stages
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
$start_secs = ofile_OutputProgressPrior("[***Checkpoint] Creating lists that survived all filter stages", $progress_w, $log_FH, *STDOUT);
$npass_filters = update_and_output_pass_fails(\%seqfailstr_H, undef, \@seqorder_A, 0, $out_root, "surv_filters", \%ofile_info_HH); # 0: do not output description of pass/fail lists to log file
$nfail_filters = $nseq - $npass_filters; 
my $npass_filters_list = $out_root . ".surv_filters.pass.seqlist";
ofile_OutputProgressComplete($start_secs, sprintf("%6d pass; %6d fail; ONLY PASSES ADVANCE", $npass_filters, $nfail_filters), $log_FH, *STDOUT);

###############################################################################################################
# If --def, create the file with redefined sequence descriptions of sequences that survived all filter stages 
###############################################################################################################
my $def_fasta_file = $out_root . ".def.fa"; # need to define this here so it's in scope when we fetch final seqs from it
if($do_def) { 
  my $tmp_fasta_file = $out_root . ".tmp.def.fa";
  my $sfetch_cmd = $execs_H{"esl-sfetch"} . " -f $full_fasta_file $npass_filters_list > $tmp_fasta_file";
  if(! $do_prvcmd) { ribo_RunCommand($sfetch_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }

  fasta_rewrite_sequence_descriptions($tmp_fasta_file, $def_fasta_file, $family, \%seqlenclass_H, \%seqorgn_H, \%seqstrain_H, \%opt_HH, \%ofile_info_HH);

  # remove the temporary fasta file
  ribo_RemoveFileUsingSystemRm($tmp_fasta_file, "ribodbmaker.pl:main", \%opt_HH, $ofile_info_HH{"FH"});

  # index the new sequence file
  if(! $do_prvcmd) { ribo_RunCommand($execs_H{"esl-sfetch"} . " --index $def_fasta_file > /dev/null", opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
  ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, "RIBO", "defssi", $def_fasta_file . ".ssi", 0, ".ssi index file for def-rewritten fasta file");
}

# define file names for ingrup stage
$stage_key = "ingrup";
my $rfonly_stk_file    = $out_root . "." . $stage_key . ".rfonly.stk";
my $rfonly_alipid_file = $out_root . "." . $stage_key . ".rfonly.alipid";
my $rfonly_list_file   = $out_root . "." . $stage_key . ".seqlist";
#my $alimask_cmd = $execs_H{"esl-alimask"} .  " --rf-is-mask $ra_full_stk_file | " . $execs_H{"esl-alimanip"} . " --seq-k $npass_filters_list - > $rfonly_stk_file";
# construct the complicated esl-alimask command, masking to keep:
# - only RF columns
# - only seqs that pass all filters
# - only columns within minimum required mdlspan (unless --fullaln)
# - only columns that pass posterior probability thresholds (unless --noprob)
my $alimask_cmd = $execs_H{"esl-alimask"} .  " --rf-is-mask $ra_full_stk_file | " . $execs_H{"esl-alimanip"} . " --seq-k $npass_filters_list - ";
if(! opt_IsUsed("--fullaln", \%opt_HH)) { # have to mask by mdlspan BEFORE masking by posterior probs
  my ($max_lpos, $min_rpos) = determine_riboaligner_lpos_rpos($family_modellen, \%opt_HH);
  $alimask_cmd .= "| " . $execs_H{"esl-alimask"} . " -t --t-rf - " . $max_lpos . "-" . $min_rpos . " ";
}
if(! opt_IsUsed("--noprob", \%opt_HH)) { 
  $alimask_cmd .= "| " . $execs_H{"esl-alimask"} . " -p --pfract " . opt_Get("--pfract", \%opt_HH) . " --pthresh " . opt_Get("--pthresh", \%opt_HH) . " - "; 
}
$alimask_cmd .= "> $rfonly_stk_file";
my $alipid_cmd  = $execs_H{"esl-alipid"} . " $rfonly_stk_file | grep -v ^\# | awk '{ printf(\"\%s \%s \%s\\n\", \$1, \$2, \$3); }' > $rfonly_alipid_file"; # we will do this if $do_ingrup or $do_clustr
my %ingrup_lost_list_H        = (); # key is phylogenetic level $level, value is list of $level groups lost
my %alipid_analyze_out_file_H = (); # key is phylogenetic level $level, value is alipid_analyze output file
my %alipid_analyze_tab_file_H = (); # key is phylogenetic level $level, value is alipid_analyze output tab file
foreach $level (@level_A) {
  $ingrup_lost_list_H{$level}        = $out_root . "." . $stage_key . "." . $level . ".lost.list";
  $alipid_analyze_out_file_H{$level} = $out_root . "." . $stage_key . "." . $level . ".alipid_analyze.out";
  $alipid_analyze_tab_file_H{$level} = $out_root . "." . $stage_key . "." . $level . ".alipid.sum.tab.txt";
}
# if no sequences remain, we're done, skip remaining stages
if($npass_filters == 0) { 
  ofile_OutputString($log_FH, 1, "# Zero sequences survived all filters. Skipping remaining stages.\n");
}
else { 
  ###################################################################
  # 'ingrup' stage: stage that does the ingroup analysis on sequences
  #                 that passed all filter stages
  ###################################################################
  if($do_ingrup) { 
    $stage_key = "ingrup";
    my $create_list_cmd = undef;

    # merge alignments created by riboaligner with esl-alimerge and remove any seqs that have not
    # passed up to this point (using esl-alimanip --seq-k)
    my $alistat_cmd = $execs_H{"esl-alistat"} . " --list $rfonly_list_file $rfonly_stk_file > /dev/null";
    my %alipid_analyze_cmd_H = (); # key is level from @level_A (e.g. "class")
    foreach $level (@level_A) { 
      $alipid_analyze_cmd_H{$level} = $execs_H{"alipid-taxinfo-analyze.pl"} . " $rfonly_alipid_file $rfonly_list_file " . $taxinfo_wlevel_file_H{$level} . " $out_root.$stage_key.$level > " . $alipid_analyze_out_file_H{$level};
    }
      
    if(! $do_prvcmd) { ribo_RunCommand($alimask_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
    ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "rfonlystk", "$rfonly_stk_file", 0, "RF-column-only alignment");
      
    $start_secs = ofile_OutputProgressPrior("[Stage: $stage_key] Determining percent identities in alignments", $progress_w, $log_FH, *STDOUT);
    if(! $do_prvcmd) { ribo_RunCommand($alipid_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
    ofile_OutputProgressComplete($start_secs, undef, $log_FH, *STDOUT);
    ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "merged" . "alipid", "$rfonly_alipid_file", 0, "esl-alipid output for $rfonly_stk_file");
      
    if(! $do_prvcmd) { ribo_RunCommand($alistat_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
    ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "merged" . "list", "$rfonly_list_file", 0, "list of sequences in $rfonly_stk_file");
      
    $start_secs = ofile_OutputProgressPrior("[Stage: $stage_key] Performing ingroup analysis", $progress_w, $log_FH, *STDOUT);
    foreach $level (@level_A) {
      if(! $do_prvcmd) { ribo_RunCommand($alipid_analyze_cmd_H{$level}, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
      ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "alipid.analyze.$level", $alipid_analyze_out_file_H{$level}, 0, "$level output file from alipid-taxinfo-analyze.pl");
    }
    # we need an array that has only the sequences that PASS all filters and will be listed
    # in the alipid_analyze_tab_files, those sequences are listed in $rfonly_list_file, we make
    # an array of them here
    my @survfilters_seqorder_A = ();
    ribo_ReadFileToArray($rfonly_list_file, \@survfilters_seqorder_A, $ofile_info_HH{"FH"});
    my $cur_nfail = parse_alipid_analyze_tab_files(\%alipid_analyze_tab_file_H, \@level_A, \%seqfailstr_H, \@survfilters_seqorder_A, $out_root, \%opt_HH, \%ofile_info_HH);
    ofile_OutputProgressComplete($start_secs, sprintf("%6d pass; %6d fail;", scalar(@survfilters_seqorder_A) - $cur_nfail, $cur_nfail), $log_FH, *STDOUT);

    # determine how many sequences at for each taxonomic group at each level $level are still left
    foreach $level (@level_A) { 
      $start_secs = ofile_OutputProgressPrior("[Stage: $stage_key] Identifying " . pluralize_level($level) . " lost in ingroup analysis", $progress_w, $log_FH, *STDOUT);
      parse_tax_level_file($taxinfo_wlevel_file_H{$level}, \%seqfailstr_H, undef, $surv_ingrup_level_ct_HH{$level}, $ofile_info_HH{"FH"});
      
      # if there are any taxonomic groups at level $level that exist in the set of sequences that survived all filters but
      # than don't survive the ingroup test, output that
      my @ingrup_lost_gtaxid_A = (); # list of the group taxids that got lost in the ingroup analysis
      my $nlost = 0;
      open(LOST, ">", $ingrup_lost_list_H{$level}) || ofile_FileOpenFailure($ingrup_lost_list_H{$level}, $pkgstr, "ribodbmaker.pl:main()", $!, "writing", $ofile_info_HH{"FH"});
      foreach my $gtaxid (sort {$a <=> $b} keys (%{$surv_filters_level_ct_HH{$level}})) { 
        if($gtaxid != 0) { 
          if(($surv_filters_level_ct_HH{$level}{$gtaxid} > 0) && 
             ((! exists $surv_ingrup_level_ct_HH{$level}{$gtaxid}) || ($surv_ingrup_level_ct_HH{$level}{$gtaxid} == 0))) { 
            print LOST $gtaxid . "\n";
            $nlost++;
          }
        }
      }
      close LOST;
      ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "ingrup.lost.$level", $ingrup_lost_list_H{$level}, 1, sprintf("list of %d %s lost in the ingroup analysis", $nlost, pluralize_level($level)));
      ofile_OutputProgressComplete($start_secs, sprintf("%d %s lost", $nlost, pluralize_level($level)), $log_FH, *STDOUT);
    }

    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    # CHECKPOINT: save any sequences that survived to this point as the 'ingrup' set
    #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    $start_secs = ofile_OutputProgressPrior("[***Checkpoint] Creating lists that survived ingroup analysis", $progress_w, $log_FH, *STDOUT);
    $npass_ingrup = update_and_output_pass_fails(\%seqfailstr_H, undef, \@seqorder_A, 1, $out_root, "surv_ingrup", \%ofile_info_HH); # 1: do output description of pass/fail lists to log file
    $nfail_ingrup = $npass_filters - $npass_ingrup; 
    ofile_OutputProgressComplete($start_secs, sprintf("%6d pass; %6d fail; ONLY PASSES ADVANCE", $npass_ingrup, $nfail_ingrup), $log_FH, *STDOUT);
    $did_ingrup = 1;
  } # end of if($do_ingrup)

  ########################
  # mdlspan table creation
  ########################
  if($do_mstbl && $do_fribo2) { # we can't create the table if we skipped the ribo2 stage
    # create the mdlspan table file that gives number of seqs/groups surviving different possible model spans
    $start_secs = ofile_OutputProgressPrior("[***OutputFile] Generating model span survival tables for all seqs", $progress_w, $log_FH, *STDOUT);
    # first, create mdlspan table with counts of all sequences (PASSing or FAILing)
    parse_riboaligner_tbl_and_output_mdlspan_tbl($ra_tbl_out_file, $execs_H{"mdlspan-survtbl-sort.pl"}, $family_modellen, $out_root, undef, \%seqtaxid_H, \%seqgtaxid_HH, \%all_gtaxid_HA, \%opt_HH, \%ofile_info_HH);
    ofile_OutputProgressComplete($start_secs, undef, $log_FH, *STDOUT);
    # now we want to include any sequence that PASSES all filters *and* sequences that PASS all filters EXCEPT the mdlspan filter stage (fmspan)
    # we made a copy of %seqfailstr_H before fmspan stage, this will ALSO not include failures from the ingrup stage, but that's okay
    $start_secs = ofile_OutputProgressPrior("[***OutputFile] Generating model span survival tables for PASSing seqs", $progress_w, $log_FH, *STDOUT);
    parse_riboaligner_tbl_and_output_mdlspan_tbl($ra_tbl_out_file, $execs_H{"mdlspan-survtbl-sort.pl"}, $family_modellen, $out_root, \%ignorems_seqfailstr_H, \%seqtaxid_H, \%seqgtaxid_HH, \%all_gtaxid_HA, \%opt_HH, \%ofile_info_HH);
    ofile_OutputProgressComplete($start_secs, undef, $log_FH, *STDOUT);
  }

  ######################################################################################
  # 'clustr' stage: stage that clusters remaining sequences and picks a representative 
  ######################################################################################
  if($did_ingrup && ($npass_ingrup == 0)) { 
    ofile_OutputString($log_FH, 1, "# Zero sequences survived ingroup analysis. Skipping remaining stages.\n");
  }
  else { 
    if($do_clustr) { 
      my $stage_key = "clustr";
      $start_secs = ofile_OutputProgressPrior("[Stage: $stage_key] Clustering surviving sequences", $progress_w, $log_FH, *STDOUT);
      my $cluster_fid = opt_Get("--cfid", \%opt_HH);
      my $cluster_did = 1.0 - $cluster_fid;
      my $cluster_dist_file     = $out_root . "." . $stage_key . ".dist";
      my $cluster_out_file      = $out_root . "." . $stage_key . ".esl-cluster";
      my $cluster_in_list_file  = $out_root . "." . $stage_key . ".in.seqlist";
      my $cluster_out_list_file = $out_root . "." . $stage_key . ".out.seqlist";
      my $nin_clustr = 0;
      
      if(! $do_ingrup) { 
        # we did not yet run esl-alimask and esl-alipid, so do that now
        if(! $do_prvcmd) { ribo_RunCommand($alimask_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
        ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "rfonlystk", "$rfonly_stk_file", 0, "RF-column-only alignment");

        $start_secs = ofile_OutputProgressPrior("[Stage: $stage_key] Determining percent identities in alignments", $progress_w, $log_FH, *STDOUT);
        if(! $do_prvcmd) { ribo_RunCommand($alipid_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
        ofile_OutputProgressComplete($start_secs, undef, $log_FH, *STDOUT);
        ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "merged" . "alipid", "$rfonly_alipid_file", 0, "esl-alipid output for $rfonly_stk_file");
      }
      
      # determine sequences that will be clustered and create a list file for them for input to esl-cluster
      open(LIST, ">", $cluster_in_list_file) || ofile_FileOpenFailure($cluster_in_list_file, $pkgstr, "ribodbmaker.pl:main()", $!, "writing", $ofile_info_HH{"FH"});
      foreach $seqname (@seqorder_A) { 
        if($seqfailstr_H{$seqname} eq "") { # sequence has survived to the clustering step if it has a blank string in %seqfailstr_H
          print LIST $seqname . "\n";
          $is_centroid_H{$seqname}  = 0; #initialize to all seqs not centroids, then set values to 1 for those that are later after clustering
          $not_centroid_H{$seqname} = 1; #initialize to all seqs not centroids, then set values to 0 for those that are later after clustering
          $in_cluster_H{$seqname}   = -1; #initialize to all seqs not in a cluster, then set values in parse_alipid_to_choose_centroids
          $nin_clustr++;
        }
      }
      close(LIST);
      ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, $stage_key . ".inlist", "$cluster_in_list_file", 0, "list of sequences that survived to cluster stage");
      
      if($nin_clustr > 1) { # can't cluster with 1 sequence 
        # create the .dist file that we'll use as input to esl-cluster
        parse_alipid_output_to_create_dist_file($rfonly_alipid_file, \%not_centroid_H, $cluster_dist_file, $ofile_info_HH{"FH"}); 
        ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "cluster.dist", "$cluster_dist_file", 0, "distance file to use as input to esl-cluster");
        
        # cluster the sequences using esl-cluster
        my $clust_cmd = $execs_H{"esl-cluster"} . " -q 1 -t 2 -v 3 -x $cluster_did $cluster_in_list_file $cluster_dist_file > $cluster_out_file";
        if(! $do_prvcmd) { 
          ribo_RunCommand($clust_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); 
        }
        ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, $stage_key . ".esl-cluster", "$cluster_out_file",  0, "esl-cluster output file");
        
        # parse the esl-cluster output to get cluster assignments
        parse_esl_cluster_output($cluster_out_file, \%in_cluster_H, \%cluster_size_H, $ofile_info_HH{"FH"});
        
        # determine centroids
        parse_dist_file_to_choose_centroids($cluster_dist_file, $cluster_out_list_file, \%in_cluster_H, \%cluster_size_H, \%is_centroid_H, \%not_centroid_H, $ofile_info_HH{"FH"}); 
        ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, $stage_key . ".outlist", "$cluster_out_list_file", 0, "list of sequences selected as centroids by esl-cluster");
      }
      else { # only 1 sequence to cluster, it is its own cluster
        foreach $seqname (%is_centroid_H) { # only 1 of these guys
          $is_centroid_H{$seqname} = 1;
          $not_centroid_H{$seqname} = 0;
          $in_cluster_H{$seqname} = 1;
        }
      }
      
      ofile_OutputProgressComplete($start_secs, undef, $log_FH, *STDOUT);

      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      # CHECKPOINT: save any sequences that survived the clustering stage
      #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      $start_secs = ofile_OutputProgressPrior("[***Checkpoint] Creating lists of seqs that survived clustering", $progress_w, $log_FH, *STDOUT);
      $npass_clustr = update_and_output_pass_fails(\%not_centroid_H, undef, \@seqorder_A, 1, $out_root, "surv_clustr", \%ofile_info_HH); # 1: do output description of pass/fail lists to log file
      $nfail_clustr = $nin_clustr - $npass_clustr; 
      ofile_OutputProgressComplete($start_secs, sprintf("%6d pass; %6d fail;", $npass_clustr, $nfail_clustr), $log_FH, *STDOUT);
      
      # determine how many sequences at for each taxonomic group are still left
      if($do_ftaxid || $do_ingrup || $do_special) { 
        foreach $level (@level_A) { 
          parse_tax_level_file($taxinfo_wlevel_file_H{$level}, \%is_centroid_H, undef, $surv_clustr_level_ct_HH{$level}, $ofile_info_HH{"FH"});
        }
      }
      $did_clustr = 1;
    } # end of # if ($do_clustr)
  } # end of else entered if (! ($did_ingrup && ($npass_ingrup == 0))) 
} # end of else entered if $npass_filters > 0
# Define final set of sequences. 
# If $do_clustr, we need to create a hash for this that combines
# %seqfailstr_H and %is_centroid_H (b/c not being a centroid is not a
# 'failure')
my %not_final_H = ();
if($do_clustr) { 
  foreach $seqname (@seqorder_A) { 
    $not_final_H{$seqname} = (($seqfailstr_H{$seqname} eq "") && ($is_centroid_H{$seqname} eq "1")) ? 0 : 1;
  }
}
else { 
  foreach $seqname (@seqorder_A) { 
    $not_final_H{$seqname} = ($seqfailstr_H{$seqname} eq "") ? 0 : 1;
  }
}

my $npass_final = update_and_output_pass_fails(\%not_final_H, undef, \@seqorder_A, 1, $out_root, "final", \%ofile_info_HH); # 1: do output description of pass/fail lists to log file
my $final_list_file  = $out_root . ".final.pass.seqlist";
my $final_fasta_file = $out_root . ".final.fa";
if($npass_final > 0) { 
  # create the fasta file of the final sequences
  my $fa_fetch_file = ($do_def) ? $def_fasta_file : $full_fasta_file;
  my $sfetch_cmd = $execs_H{"esl-sfetch"} . " -f $fa_fetch_file $final_list_file > $final_fasta_file";
  if(! $do_prvcmd) { ribo_RunCommand($sfetch_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"}); }
  ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "final.fa", "$final_fasta_file", 1, "fasta file with final set of surviving sequences");
}

#####################################################################
# Create final output files:
# - taxonomy group count files, one per level
# - output file with failure strings per sequence, tabular version
# - output file with failure strings per sequence, readable version 
#   (whitepsace delimited) 
#####################################################################
# output taxonomy level count files
my %final_nsurv_H = (); # key: taxonomic level, value number of groups at this level that have >=1 surviving seq
my %final_nmiss_H = (); # key: taxonomic level, value number of groups at this level that have >=1 input seq but 0 surviving
foreach $level (@level_A) { 
  $final_nsurv_H{$level} = 0;
  $final_nmiss_H{$level} = 0;
  my $final_surv_str = ""; # comma separated list of all taxids that have >= 1 sequences
  my $final_miss_str = ""; # comma separated list of all taxids that have 0 sequences
  my $out_level_ct_file = $out_root . "." . $level . ".ct";
  open(LVL, ">", $out_level_ct_file) || ofile_FileOpenFailure($out_level_ct_file,  "RIBO", "ribodbmaker.pl:main()", $!, "writing", $ofile_info_HH{"FH"});
  print LVL ("#taxid-$level\tnum-input\tnum-survive-filters\tnum-survive-ingroup-analysis\tnum-survive-clustering\tnum-final\n");
  my $final_level_ct_HR = undef;
  if   ($did_clustr)  { $final_level_ct_HR = $surv_clustr_level_ct_HH{$level};  }
  elsif($did_ingrup)  { $final_level_ct_HR = $surv_ingrup_level_ct_HH{$level};  }
  else                { $final_level_ct_HR = $surv_filters_level_ct_HH{$level}; }
  foreach my $taxid (@{$all_gtaxid_HA{$level}}) { 
    printf LVL ("%s\t%s\t%s\t%s\t%s\t%s\n", 
                $taxid, 
                $full_level_ct_HH{$level}{$taxid}, 
                $surv_filters_level_ct_HH{$level}{$taxid}, 
                ($did_ingrup) ? $surv_ingrup_level_ct_HH{$level}{$taxid} : "-", 
                ($did_clustr) ? $surv_clustr_level_ct_HH{$level}{$taxid} : "-", 
                $final_level_ct_HR->{$taxid});
    if($final_level_ct_HR->{$taxid} > 0) { 
      $final_nsurv_H{$level}++; 
      if($final_surv_str ne "") { $final_surv_str .= ","; }
      $final_surv_str .= $taxid;
    }
    else { 
      $final_nmiss_H{$level}++; 
      if($final_miss_str ne "") { $final_miss_str .= ","; }
      $final_miss_str .= $taxid;
    }
  } 
  printf LVL ("# List of %d/%d taxids missing (0 surviving sequences) in final set:\n#%s\n", $final_nmiss_H{$level}, $final_nsurv_H{$level} + $final_nmiss_H{$level}, $final_miss_str eq "" ? "NONE" : $final_miss_str);
  printf LVL ("# List of %d/%d taxids represented by >= 1 sequence in final set:\n#%s\n", $final_nsurv_H{$level}, $final_nsurv_H{$level} + $final_nmiss_H{$level}, $final_surv_str eq "" ? "NONE" : $final_surv_str);
  close(LVL);
  ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "out.$level", "$out_level_ct_file", 1, "tab-delimited file listing number of sequences per $level taxid");
}

# output tabular output file
my $out_rdb_tbl = $out_root . ".rdb.tbl"; # name of tabular file
my $out_tab_tbl = $out_root . ".tab.tbl"; # name of tabular file
my $pass_fail   = undef; # string for pass/fail column
my $seqfailstr  = undef; # string for failure string column
my $cluststr    = undef; # string for cluster column
my $specialstr  = undef; # string for special column
my @column_explanation_A = (); 
push(@column_explanation_A, "# Explanation of columns:\n");
push(@column_explanation_A, "# Column  1: 'idx':     index of sequence in input file\n");
push(@column_explanation_A, "# Column  2: 'seqname': name of sequence\n");
push(@column_explanation_A, "# Column  3: 'seqlen':  length of sequence\n");
push(@column_explanation_A, "# Column  4: 'staxid':  taxid of sequence (species level), '-' if all taxid related steps were skipped\n");
push(@column_explanation_A, "# Column  5: 'otaxid':  taxid of sequence (order level), '-' if all taxid related steps were skipped\n");
push(@column_explanation_A, "# Column  6: 'ctaxid':  taxid of sequence (class level), '-' if all taxid related steps were skipped\n");
push(@column_explanation_A, "# Column  7: 'ptaxid':  taxid of sequence (phylum level), '-' if all taxid related steps were skipped\n");
push(@column_explanation_A, sprintf("# Column  8: 'p/f':     PASS if sequence passed all filters%s else FAIL\n", ($did_ingrup) ? " and ingroup analysis" : ""));
push(@column_explanation_A, sprintf("# Column  9: 'clust':   %s\n", ($did_clustr) ? "'C' if sequence selected as centroid of a cluster, 'NC' if not" : "'-' for all sequences due to --skipclustr or because 0 seqs survived clustering"));
push(@column_explanation_A, sprintf("# Column 10: 'special': %s\n", ($do_special) ? "*yes* if sequence belongs to special species taxid listed in --special input file, else '*no*'" : "'-' for all sequences because --special not used"));
push(@column_explanation_A, sprintf("# Column 11: 'failstr': %s\n", "'-' for PASSing sequences, else list of reasons for FAILure, see below"));
push(@column_explanation_A, "#\n");
push(@column_explanation_A, "# Possible substrings in 'failstr' column 11, each substring separated by ';;':\n");
if($do_fambig) { 
  push(@column_explanation_A, "# 'ambig[<d>]':            contains <d> ambiguous nucleotides, which exceeds maximum allowed\n");
}
if($do_ftaxid) { 
  push(@column_explanation_A, "# 'not-in-tax-tree':       sequence taxid is not present in the input NCBI taxonomy tree\n");
  push(@column_explanation_A, "# 'not-specified-species': sequence does not belong to a specified species according to NCBI taxonomy\n");
}
if($do_fvecsc) { 
  push(@column_explanation_A, "# 'vecscreen-match[<s>]':  vecscreen reported match to vector of strength <s>\n");
}
if($do_fblast) { 
  push(@column_explanation_A, "# 'blastrepeat[<s>]':      repetitive sequence identified by blastn\n");
  push(@column_explanation_A, "#                          <s> = <s1>,<s2>,...<sI>...<sN> for N >= 1, where\n");
  push(@column_explanation_A, "#                          <sI> = <c1>|e=<g1>|len=<d1>|<d2>..<d3>/<d4>..<d5>|pid=<f1>|ngap=<d6>\n");
  push(@column_explanation_A, "#                          <c1> = + for positive strand, - for negative strand\n");
  push(@column_explanation_A, "#                          <g1> = E-value of hit\n");
  push(@column_explanation_A, "#                          <d1> = maximum of query length and subject length in hit alignment\n");
  push(@column_explanation_A, "#                          <d2>..<d3> = query coordinates of hit\n");
  push(@column_explanation_A, "#                          <d4>..<d5> = subject coordinates of hit\n");
  push(@column_explanation_A, "#                          <f1> = fractional identity of hit alignment\n");
  push(@column_explanation_A, "#                          <d6> = number of gaps in hit alignment\n");
}
if($do_fribo1) { 
  push(@column_explanation_A, "# 'ribotyper1[<s>]:        ribotyper (round 1) failure with unexpected features listed in <s>\n");
  push(@column_explanation_A, "#                          see $out_root-rt/$dir_tail-rt.ribotyper.long.out\n");
  push(@column_explanation_A, "#                          for explanation of unexpected features\n");
}
if($do_fribo2) { 
  push(@column_explanation_A, "# 'ribotyper2[<s>]:        ribotyper (riboaligner) failure with unexpected features listed in <s>\n");
  push(@column_explanation_A, "#                          see $out_root-ra/$dir_tail-ra.ribotyper.long.out\n");
  push(@column_explanation_A, "#                          for explanation of unexpected features\n");
  push(@column_explanation_A, "# 'riboaligner[<s>]:       riboaligner failure because sequence is too long or potentially too long\n");
  push(@column_explanation_A, "#                          <s>=full-extra:        alignment spans full model with >= 1 nt extra on 5' or 3' end\n");
  push(@column_explanation_A, "#                          <s>=full-ambig-more:   alignment spans full model with 0 nt extra on 5' or 3' end but\n");
  push(@column_explanation_A, "#                                                 has indels in first and/or final 10 model positions and\n");
  push(@column_explanation_A, "#                                                 insertions outnumber deletions at 5' and/or 3' end\n");
  push(@column_explanation_A, "#                          <s>=5flush-extra:      alignment extends to first but not final model position\n");
  push(@column_explanation_A, "#                                                 with >= 1 nt extra before first model position\n");
  push(@column_explanation_A, "#                          <s>=5flush-ambig-more: alignment extends to first but not final model position\n");
  push(@column_explanation_A, "#                                                 and has indels in first 10 model positions and\n");
  push(@column_explanation_A, "#                                                 insertions outnumber deletions at 5' end\n");
  push(@column_explanation_A, "#                          <s>=3flush-extra:      alignment extends to final but not first model position\n");
  push(@column_explanation_A, "#                                                 with >= 1 nt extra after final model position\n");
  push(@column_explanation_A, "#                          <s>=3flush-ambig-more: alignment extends to final but not first model position\n");
  push(@column_explanation_A, "#                                                 and has indels in final 10 model positions and\n");
  push(@column_explanation_A, "#                                                 insertions outnumber deletions at 3' end\n");
}
if($do_fmspan) { 
  push(@column_explanation_A, "# 'mdlspan[<d1>-<d2>]:     alignment of sequence does not span required model positions, model span is <d1> to <d2>\n");
  if($do_fmspan_nogap) { 
    push(@column_explanation_A, "# 'mdlspan-gap[<s>]:     <s>='gap-at-<d>' alignment of sequence has a gap at required boundary position <d> (and --fmnogap used)\n");
  }
}
if($do_ingrup) { 
  push(@column_explanation_A, "# 'ingroup-analysis[<s>]:  sequence failed ingroup analysis\n");
  push(@column_explanation_A, "#                          if <s> includes 'type=<s1>', sequence was classified as type <s1>\n");
  push(@column_explanation_A, "#                          see " . $alipid_analyze_out_file_H{"order"} . " for explanation of types\n");
  if(opt_Get("--fione", \%opt_HH)) { 
    push(@column_explanation_A, "#                          if <s> includes 'not-max-avg-pid', a different sequence with the\n");
    push(@column_explanation_A, "#                          same taxid (species) had a higher average percent identity to all\n");
    push(@column_explanation_A, "#                          other sequences in its taxonomic group than this one did\n");
    push(@column_explanation_A, "#                          at the most specific level that is defined out of order/class/phylum\n");
    if(opt_IsUsed("--fimin", \%opt_HH)) { 
      push(@column_explanation_A, "#                          if <s> includes 'too-few-in-species-taxid', there were fewer than\n");
      push(@column_explanation_A, sprintf("#                          %d sequences with the species taxid of this sequence (that were not\n", opt_Get("--fimin", \%opt_HH)));
      push(@column_explanation_A, "#                          of O type), as enforced by the --fimin option\n");
    }
  }
}

open(RDB, ">", $out_rdb_tbl) || ofile_FileOpenFailure($out_rdb_tbl,  "RIBO", "ribodbmaker.pl:main()", $!, "writing", $ofile_info_HH{"FH"});
open(TAB, ">", $out_tab_tbl) || ofile_FileOpenFailure($out_tab_tbl,  "RIBO", "ribodbmaker.pl:main()", $!, "writing", $ofile_info_HH{"FH"});
foreach my $column_explanation_line (@column_explanation_A) { 
  print RDB $column_explanation_line;
  print TAB $column_explanation_line;
}  
if($width_H{"index"} < 4) { $width_H{"index"} = 4; }
printf RDB ("#%*s  %-*s  %*s  %7s  %7s  %7s  %7s  %4s  %5s  %7s  %s\n", $width_H{"index"}-1, "idx", $width_H{"target"}, "seqname", $width_H{"length"}, "seqlen", "staxid", "otaxid", "ctaxid", "ptaxid", "p/f", "clust", "special", "failstr");
printf TAB ("#%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", "idx", "seqname", "seqlen", "staxid", "otaxid", "ctaxid", "ptaxid", "p/f", "clust", "special", "failstr");
my $taxid2print = undef;
my $otaxid2print = undef;
my $ctaxid2print = undef;
my $ptaxid2print = undef;
foreach $seqname (@seqorder_A) { 
  if($seqfailstr_H{$seqname} eq "") { 
    $pass_fail  = "PASS";
    $seqfailstr = "-";
    if($did_clustr) { $cluststr = $is_centroid_H{$seqname} ? "C" : "NC"; }
    else            { $cluststr = "-"; }
  }
  else { 
    $pass_fail = "FAIL";
    $seqfailstr = $seqfailstr_H{$seqname};
    $cluststr = "-";
  }

  if($do_special) { $specialstr = ($taxid_is_special_H{$seqtaxid_H{$seqname}}) ? "*yes*" : "*no*"; }
  else            { $specialstr = "-"; }

  $taxid2print  = ($have_taxids) ? $seqtaxid_H{$seqname} : "-";
  $otaxid2print = ($have_taxids) ? $seqgtaxid_HH{"order"}{$seqname} : "-";
  $ctaxid2print = ($have_taxids) ? $seqgtaxid_HH{"class"}{$seqname} : "-";
  $ptaxid2print = ($have_taxids) ? $seqgtaxid_HH{"phylum"}{$seqname} : "-";

  printf RDB ("%-*s  %-*s  %*d  %7s  %7s  %7s  %7s  %4s  %5s  %7s  %s\n", $width_H{"index"}, $seqidx_H{$seqname}, $width_H{"target"}, $seqname, $width_H{"length"}, $seqlen_H{$seqname}, $taxid2print, $otaxid2print, $ctaxid2print, $ptaxid2print, $pass_fail, $cluststr, $specialstr, $seqfailstr);
  printf TAB ("%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $seqidx_H{$seqname}, $seqname, $seqlen_H{$seqname}, $taxid2print, $otaxid2print, $ctaxid2print, $ptaxid2print, $pass_fail, $cluststr, $specialstr, $seqfailstr);
}
close(RDB);
close(TAB);
ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "tabtbl", $out_tab_tbl, 1, "tab-delimited tabular output summary file");
ofile_AddClosedFileToOutputInfo(\%ofile_info_HH, $pkgstr, "rdbtbl", $out_rdb_tbl, 1, "whitespace-delimited, more readable output summary file");

##########
# Conclude
##########
# final stats on number of sequences passing each stage
ofile_OutputString($log_FH, 1, "#\n");
ofile_OutputString($log_FH, 1, sprintf("%-70s  %7d  [listed in %s]\n", "# Number of input sequences:", $nseq, $full_list_file));
ofile_OutputString($log_FH, 1, sprintf("%-70s  %7d  [listed in %s]\n", "# Number surviving all filter stages:", $npass_filters, $out_root . ".surv_filters.pass.seqlist"));
if($do_ingrup) { 
  ofile_OutputString($log_FH, 1, sprintf("%-70s  %7d  [listed in %s]\n", "# Number surviving ingroup analysis:", $npass_ingrup, $out_root . ".surv_ingrup.pass.seqlist"));
}
if($do_clustr) { 
  ofile_OutputString($log_FH, 1, sprintf("%-70s  %7d  [listed in %s]\n", "# Number surviving clustering (number of clusters):", $npass_clustr, $out_root . ".surv_clustr.pass.seqlist"));
}
ofile_OutputString($log_FH, 1, sprintf("%-70s  %7d  [listed in %s]\n", "# Number in final set of surviving sequences:", $npass_final, $final_list_file));
foreach $level (@level_A) { 
  ofile_OutputString($log_FH, 1, sprintf("%-70s  %7d  [listed in final line of %s]\n", sprintf("# Number of %-7s represented in final set of surviving sequences:", pluralize_level($level)), $final_nsurv_H{$level}, $out_root . "." . $level . ".ct"));
}
$total_seconds += ribo_SecondsSinceEpoch();

if(opt_Get("-p", \%opt_HH)) { 
  ofile_OutputString($log_FH, 1, "#\n");
  ofile_OutputString($log_FH, 1, sprintf("# Elapsed time below does not include summed elapsed time of multiple jobs [-p], totalling %s (does not include waiting time)\n", ribo_GetTimeString($rt_opt_p_sum_cpu_secs + $ra_opt_p_sum_cpu_secs)));
  ofile_OutputString($log_FH, 1, "#\n");
}

ofile_OutputConclusionAndCloseFiles($total_seconds, $pkgstr, $dir, \%ofile_info_HH);
exit 0;

#####################################################################
# SUBROUTINES 
#####################################################################
# List of subroutines:
#
# Subroutines for parsing files created by the various stages
# parse_srcchk_and_tax_files_for_specified_species
# parse_parse_vecscreen_combined_file
# parse_ribotyper_short_file
# parse_riboaligner_tbl_file
# parse_blast_output_for_self_hits
# parse_alipid_analyze_tab_files
# parse_alipid_output_to_create_dist_file
# parse_dist_file_to_choose_centroids
# parse_esl_cluster_output
# parse_srcchk_file
# parse_tax_level_file
# 
# Other subroutines:
# reformat_sequence_names_in_fasta_file
# filter_list_file
# update_and_output_pass_fails
# fblast_stage
#
#################################################################
# Subroutine:  parse_srcchk_and_tax_files_for_specified_species()
# Incept:      EPN, Tue Jun 12 13:51:51 2018
#
# Purpose:     Parse a tab delimited tax file that includes
#              as its fourth column a '1' if the sequence is
#              from a 'specified species' and '0' if it is not,
#              and save information for those that are not from 
#              specified species in %{$failstr_HR}.
#
# Arguments:
#   $srcchk_file:    name of srcchk output file to parse
#   $tax_file:       name of tax file to parse
#   $seqtaxid_HR:    ref to hash of taxids of each sequence
#   $seqfailstr_HR:  ref to hash of failure string to add to here
#   $seqorder_AR:    ref to array of sequences in order
#   $out_root:       for naming output files
#   $opt_HHR:        reference to 2D hash of cmdline options
#   $ofile_info_HHR: ref to the ofile info 2D hash
#
# Returns:    Number of sequences that pass.
#
# Dies:       if a sequence is not in the $tax_file
#################################################################
sub parse_srcchk_and_tax_files_for_specified_species { 
  my $sub_name = "parse_srcchk_and_tax_files_for_specified_species";
  my $nargs_expected = 8;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($srcchk_file, $tax_file, $seqtaxid_HR, $seqfailstr_HR, $seqorder_AR, $out_root, $opt_HHR, $ofile_info_HHR) = (@_);

  my %specified_species_H = ();
  my %curfailstr_H = ();  # will hold fail string 
  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience
  my $seqname;

  my $do_strict = opt_Get("--ftstrict", \%opt_HH);

  ribo_InitializeHashToEmptyString(\%curfailstr_H, $seqorder_AR);

  foreach $seqname (@{$seqorder_AR}) { 
    if(! exists $seqtaxid_HR->{$seqname}) { 
      ofile_FAIL("ERROR in $sub_name, no taxid information for $seqname in passed in %seqtaxid_H", "RIBO", $?, $FH_HR);
    }
    $specified_species_H{$seqtaxid_HR->{$seqname}} = -1; 
  }

  # read tax_file and fill specified_species_H{} for existing taxid keys read from srcchk_file
  open(TAX, $tax_file) || ofile_FileOpenFailure($tax_file,  "RIBO", $sub_name, $!, "reading", $FH_HR);
  while($line = <TAX>) { 
    #1	1	no rank	1	0	0
    #2	131567	superkingdom	3	1	0
    #6	335928	genus	8	1	0
    #7	6	species	9	1	1
    #9	32199	species	9	1	1
    #10	1706371	genus	8	1	0
    chomp $line;
    my @el_A = split(/\t/, $line);
    if(scalar(@el_A) != 6) { 
      ofile_FAIL("ERROR in $sub_name, tax file line did not have exactly 6 tab-delimited tokens: $line\n", "RIBO", $?, $FH_HR);
    }
    my ($taxid, $parent_taxid, $rank, undef, undef, $specified_species) = @el_A;
    if(exists $specified_species_H{$taxid}) { 
      $specified_species_H{$taxid} = $specified_species; 
    }
  }
  close(TAX);
    
  # go through srrchk_file to determine if each sequence passes or fails
  open(SRCCHK, $srcchk_file)  || ofile_FileOpenFailure($srcchk_file,  "RIBO", $sub_name, $!, "reading", $FH_HR);
  my $diestr = ""; # if $do_strict and we add to this below for >= 1 sequences, we will fail after going through the full file
  # first line is header, determine max number of fields we should see based on this
  #accession  taxid   organism
  # OR 
  #accession	taxid	organism	strain	strain#2	
  my $header_line = <SRCCHK>;
  my @el_A = split(/\t/, $header_line);
  my $max_nel = scalar(@el_A); 
  while($line = <SRCCHK>) { 
    #KJ925573.1100272uncultured eukaryote
    #FJ552229.1221169uncultured Gemmatimonas sp.
    chomp $line;
    @el_A = split(/\t/, $line);
    if((scalar(@el_A) < 3) || (scalar(@el_A) > $max_nel)) { 
      ofile_FAIL("ERROR in $sub_name, srcchk file line did not have at least 3 and no more than $max_nel tab-delimited tokens: $line\n", "RIBO", $?, $FH_HR);
    }
    my $accver = $el_A[0];
    my $taxid  = $el_A[1];
    if($specified_species_H{$taxid} == -1) { 
      if($do_strict) { $diestr .= "taxid: $taxid, accession: $accver\n"; }
      else           { $curfailstr_H{$accver} = "not-in-taxtree;;"; }
    }
    elsif($specified_species_H{$taxid} == 0) { 
      $curfailstr_H{$accver} = "not-specified-species;;";
    }
    elsif($specified_species_H{$taxid} != 1) { 
      ofile_FAIL("ERROR in $sub_name, tax file had unexpected value (not '0' or '1') for specified species for taxid $taxid ($accver)", "RIBO", $?, $FH_HR);
    }
  }
  close(SRCCHK);

  if($diestr ne "") { 
    ofile_FAIL("ERROR in $sub_name, >= 1 taxids for sequences in sequence file had no tax information in $tax_file (remove --ftstrict to allow this):\n$diestr", "RIBO", $?, $FH_HR);
  }

  # now output pass and fail files
  return update_and_output_pass_fails(\%curfailstr_H, $seqfailstr_HR, $seqorder_AR, 0, $out_root, "ftaxid", $ofile_info_HHR); # 0: do not output description of pass/fail lists to log file
  
}

#################################################################
# Subroutine:  parse_parse_vecscreen_combined_files()
# Incept:      EPN, Wed Jun 20 15:05:28 2018
#
# Purpose:     Parse output file from parse_vecscreen.pl followed
#              by combine_summaries.pl.
#
# Arguments:
#   $parse_vecscreen_combined_file: name of parse_vecscreen_combined output file
#   $seqfailstr_HR:                 ref to hash of failure string to add to here
#   $seqorder_AR:                   ref to array of sequences in order
#   $out_root:                      for naming output files
#   $opt_HHR:                       reference to 2D hash of cmdline options
#   $ofile_info_HHR:                ref to the ofile info 2D hash
#
# Returns:    Number of sequences that pass.
#
# Dies:       if a sequence in $parse_vecscreen_combined_file is not in @{$seqorder_AR}
#################################################################
sub parse_parse_vecscreen_combined_file { 
  my $sub_name = "parse_parse_vecscreen_combined_file()";
  my $nargs_expected = 6;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($parse_vecscreen_combined_file, $seqfailstr_HR, $seqorder_AR, $out_root, $opt_HHR, $ofile_info_HHR) = (@_);

  my %curfailstr_H = ();  # will hold fail string 
  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience
  my $seqname;

  ribo_InitializeHashToEmptyString(\%curfailstr_H, $seqorder_AR);

  open(VEC, $parse_vecscreen_combined_file)  || ofile_FileOpenFailure($parse_vecscreen_combined_file, "RIBO", $sub_name, $!, "reading", $FH_HR);
  #AY803752.1	3	18	uv|DQ391279.1:11528-12003	345	360	Weak	Weak	Suspect[1,2];
  while(my $line = <VEC>) { 
    chomp $line;
    my @el_A = split(/\t/, $line);
    if(scalar(@el_A) != 9) { 
      ofile_FAIL("ERROR in $sub_name, parse_vecscreen combined output line in $parse_vecscreen_combined_file does not have the expected 9 tab-delimited fields\n", "RIBO", $?, $FH_HR); 
    }
    my ($seqname, $strength) = ($el_A[0], $el_A[6]);
    if($el_A[6] ne "Weak") { 
      $curfailstr_H{$seqname} = "vecscreen-match[$strength];;";
    }
  }
  close(VEC);

  # now output pass and fail files
  return update_and_output_pass_fails(\%curfailstr_H, $seqfailstr_HR, $seqorder_AR, 0, $out_root, "fvecsc", $ofile_info_HHR); # 0: do not output description of pass/fail lists to log file
  
  return;
}

#################################################################
# Subroutine:  parse_ribotyper_short_file()
# Incept:      EPN, Fri Jun 29 15:25:03 2018
#
# Purpose:     Parse a short tbl output file from ribotyper.pl
#
# Arguments:
#   $in_file:             name of input tbl file to parse
#   $seqfailstr_HR:       ref to hash of failure string to add to here
#   $seqorder_AR:         ref to array of sequences in order
#   $opt_HHR:             ref to 2D hash of cmdline options
#   $ofile_info_HHR:      ref to the ofile info 2D hash
#
# Returns:    Number of sequences that pass
#
# Dies:       if format of ribotyper short file is unexpected
# 
#################################################################
sub parse_ribotyper_short_file { 
  my $sub_name = "parse_ribotyper_short_file()";
  my $nargs_expected = 5;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($in_file, $seqfailstr_HR, $seqorder_AR, $opt_HHR, $ofile_info_HHR) = (@_);

  my %curfailstr_H = ();  # will hold fail string 
  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience
  my $seqname;

  ribo_InitializeHashToEmptyString(\%curfailstr_H, $seqorder_AR);

  open(IN, $in_file)  || ofile_FileOpenFailure($in_file, "RIBO", $sub_name, $!, "reading", $FH_HR);
  # first line is header
  my $line = <IN>;
  while($line = <IN>) { 
    if($line !~ m/^\#/) { 
      ##idx  target      classification         strnd   p/f  unexpected_features
      ##---  ----------  ---------------------  -----  ----  -------------------
      #1     KJ757513.1  SSU.Eukarya            plus   PASS  -
      #2     HQ659972.1  SSU.Eukarya            plus   PASS  -
      #3     AF019063.1  SSU.Eukarya            plus   PASS  -
      #4     MF683578.1  SSU.Eukarya            plus   FAIL  *LowCoverage:(0.926<0.990);*MultipleHits:(2);
      chomp $line;
      my @el_A = split(/\s+/, $line);
      if(scalar(@el_A) != 6) { 
        ofile_FAIL("ERROR in $sub_name, tab file line did not have exactly 6 tab-delimited tokens: $line\n", "RIBO", $?, $FH_HR);
      }
      my ($seqname, $pass_fail, $ufeatures) = ($el_A[1], $el_A[4], $el_A[5]);
      if(! exists $curfailstr_H{$seqname}) { ofile_FAIL("ERROR in $sub_name, unexpected sequence name read: $seqname", "RIBO", 1, $FH_HR); }
      if($pass_fail eq "FAIL") { 
        $curfailstr_H{$seqname} = "ribotyper1[" . $ufeatures . "];;";
      }
    }
  }
  close(IN);

  # now output pass and fail files
  return update_and_output_pass_fails(\%curfailstr_H, $seqfailstr_HR, $seqorder_AR, 1, $out_root, "ribo1", $ofile_info_HHR); # 1: do not require all seqs in seqorder exist in %curfailstr_H
}

#################################################################
# Subroutine:  parse_riboaligner_tbl_and_uapos_files()
# Incept:      EPN, Wed May 30 14:11:47 2018
#
# Purpose:     Parse a tbl output file from riboaligner.pl and
#              two files output from ali-apos-to-uapos.pl and
#              determine which sequences pass and which fail.
#
# Arguments:
#   $ra_tbl_file:            name of input riboaligner tbl file to parse
#   $lpos_tbl_file:          name of input ali-apos-to-uapos lpos tbl file to parse
#   $rpos_tbl_file:          name of input ali-apos-to-uapos rpos tbl file to parse
#   $uapos_out_file:         name of output file to create as a combination of $lpos_tbl_file and $rpos_tbl_file
#   $do_fmspan:              '1' to filter based on model span too
#   $do_fmspan_strict:       '1' to fail sequences that have a gap at either $max_lpos or $min_rpos
#   $mlen:                   model length 
#   $seqfailstr_HR:          ref to hash of failure string to add to here
#   $seqorder_AR:            ref to array of sequences in order
#   $rapass_seqorder_AR:     ref to array of sequences in order
#   $seq_uapos_lpos_HR:      ref to hash of unaligned positions that align to left model span position
#   $seq_uapos_rpos_HR:      ref to hash of unaligned positions that align to right model span position
#   $seqlenclass_HR:         ref to hash of length classes, can be undef
#   $opt_HHR:                ref to 2D hash of cmdline options
#   $ofile_info_HHR:         ref to the ofile info 2D hash
#
# Returns:    3 values:
#             $rt_npass:  number of sequences that pass ribotyper stage
#             $ra_npass: number of sequences that pass riboaligner stage
#             $ms_npass:  number of sequences that pass model span stage
#
# Dies:       if options are unexpected
#             if unable to parse a tabular line
#             in there's no model length for an observed classification
# 
#################################################################
sub parse_riboaligner_tbl_and_uapos_files { 
  my $sub_name = "parse_riboaligner_tbl_and_uapos_files()";
  my $nargs_expected = 15;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($ra_tbl_file, $lpos_tbl_file, $rpos_tbl_file, $uapos_out_file, $do_fmspan, $do_fmspan_strict, $mlen, $seqfailstr_HR, $seqorder_AR, $rapass_seqorder_AR, $seq_uapos_lpos_HR, $seq_uapos_rpos_HR, $seqlenclass_HR, $opt_HHR, $ofile_info_HHR) = (@_);

  my %rt_curfailstr_H   = (); # holds fail strings for ribotyper
  my %ra_curfailstr_H   = (); # holds fail strings for riboaligner
  my %ms_curfailstr_H   = (); # holds fail strings for model span stage
  my @rtpass_seqorder_A = (); # array of sequences that pass ribotyper stage, in order
  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience

  ribo_InitializeHashToEmptyString(\%rt_curfailstr_H,  $seqorder_AR);
  # for %ra_curfailstr_H, we only do pass/fail for those that survive ribotyper
  # for %ms_curfailstr_H,  we only do pass/fail for those that survive ribotyper and riboaligner
  # so we can't initialize those yet, we will fill in the FAILs and PASSes as we see them in the output
  
  # determine maximum 5' start position and minimum 3' stop position required to be kept
  my ($max_lpos, $min_rpos) = determine_riboaligner_lpos_rpos($mlen, $opt_HHR); 

  # parse the lpos and rpos tbl files
  my %seq_lgap_H; # key is sequence name, value is either 'gap' or 'nongap', read from $lpos_tbl_file
  my %seq_rgap_H; # key is sequence name, value is either 'gap' or 'nongap', read from $rpos_tbl_file
  parse_ali_apos_to_uapos_file($lpos_tbl_file, $seq_uapos_lpos_HR, \%seq_lgap_H, $opt_HHR, $ofile_info_HHR);
  parse_ali_apos_to_uapos_file($rpos_tbl_file, $seq_uapos_rpos_HR, \%seq_rgap_H, $opt_HHR, $ofile_info_HHR);
  combine_ali_apos_to_uapos_files($uapos_out_file, $max_lpos, $min_rpos, $seqorder_AR, $seq_uapos_lpos_HR, \%seq_lgap_H, $seq_uapos_rpos_HR, \%seq_rgap_H, $ofile_info_HHR);

  # parse each line of the riboaligner output file
  open(RATBL, $ra_tbl_file)  || ofile_FileOpenFailure($ra_tbl_file,  "RIBO", $sub_name, $!, "reading", $FH_HR);
  my $nlines = 0;

  my $line;
  while($line = <RATBL>) { 
    ##idx  target      classification         strnd   p/f  mstart   mstop  length_class  unexpected_features
    ##---  ----------  ---------------------  -----  ----  ------  ------  ------------  -------------------
    #1     Z36893.1    SSU.Eukarya            plus   PASS       1    1851    full-exact  -
    #2     Z26765.1    SSU.Eukarya            plus   PASS       1    1851    full-exact  -
    #3     X74753.1    SSU.Eukarya            plus   FAIL       -       -             -  *LowCoverage:(0.831<0.860);MultipleHits:(2);
    #4     X51542.1    SSU.Eukarya            plus   FAIL       -       -             -  *LowScore:(0.09<0.50);*LowCoverage:(0.085<0.860);
    #5     X66111.1    SSU.Eukarya            plus   FAIL       -       -             -  *LowScore:(0.01<0.50);*LowCoverage:(0.019<0.860);
    #6     X56532.1    SSU.Eukarya            plus   PASS       1    1849       partial  -
    #7     AY572456.1  SSU.Eukarya            plus   PASS       1    1851    full-exact  -
    #8     AY364851.1  SSU.Eukarya            plus   PASS      35    1816       partial  -
    if($line !~ m/^\#/) { 
      chomp $line;
      my @el_A = split(/\s+/, $line);
      if(scalar(@el_A) != 9) { 
        ofile_FAIL("ERROR in $sub_name, ra tblout file line did not have exactly 9 space-delimited tokens: $line\n", "RIBO", $?, $FH_HR);
      }
      my ($idx, $target, $class, $strand, $passfail, $mstart, $mstop, $lclass, $ufeatures) = @el_A;
      $nlines++;

      # add to failstr if necessary
      if($passfail eq "FAIL") { 
        $rt_curfailstr_H{$target} = "ribotyper2[" . $ufeatures . "];;";
      }
      else { # $passfail eq "PASS"
        # check for riboaligner fail
        if(defined $seqlenclass_HR) { $seqlenclass_HR->{$target} = $lclass; }
        if(($lclass eq "full-extra")        || 
           ($lclass eq "full-ambig-more")   || 
           ($lclass eq "5flush-extra")      || 
           ($lclass eq "5flush-ambig-more") || 
           ($lclass eq "3flush-extra")      || 
           ($lclass eq "3flush-ambig-more")) { 
          $ra_curfailstr_H{$target} = "riboaligner[" . $lclass . "];;";
        }
        else { 
          $ra_curfailstr_H{$target} = "";
          
          # check for model span fail
          if($do_fmspan) { 
            if(($mstart > $max_lpos) || ($mstop < $min_rpos)) { 
              $ms_curfailstr_H{$target} = "mdlspan[" . $mstart . "-" . $mstop . "];;";
            }
            else { 
              $ms_curfailstr_H{$target} = "";
              # check if the sequence aligns to a gap at the lpos or rpos
              if($do_fmspan_strict) { 
                my $tmp_gap_str = "";
                if(! exists $seq_lgap_H{$target}) { 
                  ofile_FAIL("ERROR in $sub_name, $target not in $lpos_tbl_file", "RIBO", $?, $FH_HR);
                }
                if(! exists $seq_rgap_H{$target}) { 
                  ofile_FAIL("ERROR in $sub_name, $target not in $rpos_tbl_file", "RIBO", $?, $FH_HR);
                }
                if($seq_lgap_H{$target} eq "gap") { 
                  $tmp_gap_str .= "gap-at-" . $max_lpos;
                }
                if($seq_rgap_H{$target} eq "gap") { 
                  if($tmp_gap_str ne "") { $tmp_gap_str .= ","; }
                  $tmp_gap_str .= "gap-at-" . $min_rpos;
                }
                if($tmp_gap_str ne "") { 
                  $ms_curfailstr_H{$target} = "mdlspan-gap[" . $tmp_gap_str . "];;";
                }
              }
            }
          }
        }
      }
    }
  }
  close(RATBL);

  
  # fill @rtpass_seqorder_A and @{$rapass_seqorder_AR}
  @rtpass_seqorder_A     = ();
  @{$rapass_seqorder_AR} = ();
  my $seqname;
  foreach $seqname (@{$seqorder_AR}) { 
    if(exists $ra_curfailstr_H{$seqname}) { 
      push(@rtpass_seqorder_A, $seqname); 
      if((! $do_fmspan) || (exists $ms_curfailstr_H{$seqname})) { 
        push(@{$rapass_seqorder_AR}, $seqname);
      }
    }
  }

  my $rt_npass  = update_and_output_pass_fails(\%rt_curfailstr_H,  $seqfailstr_HR, $seqorder_AR,         0, $out_root, "fribty", \%ofile_info_HH); # 0: do not output description of pass/fail lists to log file
  my $ra_npass = update_and_output_pass_fails(\%ra_curfailstr_H, $seqfailstr_HR, \@rtpass_seqorder_A,  0, $out_root, "friblc", \%ofile_info_HH); # 0: do not output description of pass/fail lists to log file
  my $ms_npass  = undef;
  if($do_fmspan) { 
    $ms_npass = update_and_output_pass_fails(\%ms_curfailstr_H,  $seqfailstr_HR, $rapass_seqorder_AR, 0, $out_root, "fmspan", \%ofile_info_HH); # 0: do not output description of pass/fail lists to log file
  }
  else { 
    $ms_npass = $ra_npass;
  }

  return ($rt_npass, $ra_npass, $ms_npass);
}

#################################################################
# Subroutine:  parse_riboaligner_tbl_and_output_mdlspan_tbl()
# Incept:      EPN, Tue Aug 21 12:41:59 2018
#
# Purpose:     Parse a tbl output file from riboaligner.pl and
#              output a tabular file that lists number of sequences 
#              and taxonomic groups that would survive for a 
#              variety of different start/end model positions.
#
# Arguments:
#   $in_file:             name of input tbl file to parse
#   $mdlspan_sort_exec:   path to script that we use to resort if --mslist
#   $mlen:                model length 
#   $out_root:            for naming output files
#   $seqfailstr_HR:       ref to hash of sequence fail string, if undef,
#                         do all seqs
#   $seqtaxid_HR:         ref to hash of taxids of each sequence
#   $seqgtaxid_HHR:       ref to 2D hash, 1D key tax level (e.g. "order")
#                         2D key is sequence name, value is taxid of 
#                         that group for that sequence
#   $all_gtaxid_HAR:      ref to hash of arrays, key is taxonomic level,
#                         array is all taxids in that level that had >= 1
#                         sequence in the input sequence file
#   $opt_HHR:             ref to 2D hash of cmdline options
#   $ofile_info_HHR:      ref to the ofile info 2D hash
#
# Returns:    void
#
# Dies:       If we can't parse $in_file
#             If we don't have taxid info in seqtaxid_HR or seqgtaxid_HHR 
#             for a sequence that we read in $in_file
# 
#################################################################
sub parse_riboaligner_tbl_and_output_mdlspan_tbl { 
  my $sub_name = "parse_riboaligner_tbl_and_output_mdlspan_tbl()";
  my $nargs_expected = 10;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($in_file, $mdlspan_sort_exec, $mlen, $out_root, $seqfailstr_HR, $seqtaxid_HR, $seqgtaxid_HHR, $all_gtaxid_HAR, $opt_HHR, $ofile_info_HHR) = (@_);

  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience

  # create the bins
  my $pstep      = opt_Get("--msstep",   $opt_HHR);
  my $minspanlen = opt_Get("--msminlen", $opt_HHR);
  my $minstart   = opt_IsUsed("--msminstart", $opt_HHR) ? opt_Get("--msminstart", $opt_HHR) : 1;
  my $maxstart   = opt_IsUsed("--msmaxstart", $opt_HHR) ? opt_Get("--msmaxstart", $opt_HHR) : $mlen;
  my $minstop    = opt_IsUsed("--msminstop",  $opt_HHR) ? opt_Get("--msminstop",  $opt_HHR) : 1;
  my $maxstop    = opt_IsUsed("--msmaxstop",  $opt_HHR) ? opt_Get("--msmaxstop",  $opt_HHR) : $mlen;
  my $bidx = 0;
  my $lpos; 
  my $rpos;
  my $spanlen = 0;
  my @lpos_A = (); # array of all possible lpos values
  my @rpos_A = (); # array of all possible rpos values
  my %lpos_H = (); # key is lpos value, value is always 1, used only so we can fill lpos_A
  my %rpos_H = (); # key is rpos value, value is always 1, used only so we can fill rpos_A
  my %lpos_rpos2bin_HH = (); # key1: lpos value, key2: rpos value, value is bin index corresponding to that lpos/rpos pair
  my @lpos_per_bin_A = ();   # [0..nbins-1] lpos for this bin
  my @rpos_per_bin_A = ();   # [0..nbins-1] rpos for this bin
  # $minstart == 1     unless --msminstart was used
  # $maxstart == $mlen unless --msmaxstart was used
  # $minstop  == 1     unless --msminstop  was used
  # $maxstop  == $mlen unless --msmaxstop  was used
  if($minstop  < $minstart) { $minstop  = $minstart; }
  if($maxstart > $maxstop)  { $maxstart = $maxstop; }

  # determine the bins
  for($lpos = $minstart; $lpos < ($maxstart + $pstep); $lpos += $pstep) { 
    if($lpos > $maxstop) { $lpos = $maxstop; }
    for($rpos = $lpos + $pstep; $rpos < ($maxstop + $pstep); $rpos += $pstep) { 
      if($rpos >= $minstop) { 
        if($rpos > $maxstop) { $rpos = $maxstop; }
        $spanlen = ($rpos - $lpos) + 1;
        if($spanlen >= $minspanlen) { 
          if(! exists $lpos_H{$lpos}) {
            push(@lpos_A, $lpos);
            $lpos_H{$lpos} = 1;
          }
          if(! exists $rpos_H{$rpos}) {
            push(@rpos_A, $rpos);
            $rpos_H{$rpos} = 1;
          }
          push(@lpos_per_bin_A, $lpos);
          push(@rpos_per_bin_A, $rpos);
          $lpos_rpos2bin_HH{$lpos}{$rpos} = $bidx;
          $bidx++;
        }
      }
    }
  }
  my $nbins = $bidx;
  my $nlpos = scalar(@lpos_A);
  my $nrpos = scalar(@rpos_A);

  # parse the tbl file, and for each sequence determine which bins it survives in and update counts for that bin
  my @nseq_in_A   = (); # 0..$nbins-1, number of sequences surviving each bin
  my @nseq_out_A  = (); # 0..$nbins-1, number of sequences not surviving each bin
  my @nseq_spec_A = (); # 0..$nbins-1, number of sequences specifically that fall into this bin (if bin is 51...301 and stepsize is 50, number of sequences that begin with 51..100 and end at 252..301
  my $nseq_fail = 0;
  my @ngtaxid_bin_level_AH      = (); # array [0..$nbins-1] of hashes, key is taxonomic level, value is number of groups at that level that survive in this bin
  my @nseq_bin_level_gtaxid_AHH = (); # array [0..$nbins-1] of hashes, key 1D is taxonomic level, key 2D is gtaxid, 
                                      # value is number of sequences in that group that survive in this bin
  
  # initialize
  for($bidx = 0; $bidx < $nbins; $bidx++) { 
    $nseq_in_A[$bidx]  = 0;
    $nseq_out_A[$bidx] = 0;
    $nseq_spec_A[$bidx]  = 0;
    foreach my $level (sort keys (%{$seqgtaxid_HHR})) { 
      $ngtaxid_bin_level_AH[$bidx]{$level} = 0;
      $ngtaxid_bin_level_AH[$bidx]{"species"} = 0;
    }
  }

  # parse each line of the output file and collect information from it
  open(IN, $in_file)  || ofile_FileOpenFailure($in_file,  "RIBO", $sub_name, $!, "reading", $FH_HR);

  while(my $line = <IN>) { 
    ##idx  target      classification         strnd   p/f  mstart   mstop  length_class  unexpected_features
    ##---  ----------  ---------------------  -----  ----  ------  ------  ------------  -------------------
    #1     Z36893.1    SSU.Eukarya            plus   PASS       1    1851    full-exact  -
    #2     Z26765.1    SSU.Eukarya            plus   PASS       1    1851    full-exact  -
    if($line !~ m/^\#/) { 
      chomp $line;
      my @el_A = split(/\s+/, $line);
      if(scalar(@el_A) != 9) { 
        ofile_FAIL("ERROR in $sub_name, ra tblout file line did not have exactly 9 space-delimited tokens: $line\n", "RIBO", $?, $FH_HR);
      }
      my ($target, $mstart, $mstop) = ($el_A[1], $el_A[5], $el_A[6]); 
      if(((! defined $seqfailstr_HR) || ($seqfailstr_HR->{$target} eq "")) && # we are doing all seqs ($seqfailstr_HR undef) or sequence has not failed
         ($mstart ne "-") && ($mstop ne "-")) { 
        # get taxonomic information for this guy, and store in %gtaxid_H
        my %gtaxid_H = ();
        foreach my $level (sort keys (%{$seqgtaxid_HHR})) { 
          if(! exists $seqgtaxid_HHR->{$level}{$target}) { 
            ofile_FAIL("ERROR in $sub_name, no $level information for $target\n", "RIBO", $?, $FH_HR);
          }
          $gtaxid_H{$level} = $seqgtaxid_HHR->{$level}{$target};
        }
        if(! exists $seqtaxid_HR->{$target}) { 
          ofile_FAIL("ERROR in $sub_name, no species information for $target\n", "RIBO", $?, $FH_HR);
        }
        $gtaxid_H{"species"} = $seqtaxid_HR->{$target};
        
        # determine the specific bin that this sequence falls in
        my $lpos_idx = 0; 
        my $rpos_idx = 0;
        while(($lpos_idx < ($nlpos-1)) && ($mstart > $lpos_A[($lpos_idx+1)])) { $lpos_idx++; }
        while(($rpos_idx < ($nrpos-1)) && ($mstop  > $rpos_A[($rpos_idx+1)])) { $rpos_idx++; }
        #if(defined $seqfailstr_HR) { printf("HEYA $mstart $mstop lpos_idx: $lpos_idx rpos_idx: $rpos_idx $lpos_A[$lpos_idx] $rpos_A[$rpos_idx]\n"); }

        $bidx = $lpos_rpos2bin_HH{$lpos_A[$lpos_idx]}{$rpos_A[$rpos_idx]};
        $nseq_spec_A[$bidx]++;

        # for each bin, would this sequence survive? if so, update counts for that bin
        for($bidx = 0; $bidx < $nbins; $bidx++) { 
          if(($mstart <= $lpos_per_bin_A[$bidx]) && ($mstop >= $rpos_per_bin_A[$bidx])) { 
            $nseq_in_A[$bidx]++;
            
            foreach my $level (sort keys (%gtaxid_H)) { 
              my $gtaxid = $gtaxid_H{$level};
              if(! exists $nseq_bin_level_gtaxid_AHH[$bidx]{$level}{$gtaxid}) { 
                $nseq_bin_level_gtaxid_AHH[$bidx]{$level}{$gtaxid} = 1;
                $ngtaxid_bin_level_AH[$bidx]{$level}++;
              }
              else { 
                $nseq_bin_level_gtaxid_AHH[$bidx]{$level}{$gtaxid}++;
              }
            }
          }
          else { 
            $nseq_out_A[$bidx]++;
          }
        } # end of for($bidx = 0; $bidx < $nbins; $bidx++)
      } # end of if(((! defined $seqfailstr_HR) || ($seqfailstr_HR->{$target} eq "")) && ($mstart ne "-") && ($mstop ne "-"))
      else { 
        $nseq_fail++;
      }
    }
  }
  close(IN);

  # we have all the information we need, output it
  # one line per bin
  my @out_AH = (); # [0..$nbins-1], each element is hash, key is "output", "norder", "length", "lpos"
                   # hash is used to sort output lines by norder, then length, then lpos
  for($bidx = 0; $bidx < $nbins; $bidx++) { 
    # generate lists of gtaxids for each group for this bin
    my %inlist_str_H  = ();
    my %outlist_str_H = ();
    foreach my $level (sort keys (%{$seqgtaxid_HHR})) { 
      $inlist_str_H{$level}  = "";
      $outlist_str_H{$level} = "";
      foreach my $gtaxid (@{$all_gtaxid_HAR->{$level}}) { 
        if(exists $nseq_bin_level_gtaxid_AHH[$bidx]{$level}{$gtaxid}) { 
          if($inlist_str_H{$level} ne "") { $inlist_str_H{$level} .= ","; }
          $inlist_str_H{$level} .= $gtaxid;
        }
        else { 
          if($outlist_str_H{$level} ne "") { $outlist_str_H{$level} .= ","; }
          $outlist_str_H{$level} .= "-" . $gtaxid;
        }
      }
      if($inlist_str_H{$level}  eq "") { $inlist_str_H{$level}  = "-"; }
      if($outlist_str_H{$level} eq "") { $outlist_str_H{$level} = "-"; }
    }

    $out_AH[$bidx]{"output"} = sprintf ("%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", 
                                        $rpos_per_bin_A[$bidx] - $lpos_per_bin_A[$bidx] + 1, 
                                        $lpos_per_bin_A[$bidx], $rpos_per_bin_A[$bidx], 
                                        $nseq_in_A[$bidx], $nseq_out_A[$bidx], $nseq_spec_A[$bidx], $nseq_fail,
                                        $ngtaxid_bin_level_AH[$bidx]{"species"}, 
                                        $ngtaxid_bin_level_AH[$bidx]{"order"}, 
                                        scalar(@{$all_gtaxid_HAR->{"order"}}) - $ngtaxid_bin_level_AH[$bidx]{"order"}, 
                                        $ngtaxid_bin_level_AH[$bidx]{"class"}, 
                                        scalar(@{$all_gtaxid_HAR->{"class"}}) - $ngtaxid_bin_level_AH[$bidx]{"class"}, 
                                        $ngtaxid_bin_level_AH[$bidx]{"phylum"}, 
                                        scalar(@{$all_gtaxid_HAR->{"phylum"}}) - $ngtaxid_bin_level_AH[$bidx]{"phylum"}, 
                                        $inlist_str_H{"order"}, 
                                        $outlist_str_H{"order"}, 
                                        $inlist_str_H{"class"}, 
                                        $outlist_str_H{"class"}, 
                                        $inlist_str_H{"phylum"}, 
                                        $outlist_str_H{"phylum"}); 
    $out_AH[$bidx]{"norder"} = $ngtaxid_bin_level_AH[$bidx]{"order"}; 
    $out_AH[$bidx]{"length"} = $rpos_per_bin_A[$bidx] - $lpos_per_bin_A[$bidx] + 1;
    $out_AH[$bidx]{"lpos"}   = $lpos_per_bin_A[$bidx];
  } # end of 'for($bidx = 0' loop over bins
  
  # open output file, sort the output and write output file
  my $out_key = (defined $seqfailstr_HR) ? "pass" : "all";
  my $out_file = $out_root . ".$out_key.mdlspan.survtbl";
  my ($max_lpos, $min_rpos) = determine_riboaligner_lpos_rpos($mlen, $opt_HHR); 
  open(OUT, ">", $out_file) || ofile_FileOpenFailure($out_file, "RIBO", $sub_name, $!, "writing", $ofile_info_HH{"FH"});
  print OUT ("# Filename: $out_file\n");
  print OUT ("# This file contains information on how many sequences and taxonomic groups would 'survive' for different\n");
  print OUT ("# choices of model span coordinates <max_lpos>..<min_rpos>, which are the maximum allowed 5'-most aligned\n");
  print OUT ("# model position and minimum allowed 3'-most model position for each aligned sequence.\n");
  if($out_key eq "pass") { 
    print OUT ("# For this file 'survive' means PASSes all filters (incl. fribo2: riboaligner) AND has alignment boundaries\n");
    print OUT ("# within the relevant model span for the row of the table below.\n");
  }
  else { 
    print OUT ("# For this file 'survive' means PASSes all filters OR FAILs >= 1 filters, but passes fribo2 (riboaligner)\n");
    print OUT ("# AND has alignment boundaries within the relevant model span for the row of the table below.\n");
  }
  print OUT ("# Current values:\n");
  print OUT ("# <max_lpos>: $max_lpos\n",);
  print OUT ("# <min_rpos>: $min_rpos\n");
  print OUT ("#\n");
  print OUT ("# These are settable with the --fmpos, --fmlpos, and --fmrpos options, do ribodbmaker.pl -h for more information\n");
  print OUT ("#\n");
  print OUT ("# This file shows how many sequences would pass for other possible choices of <max_lpos> and <min_rpos>.\n");
  print OUT ("# Each line has information for a pair of values <max_lpos>..<min_rpos> and contains 20 tab delimited columns, described below.\n");
  print OUT ("# Only values of <max_lpos> and <min_rpos> which are multiples of $pstep (plus 1) are shown (changeable with the --msstep option).\n");
  print OUT ("# Only pairs of <max_lpos> and <min_rpos> in which the length is >= $minspanlen are shown (changeable with the --msminlen option).\n");
  print OUT ("# The lines are sorted by the following columns: first by 'num-surviving-orders', then by 'length', and then by '5'pos'.\n");
  print OUT ("#\n");
  print OUT ("# You can recreate this file by rerunning ribodbmaker.pl using the same options it was originally run with, but\n");
  print OUT ("# additionally with the --prvcmd option, without the -f option, and with the additional options that change\n");
  print OUT ("# what data will be printed to this file:\n");
  my $used_str = undef;
  $used_str = opt_IsUsed("--msstep", $opt_HHR) ? opt_Get("--msstep", $opt_HHR) : "NOT ENABLED; used default of : " . opt_Get("--msstep", $opt_HHR); 
  print OUT ("#   --msstep <n>     : for model span output table, set step size to <n> [VALUE: $used_str]\n"); 
  $used_str = opt_IsUsed("--msminlen", $opt_HHR) ? opt_Get("--msminlen", $opt_HHR) : "NOT ENABLED; used default of: " . opt_Get("--msminlen", $opt_HHR); 
  print OUT ("#   --msminlen <n>   : for model span output table, set min length span to <n> [VALUE: $used_str]\n");
  $used_str = opt_IsUsed("--msminstart", $opt_HHR) ? opt_Get("--msminstart", $opt_HHR) : "NOT ENABLED; used default of: 1";
  print OUT ("#   --msminstart <n> : for model span output table, set min start position to <n> [VALUE: $used_str]\n");
  $used_str = opt_IsUsed("--msmaxstart", $opt_HHR) ? opt_Get("--msmaxstart", $opt_HHR) : "NOT ENABLED; used default of: $mlen (model length)";
  print OUT ("#   --msmaxstart <n> : for model span output table, set maxstart position to <n> [VALUE: $used_str]\n");
  $used_str = opt_IsUsed("--msminstop", $opt_HHR) ? opt_Get("--msminstop", $opt_HHR) : "NOT ENABLED; used default of: 1";
  print OUT ("#   --msminstop <n>  : for model span output table, set min stop position to <n> [VALUE: $used_str]\n");
  $used_str = opt_IsUsed("--msmaxstop", $opt_HHR) ? opt_Get("--msmaxstop", $opt_HHR) : "NOT ENABLED; used default of: $mlen (model length)";
  print OUT ("#   --msmaxstop <n>  : for model span output table, set max stop position to <n> [VALUE: $used_str]\n");
  print OUT ("#\n");
  print OUT ("# Also, you can have ribodbmaker.pl create an additional file similar to this one but that prioritizes specific orders, classes\n");
  print OUT ("# or phyla listed in a file, and ignores those not listed, by rerunning ribodbmaker.pl as described above but additionally\n");
  print OUT ("# using the --mslist, --msclass, and/or --msphylum options. Do 'ribodbmaker.pl -h' for more information.\n");
  print OUT ("#\n");
  print OUT ("# Finally, you can create that additional file that prioritizes certain orders, classes or phyla outside of\n");
  print OUT ("# ribodbmaker.pl using the script mdlspan-survtbl-sort.pl in the ribotyper-v1 directory that ribodbmaker.pl is in.\n");
  print OUT ("# Some example commands for that script are:\n");
  print OUT ("# perl \$RIBODIR/mdlspan-survtbl-sort.pl <PATH-TO-THIS-FILE> <file with list of orders to prioritize>\n");
  print OUT ("# OR\n");
  print OUT ("# perl \$RIBODIR/mdlspan-survtbl-sort.pl -c <PATH-TO-THIS-FILE> <file with list of orders to prioritize>\n");
  print OUT ("# OR\n");
  print OUT ("# perl \$RIBODIR/mdlspan-survtbl-sort.pl -s <PATH-TO-THIS-FILE> <comma-delimited list of orders to prioritize>\n");
  print OUT ("#\n");
  print OUT ("# Explanation of columns in this file:\n");
  print OUT ("#  1. 'length': length of model span\n");
  print OUT ("#  2. '5' pos': maximum allowed 5' start position <max_lpos>\n");
  print OUT ("#  3. '3' pos': minimum allowed 3' end   position <min_rpos>\n");
  print OUT ("#  4. num-surviving-seqs:      number of sequences that survive riboaligner and span <max_lpos..min_rpos>\n");
  print OUT ("#  5. num-seqs-not-surviving:  number of sequences that survive riboaligner and do not span <max_lpos..min_rpos>\n");
  print OUT ("#  6. num-seqs-within-range:   number of sequences that survive riboaligner that span <max_lpos>..<min_rpos> but\n");
  print OUT ("#                              do not span <max_lpos + $pstep> .. <min_rpos + $pstep>\n");
  printf OUT ("#  7. num-seqs-not-considered: number of sequences that FAILed %s riboaligner for some reason and were not evaluated\n", ($out_key eq "pass") ? "riboaligner" : "riboaligner or another filter");
  print OUT ("#  8. num-surviving-species:   number of species taxids with at least 1 sequence that survives this span\n");
  printf OUT ("#  9. num-surviving-orders:    number of order taxids with >= 1 sequence that %s survives this span\n",                  ($out_key eq "pass") ? "passes all filters and" : "passes riboaligner and");
  printf OUT ("# 10. num-missing-orders:      number of order taxids with >= 1 input sequence but 0 that %s and survives this span\n",  ($out_key eq "pass") ? "passes all filters and" : "passes riboaligner and");
  printf OUT ("# 11. num-surviving-classes:   number of class taxids with >= 1 sequence that %s survives this span\n",                  ($out_key eq "pass") ? "passes all filters and" : "passes riboaligner and");
  printf OUT ("# 12. num-missing-classes:     number of class taxids with >= 1 input sequence but 0 that %s and survives this span\n",  ($out_key eq "pass") ? "passes all filters and" : "passes riboaligner and");
  printf OUT ("# 13. num-surviving-phyla:     number of phylum taxids with >= 1 sequence that %s survives this span\n",                 ($out_key eq "pass") ? "passes all filters and" : "passes riboaligner and");
  printf OUT ("# 14. num-missing-phyla:       number of phylum taxids with >= 1 input sequence but 0 that %s and survives this span\n", ($out_key eq "pass") ? "passes all filters and" : "passes riboaligner and");
  printf OUT ("# 15. surviving-orders:        comma-separated list of order taxids with >= 1 sequence that %s survives this span\n",             ($out_key eq "pass") ? "passes all filters and" : "passes riboaligner and"); 
  printf OUT ("# 16. missing-orders:          comma-separated list of order taxids with >= 1 input sequence but 0 that %s survives this span\n", ($out_key eq "pass") ? "passes all filters and" : "passes riboaligner and");
  printf OUT ("# 17. surviving-classes:       comma-separated list of class taxids with >= 1 sequence that %s survives this span\n",             ($out_key eq "pass") ? "passes all filters and" : "passes riboaligner and"); 
  printf OUT ("# 18. missing-classes:         comma-separated list of class taxids with >= 1 input sequence but 0 that %s survives this span\n", ($out_key eq "pass") ? "passes all filters and" : "passes riboaligner and");
  printf OUT ("# 19. surviving-phyla:         comma-separated list of phyla taxids with >= 1 sequence that %s survives this span\n",             ($out_key eq "pass") ? "passes all filters and" : "passes riboaligner and"); 
  printf OUT ("# 20. missing-phyla:           comma-separated list of phyla taxids with >= 1 input sequence but 0 that %s survives this span\n", ($out_key eq "pass") ? "passes all filters and" : "passes riboaligner and");
  print OUT ("#\n");
  print OUT "#length\t5'pos\t3'pos\tnum-surviving-seqs\tnum-seqs-not-surviving\tnum-seqs-within-range\tnum-seqs-not-considered(failed)\tnum-surviving-species\tnum-surviving-orders\tnum-missing-orders\tnum-surviving-classes\tnum-missing-classes\tnum-surviving-phyla\tnum-missing-phyla\tsurviving-orders\tmissing-orders\tsurviving-classes\tmissing-classes\tsurviving-phyla\tmissing-phyla\n";
  
  @out_AH = sort { 
    $b->{"norder"} <=> $a->{"norder"} or 
    $b->{"length"} <=> $a->{"length"} or
    $a->{"lpos"}   <=> $b->{"lpos"}
  } @out_AH;
  
  for($bidx = 0; $bidx < $nbins; $bidx++) { 
    print OUT $out_AH[$bidx]{"output"};
  }
  close(OUT);
  ofile_AddClosedFileToOutputInfo($ofile_info_HHR, "RIBO", "$out_key.mdlspan.survtbl", $out_file, 1, "table summarizing number of sequences ($out_key) for different model position spans");

  # if --mslist used, re-sort to prioritize sequences in that file
  if(opt_IsUsed("--mslist", $opt_HHR)) { 
    my $resort_out_file = $out_root . ".$out_key.resort.mdlspan.survtbl";
    my $opt_str = ""; 
    my $key = "orders";
    if   (opt_Get("--msclass",  $opt_HHR)) { $opt_str .= "-c"; $key = "classes"; }
    elsif(opt_Get("--msphylum", $opt_HHR)) { $opt_str .= "-p"; $key = "phyla";   }
    my $resort_cmd = $mdlspan_sort_exec . " $opt_str $out_file " . opt_Get("--mslist", $opt_HHR) . " > $resort_out_file"; 
    ribo_RunCommand($resort_cmd, opt_Get("-v", $opt_HHR), $FH_HR);
    ofile_AddClosedFileToOutputInfo($ofile_info_HHR, "RIBO", "$out_key.resort.mdlspan.survtbl", $resort_out_file, 1, "$out_key.mdlspan.survtbl table re-sorted to prioritize $key read from --mslist <s> file");
  }
  return;
}

#################################################################
# Subroutine:  parse_blast_output_for_self_hits()
# Incept:      EPN, Wed Jun 13 15:21:14 2018
#
# Purpose:     Parse a blast output file that should have only self hits in it 
#              because the query and subject were identical files and the 
#              '-max_target_seqs 1' flag was used.
#
# Arguments:
#   $in_file:      name of input blast output file to parse
#   $nhit_HR:      ref to hash, keys are expected sequence names, values are '1'
#   $failstr_HR:   ref to hash of failure string to add to here
#   $opt_HHR:      reference to 2D hash of cmdline options
#   $FH_HR:        REF to hash of file handles, including "cmd"
#
# Returns:    Number of sequences that pass (do not have self hits)
#
# Dies:       if blast output is not in expected format (number of fields)
#             if any of the sequences in nhit_HR are not in the blast output
#             if any of the sequences in nhit_HR do not have a full length self hit in the blast output
# 
#################################################################
sub parse_blast_output_for_self_hits { 
  my $sub_name = "parse_blast_output_for_self_hits()";
  my $nargs_expected = 5;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($in_file, $nhit_HR, $failstr_HR, $top_HHR, $FH_HR) = (@_);

  my %local_failstr_H = (); # fail string created in this subroutine for each sequence

  my $do_minus_off_diagonal        = opt_Get("--fbnominus", \%opt_HH) ? 0 : 1; # do we consider off-diagonal self hits on the minus strand? 
  my $do_minus_off_and_on_diagonal = ($do_minus_off_diagonal && opt_Get("--fbmdiagok", \%opt_HH)) ? 1 : 0; # do we consider on-diagonal  self hits on the minus strand 
  my $minus_minlen = opt_Get("--fbminuslen", \%opt_HH);
  my $minus_minpid = opt_Get("--fbminuspid", \%opt_HH);
  my $ondiag = 0; # set to '1' if current hit is on-diagonal, '0' if not
                  # a hit is on diagonal if: it is on + strand of subject and $qstart == $sstart && $qend == $send
                  #                      OR  it is on - strand of subject and $qstart == $send   && $qend == $sstart

  open(IN, $in_file)  || ofile_FileOpenFailure($in_file,  "RIBO", $sub_name, $!, "reading", $FH_HR);
  while(my $line = <IN>) { 
    # print "read line: $line";
    chomp $line;
    my @el_A = split(/\t/, $line);
    if(scalar(@el_A) != 11) { 
      ofile_FAIL("ERROR in $sub_name, did not read 11 tab-delimited columns on line $line", "RIBO", 1, $FH_HR); 
    }
    
    my ($qaccver, $qstart, $qend, $nident, $length, $gaps, $pident, $sacc, $sstart, $send, $evalue) = @el_A;
    if($qaccver eq $sacc) { 
      # sanity check: query/subject should be to a sequence we expect
      if(! exists $nhit_HR->{$qaccver}){ 
        ofile_FAIL("ERROR in $sub_name, found unexpected query and subject $qaccver:\n$line", "RIBO", 1, $FH_HR); 
      }
      my $qlen;   # length of hit on query
      my $slen;   # length of hit on subject
      my $maxlen; # max of $qlen and $slen
      my $qstrand = ($qend >= $qstart) ? "+" : "-";
      my $sstrand = ($send >= $sstart) ? "+" : "-";
      if($qstrand ne "+") { # sanity check
        ofile_FAIL("ERROR in $sub_name, query coordinates suggest minus strand\n$line", "RIBO", 1, $FH_HR); 
      }
      if($sstrand eq "+") { $ondiag = (($qstart == $sstart) && ($qend == $send))   ? 1 : 0; }
      else                { $ondiag = (($qstart == $send)   && ($qend == $sstart)) ? 1 : 0; }
      $nhit_HR->{$qaccver}++;
      $qlen = abs($qstart - $qend) + 1;
      $slen = abs($sstart - $send) + 1;
      $maxlen = ($qlen > $slen) ? $qlen : $slen;
      
      # determine if we should consider this hit as a self hit to a repetitive region worth failing the sequence for?:
      # if    $sstrand eq "+" and $ondiag == 0, then YES
      # elsif $sstrand eq "-" and $ondiag == 0 and --fbpminusok is used, then YES
      # elsif $sstrand eq "-" and $ondiag == 1 and --fbmdiagoky is used, then YES
      my $do_consider = 0;
      if(($sstrand eq "+") && 
         ($ondiag == 0)) { 
        $do_consider = 1; 
      }
      elsif(($sstrand eq "-") && 
            ($ondiag == 0)    && 
            $do_minus_off_diagonal && 
            ($maxlen >= $minus_minlen) && 
            ($pident >= $minus_minpid)) { 
        $do_consider = 1; 
      }
      elsif(($sstrand eq "-") && 
            ($ondiag == 1)    && 
            $do_minus_off_and_on_diagonal && 
            ($maxlen >= $minus_minlen) && 
            ($pident >= $minus_minpid)) { 
        $do_consider = 1; 
      }

      if($do_consider) { 
        # repeat, should we keep information on it? 
        # don't want to double count (off-diagonal repeat hits usually occur twice on + strand), 
        # so we use a simple rule to only pick one. Hits on - strand only occur once.
        if($qstart <= $sstart) { 
          # store information on it
          if(exists $local_failstr_H{$qaccver}) { 
            $local_failstr_H{$qaccver} .= ","; 
          }
          else { 
            $local_failstr_H{$qaccver} = ""; 
          }
          # now append the info
          my $pident2print = sprintf("%.1f", $pident);
          $local_failstr_H{$qaccver} .= "$sstrand|e=$evalue|len=$maxlen|$qstart..$qend/$sstart..$send|pid=$pident2print|ngap=$gaps";
        }
      }
    }
  }
  close(IN);

  # fill $failstr_HR
  # previously (prior to v0.23) we did a final sanity check here to ensure 
  # each seq should have had at least 1 hit, but then realized that this is not
  # not necessarily true (example is KM853238.1 which has a bunch of ambiguous
  # nucleotides spread across the sequence) 
  foreach my $key (keys %{$nhit_HR}) { 
    # this is the pre-v0.23 sanity check:
    #if($nhit_HR->{$key} == 0) { 
    #ofile_FAIL("ERROR in $sub_name, found zero hits to query $key", "RIBO", 1, $FH_HR); 
    #}
    if(exists $local_failstr_H{$key}) { 
      $failstr_HR->{$key} .= "blastrepeat[$local_failstr_H{$key}];;";
    }
  }

  return;
}

#################################################################
# Subroutine:  parse_alipid_analyze_tab_files()
# Incept:      EPN, Mon Jun 25 15:17:12 2018
#
# Purpose:     Parse a tab delimited file output from alipid-taxinfo-analyze.pl
#              Column 5 is the 'type' of sequence. Any that begin with 'O' will
#              fail.
#
# Arguments:
#   $in_file_HR:     key is $level from @level_A, value is name of alipid
#                    file for that level to parse
#   $level_AR:       ref to array of level keys in %{$in_file_HR}
#   $seqfailstr_HR:  ref to hash of failure string to add to here
#   $seqorder_AR:    ref to array of sequences in order, ONLY seqs that 
#   $out_root:       for naming output files
#   $opt_HHR:        reference to 2D hash of cmdline options
#   $ofile_info_HHR: ref to the ofile info 2D hash
#
# Returns:    Number of sequences that fail
#
# Dies:       if a sequence read in the alipid file is not in %{$seqfailstr_HR}
#################################################################
sub parse_alipid_analyze_tab_files { 
  my $sub_name = "parse_alipid_analyze_tab_files";
  my $nargs_expected = 7;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($in_file_HR, $level_AR, $seqfailstr_HR, $seqorder_AR, $out_root, $opt_HHR, $ofile_info_HHR) = (@_);

  # are we only allowing 1 hit per tax id to survive?
  my $do_one     = (opt_Get   ("--fione", $opt_HHR)) ? 1 : 0;
  my $do_one_min = (opt_IsUsed("--fimin", $opt_HHR)) ? 1 : 0; # --fimin requires --fione
  my $one_min    = opt_Get   ("--fimin", $opt_HHR);
  my %max_pid_per_taxid_HH    = (); # 1D key is taxonomic level; 2D key is $seq_taxid (species level taxid), value is $avgpid for $argmax_pid_per_taxid_H{$seq_taxid}
  my %argmax_pid_per_taxid_HH = (); # 1D key is taxonomic level; 2D key is $seq_taxid (species level taxid), value is $accver that has max $avgpid for all seqs in 
                                    # lowest level in @{$level_AR}
  my %do_one_taxid_H   = (); # 1D key is $seqname, value is species taxid if seqname is candidate for failing b/c not max avg id in species
  my %do_one_avgpid_HH = (); # 1D key is taxonomic level, 2D key is $seqname, value is average pid at order level for seqname
  my %do_one_lowest_level_H = (); # 1D key is a species taxid, value is lowest taxonomic level $level for which that seq_taxid has a valid $level
  # note: it is wasteful for us to compute and store these for all 3 levels since we only need 
  # it for the lowest level (phylum, class, order) it is available, but we do it anyway because
  # the following implementation (see 'if($do_one)') is simple

  my %do_one_min_taxid_H = (); # 1D key is $seqname, value is species taxid if seqname is candidate for failing b/c not enough sequences in its taxid (--fimin)
  my %one_min_ntaxid_H   = (); # key is sequence taxid, value is number of sequences that have that taxid, only filled and used if $do_one_min (--fimin)

  my %curfailstr_H = ();  # will hold fail string 
  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience
  my $seqname;
  my $seq_taxid; 

  ribo_InitializeHashToEmptyString(\%curfailstr_H, $seqorder_AR);

  # go through each alipid file and determine which sequences should 
  # fail due to their type (any type that begins with O at any level fails)
  foreach my $level (@{$level_AR}) { 
    open(TAB, $in_file_HR->{$level})  || ofile_FileOpenFailure($in_file_HR->{$level},  "RIBO", $sub_name, $!, "reading", $FH_HR);
    # first line is header
    my $line = <TAB>;
    while($line = <TAB>) { 
      ##sequence	seq-taxid	species	type	p/f	in-group	in-nseq	in-avgid	in-maxid	in-maxseq	in-minid	in-minseq	maxavg-string	maxavg-group	maxavg-nseq	maxavg-avgid	maxavg-maxid	maxavg-maxseq	maxavg-minid	maxavg-minseq	maxmax-string	maxmax-group	maxmax-nseq	maxmax-avgid	maxmax-maxid	maxmax-maxseq	maxmax-minid	maxmax-minseq	avgdiff	maxdiff
      #AY761090.2	312317	Xylomelasma sordida	I1	PASS   4890	2074	96.04	99.01	MF077540.1	76.57	AB053251.1	avg:same	4761	27	93.07	94.72	AY601711.1	88.45	AF164253.2	max:same	5204	441	89.49	98.35	KJ708419.1	57.76	DQ898689.1	2.9665557163529	0.660000000000011
      #KY368137.1	1116880	Wickerhamiella infanticola	I1	PASS   4890	2074	94.60	99.68	AB018151.1	76.62	AB053253.1	avg:same	4761	27	91.82	93.53	HQ901742.1	88.31	AF164253.2	max:same	5204	441	88.66	95.79	KJ708419.1	58.12	DQ898689.1	2.77972825213143	3.89
      #MH201386.1	1195475	Benjaminiella youngii	I1	PASS   1913637	161	88.74	99.68	MH201385.1	78.50	GU559979.1	avg:same	4761	27	83.86	86.41	KY350147.1	81.55	GU358605.1	max:same	4761	27	83.86	86.41	KY350147.1	81.55	GU358605.1	4.87068055555551	13.27
      if($line !~ m/^\#/) { 
        chomp $line;
        my @el_A = split(/\t/, $line);
        if(scalar(@el_A) != 30) { ofile_FAIL(sprintf("ERROR in $sub_name, tab file line had %d tab-delimited tokens, but expected 30: $line\n", scalar(@el_A)), "RIBO", $?, $FH_HR); }
        my ($seqname, $seq_taxid, $type, $pf, $group_taxid, $avgpid) = ($el_A[0], $el_A[1], $el_A[3], $el_A[4], $el_A[5], $el_A[7]);
        if(! exists $curfailstr_H{$seqname}) { ofile_FAIL("ERROR in $sub_name, unexpected sequence name read: $seqname", "RIBO", 1, $FH_HR); }
        if($pf eq "FAIL") { 
          $curfailstr_H{$seqname} = $level . ",type=" . $type . ";"; # we'll add the 'ingroup-analysis[];;' part later
        }
      }
    }
    close(TAB);
  }

  # if $do_one: 
  # go back through the order alipid file a second time to determine
  # for all seqs with a species taxid that are not in an O type, the
  # average pid to all other seqs in the same species taxid
  if($do_one) { 
    foreach my $level (@{$level_AR}) { 
      open(TAB, $in_file_HR->{$level})  || ofile_FileOpenFailure($in_file_HR->{$level},  "RIBO", $sub_name, $!, "reading", $FH_HR);
      # first line is header
      my $line = <TAB>;
      while($line = <TAB>) { 
        chomp $line;
        if($line !~ m/^\#/) { 
          my @el_A = split(/\t/, $line);
          if(scalar(@el_A) != 30) { ofile_FAIL("ERROR in $sub_name, tab file line did not have exactly 30 tab-delimited tokens: $line\n", "RIBO", $?, $FH_HR); }
          my ($seqname, $seq_taxid, $type, $pf, $group_taxid, $avgpid) = ($el_A[0], $el_A[1], $el_A[3], $el_A[4], $el_A[5], $el_A[7]);

          if(! exists $curfailstr_H{$seqname}) { ofile_FAIL("ERROR in $sub_name, unexpected sequence name read: $seqname", "RIBO", 1, $FH_HR); }
          if(($curfailstr_H{$seqname} eq "") && ($group_taxid ne "-") && ($group_taxid ne "1") && ($avgpid ne "-")) { 
            # sequence did not FAIL ingroup test, and has valid group_taxid at this level (and so has valid seq_taxid too)
            # so it is a candidate for being the max avg pid for its species taxid
            # and also a candidate for failing if it is not max avg pid for its species
            $do_one_lowest_level_H{$seq_taxid}  = $level; # records lowest level 
            $do_one_taxid_H{$seqname}           = $seq_taxid;
            $do_one_avgpid_HH{$level}{$seqname} = $avgpid;
            if((! exists $max_pid_per_taxid_HH{$level}{$seq_taxid}) || ($avgpid > $max_pid_per_taxid_HH{$level}{$seq_taxid})) { 
              $max_pid_per_taxid_HH{$level}{$seq_taxid}    = $avgpid;
              $argmax_pid_per_taxid_HH{$level}{$seq_taxid} = $seqname;
            }
          }
          # keep track of number of sequences per taxid, if the --fimin option was used
          if(($do_one_min) && ($level eq "phylum")) { 
            # only do this at the phylum level, so we don't do it each time for all 3 levels
            if(($curfailstr_H{$seqname} eq "") && ($seq_taxid ne "-") && ($seq_taxid ne "1")) { 
              $do_one_min_taxid_H{$seqname} = $seq_taxid;
              if(! exists $one_min_ntaxid_H{$seq_taxid}) { 
                $one_min_ntaxid_H{$seq_taxid} = 0; 
              }
              else { 
                $one_min_ntaxid_H{$seq_taxid}++;
              }
            }
          }
        }
      }
      close(TAB);      
    } # end of foreach $level
    # $do_one is TRUE, so ffor all sequences that could be max avg pid for their species, 
    # determine those that are not and fail them
    foreach $seqname (sort keys %do_one_taxid_H) { 
      my $seq_taxid   = $do_one_taxid_H{$seqname};
      my $level       = $do_one_lowest_level_H{$seq_taxid};
      my $max_seqname = $argmax_pid_per_taxid_HH{$level}{$seq_taxid};
      if($seqname ne $max_seqname) { 
        $curfailstr_H{$seqname} .= sprintf("not-max-avg-pid(%.3f<%.3f);", $do_one_avgpid_HH{$level}{$seqname}, $max_pid_per_taxid_HH{$level}{$seq_taxid});
      }
    }
    if($do_one_min) { 
      # remove any sequences with too few sequences in their seq taxid
      foreach $seqname (sort keys %do_one_min_taxid_H) { 
        my $seq_taxid   = $do_one_min_taxid_H{$seqname};
        if($one_min_ntaxid_H{$seq_taxid} < $one_min) { 
          $curfailstr_H{$seqname} .= sprintf("too-few-in-species-taxid(%d<%d);", $one_min_ntaxid_H{$seq_taxid}, $one_min); 
        }
      }
    }
  }

  # now reformat the error string to include the stage name
  my $nfail = 0;
  foreach $seqname (keys %curfailstr_H) { 
    if($curfailstr_H{$seqname} ne "") { 
      $curfailstr_H{$seqname} = "ingroup-analysis[" . $curfailstr_H{$seqname} . "];;";
      $nfail++;
    }
  }
    
  # now output pass and fail files
  update_and_output_pass_fails(\%curfailstr_H, $seqfailstr_HR, $seqorder_AR, 1, $out_root, "ingrup", $ofile_info_HHR); # 1: do not require all seqs in seqorder exist in %curfailstr_H

  return $nfail;
}

#################################################################
# Subroutine:  parse_alipid_output_to_create_dist_file()
# Incept:      EPN, Wed Jul 11 12:38:46 2018
#
# Purpose:     Given an esl-alipid output and a hash of sequences
#              to use, create a 'distance' file that we can use
#              as input to esl-cluster.
#
# Arguments:
#   $alipid_file:    name of esl-alipid output file to parse
#   $useme_HR:       ref to hash, key is sequence name
#   $dist_file:      name of distance file to create
#   $ofile_info_HHR: ref to the ofile info 2D hash
#
# Returns:    void
#
# Dies:       if we have trouble opening either file or parsing alipid file
#################################################################
sub parse_alipid_output_to_create_dist_file { 
  my $sub_name = "parse_alipid_output_to_create_dist_file";
  my $nargs_expected = 4;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($alipid_file, $useme_HR, $dist_file, $ofile_info_HHR) = (@_);

  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience

  open(ALIPID,    $alipid_file) || ofile_FileOpenFailure($alipid_file, "RIBO", $sub_name, $!, "reading", $FH_HR);
  open(DIST, ">", $dist_file)   || ofile_FileOpenFailure($dist_file,   "RIBO", $sub_name, $!, "writing", $FH_HR);

  while($line = <ALIPID>) { 
    #EU011733.1 KM065910.1 99.07
    #EU011733.1 AB053242.2 97.22
    #EU011733.1 AB018172.1 96.60
    chomp $line;
    if($line !~ m/^\#/) { 
      my @el_A = split(/\s+/, $line);
      if(scalar(@el_A) != 3) { 
        ofile_FAIL("ERROR in $sub_name, unable to parse line that does not have 8 whitespace-delimited tokens in $alipid_file\n$line\n", "RIBO", 1, $FH_HR);
      }
      my ($seq1, $seq2, $pid) = ($el_A[0], $el_A[1], $el_A[2]);
      if((exists($useme_HR->{$seq1})) && (exists($useme_HR->{$seq2}))) { 
        printf DIST ("$seq1 $seq2 %.4f\n", ((100. - $pid) / 100.));
      }
    }
  }
  close(DIST);
  
  close(ALIPID);

  return;
}

#################################################################
# Subroutine:  parse_dist_file_to_choose_centroids()
# Incept:      EPN, Wed Jul 11 13:48:34 2018
#
# Purpose:     Given an esl-alipid output and information
#              about which cluster those sequences belong
#              to, choose a centroid for each cluster as
#              the sequence with maximum similarity with
#              all other sequences in its cluster. Write
#              all centroids to a file.
#
# Arguments:
#   $dist_file:       name of esl-alipid output file to parse
#   $out_list_file:   name of list file to create with centroid seqs
#   $in_cluster_HR:   ref to hash, key is sequence name, value is cluster index ALREADY FILLED
#   $cluster_size_HR: ref to hash, key is cluster index, value is size of the cluster ALREADY FILLED
#   $is_centroid_HR:  ref to hash, key is sequence name, value is '1' if centroid, else '0' FILLED HERE
#   $not_centroid_HR: ref to hash, key is sequence name, value is '0' if centroid, else '1' FILLED HERE
#   $ofile_info_HHR:  ref to the ofile info 2D hash
#
# Returns:    void
#
# Dies:       if we have trouble opening either file or parsing alipid file
#################################################################
sub parse_dist_file_to_choose_centroids { 
  my $sub_name = "parse_dist_file_to_choose_centroids";
  my $nargs_expected = 7;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($dist_file, $out_list_file, $in_cluster_HR, $cluster_size_HR, $is_centroid_HR, $not_centroid_HR, $ofile_info_HHR) = (@_);

  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience
  my %sumdist_H = (); # key sequence name, value is summed distance between this sequence and all other sequences in its cluster

  open(DIST, $dist_file) || ofile_FileOpenFailure($dist_file, "RIBO", $sub_name, $!, "writing", $FH_HR);

  while($line = <DIST>) { 
    #AJ306437.1 JN941634.1 0.1474
    #AJ306437.1 AJ496250.1 0.1375
    #AJ306437.1 HF968784.1 0.0515
    chomp $line;
    if($line !~ m/^\#/) { 
      my @el_A = split(/\s+/, $line);
      my ($seq1, $seq2, $dist) = ($el_A[0], $el_A[1], $el_A[2]);
      if(! exists $in_cluster_HR->{$seq1}) { 
        ofile_FAIL("ERROR in $sub_name, read unexpected sequence $seq1 in $dist_file\n", "RIBO", 1, $FH_HR);
      }
      if(! exists $in_cluster_HR->{$seq2}) { 
        ofile_FAIL("ERROR in $sub_name, read unexpected sequence $seq2 in $dist_file\n", "RIBO", 1, $FH_HR);
      }
      if($in_cluster_HR->{$seq1} eq $in_cluster_HR->{$seq2}) { 
        $sumdist_H{$seq1} += $dist;
        $sumdist_H{$seq2} += $dist;
      }
    }
  }
  close(DIST);

  my %seq_mindist_H = (); # key is cluster index, value is sequence in that cluster with min summed distance to all other seqs in the cluster
  my %mindist_H     = (); # key is cluster index, value is min summed distance of $seq_mindist_H{} to all other seqs in the cluster
  my $cluster;
  my $seqname;
  # go back through all sequences to determine centroid of all clusters
  foreach $seqname (sort keys %{$in_cluster_HR}) { 
    $cluster = $in_cluster_HR->{$seqname};
    if($cluster_size_HR->{$cluster} == 1) { # a singleton
      $sumdist_H{$seqname} = 0.;
    }
    elsif(! exists $sumdist_H{$seqname}) { 
      ofile_FAIL("ERROR in $sub_name, did not read any distance info for $seqname", "RIBO", 1, $FH_HR);
    }
    if((! exists $mindist_H{$cluster}) || 
       ($sumdist_H{$seqname} < $mindist_H{$cluster})) { 
      $seq_mindist_H{$cluster} = $seqname;
      $mindist_H{$cluster} = $sumdist_H{$seqname};
    }
  }

  # record centroid for each cluster
  foreach $cluster (sort keys %mindist_H) { 
    my $centroid = $seq_mindist_H{$cluster};
    if(! exists $is_centroid_H{$centroid}) { 
      ofile_FAIL("ERROR in $sub_name, $seqname does not exists in input %is_centroid_H", "RIBO", 1, $FH_HR);
    }
    if(! exists $not_centroid_H{$centroid}) { 
      ofile_FAIL("ERROR in $sub_name, $seqname does not exists in input %not_centroid_H", "RIBO", 1, $FH_HR);
    }
    $is_centroid_HR->{$centroid}  = 1;
    $not_centroid_HR->{$centroid} = 0;
  }

  return;
}

#################################################################
# Subroutine:  parse_esl_cluster_output()
# Incept:      EPN, Wed Jul 11 13:21:09 2018
#
# Purpose:     Given an esl-cluster output file, fill two hashes
#              with information from it.
#
# Arguments:
#   $in_file:         name of esl-cluster output file
#   $in_cluster_HR:   ref to hash, key is sequence from $in_file,
#                     value is cluster index this sequence is in
#   $cluster_size_HR: ref to hash, key is cluster index (possible
#                     value in %{$in_cluster_HR}), value is 
#                     number of sequences in that cluster
#   $ofile_info_HHR: ref to the ofile info 2D hash
#
# Returns:    Total number of clusters (max key in %{$cluster_size_HR})
#
# Dies:       if we have trouble opening input file
#             or we read a sequence in the input file that
#             does not exist as a key in %{$in_cluster_HR}
#             or $in_file has a line in unexpected format
#################################################################
sub parse_esl_cluster_output {
  my $sub_name = "parse_esl_cluster_output";
  my $nargs_expected = 4;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($in_file, $in_cluster_HR, $cluster_size_HR, $ofile_info_HHR) = (@_);

  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience

  open(IN, $in_file) || ofile_FileOpenFailure($in_file, "RIBO", $sub_name, $!, "reading", $FH_HR);

  my $nsingletons   = 0; # number of singleton 'clusters' we've seen so far
  my $prv_read_cidx = 0; # most recent cluster index from esl-cluster output we've seen (init at 0 is fine) 
  my $cidx = undef;      # cluster index for our purposes here (differs from index in esl-cluster output because
                         # singleton clusters are not counted
  while($line = <IN>) { 
    #Singleton:
    #= AB016022.1	-	-
    #
    #Cluster 1:  0.099
    #= MH201387.1 	1	0.099
    #= HQ682648.1 	1	0.099
    #= AF157125.1 	1	0.099
    chomp $line;
    if($line =~ m/^\=/) { 
      my @el_A = split(/\s+/, $line);
      if(scalar(@el_A) != 4) { 
        ofile_FAIL("ERROR in $sub_name, unable to parse line that does not have 4 whitespace-delimited tokens in $in_file\n$line\n", "RIBO", 1, $FH_HR);
      }
      my ($seqname, $read_cidx) = ($el_A[1], $el_A[2]); 
      if(! exists $in_cluster_HR->{$seqname}) { 
        ofile_FAIL("ERROR in $sub_name, read unexpected sequence $seqname in esl-cluster output $in_file\n", "RIBO", 1, $FH_HR);
      }
      # determine cluster number for our accounting, will likely differ from esl-cluster because it didn't count singletons as clusters
      if($read_cidx eq "-") { 
        $nsingletons++;
        $cidx = $prv_read_cidx + $nsingletons;
      }
      else { # part of a esl-cluster cluster
        $cidx = $read_cidx + $nsingletons;
        $prv_read_cidx = $read_cidx;
      }
      $in_cluster_HR->{$seqname} = $cidx;
      if(! exists $cluster_size_HR->{$cidx}) { 
        $cluster_size_HR->{$cidx} = 1;
      }
      else { 
        $cluster_size_HR->{$cidx}++;
      }
    }
  }
  close(IN);

  return ($nsingletons + $prv_read_cidx); 
}

#################################################################
# Subroutine:  parse_srcchk_file()
# Incept:      EPN, Tue Jun 26 15:36:11 2018
#
# Purpose:     Parse the srcchk output file run with option
#              -f 'taxid,organism,strain' and fill %{$seqtaxid_HR}
#              with taxid for each sequence in the file,
#              and %{$seqorgn_HR} and %{$seqstrain_HR} with organism for each
#              sequence (if $seqorgn_HR/$seqstrain_HR is defined).
#              Also, parse the six column taxonomy tree file,
#              for any sequence in the srcchk output file with
#              a taxid NOT in the taxonomy tree (obsolete taxid)
#              give that sequence a taxid of 1.
#
# Arguments:
#   $srcchk_file:    name of srcchk output file to parse
#   $taxtree_file:   name of taxonomy tree file
#   $seqtaxid_HR:    ref to hash of failure string to add to here
#   $seqorgn_HR:     ref to hash of organism values for each sequence
#   $seqstrain_HR:   ref to hash of strain value for each sequence
#   $seqorder_AR:    ref to array of sequences in order
#   $ofile_info_HHR: ref to the ofile info 2D hash
#
# Returns:    void
#
# Dies:       if a sequence in @{$seqorder_AR} does not have a taxid in $in_file
#################################################################
sub parse_srcchk_file { 
  my $sub_name = "parse_srcchk_file";
  my $nargs_expected = 7;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($srcchk_file, $taxtree_file, $seqtaxid_HR, $seqorgn_HR, $seqstrain_HR, $seqorder_AR, $ofile_info_HHR) = (@_);

  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience
  my $seqname;
  my %valid_taxid_H = ();

  %{$seqtaxid_HR} = ();

  # first parse the taxtree file to determine all valid taxids
  open(TAXTREE, $taxtree_file)  || ofile_FileOpenFailure($taxtree_file,  "RIBO", $sub_name, $!, "reading", $FH_HR);
  # first line is header
  my $line = <TAXTREE>;
  while($line = <TAXTREE>) { 
    #1	1	no rank	1	0	0
    #2	131567	superkingdom	3	1	0
    my @el_A = split(/\t/, $line);
    if(scalar(@el_A) != 6) { 
      ofile_FAIL("ERROR in $sub_name, taxtree file line did not have exactly 6 tab-delimited tokens: $line\n", "RIBO", $?, $FH_HR);
    }
    $valid_taxid_H{$el_A[0]} = 1; 
  }
  close(TAXTREE);

  open(SRCCHK, $srcchk_file)  || ofile_FileOpenFailure($srcchk_file,  "RIBO", $sub_name, $!, "reading", $FH_HR);
  # first line is header, determine max number of fields we should see based on this
  #accession  taxid   organism
  # OR 
  #accession	taxid	organism	strain	strain#2	
  my $header_line = <SRCCHK>;
  my @el_A = split(/\t/, $header_line);
  my $max_nel = scalar(@el_A); 
  while($line = <SRCCHK>) { 
    #accessiontaxidorganism
    #AY343923.1	175243	uncultured Ascomycota	
    #DQ181066.1	343769	Dilophotes sp. UPOL 000244	
    chomp $line;
    @el_A = split(/\t/, $line);
    my ($seqname, $taxid, $organism, $strain);
    # there can anywhere between be 3 and $max_nel elements
    if((scalar(@el_A) >= 4) && (scalar(@el_A) <= $max_nel)) { 
      ($seqname, $taxid, $organism, $strain) = @el_A;
    }
    elsif(scalar(@el_A) == 3) { 
      ($seqname, $taxid, $organism) = @el_A;
      $strain = "";
    }
    else { 
      ofile_FAIL("ERROR in $sub_name, srcchk file line did not have at least 3 and no more than $max_nel tab-delimited tokens: $line\n", "RIBO", $?, $FH_HR);
    }
    if(! exists $valid_taxid_H{$taxid}) { # replace obsolete taxids with '1'
      $taxid = 1; 
      $organism = ""
    }
    $seqtaxid_HR->{$seqname} = $taxid;
    if(defined $seqorgn_HR) { 
      $seqorgn_HR->{$seqname} = $organism; 
      if(($valid_taxid_H{$taxid}) && (! defined $organism || $organism eq "")) { 
        ofile_FAIL("ERROR in $sub_name, srcchk did not return a organism for line: $line\n", "RIBO", $?, $FH_HR);
      }
    }
    if(defined $seqstrain_HR) { 
      $seqstrain_HR->{$seqname} = $valid_taxid_H{$taxid} ? $strain : ""; # $strain can be ""
    }
  }
  close(SRCCHK);

  # make sure all sequences were read
  foreach $seqname (@{$seqorder_AR}) { 
    if(! exists $seqtaxid_HR->{$seqname}) { 
      ofile_FAIL("ERROR in $sub_name, no taxid information for $seqname in $srcchk_file\n", "RIBO", $?, $FH_HR);
    }
  }
}

#################################################################
# Subroutine:  parse_tax_level_file()
# Incept:      EPN, Wed Jun 27 12:35:37 2018
#
# Purpose:     Parse the 'taxonomy with levels' file created by 
#              find_taxonomy_ancestors.pl
#              and update counts in %{$level_ct_HR} where each
#              key is an taxid. Only count for sequences that
#              are present in %{$useme_HR} if defined, if it
#              is not defined, count all seqs.
#
# Arguments:
#   $in_file:        name of srcchk output file to parse
#   $useme_HR:       ref to hash, 
#                    if defined: count only seqs $seq for which 
#                    $useme_HR->{$seq} exists and is equal to "" or "1"
#                    if undefined, count for all seqs
#   $gtaxid_HR:      ref to hash to fill, key is sequence name, value is
#                    group taxid from column 4, can be undef to not fill
#                    if defined, fill for all sequences, regardless of
#                    values in $useme_HR
#   $count_HR:       ref to hash to fill, key is taxid in column 4
#   $FH_HR:          file handle hash ref
#
# Returns:    void
#
# Dies:       never
#################################################################
sub parse_tax_level_file { 
  my $sub_name = "parse_tax_level_file";
  my $nargs_expected = 5;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 
  my ($in_file, $useme_HR, $gtaxid_HR, $count_HR, $FH_HR) = (@_);

  open(IN, $in_file)  || ofile_FileOpenFailure($in_file,  "RIBO", $sub_name, $!, "reading", $FH_HR);

  while(my $line = <IN>) { 
    chomp $line;
    my @el_A = split(/\t+/, $line);
    if(scalar(@el_A) != 4) { 
      ofile_FAIL("ERROR in $sub_name, could not parse taxinfo file $in_file line (%d elements, expected 4)", "RIBO", $?, $FH_HR);
    }
    
    my ($seq, $seq_taxid, $seq_spec, $group_taxid) = ($el_A[0], $el_A[1], $el_A[2], $el_A[3]);
    if(defined $gtaxid_HR) { $gtaxid_HR->{$seq} = $group_taxid; }
    if(! exists $count_HR->{$group_taxid}) { # initialize
      $count_HR->{$group_taxid} = 0;
    }
    my $useme = undef;
    if(defined $useme_HR) { 
      if(exists $useme_HR->{$seq}) { # $seq key exists 
        $useme = (($useme_HR->{$seq} eq "1") || ($useme_HR->{$seq} eq "")) ? 1 : 0; # count only if value is "1" or ""
      }
      else { # $seq key does not exist, do not count
        $useme = 0;
      }
    }
    else { 
      $useme = 1; # $useme_HR, not defined count all seqs
    }
    if($useme) { 
      $count_HR->{$group_taxid}++;
    }
  }
  close(IN);

  return;
}

#################################################################
# Subroutine:  reformat_sequence_names_in_fasta_file()
# Incept:      EPN, Tue May 29 11:24:06 2018
#
# Purpose:     Given a fasta file, create a copy of it with 
#              sequences renamed in accession.version format
#              for those sequence names that match an 
#              expected input format.
#
# Arguments:
#   $in_file:      name of input file to change names of
#   $out_file:     name of output file to create
#   $FH_HR:        REF to hash of file handles, including "cmd"
#
# Returns:    void
#
# Dies:       if a sequence name in $in_file does not match the expected
#             format and $check_format is TRUE.
#################################################################
sub reformat_sequence_names_in_fasta_file { 
  my $sub_name = "reformat_sequence_names_in_fasta_file()";
  my $nargs_expected = 3;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($in_file, $out_file, $FH_HR) = (@_);

  open(IN,       $in_file)  || ofile_FileOpenFailure($in_file,  "RIBO", $sub_name, $!, "reading", $FH_HR);
  open(OUT, ">", $out_file) || ofile_FileOpenFailure($out_file, "RIBO", $sub_name, $!, "writing", $FH_HR);

  while(my $line = <IN>) { 
    if($line =~ /^>(\S+)/) { 
      # header line
      my $orig_name = $1;
      my $desc = "";
      if($line =~ /^\>\S+\s+(.+)/) { 
        $desc = " " . $1;
      }
      my $new_name = ribo_ConvertFetchedNameToAccVersion($orig_name, 0, $FH_HR);
      printf OUT (">%s%s\n", $new_name, $desc);
    }
    else { 
      print OUT $line; 
    }
  }
  close(OUT);
      
  return;
}

#################################################################
# Subroutine:  filter_list_file()
# Incept:      EPN, Tue May 29 15:15:42 2018
#
# Purpose:     Given a file with a list of sequences names, 
#              filter that list to make a new list file based on 
#              the values in the hash %{$value_HR}. Keep only sequences 
#              for which the value of %{$value_HR} is <= $maxvalue.
#
# Arguments:
#   $in_file:      name of input list file to filter
#   $out_file:     name of output list file to create
#   $maxvalue:     maximum value to allow in %{$HR} 
#   $value_HR:     ref to hash with values to use to determine filtering
#   $FH_HR:        REF to hash of file handles, including "cmd"
#
# Returns:    Two values: 
#             Number of sequences kept in filtered list
#             Number of sequences removed from input list
#
# Dies:       if a sequence name read in $in_file does not exist in %{$value_HR}
#################################################################
sub filter_list_file { 
  my $sub_name = "filter_list_file()";
  my $nargs_expected = 5;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($in_file, $out_file, $maxvalue, $value_HR, $FH_HR) = (@_);

  open(IN,       $in_file)  || ofile_FileOpenFailure($in_file,  "RIBO", "ribodbmaker.pl:main()", $!, "reading", $FH_HR);
  open(OUT, ">", $out_file) || ofile_FileOpenFailure($out_file, "RIBO", "ribodbmaker.pl:main()", $!, "writing", $FH_HR);

  my $nkept    = 0;
  my $nremoved = 0;
  while(my $line = <IN>) { 
    chomp $line;
    if($line =~ /^(\S+)/) { 
      my $seqname = $1;
      if(! exists $value_HR->{$seqname}) { 
        ofile_FAIL("ERROR in $sub_name, the following command failed:\n$cmd\n", "RIBO", $?, $FH_HR); 
      }
      if($value_HR->{$seqname} <= $maxvalue) { 
        print OUT $line .= "\n";
        $nkept++;
      }
      else { 
        $nremoved++; 
      }
    }
  }
  close(IN);
  close(OUT);
  
  return ($nkept, $nremoved);
}

#################################################################
# Subroutine:  update_and_output_pass_fails()
# Incept:      EPN, Wed Jun 20 12:43:14 2018
#
# Purpose:     Given a hash of current failure strings for all
#              sequences, in which sequences that pass have a "" value,
#              Update %{$seqfailstr_H} by adding the current failure
#              strings in %{$curfailstr_H} and output a file listing all
#              sequences that passed, and a file listing all sequences
#              that failed this stage.
#
# Arguments:
#   $curfailstr_HR:  ref to hash of current fail strings
#   $seqfailstr_HR:  ref to hash of full fail strings, to add to, can be undef to not add to
#   $seqorder_AR:    ref to array of sequence order
#   $mainout:        '1' to output description of the two files created here to stdout, 
#                    '0' to only output description to .list file
#   $out_root:       string for naming output files
#   $stage_key:      string that explains a stage
#   $ofile_info_HHR: ref to the ofile info 2D hash
#
# Returns:    Number of sequences that pass.
#
# Dies:       if $curfailstr_HR->{$key} does not exist for an expected $key from @{$seqorder_AR}
#             if $seqfailstr_HR->{$key} does not exist for an expected $key from @{$seqorder_AR}
# 
#################################################################
sub update_and_output_pass_fails { 
  my $sub_name = "update_and_output_pass_fails()";
  my $nargs_expected = 7;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($curfailstr_HR, $seqfailstr_HR, $seqorder_AR, $mainout, $out_root, $stage_key, $ofile_info_HHR) = (@_);

  my %pass_H = (); # temporary hash refilled per stage, key is sequence name, value is '1' if passes filter, '0' if fails
  my $npass   = 0;  # number of sequences that passed current stage
  my $nfail   = 0;  # number of sequences that failed current stage
  my $seqname = undef; 
  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience
  # do we we require all sequences in @{$seqorder_AR} get output (have values in %{$curfailstr_HR}?
  # our rule is: if they have the same number of values, they should all be the same
  my $require_all_seqs = (scalar(@{$seqorder_AR}) eq scalar(keys %{$curfailstr_HR})) ? 1 : 0;

  foreach $seqname (@{$seqorder_AR}) { 
    if(exists $curfailstr_HR->{$seqname}) { 
      if((defined $seqfailstr_HR) && 
         (! exists $seqfailstr_HR->{$seqname})) { ofile_FAIL("ERROR in $sub_name, sequence $seqname not in seqfailstr_HR hash", "RIBO", 1, $FH_HR); }
      if($curfailstr_HR->{$seqname} ne "" && $curfailstr_HR->{$seqname} ne "0") { 
        if(defined $seqfailstr_HR) { $seqfailstr_HR->{$seqname} .= $curfailstr_HR->{$seqname}; }
        $pass_H{$seqname} = 0;
        $nfail++;
      }
      else { 
        $pass_H{$seqname} = 1;
        $npass++;
      }
    }
    else { # ! exists $curfailstr_HR->{$seqname}
      if($require_all_seqs) { 
        ofile_FAIL("ERROR in $sub_name, sequence $seqname not in curfailstr_HR hash", "RIBO", 1, $FH_HR); 
      }
    }
  }
  
  my $pass_file = $out_root . "." . $stage_key . ".pass.seqlist";
  my $fail_file = $out_root . "." . $stage_key . ".fail.seqlist";

  open(PASS, ">", $pass_file) || ofile_FileOpenFailure($pass_file,  "RIBO", $sub_name, $!, "writing", $FH_HR);
  open(FAIL, ">", $fail_file) || ofile_FileOpenFailure($fail_file,  "RIBO", $sub_name, $!, "writing", $FH_HR);
  foreach $seqname (@{$seqorder_AR}) { 
    if($pass_H{$seqname}) { print PASS $seqname . "\n"; }
    else                  { print FAIL $seqname . "\n"; }
  }
  close(PASS);
  close(FAIL);

  my $pass_desc = "";
  my $fail_desc = "";
  if($stage_key eq "final") {  # special case, we word it a bit differently
    $pass_desc = "sequences that PASSed all filters and stages and are in the final set [$npass]";
    $fail_desc = "sequences that FAILed one or more filter or stage and are NOT in the final set [$nfail]";
  }
  else { 
    $pass_desc = "sequences that PASSed $stage_key stage [$npass]";
    $fail_desc = "sequences that FAILed $stage_key stage [$nfail]";
  }
  ofile_AddClosedFileToOutputInfo($ofile_info_HHR, "RIBO", $stage_key . ".pass.seqlist", "$pass_file", 0, $pass_desc);
  ofile_AddClosedFileToOutputInfo($ofile_info_HHR, "RIBO", $stage_key . ".fail.seqlist", "$fail_file", 0, $fail_desc);

  return $npass;
}

#################################################################
# Subroutine:  fblast_stage
# Incept:      EPN, Thu Jun 21 09:14:13 2018
#
# Purpose:     Initialize all values of a hash to the empty string.
#
# Arguments:
#   $execs_HR:       ref to hash of executables
#   $seqfailstr_HR:  ref to hash of failure string to add to here
#   $seqorder_AR:    ref to array of sequences in order
#   $out_root:       for naming output files
#   $opt_HHR:        ref to 2D hash of cmdline options
#   $ofile_info_HHR: ref to the ofile info 2D hash
#
# Returns:    Number of sequences that pass (do not fail) BLAST filter
#
# Dies: upon file open failure
#       if blast output violates assumptions
# 
#################################################################
sub fblast_stage { 
  my $sub_name = "fblast_stage()";
  my $nargs_expected = 6;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($execs_HR, $seqfailstr_HR, $seqorder_AR, $out_root, $opt_HHR, $ofile_info_HHR) = (@_);

  my %curfailstr_H = ();  # will hold fail string 
  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience
  my $seqname;

  ribo_InitializeHashToEmptyString(\%curfailstr_H, $seqorder_AR);

  # split input sequence file into chunks and process each
  my $chunksize = opt_Get("--fbcall",   \%opt_HH) ? $nseq : opt_Get("--fbcsize", \%opt_HH); # number of sequences in each file that BLAST will be run on
  my $wordsize  = opt_Get("--fbword",   \%opt_HH); # argument for -word_size option to blastn
  my $evalue    = opt_Get("--fbevalue", \%opt_HH); # argument for -evalue option to blastn
  my $dbsize    = opt_Get("--fbdbsize", \%opt_HH); # argument for -dbsize option to blastn
  my $seqline = undef;
  my $seq = undef;
  my $cur_seqidx = 0;
  my $chunk_sfetch_file  = undef;
  my $chunk_fasta_file   = undef;
  my $chunk_blast_file   = undef;
  my @chunk_blast_file_A = (); # array of all $chunk_blast_file names
  my $concat_blast_file  = $out_root . "." . $stage_key . ".blast";  # name of concatenated blast output file
  my $sfetch_cmd         = undef;
  my $blast_cmd          = undef; 
  my %cur_nhit_H         = (); # key is sequence name, value is number of of hits this sequence has in current chunk
                               # only keys for sequence names in current chunk exist in the hash
  my %nblasted_H         = (); # key is sequence name, value is number of times this sequence was ever in the current set 
                               # (e.g. times blasted against itself), should be 1 for all at end of function
  foreach $seq (@{$seqorder_AR}) { 
    $nblasted_H{$seq} = 0;
  }

  # loop through all seqs
  # when we reach $chunksize (50) seqs in our current temp file, stop and run blast
  # this avoids the N^2 runtime of running blast all v all
  # 50 was good tradeoff between overhead of starting up blast and speed of execution on 18S
  open(LIST, $full_list_file) || ofile_FileOpenFailure($full_list_file,  "RIBO", "ribodbmaker.pl:main()", $!, "reading", $ofile_info_HH{"FH"});
  my $keep_going   = 1; 
  my $cidx         = 0; # chunk counter
  my $do_blast     = 0; # flag for whether we need to run blast on current set
  my $do_open_next = 1; # flag for whether we need to open a new chunk sequence file or not
  while($keep_going) { 
    if($do_open_next) { # open new sfetch file
      $cidx++;
      $chunk_sfetch_file = $out_root . "." . $stage_key . "." . $cidx . ".sfetch"; # name of our temporary sfetch file
      $chunk_fasta_file  = $out_root . "." . $stage_key . "." . $cidx . ".fa";     # name of our temporary fasta file
      $chunk_blast_file  = $out_root . "." . $stage_key . "." . $cidx  .".blast";  # name of our temporary blast file
      open(SFETCH, ">", $chunk_sfetch_file) || ofile_FileOpenFailure($chunk_sfetch_file,  "RIBO", "ribodbmaker.pl:main()", $!, "writing", $ofile_info_HH{"FH"});
      $cur_seqidx   = 0;
      %cur_nhit_H   = ();
      $do_open_next = 0;
      $do_blast     = 0;
    }
    if($seqline = <LIST>) { 
      $seq = $seqline;
      chomp($seq);
      $cur_nhit_H{$seq} = 0;
      $nblasted_H{$seq}++;
      print SFETCH $seqline;
      $cur_seqidx++;
      if($cur_seqidx == $chunksize) { # reached chunksize, close file and blast, below
        close(SFETCH);
        $do_blast     = 1; # set flag to blast
        $do_open_next = 1; # set flag to open new output file when we read the next seq
      }
    }
    else { # no more sequences
      close(SFETCH);
      $do_blast     = ($cur_seqidx > 0) ? 1 : 0; # set flag to blast if we have any seqs in the set
      $do_open_next = 0;                         # out of seqs, lower flag to open new output file 
      $keep_going   = 0;                         # set flag to stop reading sequences
    }
    if($do_blast) { 
      if(! $do_prvcmd) { # NOTE: this will only work if previous run used --fbcall and --keep
        $sfetch_cmd = "esl-sfetch -f $full_fasta_file $chunk_sfetch_file > $chunk_fasta_file";
        ribo_RunCommand($sfetch_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"});
        if(! $do_keep) { 
          ribo_RunCommand("rm $chunk_sfetch_file", opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"});
        }
        $blast_cmd  = $execs_H{"blastn"} . " -evalue $evalue -dbsize $dbsize -word_size $wordsize -num_threads 1 -subject $chunk_fasta_file -query $chunk_fasta_file -outfmt \"6 qaccver qstart qend nident length gaps pident sacc sstart send evalue\" > $chunk_blast_file";
        # previously I tried to use max_target_seqs, but doesn't guarantee top hit will be to self if identical seq (or superseq) exists
        ribo_RunCommand($blast_cmd, opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"});
      }
      # parse the blast output, keeping track of failures in curfailstr_H
      parse_blast_output_for_self_hits($chunk_blast_file, \%cur_nhit_H, \%curfailstr_H, \%opt_HH, $ofile_info_HH{"FH"});

      push(@chunk_blast_file_A, $chunk_blast_file); # we will concatenate these when we are done
      if((! $do_prvcmd) && (! $do_keep)) { 
        ribo_RunCommand("rm $chunk_fasta_file", opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"});
      }
    }
  }

  # clean up final empty sfetch file that may exist
  if((! $do_keep) && (-e $chunk_sfetch_file)) { 
    ribo_RunCommand("rm $chunk_sfetch_file", opt_Get("-v", \%opt_HH), $ofile_info_HH{"FH"});
  }

  # make sure all seqs were blasted against each other exactly once
  foreach $seq (@{$seqorder_AR}) { 
    if($nblasted_H{$seq} != 1) { 
      ofile_FAIL("ERROR in ribodbmaker.pl::main, sequence $seq was BLASTed against itself $nblasted_H{$seq} times (should be 1)", "RIBO", $?, $ofile_info_HH{"FH"});
    }
  }

  # concatenate the blast output 
  ribo_ConcatenateListOfFiles(\@chunk_blast_file_A, $concat_blast_file, $sub_name, $opt_HHR, $ofile_info_HHR->{"FH"});
  ofile_AddClosedFileToOutputInfo($ofile_info_HHR, "RIBO", $stage_key . ".blast", "$concat_blast_file", 0, "concatenated blast output for chunked sequence file");

  # create pass and fail lists
  return update_and_output_pass_fails(\%curfailstr_H, $seqfailstr_HR, $seqorder_AR, 0, $out_root, "fblast", $ofile_info_HHR); # 0: do not output description of pass/fail lists to log file

}

#################################################################
# Subroutine:  pluralize_level
# Incept:      EPN, Mon Jul 23 20:36:08 2018
#
# Purpose:     Return the plural of 'class', 'order' or 'phylum'
#
# Arguments:
#   $level:   the level
#
# Returns:    string that is plural of $level
#
# Dies: Never
# 
#################################################################
sub pluralize_level { 
  my $sub_name = "pluralize_level";
  my $nargs_expected = 1;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($level) = (@_);

  if($level eq "class") {
    return "classes";
  }
  if($level eq "phylum") {
    return "phyla";
  }
  return $level . "s";
}

#################################################################
# Subroutine:  determine_riboaligner_lpos_rpos
# Incept:      EPN, Mon Jul 30 11:32:26 2018
#
# Purpose:     Return the maximum 5' model position ($max_lpos) and minimum
#              3' model position that a sequence must extend to in the
#              alignment, based on model length and input options.
#
# Arguments:
#   $mlen:    model length
#   $opt_HHR: ref to 2D hash of cmdline options
# 
# Returns:    Two values:
#             ($max_lpos, $min_rpos) [see Purpose]
#
# Dies: Never
# 
#################################################################
sub determine_riboaligner_lpos_rpos { 
  my $sub_name = "determine_riboaligner_lpos_rpos";
  my $nargs_expected = 2;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($mlen, $opt_HHR) = (@_);

  my $in_pos   = undef;
  my $max_lpos = undef;
  my $min_rpos = undef;
  $in_pos  = opt_Get("--fmpos", $opt_HHR); # use this by default
  if(opt_IsUsed("--fmlpos", $opt_HHR)) { 
    # ignore --pos value, this also requires --rpos, epn-options already checked for this 
    $max_lpos = opt_Get("--fmlpos", $opt_HHR);
    $min_rpos = opt_Get("--fmrpos", $opt_HHR);
    $in_pos = undef;
  }
  else { 
    $max_lpos = $in_pos;
    $min_rpos = $mlen - $in_pos + 1;
  }

  return($max_lpos, $min_rpos);
}

#################################################################
# Subroutine:  parse_ali_apos_to_uapos_file
# Incept:      EPN, Mon Jul 30 12:51:38 2018
#
# Purpose:     Parse an output file from ali-apos-to-uapos.pl
#              and fill %{$uapos_HR} and %{$gap_HR, with info 
#              from that file.
# 
# Arguments:
#   $in_file:        input file to parse
#   $uapos_HR:       ref to hash, key is sequence name, value is unaligned position
#   $gap_HR:         ref to hash, key is sequence name, value is 'gap' or 'nongap'
#   $opt_HHR:        ref to 2D hash of cmdline options
#   $ofile_info_HHR: ref to the ofile info 2D hash
#
# Returns:    void, fills %{$uapos_HR} and %{$gap_HR}
#
# Dies: If format of $in_file is invalid, or $in_file does not exist or is not readable
# 
#################################################################
sub parse_ali_apos_to_uapos_file { 
  my $sub_name = "parse_ali_apos_to_uapos_file";
  my $nargs_expected = 5;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($in_file, $uapos_HR, $gap_HR, $opt_HHR, $ofile_info_HHR) = (@_);

  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience

  open(IN, $in_file)  || ofile_FileOpenFailure($in_file,  "RIBO", $sub_name, $!, "reading", $FH_HR);

  while(my $line = <IN>) { 
    ##seqname     uapos  gap?  
    #AB034910.1      39  nongap
    #KC670242.1      60  nongap
    #DQ677995.1       -  gap   
    chomp $line;
    if($line !~ /^\#/) { 
      my @el_A = split(/\s+/, $line);
      if(scalar(@el_A) != 3) { 
        ofile_FAIL(sprintf("ERROR in $sub_name, could not parse ali-apos-to-uapos.pl output file $in_file line (%d elements, expected 3): $line", scalar(@el_A)), "RIBO", $?, $FH_HR);
      }
      my ($target, $uapos, $gap) = (@el_A);
      $uapos_HR->{$target} = $uapos;
      $gap_HR->{$target}   = $gap;
    }
  }
  close(IN);

  return;
}

#################################################################
# Subroutine:  combine_ali_apos_to_uapos_files
# Incept:      EPN, Mon Jul 30 13:57:04 2018
#
# Purpose:     Given info on which nucleotides align at two 
#              specific model positions, combine them into one
#              file. 
# 
# Arguments:
#   $out_file:       name of output file to create
#   $lpos:           left position
#   $rpos:           right position
#   $seq_AR:         ref to array of all sequence names
#   $lpos_HR:        ref to hash, key is sequence name, value is unaligned position that aligns at $lpos
#   $lgap_HR:        ref to hash, key is sequence name, value is 'gap' or 'nongap' 
#   $rpos_HR:        ref to hash, key is sequence name, value is unaligned position that aligns at $rpos
#   $rgap_HR:        ref to hash, key is sequence name, value is 'gap' or 'nongap' 
#   $ofile_info_HHR: ref to the ofile info 2D hash
#
# Returns:    void
#
# Dies: If unable to create $out_file
# 
#################################################################
sub combine_ali_apos_to_uapos_files {
  my $sub_name = "combine_ali_apos_to_uapos_files";
  my $nargs_expected = 9;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($out_file, $lpos, $rpos, $seq_AR, $lpos_HR, $lgap_HR, $rpos_HR, $rgap_HR, $ofile_info_HHR) = (@_);

  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience

  open(OUT, ">", $out_file)  || ofile_FileOpenFailure($out_file,  "RIBO", $sub_name, $!, "writing", $FH_HR);

  # print explanation of columns:
  print OUT ("# Explanation of tab delimited columns in this file:\n");
  print OUT ("# seqname: name of sequence\n");
  print OUT ("# lpos:  unaligned sequence position that aligns at alignment RF position $lpos\n");
  print OUT ("#        if 'lgap' column is 'gap' then alignment is a gap for this sequence at position $lpos\n");
  print OUT ("#        and so 'lpos' column is the final sequence position aligned before position $lpos\n");
  print OUT ("#        or '-' if no residues exist before position $lpos\n");
  print OUT ("#        or 'NA' if sequence was not aligned\n");
  print OUT ("# rpos:  unaligned sequence position that aligns at alignment RF position $rpos\n");
  print OUT ("#        if 'rgap' column is 'gap' then alignment is a gap for this sequence at position $rpos\n");
  print OUT ("#        and so 'rpos' column is the first sequence position aligned after position $rpos\n");
  print OUT ("#        or '-' if no residues exist after position $rpos\n");
  print OUT ("#        or 'NA' if sequence was not aligned\n");
  print OUT ("# lgap:  'nongap' if position $lpos is not a gap in sequence, 'gap' if it is, or 'NA' if sequence not aligned\n");
  print OUT ("# rgap:  'nongap' if position $rpos is not a gap in sequence, 'gap' if it is, or 'NA' if sequence not aligned\n");
  print OUT ("%s\t%s\t%s\t%s\t%s\n", "#seqname", "lpos", "rpos", "lgap", "rgap");

  foreach my $target (@{$seq_AR}) { 
    my $lpos = "NA";
    my $rpos = "NA";
    my $lgap = "NA";
    my $rgap = "NA";

    if(exists $lpos_HR->{$target} || exists $rpos_HR->{$target} || exists $lgap_HR->{$target} || exists $rgap_HR->{$target}) { 
      if((! exists $lpos_HR->{$target}) || (! exists $rpos_HR->{$target}) || (! exists $lgap_HR->{$target}) || (! exists $rgap_HR->{$target})) { 
        ofile_FAIL("ERROR in $sub_name, $target exists in some but not hashes", "RIBO", $?, $FH_HR);
      }
      $lpos = $lpos_HR->{$target};
      $rpos = $rpos_HR->{$target};
      $lgap = $lgap_HR->{$target};
      $rgap = $rgap_HR->{$target};
    }
    printf OUT ("%s\t%s\t%s\t%s\t%s\n", $target, $lpos, $rpos, $lgap, $rgap); 
  }
  close(OUT);

  return;
}

#################################################################
# Subroutine:  fasta_rewrite_sequence_descriptions
# Incept:      EPN, Wed Sep  5 14:37:59 2018
#
# Purpose:     Rewrite the 'deflines' (sequence descriptions) for
#              sequences in a fasta file based on the family 
#              being annotated ($family), and the organism, strain
#              and length class information.
# 
# Arguments:
#   $in_file:        name of fasta file to update
#   $out_file:       name of new fasta file to create with updated descs
#   $family:         family for the model being used (e.g. "SSU.eukarya")
#   $seqlenclass_HR: ref to hash of length class for each sequence, value should be defined for all seqs
#   $seqorgn_HR:     ref to hash of organism for each sequence, value should be defined for all seqs
#   $seqstrain_HR:   ref to hash of organism for each sequence, value can be undefined for some seqs
#   $opt_HHR:        ref to 2D hash of cmdline options
#   $ofile_info_HHR: ref to the ofile info 2D hash
#
# Returns:    void
#
# Dies: If unable to create $out_file, or doesn't have required
#       info for a sequence in $in_file
# 
#################################################################
sub fasta_rewrite_sequence_descriptions { 
  my $sub_name = "fasta_rewrite_sequence_descriptions";
  my $nargs_expected = 8;
  if(scalar(@_) != $nargs_expected) { printf STDERR ("ERROR, $sub_name entered with %d != %d input arguments.\n", scalar(@_), $nargs_expected); exit(1); } 

  my ($in_file, $out_file, $family, $seqlenclass_HR, $seqorgn_HR, $seqstrain_HR, $opt_HHR, $ofile_info_HHR) = (@_);

  my $FH_HR = $ofile_info_HHR->{"FH"}; # for convenience

  my $subunit_size = undef;   # --def is incompatible with --skipfribo2, so --model must be used and so $family will be defined
  if   ($family =~ m/SSU/) { $subunit_size = "small subunit"; }
  elsif($family =~ m/LSU/) { $subunit_size = "large subunit"; }
  else                     { ofile_FAIL("ERROR in $sub_name, family $family does not have SSU or LSU in it, --def option not yet set up for $family", "RIBO", $!, $FH_HR); }

  open(IN,  $in_file)       || ofile_FileOpenFailure($in_file,  "RIBO", "ribodbmaker.pl:main()", $!, "reading", $ofile_info_HH{"FH"});
  open(OUT, ">", $out_file) || ofile_FileOpenFailure($out_file, "RIBO", "ribodbmaker.pl:main()", $!, "writing", $ofile_info_HH{"FH"});
  while($line = <IN>) { 
    if($line =~ m/^>(\S+)(\s*.+$)/) { 
      chomp $line;
      my ($seqname, $orig_def) = ($1, $2); 
      if(! defined $seqlenclass_HR->{$seqname}) { 
        ofile_FAIL("ERROR trying to create new definition line for $seqname, but no length class information exists for this sequence", $pkgstr, $!, $ofile_info_HH{"FH"}); 
      }
      if(! defined $seqorgn_HR->{$seqname}) { 
        ofile_FAIL("ERROR trying to create new definition line for $seqname, but organism is undefined for this sequence", $pkgstr, $!, $ofile_info_HH{"FH"}); 
      }
      if($seqorgn_HR->{$seqname} eq "") { 
        ofile_FAIL("ERROR trying to create new definition line for $seqname, but organism is blank for this sequence", $pkgstr, $!, $ofile_info_HH{"FH"}); 
      }
      my $orgn_strain = $seqorgn_HR->{$seqname};
      if((defined $seqstrain_HR->{$seqname}) && ($seqstrain_HR->{$seqname} ne "")) { $orgn_strain .= " " . $seqstrain_HR->{$seqname}; }
      my $feature = sprintf("%s ribosomal RNA gene, %s sequence", $subunit_size, ($seqlenclass_HR->{$seqname} eq "full-exact") ? "complete" : "partial");
      printf OUT (">%s %s %s\n", $seqname, $orgn_strain, $feature);
    }
    else { # not a sequence name line, output it as is
      print OUT $line; 
    }
  }
  close(IN);
  close(OUT);

  ofile_AddClosedFileToOutputInfo($ofile_info_HHR, "RIBO", "def.fa", "$out_file", 1, "fasta file with final set of surviving sequences with new deflines (--def)");

  return;
}