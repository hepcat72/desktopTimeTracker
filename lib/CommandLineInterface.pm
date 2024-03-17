package CommandLineInterface;

##
## NOTICE
## ------
## This is a pre-release version of this module, which has been incorporated
## into multiple released tools under http://github.com/hepcat72/.  This module
## has not yet been released as its own stand-alone module.  It is in alpha
## phase development, and while it can be used, as it is found in other tools,
## it is provided with no guarantee.  Core functionality may be subject to
## change before beta release.
##


#Robert William Leach
#Princeton University
#Carl Icahn Laboratory
#Lewis Sigler Institute for Integrative Genomics
#Bioinformatics Group
#Princeton, NJ 08544
#rleach@princeton.edu
#Copyright 2018

use warnings;
use strict;
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev);
use File::Glob ':glob';

#Constants to track stages of command line processing
use constant {CALLED    => 1,
              STARTED   => 1,
              DECLARED  => 2,
              DEFAULTED => 3,
              ARGSREAD  => 4,
              VALIDATED => 5,
              COMMITTED => 6,
              LOGGING   => 7,
              DONE      => 8};

our
  $VERSION = '5.004';
our($compile_err);

#Basic script info
my($script_version_number,
   $created_on_date,
   $help_summary,
   $advanced_help,
   $script_author,
   $script_contact,
   $script_company,
   $script_license);
#Variables that are not directly controlled by the command line
my($default_stub,
   $preserve_args,
   $active_args,
   $defaults_dir,
   $error_limit_default);

#Run mode options
my($help,
   $dry_run,
   $run,
   $version,
   $usage,

   $def_help,
   $def_dry_run,
   $def_run,
   $def_version,
   $def_usage);

#Standard variables controlled by the command line
my($header,
   $user_collide_mode,  #Overrides all option collision modes
   $error_limit,
   $extended,
   $overwrite,
   $skip_existing,
   $append,
   $verbose,
   $quiet,
   $DEBUG,
   $force,
   $pipeline,
   $pipeline_auto,
   $use_as_default);

#Variables controlled by the command line, but are user-configurable
my($outfile_suffix_array,
   $input_files_array,
   $outdirs_array);

#Variables for tracking the command line params, input files, and output_files
my($GetOptHash,
   $getopt_default_mode,
   $input_file_sets,
   $output_file_sets);

#Former global variables converted to package variables
my($stderr_buffer,
   $flushing,
   $last_flush_error,
   $last_flush_warning,
   $verbose_freq_hash,
   $last_verbose_size,
   $last_verbose_state,
   $verbose_warning,
   $error_number,
   $error_limit_met,
   $cli_error_num,
   $num_setup_errors,
   $error_hash,
   $warning_number,
   $warning_hash,
   $infile_line_buffer,
   $debug_number,
   $time_marks,
   $open_out_handles,
   $rejected_out_handles,
   $closed_out_handles,
   $open_in_handles,
   $header_str);

#New variables for tracking internal workings of the code
my($outdirs_added,
   $primary_infile_optid,      #Index into usage_array
   $flagless_multival_optid,   #Index into usage_array
   $usage_array,
   $usage_lookup,
   $unique_refs_hash,
   $file_set_num,
   $max_set_num,
   $unproc_file_warn,
   $optval_returned_before,
   $auto_file_iterate,
   $command_line_stage,
   $outfile_types_hash,
   $outfile_tagteams,
   $tagteam_to_supplied_optid,
   $def_collide_mode,          #Used if not specified per outfile type
   $def_collide_mode_suff,
   $def_collide_mode_outf,
   $def_collide_mode_logf,
   $outfile_mode_lookup,
   $default_infile_added,
   $default_outfile_suffix_added,
   $default_outfile_added,
   $default_outdir_added,
   $default_tagteam_added,
   $logfile_added,
   $logfile_default_added,
   $logfile_suffix_added,
   $default_infile_opt,
   $default_outfile_suffix_opt,
   $default_outfile_opt,
   $default_outdir_opt,
   $default_logfile_opt,
   $default_logfile_suffix_opt,
   $default_outfile_optid,
   $default_suffix_optid,
   $dispdef_max,
   $logfile_optid,
   $logfile_suffix_optid,
   $file_group_num,
   $explicit_quit,
   $cleanup_mode,
   $flag_check_hash,
   $bad_user_opts,              #Records option hashes of invalid user defaults
   $file_indexes_to_usage,

   $genopt_types,
   $fileopt_types,

   $scalar_genopt_types,
   $array_genopt_types,
   $array2d_genopt_types,

   $scalar_fileopt_types,
   $array2d_fileopt_types,

   $scalaropt_types,
   $array2dopt_types,

   $window_width,
   $window_width_def,
   $pipe_cache,
   $lsof_cache,
   $lsof_debugged,
   $runreport,
   $log_handle,
   $logging,
   $log_verbose,
   $log_debug,
   $log_warnings,
   $log_errors,
   $log_header,
   $log_report,
   $log_mirror,
   $def_option_hash,
   $exclusive_options,
   $exclusive_lookup,
   $mutual_params,
   $builtin_mutexes,
   $builtin_add_failures,
   $builtin_edit_failures);

sub _init
  {
    #If preserve_args is defined and the values look different
    if(defined($preserve_args) &&
       (scalar(@ARGV) != scalar(@$preserve_args) ||
	(scalar(@ARGV) && scalar(@$preserve_args) &&
	 $ARGV[0] ne $preserve_args->[0])))
      #Restore ARGV which is assumed to have been manipulated by GetOptions
      {@ARGV = @$preserve_args}
    else
      #Save the command line arguments before they are processed
      {$preserve_args = [map {chomp;$_} @ARGV]}
    #Get all the args before '--'
    my $stop     = 0;
    $active_args = [grep {$stop = 1 if($_ eq '--');!$stop} @$preserve_args];


    #Set buffer-related vars 1st in case any errors are encountered during init
    $command_line_stage        = 0;
    $getopt_default_mode       = undef;
    $stderr_buffer             = undef;
    $flushing                  = 0;
    $last_flush_error          = undef;
    $last_flush_warning        = undef;
    $verbose_freq_hash         = undef;
    $last_verbose_size         = undef;
    $last_verbose_state        = undef;
    $verbose_warning           = undef;
    $error_number              = undef;
    $error_limit_met           = 0;
    $cli_error_num             = undef;
    $num_setup_errors          = 0;
    $error_hash                = undef;
    $warning_number            = undef;
    $warning_hash              = undef;
    $infile_line_buffer        = undef;
    $debug_number              = undef;
    $time_marks                = undef;
    $open_out_handles          = undef;
    $rejected_out_handles      = undef;
    $closed_out_handles        = undef;
    $open_in_handles           = undef;
    $header_str                = undef;
    $window_width              = undef;
    $window_width_def          = 80;
    $pipe_cache                = undef;
    $lsof_cache                = undef;
    $lsof_debugged             = 0;
    $runreport                 = 1;
    $log_handle                = undef;
    $logging                   = undef;
    $log_verbose               = undef;
    $log_debug                 = undef;
    $log_warnings              = undef;
    $log_errors                = undef;
    $log_header                = undef;
    $log_report                = undef;
    $log_mirror                = undef;

    #Basic script info
    $script_version_number = 'unknown';
    $created_on_date       = 'UNKNOWN';
    $help_summary          = undef;
    $advanced_help         = undef;
    $script_author         = undef;
    $script_contact        = undef;
    $script_company        = undef;
    $script_license        = undef;

    #Set some early defaults
    $defaults_dir          = (sglob('~/.rpst',1))[0];
    $default_stub          = 'STDIN';
    $error_limit_default   = 5;
    $header                = undef;

    #These need to be initialized for later
    $outfile_suffix_array  = [];
    $input_files_array     = [];
    $outdirs_array         = [];
    $GetOptHash            = {};
    $input_file_sets       = [];
    $output_file_sets      = [];

    #These command line params should be cleared
    $user_collide_mode     = undef; #This has to be undef to know if user-set
    $def_collide_mode      = undef; #This has to be undef to know if prog-set
    $error_limit           = undef;
    $extended              = undef;
    $overwrite             = undef;
    $skip_existing         = undef;
    $append                = undef;
    $verbose               = undef;
    $quiet                 = undef;
    $DEBUG                 = undef;
    $force                 = undef;
    $pipeline              = undef;
    $pipeline_auto         = undef;
    $use_as_default        = undef;

    #Run mode options - only 1 can be non-zero
    $usage                 = undef;
    $help                  = undef;
    $run                   = undef;
    $dry_run               = undef;
    $version               = undef;

    $def_usage             = 1;
    $def_help              = 0;
    $def_run               = 0;
    $def_dry_run           = 0;
    $def_version           = 0;

    #Initialize the default command line params
    $GetOptHash                   = {};
    $primary_infile_optid         = undef;
    $flagless_multival_optid      = undef;
    $usage_array                  = [];
    $usage_lookup                 = {};
    $unique_refs_hash             = {}; #{variable reference} = primary flag
    $file_set_num                 = undef;
    $max_set_num                  = undef;
    $unproc_file_warn             = 1;
    $optval_returned_before       = {};
    $auto_file_iterate            = 1;  #0=false,non-0=true. See nextFileCombo
    $outfile_types_hash           = {};
    $outfile_tagteams             = {}; #id=>{SUFFOPTID/OTSFOPTID/PRIMARY/REQ..}
    $tagteam_to_supplied_optid    = {};
    $outfile_mode_lookup          = {};
    $default_infile_added         = 0;
    $default_outfile_added        = 0;
    $default_outfile_suffix_added = 0;
    $default_outdir_added         = 0;
    $default_tagteam_added        = 0;
    $logfile_added                = 0;
    $logfile_default_added        = 0;
    $logfile_suffix_added         = 0;
    $builtin_add_failures         = 0;
    $builtin_edit_failures        = 0;
    $default_infile_opt           = 'i|infile=s';
    $default_outfile_suffix_opt   = 'o|suffix=s';
    $default_outfile_opt          = 'outfile=s';
    $default_outdir_opt           = 'outdir=s';
    $default_logfile_opt          = 'logfile=s';
    $default_logfile_suffix_opt   = 'logfile-suffix=s';
    $default_outfile_optid        = undef;
    $default_suffix_optid         = undef;
    $dispdef_max                  = 20;
    $logfile_optid                = undef;
    $logfile_suffix_optid         = undef;
    $file_group_num               = [];
    $explicit_quit                = 0;
    $cleanup_mode                 = 0;
    $flag_check_hash              = {};
    $bad_user_opts                = [];
    $outdirs_added                = 0;
    $file_indexes_to_usage        = {};
    $def_collide_mode_suff        = 'error'; #Use these 2 defaults for mode for
    $def_collide_mode_outf        = 'merge'; #outfile option types' collide mode
    $def_collide_mode_logf        = 'merge'; #logfile option types' collide mode
    $exclusive_options            = [];      #[[optid1,...],...]
    $exclusive_lookup             = {};      #{optid=>{exclusiveid1=>1,...}}
    $mutual_params                = {};      #{exclusiveid1=>{...whatever}}
    $builtin_mutexes              = {runmode => [qw(usage help run dry_run
						    version)],
				     debug   => [qw(debug quiet)],
				     verbose => [qw(verbose quiet)],
				     outmode => [qw(skip overwrite append)]};

    $scalar_genopt_types          = {'bool'    => '',   #val is appended to key
				     'negbool' => '!',
				     'count'   => ':+',
				     'string'  => '=s',
				     'integer' => '=i',
				     'float'   => '=f',
				     'enum'    => '=s'};
    $array_genopt_types           = {'string_array'    => '=s',
				     'integer_array'   => '=s',
				     'float_array'     => '=s',
				     'enum_array'      => '=s'};
    $array2d_genopt_types         = {'string_array2d'  => '=s',
				     'integer_array2d' => '=s',
				     'float_array2d'   => '=s',
				     'enum_array2d'    => '=s'};
    $scalar_fileopt_types         = {'suffix'  => '=s',
				     'logfile' => '=s',
				     'logsuff' => '=s'};
    $array2d_fileopt_types        = {'infile'  => '=s',
				     'outfile' => '=s',
				     'stub'    => '=s',        #currently unused
				     'outdir'  => '=s'};
    $scalaropt_types              = {%$scalar_genopt_types,
				     %$scalar_fileopt_types};
    $array2dopt_types             = {%$array2d_genopt_types,
				     %$array2d_fileopt_types};
    $genopt_types                 = {%$scalar_genopt_types,
				     %$array_genopt_types,
				     %$array2d_genopt_types};
    $fileopt_types                = {%$array2d_fileopt_types,
				     %$scalar_fileopt_types};

    $def_option_hash =
      {verbose    => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editVerboseOption',
		      DEFAULT  => 0, #CLI default
		      EDITABLE => [qw(FLAG REQUIRED DEFAULT HIDDEN SHORT_DESC
				      LONG_DESC ADVANCED HEADING DISPDEF)],
		      PARAMS   => {FLAG        => 'verbose',
				   VARREF      => \$verbose,
				   TYPE        => 'count',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => 0,
				   HIDDEN      => 0,
				   SHORT_DESC  => getDesc('verbose',1),
				   LONG_DESC   => getDesc('verbose',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 0,
				   USAGE_NAME  => 'verbose',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => 'UNIVERSAL BASIC OPTIONS'}},

       quiet      => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editQuietOption',
		      DEFAULT  => 0, #CLI default
		      EDITABLE => [qw(FLAG DEFAULT HIDDEN SHORT_DESC LONG_DESC
				      ADVANCED HEADING DISPDEF)],
		      PARAMS   => {FLAG        => 'quiet',
				   VARREF      => \$quiet,
				   TYPE        => 'bool',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => 0,
				   HIDDEN      => 0,
				   SHORT_DESC  => getDesc('quiet',1),
				   LONG_DESC   => getDesc('quiet',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 0,
				   USAGE_NAME  => 'quiet',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => ''}},

       overwrite  => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editOverwriteOption',
		      DEFAULT  => 0, #CLI default
		      EDITABLE => [qw(FLAG REQUIRED DEFAULT HIDDEN SHORT_DESC
				      LONG_DESC ADVANCED HEADING DISPDEF)],
		      PARAMS   => {FLAG        => 'overwrite',
				   VARREF      => \$overwrite,
				   TYPE        => 'count',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => 0,
				   HIDDEN      => 0,
				   SHORT_DESC  => getDesc('overwrite',1),
				   LONG_DESC   => getDesc('overwrite',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 0,
				   USAGE_NAME  => 'overwrite',
				   USAGE_ORDER => undef,
				   HEADING     => ''}},

       skip       => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editSkipOption',
		      DEFAULT  => 0, #CLI default
		      EDITABLE => [qw(FLAG DEFAULT HIDDEN SHORT_DESC
				      LONG_DESC ADVANCED HEADING DISPDEF)],
		      PARAMS   => {FLAG        => 'skip',
				   VARREF      => \$skip_existing,
				   TYPE        => 'bool',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => 0,
				   HIDDEN      => 0,
				   SHORT_DESC  => getDesc('skip',1),
				   LONG_DESC   => getDesc('skip',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 0,
				   USAGE_NAME  => 'skip',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => ''}},

       header     => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editHeaderOption',
		      DEFAULT  => 1, #CLI default
		      EDITABLE => [qw(FLAG REQUIRED DEFAULT HIDDEN SHORT_DESC
				      LONG_DESC ADVANCED HEADING DISPDEF)],
		      PARAMS   => {FLAG        => 'header',
				   VARREF      => \$header,
				   TYPE        => 'negbool',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => 1,
				   HIDDEN      => 0,
				   SHORT_DESC  => getDesc('header',1),
				   LONG_DESC   => getDesc('header',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 0,
				   USAGE_NAME  => 'header',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => ''}},

       version    => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editVersionOption',
		      DEFAULT  => 0, #CLI default
		      EDITABLE => [qw(FLAG HIDDEN SHORT_DESC LONG_DESC ADVANCED
				      HEADING DEFAULT DISPDEF)],
		      PARAMS   => {FLAG        => 'version',
				   VARREF      => \$version,
				   TYPE        => 'bool',
				   REQUIRED    => 0,
				   DEFAULT     => $def_version,
				   HIDDEN      => 0,
				   SHORT_DESC  => getDesc('version',1),
				   LONG_DESC   => getDesc('version',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 0,
				   USAGE_NAME  => 'version',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => ''}},

       extended   => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editExtendedOption',
		      DEFAULT  => 0, #CLI default
		      EDITABLE => [qw(FLAG REQUIRED DEFAULT HIDDEN SHORT_DESC
				      LONG_DESC ADVANCED HEADING DISPDEF)],
		      PARAMS   => {FLAG        => 'extended',
				   VARREF      => \$extended,
				   TYPE        => 'count',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => 0,
				   HIDDEN      => 0,
				   SHORT_DESC  => getDesc('extended',1),
				   LONG_DESC   => getDesc('extended',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 0,
				   USAGE_NAME  => 'extended',  #Used internally
				   USAGE_ORDER => -1,
				   HEADING     => ''}},

       force      => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editForceOption',
		      DEFAULT  => 0, #CLI default
		      EDITABLE => [qw(FLAG REQUIRED DEFAULT HIDDEN SHORT_DESC
				      LONG_DESC ADVANCED HEADING DISPDEF)],
		      PARAMS   => {FLAG        => 'force',
				   VARREF      => \$force,
				   TYPE        => 'count',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => 0,
				   HIDDEN      => 0,
				   SHORT_DESC  => getDesc('force',1),
				   LONG_DESC   => getDesc('force',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 1,
				   USAGE_NAME  => 'force',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => ('UNIVERSAL ' .
						   'ADVANCED ' .
						   'OPTIONS')}},

       debug      => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editDebugOption',
		      DEFAULT  => 0, #CLI default
		      EDITABLE => [qw(FLAG REQUIRED DEFAULT HIDDEN SHORT_DESC
				      LONG_DESC ADVANCED HEADING DISPDEF)],
		      PARAMS   => {FLAG        => 'debug',
				   VARREF      => \$DEBUG,
				   TYPE        => 'count',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => 0,
				   HIDDEN      => 0,
				   SHORT_DESC  => getDesc('debug',1),
				   LONG_DESC   => getDesc('debug',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 1,
				   USAGE_NAME  => 'debug',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => ''}},

       save_args  => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editSaveArgsOption',
		      DEFAULT  => 0, #CLI default
		      EDITABLE => [qw(FLAG HIDDEN SHORT_DESC LONG_DESC ADVANCED
				      HEADING)],
		      PARAMS   => {FLAG        => 'save-args',
				   VARREF      => \$use_as_default,
				   TYPE        => 'bool',
				   REQUIRED    => 0,
				   DISPDEF     => join(' ',getUserDefaults()),
				   DEFAULT     => undef,
				   HIDDEN      => 0,
				   SHORT_DESC  => getDesc('save_args',1),
				   LONG_DESC   => getDesc('save_args',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 0, #Changed by applyOptionAdd.
				   USAGE_NAME  => 'save_args',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => 'USER DEFAULTS'}},

       pipeline   => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editPipelineOption',
		      DEFAULT  => undef, #CLI default
		      EDITABLE => [qw(FLAG REQUIRED DEFAULT HIDDEN SHORT_DESC
				      LONG_DESC ADVANCED HEADING DISPDEF)],
		      PARAMS   => {FLAG        => 'pipeline',
				   VARREF      => \$pipeline,
				   TYPE        => 'negbool',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => undef,
				   HIDDEN      => 0,
				   SHORT_DESC  => getDesc('pipeline',1),
				   LONG_DESC   => getDesc('pipeline',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 1,
				   USAGE_NAME  => 'pipeline',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => ''}},

       error_lim  => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editErrorLimitOption',
		      DEFAULT  => $error_limit_default, #CLI default
		      EDITABLE => [qw(FLAG REQUIRED DEFAULT HIDDEN SHORT_DESC
				      LONG_DESC ADVANCED HEADING DISPDEF)],
		      PARAMS   => {FLAG        => 'error-limit',
				   VARREF      => \$error_limit,
				   TYPE        => 'integer',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => $error_limit_default,
				   HIDDEN      => 0,
				   SHORT_DESC  => getDesc('error_lim',1),
				   LONG_DESC   => getDesc('error_lim',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 1,
				   USAGE_NAME  => 'error_lim',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => ''}},

       append     => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editAppendOption',
		      DEFAULT  => 0, #CLI default
		      EDITABLE => [qw(FLAG DEFAULT HIDDEN SHORT_DESC
				      LONG_DESC ADVANCED HEADING DISPDEF)],
		      PARAMS   => {FLAG        => 'append',
				   VARREF      => \$append,
				   TYPE        => 'bool',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => 0,
				   HIDDEN      => 0,
				   SHORT_DESC  => getDesc('append',1),
				   LONG_DESC   => getDesc('append',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 1,
				   USAGE_NAME  => 'append',     #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => ''}},

       collision  => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editCollisionOption',
		      DEFAULT  => 'error', #CLI default
		      EDITABLE => [qw(FLAG REQUIRED HIDDEN SHORT_DESC LONG_DESC
				      ADVANCED HEADING)],
		      PARAMS   => {FLAG        => 'collision-mode',
				   VARREF      => \$user_collide_mode,
				   TYPE        => 'enum',
				   REQUIRED    => 0,

				   #DEFAULT is determined dynamically via
				   #processCommandLine
				   DISPDEF     => undef,
				   DEFAULT     => undef,

				   HIDDEN      => 1,
				   SHORT_DESC  => getDesc('collision',1),
				   LONG_DESC   => getDesc('collision',0),
				   ACCEPTS     => ['merge','rename','error'],
				   ADVANCED    => 1,
				   USAGE_NAME  => 'collision',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => ''}},

       run        => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editRunOption',
		      DEFAULT  => $def_run, #CLI default
		      EDITABLE => [qw(FLAG HIDDEN SHORT_DESC LONG_DESC ADVANCED
				      HEADING DEFAULT DISPDEF)],
		      PARAMS   => {FLAG        => 'run',
				   VARREF      => \$run,
				   TYPE        => 'bool',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => $def_run,

				   #HIDDEN is determined dynamically via
				   #processCommandLine and can only
				   #be modified to always be shown
				   HIDDEN      => undef,

				   SHORT_DESC  => getDesc('run',1),
				   LONG_DESC   => getDesc('run',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 0,
				   USAGE_NAME  => 'run',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => ''}},

       dry_run    => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editDryRunOption',
		      DEFAULT  => $def_dry_run, #CLI default
		      EDITABLE => [qw(FLAG HIDDEN SHORT_DESC LONG_DESC DISPDEF
				      ADVANCED HEADING DEFAULT DISPDEF)],
		      PARAMS   => {FLAG        => 'dry-run',
				   VARREF      => \$dry_run,
				   TYPE        => 'bool',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => $def_dry_run,

				   #HIDDEN is determined dynamically via
				   #processCommandLine and can only
				   #be modified to always be shown
				   HIDDEN      => undef,

				   SHORT_DESC  => getDesc('dry_run',1),
				   LONG_DESC   => getDesc('dry_run',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 0,
				   USAGE_NAME  => 'dry_run',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => ''}},

       usage      => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editUsageOption',
		      DEFAULT  => $def_usage, #CLI default
		      EDITABLE => [qw(FLAG HIDDEN SHORT_DESC LONG_DESC DISPDEF
				      ADVANCED HEADING DEFAULT DISPDEF)],
		      PARAMS   => {FLAG        => 'usage',
				   VARREF      => \$usage,
				   TYPE        => 'bool',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => $def_usage,

				   #HIDDEN is determined dynamically via
				   #processCommandLine and can only
				   #be modified to always be shown
				   HIDDEN      => undef,

				   SHORT_DESC  => getDesc('usage',1),
				   LONG_DESC   => getDesc('usage',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 0,
				   USAGE_NAME  => 'usage',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => ''}},

	help      => {ADDED    => 0,
		      CHANGED  => 0,
                      METHOD   => 'editHelpOption',
		      DEFAULT  => $def_help, #CLI default
		      EDITABLE => [qw(FLAG HIDDEN SHORT_DESC LONG_DESC DISPDEF
				      ADVANCED HEADING DEFAULT DISPDEF)],
		      PARAMS   => {FLAG        => 'help',
				   VARREF      => \$help,
				   TYPE        => 'bool',
				   REQUIRED    => 0,
				   DISPDEF     => undef,
				   DEFAULT     => $def_help,

				   #HIDDEN is determined dynamically via
				   #processCommandLine and can only
				   #be modified to always be shown
				   HIDDEN      => undef,

				   SHORT_DESC  => getDesc('help',1),
				   LONG_DESC   => getDesc('help',0),
				   ACCEPTS     => undef,
				   ADVANCED    => 0,
				   USAGE_NAME  => 'help',  #Used internally
				   USAGE_ORDER => undef,
				   HEADING     => ''}}};

    #Copy the default parameters to use as a fallback in case of a fatal config
    #error
    foreach my $opt (keys(%$def_option_hash))
      {$def_option_hash->{$opt}->{FALLBACKS} =
         {%{$def_option_hash->{$opt}->{PARAMS}}}}
  }

sub setScriptInfo
  {
    my @params   = qw(VERSION HELP CREATED AUTHOR CONTACT COMPANY LICENSE
		      DETAILED_HELP|DETAIL);
    my $check    = {map {$_ => 1} @params};
    my @in       = getSubParams([@params],[],[@_],1);
    my %infohash = map {$params[$_] => $in[$_]} 0..$#in;

    if($command_line_stage >= ARGSREAD)
      {
	my $version = getVarref('version',1);
	my $help    = getVarref('help',1);

	if($help || $version)
	  {
	    error("You cannot set the script information (i.e. call ",
		  "setScriptInfo()) after the command line has already been ",
		  "processed (i.e. processCommandLine()) without at least ",
		  "re-initializing (i.e. calling _init()) because --help or ",
		  "--version flags which return the information set by this ",
		  "method have already been acted on during the processing ",
		  "of the default options.  Call setScriptInfo before doing ",
		  "any file processing.");
	    return(undef);
	  }
      }

    debug({LEVEL => -1},"Keys passed in: [",join(',',keys(%infohash)),"].");

    my @invalid = grep {!exists($check->{$_})} keys(%infohash);

    if(scalar(@invalid) > 0)
      {
	%infohash = map {$_ => $infohash{$_}} grep {exists($check->{$_})}
	  keys(%infohash);

	warning("Invalid keys passed in: [",join(',',@invalid),"].");
      }

    $script_version_number = $infohash{VERSION};
    $help_summary          = $infohash{HELP};
    $created_on_date       = $infohash{CREATED};
    $script_author         = $infohash{AUTHOR};
    $script_contact        = $infohash{CONTACT};
    $script_company        = $infohash{COMPANY};
    $script_license        = $infohash{LICENSE};
    $advanced_help         = $infohash{'DETAIL|DETAILED_HELP'};

    $script_version_number =~ s/^\n+// if(defined($script_version_number));
    $help_summary          =~ s/^\n+// if(defined($help_summary));
    $created_on_date       =~ s/^\n+// if(defined($created_on_date));
    $script_author         =~ s/^\n+// if(defined($script_author));
    $script_contact        =~ s/^\n+// if(defined($script_contact));
    $script_company        =~ s/^\n+// if(defined($script_company));
    $script_license        =~ s/^\n+// if(defined($script_license));
    $advanced_help         =~ s/^\n+// if(defined($advanced_help));
  }

sub getRelationStr
  {
    #NOTE: Requirement 140 needs to be implemented to properyly support M:M
    my $instr = $_[0]; #'1','1:1','1:M','1:1orM'
    my $default  = undef;
    if(scalar(@_) != 1)
      {
	if(scalar(@_))
	  {warning('Expected 1 parameter.  Got [',scalar(@_),'].')}
	else
	  {
	    error('Expected 1 parameter.  Got [',scalar(@_),'].  ',
		  "Returning default: [",
		  (defined($default) ? $default : 'undef'),"].");
	    return($default);
	  }
      }
    if(!defined($instr))
      {return($default)}
    elsif(ref($instr) ne '')
      {
	error('Expected a scalar.  Got [',ref($instr),'].  ',
	      "Returning default: [",
		  (defined($default) ? $default : 'undef'),"].");
	return($default);
      }

    if($instr eq '')
      {return($default)}
    elsif($instr =~ /^(1|one)[\s\-_]?(:|to)[\s\-_]?(1|one)$/i)
      {return('1:1')}
    elsif($instr =~ /^(1|one)[\s\-_]?(:|to)[\s\-_]?(m|n|many)$/i)
      {return('1:M')}
    #TODO: Requirement 140 needs to be implemented to properyly support M:M
    #    elsif($instr =~ /^(m|n|many)[\s\-_]?(:|to)[\s\-_]?(m|n|many)$/i)
    #      {return('M:M')}
    elsif($instr =~ /^(1|one)[\s\-_]?(:|to)[\s\-_]?(1|one)
		     [\s\-_]?(or|\|)[\s\-_]?(m|n|many)$/ix)
      {return('1:1orM')}
    elsif($instr =~ /^(\d+|one)$/i)
      {
	my $val = $1;
	$val = 1 if($val =~ /\D/);
	return($val);
      }

    error('Invalid relation string: [',$instr,"].  Valid values are: ['1',",
	  "'1:1','1:M','1:1orM'].  Returning default: [",
	  (defined($default) ? $default : 'undef'),"].");
    return($default);
  }

#Might add the ability to indicate what file types must have the same number of
#input files
#Returns a file type ID to be used in addOutfileSuffixOption
sub addInfileOption
  {
    my $nokeysfound = 0;
    my @in = getSubParams([qw(FLAG|GETOPTKEY REQUIRED DEFAULT PRIMARY HIDDEN
			      SHORT_DESC|SMRY|SMRY_DESC
			      LONG_DESC|DETAIL|DETAIL_DESC FORMAT|FORMAT_DESC
			      PAIR_WITH PAIR_RELAT FLAGLESS ADVANCED HEADING
			      DISPDEF)],
			  [scalar(@_) ? qw(FLAG|GETOPTKEY) : ()],
			  [@_],0,\$nokeysfound);
    my $get_opt_str  = $in[0]; #e.g. 'i|infile=s'
    my $required     = $in[1]; #Is file required?: 0 (false) or non-zero (true)
    my $default      = $in[2]; #String, ref to a 1D or 2D array of strings/globs
    my $primary      = $in[3]; #0 or non-0: true = flag optional & accepts pipe
    my $hidden       = $in[4]; #0 or non-0. Non-0 requires a default or to be a
                               #primary option (i.e. takes input on STDIN).
                               #Excludes from usage output.
    my $smry_desc    = $in[5]; #e.g. 'Input file(s).  See --help for format.'
                               #Empty/undefined = exclude from short usage
    my $detail_desc  = $in[6]; #e.g. 'Input file(s).  Space separated, globs...'
    my $format_desc  = $in[7]; #e.g. 'Tab delimited text w/ columns: 1. Name...'
    my $req_with_opt = $in[8];
    my $req_rel_str  = getRelationStr($in[9]);   #e.g. 1,1:1,1:M,1:1orM
    my $flagless     = $in[10];#Whether the option can be supplied sans flag
    my $advanced     = $in[11];#Advanced options print when extended >= 2
    my $heading      = $in[12];#Section heading to print in extended usage
    my $display_def  = $in[13];#The default to display in the usage
    my($req_with_uhash);

    #Trim leading & trailing hard returns and white space characters (from
    #using '<<')
    $smry_desc   =~ s/^\s+//s if(defined($smry_desc));
    $smry_desc   =~ s/\s+$//s if(defined($smry_desc));
    $detail_desc =~ s/^\s+//s if(defined($detail_desc));
    $detail_desc =~ s/\s+$//s if(defined($detail_desc));
    $format_desc =~ s/^\s+//s if(defined($format_desc));
    $format_desc =~ s/\s+$//s if(defined($format_desc));

    if($command_line_stage >= ARGSREAD)
      {
	error("You cannot add command line options (i.e. call ",
	      "addInfileOption()) after the command line has already been ",
	      "processed (i.e. processCommandLine()) without at least ",
	      "re-initializing (i.e. calling _init()).");
	return(undef);
      }

    #Defaults mode - Only call with no params once.
    my $adding_default = (scalar(@in) == 0);
    if($adding_default)
      {
	if($default_infile_added)
	  {
	    error('The default input file type has already been added.');
	    return(undef);
	  }

	debug({LEVEL => -1},'Setting default values for addInfileOption.');

	$get_opt_str = removeDupeFlags($default_infile_opt);
	if(!defined($get_opt_str) || $get_opt_str eq '')
	  {
	    error('Unable to add default input file type ',
		  "[$default_infile_opt] due to redundant flags: [",
		  join(',',getDupeFlags($default_infile_opt,
                                        $default_infile_opt)),'].');
	    $default_infile_opt = $get_opt_str;
	    return(undef);
	  }
	$default_infile_opt = $get_opt_str;

	$default_infile_added = 1;
	$required    = 0;
	$primary     = 1;
	#The descriptions are added below
      }

    #Allow the flag to be an array of scalars and turn it into a get opt str
    my $save_getoptstr = $get_opt_str;
    $get_opt_str = makeGetOptKey($get_opt_str,'infile',0,'addInfileOption');

    if(defined($get_opt_str))
      {$get_opt_str = fixStringOpt($get_opt_str)}
    else
      {
        error("Invalid option flag definition: [",
              (defined($save_getoptstr) ? $save_getoptstr : 'undef'),"].");
	$num_setup_errors++;
	return(undef);
      }

    if(!isGetOptStrValid($get_opt_str,'infile',$default_infile_opt))
      {
	if($adding_default)
	  {warning("Unable to add default input file option.")}
	else
	  {$num_setup_errors++}
	return(undef);
      }

    if(defined($required) && $required !~ /^\d+$/)
      {
        my $msg = ["Invalid required parameter: [$required].",
                   {DETAIL => ("The value will be treated as " .
                               ($required ? 'true' : 'false') . '.')}];
        if($nokeysfound)
          {error(@$msg)}
        else
          {warning(@$msg)}
      }

    if(defined($req_with_opt))
      {
	#TODO: Requirement 280 will allow linking to either input or output
	#      file types
	if(!isInt($req_with_opt) || $req_with_opt < 0 ||
	   $req_with_opt > $#{$usage_array} ||
	   $usage_array->[$req_with_opt]->{OPTTYPE} ne 'infile')
	  {
	    error("Invalid PAIR_WITH option ID: [$req_with_opt]",
                  (!isInt($req_with_opt) || $req_with_opt < 0 ||
                   $req_with_opt > $#{$usage_array} ? '' : ' for option [' .
                   "$usage_array->[$req_with_opt]->{OPTFLAG_DEF}]"),
                  ".  Must be an ID as returned by addInfileOption.");

            $num_setup_errors++;
            return(undef);
	  }
	$req_with_uhash = $usage_array->[$req_with_opt];
      }

    my $flags = [getOptStrFlags($get_opt_str)];
    my $flag  = getDefaultFlag($flags);
    my $name  = createOptionNameFromFlags($flags);

    #If hidden is not defined and there is a linked file, default to the hidden
    #state of the file type this is linked to, otherwise 0.
    if(!defined($hidden) && defined($req_with_opt))
      {
	if(defined($req_with_opt) && $req_with_uhash->{HIDDEN})
	  {$hidden = 1}
	else
	  {$hidden = 0}
      }
    elsif(!defined($hidden))
      {$hidden = 0}
    elsif(!$hidden && defined($req_with_opt))
      {
	#Error if this option is set to be visible and it is linked to a hidden
	#file that has no default and is not primary
	if($req_with_uhash->{HIDDEN} && !$req_with_uhash->{PRIMARY} &&
	   !hasDefault($req_with_uhash))
	  {
	    error("Input file option [$flag] cannot be visible when its ",
		  "PAIR_WITH linked file [",
		  getFlag($usage_array->[$req_with_opt],2),"] is ",
		  "hidden, has no default value, and is not primary.",
		  {DETAIL =>
		   join('',("A linked file (e.g. [",
			    getFlag($usage_array->[$req_with_opt],2),
			    "]) is required to be supplied if [$flag] is ",
			    "supplied, but since the linked file type is ",
			    "hidden, there's no way to tell the user of the ",
			    "required file type that may be missing, thus if ",
			    "a file type is hidden, any file type linked to ",
			    "it must also be hidden and thereby revealed ",
			    "together when viewing hidden options."))});
	    $hidden = 1;
	  }
      }

    my $varref      = [];
    my $varref_copy = [];

    if($hidden && !defined($default) && (!defined($primary) || !$primary) &&
       defined($required) && $required)
      {
	warning("Cannot hide option [$flag] if required, no default provided, ",
                "and not primary (i.e. doesn't take input on standard in).  ",
                'Setting as not hidden.');
	$hidden = 0;
      }

    #Add the default(s) to the default infiles array, to be globbed when the
    #command line is processed
    if(defined($default))
      {
	my($twodarray,$default_str) = makeCheck2DFileArray($default);
	if(defined($twodarray))
	  {$default = $twodarray}
	else
	  {
            $num_setup_errors++;
            return(undef);
          }
      }

    if(defined($display_def) && (ref($display_def) ne '' || $display_def eq ''))
      {
	error("Invalid display default.  Must be a non-empty string.  ",
	      "Ignoring.");
	undef($display_def);
      }

    if(defined($smry_desc) && $smry_desc ne '' &&
       (!defined($detail_desc) || $detail_desc eq ''))
      {$detail_desc = $smry_desc}

    if((!defined($smry_desc) || $smry_desc eq '') &&
       ($required || !defined($detail_desc) || $detail_desc eq ''))
      {$smry_desc = defined($detail_desc) && $detail_desc ne '' ?
         $detail_desc : 'Input file(s).'}

    if(!defined($detail_desc) || $detail_desc eq '')
      {$detail_desc =
	 join('',('Input file(s).',
		  (defined($format_desc) && $format_desc ne '' ?
		   '  See --help for file format.' : '')))}
    #If the description doesn't reference the help flag for the file format and
    #a file format was provided, add a reference to it
    elsif($detail_desc !~ /--help/ && defined($format_desc) &&
	  $format_desc ne '')
      {$detail_desc .= "\n\nSee --help for file format."}

    $GetOptHash->{$get_opt_str} = getGetoptSub($name,0);

    if(defined($primary) && $primary)
      {
	if(defined($primary_infile_optid))
	  {
	    error("Multiple primary input file options supplied ",
		  "[$get_opt_str].  Only 1 is allowed.");
	    return(undef);
	  }

	$primary_infile_optid = getNextUsageIndex();
      }

    if(defined($flagless) && $flagless)
      {
	if(defined($flagless_multival_optid) && $flagless_multival_optid > -1)
	  {
	    error("An additional multi-value option has been designated as ",
		  "'flagless': [$get_opt_str]: [$flagless].  Only 1 is ",
		  "allowed.",
		  {DETAIL => "First flagless option was: [" .
		   $usage_array->[$flagless_multival_optid]->{OPTFLAG_DEF} .
		   "]."});
	    return(undef);
	  }

	$GetOptHash->{'<>'} = getGetoptSub($name,1);

	#This assumes that the call to addToUsage a few lines below is the
	#immediate next call to addToUsage
	$flagless_multival_optid = getNextUsageIndex();
      }

    my $oid = addToUsage($get_opt_str,
                         $flags,
                         $smry_desc,
                         $detail_desc,
                         $required,
                         $display_def,
                         $default,
                         undef,         #accepts
                         $hidden,
                         'infile',
                         $flagless,
                         $advanced,
                         $heading,
                         undef,         #usage name
                         undef,         #usage order
                         [],            #VARREF_PRG - ref programmer supplied
                         $req_with_opt,
                         $req_rel_str,
                         undef,
                         $primary,
                         $format_desc,
                         undef);

    if(!defined($oid))
      {$num_setup_errors++}
    else
      {addRequiredRelationship($oid,$req_with_opt,$req_rel_str)}

    return($oid);
  }

#Globals used: $file_indexes_to_usage
sub fileIndexesToOptionID
  {
    my $file_type_index = $_[0];
    my $suffix_index    = $_[1];

    if(exists($file_indexes_to_usage->{$file_type_index}) &&
       defined($file_indexes_to_usage->{$file_type_index}) &&
       exists($file_indexes_to_usage->{$file_type_index}->{$suffix_index}) &&
       defined($file_indexes_to_usage->{$file_type_index}->{$suffix_index}))
      {return($file_indexes_to_usage->{$file_type_index}->{$suffix_index})}

    return(undef);
  }

sub getOutdirUsageHash
  {
    ##TODO: The outdir options need to be fixed. See requirement 178
    my $oduh = undef;
    foreach my $uh (@$usage_array)
      {
	if($uh->{OPTTYPE} eq 'outdir')
	  {
	    if(defined($oduh))
	      {outdirLimitation(0)}
	    $oduh = $uh;
	  }
      }
    return($oduh);
  }

sub fixStringOpt
  {
    my $get_opt_str = $_[0];
    my $force_fix   = defined($_[1]) ? $_[1] : 0;

    if(!defined($get_opt_str) || $get_opt_str eq '')
      {debug({LEVEL => -1},"Unable to fix option string: [",
	     (defined($get_opt_str) ? $get_opt_str : 'undef'),"].")}
    else
      {
	#Remove any leading dashes
	$get_opt_str =~ s/^-+//;

	#If the option specification is just missing the string type, add it
	if(defined($get_opt_str) && $get_opt_str ne '' &&
	   $get_opt_str !~ /[=+:\@\%!]/)
	  {$get_opt_str .= '=s'}
	elsif(defined($get_opt_str) && $get_opt_str ne '' && $force_fix &&
	      $get_opt_str !~ /=s$/)
	  {
	    $get_opt_str =~ s/[=+:\@\%!].*//;
	    $get_opt_str .= '=s';
	  }
      }

    return($get_opt_str);
  }

#Globals used: $genopt_types, $fileopt_types
sub makeGetOptKey
  {
    my $get_opt_str = $_[0];
    my $type        = $_[1]; #Does not remove trailing flag type str if undef
    my $local_quiet = defined($_[2]) ? $_[2] : 0;
    my $calling_sub = defined($_[3]) ? $_[3] : 'unspecified';

    my %types = %$genopt_types;
    if(defined($type) && exists($fileopt_types->{$type}))
      {%types = %$fileopt_types}

    if(defined($get_opt_str))
      {
	if(ref($get_opt_str) eq 'ARRAY')
	  {
	    if(scalar(grep {ref($_) ne ''} @$get_opt_str))
	      {
		error("FLAG supplied to [$calling_sub] must be either a ",
                      "scalar or a reference to an array of scalars, but an ",
                      "array containing [",join("','",map {ref($_)}
                                                grep {ref($_) ne ''}
                                                @$get_opt_str),
		      "] was supplied.")
		  if(!$local_quiet);
                return(undef);
	      }
	    if(scalar(grep {defined($_) && /[=+:\@\%!].*/} @$get_opt_str))
	      {
		error("FLAG array supplied to [$calling_sub]: [",
		      join(',',grep {defined($_)} @$get_opt_str),
		      "] must not contain type information.",
		      {DETAIL => ('Must not contain the following ' .
				  'characters: [=+:\@\%!].')})
		  if(!$local_quiet);
		return(undef);
	      }
	    elsif(scalar(grep {!defined($_)} @$get_opt_str))
	      {
		error("FLAG array supplied to [$calling_sub]: [",
		      join(',',map {defined($_) ? $_ : 'undef'} @$get_opt_str),
		      "] must not contain undefined values.",
		      {DETAIL => ('Must not contain the following ' .
				  'characters: [=+:\@\%!].')})
		  if(!$local_quiet);
                return(undef);
	      }
	    $get_opt_str = join('|',@$get_opt_str);
	  }
	elsif(ref($get_opt_str) eq '')
	  {
	    #Assume flags are to be separated by "invalid characters, like
	    #commas, spaces, etc. if the flags contain unacceptable characters
	    if($get_opt_str !~ /\|/ &&
	       $get_opt_str =~ /[^a-zA-Z0-9\-_\?=+:\@\%!]/)
	      {$get_opt_str = join('|',split(/[^a-zA-Z0-9\-_\?=+:\@\%!]+/,
					     $get_opt_str))}
            elsif($get_opt_str eq '')
              {
                error("Invalid FLAG string: [$get_opt_str].",
                      {DETAIL => ("FLAG string [$get_opt_str] supplied to " .
                                  "[$calling_sub] contains no flags.")})
                  if(!$local_quiet);
              }
	  }
	else
	  {
	    error("FLAG supplied to [$calling_sub] must be either a scalar ",
		  "or a reference to an array of scalars, but [",
		  ref($get_opt_str),"] was supplied.")
	      if(!$local_quiet);
	    return(undef);
	  }
      }

    if(defined($type) && !exists($types{$type}))
      {
	error("Invalid type: [$type] for [$calling_sub].",
	      {DETAIL => 'Must be one of [' . join(',',keys(%types)) . '].'})
	  if(!$local_quiet);
	return(undef);
      }

    if(!defined($get_opt_str) || $get_opt_str eq '')
      {
	debug({LEVEL => -1},"Unable to fix option string: [",
	      (defined($get_opt_str) ? $get_opt_str : 'undef'),"].");
	return(undef);
      }

    if(defined($type))
      {
        $get_opt_str =~ /([=+:\@\%!].*)/;
        my $typeinfo = defined($1) ? $1 : '';
	if((defined($type) &&
            (!exists($types{$type}) || $typeinfo ne $types{$type})) &&
            $typeinfo ne '')
	  {warning("Invalid FLAG string: [$get_opt_str].",
                   {DETAIL =>
                    join('',("FLAG string [$get_opt_str] supplied to ",
                             "[$calling_sub] contains type information [$1], ",
                             "but a TYPE [$type] was also supplied.  Setting ",
                             "type information to [$types{$type}]."))})
             if(!$local_quiet)}
	elsif($typeinfo ne '' && exists($types{$type}))
	  {
	    my $pat = quotemeta($types{$type});
	    if(exists($types{$type}) && $get_opt_str !~ /($pat)$/)
	      {
                $get_opt_str =~ /([=+:\@\%!].*)/;
                warning("Invalid flag definition: [$get_opt_str] for type ",
                        "[$type] in [$calling_sub].",
                        {DETAIL => ("Type [$type] can only have a flag " .
                                    'definition (if any) that ends with ' .
                                    "[$types{$type}].  Ignoring the invalid " .
                                    "portion of the flag definition: [$1].")})}
	  }

	#Remove anything following the flags
	$get_opt_str =~ s/[=+:\@\%!].*//;

	$get_opt_str .= $types{$type};
      }

    #Remove any leading dashes
    $get_opt_str =~ s/^-+//;

    if($get_opt_str eq '' || $get_opt_str =~ /^[=+:\@\%!]/)
      {
        error("Invalid FLAG string: [$get_opt_str].",
              {DETAIL => ("FLAG string [$get_opt_str] supplied to " .
                          "[$calling_sub] contains no flags.")})
          if(!$local_quiet);
      }

    return($get_opt_str);
  }

#Globals used: $genopt_types, $fileopt_types
#If undef is returned, the type is assumed to be set in the FLAG string
sub getOptType
  {
    my $type_str    = $_[0];
    my $get_opt_str = $_[1];
    my $accepts     = $_[2]; #Only used for assuming enum type
    my $get_opt_ref = $_[3]; #Only used to change bool to negbool if true
    my $default     = $_[4];
    my $opt_name    = $_[5];
    my %types       = (%$genopt_types,%$fileopt_types);

    if(defined($type_str) && scalar(grep {$type_str eq $_} keys(%types)) == 0)
      {error("Invalid type: [$type_str].")}
    elsif(defined($type_str) && exists($types{$type_str}))
      {
	if($type_str eq 'enum' &&
	   (!defined($accepts) || ref($accepts) ne 'ARRAY' ||
	    scalar(@$accepts) == 0 || scalar(grep {ref($_) ne ''} @$accepts)))
	  {
	    error("TYPE enum requires a valid ACCEPTS value.",
		  {DETAIL => ('ACCEPTS must be a reference to an array of ' .
			      "scalars.  [" .
			      (!defined($accepts) ? 'nothing' :
			       (ref($accepts) ne 'ARRAY' ?
				(ref($accepts) eq '' ?
				 'a SCALAR' : 'a reference to (' .
				 ref($accepts) . ')') :
				(scalar(@$accepts) ?
				 'a reference to an array of (' .
				 join(',',map {ref($_) eq '' ?
						 'SCALAR' : ref($_)}
				      @$accepts) . ')' :
				 'a reference to an empty array'))) .
			      "] was passed in.")});
            $num_setup_errors++;
            return(undef); #does not signify error - just no type determined
	  }

	#If the user defined this as a bool, but set the default value to true,
	#assume they actually want a negbool
	if($type_str eq 'bool' && ref($get_opt_ref) eq 'SCALAR' &&

	   #The option is not a builtin boolean option (because these already
	   #exist in the GetOptHash and would have to be removed from there in
	   #order to work correctly, because the processing order is not
	   #guaranteed, they reference the same variable, and thus would step on
	   #eachother's toes randomly).  See req #349
	   !exists($GetOptHash->{$get_opt_str}) &&
	   (!defined($opt_name) || !exists($def_option_hash->{$opt_name})) &&

	   ((defined($$get_opt_ref) && $$get_opt_ref) ||
	    (defined($default) && $default)))
	  {
	    warning("Initial value of a [bool] should evaluate to ",
		    "false.  Changing type of [",
		    getDefaultFlag(scalar(getOptStrFlags($get_opt_str))),
		    "] to [negbool].");
	    $type_str = 'negbool';
	  }

	return($type_str);
      }

    #If the type is not defined in the get opt key, default to 'string'
    if($get_opt_str !~ /[=+:\@\%!].*/)
      {return('string')}

    return(undef);
  }

#This sub is a helper to addInfileOption specifically.  The error wordings are
#specific to that sub.
#Takes a string, reference to an array of strings, or a reference to an array
#of references to arrays of strings.  Ensures dimensionality is consistent.  If
#a string is provided, it puts it as the first element of the first array of an
#array.  If a 1D array is provided, it puts it as the first array of an array.
#Ensures that there are no undefined values and that there are no empty arrays
#or empty strings.
#Copies the array sent in.
#Returns a copy of the conformed array and a string version of the array
sub makeCheck2DFileArray
  {
    my $inarray = copyArray($_[0]);

    #If the array is not defined
    if(!defined($inarray))
      {
	error("Undefined default file encountered.");
	return(undef,'');
      }
    #If it's a scalar, but an empty string
    elsif(ref(\$inarray) eq 'SCALAR' && $inarray eq '')
      {
	error("Default file defined as empty string.");
	return(undef,'');
      }
    #If it's just a valid scalar value
    elsif(ref(\$inarray) eq 'SCALAR' && $inarray ne '')
      {return([[$inarray]],"(($inarray))")}

    #If it's a valid 1D array
    elsif(ref($inarray) eq 'ARRAY' && scalar(@$inarray) &&
	  scalar(@$inarray) ==
	  scalar(grep {defined($_) && ref(\$_) eq 'SCALAR' && $_ ne ''}
		 @$inarray))
      {return([$inarray],'((' . join(',',@$inarray) . '))')}
    #If it's an empty 1D array, silently return undef
    elsif(ref($inarray) eq 'ARRAY' && scalar(@$inarray) == 0)
      {return(undef,'')}
    #If it's an invalid 1D array containing undefined values
    elsif(ref($inarray) eq 'ARRAY' && scalar(grep {!defined($_)} @$inarray))
      {
	error("Undefined default file in a 1D array encountered.");
	return(undef,'');
      }
    #If it's an invalid 1D array containing empty strings
    elsif(ref($inarray) eq 'ARRAY' && scalar(grep {$_ eq ''} @$inarray))
      {
	error("Default file defined as empty string in a 1D array.");
	return(undef,'');
      }
    #If it's an invalid 1D array containing a mix of strings and something else
    elsif(ref($inarray) eq 'ARRAY' &&
	  scalar(grep {ref(\$_) eq 'SCALAR'} @$inarray) &&
	  scalar(grep {ref(\$_) ne 'SCALAR'} @$inarray))
      {
	error("File strings in a 1D array mixed with non-scalar values.");
	return(undef,'');
      }

    #If it's a valid 2D array
    elsif(isTwoDArray($inarray,0))
      {return($inarray,'((' . join(')(',map {join(',',@$_)} @$inarray) . '))')}

    error("Invalid 2D array of non-empty file strings encountered.  All ",
	  "inner arrays must be defined and contain 1 or more non-empty ",
	  "strings of globs/file names.");

    return(undef,'');
  }

sub isTwoDArray
  {
    my $inarray = $_[0];
    my $empty_str_ok = defined($_[1]) ? $_[1] : 1;

    return(ref($inarray) eq 'ARRAY' && scalar(@$inarray) &&
	   scalar(@$inarray) ==
	   scalar(grep {defined($_) && ref($_) eq 'ARRAY' && scalar(@$_)}
		  @$inarray) &&
	   scalar(@$inarray) ==
	   scalar(grep {my $a=$_;scalar(@$a) && scalar(@$a) ==
			  scalar(grep {defined($_) && ref(\$_) eq 'SCALAR' &&
					 ($empty_str_ok || $_ ne '')}
				 @$a)} @$inarray));
  }

#This method will add a relationship between file types and will fill in a
#default relationship if the user did not define one and one is possible.
#Globals used: $primary_infile_optid
sub addRequiredRelationship
  {
    my $ftype1_optid = $_[0]; #The file type being added
    my $ftype2_optid = $_[1]; #A file type that should have already been added
    my $relationship = $_[2]; #String matching: '1','1:1','1:M','1:1orM'
    my $success      = 0;     #Default = failure

    ##
    ## Input validation
    ##

    #Enforce required params and fill in defaults
    if(!defined($ftype1_optid))
      {
	error("First parameter (file type being added) is required.");
        $num_setup_errors++;
	return($success);
      }
    #Silently/successfully return if the last 2 params are not defined/empty
    elsif((!defined($ftype2_optid) || $ftype2_optid eq '') &&
	  (!defined($relationship) || $relationship eq ''))
      {return($success = 1)}
    elsif(!defined($ftype2_optid) || $ftype2_optid eq '')
      {
	my $def_prim_inf_optid = getDefaultPrimaryInfileID();
	#If the paired file type doesn't matter, set it to the first file type,
	#even if it is with itself
	if($relationship =~ /^\d+$/ && defined($def_prim_inf_optid))
	  {$ftype2_optid = $def_prim_inf_optid}
	elsif(!defined($primary_infile_optid))
	  {
	    error("No PAIR_WITH file type was provided and no primary input ",
		  "file type has yet been added.  Please supply ",
		  "addInfileOption with a previously added file type ID ",
		  "using the PAIR_WITH option or remove the ",
		  "PAIR_RELAT option.");
            $num_setup_errors++;
            return($success);
	  }
	elsif($primary_infile_optid == $ftype1_optid)
	  {
	    error("No PAIR_WITH file type was provided and the default ",
		  "primary input file type is what is being added.  Please ",
		  "supply addInfileOption with a previously added file type ",
		  "ID using the PAIR_WITH option.  ");
            $num_setup_errors++;
            return($success);
	  }
	else
	  {
	    warning("Setting primary input file type to establish ",
		    "relationship: [$relationship] with another file type ",
		    "that is dependent on it because the file type ID was ",
		    "not supplied.",
		    {DETAIL =>
		     join('',('Usually, this happens when an outfile suffix ',
			      'is defined either by addOutfileSuffixOption ',
			      'or addOutfileTagteamOption without FILETYPEID ',
			      'or PAIR_WITH being defined, though other ',
			      'dependant options can also cause this ',
			      'warning.  If there is only 1 input file type ',
			      'or one input file type has been set as ',
			      'primary, it is set here automatically with ',
			      'this warning.'))});
	    $ftype2_optid = $primary_infile_optid;
	  }
      }
    elsif(!defined($relationship) || $relationship eq '')
      {$relationship = '1:1orM'}

    #Make sure the first file type ID is an unsigned integer
    if($ftype1_optid !~ /^\d+$/)
      {
	error('Invalid file type 1 ID (first parameter): [',$ftype1_optid,']');
        $num_setup_errors++;
	return($success);
      }

    #If the relationship is '1' (only 1 file allowed regardless of any input
    #file type), set the file type 2 to undefined
    if($relationship eq '1')
      {undef($ftype2_optid)}
    #Make sure the second file type ID is an unsigned integer
    elsif($ftype2_optid !~ /^\d+$/)
      {
	error('Invalid file type 2 ID (second parameter): [',$ftype2_optid,']');
        $num_setup_errors++;
	return($success);
      }
    #Make sure the second file type ID pre-exists
    elsif($ftype2_optid > $#{$usage_array} ||
	  ($usage_array->[$ftype2_optid]->{OPTTYPE} ne 'infile' &&
	   $usage_array->[$ftype2_optid]->{OPTTYPE} ne 'outfile') ||
	  $ftype1_optid == $ftype2_optid)
      {
	error('Second file type ID supplied (second parameter): ',
	      "[$ftype2_optid] does not exist, is not a file option, or is a ",
	      'duplicate.',
	      {DETAIL => 'The PAIR_WITH option can only take IDs as have been ',
	       'previously returned by addInfileOption or addOutfileOption.'});
        $num_setup_errors++;
	return($success);
      }

    ##
    ## Add the relationship
    ##

    $success = 1;
    $usage_array->[$ftype1_optid]->{PAIRID}   = $ftype2_optid;
    $usage_array->[$ftype1_optid]->{RELATION} = $relationship;

    return($success);
  }

#Checks strings for 7 types of params: infile, outfile, suffix, outdir,
#general, 1darray, and 2darray
sub isGetOptStrValid
  {
    my $get_opt_str   = $_[0];
    my $type          = $_[1];
    my $name_or_gostr = $_[2]; #Builtin option name or getoptkey default (e.g.
                               #$default_infile_opt)
    my $answer        = 1;

    if(!defined($get_opt_str))
      {
	error("Invalid option flag definition: [undef].");
        $answer = 0;
        return($answer);
      }

    #Don't hold builtin options to the same standard
    my $conflicts = [];
    my @existing  = getDupeFlags($get_opt_str,$name_or_gostr,$conflicts);
    if(scalar(@existing))
      {
        #Builtin option conflicts
        my @bics = grep {exists($def_option_hash->{$_})} @$conflicts;
        #Default file option conflicts
        my @dfcs = grep {!exists($def_option_hash->{$_})} @$conflicts;
        #Determine whether the dupes are due to conflicts with builtin options
        my $detail = '';
        $detail .= (scalar(@bics) == 0 ? '' :
                    join('',('The flag(s) of the following builtin option(s) ',
                             'must be edited to not conflict using: [' .
                             join(',',
                                  map {"$_: $def_option_hash->{$_}->{METHOD}"}
                                  @bics),'].')));
        $detail .= (scalar(@dfcs) == 0 ? '' :
                    ($detail eq '' ? '' : '  ') .
                    join('',('These flags conflict with default file options ',
                             'and may need to be added explicitly with the ',
                             'method shown here using a different flag value: ',
                             '[',join(',',@dfcs) . '].')));

        error("Duplicate flags detected: [",join(',',@existing),"].",
              ($detail eq '' ? '' : {DETAIL => $detail}));
        debug({LEVEL => -1},"Existing flags: [",
              join(',',keys(%$flag_check_hash)),
              "]. Adding Flag: [$get_opt_str]");

        $answer = 0;

        return($answer);
      }

    #General validity checks
    if($get_opt_str !~ /[a-zA-Z0-9!+\@\}\@\%]$/)
      {
	error("Invalid option flag definition: [$get_opt_str].  The flag ",
	      "specification [$get_opt_str] must not be an empty string and ",
	      "end in a letter, number, or one of: [!+\@\}\%].  See the ",
	      "Summary of Option Specifications section of `perldoc Getopt::",
	      "Long` for how to specify the command line option.");
	$answer = 0;
      }

    #Make sure the user has specified a string type
    my $ok = 1;
    if($get_opt_str !~ /=s$/)
      {$ok = 0}

    if(exists($fileopt_types->{$type}))
      {
	if(!$ok)
	  {
	    error("The option flag specification for $type must end with ",
		  "'=s'.  [$get_opt_str] was passed in.");
	    $answer = 0;
	  }
      }
    elsif($type eq '1darray' || $type eq '2darray')
      {
	if(!$ok)
	  {
	    error("The option specification: [$get_opt_str] must end with ",
		  "'=s'.",
		  {DETAIL =>
		   join('',
			("In order to split the values, ",
			 "CommandLineInterface requires array options to ",
			 "have the string type passed to GetOpt::Long ",
			 "because it replaces option string with a reference ",
			 "to a subroutine and does not have its own type-",
			 "enforcement (e.g. for integers).  ",
			 "CommandLineInterface's subroutine for array ",
			 "options adds mitigations of some shell-imposed ",
			 "command-line length limitations and can handle 2D ",
			 "arrays (or multiple 1D arrays of the same type).  ",
			 "Thus, you must enforce types in your own code."))});
	    $answer = 0;
	  }
      }
    elsif($type ne 'general')
      {warning("Unknown option type: [$type].  Unable to validate option.")}

    return($answer);
  }

#This method populates and checks flags against the flag_check_hash and
#Returns the specific -f or --flag values that have duplicates
#globals used: $flag_check_hash
sub getDupeFlags
  {
    my $get_opt_str      = $_[0];
    my $exclude_builtin  = defined($_[1]) ? $_[1] : '';
    my $builtin_conflict = defined($_[2]) ? $_[2] : []; #For retrieval for errs
    my $conflict_hash    = {};
    my $new_flags        = getOptStrFlags($get_opt_str,1);
    my $existing         = [];
    my $self_check       = {};

    debug({LEVEL => -2},"Looking for dupes of [",join(',',sort(@$new_flags)),
          "] in: [",join(',',sort(keys(%$flag_check_hash))),"].");

    my $builtin_check = {};

    #Add the builtin general options
    my $biopt_lookup = {};
    my @builtins = (map {my $op = $_;my @flgs =
                           getOptStrFlags(makeGetOptKey($def_option_hash->{$op}
                                                        ->{PARAMS}->{FLAG},
                                                        $def_option_hash->{$op}
                                                        ->{PARAMS}->{TYPE},
                                                        1,'getDupeFlags'));
                         foreach(@flgs){$biopt_lookup->{$_} = $op}
                         @flgs;
                       }
                    grep {$_ ne $exclude_builtin &&
                            !$def_option_hash->{$_}->{ADDED}}
                    keys(%{$def_option_hash}));

    $biopt_lookup->{$default_infile_opt} =
      "addInfileOption(FLAG => '$default_infile_opt')";
    $biopt_lookup->{$default_outfile_suffix_opt} =
      "addOutfileSuffixOption(FLAG => '$default_outfile_suffix_opt')";
    $biopt_lookup->{$default_outfile_opt} =
      "addOutfileOption(FLAG => '$default_outfile_opt')";
    $biopt_lookup->{$default_outdir_opt} =
      "addOutdirOption(FLAG => '$default_outdir_opt')";
    $biopt_lookup->{$default_logfile_opt} =
      "addLogfileOption(FLAG => '$default_logfile_opt')";
    $biopt_lookup->{$default_logfile_suffix_opt} =
      "addLogfileSuffixOption(FLAG => '$default_logfile_suffix_opt')";

    if($get_opt_str ne $exclude_builtin || $exclude_builtin eq '')
      {
        #Make a hash for the flags being checked
        my $nfhash = {map {my $nf=$_;$nf=~s/^-+//;$nf => 0} @$new_flags};
        #Add the builtin file options (even though they may not be added)
        foreach my $bikey (grep {$_ ne $exclude_builtin}
                           ($default_infile_opt,$default_outfile_suffix_opt,
                            $default_outfile_opt,$default_outdir_opt,
                            $default_logfile_opt,$default_logfile_suffix_opt))
          {
            #Extract the end of the getopt string (e.g. ':+' or '=s')
            my $bikeyend = $bikey;
            $bikeyend =~ s/.*?(?=[=:!+])//;
            #See if we can remove
            my @biflags = (grep {!exists($nfhash->{$_})} map {s/^-+//;$_}
                           getOptStrFlags($bikey));
            my $newbikey = join('|',@biflags) . $bikeyend;
            if(scalar(@biflags) == 0)
              {
                push(@builtins,getOptStrFlags($bikey));
                foreach(getOptStrFlags($bikey))
                  {$biopt_lookup->{$_} = $biopt_lookup->{$bikey}}
              }
            else
              {
                foreach my $biflag (grep {$_ eq $bikey && $bikey ne $newbikey}
                                    grep {$_ ne $exclude_builtin}
                                    ($default_infile_opt,
                                     $default_outfile_suffix_opt,
                                     $default_outfile_opt,$default_outdir_opt,
                                     $default_logfile_opt,
                                     $default_logfile_suffix_opt))
                  {$biflag = $newbikey}
              }
          }
      }

    #Create an on-the-fly hash of flags for builtin options not yet added
    foreach my $f (@builtins)
      {$builtin_check->{$f} = 0}

    foreach my $flag (@$new_flags)
      {
	if(exists($flag_check_hash->{$flag}) || exists($self_check->{$flag}) ||
           exists($builtin_check->{$flag}))
	  {
            push(@$existing,$flag);
            if(exists($builtin_check->{$flag}))
              {$conflict_hash->{$biopt_lookup->{$flag}}++}
          }
	$self_check->{$flag} = 0;
      }

    foreach my $f (sort(keys(%$conflict_hash)))
      {push(@$builtin_conflict,$f)}

    return(wantarray ? @$existing : $existing);
  }

#Globals used: $flag_check_hash, $usage_array
sub removeDupeFlags
  {
    my $get_opt_str = $_[0];

    my @opt_strs = ();
    my $hash = {};
    if(scalar(@$usage_array))
      {push(@opt_strs,map {$_->{GETOPTKEY}} @$usage_array)}
    else
      {return($get_opt_str)}

    #Separate the end of the get opt str from the body
    my $get_opt_str_end = $get_opt_str;
    if($get_opt_str_end =~ /.*([=:!+].*)/)
      {$get_opt_str_end =~ s/.*([=:!+].*)/$1/}
    else
      {$get_opt_str_end = ''}
    my $new_get_opt_str = $get_opt_str;
    $new_get_opt_str =~ s/[=:!+].*//;

    #Determine whether the flag could have "no" or "no-" prepended to it
    my $negatable = ($get_opt_str =~ /\!$/);

    $new_get_opt_str =
      join('|',
	   grep {my $s = $_;my @fs = getOptStrFlags("$s$get_opt_str_end",1);
                 scalar(grep {exists($flag_check_hash->{$_})} @fs) == 0}
	   split(/\|/,$new_get_opt_str));

    if($new_get_opt_str eq '')
      {return($new_get_opt_str)}

    $new_get_opt_str .= $get_opt_str_end;

    return($new_get_opt_str);
  }

#This sub does not add new functionality.  It simply adds an infile option, but
#marks it as an outfile in the outfile_types_array.  It also adds a hidden
#outfile_suffix option with a static default value of an empty string.  That
#way, no functionality needs to change with regard to outfile checking.
sub addOutfileOption
  {
    my @in = getSubParams([qw(FLAG|GETOPTKEY COLLISIONMODE REQUIRED PRIMARY
			      DEFAULT SHORT_DESC|SMRY|SMRY_DESC
			      LONG_DESC|DETAIL|DETAIL_DESC FORMAT|FORMAT_DESC
			      HIDDEN PAIR_WITH PAIR_RELAT FLAGLESS ADVANCED
			      HEADING DISPDEF)],
			  [scalar(@_) ? qw(FLAG|GETOPTKEY) : ()],
			  [@_]);
    my $get_opt_str  = $in[0]; #e.g. 'o|outfile=s'
    my $collide_mode = getCollisionMode(undef,'outfile',$in[1]);
    my $required     = $in[2]; #Is file required?: 0 (false) or non-zero (true)
    my $primary      = $in[3]; #non-0:stdout 0:no output
    my $default      = $in[4]; #e.g. 'my_output_file.txt'
    my $smry_desc    = $in[5]; #e.g. 'Input file(s).  See --help for format.'
                               #Empty/undefined = exclude from short usage
    my $detail_desc  = $in[6]; #e.g. 'Input file(s).  Space separated, globs...'
    my $format_desc  = $in[7]; #e.g. 'Tab delimited text w/ columns: 1. Name...'
    my $hidden       = $in[8]; #0 or non-0. Requires a default. Excludes from
                               #usage output.
    my $req_with_opt = $in[9];
    my $req_rel_str  = getRelationStr($in[10]);  #e.g. 1,1:1,1:M,1:1orM
    my $flagless     = $in[11];#Whether the option can be supplied sans flag
    my $advanced     = $in[12];#Advanced options print when extended >= 2
    my $heading      = $in[13];#Section heading to print in extended usage
    my $display_def  = $in[14];#The default to display in the usage
    my($req_with_uhash);

    #Trim leading & trailing hard returns and white space characters (from
    #using '<<')
    $smry_desc   =~ s/^\s+//s if(defined($smry_desc));
    $smry_desc   =~ s/\s+$//s if(defined($smry_desc));
    $detail_desc =~ s/^\s+//s if(defined($detail_desc));
    $detail_desc =~ s/\s+$//s if(defined($detail_desc));
    $format_desc =~ s/^\s+//s if(defined($format_desc));
    $format_desc =~ s/\s+$//s if(defined($format_desc));

    if($command_line_stage >= ARGSREAD)
      {
	error("You cannot add command line options (i.e. call ",
	      "addOutfileOption()) after the command line has already been ",
	      "processed (i.e. processCommandLine()) without at least ",
	      "re-initializing (i.e. calling _init()).");
	return(undef);
      }

    #Defaults mode - Only call with no params once.
    my $adding_default = (scalar(@in) == 0);
    if($adding_default)
      {
	if($default_outfile_added)
	  {
	    error('The default output file type has already been added.');
	    return(undef);
	  }

	debug({LEVEL => -1},'Setting default values for addOutfileOption.');

	$get_opt_str = removeDupeFlags($default_outfile_opt);
	if(!defined($get_opt_str) || $get_opt_str eq '')
	  {
	    error('Unable to add default output file type ',
		  "[$default_outfile_opt] due to redundant flags: [",
		  join(',',getDupeFlags($default_outfile_opt,
                                        $default_outfile_opt)),'].');
	    $default_outfile_opt = $get_opt_str;
	    return(undef);
	  }
	$default_outfile_opt = $get_opt_str;

	#The descriptions are added below

	#If a compatible infile type exists that we will be linked to,
	#match it.  (Returns undef if none.)
	$req_with_opt = getDefaultPrimaryLinkedInfileID();

	if(defined($req_with_opt))
	  {$req_rel_str = getRelationStr('1:1orM')}
      }

    #Allow the flag to be an array of scalars and turn it into a get opt str
    my $save_getoptstr = $get_opt_str;
    $get_opt_str = makeGetOptKey($get_opt_str,'outfile',0,'addOutfileOption');

    if(defined($get_opt_str))
      {$get_opt_str = fixStringOpt($get_opt_str)}
    else
      {
	$num_setup_errors++;
	return(undef);
      }

    if(!isGetOptStrValid($get_opt_str,'outfile',$default_outfile_opt))
      {
	if($adding_default)
	  {warning("Unable to add default output file option.")}
	else
	  {$num_setup_errors++}
	return(undef);
      }

    if(defined($collide_mode) && $collide_mode ne '' &&
       $collide_mode ne 'error' && $collide_mode ne 'rename' &&
       $collide_mode ne 'merge')
      {
	my $defcoll = getCollisionMode(undef,'outfile');
	error("Invalid COLLISIONMODE parameter: [$collide_mode].  Must be one ",
	      "of ['error','merge','rename'].  Reverting to default: ",
	      "[$defcoll].");
	$collide_mode = $defcoll;
      }

    if(defined($required) && $required !~ /^\d+$/)
      {error("Invalid REQUIRED parameter: [$required].")}

    if(defined($req_with_opt))
      {
	#TODO: Requirement 280 will allow linking to either input or output
	#      file types
	if(!isInt($req_with_opt) || $req_with_opt < 0 ||
	   $req_with_opt > $#{$usage_array} ||
	   $usage_array->[$req_with_opt]->{OPTTYPE} ne 'infile')
	  {
	    error("Invalid PAIR_WITH option ID: [$req_with_opt]",
                  (!isInt($req_with_opt) || $req_with_opt < 0 ||
                   $req_with_opt > $#{$usage_array} ? '' : ' for option [' .
                   "$usage_array->[$req_with_opt]->{OPTFLAG_DEF}]"),
                  ".  Must be an ID as returned by addInfileOption.");
            $num_setup_errors++;
            return(undef);
	  }
	$req_with_uhash = $usage_array->[$req_with_opt];
      }


    #If hidden is not defined, default to the hidden state of whatever file
    #type this might be linked to, otherwise 0.
    if(!defined($hidden) && defined($req_with_opt))
      {
	if($req_with_uhash->{HIDDEN})
	  {$hidden = 1}
	else
	  {$hidden = 0}
      }
    elsif(!defined($hidden))
      {$hidden = 0}

    my $flags = [getOptStrFlags($get_opt_str)];
    my $flag  = getDefaultFlag($flags);
    my $name  = createOptionNameFromFlags($flags);

    #Validity of hidden is checked in applyOptionAddendums in case this option
    #ends up being part of a tagteam

    #Add the default(s) to the default infiles array, to be globbed when the
    #command line is processed
    if(defined($default))
      {
	my($twodarray,$default_str) = makeCheck2DFileArray($default);
	if(defined($twodarray))
	  {$default = $twodarray}
	else
	  {
            $num_setup_errors++;
            return(undef);
          }
      }

    if(defined($display_def) && (ref($display_def) ne '' || $display_def eq ''))
      {
	error("Invalid display default.  Must be a non-empty string.  ",
	      "Ignoring.");
	undef($display_def);
      }

    #Note: primary defaults to true in addToUsage if not defined for outfile &
    #suffix types
    if(!defined($display_def) &&
       (!defined($default) || scalar(@$default) == 0) &&
       (!defined($primary) || $primary) && !$required)
      {$display_def = 'STDOUT'}

    #Note, addToUsage won't include if set to empty string
    if(!defined($smry_desc) || $smry_desc eq '')
      {
	if($required)
	  {$smry_desc =
             defined($detail_desc) ? $detail_desc : 'Output file(s).'}
	elsif(!defined($smry_desc))
	  {$smry_desc = ''}
      }

    if(!defined($detail_desc) || $detail_desc eq '')
      {$detail_desc =
	 join('',('Output file(s) ',
		  (defined($req_with_opt) &&
		   $usage_array->[$req_with_opt]->{OPTTYPE} eq 'infile' ?
		   "associated with [" .
		   getFlag($usage_array->[$req_with_opt]) . "] input file(s)" .
		   (defined($req_rel_str) ?
		    " in a " . getDispRelStr($req_rel_str) . " relationship" :
		    '') : "type " . (getNextUsageIndex() + 1)),
		  '.',(defined($format_desc) && $format_desc ne '' ?
		       '  See --help for file format.' : '')))}
    #If the description doesn't reference the help flag for the file format and
    #a file format was provided, add a reference to it
    elsif($detail_desc !~ /--help/ && defined($format_desc) &&
	  $format_desc ne '')
      {$detail_desc .= "\n\nSee --help for file format."}

    $GetOptHash->{$get_opt_str} = getGetoptSub($name,0);

    if(defined($flagless) && $flagless)
      {
	if(defined($flagless_multival_optid) && $flagless_multival_optid > -1)
	  {
	    error("An additional multi-value option has been designated as ",
		  "'flagless': [$get_opt_str]: [$flagless].  Only 1 is ",
		  "allowed.",
		  {DETAIL => "First flagless option was: [" .
		   $usage_array->[$flagless_multival_optid]->{OPTFLAG_DEF} .
		   "]."});
	    return(undef);
	  }

	$GetOptHash->{'<>'} = getGetoptSub($name,1);

	#This assumes that the call to addToUsage a few lines below is the
	#immediate next call to addToUsage
	$flagless_multival_optid = getNextUsageIndex();
      }

    my $usage_index = addToUsage($get_opt_str,
                                 $flags,
                                 $smry_desc,
                                 $detail_desc,
                                 $required,
                                 $display_def,
                                 $default,
                                 undef,         #accepts
                                 $hidden,
                                 'outfile',
                                 $flagless,
                                 $advanced,
                                 $heading,
                                 undef,         #usage name
                                 undef,         #usage order
                                 [],            #VARREF_PRG: ref programmer spld
                                 $req_with_opt,
                                 $req_rel_str,
                                 undef,
                                 $primary,
                                 $format_desc,
                                 $collide_mode);

    if(!defined($usage_index))
      {
        $num_setup_errors++;
        return(undef);
      }

    if($adding_default)
      {
	$default_outfile_added = 1;
	$default_outfile_optid = $usage_index;
      }

    my $hidden_opt_str = join('|',
			      (map {if(/[\:\=\+\!]/){
				s/([:=\+\!])/-hidden-suffix$1/;$_}
				    else{$_ .= '-hidden-suffix'}}
			       split(/\|/,$get_opt_str)));
    my $error_message = join('',('This is a hidden outfile suffix option.  ',
				 'The user should not see it.  This option ',
				 'adds an empty string to an "input file ',
				 'type" which is treated as an output file ',
				 'type.  This is an internal way of handling ',
				 'output files so that they are grouped with ',
				 'the appropriate input files in sets.'));

    #We need to return the suffix_id returned by addOutfileSuffixOption so that
    #getOutfile returns the correct output file name.

    my $suffix_optid = addOutfileSuffixOption($hidden_opt_str,$usage_index,
					      undef,$required,$primary,'',1,'',
					      $error_message,$error_message,
					      $collide_mode);

    #If req_with is not defined, this call just returns without doing anything
    addRequiredRelationship($usage_index,$req_with_opt,$req_rel_str);

    return($usage_index);
  }

#Makes relationship strings such as '1','1:1','1:M','1:1orM' human-readable
sub getDispRelStr
  {
    my $str = $_[0];
    if(defined($str))
      {
	if($str eq '1')
	  {return('one to all')}
	elsif($str eq '1:1')
	  {return('one to one')}
	elsif($str eq '1:M')
	  {return('one to many')}
	elsif($str eq '1:1orM')
	  {return('one to (one or many)')}
      }

    return('ERROR');
  }

#Globals used: usage_array
sub getOutdirFlag
  {
    my $usage_hash     = $_[0];
    my $extended       = getVarref('extended',1,1,1);
    my $local_extended = (defined($_[1]) ? (defined($extended) && $extended ?
					    $extended : $_[1]) :
			  (defined($extended) ? $extended : 0));

    ##TODO: The outdir options need to be fixed. See requirement 178.  This can
    #be called before the outdir option has been added - and there's currently
    #no support for more than one outdir.  The return here can be wrong if they
    #add a custom outdir option later.
    if(!defined($usage_hash) &&
       scalar(grep {$_->{OPTTYPE} eq 'outdir'} @$usage_array) > 1)
      {error("More than one outdir option and no usage hash supplied.",
	     {DETAIL => 'See requirement 178.'})}
    elsif(!defined($usage_hash) &&
	  scalar(grep {$_->{OPTTYPE} eq 'outdir'} @$usage_array) == 0)
      {warning("No outdir options exist and no usage hash supplied.",
	       {DETAIL => 'See requirement 178.'})
	 if($command_line_stage >= DONE)}
    elsif(defined($usage_hash) && $usage_hash->{OPTTYPE} ne 'outdir')
      {error('Invalid outdir usage hash.')}

    #Default to the yet-to-be-added default outdir option if there's still a
    #chance it could be added
    if(!defined($usage_hash) && $command_line_stage < DEFAULTED)
      {return(getDefaultFlag([getOptStrFlags($default_outdir_opt)]))}
    elsif(!defined($usage_hash) &&
	  scalar(grep {$_->{OPTTYPE} eq 'outdir'} @$usage_array) == 1)
      {return(getFlag((grep {$_->{OPTTYPE} eq 'outdir'} @$usage_array)[0],
		      $local_extended))}
    elsif(!defined($usage_hash))
      {return('')}

    return(getFlag(@_));
  }

sub getRepresentativeFlag
  {
    my $usage_hash = $_[0];
    if(defined($usage_hash))
      {
	#If the command line has been processed, use the flag that the user
	#supplied (if they used a flag)
	if($command_line_stage >= ARGSREAD && $usage_hash->{SUPPLIED} &&
	   defined($usage_hash->{OPTFLAG_SUP}) &&
	   isFlag($usage_hash,$usage_hash->{OPTFLAG_SUP}))
	  {
	    my $match = getMatchingFlag($usage_hash,$usage_hash->{OPTFLAG_SUP});
	    if($match ne '')
	      {return(getMatchingFlag($usage_hash,$usage_hash->{OPTFLAG_SUP}))}
	    else
	      {warning("Error finding matching flag.")}
	  }

	if(scalar(@{$usage_hash->{OPTFLAGS}}))
	  {return(getDefaultFlag($usage_hash->{OPTFLAGS}))}
      }

    return('');
  }

sub getBestFlag
  {
    my $uh = $_[0];
    return(defined($uh) ?
	   ($uh->{SUPPLIED} ? $uh->{OPTFLAG_SUP} :
	    ($uh->{SUPPLIED_UDF} ? $uh->{OPTFLAG_SUP_UDF} :
	     $uh->{OPTFLAG_DEF})) : '');
  }

sub isFlag
  {
    my $usage_hash    = $_[0];
    my $possible_flag = $_[1];
    my $possible_flag_pat = quotemeta($possible_flag);

    if($possible_flag =~ /^\-\-?\S/ &&
       scalar(grep {/^$possible_flag_pat/} @{$usage_hash->{OPTFLAGS}}))
      {return(1)}

    return(0);
  }

sub getMatchingFlag
  {
    my $usage_hash    = $_[0];
    my $possible_flag = $_[1];

    my $exact_flags = [grep {$_ eq $possible_flag} @{$usage_hash->{OPTFLAGS}}];
    if(scalar(@$exact_flags))
      {return($exact_flags->[0])}

    my $possible_flag_pat = quotemeta($possible_flag);
    my $matching_flags    = [grep {/^$possible_flag_pat/}
			     sort {length($a) <=> length($b)}
			     @{$usage_hash->{OPTFLAGS}}];
    if(scalar(@$matching_flags))
      {return($matching_flags->[0])}

    return('');
  }

#This returns a flag and/or 'stdin/stdout' or a default file name depending
#on whether a file option is hidden, primary, or has a default.  Supplying
#--extended 2+ will always show the flag, hidden or not.
sub getFlag
  {
    my $usage_hash     = $_[0];
    my $extended       = getVarref('extended',1,1,1);
    my $local_extended = (defined($_[1]) ? (defined($extended) && $extended ?
					    $extended : $_[1]) :
			  (defined($extended) ? $extended : 0));
    my $flag = '';

    #This will use the version of the flag that the user supplied
    my $representative_flag = getRepresentativeFlag($usage_hash);

    #Validate
    if(defined($usage_hash))
      {
	if(ref($usage_hash) eq 'HASH' && exists($usage_hash->{OPTTYPE}) &&
	   defined($usage_hash->{OPTTYPE}) &&
	   ref($usage_hash->{OPTFLAGS}) eq 'ARRAY' &&
	   scalar(@{$usage_hash->{OPTFLAGS}}) > 0)
	  {
	    $flag = $representative_flag;
	    if($local_extended == -1)
	      {return($flag)}
	  }
	else
	  {
	    error("Invalid usage hash.",
		  {DETAIL => ((ref($usage_hash) eq 'HASH' ?
			       (exists($usage_hash->{OPTTYPE}) ?
				(defined($usage_hash->{OPTTYPE}) ?
				 (ref($usage_hash->{OPTFLAGS}) eq 'ARRAY' ?
				  (scalar(@{$usage_hash->{OPTFLAGS}}) > 0 ?
				   'internal error' : 'OPTFLAGS is empty') :
				  'OPTFLAGS not an ARRAY.') :
				 'OPTTYPE not defined.') :
				'No OPTTYPE key.') :
			       'Not a HASH.'))});
	    return($flag);
	  }
      }
    else
      {
	error("Usage hash undefined.");
	return($flag);
      }

    if($usage_hash->{OPTTYPE} eq 'infile' ||
       $usage_hash->{OPTTYPE} eq 'outfile')
      {
	#If primary and (visible or extended > 1)
	if($usage_hash->{PRIMARY} &&
	   (!$usage_hash->{HIDDEN} || $local_extended > 1))
	  {return($flag . ($local_extended > 1 ? ' (or "STD' .
			   ($usage_hash->{OPTTYPE} eq 'outfile' ?
			    'OUT' : 'IN') . '")' : ''))}
	#If primary and hidden
	elsif($usage_hash->{PRIMARY} && $usage_hash->{HIDDEN})
	  {return('"STD' . ($usage_hash->{OPTTYPE} eq 'outfile' ?
			   'OUT"' : 'IN"'))}
	#Guaranteed not primary, so if defaulted and hidden and extended < 2
	elsif(hasDefault($usage_hash) &&
	      $usage_hash->{HIDDEN} && $local_extended < 2)
	  {
	    my $defaults =
	      (defined($usage_hash->{DEFAULT_USR}) &&
	       scalar(@{$usage_hash->{DEFAULT_USR}}) ?
	       $usage_hash->{DEFAULT_USR} :
	       ((defined($usage_hash->{DEFAULT_PRG}) &&
		 scalar(@{$usage_hash->{DEFAULT_PRG}})) ?
		 $usage_hash->{DEFAULT_PRG} : []));
	    if(scalar(@$defaults) == 1)
	      {return(join(',',map {defined($_) ? $_ : 'undef'}
			   @{$defaults->[0]}))}
	    else
	      {return('(' .
		      join('),(',
			   map {my $a = $_;
				join(',',map {defined($_) ? $_ : 'undef'} @$a)}
			   @$defaults) . ')')}
	  }
	elsif($usage_hash->{HIDDEN} && $local_extended < 2)
	  {return('[HIDDEN - use `--extended --extended` to reveal]')}
      }
    elsif($usage_hash->{OPTTYPE} eq 'suffix')
      {
	#If primary and (visible or extended > 1)
	if($usage_hash->{PRIMARY} && (!$usage_hash->{HIDDEN} ||
				      $local_extended > 1))
	  {return($flag . ($local_extended > 1 ? ' (or "STDOUT")' : ''))}
	#If primary and hidden
	elsif($usage_hash->{PRIMARY} && $usage_hash->{HIDDEN})
	  {return('"STDOUT"')}
	#Guaranteed not primary, so if defaulted and hidden and extended < 2
	elsif(defined($usage_hash->{DISPDEF}) && $usage_hash->{HIDDEN} &&
	      $local_extended < 2)
	  {return($usage_hash->{DISPDEF})}
	elsif($usage_hash->{HIDDEN} && $local_extended < 2)
	  {return('[HIDDEN - use `--extended --extended` to reveal]')}
      }
    elsif($usage_hash->{OPTTYPE} eq 'outdir')
      {
	#If defaulted and hidden and extended < 2
	if(defined($usage_hash->{DISPDEF}) && $usage_hash->{HIDDEN} &&
	   $local_extended < 2)
	  {return($usage_hash->{DISPDEF})}
	elsif($usage_hash->{HIDDEN} && $local_extended < 2)
	  {return('[HIDDEN - use `--extended --extended` to reveal]')}
      }
    #Any other option type
    else
      {
	if(defined($usage_hash->{DISPDEF}) && $usage_hash->{HIDDEN} &&
	   $local_extended < 2)
	  {return($usage_hash->{DISPDEF})}
	elsif($usage_hash->{HIDDEN} && $local_extended < 2)
	  {return('[HIDDEN - use `--extended --extended` to reveal]')}
      }

    return($flag);
  }

#Returns a usage_array index
sub addOutfileSuffixOption
  {
    debug({LEVEL => -1},"Params sent in BEFORE: [",
	  join(',',map {defined($_) ? $_ : 'undef'} @_),"].");
    my @in = getSubParams([qw(FLAG|GETOPTKEY FILETYPEID VARREF|GETOPTVAL
			      REQUIRED PRIMARY DEFAULT HIDDEN
			      SHORT_DESC|SMRY|SMRY_DESC
			      LONG_DESC|DETAIL|DETAIL_DESC FORMAT|FORMAT_DESC
			      COLLISIONMODE ADVANCED HEADING DISPDEF)],
			  #If there are any params sent in, require the first
			  [scalar(@_) ?
			   #If there are at least 2 input file types, also
			   #require the FILETYPEID
			   (getNumInfileTypes() < 2 ?
			    qw(FLAG|GETOPTKEY) :
			    qw(FLAG|GETOPTKEY FILETYPEID)) : ()],
			  [@_]);
    debug({LEVEL => -1},"Params sent in AFTER: [",
	  join(',',map {defined($_) ? $_ : 'undef'} @in),"].");
    my $get_opt_str     = $in[0]; #e.g. 'o|suffix=s'
    my $req_with_opt    = $in[1];
    my $get_opt_val     = $in[2]; #A reference to a scalar
    my $required        = $in[3]; #Is suff required?: 0 (false) or non-0 (true)
    my $primary         = $in[4]; #non-0=STDOUT if no suf
    my $default         = $in[5]; #e.g. '.out'
    my $hidden          = $in[6]; #0 or non-0. Non-0 requires a default.
                                  #Excludes from usage output.
    my $smry_desc       = $in[7]; #e.g. Input file(s).  See --help for format.
                                  #Empty/undefined = exclude from short usage
    my $detail_desc     = $in[8]; #e.g. 'Input file(s).  Space separated,...'
    my $format_desc     = $in[9]; #e.g. 'Tab delimited text w/ cols: 1.Name...'
    my $collide_mode    = getCollisionMode(undef,'suffix',$in[10]);
    my $advanced        = $in[11];#Advanced options print when extended >= 2
    my $heading         = $in[12];#Section heading to print in extended usage
    my $display_def     = $in[13];#The default to display in the usage
    my($req_with_uhash);
    ##TODO: Don't use the generic/global collide_mode here - implement an
    #output mode that the user can control per outfile type.  See requirement
    #114

    #Trim leading & trailing hard returns and white space characters (from
    #using '<<')
    $smry_desc   =~ s/^\s+//s if(defined($smry_desc));
    $smry_desc   =~ s/\s+$//s if(defined($smry_desc));
    $detail_desc =~ s/^\s+//s if(defined($detail_desc));
    $detail_desc =~ s/\s+$//s if(defined($detail_desc));
    $format_desc =~ s/^\s+//s if(defined($format_desc));
    $format_desc =~ s/\s+$//s if(defined($format_desc));

    if(defined($req_with_opt) && (!isInt($req_with_opt) || $req_with_opt < 0 ||
				  $req_with_opt > $#{$usage_array}))
      {
        error("Invalid PAIR_WITH option ID: [$req_with_opt]",
              (!isInt($req_with_opt) || $req_with_opt < 0 ||
               $req_with_opt > $#{$usage_array} ? '' : ' for option [' .
               "$usage_array->[$req_with_opt]->{OPTFLAG_DEF}]"),
              ".  Must be an ID as returned by addInfileOption.");
        $num_setup_errors++;
        return(undef);
      }

    if(defined($get_opt_val) &&
       ref($get_opt_val) ne 'SCALAR' && ref($get_opt_val) ne 'CODE')
      {
	error("GETOPTVAL must be a reference to a SCALAR to hold the value ",
	      "for the outfile suffix string, but instead, a [",
	      (ref($get_opt_val) eq '' ?
	       'SCALAR' : 'reference to a ' . ref($get_opt_val)),
	      "] was received.  Unable to add outfile suffix option.");
        $num_setup_errors++;
	return(undef);
      }
    #Create a scalar reference to undef
    elsif(!defined($get_opt_val))
      {$get_opt_val = \my $junk}

    if($command_line_stage >= ARGSREAD)
      {
	error("You cannot add command line options (i.e. call ",
	      "addOutfileSuffixOption()) after the command line has already",
	      " been processed (i.e. processCommandLine()) without at ",
	      "least re-initializing (i.e. calling _init()).");
        $num_setup_errors++;
	return(undef);
      }

    #Keep track of whether this method was called internally or not
    my $called_implicitly = 0;
    #Defaults mode - Only call with no params once.
    my $adding_default = (scalar(@in) == 0);
    if($adding_default)
      {
	if($default_outfile_suffix_added)
	  {
	    error('The default output file suffix type has already been ',
		  'added.');
            $num_setup_errors++;
	    return(undef);
	  }

	debug({LEVEL => -1},'Setting default values for ',
	      'addOutfileSuffixOption.');

	$get_opt_str = removeDupeFlags($default_outfile_suffix_opt);
	if(!defined($get_opt_str) || $get_opt_str eq '')
	  {
	    error('Unable to add default output file suffix type ',
		  "[$default_outfile_suffix_opt] due to redundant flags: [",
		  join(',',getDupeFlags($default_outfile_suffix_opt,
                                        $default_outfile_suffix_opt)),'].');
	    $default_outfile_suffix_opt = $get_opt_str;
            $num_setup_errors++;
	    return(undef);
	  }
	$default_outfile_suffix_opt = $get_opt_str;

	$required     = 0;
	$collide_mode = getCollisionMode(undef,'suffix');
	##TODO: Use a command line flag specific to the outfile type instead of the current def_collide_mode which applies to all outfile types.  Create the flag when the outfile suffix option is created (but only if the programmer specified that the user is to choose).  See requirement 114

	#If a compatible outfile type exists that we will be tagteamed up with,
	#match it.  (Returns undef if none.)
	$req_with_opt = getDefaultPrimaryLinkedInfileID();

	#The descriptions are added below
      }
    else
      {
	if(isCaller('addDefaultFileOptions','addOutfileOption'))
	  {$called_implicitly = 1}
	if(!$called_implicitly)
	  {debug({LEVEL => -1},'Received custom values for ',
		 'addOutfileSuffixOption.')}
      }

    if(!defined($get_opt_str) || $get_opt_str eq '')
      {
	error("The first parameter (Getopt::Long key string) is required.");
        $num_setup_errors++;
        return(undef);
      }

    #If the file type ID is not an integer
    if(defined($req_with_opt) && $req_with_opt !~ /^\d+$/)
      {
	error("Invalid FILETYPEID parameter: [$req_with_opt].  Must be an ",
	      "unsigned integer as returned by addInfileOption.");
        $num_setup_errors++;
        return(undef);
      }
    #If the integer is defined, was supplied by the programmer, and references
    #a type other than an intput file type
    elsif(defined($req_with_opt) && !isCaller('addOutfileOption') &&
	  $usage_array->[$req_with_opt]->{OPTTYPE} ne 'infile')
      {
        error("Invalid FILETYPEID option ID: [$req_with_opt] for option [",
              "$usage_array->[$req_with_opt]->{OPTFLAG_DEF}].  Must be an ID ",
              "as returned by addInfileOption.");
        $num_setup_errors++;
        return(undef);
      }
    #If the file type is not defined
    elsif(!defined($req_with_opt))
      {
	$req_with_opt = getDefaultPrimaryInfileID();

	if(!defined($req_with_opt))
	  {
	    error('An input file type must be added before an outfile suffix ',
                  'option.',
                  {DETAIL => ('Explicitly adding a default outfile suffix ' .
                              '(or tagteam) requires an infile option to ' .
                              'have been added first in order to link the ' .
                              'suffix to an infile option.')});
            $num_setup_errors++;
            return(undef);
	  }
      }
    #If the valid file type ID was added as a part of creating a default
    elsif($adding_default)
      {debug({LEVEL => -1},"Input file type is: [",
	     getFlag($usage_array->[$req_with_opt],-1),"].")}

    #If the file type looked right, but was supplied by the programmer, double-
    #check they actually got the file type ID from addInfileOption
    if(defined($req_with_opt) && !$called_implicitly)
      {
	$req_with_uhash = $usage_array->[$req_with_opt];
	if(!defined($req_with_uhash) || ref($req_with_uhash) ne 'HASH' ||
	   !exists($req_with_uhash->{OPTTYPE}))
	  {
	    error("Invalid FILETYPEID option ID: [$req_with_opt].  Must be an ",
		  "ID as returned by addInfileOption.");
            $num_setup_errors++;
            return(undef);
	  }
	elsif(!exists($req_with_uhash->{OPTTYPE}))
	  {
            error("Invalid FILETYPEID: [$req_with_opt].  Must be an ID ",
                  "returned by addInfileOption.");
            $num_setup_errors++;
            return(undef);
          }
	#TODO: Requirement 280 will allow linking to either input or output
	#      file types
	elsif($req_with_uhash->{OPTTYPE} ne 'infile')
	  {
            error("FILETYPEID passed in must be an input file type ID as ",
                  "returned by addInfileOption.  Instead, received an ID of ",
                  "type: [$req_with_uhash->{OPTTYPE}].");
            $num_setup_errors++;
            return(undef);
          }
      }

    #If hidden is not defined, default to the hidden state of whatever file
    #type this might be linked to, except when called via addOutfileOption,
    #otherwise 0.
    if(!defined($hidden) && defined($req_with_opt) &&
       !isCaller('addOutfileOption'))
      {
	if($req_with_uhash->{HIDDEN})
	  {$hidden = 1}
	else
	  {$hidden = 0}
      }
    elsif(!defined($hidden))
      {$hidden = 0}

    #Allow the flag to be an array of scalars and turn it into a get opt str
    my $save_getoptstr = $get_opt_str;
    $get_opt_str = makeGetOptKey($get_opt_str,'suffix',0,
				 'addOutfileSuffixOption');
    if(!defined($get_opt_str))
      {
	$num_setup_errors++;
	return(undef);
      }

    if(!isGetOptStrValid($get_opt_str,'suffix',$default_outfile_suffix_opt))
      {
	if($adding_default)
	  {warning("Unable to add default output file suffix option.")}
	else
	  {
            $num_setup_errors++;
	  }
	return(undef);
      }

    $get_opt_str = fixStringOpt($get_opt_str);

    my $flags = [getOptStrFlags($get_opt_str)];
    my $flag  = getDefaultFlag($flags);
    my $name  = createOptionNameFromFlags($flags);

    if(defined($get_opt_val) && !isOptRefUnique($get_opt_val,$flag))
      {
        $num_setup_errors++;
        return(undef);
      }

    #Validity of hidden is checked in applyOptionAddendums in case this option
    #ends up as part of an outfile tagteam

    if($req_with_opt < 0 || $req_with_opt =~ /\D/)
      {
	error("Invalid file type id: [$req_with_opt].  Must be a value ",
	      "returned from addInfileOption.");
        $num_setup_errors++;
	return(undef);
      }

    if($req_with_opt > $#{$usage_array} ||
       ($usage_array->[$req_with_opt]->{OPTTYPE} ne 'infile' &&
        $usage_array->[$req_with_opt]->{OPTTYPE} ne 'outfile'))
      {
	error("Outfile suffix option [$flag] has been added to take a suffix ",
	      "that is appended to input file type [$req_with_opt], but that ",
	      "input file type has either not been created yet or is not an ",
	      "infile option.",
	      {DETAIL => ("File types should be created by addInfileOption " .
                          "before specifying an outfile suffix is added to " .
                          "be appended to those files.")});
        $num_setup_errors++;
	return(undef);
      }

    if(ref($get_opt_val) eq 'SCALAR')
      {
	if(defined($$get_opt_val) && defined($default) &&
	   $$get_opt_val ne $default)
	  {
	    error('Multiple conflicting default suffix values.  Both VARREF ',
		  'and DEFAULT parameters have defined values.  Define only ',
		  '1.');
            $num_setup_errors++;
            return(undef);
	  }
	elsif(defined($$get_opt_val))
	  {$default = $$get_opt_val}
      }

    if(defined($collide_mode) && $collide_mode ne '' &&
       $collide_mode ne 'error' && $collide_mode ne 'rename' &&
       $collide_mode ne 'merge')
      {
	my $defcoll = getCollisionMode(undef,'suffix');
	error("Invalid COLLISIONMODE parameter: [$collide_mode].  Must be one ",
	      "of ['error','merge','rename'].  Reverting to default: ",
	      "[$defcoll].");
	$collide_mode = $defcoll;
      }

    $GetOptHash->{$get_opt_str} = getGetoptSub($name,0);

    if(defined($smry_desc) && $smry_desc ne '' &&
       (!defined($detail_desc) || $detail_desc eq ''))
      {$detail_desc = $smry_desc}

    #If smry_desc is not defined or is an empty string
    if(!defined($smry_desc) || $smry_desc eq '')
      {
	if(($required || !defined($detail_desc)) &&
           $usage_array->[$req_with_opt]->{OPTTYPE} eq 'infile')
	  {$smry_desc = defined($detail_desc) ? $detail_desc :
             'Outfile suffix appended to file names supplied to [' .
               getFlag($usage_array->[$req_with_opt]) . '].'}
	else
	  {$smry_desc = ''}
      }

    if((!defined($detail_desc) || $detail_desc eq '') &&
       $usage_array->[$req_with_opt]->{OPTTYPE} eq 'infile')
      {$detail_desc =
	 join('',
	      ('Outfile suffix appended to file names supplied to [',
	       getFlag($usage_array->[$req_with_opt]),
	       '].  See --help for file format.'))}
    #If the description doesn't reference the help flag for the file format and
    #a file format was provided, add a reference to it
    elsif($detail_desc !~ /--help/ && defined($format_desc) &&
	  $format_desc ne '')
      {$detail_desc .= "\n\nSee --help for file format."}

    #Note: primary defaults to true in addToUsage for outfile and suffix types
    if(!defined($display_def) && !defined($default) &&
       (!defined($primary) || $primary) && !$required)
      {$display_def = 'STDOUT'}

    if(defined($display_def) && (ref($display_def) ne '' || $display_def eq ''))
      {
	error("Invalid display default.  Must be a non-empty string.  ",
	      "Ignoring.");
	undef($display_def);
      }

    my $optid = addToUsage($get_opt_str,
			   $flags,
			   $smry_desc,
			   $detail_desc,
			   $required,
			   $display_def,
			   $default,
			   undef,         #accepts
			   $hidden,
			   'suffix',
			   0,
			   $advanced,
			   $heading,
			   undef,         #usage name
			   undef,         #usage order
			   $get_opt_val,
			   $req_with_opt,
			   getRelationStr('1:M'),
			   undef,
			   $primary,
			   $format_desc,
			   $collide_mode);

    if(!defined($optid))
      {
        $num_setup_errors++;
        return(undef);
      }

    if($adding_default)
      {
	$default_suffix_optid         = $optid;
	$default_outfile_suffix_added = 1;
      }

    return($#{$usage_array});
  }

#This sub should only be called once.
sub addLogfileOption
  {
    my @in = getSubParams([qw(FLAG|GETOPTKEY APPEND|APPEND_MODE REQUIRED DEFAULT
			      SHORT_DESC|SMRY|SMRY_DESC
			      LONG_DESC|DETAIL|DETAIL_DESC HIDDEN ADVANCED
			      HEADING DISPDEF VERBOSE DEBUG WARN ERROR MIRROR
                              HEADER|RUNINFO RUNREPORT)],
			  [],
			  [@_]);
    my $get_opt_str  = $in[0]; #e.g. 'l|logfile=s'
    my $append_mode  = $in[1]; #e.g. 0 or1
    my $required     = $in[2]; #Is file required?: 0 (false) or non-zero (true)
    my $default      = $in[3]; #e.g. 'my_output_file.txt'
    my $smry_desc    = $in[4]; #e.g. 'Log file.' undef = exclude from short usg
    my $detail_desc  = $in[5]; #e.g. 'Input file(s).  Space separated, globs...'
    my $hidden       = $in[6]; #0 or non-0. Requires default. Excludes from usg.
    my $advanced     = $in[7]; #Advanced options print when extended >= 2
    my $heading      = $in[8]; #Section heading to print in extended usage
    my $display_def  = $in[9]; #The default to display in the usage
    my $verboses     = defined($in[10]) ? $in[10] : 1; #Log verbose messages
    my $debugs       = defined($in[11]) ? $in[11] : 1; #Log debug messages
    my $warnings     = defined($in[12]) ? $in[12] : 1; #Log warning messages
    my $errors       = defined($in[13]) ? $in[13] : 1; #Log errors
    my $stderr       = defined($in[14]) ? $in[14] : 0; #Mirror log to STDERR
    my $runinfo      = defined($in[15]) ? $in[15] : 1; #Put header in log
    my $runreport    = defined($in[16]) ? $in[16] : 1; #Put run report in log

    #Trim leading & trailing hard returns and white space characters (from
    #using '<<')
    $smry_desc   =~ s/^\s+//s if(defined($smry_desc));
    $smry_desc   =~ s/\s+$//s if(defined($smry_desc));
    $detail_desc =~ s/^\s+//s if(defined($detail_desc));
    $detail_desc =~ s/\s+$//s if(defined($detail_desc));

    if($command_line_stage >= ARGSREAD)
      {
	error("You cannot add command line options (i.e. call ",
	      "addLogfileOption()) after the command line has already been ",
	      "processed (i.e. processCommandLine()) without at least ",
	      "re-initializing (i.e. calling _init()).");
	return(undef);
      }

    if($logfile_added)
      {
	error('The logfile type has already been added.');
	return(undef);
      }

    #Defaults mode - Only call with no params once.
    my $adding_default = (scalar(@in) == 0);
    #If we are adding a default logfile option, a logfile suffix option exists,
    #and this was called through addDefaultFileOptions, set hidden to true
    if($adding_default && $logfile_suffix_added &&
       isCaller('addDefaultFileOptions'))
      {
	$hidden   = 1;
	$required = $usage_array->[$logfile_suffix_optid]->{REQUIRED};
      }

    if(!defined($get_opt_str) || $get_opt_str eq '')
      {
	$get_opt_str = removeDupeFlags($default_logfile_opt);
	if(!defined($get_opt_str) || $get_opt_str eq '')
	  {
	    error("Unable to add default log file type [$default_logfile_opt] ",
		  'due to redundant flags: [',
		  join(',',getDupeFlags($default_logfile_opt,
                                        $default_logfile_opt)),'].');
	    return(undef);
	  }
	$default_logfile_opt = $get_opt_str;
      }

    #Allow the flag to be an array of scalars and turn it into a get opt str
    my $save_getoptstr = $get_opt_str;
    $get_opt_str = makeGetOptKey($get_opt_str,'logfile',0,'addLogfileOption');

    if(defined($get_opt_str))
      {$get_opt_str = fixStringOpt($get_opt_str)}
    else
      {
	$num_setup_errors++;
	return(undef);
      }

    if(!isGetOptStrValid($get_opt_str,'logfile',$default_logfile_opt))
      {
	if($adding_default)
	  {warning("Unable to add default log file option.")}
	else
	  {
            $num_setup_errors++;
            return(undef);
	  }
	return(undef);
      }

    #Set globals for what to put in the log and stderr
    $log_verbose  = $verboses;
    $log_debug    = $debugs;
    $log_warnings = $warnings;
    $log_errors   = $errors;
    $log_mirror   = $stderr;
    $log_header   = $runinfo;
    $log_report   = $runreport;

    if(!defined($append_mode))
      {$append_mode = 1}

    if(defined($required) && $required !~ /^\d+$/)
      {error("Invalid REQUIRED parameter: [$required].")}

    #If hidden is not defined, default to 0.
    if(!defined($hidden))
      {$hidden = 0}

    my $flags = [getOptStrFlags($get_opt_str)];
    my $flag  = getDefaultFlag($flags);
    my $name  = createOptionNameFromFlags($flags);

    #Add the default(s) to the default infiles array, to be globbed when the
    #command line is processed
    if(defined($default))
      {
	my($twodarray,$default_str) = makeCheck2DFileArray($default);
	if(defined($twodarray))
	  {$default = $twodarray->[0]->[0]}
	else
	  {
            $num_setup_errors++;
            return(undef);
          }
      }

    if(defined($display_def) && (ref($display_def) ne '' || $display_def eq ''))
      {
	error("Invalid display default.  Must be a non-empty string.  ",
	      "Ignoring.");
	undef($display_def);
      }

    if((!defined($detail_desc) || $detail_desc eq '') &&
       (defined($smry_desc) && $smry_desc ne ''))
      {$detail_desc = $smry_desc}

    #Note, addToUsage won't include if set to empty string
    if(!defined($smry_desc) || $smry_desc eq '')
      {
	if($required)
	  {$smry_desc = defined($detail_desc) ? $detail_desc : 'Log file.'}
	elsif(!defined($smry_desc))
	  {$smry_desc = ''}
      }

    if(!defined($detail_desc) || $detail_desc eq '')
      {$detail_desc = join('',('Log file.  All standard error output will be ' .
			       'mirrored here (except for messages on a ' .
			       'single line that get over-written, i.e. end ' .
			       'with a carriage return instead of a newline ' .
			       'character).'))}

    $GetOptHash->{$get_opt_str} = getGetoptSub($name,0);

    my $usage_index = addToUsage($get_opt_str,
                                 $flags,
                                 $smry_desc,
                                 $detail_desc,
                                 $required,
                                 $display_def,
                                 $default,
                                 undef,         #accepts
                                 $hidden,
                                 'logfile',
                                 0,             #flagless
                                 $advanced,
                                 $heading,
                                 undef,         #usage name
                                 undef,         #usage order
                                 \my $junk,     #VARREF_PRG: ref programmer spld
                                 undef,         #req_with_opt
                                 undef,         #req_rel_str
                                 undef,         #delimiter
                                 undef,         #primary
                                 undef,         #format
                                 'merge',       #collision mode
                                 $append_mode);

    if(!defined($usage_index))
      {
        $num_setup_errors++;
        return(undef);
      }

    $logfile_added  = 1;
    $logfile_optid  = $usage_index;

    return($usage_index);
  }

sub addLogfileSuffixOption
  {
    my @in = getSubParams([qw(PAIRID FLAG|GETOPTKEY VARREF|GETOPTVAL REQUIRED
			      DEFAULT HIDDEN SHORT_DESC|SMRY|SMRY_DESC
			      LONG_DESC|DETAIL|DETAIL_DESC APPEND|APPEND_MODE
			      ADVANCED HEADING DISPDEF VERBOSE DEBUG WARN ERROR
			      MIRROR HEADER|RUNINFO RUNREPORT)],
			  [qw(PAIRID)], #Require PAIRID only
			  [@_]);
    my $req_with_opt = $in[0]; #The only required option
    my $get_opt_str  = $in[1]; #e.g. 'o|suffix=s' - default: --logfile-suffix
    my $get_opt_val  = $in[2]; #A reference to a scalar
    my $required     = $in[3]; #Is suff required?: 0 (false) or non-0 (true)
    my $default      = $in[4]; #e.g. '.out'
    my $hidden       = $in[5]; #0 or non-0. Non-0 requires a default.
                                  #Excludes from usage output.
    my $smry_desc    = $in[6]; #e.g. Input file(s).  See --help for format.
                                  #Empty/undefined = exclude from short usage
    my $detail_desc  = $in[7]; #e.g. 'Input file(s).  Space separated,...'
    my $append_mode  = $in[8]; #e.g. 0 or 1
    my $advanced     = $in[9]; #Advanced options print when extended >= 2
    my $heading      = $in[10];#Section heading to print in extended usage
    my $display_def  = $in[11];#The default to display in the usage
    my $verboses     = defined($in[12]) ? $in[12] : 1; #Log verbose messages
    my $debugs       = defined($in[13]) ? $in[13] : 1; #Log debug messages
    my $warnings     = defined($in[14]) ? $in[14] : 1; #Log warning messages
    my $errors       = defined($in[15]) ? $in[15] : 1; #Log errors
    my $stderr       = defined($in[16]) ? $in[16] : 0; #Also allow STDERR output
    my $runinfo      = defined($in[17]) ? $in[17] : 1; #Put header in log
    my $runreport    = defined($in[18]) ? $in[18] : 1; #Put run report in log
    my($req_with_uhash);
    ##TODO: Don't use the generic/global collide_mode here - implement an
    #output mode that the user can control per outfile type.  See requirement
    #114

    #Trim leading & trailing hard returns and white space characters (from
    #using '<<')
    $smry_desc   =~ s/^\s+//s if(defined($smry_desc));
    $smry_desc   =~ s/\s+$//s if(defined($smry_desc));
    $detail_desc =~ s/^\s+//s if(defined($detail_desc));
    $detail_desc =~ s/\s+$//s if(defined($detail_desc));

    if(defined($req_with_opt) && (!isInt($req_with_opt) || $req_with_opt < 0 ||
				  $req_with_opt > $#{$usage_array}))
      {
	error("Invalid PAIRID: [$req_with_opt].  Must be an ID as returned by ",
	      "addOption.");
        $num_setup_errors++;
        return(undef);
      }

    if(defined($get_opt_val) && ref($get_opt_val) ne 'SCALAR')
      {
	error("GETOPTVAL must be a reference to a SCALAR to hold the value ",
	      "for the logfile suffix string, but instead, a [",
	      (ref($get_opt_val) eq '' ?
	       'SCALAR' : 'reference to a ' . ref($get_opt_val)),
	      "] was received.  Unable to add logfile suffix option.");
        $num_setup_errors++;
	return(undef);
      }
    #Create a scalar reference to undef
    elsif(!defined($get_opt_val))
      {$get_opt_val = \my $junk}

    if($command_line_stage >= ARGSREAD)
      {
	error("You cannot add command line options (i.e. call ",
	      "addLogfileSuffixOption()) after the command line has already ",
	      "been processed (i.e. processCommandLine()) without at ",
	      "least re-initializing (i.e. calling _init()).");
	return(undef);
      }

    if($logfile_suffix_added)
      {
	warning('A log file suffix type has already been added.');
	return(undef);
      }

    if(defined($get_opt_str) && $get_opt_str eq '')
      {
	warning("FLAG cannot be an empty string.  Using default.");
	undef($get_opt_str);
      }

    #If the file type ID is not an integer
    if(defined($req_with_opt) && $req_with_opt !~ /^\d+$/)
      {
	error("Invalid PAIRID parameter: [$req_with_opt].  Must be an ",
	      "unsigned integer as returned by addOption.");
        $num_setup_errors++;
        return(undef);
      }
    #If the integer is defined, was supplied by the programmer, and references
    #an output file type
    elsif(defined($req_with_opt) &&
	  $usage_array->[$req_with_opt]->{OPTTYPE} ne 'string')
      {
	error("Invalid PIARID parameter: [$req_with_opt].  Must refer ",
	      "to a string option type added by addOption, instead of a ",
	      "[$usage_array->[$req_with_opt]->{OPTTYPE}].");
        $num_setup_errors++;
        return(undef);
      }

    #If required and the paired string option's REQUIRED is false and has no
    #default - this has to be handled elsewhere due to test760

    #If required and the paired string option's HIDDEN is true
    elsif(defined($req_with_opt) && defined($required) && $required &&
	  $usage_array->[$req_with_opt]->{HIDDEN} &&
	  (!defined($usage_array->[$req_with_opt]->{DEFAULT}) ||
	   $usage_array->[$req_with_opt]->{DEFAULT} eq ''))
      {
	error("Paired string option [",
	      $usage_array->[$req_with_opt]->{OPTFLAG_DEF},"] must either be ",
	      "not HIDDEN or have a non-empty default when the logfile suffix ",
	      "is REQUIRED.");
        $num_setup_errors++;
        return(undef);
      }
    #If the file type is not defined
    elsif(!defined($req_with_opt))
      {
	error("Invalid PAIRID or unsupplied.");
        $num_setup_errors++;
        return(undef);
      }
    #If required and the paired string option's SUMMARY is empty
    elsif(defined($req_with_opt) && defined($required) && $required &&
	  (!defined($usage_array->[$req_with_opt]->{SUMMARY}) ||
           $usage_array->[$req_with_opt]->{SUMMARY} eq ''))
      {
        ##TODO: Change this to a warning once the ability to add a hash param
        #for only warning in debug mode
	debug('Paired string option [',
              $usage_array->[$req_with_opt]->{OPTFLAG_DEF},'] must have a ',
              'summary usage when the logfile suffix is REQUIRED.  Setting ',
              'SUMMARY using DETAILS.');
        $usage_array->[$req_with_opt]->{SUMMARY} =
          $usage_array->[$req_with_opt]->{DETAILS};
      }

    #If hidden is not defined, default to not hidden
    if(!defined($hidden))
      {$hidden = 0}

    if(!defined($get_opt_str))
      {$get_opt_str = $default_logfile_suffix_opt}

    #Allow the flag to be an array of scalars and turn it into a get opt str
    my $save_getoptstr = $get_opt_str;
    $get_opt_str = makeGetOptKey($get_opt_str,'logsuff',0,
				 'addLogfileSuffixOption');

    if(!defined($get_opt_str))
      {
	$num_setup_errors++;
	return(undef);
      }

    if(!isGetOptStrValid($get_opt_str,'logsuff',$default_logfile_suffix_opt))
      {
        $num_setup_errors++;
	return(undef);
      }

    $get_opt_str = fixStringOpt($get_opt_str);

    my $flags = [getOptStrFlags($get_opt_str)];
    my $flag  = getDefaultFlag($flags);
    my $name  = createOptionNameFromFlags($flags);

    if(defined($get_opt_val) && !isOptRefUnique($get_opt_val,$flag))
      {
        $num_setup_errors++;
        return(undef);
      }

    if($req_with_opt < 0 || $req_with_opt =~ /\D/)
      {
	error("Invalid PAIRID: [$req_with_opt].  Must be a value returned ",
	      "from addOption of type string.");
        $num_setup_errors++;
	return(undef);
      }

    if($req_with_opt > $#{$usage_array} ||
       $usage_array->[$req_with_opt]->{OPTTYPE} ne 'string')
      {
	error("Logfile suffix option [$flag] has been added to take a suffix ",
	      "that is appended to string option type [$req_with_opt], but ",
	      "that string type has either not been created yet or is not a ",
	      "string option.",
	      {DETAIL => ("String types should be created by addOption " .
                          "before specifying a logfile suffix option type.")});
        $num_setup_errors++;
	return(undef);
      }

    if(defined($$get_opt_val) && defined($default) && $$get_opt_val ne $default)
      {
	error("Multiple conflicting default logfile suffix values.  Both ",
	      "VARREF and DEFAULT parameters have defined (and differing) ",
	      "values.  Define only 1.");
        $num_setup_errors++;
        return(undef);
      }
    elsif(defined($$get_opt_val))
      {$default = $$get_opt_val}

    #Set globals for what to put in the log and stderr
    $log_verbose  = $verboses;
    $log_debug    = $debugs;
    $log_warnings = $warnings;
    $log_errors   = $errors;
    $log_mirror   = $stderr;
    $log_header   = $runinfo;
    $log_report   = $runreport;

    if(!defined($append_mode))
      {$append_mode = 1}

    $GetOptHash->{$get_opt_str} = getGetoptSub($name,0);

    if(defined($smry_desc) && $smry_desc ne '' &&
       (!defined($detail_desc) || $detail_desc eq ''))
      {$detail_desc = $smry_desc}

    #If smry_desc is not defined or is an empty string
    if(!defined($smry_desc) || $smry_desc eq '')
      {
	if($required)
	  {$smry_desc = defined($detail_desc) ? $detail_desc :
             'Logfile suffix appended to string supplied to [' .
               getFlag($usage_array->[$req_with_opt]) . '].'}
	else
	  {$smry_desc = ''}
      }

    if((!defined($detail_desc) || $detail_desc eq '') &&
       $usage_array->[$req_with_opt]->{OPTTYPE} eq 'string')
      {$detail_desc = 'Logfile suffix appended to string supplied to [' .
	 getFlag($usage_array->[$req_with_opt]) . '].'}

    if(!defined($display_def) && !defined($default) && !$required)
      {$display_def = 'STDERR'}

    if(defined($display_def) && (ref($display_def) ne '' || $display_def eq ''))
      {
	error("Invalid display default.  Must be a non-empty string.  ",
	      "Ignoring.");
	undef($display_def);
      }

    my $optid = addToUsage($get_opt_str,
			   $flags,
			   $smry_desc,
			   $detail_desc,
			   $required,
			   $display_def,
			   $default,
			   undef,         #accepts
			   $hidden,
			   'logsuff',
			   0,
			   $advanced,
			   $heading,
			   undef,         #usage name
			   undef,         #usage order
			   $get_opt_val,
			   $req_with_opt,
			   getRelationStr('1:1'),
			   undef,         #delimiter
			   undef,         #primary
			   undef,         #format
			   'merge',       #collision mode
			   $append_mode);

    if(!defined($optid))
      {
        $num_setup_errors++;
        return(undef);
      }

    $logfile_suffix_optid = $optid;
    $logfile_suffix_added = 1;

    return($#{$usage_array});
  }

sub addOutfileTagteamOption
  {
    my @in =
      getSubParams([qw(FLAG_SUFF|GETOPTKEY_SUFF FLAG_FILE|GETOPTKEY_FILE
		       FILETYPEID|PAIR_WITH PAIR_RELAT VARREF_SUFF|GETOPTVAL
		       REQUIRED PRIMARY FORMAT|FORMAT_DESC DEFAULT
		       DEFAULT_IS_FILE HIDDEN_SUFF HIDDEN_FILE
		       SHORT_DESC_SUFF|SMRY_SUFF|SMRY_DESC_SUFF
		       SHORT_DESC_FILE|SMRY_FILE|SMRY_DESC_FILE
		       LONG_DESC_SUFF|DETAIL_SUFF|DETAIL_DESC_SUFF
		       LONG_DESC_FILE|DETAIL_FILE|DETAIL_DESC_FILE
		       COLLISIONMODE_SUFF COLLISIONMODE_FILE ADVANCED_SUFF
		       ADVANCED_FILE DISPDEF HEADING)],
		   #If there are any params sent in, require the first
		   [scalar(@_) == 0 ? () :
		    #If there are at least 2 input file types, also require the
		    # FILETYPEID
		    (getNumInfileTypes() < 2 ?
		     qw(FLAG_SUFF|GETOPTKEY_SUFF FLAG_FILE|GETOPTKEY_FILE) :
		     qw(FLAG_SUFF|GETOPTKEY_SUFF FLAG_FILE|GETOPTKEY_FILE
			FILETYPEID|PAIR_WITH))],
		   [@_]);
    my $get_opt_str_suff = $in[0];  #e.g. 'o|suffix=s'
    my $get_opt_str_file = $in[1];  #e.g. 'outfile=s'
    my $file_type_index  = $in[2];  #Val returned from addInfileOption
    my $relationship     = $in[3];  #e.g. 1,1:1,1:M,1:1orM
    my $get_opt_val      = $in[4];  #A reference to a scalar
    my $required         = $in[5];  #Is outfile required?: 0=false non-0=true
    my $primary          = $in[6];  #non-0=STDOUT if unsup
    my $format_desc      = $in[7];  #e.g. 'Tab delim text w/ cols: 1.Name...'
    my $default          = $in[8];  #e.g. '.out' or 'file.out'
    my $default_is_file  = $in[9];  #0 or non-0.
    my $hidden_suff      = $in[10]; #0 or non-0. Non-0 requires a default.
                                    #Excludes from usage
    my $hidden_file      = $in[11]; #0 or non-0. Non-0 requires a default.
                                    #Excludes from usage
    my $smry_desc_suff   = $in[12]; #e.g. Outfile suffix.
                                    #Empty/undefined = exclude from short usage
    my $smry_desc_file   = $in[13]; #e.g. Output file.
                                    #Empty/undefined = exclude from short usage
    my $detail_desc_suff = $in[14]; #e.g. Outfile suffix.  See --help for...
    my $detail_desc_file = $in[15]; #e.g. Output file.  See --help for...
    my $collid_mode_suff = $in[16]; #1 of: merge,rename,error
    my $collid_mode_file = $in[17]; #1 of: merge,rename,error
    my $advanced_suff    = $in[18]; #Advanced options print when extended >= 2
    my $advanced_file    = $in[19]; #Advanced options print when extended >= 2
    my $display_def      = $in[20]; #The default to display in the usage
    my $heading          = $in[21]; #Section heading for first option
    my($suffix_id,$outfile_id);

    #If no parameters were submitted, add the default options
    if(scalar(@_) == 0)
      {
	if($default_tagteam_added)
	  {
	    error("A default outfile tagteam has already been added.");
	    return(undef,undef);
	  }
	$default_tagteam_added = 1;

	$suffix_id  = addOutfileSuffixOption();
	$outfile_id = addOutfileOption();
      }
    else
      {
	#There can only be 1 with a default
	my($default_suff,$default_file) =
	  (defined($default_is_file) && $default_is_file ?
	   (undef,$default) : ($default,undef));
	my($dispdef_suff,$dispdef_file) =
	  (defined($default_is_file) && $default_is_file ?
	   (undef,$display_def) : ($display_def,undef));

	$suffix_id  = addOutfileSuffixOption($get_opt_str_suff,
					     $file_type_index,
					     $get_opt_val,
					     $required,
					     $primary,
					     $default_suff,
					     $hidden_suff,
					     $smry_desc_suff,
					     $detail_desc_suff,
					     $format_desc,
					     $collid_mode_suff,
					     $advanced_suff,
					     $heading,
					     $dispdef_suff);

        #Assuming errors already printed if suffix_id is undef
        if(!defined($suffix_id))
          {return(undef,undef)}

        #If the suffix option assigned a file type index by default (and none
        #was defined in the call to this sub, define it for the call to
        #addOutfileOption (because it does not assign this by default).
        if(!defined($file_type_index) && defined($suffix_id) &&
           defined($usage_array->[$suffix_id]->{PAIRID}))
          {$file_type_index = $usage_array->[$suffix_id]->{PAIRID}}

	$outfile_id = addOutfileOption($get_opt_str_file,
				       $collid_mode_file,
				       $required,
				       $primary,
				       $default_file,
				       $smry_desc_file,
				       $detail_desc_file,
				       $format_desc,
				       $hidden_file,
				       $file_type_index,
				       $relationship,
				       undef, #flagless
				       $advanced_file,
				       undef, #heading
				       $dispdef_file);

        #Assuming errors already printed if outfile_id is undef
        if(!defined($outfile_id))
          {return(undef,undef)}
      }

    my $ttid = createSuffixOutfileTagteam($suffix_id,$outfile_id,0);

    if(!defined($ttid))
      {return(undef,undef)}

    #It should not matter which usage index we return.  We will return both.  If
    #they assign a scalar to the return value, they will get the last one.
    return($suffix_id,$outfile_id);
  }

#This sub links options created by addOutfileSuffixOption and addOutfileOption
#in such a way that either one or the other can be supplied to generate output
#file names.  It edits the options if there is a conflict in the options versus
#what was supplied to this method.  Difference in PRIMARY and REQUIRED can
#change the PRIMARY, REQUIRED, DEFAULT, and SUMMARY values in the usage.
#DEFAULT and SUMMARY can change IF they contin default values that were
#inflenced by PRIMARY and/or REQUIRED values.  Other variables are also edited
#if PRIMARY and/or REQUIRED change: values in $usage_array,
sub createSuffixOutfileTagteam
  {
    my $suffix_optid  = $_[0];
    my $outfile_optid = $_[1];
    my $skip_existing = defined($_[2]) ? $_[2] : 0; #See addDefaultFileOptions

    #Tagteam IDs will be negative numbers so they do not collide with outfile
    #suffix IDs.  This gets a unique one.
    my $ttid = -1 - scalar(keys(%$outfile_tagteams));

    #Get the option ID of the hidden suffix associated with the outfile option
    my $outfile_suffix_optid = (map {$_->{OPTION_ID}}
				grep {$_->{OPTTYPE} eq 'suffix' &&
					$_->{PAIRID} == $outfile_optid}
				@$usage_array)[0];

    if(!defined($suffix_optid) || $#{$usage_array} < $suffix_optid ||
       $usage_array->[$suffix_optid]->{OPTTYPE} ne 'suffix')
      {
	error("Invalid suffix option ID: [",
	      (defined($suffix_optid) ? $suffix_optid : 'undef'),"].");
        $num_setup_errors++;
	return(undef);
      }
    else
      {debug({LEVEL => -2},"Suffix option ID: [$suffix_optid] is a valid ",
	     "[$usage_array->[$suffix_optid]->{OPTTYPE}] linked to a [",
	     $usage_array->[$usage_array->[$suffix_optid]->{PAIRID}]->{OPTTYPE},
	     "].")}

    if(!defined($outfile_optid) || $#{$usage_array} < $outfile_optid ||
       $usage_array->[$outfile_optid]->{OPTTYPE} ne 'outfile')
      {
	error("Invalid outfile option ID: [",
	      (defined($outfile_optid) ? $outfile_optid : 'undef'),"].");
        $num_setup_errors++;
	return(undef);
      }
    else
      {debug({LEVEL => -2},"Outfile option ID: [$outfile_optid] is a valid ",
	     "[$usage_array->[$outfile_optid]->{OPTTYPE}] linked to a [",
	     $usage_array->[$usage_array->[$outfile_optid]->{PAIRID}]
	     ->{OPTTYPE},"].")}

    my $if_opt_id    = $usage_array->[$suffix_optid]->{PAIRID};
    my $of_usage     = $usage_array->[$outfile_optid];
    my $ofsuff_usage = $usage_array->[$outfile_suffix_optid];
    my $sf_usage     = $usage_array->[$suffix_optid];

    #If this is being called from addDefaultFileOptions, figure out which
    #type was not default-added (if any) so that we can change the tagteam ID
    #to it (because the user won't otherwise have a way of retrieving the
    #default-added outfile type)
    my $outf_explicit = 1;
    my $suff_explicit = 1;
    if(isCaller('addDefaultFileOptions'))
      {
	my $def_outf_suff_optid = -1;
	if($default_outfile_added)
	  {$def_outf_suff_optid =
	     (map {$_->{OPTION_ID}}
	      grep {$_->{OPTTYPE} eq 'suffix' && defined($_->{PAIRID}) &&
		      $_->{PAIRID} == $default_outfile_optid}
	      @$usage_array)[0]}

	if($default_outfile_suffix_added && $default_outfile_added &&
	   $def_outf_suff_optid == $outfile_suffix_optid &&
	   $default_suffix_optid == $suffix_optid)
	  {
	    $ttid          = 0;
	    $outf_explicit = 0;
	    $suff_explicit = 0;
	  }
	elsif($default_outfile_suffix_added && !$default_outfile_added &&
	      $default_suffix_optid == $suffix_optid)
	  {
	    $ttid          = $outfile_suffix_optid;
	    $suff_explicit = 0;
	  }
	elsif($default_outfile_added && !$default_outfile_suffix_added &&
	      $def_outf_suff_optid == $outfile_suffix_optid)
	  {
	    $ttid          = $suffix_optid;
	    $outf_explicit = 0;
	  }
      }

    #Make sure these IDs aren't involved in any other tagteams
    my $dupe = 0;
    if(scalar(grep {$_->{SUFFOPTID} eq $suffix_optid}
	      values(%$outfile_tagteams)))
      {
	my $already_outsf_index =
	  (grep {$_->{SUFFOPTID} eq $outfile_suffix_optid}
	   values(%$outfile_tagteams))[0]->{OTSFOPTID};
	my $already_outf_index = $usage_array->[$already_outsf_index]->{PAIRID};
	error("The outfile suffix supplied as [",
	      getFlag($usage_array->[$suffix_optid]),
	      "] already belongs to an outfile tagteam with outfiles supplied ",
	      "as [",$usage_array->[$already_outf_index]->{OPTFLAG_DEF},
	      "].  Unable to add to another tagteam.") unless($skip_existing);
	$dupe = 1;
      }
    if(scalar(grep {$_->{OTSFOPTID} eq $outfile_suffix_optid}
	      values(%$outfile_tagteams)))
      {
	my $already_suff_id = (grep {$_->{OTSFOPTID} eq $outfile_suffix_optid}
			       values(%$outfile_tagteams))[0]->{SUFFOPTID};
	error("Outfiles supplied as [",getFlag($usage_array->[$outfile_optid]),
	      "] already belong to an outfile tagteam with outfiles created ",
	      "with suffixes supplied as [",
	      getFlag($usage_array->[$already_suff_id]),
	      "].  Unable to add to another tagteam.") unless($skip_existing);
	$dupe = 1;
      }
    if($dupe)
      {
        $num_setup_errors++;
        return(undef);
      }

    #If the suffix ID is not from addOutfileSuffixOption
    if($if_opt_id > $#{$usage_array} ||
       $usage_array->[$if_opt_id]->{OPTTYPE} ne 'infile')
      {
	error("The outfile suffix option ID submitted: [$suffix_optid] does ",
	      "not appear to be an outfile suffix, as the file option it is ",
	      "linked to is not an input file: [",
	      getFlag($usage_array->[$if_opt_id]),
	      "], and not an input file as expected.");
        $num_setup_errors++;
	return(undef);
      }
    if($outfile_optid > $#{$usage_array} ||
       $usage_array->[$outfile_optid]->{OPTTYPE} ne 'outfile')
      {
	error("The outfile ID submitted: [$outfile_optid] does not appear to ",
	      "be an outfile option, as the file option it is linked to is an ",
	      "input file, [",getFlag($usage_array->[$outfile_optid]),
	      "], and not an output file as expected.");
        $num_setup_errors++;
	return(undef);
      }

    #Make sure that if the outfile option has a PAIR_WITH value, it is the same.
    #as the FILETYPEID of the suffix option, otherwise - fatal error.
    #If there is any relationship that the outfile links to that is not this
    #infile...
    if(defined($of_usage->{PAIRID}) && $of_usage->{PAIRID} != $if_opt_id)
      {
	if(defined($of_usage->{PAIRID}))
	  {error('Outfile tagteam error: suffix [',
		 getFlag($usage_array->[$suffix_optid]),
		 '] and outfile(s) [',getFlag($usage_array->[$outfile_optid]),
		 '] are not associated with the same input file(s): [',
		 getFlag($usage_array->[$if_opt_id]),'] and [',
		 getFlag($usage_array->[$of_usage->{PAIRID}]),
		 '], respectively.',
		 {DETAIL => ('An outfile tagteam must be between an outfile ' .
			     "suffix type [ID: $suffix_optid] and an outfile " .
			     "type [ID: $outfile_optid] that are associated " .
			     "with the same input file type [ID: $if_opt_id " .
			     "!= PAIR_RELAT $of_usage->{PAIRID}].")})}
	else
	  {error('Outfile tagteam error: suffix [',
		 getFlag($usage_array->[$suffix_optid]),
		 '] and outfile(s) [',getFlag($usage_array->[$outfile_optid]),
		 '] are not associated with the same input file(s): [',
		 getFlag($usage_array->[$if_opt_id]),'] versus ',
		 '[no input file type relationship defined] respectively.',
		 {DETAIL => ('An outfile tagteam must be between an outfile ' .
			     "suffix type [ID: $suffix_optid] and an outfile " .
			     "type [ID: $outfile_optid] that are associated " .
			     'with the same input file type [ID: ' .
			     "$if_opt_id != PAIR_RELAT undef].")})}
        $num_setup_errors++;
	return(undef);
      }
    #Else if a relationship wasn't saved at all
    elsif(!defined($of_usage->{PAIRID}))
      {addRequiredRelationship($outfile_optid,
			       $if_opt_id,
			       getRelationStr('1:1orM'))}

    #Set $primary from the file IDs
    debug({LEVEL => -2},"Arbitrarily setting PRIMARY to the value from ",
	  "the ",($outf_explicit ? 'outfile' : 'suffix')," option.");
    #Suffix's primary value is the default
    my $primary = ($outf_explicit ? $of_usage->{PRIMARY} :
		   ($suff_explicit ? $sf_usage->{PRIMARY} : 1));

    #Make sure PRIMARY agrees with the options supplied
    if($of_usage->{PRIMARY} != $primary)
      {
	warning("Tagteam outfile conflict for PRIMARY output settings.  ",
		"An outfile tagteam is set as ",($primary ? '' : 'NOT '),
		"PRIMARY, but outfiles supplied as [",
		getFlag($usage_array->[$outfile_optid]),
		"] were explicitly and independently set as ",
		($of_usage->{PRIMARY} ? '' : 'NOT '),"PRIMARY.")
	  if($outf_explicit);

	$of_usage->{PRIMARY} = $primary;

	#If the default was automatically set based on its own primary value,
	#reset it based on the value supplied here
	if($of_usage->{DISPDEF} eq 'STDOUT' ||
	   $of_usage->{DISPDEF} eq '')
	  {$of_usage->{DISPDEF} = ($primary ? 'STDOUT' : undef)}

	$ofsuff_usage->{PRIMARY} = $primary;
      }
    #This one can be assumed to be the same as the above, but we'll double-
    #check it if the above matches
    elsif($ofsuff_usage->{PRIMARY} != $primary)
      {
	warning("Tagteam outfile's hidden suffix conflict for PRIMARY ",
		"output settings.  The tagteam output is set as ",
		($primary ? '' : 'NOT '),"PRIMARY, but its suffix [",
		getFlag($ofsuff_usage),"] is set as ",
		($ofsuff_usage->{PRIMARY} ? '' : 'NOT '),"PRIMARY.")
	  if($outf_explicit);

	$ofsuff_usage->{PRIMARY} = $primary;
      }
    if($sf_usage->{PRIMARY} != $primary)
      {
	warning("Tagteam suffix conflict for PRIMARY output settings.  ",
		"The tagteam output is set as ",($primary ? '' : 'NOT '),
		"PRIMARY, but the settings for its suffix [",getFlag($sf_usage),
		"] is set as ",($sf_usage->{PRIMARY} ? '' : 'NOT '),"PRIMARY.")
	  if($suff_explicit);

	$sf_usage->{PRIMARY} = $primary;
      }

    #Set $required from the file IDs
    debug({LEVEL => -2},"Arbitrarily setting REQUIRED to the value ",
	  ($outf_explicit ? "from the outfile option [$of_usage->{REQUIRED}]" :
	   ($suff_explicit ? "from the suffix option [$sf_usage->{REQUIRED}]" :
	    'to 0')),'.');
    #Suffix's required value is the default
    my $required = ($outf_explicit ? $of_usage->{REQUIRED} :
		    ($suff_explicit ? $sf_usage->{REQUIRED} : 0));

    #Check each option's REQUIRED value and issue a warning if either is true
    if(!$required && $of_usage->{REQUIRED})
      {
	warning("Tagteam outfile conflict for REQUIRED output settings.  ",
		"An outfile tagteam is set as ",($required ? '' : 'NOT '),
		"REQUIRED, but outfiles supplied as [",
		getFlag($usage_array->[$outfile_optid]),
		"] were explicitly and independently set as ",
		($of_usage->{REQUIRED} ? '' : 'NOT '),"REQUIRED.")
	  if($outf_explicit);

	#We will leave the SUMMARY for the usage as-is, since we want required
	#options (especially if the user added it explicitly as required) to
	#show in the summary usage
      }
    if(!$required && $sf_usage->{REQUIRED})
      {
	warning("Tagteam suffix conflict for REQUIRED output settings.  ",
		"The tagteam output is set as ",($required ? '' : 'NOT '),
		"REQUIRED, but the settings for its suffix [",
		getFlag($sf_usage),
		"] is set as ",($sf_usage->{REQUIRED} ? '' : 'NOT '),
		"REQUIRED.")
	  if($suff_explicit);

	#We will leave the SUMMARY for the usage as-is, since we want required
	#options (especially if the user added it explicitly as required) to
	#show in the summary usage
      }

    #Set the options' REQUIRED value to false
    #Regardless of the value of required for the tagteam, the individual
    #options will always be set to not be required so that the tagteam
    #requirement can be enforced without individual required options interfering
    $of_usage->{REQUIRED}     = 0;
    $ofsuff_usage->{REQUIRED} = 0;
    $sf_usage->{REQUIRED}     = 0;

    #Check whether any options are hidden
    #Both being defaulted is handled by the mutex code
    my $hidden = $of_usage->{HIDDEN} + $sf_usage->{HIDDEN};
    if($required && !$primary && $hidden == 2 &&
       !hasDefault($of_usage) && !hasDefault($sf_usage))
      {
	warning('Cannot hide both [',getBestFlag($sf_usage),'] and [',
		getBestFlag($usage_array->[$outfile_optid]),'] when required, ',
                'non-primary, and no default provided.  Unhiding.',
                {DETAIL =>
                 'Non-primary means the do not output to standard out.'});
	$of_usage->{HIDDEN} = 0;
	$sf_usage->{HIDDEN} = 0;
      }

    #Mark these items as being involved in a tagteam, so they can be skipped in
    #customHelp
    $of_usage    ->{TAGTEAM} = 1;
    $ofsuff_usage->{TAGTEAM} = 1;
    $sf_usage    ->{TAGTEAM} = 1;

    #Save the tagteam ID so that it can be looked up during the processing of
    #the usage_array hashes
    $of_usage    ->{TAGTEAMID} = $ttid;
    $ofsuff_usage->{TAGTEAMID} = $ttid;
    $sf_usage    ->{TAGTEAMID} = $ttid;

    #These are the hash keys of the hashes in the usage_array that are used in
    #the customHelp method.  The same keys will be created in the
    #outfile_tagteams hash: HIDDEN, OPTFLAGS, PRIMARY, OPTTYPE, & FORMAT
    #The options will still appear individually in the usage output (though
    #they were edited above to do things like append mutual-exclusion cross-
    #references and required messages).
    my $flags = ($hidden == 1 && $of_usage->{HIDDEN} ?
		 [] : [@{$of_usage->{OPTFLAGS}}]);
    if($hidden != 1 || !$sf_usage->{HIDDEN})
      {push(@$flags,@{$sf_usage->{OPTFLAGS}})}

    my $type = (!$hidden ? 'tagteam' : ($of_usage->{HIDDEN} ?
					'suffix' : 'outfile'));

    my $format = ($outf_explicit && defined($of_usage->{FORMAT}) ?
		  $of_usage->{FORMAT} :
		  ($suff_explicit && defined($sf_usage->{FORMAT}) ?
		   $sf_usage->{FORMAT} : ''));

    my $mtxid =
      makeMutuallyExclusive(OPTIONIDS   => [$suffix_optid,$outfile_optid],
			    MUTUALS     => {SUFFOPTID => $suffix_optid,
					    OTSFOPTID => $outfile_suffix_optid,

					    REQUIRED  => $required,    #Used in
					    PRIMARY   => $primary,     #custom-
					    HIDDEN    => $hidden == 2, #Help
					    OPTFLAGS  => $flags,       #
					    OPTTYPE   => $type,        #
					    FORMAT    => $format},     #
			    REQUIRED    => $required,
			    OVERRIDABLE => 1,
                            NAME        => ('outfile tagteam ' .
                                            scalar(keys(%$outfile_tagteams))));

    if(!defined($mtxid))
      {return(undef)}

    $outfile_tagteams->{$ttid} = $mutual_params->{$mtxid};

    return($ttid);
  }

#Returns whether any of the submitted subroutine names are in the stack trace
sub isCaller
  {
    my @subs = @_;

    my $stack_level = 0;
    while(my @caller_info = caller($stack_level))
      {
	my $calling_sub = $caller_info[3];
	if(defined($calling_sub))
	  {
	    $calling_sub =~ s/^.*?::(.+)$/$1/;
	    if(scalar(grep {$calling_sub eq $_} @subs))
	      {return(1)}
	  }
	$stack_level++;
      }

    return(0);
  }

sub addOutdirOption
  {
    my @in = getSubParams([qw(FLAG|GETOPTKEY REQUIRED DEFAULT HIDDEN
			      SHORT_DESC|SMRY|SMRY_DESC
			      LONG_DESC|DETAIL|DETAIL_DESC FLAGLESS ADVANCED
			      HEADING DISPDEF)],
			  [scalar(@_) ? qw(FLAG|GETOPTKEY) : ()],
			  [@_]);
    my $get_opt_str = $in[0]; #e.g. 'outdir=s'
    my $required    = $in[1]; #Is outdir required?: 0 (false) or non-0 (true)
    my $default     = $in[2]; #e.g. 'output_directory'
    my $hidden      = $in[3]; #0 or non-0. Requires a default. Excludes from
                              #usage output.
    my $smry_desc   = $in[4]; #e.g. 'Input file(s).  See --help for format.'
                              #Empty/undefined = exclude from short usage
    my $detail_desc = $in[5]; #e.g. 'Input file(s).  Space separated,...'
    my $flagless    = $in[6]; #Whether the option can be supplied sans flag
    my $advanced    = $in[7]; #Advanced options print when extended >= 2
    my $heading     = $in[8]; #Section heading to print in extended usage
    my $display_def = $in[9]; #The default to display in the usage

    #Trim leading & trailing hard returns and white space characters (from
    #using '<<')
    $smry_desc   =~ s/^\s+//s if(defined($smry_desc));
    $smry_desc   =~ s/\s+$//s if(defined($smry_desc));
    $detail_desc =~ s/^\s+//s if(defined($detail_desc));
    $detail_desc =~ s/\s+$//s if(defined($detail_desc));

    if($command_line_stage >= ARGSREAD)
      {
	error("You cannot add command line options (i.e. call ",
	      "addOutdirOption()) after the command line has already ",
	      "been processed (i.e. processCommandLine()) without at ",
	      "least re-initializing (i.e. calling _init()).");
	return(undef);
      }

    #Defaults mode - Only call with no params once.
    my $adding_default = (scalar(@in) == 0);
    if($adding_default)
      {
	if($default_outdir_added)
	  {
	    error('The default output directory type has already been added.');
	    return(undef);
	  }

	$get_opt_str = removeDupeFlags($default_outdir_opt);
	if(!defined($get_opt_str) || $get_opt_str eq '')
	  {
	    error('Unable to add default output directory type ',
		  "[$default_outdir_opt] due to redundant flags: [",
		  join(',',getDupeFlags($default_outdir_opt,
                                        $default_outdir_opt)),'].');
	    $default_outdir_opt = $get_opt_str;
	    return(undef);
	  }
	$default_outdir_opt = $get_opt_str;

	$default_outdir_added = 1;
	$required             = 0;

	if(!visibleOutfileExists())
	  {$hidden = 1}
	#The descriptions are added below
      }

    if(defined($required) && $required !~ /^\d+$/)
      {error("Invalid REQUIRED parameter: [$required].")}

    #Allow the flag to be an array of scalars and turn it into a get opt str
    my $save_getoptstr = $get_opt_str;
    $get_opt_str = makeGetOptKey($get_opt_str,'outdir',0,'addOutdirOption');

    if(!defined($get_opt_str))
      {
	$num_setup_errors++;
	return(undef);
      }

    $get_opt_str = fixStringOpt($get_opt_str);

    if(!isGetOptStrValid($get_opt_str,'outdir',$default_outdir_opt))
      {
	if($adding_default)
	  {warning("Unable to add default output directory option.")}
	else
	  {$num_setup_errors++}
	return(undef);
      }

    my $flags = [getOptStrFlags($get_opt_str)];
    my $flag  = getDefaultFlag($flags);
    my $name  = createOptionNameFromFlags($flags);

    if($outdirs_added)
      {
        outdirLimitation(1);
        $num_setup_errors++;
	return(undef);
      }

    $outdirs_added = 1;

    if($hidden && !defined($default) && defined($required) && $required)
      {
	warning("Cannot hide option [$flag] if no default provided and if it ",
		"is required.  Setting as not hidden.");
	$hidden = 0;
      }

    #Since multiple outdirs are supported by the code and the default is
    #limited to 1, just make sure the limit is enforced.
    if(defined($default) && ref(\$default) ne 'SCALAR')
      {
	error("Default value supplied must be a scalar.  A [",ref($default),
	      "] was encountered.  Ignoring.");
	undef($default);
      }

    if(defined($default) && $default eq '')
      {
	warning("Default outdir is an empty string.",
		{DETAIL => 'Setting to undefined.'});
	undef($default);
      }

    if(defined($default))
      {
	my($twodarray,$default_str) = makeCheck2DFileArray($default);
	$default = $twodarray;
      }

    if(defined($display_def) && (ref($display_def) ne '' || $display_def eq ''))
      {
	error("Invalid display default.  Must be a non-empty string.  ",
	      "Ignoring.");
	undef($display_def);
      }

    debug({LEVEL=>-1},"Creating an outdir option.");

    ##TODO: Note, this won't be necessary in the future when I allow more than
    ##      1 outdir type.  See req 212.

    $GetOptHash->{$get_opt_str} = getGetoptSub($name,0);

    #If no summary usage was provided for this option
    if(!defined($smry_desc) || $smry_desc eq '')
      {
	if($required)
	  {$smry_desc =
             defined($detail_desc) ? $detail_desc : 'Output directory.'}
	else
	  {$smry_desc = ''}
      }

    if(!defined($detail_desc) || $detail_desc eq '')
      {
	if(defined($smry_desc) && $smry_desc ne '')
	  {$detail_desc = $smry_desc}
	else
	  {$detail_desc =
	     join('',
		  ('Directory in which to put output files.  Creates ',
		   'directories specified, but not recursively.  Also see ',
		   '--extended --help for advanced usage examples.'))}
      }

    if(defined($flagless) && $flagless)
      {
	if(defined($flagless_multival_optid) && $flagless_multival_optid > -1)
	  {
	    error("An additional multi-value option has been designated as ",
		  "'flagless': [$get_opt_str]: [$flagless].  Only 1 is ",
		  "allowed.",
		  {DETAIL => "First flagless option was: [" .
		   getDefaultFlag($usage_array->[$flagless_multival_optid]
				  ->{OPTFLAGS}) . "]."});
	    return(undef);
	  }

	$GetOptHash->{'<>'} = getGetoptSub($name,1);

	#This assumes that the call to addToUsage a few lines below is the
	#immediate next call to addToUsage
	$flagless_multival_optid = getNextUsageIndex();
      }

    my $oid = addToUsage($get_opt_str,
                         $flags,
                         $smry_desc,
                         $detail_desc,
                         $required,
                         $display_def,
                         $default,
                         undef,         #accepts
                         $hidden,
                         'outdir',
                         0,
                         $advanced,
                         $heading,
                         undef,         #usage name
                         undef,         #usage order
                         $outdirs_array,
                         undef,         #pair with option ID
                         getRelationStr('1'));

    if(!defined($oid))
      {$num_setup_errors++}

    return($oid);
  }

sub outdirLimitation
  {
    my $fatal = $_[0];
    my $flag  = getOutdirFlag();
    my $msg =
      join('',('Currently, only 1 outdir option is supported, however ',
	       'multiple outdirs can be supplied using the 1 outdir option: ',
	       "[$flag].  Files of different output types cannot currently ",
	       'be put in different outdirs, but different sets can go in ',
	       'different dirctories.  See `--help --extended` for examples ',
	       "using the sample $flag option."));
    if($fatal)
      {error($msg)}
    else
      {warning($msg)}
  }

#Returns a boolean as to whether there exists an outfile type that is visible
#(i.e. not hidden)
#Globals used: usage_array
sub visibleOutfileExists
  {
    if(scalar(grep {($_->{OPTTYPE} eq 'outfile' ||
		     $_->{OPTTYPE} eq 'suffix') && !$_->{HIDDEN}}
	      @$usage_array))
      {return(1)}

    return(0);
  }

#Returns a boolean as to whether there exists an outdir type that is visible
#(i.e. not hidden)
#Globals used: usage_array
sub visibleOutdirExists
  {
    if(scalar(grep {($_->{OPTTYPE} eq 'outdir') && !$_->{HIDDEN}}
	      @$usage_array))
      {return(1)}

    return(0);
  }

sub addOption
  {
    my @in = getSubParams([qw(FLAG|GETOPTKEY VARREF|GETOPTVAL TYPE REQUIRED
			      DISPDEF HIDDEN SHORT_DESC|SMRY|SMRY_DESC
			      LONG_DESC|DETAIL|DETAIL_DESC ACCEPTS ADVANCED
			      HEADING DEFAULT USAGE_NAME USAGE_ORDER
			      INTERNAL_ARRAY_REF INTERNAL_DELIM
			      INTERNAL_FLAGLESS)],
			  [qw(FLAG|GETOPTKEY VARREF|GETOPTVAL)],
			  [@_]);
    my $get_opt_str     = $in[0]; #e.g. 'o|suffix=s'
    my $get_opt_ref     = $in[1]; #e.g. \$my_option - A reference to a var/sub
    my $type            = $in[2]; #bool,negbool,string,integer,float,enum,count
    my $required        = $in[3]; #Is option required?: 0=false, non-0=true
    my $display_def     = $in[4]; #The default to display in the usage
    my $hidden          = $in[5]; #0 or non-0. non-0 requires a default.
                                  #Excludes from usage output.
    my $smry_desc       = $in[6]; #e.g. Input file(s).  See --help for format.
                                  #Empty/undefined = exclude from short usage
    my $detail_desc     = $in[7]; #e.g. 'Input file(s).  Space separated,...'
    my $accepts         = $in[8]; #e.g. ['yes','no','maybe']
    my $advanced        = $in[9]; #Advanced options print when extended >= 2
    my $heading         = $in[10];#Section heading to print in extended usage
    my $default         = $in[11];#E.g. '1'
    my $name            = $in[12];
    my $order           = $in[13];
    my $internal_array  = $in[14];#For internal use only
    my $internal_delim  = $in[15];#For internal use only
    my $internal_flglss = $in[16];#For internal use only

    #Trim leading & trailing hard returns and white space characters (from
    #possibly having used '<<' to define these values)
    $smry_desc   =~ s/^\s+//s if(defined($smry_desc));
    $smry_desc   =~ s/\s+$//s if(defined($smry_desc));
    $detail_desc =~ s/^\s+//s if(defined($detail_desc));
    $detail_desc =~ s/\s+$//s if(defined($detail_desc));

    if($command_line_stage >= ARGSREAD)
      {
	error("You cannot add command line options (i.e. call ",
	      "addOption()) after the command line has already ",
	      "been processed (i.e. processCommandLine()) without at ",
	      "least re-initializing (i.e. calling _init()).");
        $num_setup_errors++;
	return(undef);
      }

    if(ref($get_opt_ref) eq '')
      {
	error("Invalid VARREF.  Must be a reference.");
        $num_setup_errors++;
	return(undef);
      }

    if(defined($required) && $required !~ /^\d+$/)
      {error("Invalid REQUIRED parameter: [$required].")}

    #This validates the type passed in or sets a default if no type info
    #present
    $type = getOptType($type,$get_opt_str,$accepts,$get_opt_ref,$default,$name);
    my $save_getoptstr = $get_opt_str;
    my $get_opt_key    = makeGetOptKey($get_opt_str,$type,0,'addOption');

    if(!defined($get_opt_key))
      {
	$num_setup_errors++;
	return(undef);
      }

    my $flags = [getOptStrFlags($get_opt_key)];
    my $flag  = getDefaultFlag($flags);

    if($hidden && !defined($default) && defined($required) && $required)
      {
	warning("Cannot hide option [$flag] if no default provided and if it ",
		"is required.  Setting as not hidden.");
	$hidden = 0;
      }

    #Do no check getop str if called by addArrayOption or add2DArrayOption
    my @caller_info = caller(1);
    my $calling_sub = scalar(@caller_info) < 4 ? '' : $caller_info[3];
    debug({LEVEL => -2},"Called by $calling_sub");
    #Array options have already been added, so they have been checked for
    #validity and thus they don't need to have isGetOptStrValid called on them
    my $is_array_opt =
      ($calling_sub =~ /^CommandLineInterface::add(2D)?ArrayOption$/g);
    #Variable options should be checked for validity, but not for duplicates.
    #They are always present though as of the initial _init call, though not
    #always presented in the interface, thus the check should allow duplicates.
    my $is_builtin_opt = isCaller('addBuiltinOption');

    debug({LEVEL => -2},"Allowing duplicates?: $is_builtin_opt");

    if(!$is_array_opt && !isGetOptStrValid($get_opt_key,'general',$name))
      {
	if($is_builtin_opt)
	  {warning("Unable to add builtin option.",
		   {DETAIL => "GetOptStr: [$get_opt_str]."})}
	else
	  {$num_setup_errors++}
	return(undef);
      }

    #If no detailed usage was provided for this option
    if(!defined($detail_desc) || $detail_desc eq '')
      {
	if(defined($smry_desc) && $smry_desc ne '')
	  {$detail_desc = $smry_desc}
	else
	  {$detail_desc = 'No usage provided for this option.'}
      }

    #If no summary usage was provided for this option
    if(!defined($smry_desc) || $smry_desc eq '')
      {
	if($required)
	  {$smry_desc = defined($detail_desc) ? $detail_desc :
             'No usage summary provided for this option.'}
	else
	  {$smry_desc = ''}
      }

    if(defined($accepts) &&
       (ref($accepts) ne 'ARRAY' ||
	scalar(@$accepts) != scalar(grep {ref(\$_) eq 'SCALAR'} @$accepts)))
      {
	error("Invalid accepts value passed in.  Only a reference to an ",
	      "array of scalars is valid.  Received a reference to a",
	      (ref($accepts) eq 'ARRAY' ? 'n ARRAY of (' .
	       join(',',map {ref(\$_)} @$accepts) . ')' : ' ' . ref($accepts)),
	      "] instead.");
        $num_setup_errors++;
	return(undef);
      }

    my($getoptref);

    if(!defined($type))
      {$type = getGeneralOptType($get_opt_key)}

    if(!defined($name))
      {$name = createOptionNameFromFlags($flags)}

    if(!$is_array_opt)
      {
	$getoptref = getGetoptSub($name);

	if(ref($get_opt_ref) eq 'SCALAR' && defined($$get_opt_ref) &&
	   defined($default) && $$get_opt_ref ne $default)
	  {
	    if(isCaller('addBuiltinOption'))
	      {$$get_opt_ref = $default}
	    else
	      {
		error("Multiple conflicting default values supplied.  The ",
		      "variable reference (VARREF) is: [$$get_opt_ref] versus ",
		      "the DEFAULT: [$default].",
		      {DETAIL =>
		       join('',('Only one must have a value or they must both ',
				'be the same.  If you are trying to supply a ',
				'value to display in the usage, use the ',
				'DISPDEF parameter instead of the DEFAULT ',
				'parameter.'))});
                $num_setup_errors++;
                return(undef);
	      }
	  }

	if(ref($get_opt_ref) ne 'CODE' && defined($$get_opt_ref) &&
	   !defined($default))
	  {$default = $$get_opt_ref}

	unless(isOptRefUnique($get_opt_ref,$flag))
	  {
            $num_setup_errors++;
            return(undef);
          }

	$GetOptHash->{$get_opt_key} = $getoptref;
      }
    else
      {
	#get_opt_ref should already be a code ref from the array option subs
	$GetOptHash->{$get_opt_key} = $get_opt_ref;
      }

    if(defined($display_def) && ref($display_def) ne '')
      {
	error("Invalid display default.  Must be a non-empty string.  ",
	      "Ignoring.");
	undef($display_def);
      }

    my $oid = addToUsage($get_opt_key,
                         $flags,
                         $smry_desc,
                         $detail_desc,
                         $required,
                         $display_def,
                         $default,
                         $accepts,
                         $hidden,
                         $type,
                         $internal_flglss,
                         $advanced,
                         $heading,
                         $name,              #usage name
                         $order,             #usage order
                         $get_opt_ref,
                         undef,              #pair with option ID
                         undef,              #pair relationship
                         $internal_delim);

    if(!defined($oid))
      {$num_setup_errors++}

    return($oid);
  }

#Globals used: $def_option_hash, $command_line_stage
sub editBuiltinOption
  {
    my $opt           = shift(@_);
    my $affects_order = shift(@_);
    my %params        = scalar(@_) % 2 == 0 ? @_ : ();

    #If the option has already been added or we've passed the auto-add of
    #builtin options in processCommandLine()
    if($def_option_hash->{$opt}->{ADDED} || $command_line_stage > CALLED)
      {
	$builtin_edit_failures++;
	error("The $opt option has either already been added to the ",
	      "interface or the command line has already been processed and ",
	      "thus $opt is no longer editable.");
	return(0);
      }

    #Make sure the keys supplied are valid.  Record supplied keys.
    my $supplied = {};
    if(scalar(@_) % 2 == 0)
      {
	foreach my $key (grep {my $p = $_;
			       scalar(grep {$_ eq $p}
				      @{$def_option_hash->{$opt}->{EDITABLE}})}
			 keys(%params))
	  {
	    $supplied->{$key} = 1;
	    $def_option_hash->{$opt}->{CHANGED} = 1;
	  }
      }
    else
      {
	$builtin_edit_failures++;
	error("Odd number of values in the parameter array.",
	      {DETAIL => "The hash must be used to supply parameters with " .
	       "the following (optional) keys: [" .
	       join(',',keys(%{$def_option_hash->{$opt}->{EDITABLE}})) . "]."});
	return(0);
      }

    #Make sure all the values supplied are editable
    if(scalar(keys(%params)) &&
       scalar(grep {my $p = $_;scalar(grep {$_ eq $p}
				      @{$def_option_hash->{$opt}->{EDITABLE}})}
	      keys(%params)) != scalar(keys(%params)))
      {
	$builtin_edit_failures++;
	error("The following invalid or unallowed parameters were submitted ",
	      "to edit the $opt option: [",
	      join(',',sort {$a cmp $b}
		   grep {my $p = $_;
			 scalar(grep {$_ eq $p}
				@{$def_option_hash->{$opt}->{EDITABLE}}) == 0}
		   keys(%params)),"].",
	      {DETAIL => "Valid/allowed parameters are: [" .
	       join(',',@{$def_option_hash->{$opt}->{EDITABLE}}) . "].  You " .
	       "supplied: [" . join(',',sort(keys(%params))) . "]."});
	return(0);
      }

    #If there's nothing submitted, return success, otherwise, initialize to 0
    my $edited = (scalar(@_) ? 0 : 1);
    my @in = getSubParams($def_option_hash->{$opt}->{EDITABLE},[],[@_]);
    foreach my $index (0..$#{$def_option_hash->{$opt}->{EDITABLE}})
      {
	my $key   = $def_option_hash->{$opt}->{EDITABLE}->[$index];
	my $value = $in[$index];
	if(exists($supplied->{$key}))
	  {
	    my($goodval,$valid) = isValidBuiltinParam($opt,$key,$value);
	    if($valid)
	      {
		$def_option_hash->{$opt}->{PARAMS}->{$key} = $goodval;
		$edited = 1;
	      }
	  }
      }

    #If a successful change was made, there was a change, this change affects,
    #the option order, and no heading was supplied, clear out any default
    #heading
    if($edited && scalar(@_) && $affects_order && !exists($supplied->{HEADING}))
      {$def_option_hash->{$opt}->{PARAMS}->{HEADING} = ''}

    return($edited);
  }

#Globals used: $def_option_hash
sub isValidBuiltinParam
  {
    my $opt   = $_[0];
    my $param = $_[1];
    my $value = $_[2];
    my $retval = $value;
    my $valid  = 1;

    if(!defined($param) || !defined($opt))
      {
	error("Option and parameter must be defined.");
	$valid = 0;
      }
    elsif($param eq 'FLAG')
      {
	#Cursory check.  The real details will be checked in addOption()
	if(!defined($value) || (ref($value) ne '' && ref($value) ne 'ARRAY') ||
	   ((ref($value) eq '' && ($value !~ /\S/ || $value =~ /\s/s)) &&
	    (ref($value) eq 'ARRAY' &&
	     (scalar(@$value) !=
	      scalar(grep {ref($_) ne '' || /\s/ || $_ !~ /\S/} @$value)))))
	  {
	    error("Flags must be a string with no whitespace.");
	    $valid = 0;
	  }
        else
          {
            my $me    = 'isValidBuiltinParam';
            my $type  = $def_option_hash->{$opt}->{PARAMS}->{TYPE};
            my $gokey = makeGetOptKey($value,$type,1,$me);

            if(!isGetOptStrValid($gokey,'general',$opt))
              {$valid = 0}
          }
      }
    elsif($param eq 'VARREF' || $param eq 'TYPE')
      {
	error("Editing of VARREF, ACCEPTS, and TYPE are not supported.");
	$valid = 0;
      }
    elsif($param eq 'REQUIRED' || $param eq 'HIDDEN' || $param eq 'ADVANCED')
      {$retval = ($value ? $value : 0)}
    elsif($param eq 'DISPDEF' || $param eq 'HEADING')
      {
	if(defined($value) && ref($value) ne '')
	  {
	    error("Invalid parameter: [$param] for option [$opt].  Must be a ",
		  "string.");
	    $valid = 0;
	  }
	$retval = $value;
      }
    elsif($param eq 'SHORT_DESC' || $param eq 'LONG_DESC')
      {
	$retval = (defined($value) ? $value : '');
	if(ref($value) ne '')
	  {
	    error("Descriptions must be a string value.");
	    $valid = 0;
	  }
      }
    elsif($param eq 'DEFAULT')
      {
	#These must be defined but can be set to 0
	if($def_option_hash->{$opt}->{PARAMS}->{TYPE} eq 'negbool')
	  {
	    $valid = isBool($value);
	    $retval = (defined($value) ? ($value ? 1 : 0) : undef);
	  }
	elsif($def_option_hash->{$opt}->{PARAMS}->{TYPE} eq 'bool')
	  {
	    $valid = isBool($value);
	    $retval = ($value ? 1 : 0);
	  }
	elsif($def_option_hash->{$opt}->{PARAMS}->{TYPE} eq 'count')
	  {
	    if(defined($value))
	      {
		$valid = isCount($value);
		$retval = $value;
	      }
	  }
	elsif($def_option_hash->{$opt}->{PARAMS}->{TYPE} eq 'integer')
	  {$valid = isInt($value)}
	elsif($def_option_hash->{$opt}->{PARAMS}->{TYPE} eq 'float')
	  {$valid = isFloat($value)}
	elsif($def_option_hash->{$opt}->{PARAMS}->{TYPE} eq 'enum')
	  {
	    if(defined($value))
	      {
		#This assumes that ACCEPTS is not editable (because if it was,
		#there's no guarantee of the hash key order and we might be
		#checking the default against a stale accepts array
		$valid =
		  exists($def_option_hash->{$opt}->{PARAMS}->{ACCEPTS}) &&
		    defined($def_option_hash->{$opt}->{PARAMS}->{ACCEPTS}) &&
		      scalar(grep {$value eq $_} @{$def_option_hash->{$opt}
						     ->{PARAMS}->{ACCEPTS}});
		if(!$valid &&
		   (!exists($def_option_hash->{$opt}->{PARAMS}->{ACCEPTS}) ||
		    !defined($def_option_hash->{$opt}->{PARAMS}->{ACCEPTS}) ||
		    scalar(@{$def_option_hash->{$opt}->{PARAMS}->{ACCEPTS}}) ==
		    0))
		  {error("Invalid ACCEPTS value.  Cannot validate DEFAULT.",
			 {DETAIL => 'ACCEPTS must be an array of strings.'})}
		elsif(!$valid)
		  {error("Invalid value: [",
			 (defined($value) ? $value : 'undef'),
			 "] for parameter: [$param] of builtin option: [$opt].",
			 {DETAIL =>
			  ('Must be one of [' .
			   join(',', @{$def_option_hash->{$opt}->{PARAMS}
					 ->{ACCEPTS}}) . '].')})}
	      }
	  }
	else
	  {
	    error("Parameter type [$def_option_hash->{$opt}->{PARAMS}->{TYPE}]",
		  " is not supported yet for builtin options.");
	    $valid = 0;
	  }

	#Header and pipeline can be undefined
	if($opt eq 'header' || $opt eq 'pipeline')
	  {$valid = isBool($value)}
      }
    else
      {
	error("Invalid parameter for option [$opt]: [$param].");
	$valid = 0;
      }

    return($retval,$valid);
  }

sub editVerboseOption
  {return(editBuiltinOption('verbose',0,@_))}

sub editQuietOption
  {return(editBuiltinOption('quiet',0,@_))}

#Do not call this method internally.  Instead, check $quiet
#Globals used: $command_line_stage
sub isQuiet
  {
    unless($command_line_stage)
      {
	warning("isQuiet called before command line has been processed.");
	processCommandLine();
      }
    return(getVarref('quiet',1));
  }

sub editOverwriteOption
  {return(editBuiltinOption('overwrite',0,@_))}

#Do not call this method internally.  Instead, check $overwrite
#Globals used: $overwrite, $command_line_stage
sub isOverwrite
  {
    unless($command_line_stage)
      {
	warning("isOverwrite called before command line has been processed.");
	processCommandLine();
      }
    return(getVarref('overwrite',1));
  }

sub editSkipOption
  {return(editBuiltinOption('skip',0,@_))}

#Do not call this method internally.  Instead, check $skip_existing
#Globals used: $command_line_stage
sub isSkip
  {
    unless($command_line_stage)
      {
	warning("isSkip called before command line has been processed.");
	processCommandLine();
      }
    return(getVarref('skip',1));
  }

sub editHeaderOption
  {return(editBuiltinOption('header',0,@_))}

sub editVersionOption
  {return(editBuiltinOption('version',0,@_))}

#Do not call this method internally.  Instead, check $version.  Can only be
#effectively called in an END block of main.
#Globals used: $command_line_stage
sub wasVersionRequested
  {
    unless($command_line_stage)
      {warning("wasVersionRequested called before command line has been ",
	       "processed.")}
    return(getVarref('version',1));
  }

sub editExtendedOption
  {return(editBuiltinOption('extended',0,@_))}

#Do not call this method internally.  Instead, check $extended
#Globals used: $command_line_stage
sub isExtended
  {
    unless($command_line_stage)
      {
	warning("isExtended called before command line has been processed.");
	processCommandLine();
      }
    return(getVarref('extended',1,1));
  }

sub editForceOption
  {return(editBuiltinOption('force',0,@_))}

sub editDebugOption
  {return(editBuiltinOption('debug',0,@_))}

sub editSaveArgsOption
  {return(editBuiltinOption('save_args',0,@_))}

#Do not call this method internally.  Instead, check $use_as_default.  Can only
#be effectively called in an END block of main.
#Globals used: $command_line_stage
sub isSaveArgsMode
  {
    unless($command_line_stage)
      {
	warning("isSaveArgsMode called before command line has been ",
		"processed.");
	processCommandLine();
      }
    return(getVarref('save_args',1));
  }

sub editPipelineOption
  {return(editBuiltinOption('pipeline',0,@_))}

#This is different from inPipeline, which dynamically determines pipeline mode.
#This sub is just a getter
#Do not call this method internally.  Instead, check $pipeline
#Globals used: $pipeline, $command_line_stage
sub getPipelineMode
  {
    unless($command_line_stage)
      {
	warning("getPipelineMode called before command line has been ",
		"processed.");
	processCommandLine();
      }
    return(getVarref('pipeline',1,1));
  }

sub editErrorLimitOption
  {return(editBuiltinOption('error_lim',0,@_))}

#Do not call this method internally.  Instead, check $error_limit
#Globals used: $command_line_stage
sub getErrorLimit
  {
    unless($command_line_stage)
      {warning("getErrorLimit called before command line has been processed.")}
    return(getVarref('error_lim',1,1));
  }

sub editAppendOption
  {return(editBuiltinOption('append',0,@_))}

#Do not call this method internally.  Instead, check $append
#Globals used: $command_line_stage
sub isUserAppendMode
  {
    unless($command_line_stage)
      {
	warning("isUserAppendMode called before command line has been ",
		"processed.");
	processCommandLine();
      }
    return(getVarref('append',1));
  }

sub editRunOption
  {return(editBuiltinOption('run',0,@_))}

#Do not call this method internally.  Instead, check $run
#Globals used: $command_line_stage
sub isRunMode
  {
    unless($command_line_stage)
      {
	warning("isRunMode called before command line has been processed.");
	processCommandLine();
      }
    return(getVarref('run',1));
  }

sub editDryRunOption
  {return(editBuiltinOption('dry_run',0,@_))}

sub editUsageOption
  {return(editBuiltinOption('usage',0,@_))}

sub editCollisionOption
  {return(editBuiltinOption('collision',0,@_))}

#Do not call this method internally.  Instead, check $usage
#Globals used: $command_line_stage
sub isUsageMode
  {
    unless($command_line_stage)
      {
	warning("isUsageMode called before command line has been processed.");
	processCommandLine();
      }
    return(getVarref('usage',1));
  }

#This only dereferences scalars
sub deRefVarref
  {
    if(ref($_[0]) eq 'SCALAR')
      {return(${$_[0]})}
    return($_[0]);
  }

sub editHelpOption
  {return(editBuiltinOption('help',0,@_))}

#Do not call this method internally.  Instead, check $help
#Globals used: $command_line_stage
sub isHelpMode
  {
    unless($command_line_stage)
      {
	warning("isHelpMode called before command line has been processed.");
	processCommandLine();
      }
    return(getVarref('help',1));
  }

#Globals used: $def_option_hash, $command_line_stage
sub addBuiltinOption
  {
    my $opt = shift(@_);
    my($retval,$origretval);

    ##TODO: Do this in a better way
    my $heading_backup = $def_option_hash->{$opt}->{PARAMS}->{HEADING};

    if(!defined($opt))
      {error("First parameter is required.")}
    elsif(!exists($def_option_hash->{$opt}))
      {error("Invalid basic option key: [$opt].")}
    elsif($def_option_hash->{$opt}->{ADDED})
      {error("The $opt option has already been added to the interface.")}
    elsif($command_line_stage >= ARGSREAD)
      {error("The command line has already been processed.")}
    #Else if editing the option is successful
    elsif(editBuiltinOption($opt,1,@_))
      {
	$retval = addOption(%{$def_option_hash->{$opt}->{PARAMS}});
        $origretval = $retval;
        if(!defined($retval))
	  {
	    $def_option_hash->{$opt}->{ADDED} = 0;
	    error("Unable to add $opt option.");

            my $params = $def_option_hash->{$opt}->{PARAMS};

            #Attempt a fallback so we can handle dying gracefully
            $retval =
              addOption(FLAG       => "$params->{USAGE_NAME}__ERROR",
                        TYPE       => $params->{TYPE},
                        VARREF     => $params->{VARREF},
                        USAGE_NAME => $opt);
	  }

	if(defined($retval))
	  {
            $def_option_hash->{$opt}->{ADDED} = 1;
            $def_option_hash->{$opt}->{PARAMS}->{HEADINGBACKUP} =
              $heading_backup;
          }
      }

    if(!defined($origretval))
      {$builtin_add_failures++}

    return($retval);
  }

sub addVerboseOption
  {return(addBuiltinOption('verbose',@_))}

sub addQuietOption
  {return(addBuiltinOption('quiet',@_))}

sub addOverwriteOption
  {return(addBuiltinOption('overwrite',@_))}

sub addSkipOption
  {return(addBuiltinOption('skip',@_))}

sub addHeaderOption
  {return(addBuiltinOption('header',@_))}

sub addVersionOption
  {return(addBuiltinOption('version',@_))}

sub addExtendedOption
  {return(addBuiltinOption('extended',@_))}

sub addForceOption
  {return(addBuiltinOption('force',@_))}

sub addDebugOption
  {return(addBuiltinOption('debug',@_))}

sub addSaveArgsOption
  {return(addBuiltinOption('save_args',@_))}

sub addPipelineOption
  {return(addBuiltinOption('pipeline',@_))}

sub addErrorLimitOption
  {return(addBuiltinOption('error_lim',@_))}

sub addAppendOption
  {return(addBuiltinOption('append',@_))}

sub addCollisionOption
  {return(addBuiltinOption('collision',@_))}

#Do not call this method internally.  Instead, check $user_collide_mode
#Globals used: $user_collide_mode, $command_line_stage
sub getUserCollisionMode
  {
    unless($command_line_stage)
      {warning("getUserCollisionMode called before command line has been ",
	       "processed.")}
    return($user_collide_mode);
  }

sub addRunOption
  {return(addBuiltinOption('run',@_))}

sub addDryRunOption
  {return(addBuiltinOption('dry_run',@_))}

sub addUsageOption
  {return(addBuiltinOption('usage',@_))}

sub addHelpOption
  {return(addBuiltinOption('help',@_))}

#Checks the validity of values (ignores undefs because they're handled by the
#requirement checking code).  Assumes default values have been copied to
#VARREF_CLI
#Globals used: $usage_array, $genopt_types
sub validateGeneralOptions
  {
    my $status = 1;

    #For every option that's been supplied a defined reference of a known type
    foreach my $usghash (grep {defined($_->{OPTTYPE}) &&
				 defined(getVarref($_)) &&
				   exists($genopt_types->{$_->{OPTTYPE}})}
			 @$usage_array)
      {
	my $varref  = getVarref($usghash);
	my $opttype = $usghash->{OPTTYPE};
	my $flag    = getBestFlag($usghash);
	my $accepts = $usghash->{ACCEPTS};

	#The following types do not need to be checked or they cannot be checked
	#because either Getopt::Long handles them: bool,negbool,string.

	#We cannot check defaults that are set when we're supplied a CODE
	#reference because we don't have access to the variable in main that
	#keeps the value, but we can check the value supplied on the command
	#line if we were given a TYPE for: integer, float, count.

	#We should always check enum types.

	#Validate integers and floats which gave an anonymous subroutine to
	#getopt, but they supplied a type.  In these cases, the VARREF should be
	#a reference to a tracking variable that was set in a wrapping sub by
	#createOptRefs
	if($opttype eq 'integer')
	  {
	    if(ref($varref) ne 'SCALAR')
	      {
		error("Invalid integer reference [",ref($varref),
		      "] supplied to [$flag].",
		      {DETAIL => 'Should be a scalar reference.'});
		$status = 0;
	      }
	    elsif(defined($$varref) && !isInt($$varref))
	      {$status = 0}
	  }
	elsif($opttype eq 'count')
	  {
	    if(ref($varref) ne 'SCALAR')
	      {
		error("Invalid count reference [",ref($varref),
		      "] supplied to [$flag].",
		      {DETAIL => 'Should be a scalar reference.'});
		$status = 0;
	      }
	    elsif(defined($$varref) && !isInt($$varref))
	      {$status = 0}
	  }
	elsif($opttype eq 'float')
	  {
	    if(ref($varref) ne 'SCALAR')
	      {
		error("Invalid float reference [",ref($varref),
		      "] supplied to [$flag].",
		      {DETAIL => 'Should be a scalar reference.'});
		$status = 0;
	      }
	    elsif(defined($$varref) && !isFloat($$varref))
	      {$status = 0}
	  }
	elsif($opttype eq 'enum')
	  {
	    if(ref($varref) ne 'SCALAR')
	      {
		error("Invalid enum reference [",ref($varref),
		      "] supplied to [$flag].",
		      {DETAIL => 'Should be a scalar reference.'});
		$status = 0;
	      }
	    elsif(defined($$varref) && !validateEnum($$varref,$accepts,$flag))
	      {$status = 0}
	  }
	elsif(exists($array_genopt_types->{$opttype}))
	  {
	    if(ref($varref) ne 'ARRAY' ||
	       scalar(grep {ref($_) ne ''} @$varref))
	      {
		error("Invalid array [",
		      (ref($varref) eq 'ARRAY' ? 'ARRAY REF of ' .
		       join(',',map {ref($_) eq '' ?
				       'SCALAR' : ref($_) . ' REF'} @$varref) :
		       ref($varref)),"] supplied to [$flag].",
		      {DETAIL => ('Should be a reference to an ARRAY of ' .
				  'SCALARs.')});
		$status = 0;
	      }
	    else
	      {
		if($opttype eq 'float_array')
		  {
		    my $bads = [grep {!isFloat($_)} @$varref];
		    if(scalar(@$bads))
		      {
			error("Invalid float value(s) [",join(',',@$bads),
			      "] supplied to [$flag]",
			      ($usghash->{SUPPLIED} ? " (as parsed from this " .
			       "value supplied on the command line: [" .
			       join(' ',@{$usghash->{SUPPLIED_AS}}) . "])" :
			       ' (as set in the defaults)'),".");
			$status = 0;
		      }
		  }
		elsif($opttype eq 'integer_array')
		  {
		    my $bads = [grep {!isInt($_)} @$varref];
		    if(scalar(@$bads))
		      {
			error("Invalid integer value(s) [",join(',',@$bads),
			      "] supplied to [$flag]",
			      ($usghash->{SUPPLIED} ? " (as parsed from this " .
			       "value supplied on the command line: [" .
			       join(' ',@{$usghash->{SUPPLIED_AS}}) . "])" :
			       ' (as set in the defaults)'),".");
			$status = 0;
		      }
		  }
		elsif($opttype eq 'enum_array')
		  {
		    my $bads = [grep {!validateEnum($_,$accepts,$flag)}
				@$varref];
		    if(scalar(@$bads))
		      {
			error("Invalid enum value(s) [",join(',',@$bads),
			      "] supplied to [$flag]",
			      ($usghash->{SUPPLIED} ? " (as parsed from this " .
			       "value supplied on the command line: [" .
			       join(' ',@{$usghash->{SUPPLIED_AS}}) . "])" :
			       ' (as set in the defaults)'),".");
			$status = 0;
		      }
		  }
	      }
	  }
	elsif(exists($array2d_genopt_types->{$opttype}))
	  {
	    if(ref($varref) ne 'ARRAY' ||
	       scalar(grep {my $ar=$_;
			    (defined($ar) && ref($ar) ne 'ARRAY') ||
			      (defined($ar) &&
			       scalar(grep {defined($_) &&
					      ref($_) ne ''} @$ar))} @$varref))
	      {
		error("Invalid 2D array [",
		      (ref($varref) eq 'ARRAY' ?
		       'ARRAY REF of ' .
		       join(';',
			    map {my $ar=$_;
				 ref($ar) eq 'ARRAY' ?
				   'ARRAY REF of ' .
				     join(',',
					  map {ref($_) eq '' ?
						 'SCALAR' : ref($_) . ' REF'}
					  @$ar) :
					    (ref($ar) eq '' ?
					     'SCALAR' : ref($ar) . ' REF')}
			    @$varref) :
		       (ref($varref) eq '' ?
			'SCALAR' : ref($varref) . ' REF')),
		      "] supplied to [$flag].",
		      {DETAIL => ('Should be an ARRAY REF of ARRAY REFs of ' .
				  'SCALARs.')});
		$status = 0;
	      }
	    else
	      {
		if($opttype eq 'integer_array2d')
		  {
		    if(scalar(grep {!isInt($_)}
			      map {my $ar=$_;grep {defined($_)} @$ar}
			      grep {my $ar=$_;defined($ar) &&
				      scalar(grep {defined($_)} @$ar)}
			      @$varref))
		      {
			my $bads = [grep {!isInt($_)}
				    map {my $ar=$_;grep {defined($_)} @$ar}
				    grep {my $ar=$_;defined($ar) &&
					    scalar(grep {defined($_)} @$ar)}
				    @$varref];
			error("Invalid integer value(s) [",join(',',@$bads),
			      "] supplied to [$flag]",
			      ($usghash->{SUPPLIED} ? " (as parsed from this " .
			       "value supplied on the command line: [" .
			       join(' ',@{$usghash->{SUPPLIED_AS}}) . "])" :
			       ' (as set in the defaults)'),".");
			$status = 0;
		      }
		  }
		elsif($opttype eq 'float_array2d')
		  {
		    if(scalar(grep {!isFloat($_)}
			      map {my $ar=$_;grep {defined($_)} @$ar}
			      grep {my $ar=$_;defined($ar) &&
				      scalar(grep {defined($_)} @$ar)}
			      @$varref))
		      {
			my $bads = [grep {!isInt($_)}
				    map {my $ar=$_;grep {defined($_)} @$ar}
				    grep {my $ar=$_;defined($ar) &&
					    scalar(grep {defined($_)} @$ar)}
				    @$varref];
			error("Invalid integer value(s) [",join(',',@$bads),
			      "] supplied to [$flag]",
			      ($usghash->{SUPPLIED} ? " (as parsed from this " .
			       "value supplied on the command line: [" .
			       join(' ',@{$usghash->{SUPPLIED_AS}}) . "])" :
			       ' (as set in the defaults)'),".");
			$status = 0;
		      }
		  }
		elsif($opttype eq 'enum_array2d')
		  {
		    if(scalar(grep {!validateEnum($_,$accepts,$flag)}
			      map {my $ar=$_;grep {defined($_)} @$ar}
			      grep {my $ar=$_;defined($ar) &&
				      scalar(grep {defined($_)} @$ar)}
			      @$varref))
		      {
			my $bads = [grep {!validateEnum($_,$accepts,$flag)}
				    map {my $ar=$_;grep {defined($_)} @$ar}
				    grep {my $ar=$_;defined($ar) &&
					    scalar(grep {defined($_)} @$ar)}
			      @$varref];
			error("Invalid enum value(s) [",join(',',@$bads),
			      "] supplied to [$flag]",
			      ($usghash->{SUPPLIED} ? " (as parsed from this " .
			       "value supplied on the command line: [" .
			       join(' ',@{$usghash->{SUPPLIED_AS}}) . "])" :
			       ' (as set in the defaults)'),".");
			$status = 0;
		      }
		  }
	      }
	  }
      }

    verbose({LEVEL => 3},"All supplied values validated.") if($status);

    return($status);
  }

#The value supplied must be as it occurs on the command line for a single flag
#undefs = ok, i.e. returns true
sub isValueValid
  {
    my $value    = $_[0]; #undef, scalar, or array ref
    my $usg_hash = $_[1];
    my $flag     = getBestFlag($usg_hash);
    my @er       = ();
    my $is       = 1;

    if($flag !~ /^-/)
      {$flag = (length($flag) > 1 ? '--' : '-') . $flag}

    if($usg_hash->{OPTTYPE} eq 'string'       ||
       $usg_hash->{OPTTYPE} eq 'bool'         ||
       $usg_hash->{OPTTYPE} eq 'negbool'      ||
       $usg_hash->{OPTTYPE} eq 'string_array' ||
       $usg_hash->{OPTTYPE} eq 'string_array2d')
      {
	$is = !defined($value) || ref($value) eq '';
	if(!$is)
	  {@er = ("Invalid reference [",ref($value),"] supplied to [$flag].",
                  {DETAIL => "Must be a scalar value (not a reference)."});}
      }
    elsif($usg_hash->{OPTTYPE} eq 'integer' || $usg_hash->{OPTTYPE} eq 'count')
      {
	$is = !defined($value) || isInt($value);
	if(!$is)
	  {@er = ("Invalid value [$value] supplied to [$flag].",
                  {DETAIL => "Must be an integer."});}
      }
    elsif($usg_hash->{OPTTYPE} eq 'float')
      {
	$is = !defined($value) || isFloat($value);
	if(!$is)
	  {@er = ("Invalid value [",ref($value),"] supplied to [$flag].",
                  {DETAIL => "Must be an real number, e.g. -1.0."})}
      }
    elsif($usg_hash->{OPTTYPE} eq 'enum')
      {
        $is = !defined($value) || isEnum($value,$usg_hash->{ACCEPTS});
        if(!$is)
          {@er = ('Invalid ',
                  ($command_line_stage >= DEFAULTED ? '' : 'user default '),
                  "value [$value] supplied to [$flag].  Must be one of: [",
                  (defined($usg_hash->{ACCEPTS}) ?
                   join(',',@{$usg_hash->{ACCEPTS}}) : ''),"].")}
      }
    elsif($usg_hash->{OPTTYPE} =~ /array/)
      {
	my @values = ();
	if(defined($usg_hash->{DELIMITER}))
	  {push(@values,split(/$usg_hash->{DELIMITER}/,$value))}
	else
	  {push(@values,$value)}

        $is           = 1;
	my $unhandled = {};
	my $bad_vals  = [];
	my $mustbe    = ($usg_hash->{OPTTYPE} =~ /integer/ ? 'an integer' :
			 ($usg_hash->{OPTTYPE} =~ /float/ ? 'a real number' :
			  ($usg_hash->{OPTTYPE} =~ /enum/ ? 'one of: [' .
                           (defined($usg_hash->{ACCEPTS}) ?
                            join(',',@{$usg_hash->{ACCEPTS}}) : '') . "]" :
                           '')));
	foreach my $item_value (@values)
	  {
	    if($usg_hash->{OPTTYPE} eq 'integer_array' ||
	       $usg_hash->{OPTTYPE} eq 'integer_array2d')
	      {if(defined($item_value) && !isInt($item_value))
		 {push(@$bad_vals,$item_value)}}
	    elsif($usg_hash->{OPTTYPE} eq 'float_array' ||
		  $usg_hash->{OPTTYPE} eq 'float_array2d')
	      {if(defined($item_value) && !isFloat($item_value))
		 {push(@$bad_vals,$item_value)}}
	    elsif($usg_hash->{OPTTYPE} eq 'enum_array' ||
		  $usg_hash->{OPTTYPE} eq 'enum_array2d')
	      {if(defined($item_value) && !isEnum($item_value,
                                                  $usg_hash->{ACCEPTS}))
		 {push(@$bad_vals,$item_value)}}
	    else
	      {$unhandled->{$usg_hash->{OPTTYPE}} = 1}
	  }
	if(scalar(keys(%$unhandled)))
	  {
	    error("Unhandled option type(s): [",join(',',keys(%$unhandled)),
		  "].");
	    $is = 0;
	  }
	if(scalar(@$bad_vals) || (scalar(@values) == 0 && $value ne ''))
	  {
            #Make the error succinct if there's one value and its bad
	    if(scalar(@$bad_vals) == scalar(@values) && scalar(@$bad_vals) &&
               $bad_vals->[0] eq $value)
	      {@er = ('Invalid ',
                      ($command_line_stage >= DEFAULTED ? '' : 'user default '),
                      "value [$value] supplied to [$flag].",
                      {DETAIL => "Must be $mustbe."})}
	    else
	      {@er =
                 ('Invalid ',
                  ($command_line_stage >= DEFAULTED ? '' : 'user default '),
                  'value',(scalar(@$bad_vals) > 1 ? 's' : '')," [",
                  join(',',map {$_ eq '' ? "''" : $_} @$bad_vals),
                  "]" . (defined($usg_hash->{DELIMITER}) ?
                         " parsed from string [$value]" : '') .
                  " supplied to [$flag].",
                  {DETAIL => "Must be $mustbe.  " .
                   (defined($usg_hash->{DELIMITER}) ?
                    (defined($usg_hash->{DELIMITER}) ?
                     (length($usg_hash->{DELIMITER}) > 1 ?
                      "  Delimiter-pattern used: ($usg_hash->{DELIMITER})" :
                      "  Delimiter used: ($usg_hash->{DELIMITER})r") :
                     "  Non-number-delimiter pattern used") : '')})}

	    $is = 0;
	  }
      }
    elsif($usg_hash->{OPTTYPE} eq 'infile')
      {
	#We will not enforce that the files must exist here
	$is = 1;
      }
    elsif($usg_hash->{OPTTYPE} eq 'outfile' || $usg_hash->{OPTTYPE} eq 'stub' ||
	  $usg_hash->{OPTTYPE} eq 'logfile')
      {
	#Must be a valid file name and path must exist
	my $path = $value;
        if(defined($path))
          {$path =~ s/[^\/]*$//}
	$is = !defined($value) || $path eq '' || -e $path;
        if(!$is)
	  {@er = ("Invalid value [$value] supplied to [$flag].  Directory ",
                  "must (but does not) pre-exist.")}
      }
    elsif($usg_hash->{OPTTYPE} eq 'suffix' || $usg_hash->{OPTTYPE} eq 'logsuff')
      {
	#Must be valid for a file name
	#We will assume any values is an OK file name
	$is = 1;
      }
    elsif($usg_hash->{OPTTYPE} eq 'outdir')
      {
	#We will not enforce the outdir value here
	$is = 1;
      }
    else
      {
        $is = 0;
        error("Unhandled option type: [",
              (defined($usg_hash->{OPTTYPE}) ? $usg_hash->{OPTTYPE} : 'undef'),
              "].");
      }

    handleBadValueError(\@er,$usg_hash);

    return($is);
  }

sub handleBadValueError
  {
    my $er       = $_[0];
    my $usg_hash = $_[1];

    if(scalar(@$er))
      {
        if($command_line_stage >= DEFAULTED ||
           !areBadOptValsReplaced([$usg_hash]))
          {error(@$er)}
##TODO: Add a hash parameter to warning() to tell it to only warn when debug is true.  I will also have to change the behavior of sig_warn in loadUserDefaults for type errors handled by Getopt::Long.  Since $DEBUG hasn't been parsed from the command line yet, we can't just check that here to decide whether to issue the warning or not.
#        else
#          {warning(@$er,'  Ignoring since the value was replaced on the ',
#                   'command line.')}
      }
  }

#Returns true if value is undefined or (defined and is in the accepts array)
sub validateEnum
  {
    my $value   = $_[0];
    my $accepts = $_[1];
    my $flag    = $_[2]; #For error reporting
    my $status  = 1; #validated

    if(defined($accepts))
      {
	if(ref($accepts) ne 'ARRAY' || scalar(@$accepts) == 0)
	  {
	    error("Invalid or unsupplied ACCEPTS array supplied to ",
		  "[$flag].");
	    $status = 0;
	  }
	elsif(scalar(grep {$_ eq $value} @$accepts) == 0)
	  {
	    error("Invalid value [$value] supplied to [$flag].  Must be ",
		  "one of: [",join(',',@$accepts),"].");
	    $status = 0;
	  }
      }
    else
      {
	error("ACCEPTS array is required for TYPE enum for the ",
	      "option defined by [$flag].",
	      {DETAIL => ('Add a value for ACCEPTS to the call to ' .
			  "addOption() for [$flag].")});
	$status = 0;
      }

    return($status);
  }

sub isEnum
  {
    my $value   = $_[0];
    my $accepts = $_[1];
    my $status  = 1;

    if(defined($accepts))
      {
	if(ref($accepts) ne 'ARRAY' || scalar(@$accepts) == 0)
	  {
	    error("ACCEPTS must be an array reference.  [",
                  (ref($accepts) eq '' ?
                   'SCALAR' : ref($accepts) . ' reference'),"] supplied.");
	    $status = 0;
	  }
	elsif(scalar(grep {$_ eq $value} @$accepts) == 0)
	  {$status = 0}
      }
    else
      {
	error("ACCEPTS array reference is required.",{DETAIL => ('isEnum.')});
	$status = 0;
      }

    return($status);
  }

#Returns one of the following strings: bool,negbool,count,scalar,unk.
#Used by addToUsage and getSummaryOptStr
sub getGeneralOptType
  {
    my $get_opt_str = $_[0];
    if(!defined($get_opt_str) || $get_opt_str eq '')
      {return('unk')}
    elsif($get_opt_str =~ /\!$/)
      {return('negbool')}
    elsif($get_opt_str =~ /=i$/)
      {return('integer')}
    elsif($get_opt_str =~ /=f$/)
      {return('float')}
    elsif($get_opt_str =~ /=\S$/)
      {return('string')}
    elsif($get_opt_str =~ /\+$/)
      {return('count')}
    elsif($get_opt_str !~ /[:!\+=]/)
      {return('bool')}
    else
      {return('unk')}
  }

sub addArrayOption
  {
    my @in = getSubParams([qw(FLAG|GETOPTKEY VARREF|GETOPTVAL TYPE REQUIRED
			      DEFAULT HIDDEN SHORT_DESC|SMRY|SMRY_DESC
			      LONG_DESC|DETAIL|DETAIL_DESC DELIMITER ACCEPTS
			      FLAGLESS INTERPOLATE ADVANCED HEADING DISPDEF)],
			  [qw(FLAG|GETOPTKEY VARREF|GETOPTVAL)],
			  [@_]);
    my $get_opt_str = $in[0]; #e.g. 'o|suffix=s'
    my $get_opt_ref = $in[1]; #e.g. $my_option - A reference to an array
    my $type        = $in[2]; #e.g. [string],integer,float,enum
    my $required    = $in[3]; #Is option required?: 0=false, non-0=true
    my $default     = $in[4]; #e.g. '1'
    my $hidden      = $in[5]; #0 or non-0. non-0 requires a default.
                              #Excludes from usage output.
    my $smry_desc   = $in[6]; #e.g. Input file(s).  See --help for format.
                              #Empty/undefined = exclude from short usage
    my $detail_desc = $in[7]; #e.g. 'Input file(s).  Space separated,...'
    my $delimiter   = $in[8]; #Split what is supplied if defined. Defaults
                              #to non-number chars if type is integer or
                              #float, non-accepts chars if enum, and undef
                              #if string
    my $accepts     = $in[9]; #e.g. ['yes','no']
    my $flagless    = $in[10];#Whether the option can be supplied sans flag
    my $interpolate = $in[11];#For backward compatibility
    my $advanced    = $in[12];#Advanced options print when extended >= 2
    my $heading     = $in[13];#Section heading to print in extended usage
    my $display_def = $in[14];#The default to display in the usage

    #Trim leading & trailing hard returns and white space characters (from
    #using '<<')
    $smry_desc   =~ s/^\s+//s if(defined($smry_desc));
    $smry_desc   =~ s/\s+$//s if(defined($smry_desc));
    $detail_desc =~ s/^\s+//s if(defined($detail_desc));
    $detail_desc =~ s/\s+$//s if(defined($detail_desc));

    #Validate the accepts parameter
    if(defined($accepts) &&
       (ref($accepts) ne 'ARRAY' ||
	scalar(@$accepts) != scalar(grep {ref(\$_) eq 'SCALAR'} @$accepts)))
      {
	error("Invalid accepts value passed in.  Only a reference to an ",
	      "array of scalars is valid.  Received a reference to a",
	      (ref($accepts) eq 'ARRAY' ? 'n ARRAY of (' .
	       join(',',map {ref(\$_)} @$accepts) . ')' : ' ' . ref($accepts)),
	      "] instead.");
        $num_setup_errors++;
	return(undef);
      }

    #Validate or set the default of the type parameter
    if(defined($type) && $type ne 'string' && $type ne 'integer' &&
       $type ne 'float' && $type ne 'enum')
      {
	error("Invalid TYPE [$type].  Only string, integer, float, or enum ",
	      "are allowed.");
        $num_setup_errors++;
        return(undef);
      }
    elsif(!defined($type))
      {
	if(ref($get_opt_str)    eq '' && $get_opt_str =~ /=i$/)
	  {$type = 'integer'}
	elsif(ref($get_opt_str) eq '' && $get_opt_str =~ /=f$/)
	  {$type = 'float'}
	elsif(defined($accepts))
	  {$type = 'enum'}
	else
	  {$type = 'string'}
      }

    #Allow the flag to be an array of scalars and turn it into a get opt str
    my $save_getoptstr = $get_opt_str;
    $get_opt_str = makeGetOptKey($get_opt_str,$type,0,'addArrayOption');

    if(defined($get_opt_str))
      {$get_opt_str = fixStringOpt($get_opt_str,1)}
    else
      {
	$num_setup_errors++;
	return(undef);
      }

    if(!isGetOptStrValid($get_opt_str,'1darray',undef))
      {
        $num_setup_errors++;
        return(undef);
      }

    #Validate the type & accepts combo
    if($type eq 'enum' && (!defined($accepts) || scalar(@$accepts) == 0))
      {
	error("ACCEPTS is required if TYPE is enum.");
        $num_setup_errors++;
	return(undef);
      }
    elsif($type ne 'enum' && defined($accepts))
      {
	warning("ACCEPTS is ignored when TYPE is not enum.",
		{DETAIL => ('Remove the ACCEPTS parameter to eliminate this ' .
			    'warning.')});
	undef($accepts);
      }

    #Set the default delimiter based on the type
    if(!defined($delimiter))
      {
	if($type eq 'integer')
	  {$delimiter = '[^\d+\-eE]+'}
	elsif($type eq 'float')
	  {$delimiter = '[^\d+\-eE\.]+'}
	elsif($type eq 'enum')
	  {$delimiter = '[^' . join('',@$accepts) . ']+'}
	elsif(defined($interpolate) && $interpolate)
	  {$delimiter = '\s+'}
	#No default delimiter defined for type str
      }
    elsif(length($delimiter) == 1)
      {$delimiter = "$delimiter+"}
    elsif(length($delimiter) > 1)
      {$delimiter = "(?:$delimiter)+"}

    #Strip junk off the get opt str
    $get_opt_str =~ s/[=+:\@\%!].*//;
    #Make type a string so multiple vals can be parsed with a non-num delimiter
    $get_opt_str .= '=s';

    if($command_line_stage >= ARGSREAD)
      {
	error("You cannot add command line options (i.e. call ",
	      "addArrayOption()) after the command line has already ",
	      "been processed (i.e. processCommandLine()) without at ",
	      "least re-initializing (i.e. calling _init()).");
        $num_setup_errors++;
	return(undef);
      }

    if(defined($required) && $required !~ /^\d+$/)
      {error("Invalid REQUIRED parameter: [$required].")}

    my $flags = [getOptStrFlags($get_opt_str)];
    my $flag  = getDefaultFlag($flags);

    if($hidden && !defined($default) && defined($required) && $required)
      {
	warning("Cannot hide option [$flag] if no default provided and if it ",
		"is required.  Setting as not hidden.");
	$hidden = 0;
      }

    #If no detailed usage was provided for this option
    if(!defined($detail_desc) || $detail_desc eq '')
      {
	if(defined($smry_desc) && $smry_desc ne '')
	  {$detail_desc = $smry_desc}
	else
	  {$detail_desc = 'No detailed usage provided for this array option.'}
      }

    #If no summary usage was provided for this option
    if(!defined($smry_desc) || $smry_desc eq '')
      {
	if($required)
	  {$smry_desc = defined($detail_desc) ? $detail_desc :
             'No usage summary provided for this option.'}
	else
	  {$smry_desc = ''}
      }

    my $disp_delim = getDisplayDelimiter($delimiter,$type,$accepts);
    if(defined($disp_delim) && $disp_delim eq 'ERROR')
      {return(undef)}
    if(defined($disp_delim) && length($disp_delim) > 1)
      {$detail_desc .= "\n\nValues are delimited using this perl regular " .
	 "expression: [$disp_delim]."}

    my $name = createOptionNameFromFlags($flags);
    my $sub  = getGetoptSub($name,0);

    if(!defined($get_opt_ref) ||
       (ref($get_opt_ref) ne 'ARRAY' && ref($get_opt_ref) ne 'CODE'))
      {
	error("Invalid array variable.  The second parameter must be a ",
	      "reference to an array, but got ",
	      (defined($get_opt_ref) ? "a reference to [" . ref($get_opt_ref) :
	      '[undef'),"].");
        $num_setup_errors++;
        return(undef);
      }
    elsif(defined($get_opt_ref) && ref($get_opt_ref) eq 'ARRAY')
      {
	#If there's a default value in both the var ref and in the default param
	if(scalar(@$get_opt_ref) && defined($default) &&
	   !areArraysEqual($get_opt_ref,$default))
	  {
	    error("Multiple conflicting default values supplied.  Use either ",
		  "the DEFAULT parameter or initialize the VARREF parameter ",
		  "with an array, but do not supply both.",
		  {DETAIL =>
		   join('',('Only one must have a value or they must both be ',
			    'the same.  If you are trying to supply a value ',
			    'to display in the usage, use the DISPDEF ',
			    'parameter instead of the DEFAULT parameter.'))});
            $num_setup_errors++;
            return(undef);
	  }
	elsif(scalar(@$get_opt_ref))
	  {$default = [@$get_opt_ref]}
      }

    unless(isOptRefUnique($get_opt_ref,$flag))
      {
        $num_setup_errors++;
        return(undef);
      }

    my($real_def,$def_str);
    #If the default has a value, set the real and display defaults
    if(defined($default) && ref($default) eq 'ARRAY' &&
       scalar(grep {ref($_) ne ''} @$default) == 0)
      {
	$def_str  = join(',',map {defined($_) ? $_ : 'undef'} @$default);
	$real_def = [@$default];
      }
    elsif(defined($default) && ref($default) eq '')
      {
	$def_str  = $default;
	$real_def = [$default];
      }
    elsif(defined($default))
      {
	error("Default value supplied to addArrayOption must be a scalar or a ",
	      "reference to an array of scalars.");
        $num_setup_errors++;
        return(undef);
      }

    #If a display default was provided, overwrite the default based on the real
    #default value (or the value referenced in varref)
    if(defined($display_def))
      {
	#If it's a scalar
	if(ref($display_def) eq '')
	  {$def_str = $display_def}
	else
	  {error("Invalid display default.  Must be a non-empty string.  ",
		 "Ignoring.")}
      }

    if(defined($flagless) && $flagless)
      {
	if(defined($flagless_multival_optid) && $flagless_multival_optid > -1)
	  {
	    error("An additional multi-value option has been designated as ",
		  "'flagless': [$get_opt_str]: [$flagless].  Only 1 is ",
		  "allowed.",
		  {DETAIL => "First flagless option was: [" .
		   getDefaultFlag($usage_array->[$flagless_multival_optid]
				  ->{OPTFLAGS}) . "]."});
            $num_setup_errors++;
	    return(undef);
	  }

	$GetOptHash->{'<>'} = getGetoptSub($name,1);

	#This assumes that the call to addToUsage a few lines below is the
	#immediate next call to addToUsage
	$flagless_multival_optid = getNextUsageIndex();
      }

    my $option_id = addOption($get_opt_str,
			      $sub,
			      $type . '_array',
			      $required,
			      $def_str,
			      $hidden,
			      $smry_desc,
			      $detail_desc,
			      $accepts,
			      $advanced,
			      $heading,
			      $real_def,
			      undef,         #name
			      undef,         #order
			      $get_opt_ref,
			      $delimiter,
			      $flagless);

    #The internal sub was given to GOL in addOption, but we need to replace the
    #programmer's VARREF so it doesn't call itself in a loop
    $usage_array->[$option_id]->{VARREF_PRG} = $get_opt_ref;

    return($option_id);
  }

#Checks to make sure the programmer hasn't accidentally supplied the same
#variable to 2 different options
#Globals used: $unique_refs_hash
sub isOptRefUnique
  {
    my $get_opt_ref = $_[0];
    my $new_flag    = $_[1];
    my $uniq        = !exists($unique_refs_hash->{$get_opt_ref});
    if($uniq)
      {$unique_refs_hash->{$get_opt_ref} = $new_flag}
    else
      {error("Same reference passed for options: ",
	     "[$unique_refs_hash->{$get_opt_ref}] and [$new_flag].")}
    return($uniq);
  }

#Returns a single character that will work as a delimiter because it matches
#the regular expression the programmer supplied
sub getDisplayDelimiter
  {
    my $delim   = $_[0];
    my $type    = $_[1];
    my $accepts = $_[2];

    if(!defined($delim))
      {return(undef)}
    if($delim eq '')
      {return($delim)}

    my $dispdelims = [',', ';', ':', '|', '~', ' '];
    my $dispdelim  = $delim;

    if($type eq 'enum')
      {
	my $enumchars = join('',@$accepts);
	if($enumchars =~ /$delim/)
	  {
	    error("Delimiter [$delim] matches one or more of the characters ",
		  "in the enumeration values: [",join(' ',@$accepts),"].");
            $num_setup_errors++;
	    return('ERROR');
	  }

	if($delim =~ /^(.)\+$/)
	  {return($1)}

	foreach my $potentialdispdelim (@$dispdelims)
	  {
	    if($potentialdispdelim =~ /$delim/ &&
	       $enumchars !~ /\Q$potentialdispdelim\E/)
	      {
		$dispdelim = $potentialdispdelim;
		last;
	      }
	  }
      }
    else
      {
	if($delim =~ /^(.)\+$/)
	  {return($1)}

	foreach my $potentialdispdelim (@$dispdelims)
	  {
	    if($potentialdispdelim =~ /$delim/)
	      {
		$dispdelim = $potentialdispdelim;
		last;
	      }
	  }
      }

    return($dispdelim);
  }

sub add2DArrayOption
  {
    my @in = getSubParams([qw(FLAG|GETOPTKEY VARREF|GETOPTVAL TYPE REQUIRED
			      DEFAULT HIDDEN SHORT_DESC|SMRY|SMRY_DESC
			      LONG_DESC|DETAIL|DETAIL_DESC ACCEPTS FLAGLESS
			      DELIMITER ADVANCED HEADING DISPDEF)],
			  [qw(FLAG|GETOPTKEY VARREF|GETOPTVAL)],
			  [@_]);
    my $get_opt_str = $in[0]; #e.g. 'o|suffix=s'
    my $get_opt_ref = $in[1]; #e.g. $my_option - A reference to an array
    my $type        = $in[2]; #e.g. [string],integer,float,enum
    my $required    = $in[3]; #Is option required?: 0=false, non-0=true
    my $default     = $in[4]; #e.g. '1'
    my $hidden      = $in[5]; #0 or non-0. non-0 requires a default.
                              #Excludes from usage output.
    my $smry_desc   = $in[6]; #e.g. Input file(s).  See --help for format.
                              #Empty/undefined = exclude from short usage
    my $detail_desc = $in[7]; #e.g. 'Input file(s).  Space separated,...'
    my $accepts     = $in[8]; #e.g. ['yes','no']
    my $flagless    = $in[9]; #Whether the option can be supplied sans flag
    my $delimiter   = $in[10];#Split what is supplied if defined. Defaults
                              #to non-number chars if type is integer or
                              #float, non-accepts chars if enum, and space
                              #if string
    my $advanced    = $in[11];#Advanced options print when extended >= 2
    my $heading     = $in[12];#Section heading to print in extended usage
    my $display_def = $in[13];#The default to display in the usage

    #Trim leading & trailing hard returns and white space characters (from
    #using '<<')
    $smry_desc   =~ s/^\s+//s if(defined($smry_desc));
    $smry_desc   =~ s/\s+$//s if(defined($smry_desc));
    $detail_desc =~ s/^\s+//s if(defined($detail_desc));
    $detail_desc =~ s/\s+$//s if(defined($detail_desc));

    #Validate the accepts parameter
    if(defined($accepts) &&
       (ref($accepts) ne 'ARRAY' ||
	scalar(@$accepts) != scalar(grep {ref(\$_) eq 'SCALAR'} @$accepts)))
      {
	error("Invalid accepts value passed in.  Only a reference to an ",
	      "array of scalars is valid.  Received a reference to a",
	      (ref($accepts) eq 'ARRAY' ? 'n ARRAY of (' .
	       join(',',map {ref(\$_)} @$accepts) . ')' : ' ' . ref($accepts)),
	      "] instead.");
        $num_setup_errors++;
	return(undef);
      }

    #Validate or set the default of the type parameter
    if(defined($type) && $type ne 'string' && $type ne 'integer' &&
       $type ne 'float' && $type ne 'enum')
      {
	error("Invalid TYPE [$type].  Only string, integer, float, or enum ",
	      "are allowed.");
        $num_setup_errors++;
	return(undef);
      }
    elsif(!defined($type))
      {
	if(ref($get_opt_str)    eq '' && $get_opt_str =~ /=i$/)
	  {$type = 'integer'}
	elsif(ref($get_opt_str) eq '' && $get_opt_str =~ /=f$/)
	  {$type = 'float'}
	elsif(defined($accepts))
	  {$type = 'enum'}
	else
	  {$type = 'string'}
      }

    #Allow the flag to be an array of scalars and turn it into a get opt str
    my $save_getoptstr = $get_opt_str;
    $get_opt_str = makeGetOptKey($get_opt_str,$type,0,'add2DArrayOption');

    if(!defined($get_opt_str))
      {
	$num_setup_errors++;
	return(undef);
      }

    #Validate the type & accepts combo
    if($type eq 'enum' && (!defined($accepts) || scalar(@$accepts) == 0))
      {
	error("ACCEPTS is required if TYPE is enum.");
        $num_setup_errors++;
	return(undef);
      }
    elsif($type ne 'enum' && defined($accepts))
      {
	warning("ACCEPTS is ignored when TYPE is not enum.",
		{DETAIL => ('Remove the ACCEPTS parameter to eliminate this ' .
			    'warning.')});
	undef($accepts);
      }

    #Set the default delimiter based on the type
    if(!defined($delimiter))
      {
	if($type eq 'integer')
	  {$delimiter = '[^\d+\-eE]+'}
	elsif($type eq 'float')
	  {$delimiter = '[^\d+\-eE\.]+'}
	elsif($type eq 'enum')
	  {$delimiter = '[^' . join('',@$accepts) . ']+'}
	else
	  {$delimiter = '\s+'}
      }
    elsif(length($delimiter) == 1)
      {$delimiter = "$delimiter+"}
    elsif(length($delimiter) > 1)
      {$delimiter = "(?:$delimiter)+"}

    if(defined($get_opt_str))
      {
	#Strip junk off the get opt str
	$get_opt_str =~ s/[=+:\@\%!].*//;
	#Make type a string so multiple vals can be parsed with a non-num
	#delimiter
	$get_opt_str .= '=s';
      }

    if($command_line_stage >= ARGSREAD)
      {
	error("You cannot add command line options (i.e. call ",
	      "add2DArrayOption()) after the command line has already ",
	      "been processed (i.e. processCommandLine()) without at ",
	      "least re-initializing (i.e. calling _init()).");
        $num_setup_errors++;
	return(undef);
      }

    if(defined($required) && $required !~ /^\d+$/)
      {error("Invalid REQUIRED parameter: [$required].")}

    $get_opt_str = fixStringOpt($get_opt_str,1);

    if(!isGetOptStrValid($get_opt_str,'2darray',undef))
      {
        $num_setup_errors++;
	return(undef);
      }

    my $flags = [getOptStrFlags($get_opt_str)];
    my $flag  = getDefaultFlag($flags);

    if($hidden && !defined($default) && defined($required) && $required)
      {
	warning("Cannot hide option [$flag] if no default provided and if it ",
		"is required.  Setting as not hidden.");
	$hidden = 0;
      }

    #If no detailed usage was provided for this option
    if(!defined($detail_desc) || $detail_desc eq '')
      {
	if(defined($smry_desc) && $smry_desc ne '')
	  {$detail_desc = $smry_desc}
	else
	  {$detail_desc = 'No detailed usage provided for this 2D array ' .
	     'option.'}
      }

    #If no summary usage was provided for this option
    if(!defined($smry_desc) || $smry_desc eq '')
      {
	#If it's a required option, add a default summary
	if($required)
	  {$smry_desc = defined($detail_desc) ? $detail_desc :
             'No usage summary provided for this option.'}
	else
	  {$smry_desc = ''}
      }

    my $disp_delim = getDisplayDelimiter($delimiter,$type,$accepts);
    if(defined($disp_delim) && $disp_delim eq 'ERROR')
      {return(undef)}
    if(defined($disp_delim) && length($disp_delim) > 1)
      {$detail_desc .= "\n\nInner array elements are delimited from the " .
	 "value given to a single flag using this perl regular expression: " .
	   "[$disp_delim]."}

    my($sub,$varref_copy);
    my $name = createOptionNameFromFlags($flags);
    $sub = getGetoptSub($name,0);
    $varref_copy = [];

    if(!defined($get_opt_ref) ||
       (ref($get_opt_ref) ne 'ARRAY' && ref($get_opt_ref) ne 'CODE') ||
       (ref($get_opt_ref) eq 'ARRAY' && scalar(@$get_opt_ref) != 0 &&
	!isTwoDArray($get_opt_ref)))
      {
	error("Invalid array variable.  The second option must be a ",
	      "reference to an array which was initialized before calling ",
	      "this method.");
        $num_setup_errors++;
	return(undef);
      }

    unless(isOptRefUnique($get_opt_ref,$flag))
      {
        $num_setup_errors++;
	return(undef);
      }

    #If there's a default value in both the var ref and in the default param
    if(ref($get_opt_ref) eq 'ARRAY' && defined($get_opt_ref) &&
       scalar(@$get_opt_ref) && defined($default) &&
       !areArraysEqual($get_opt_ref,$default))
      {
	error("Multiple conflicting default values supplied.  Use either the ",
	      "DEFAULT parameter or initialize the VARREF parameter with an ",
	      "array, but do not supply both.",
	      {DETAIL =>
	       join('',('Only one must have a value or they must both be ',
			'the same.  If you are trying to supply a value ',
			'to display in the usage, use the DISPDEF ',
			'parameter instead of the DEFAULT parameter.'))});
        $num_setup_errors++;
	return(undef);
      }
    elsif(ref($get_opt_ref) eq 'ARRAY' && scalar(@$get_opt_ref) &&
	  (!defined($default) || scalar(@$default) == 0))
      {$default = copyArray($get_opt_ref)}

    my($real_def,$def_str);
    #If the default has a value, set the real and display defaults
    if(defined($default) && ref($default) eq 'ARRAY' &&
       scalar(grep {ref($_) ne 'ARRAY'} @$default) == 0 &&
       scalar(grep {my $a=$_;scalar(grep {ref($_) ne ''} @$a)} @$default) == 0)
      {
	$def_str = '(' .
	  join('),(',map {my $a = $_;
			  join(',',map {defined($_) ? $_ : 'undef'} @$a)}
	       @$default) . ')';
	$real_def = [map {defined($_) ? [@$_] : undef} @$default];
      }
    elsif(defined($default) && ref($default) eq 'ARRAY' &&
	  scalar(grep {ref($_) ne ''} @$default) == 0)
      {
	$def_str  = join(',',map {defined($_) ? $_ : 'undef'} @$default);
	$real_def = [[@$default]];
      }
    elsif(defined($default) && ref($default) eq '')
      {
	$def_str  = $default;
	$real_def = [[$default]];
      }
    elsif(defined($default))
      {
	error("Default value supplied to addArrayOption must be a scalar, a ",
	      "reference to an array of scalars, or a reference to an array ",
	      "of references to arrays of scalars.");
        $num_setup_errors++;
	return(undef);
      }

    #If a display default was provided, overwrite the default based on the real
    #default value (or the value referenced in varref)
    if(defined($display_def))
      {
	#If it's a scalar
	if(ref($display_def) eq '')
	  {$def_str = $display_def}
	else
	  {error("Invalid display default.  Must be a non-empty string.  ",
		 "Ignoring.")}
      }

    if(defined($flagless) && $flagless)
      {
	if(defined($flagless_multival_optid) && $flagless_multival_optid > -1)
	  {
	    error("An additional multi-value option has been designated as ",
		  "'flagless': [$get_opt_str]: [$flagless].  Only 1 is ",
		  "allowed.",
		  {DETAIL => "First flagless option was: [" .
		   getDefaultFlag($usage_array->[$flagless_multival_optid]
				  ->{OPTFLAGS}) . "]."});
            $num_setup_errors++;
	    return(undef);
	  }

	$GetOptHash->{'<>'} = getGetoptSub($name,1);

	#This assumes that the call to addToUsage a few lines below is the
	#immediate next call to addToUsage
	$flagless_multival_optid = getNextUsageIndex();
      }

    my $option_id = addOption($get_opt_str,
			      $sub,
			      $type . '_array2d',
			      $required,
			      $def_str,
			      $hidden,
			      $smry_desc,
			      $detail_desc,
			      $accepts,
			      $advanced,
			      $heading,
			      $real_def,
			      undef,         #name
			      undef,         #order
			      $varref_copy,
			      $delimiter,
			      $flagless);

    #The above sets the VARREF_PRG in the usage to the sub we created.  It needs
    #to be fixed to be the reference that was submitted by the programmer.
    $usage_array->[$option_id]->{VARREF_PRG} = $get_opt_ref;

    return($option_id);
  }

sub isRequiredGeneralOptionSatisfied
  {
    my $usg_hash         = $_[0];
    my $by_defaults_only = (defined($_[1]) ? $_[1] : 0);

    my $varref  = getVarref($usg_hash,0,1);
    my $flags   = $usg_hash->{OPTFLAGS};
    my $def     = (defined($usg_hash->{DEFAULT_USR}) ?
		   $usg_hash->{DEFAULT_USR} : $usg_hash->{DEFAULT_PRG});
    my $dispdef = $usg_hash->{DISPDEF};

    #If the display default is set and the default is not set, it means that the
    #programmer is going to handle the default themselves after options are
    #parsed, so we will ignore such required options and trust that the
    #programmer will handle it in main
    if(defined($dispdef) && !defined($def))
      {
	debug("Not requiring option: $flags->[0] because DISPDEF provided and ",
	      "DEFAULT not provided.");
	return(1);
      }

    #Sanity check - make sure the reference is defined
    if(!$by_defaults_only && !defined($varref))
      {return(0)}

    #Note, these are best guesses.  For example, if the option takes an
    #array, and it's intended to be a 2D array and an empty inner
    #array is added to start, this would think values have been
    #supplied when essentially they haven't.  I should more
    #intelligently handle defaults for all types instead of just
    #default strings for usage display (e.g. 'none' for no default).
    #TODO: See req 214

    if(ref($varref) eq 'SCALAR')
      {return((!$by_defaults_only && defined($$varref)) || defined($def))}
    elsif(ref($varref) eq 'ARRAY')
      {return((!$by_defaults_only && scalar(@$varref)) ||
	      (defined($def) && scalar(@$def)))}
    elsif(ref($varref) eq 'HASH')
      {return((!$by_defaults_only && scalar(%$varref)) ||
	      (defined($def) && scalar(%$def)))}
    elsif(ref($varref) ne 'SCALAR' && ref($varref) ne 'ARRAY' &&
	  ref($varref) ne 'HASH')
      {
	#We're going to trust that if the user supplied a default string, they
	#are handling the default after-the-fact themselves
	if(defined($def))
	  {return(1)}

	if(!$by_defaults_only && !$usg_hash->{SUPPLIED})
	  {return(0)}
      }

    return(1);
  }

#Determines whether multi-dimensional arrays of scalars are the same
sub areArraysEqual
  {
    my $a1 = $_[0];
    my $a2 = $_[1];

    if(ref($a1) eq ref($a2))
      {
	if(ref($a1) eq 'ARRAY')
	  {
	    if(scalar(@$a1) != scalar(@$a2))
	      {return(0)}
	    foreach(0..$#{$a1})
	      {unless(areArraysEqual($a1->[$_],$a2->[$_]))
		 {return(0)}}
	    return(1);
	  }
	elsif(ref($a1) eq '')
	  {if($a1 eq $a2)
	     {return(1)}}
	else
	  {warning("Not an array of scalars.")}
      }

    return(0);
  }

sub addOptions
  {
    my @in = getSubParams([qw(GETOPTHASH REQUIRED OVERWRITE RENAME ADVANCED
                              HEADING)],
			  [qw(GETOPTHASH)],
			  [@_]);
    my $getopthash = $in[0];
    my $required   = $in[1]; #Are all these opts required?: 0=false, non-0=true
                             #Call once for all required opts & once for others
    my $commandeer = $in[2]; #Deactivate a default option that you wish to
                             #handle yourself. If a key in the getopthash
                             #matches a pre-existing key, delete and overwrite
                             #it. The associated code will run or not run based
                             #on the built-in default value.
    my $rename     = $in[3]; #0=false, >0=true, <0=ignore. If the reference to
                             #the variable already exists as a value in the
                             #getopts hash, delete and remake the key-value
                             #pair using the existing key.
    my $advanced   = $in[4]; #Advanced options print when extended >= 2
    my $heading    = $in[5]; #Section heading to print in extended usage

    my $usage_indexes = [];

    if($command_line_stage >= ARGSREAD)
      {
	error("You cannot add command line options (i.e. call ",
	      "addOptions()) after the command line has already ",
	      "been processed (i.e. processCommandLine()) without at ",
	      "least re-initializing (i.e. calling _init()).");
	return(undef);
      }

    if(!defined($getopthash) || ref($getopthash) ne 'HASH')
      {
	error("Required first parameters (GETOPTHASH) must be a reference to ",
	      "a HASH, but [",
	      (defined($getopthash) ?
	       (ref($getopthash) eq '' ?
		'a non-reference' :
		'a reference to a [' . ref($getopthash) . ']') :
	       'an undefined value'),"] was sent in.");
        $num_setup_errors++;
        return(undef);
      }

    if(defined($required) && $required !~ /^\d+$/)
      {error("Invalid REQUIRED parameter: [$required].")}

    foreach my $get_opt_str (keys(%$getopthash))
      {
	if(!isGetOptStrValid($get_opt_str,'general',undef))
	  {
            $num_setup_errors++;
            return(undef);
	  }

	if((!defined($commandeer) || !$commandeer) &&
	   exists($GetOptHash->{$get_opt_str}))
	  {
	    error("Option [$get_opt_str] is a built-in option.  Supply ",
		  "OVERWRITE as true to supply your own functionality.  ",
		  "Note to also set the built-in function's default to ",
		  "deactivate it.");
	    next;
	  }
	if($get_opt_str eq '<>')
	  {
	    warning('Conversion of flagless option not supported.');
	    next;
	  }

	my $delkeys = [grep {$GetOptHash->{$_} eq $getopthash->{$get_opt_str}}
		       keys(%$GetOptHash)];
	if(scalar(@$delkeys))
	  {
	    if(defined($rename) && $rename > 0)
	      {delete($GetOptHash->{$delkeys->[$_]}) foreach(@$delkeys)}
	    elsif(!defined($rename) || $rename == 0)
	      {
		error("These options [",join(', ',@$delkeys),"] point to the ",
		      "same variable reference as new option ",
		      "[$get_opt_str].  Set \$rename to either ignore (and ",
		      "allow multiple options to control the same variable) ",
		      "or to replace the option name.");
		next;
	      }
	  }

	my $genopttype = getGeneralOptType($get_opt_str);
	my $flags      = [getOptStrFlags($get_opt_str)];
	my $name       = createOptionNameFromFlags($flags);

	$GetOptHash->{$get_opt_str} = getGetoptSub($name);

	#Let's do what we can...
	my $dispdef = getDefaultStr($getopthash->{$get_opt_str});
	my $default = copyVar(${$getopthash->{$get_opt_str}});
	if(ref($default) eq 'SCALAR')
	  {$default = $$default}
	my $desc    = ('No description supplied.  Programmer note: Use ' .
		       'addOption() instead of addOptions(), or use ' .
		       'addToUsage() to supply a usage.');

	my $oid = addToUsage($get_opt_str,
                             $flags,
                             undef,                           #SMRY_DESC
                             $desc,
                             $required,
                             $dispdef,
                             $default,
                             undef,                           #ACCEPTS
                             0,                               #HIDDEN
                             $genopttype,
                             ($get_opt_str eq '<>'),          #FLAGLESS
                             $advanced,
                             $heading,
                             $name,                           #usage name
                             undef,                           #usage order
                             $getopthash->{$get_opt_str},     #Programmer's ref
                             undef,                           #pair w option ID
                             undef);                          #pair relationship

	$heading = '';

        if(!defined($oid))
          {$num_setup_errors++}
        else
          {push(@$usage_indexes,$oid)}
      }

    return(wantarray ? @$usage_indexes : $usage_indexes);
  }

#This creates a subroutine to give as the hash value for an option in the
#GetOptHash
sub getGetoptSub
  {
    my $option_name = $_[0];
    my $flagless    = (defined($_[1]) ? $_[1] : 0);
    #We're only going to set a reference to a sub now because there is no usage
    #hash yet.  When the returned sub is called, it will have been set
    return(sub {getoptSubHelper([@_],
				eval("qq($option_name)"),
				eval("$flagless"))});
  }

#Globals used: $command_line_stage
sub getoptSubHelper
  {
    my $arg_array  = $_[0];
    my $opt_name   = $_[1];
    my $flagless   = $_[2];
    my $usg_hash   = getUsageHash($opt_name);
    my $type       = $usg_hash->{OPTTYPE};
    my $varref_stg = $usg_hash->{VARREF_STG};
    my $varref_prg = $usg_hash->{VARREF_PRG};
    my $delim      = $usg_hash->{DELIMITER};
    my $arg_value  = ($flagless ? $arg_array->[0] : $arg_array->[1]);
    my $arg_name   = ($flagless ? $opt_name : $arg_array->[0]);

    my $value      = $arg_value;
    my(@values); #For array types

    if(!defined($getopt_default_mode))
      {
        #Must be set to know whether to initialize defaults or option variables
	error("getopt_default_mode not defined.");
	return();
      }

    if(!$getopt_default_mode)
      {
	#Set the fact that this option is user supplied
	$usg_hash->{SUPPLIED}    = 1;
	$usg_hash->{OPTFLAG_SUP} = ($flagless ? '' :
				    (length($arg_name) > 1 ? '--' : '-') .
				    $arg_name);
	push(@{$usg_hash->{SUPPLIED_AS}},
	     ($flagless ?
	      "'$arg_value'" : "$usg_hash->{OPTFLAG_SUP} '$arg_value'"));
	push(@{$usg_hash->{SUPPLIED_ARGS}},$arg_array);
      }
    else
      {
	#Set the fact that this option is user-default supplied
	$usg_hash->{SUPPLIED_UDF}    = 1;
	$usg_hash->{OPTFLAG_SUP_UDF} = ($flagless ? '' :
					(length($arg_array->[0]) > 1 ?
					 '--' : '-') . $arg_name);
	push(@{$usg_hash->{SUPPLIED_AS_UDF}},
	     ($flagless ?
	      "'$arg_value'" : "$usg_hash->{OPTFLAG_SUP_UDF} '$arg_value'"));
	push(@{$usg_hash->{SUPPLIED_ARGS_UDF}},$arg_array);
      }

    #Validate the value
    if(!isValueValid($arg_value,$usg_hash))
      {
	#If we're processing user defaults
	if($getopt_default_mode)
	  {push(@$bad_user_opts,$usg_hash)}
	return();
      }

    ##
    ## Determine the value to be set if it's not a single scalar
    ##

    #We need to pre-process count-type options
    if($type eq 'count')
      {
	#This reaches into Getopt::Long::CallBack's object to tell whether or
	#not an argument was supplied with the flag.  It is based on this test
	#code/proof of concept:
	#perl -e 'use Getopt::Long;%h=("t|test:+" => sub {print(join(",",
	#@{$_[0]->{ctl}})," [",join("],[",@_),"]\n")});GetOptions(%h);' -- -t 5
	#-t 1 -t --test 6
	#I,t,,0,0,1 [t],[5]
	#I,t,,0,0,1 [t],[1]
	#+,t,,0,0,1 [t],[1]
	#I,t,,0,0,1 [t],[6]
	my $has_arg = ($arg_array->[0]->{ctl}->[0] ne '+');

	if(!$has_arg)
	  {
	    #We're either incrementing the value in $usg_hash->{DEFAULT_USR} or
	    #in $$varref_stg, unless they're not defined, then we're setting it.
            if($getopt_default_mode)
	      {
		if(defined($usg_hash->{DEFAULT_USR}))
		  {$value = $usg_hash->{DEFAULT_USR} + $arg_value}
		else
		  {$value = $arg_value}
	      }
	    else
	      {
		if(defined($$varref_stg))
		  {$value = $$varref_stg + $arg_value}
		else
		  {$value = $arg_value}
	      }
	  }
	else
	  {$value = $arg_value}
      }
    elsif($type =~ /array$/)
      {@values = (defined($delim) ? split(/$delim/,$arg_value) : $arg_value)}
    elsif($type =~ /array2d$/)
      {$value = [split(/$delim/,$arg_value)]}
    elsif($type eq 'outdir' || $type eq 'infile' || $type eq 'outfile')
      {
	#If this is a flagless option, let's be extra careful about validation
	if($flagless)
	  {checkFileOpt($arg_value,1)}

	$value = [sglob($arg_value,$usg_hash->{SUPPLIED_UDF})];
      }

    #If we are not yet processing the actual command line, we are setting user
    #defaults
    if($getopt_default_mode)
      {
	if($type =~ /array$/)
	  {
	    if(defined($usg_hash->{DEFAULT_USR}))
	      {push(@{$usg_hash->{DEFAULT_USR}},@values)}
	    else
	      {$usg_hash->{DEFAULT_USR} = [@values]}

	    #In case the programmer has a display default, clear it
	    $usg_hash->{DISPDEF} = undef;
	  }
	elsif($type =~ /array2d$/ ||
	      $type eq 'outdir' || $type eq 'infile' || $type eq 'outfile')
	  {
	    if(defined($usg_hash->{DEFAULT_USR}))
	      {push(@{$usg_hash->{DEFAULT_USR}},$value)}
	    else
	      {$usg_hash->{DEFAULT_USR} = [$value]}

	    #In case the programmer has a display default, clear it
	    $usg_hash->{DISPDEF} = undef;
	  }
	else
	  {
	    #Ignore invalid user defaults with a warning.  save_args is
	    #simply never allowed to be defaulted.
	    if(scalar(grep {$usg_hash->{USAGE_NAME} eq $_} qw(save_args)))
	      {warning("Unallowed user default option encountered among the ",
		       "saved user defaults: [",
		       (length($arg_array->[0]) > 1 ? '--' : '-'),
		       "$arg_array->[0]].  Ignoring.")}
	    else
	      {
		$usg_hash->{DEFAULT_USR} = $value;

		#In case the programmer has a display default, clear it
		$usg_hash->{DISPDEF}     = undef;
	      }
	  }
      }
    #Otherwise, we must update the varref value and the variable in main (if we
    #were given a code reference)
    else
      {
	#Now set the variables based on type
	if($type =~ /array$/)
	  {
	    #The programmer's variable in main (via a CODE ref) won't be set
            #(and assume they handle clearing out their initial default value)
            #until after validation
	    if(ref($varref_prg) ne 'CODE' && $varref_prg ne $varref_stg)
	      {
		#If the copy is empty and the programmer's variable was
		#initialized with a default, clear it out so the user's values
		#can replace them
		if(defined($varref_stg)      && defined($varref_prg) &&
		   scalar(@$varref_stg) == 0 && scalar(@$varref_prg))
		  {@$varref_prg = ()}

		if(defined($varref_prg))
		  {push(@$varref_prg,@values)}
		else
		  {$varref_prg = [@values]}
	      }

	    #Push them onto the copy (if the push above didn't happen or it's
	    #not the same reference as the programmer's variable)
	    if(ref($varref_prg) eq 'CODE' || $varref_prg ne $varref_stg)
	      {
		if(defined($varref_stg))
		  {push(@$varref_stg,@values)}
		else
		  {$varref_stg = [@values]}
	      }
	  }
	#These are kept in 2D scalar arrays: *_array2d, infile, outfile, outdir
	elsif($type =~ /array2d$/ ||
	      $type eq 'outdir' || $type eq 'infile' || $type eq 'outfile')
	  {
	    #The programmer's variable in main (via a CODE ref) won't be set
            #(and assume they handle clearing out their initial default value)
            #until after validation
	    if(ref($varref_prg) ne 'CODE' && $varref_prg ne $varref_stg)
	      {
		#If the copy is empty and the programmer's variable was
		#initialized with a default, clear it out so the user's values
		#can replace them
		if(defined($varref_stg)      && defined($varref_prg) &&
		   scalar(@$varref_stg) == 0 && scalar(@$varref_prg))
		  {@$varref_prg = ()}

		if(defined($varref_prg))
		  {push(@$varref_prg,$value)}
		else
		  {$varref_prg = [$value]}
	      }

	    #Push them onto the copy (if the push above didn't happen or it's
	    #not the same reference as the programmer's variable)
	    if(ref($varref_prg) eq 'CODE' || $varref_prg ne $varref_stg)
	      {
		#Push them onto the copy (if it's not the same reference)
		if(defined($varref_stg))
		  {push(@$varref_stg,$value)}
		else
		  {$varref_stg = [$value]}
	      }
	  }
	else
	  {
	    $$varref_stg = $value;

	    #The programmer's variable in main (via a CODE ref) won't be set
            #(and assume they handle clearing out their initial default value)
            #until after validation
	    if(ref($varref_prg) ne 'CODE')
	      {$$varref_prg = $value}
	  }
      }
  }

sub getDefaultStr
  {
    my $ref = $_[0];
    my($str);

    if(ref($ref) eq 'SCALAR')
      {$str = $$ref}
    elsif(ref($ref) eq 'ARRAY' &&
	  scalar(@$ref) == scalar(grep {ref(\$_) eq 'SCALAR'} @$ref))
      {$str = join(',',@$ref)}
    elsif(ref($ref) eq 'HASH' && scalar(keys(%$ref)) ==
	  scalar(grep {ref(\$_) eq 'SCALAR'} values(%$ref)))
      {$str = join(',',map {"$_=$ref->{$_}"} keys(%$ref))}

    my $def_str = clipStr($str,30);

    return($def_str);
  }

sub copyVar
  {
    my $ref  = $_[0];
    my $copy = $ref;

    if(ref($ref) eq 'SCALAR')
      {$copy = \$$ref}
    elsif(ref($ref) eq 'ARRAY' &&
	  scalar(@$ref) == scalar(grep {ref(\$_) eq 'SCALAR'} @$ref))
      {$copy = [@$ref]}
    elsif(ref($ref) eq 'HASH' && scalar(keys(%$ref)) ==
	  scalar(grep {ref(\$_) eq 'SCALAR'} values(%$ref)))
      {$copy = {%$ref}}
    elsif(ref($ref) ne '')
      {warning("Unsupported variable type.  Unable to copy option value.  ",
	       "Default value will contain references to main.")}

    return($copy);
  }

#Truncates a string to a given length and adds an elipsis to indicate it was
#truncated (if the trim length is long enough)
sub clipStr
  {
    my $str = defined($_[0]) ? $_[0] : 'undef';
    my $len = $_[1];

    if(!defined($len) || $len < 1)
      {return($str)}

    my $elipsis = '...';

    if($len < 6)
      {$elipsis = ''}

    my $elen = length($elipsis);

    if(length($str) > $len)
      {$str = substr($str,0,($len-$elen)) . $elipsis}

    return($str);
  }

sub addToUsage
  {
    my $getoptkey     = $_[0];
    my $flags_array   = $_[1];
    my $smry_desc     = $_[2];
    my $detail_desc   = $_[3];
    my $required      = $_[4];
    my $display_def   = $_[5];
    my $default_val   = $_[6];
    my $accepts       = $_[7]; #Array of scalars
    my $hidden        = $_[8];
    my $opttype       = defined($_[9]) ? $_[9] : 'string';
    my $flagless      = $_[10];
    my $advanced      = $_[11];
    my $heading       = defined($_[12]) ? $_[12] : '';

    my $usage_name    = $_[13];
    my $usage_order   = $_[14];

    my $varref_prg    = $_[15];
    my $varref_cli    = (exists($scalaropt_types->{$opttype}) ? \my $v : []);
    my $varref_stg    = (exists($scalaropt_types->{$opttype}) ? \my $w : []);

    #Relationships to other options
    my $pair_with_opt = $_[16];
    my $pair_relat    = (defined($_[17]) ? $_[17] : '');

    #For 1D & 2D array options only
    my $delim         = $_[18];

    ##
    ## For in/out file types
    ##
    my $primary_prg   = $_[19];
    my $primary       = $primary_prg;
    my $format_desc   = $_[20];

    #For outfile types
    my $collide_mode  = $_[21];

    #For file types that take only 1 file and which the programmer can't't open,
    #e.g. logfile & logsuff, so an append mode can be set.  Otherwise, append
    #mode is controlled via calls to open
    my $append_mode   = $_[22];

    if(!defined($flags_array))
      {
	error("Flags array undefined.");
	return(0);
      }

    #Update the global flag_check_hash
    foreach(@$flags_array)
      {
        my $flag = $_;

        $flag_check_hash->{$flag} = 0;

        if($opttype eq 'negbool')
          {
            $flag =~ s/^-+//;
            $flag_check_hash->{"--no$flag"}  = 0;
            $flag_check_hash->{"--no-$flag"} = 0;
          }
      }

    #If the programmer did not explicitly set a primary state, set one based on
    #the option type
    if(!defined($primary_prg))
      {
	if($opttype eq 'infile')
	  {$primary = 0}
	elsif($opttype eq 'outfile' || $opttype eq 'suffix')
	  {$primary = 1}
	else
	  {$primary = 0}
      }

    my $def_flag = getDefaultFlag($flags_array);

    #To be backward compatible, convert a string to an array using comma delim
    if(ref($flags_array) ne 'ARRAY')
      {
	error("Invalid flags array passed in.",
	      {DETAIL => 'Must be a reference to an array of scalars'});
        $num_setup_errors++;
        return(undef);
      }

    if(defined($pair_with_opt) &&
       ($pair_with_opt !~ /^\d+$/ || $pair_with_opt > $#{$usage_array}))
      {
	error("Invalid paired option ID: [$pair_with_opt].",
	      {DETAIL => ('Must be an integer as returned by any of the add*' .
			  'Option methods.')});
        $num_setup_errors++;
        return(undef);
      }

    ##TODO: Remove this check when pairing any option is supported.
    ##      Until then, temporary check of allowed options to pair. See REQ #341
    if(defined($pair_with_opt))
      {
	if($opttype ne 'infile' && $opttype ne 'outfile' &&
	   $opttype ne 'suffix' && $opttype ne 'logsuff')
	  {error("Pairing of $opttype options is not currently supported.")}
	if(($usage_array->[$pair_with_opt]->{OPTTYPE} ne 'infile' &&
	    $usage_array->[$pair_with_opt]->{OPTTYPE} ne 'outfile' &&
	    $usage_array->[$pair_with_opt]->{OPTTYPE} ne 'string') ||
	   ($opttype ne 'suffix' && $opttype ne 'logsuff' &&
	    $opttype ne 'infile' && $opttype ne 'outfile') ||
	   (($opttype eq 'outfile' || $opttype eq 'infile') &&
	    $usage_array->[$pair_with_opt]->{OPTTYPE} ne 'infile') ||
	   ($opttype eq 'logsuff' &&
	    $usage_array->[$pair_with_opt]->{OPTTYPE} ne 'string'))
	  {error("Pairing to $usage_array->[$pair_with_opt]->{OPTTYPE} ",
		 "options from a $opttype is not currently supported")}
      }

    if($heading ne '')
      {
	$heading =~ s/^\n+//;
	$heading =~ s/\n+$//;
      }

    if(!defined($usage_name))
      {$usage_name = createOptionNameFromFlags($flags_array)}

    if(defined($append_mode) && $append_mode &&
       $opttype ne 'logfile' && $opttype ne 'logsuff')
      {
	error("Can only set append mode for option types logfile and logsuff.");
	$append_mode = 0;
      }

    my $usage_index = scalar(@$usage_array);
    push(@$usage_array,
	 {OPTION_ID     => $usage_index,
	  GETOPTKEY     => $getoptkey,

	  VARREF_PRG    => $varref_prg,     #For internal use only
	  VARREF_CLI    => $varref_cli,     #Validated copy of value SUPPLIED
	  VARREF_STG    => $varref_stg,     #Staged/unvalidated copy of value
                                            #SUPPLIED
	  OPTFLAGS      => $flags_array,
	  OPTFLAG_DEF   => $def_flag,
	  SUMMARY       => (defined($smry_desc) ? $smry_desc :''),
	  DETAILS       => (defined($detail_desc) ?
			    $detail_desc : ''),
	  REQUIRED      => (defined($required) ? $required : 0),
	  DISPDEF       => $display_def,
	  DEFAULT_PRG   => $default_val,  #CLI's/Programmer's dflt
	  DEFAULT_USR   => undef,         #User's default
          DEFAULT_CLI   => undef,         #Like VARREF_CLI - validated default
	  ACCEPTS       => $accepts,
	  HIDDEN        => (defined($hidden) ? $hidden : 0),
	  OPTTYPE       => $opttype,  #bool,negbool,count,integer,float,string,
	                              #enum,integer_array,float_array,string_
                                      #array,enum_array,integer_array2d,float_
                                      #array2d,string_array2d,enum_array2d,
                                      #infile,outfile,outdir,suffix,logfile,
                                      #logsuff
	  FLAGLESS      => $flagless, #1, 0, or undef
	  ADVANCED      => $advanced,
	  HEADING       => $heading,
	  USAGE_NAME    => $usage_name,
	  USAGE_ORDER   => $usage_order,
	  PAIRID        => $pair_with_opt,
	  RELATION      => $pair_relat,
	  DELIMITER     => $delim,

	  #Track whether or not the user supplied an option,
	  #versus the option having a default value
	  SUPPLIED_AS   => [],          #Recreation of cmnd ln string
	  SUPPLIED_ARGS => [],          #Args supplied to the code ref
	  SUPPLIED      => 0,           #Whether user supplied opt
	  OPTFLAG_SUP   => undef,       #The flag/arg pos used

	  #Track whether or not the user supplied a user-default,
	  #versus the option having a programmer-default value
	  SUPPLIED_AS_UDF   => [],      #Raw values supplied by user (set below)
	  SUPPLIED_ARGS_UDF => [],      #Args supplied to the code ref
	  SUPPLIED_UDF      => 0,       #Whether user supplied opt
	  OPTFLAG_SUP_UDF   => undef,   #The flag/arg pos used

	  #File option info
	  PRIMARY       => $primary, #primary means stdin/out dflt
	  PRIMARY_PRG   => $primary_prg,
	  COLLIDE_MODE  => $collide_mode,
	  APPEND_MODE   => $append_mode,
	  FORMAT        => $format_desc,
	  FILEID        => undef,
	  TAGTEAM       => 0,   #Involved in a tagteam pair
	  TAGTEAMID     => ''});

    #This is mainly here so that builtin usage hashes can be retrieved by name
    #no matter what order the usage array is in
    $usage_lookup->{$usage_name} = $usage_array->[$usage_index];

    return($usage_index);
  }

#Returns the first flag longer than 1 character or the first flag, period.
sub createOptionNameFromFlags
  {
    my $flag_array = $_[0];
    my($name);
    my $defname    = '__flagless__';

    foreach my $flag (@$flag_array)
      {
	my $tmp = $flag;
	$tmp =~ s/^-+//;
	if(!defined($name))
	  {$name = $tmp}
	if(length($tmp) > 1)
	  {
	    $name = $tmp;
	    last;
	  }
      }

    if(!defined($name))
      {$name = $defname}

    return($name);
  }

#Supply a getoptkey and get back a usage hash
sub getUsageHash
  {
    my $usage_name = $_[0];
    if(!defined($usage_name) || ref($usage_name) ne '')
      {error('Invalid USAGE_NAME: [',
	     (defined($usage_name) ? ref($usage_name) : 'undef'),'].',
	     {DETAIL => 'Must be a scalar value.'})}
    if(exists($usage_lookup->{$usage_name}) &&
       defined($usage_lookup->{$usage_name}))
      {return($usage_lookup->{$usage_name})}
    error("USAGE_NAME [$usage_name] not found.");
    return({});
  }

sub getNextUsageIndex
  {return(scalar(@$usage_array))}

#Converts a getopt key string into an array of associated flag strings
sub getOptStrFlags
  {
    my $get_opt_str  = $_[0];
    my $include_negs = (defined($_[1]) ? $_[1] : 0);
    my @flags        = ();

    if(defined($get_opt_str))
      {
        my $negatable = ($get_opt_str =~ /!/);
        $get_opt_str  =~ s/[=:\!].*$//;

        push(@flags,
             map {(length($_) > 1 ? '--' : '-') . $_} split(/\|/,$get_opt_str));

        if($include_negs && $negatable)
          {@flags = map {my $f = $_;$f =~ s/^-+//;$_,"--no$f","--no-$f"} @flags}
      }

    return(wantarray ? @flags : [@flags]);
  }

#Returns the first 2 character flag or the first flag if a 2-character flag is
#not present
sub getDefaultFlag
  {
    my $flag_array = $_[0];
    if(!defined($flag_array) || ref($flag_array) ne 'ARRAY')
      {
	error("Invalid flag array: [",
	      (defined($flag_array) ?
	       (ref($flag_array) eq '' ? 'SCALAR' : ref($flag_array) . ' REF')
	       : 'undef'),"]");
	return('');
      }

    my $first_flag = '';
    foreach my $flag (@$flag_array)
      {
	if($first_flag eq '' && $flag =~ /^-/)
	  {$first_flag = $flag}
	if($flag =~ /^-[^\-]$/)
	  {return($flag)}
      }

    return($first_flag);
  }

sub getInfile
  {
    unless($command_line_stage)
      {processCommandLine()}

    my @in           = getSubParams([qw(FILETYPEID ITERATE)],[],[@_]);
    my $optid        = $in[0];
    my $file_type_id = (isInt($optid) && $optid >= 0 &&
			$optid <= $#{$usage_array} &&
			$usage_array->[$optid]->{OPTTYPE} eq 'infile' ?
			$usage_array->[$optid]->{FILEID} : undef);
    my $iterate      = defined($in[1]) ? $in[1] : $auto_file_iterate;

    if(defined($optid) && !defined($file_type_id))
      {
	error("Invalid infile option ID: [$optid].");
	return(undef);
      }

    if(!defined($file_set_num))
      {
	$file_set_num = 0;
	if(!defined($max_set_num))
	  {$max_set_num = 0}
      }

    if($file_set_num >= scalar(@$input_file_sets))
      {
	$file_set_num = 0;
	return(undef);
      }

    #Allow file_type_id to be optional when there's only 1 infile type
    ##TODO: Create an iterator to cycle through the types when no type ID is
    ##      supplied.  See requirement 181
    if(!defined($file_type_id) && (getNumInfileTypes() == 1 || !wantarray))
      {
	#Even if we're returning a list, we'll set a file that will
	#unnecessarily go through a conditional below to check for validity -
	#just so this sub will work in both contexts
	my @optids =
	  map {$_->{OPTION_ID}} grep {$_->{OPTTYPE} eq 'infile'} @$usage_array;
	if(scalar(@optids) == 0)
	  {
	    error("No input file options could be found.");
	    return(undef);
	  }
	$optid = $optids[0];
	$file_type_id = $usage_array->[$optid]->{FILEID};
      }
    elsif(!defined($file_type_id) && !wantarray)
      {
	error("A file type ID is required.");
	return(undef);
      }

    my @return_files = ();
    if(wantarray && !defined($file_type_id) &&
       defined($input_file_sets->[$file_set_num]))
      {
	##TODO: Reconsider this in such a way that the user knows the type of
	##   each file returned. Cannot use position here since we are grepping
	##   See requirement 182.
	@return_files = map {$input_file_sets->[$file_set_num]->[$_->{FILEID}]}
	  grep {$_->{OPTTYPE} eq 'infile' &&
		  defined($input_file_sets->[$file_set_num]->[$_->{FILEID}])}
	    @$usage_array;
      }

    my $repeated = 0;
    if((defined($file_type_id) && optvalReturnedBefore($optid)) ||
       !defined($file_type_id) && wantarray &&
       scalar(grep {optvalReturnedBefore($_)} @return_files))
      {$repeated = 1}

    if($repeated)
      {
	if($iterate)
	  {nextFileCombo()}
	else
	  {warning("Repeated requests for the same file detected.  Call ",
		   "nextFileCombo() between calls to getInfile().")}
	if(!defined($file_set_num))
	  {return(undef)}
      }

    if(wantarray && !defined($file_type_id))
      {$optval_returned_before->{IN}->{$file_set_num}->{$_} = 1
	 foreach(@return_files)}
    else
      {$optval_returned_before->{IN}->{$file_set_num}->{$optid} = 1}

    return(wantarray && !defined($file_type_id) ? @return_files :
	   $input_file_sets->[$file_set_num]->[$file_type_id]);
  }

#Determines whether a suffix is defined or not.  By "defined", what is meant
#depends on how the output file was defined by the programmer.  If the outfile
#type was created using addOutfileSuffixOption, then the result is whether or
#not the value for the suffix is defined (the straight-forward possibility).
#If however, the outfile type was defined by addOutfileOption, then the suffix
#is a hidden one with an empty string as a value and the suffix is "defined" if
#any files were supplied by the user for that option.
sub isSuffixDefined
  {
    my $file_index = $_[0];
    my $suff_index = $_[1];
    my $is_defined = 0;

    my $suffoptid = $file_indexes_to_usage->{$file_index}->{$suff_index};
    my $suffuhash = $usage_array->[$suffoptid];
    my $fileuhash = $usage_array->[$suffuhash->{PAIRID}];

    #If this is a suffix of an outfile type added by addOutfileOption
    if($fileuhash->{OPTTYPE} eq 'outfile')
      {$is_defined =
	 scalar(grep {my $a=$_;defined($a) && scalar(grep {defined($_)} @$a)}
		@{getVarref($fileuhash)})}
    else
      {$is_defined = defined(getVarref($suffuhash,1))}

    return($is_defined);
  }

#Takes either a suffix option ID or an outfile option ID and returns the
#associated suffix option ID.  This assumes that outfile options have a single
#hidden associated suffix option.  Returns the suffix option sent in if it
#already is a suffix option.
sub toSuffixOpt
  {
    my $optid = $_[0];
    return(undef) unless(defined($optid));
    if($optid > $#{$usage_array} ||
       ($usage_array->[$optid]->{OPTTYPE} ne 'suffix' &&
	$usage_array->[$optid]->{OPTTYPE} ne 'outfile'))
      {
	error("Invalid option ID: [$optid].");
	return(undef);
      }
    my($retopt);
    if($usage_array->[$optid]->{OPTTYPE} eq 'suffix')
      {$retopt = $optid}
    else
      {
	my $sfoptids = [map {$_->{OPTION_ID}}
			grep {$_->{OPTTYPE} eq 'suffix' &&
				$_->{PAIRID} == $optid} @$usage_array];
	if(scalar(@$sfoptids) != 1)
	  {error("Could not find hidden suffix option.")}
	else
	  {$retopt = $sfoptids->[0]}
      }
    return($retopt);
  }

#Globals used: $suffix_id_lookup
sub getOutfile
  {
    my @in = getSubParams([qw(SUFFIXID ITERATE)],[],[@_]);

    unless($command_line_stage)
      {processCommandLine()}

    my $suff_opt = toSuffixOpt($in[0]);
    my $sup_suff_opt =
      (defined($suff_opt) ? ($usage_array->[$suff_opt]->{TAGTEAM} ?
			     tagteamToSuffixID($usage_array->[$suff_opt]
					       ->{TAGTEAMID}) : $suff_opt) :
       undef);
    my $iterate = defined($in[1]) ? $in[1] : $auto_file_iterate;

    #If this is the first time we've returned any files, set up the file set
    #counter
    if(!defined($file_set_num))
      {
	$file_set_num = 0;
	if(!defined($max_set_num))
	  {$max_set_num = 0}
      }

    #If we're past the number of files supplied by the user, reset the file set
    #counter and return undef
    if($file_set_num >= scalar(@$input_file_sets))
      {
	$file_set_num = 0;
	return(undef);
      }

    ##
    ## Error-check or provide a default suffix ID
    ##

    #If the suffix ID provided does not exist.  Note, this works for both
    #outfile suffix types and outfile types (because it has a hidden suffix ID)
    if(defined($sup_suff_opt) &&
       ($sup_suff_opt > $#{$usage_array} || $sup_suff_opt < 0))
      {
	error("Invalid suffix ID: [$suff_opt].");
	return(undef);
      }
    #Else if no ID was provided and there's only one existing suffix ID
    elsif(!defined($sup_suff_opt) &&
	  scalar(grep {$_->{OPTTYPE} eq 'suffix'} @$usage_array) == 1)
      {$sup_suff_opt = (grep {$_->{OPTTYPE} eq 'suffix'} @$usage_array)[0]}
    #Else if no ID was provided and there's only 1 output file type supplied
    #on the command line
    elsif(!defined($sup_suff_opt) &&
	  #Both the suffix is defined and there are files it's appended to or
	  #the suffix is primary
	  scalar(grep {$_->{OPTTYPE} eq 'suffix' &&
			 ((defined(getVarref($_,1)) &&
			   scalar(@{getVarref($usage_array->[$_->{PAIRID}])}))
			  || $_->{PRIMARY})}
		 @$usage_array) == 1)
      {

	$sup_suff_opt = (grep {$_->{OPTTYPE} eq 'suffix' &&
				 ((defined(getVarref($_,1)) &&
				   scalar(@{getVarref($usage_array
						      ->[$_->{PAIRID}])})) ||
				  $_->{PRIMARY})}
			 @$usage_array)[0]->{OPTION_ID};
      }
    #Else if no ID was provided and no output files have been supplied (for
    #this set - which implies none specified for *any* set)
    elsif(!defined($sup_suff_opt) &&
	  #Both the suffix is defined and there are files it's appended to or
	  #the suffix is primary
	  scalar(grep {$_->{OPTTYPE} eq 'suffix' &&
			 ((defined(getVarref($_,1)) &&
			   scalar(@{getVarref($usage_array->[$_->{PAIRID}])}))
			  || $_->{PRIMARY})}
		 @$usage_array) == 0)
      {
	#If all output file types are primary, return '-'
	if(scalar(grep {$_->{OPTTYPE} eq 'suffix'} @$usage_array) ==
	   scalar(grep {$_->{OPTTYPE} eq 'suffix' &&
			  $_->{PRIMARY}} @$usage_array))
	  {return('-')}
	#Else return undef
	return(undef);
      }
    #Else if no ID was provided and no output file types have been defined
    elsif(!defined($sup_suff_opt) &&
	  scalar(grep {$_->{OPTTYPE} eq 'suffix'} @$usage_array) == 0)
      {
	error("No output file (or suffix) options have been added to the ",
	      "command line interface.");
	return(undef);
      }
    #Else if no ID was provided and there are multiple outfile types defined
    #and supplied
    elsif(!defined($sup_suff_opt) &&
	  scalar(grep {$_->{OPTTYPE} eq 'suffix'} @$usage_array) > 1)
      {
	#If there are only 2 outfile types and a tagteam exists
	if(scalar(grep {$_->{OPTTYPE} eq 'suffix'} @$usage_array) == 2 &&
	   scalar(keys(%$outfile_tagteams)) == 1)
	  {
	    my $ttid = (keys(%$outfile_tagteams))[0];
	    $sup_suff_opt = tagteamToSuffixID($ttid);
	  }
	else
	  {
	    error("Suffix ID is required when there is more than one output ",
		  "file type defined & supplied on the command line.");
	    return(undef);
	  }
      }

    debug({LEVEL => -99},"Suffix option ID is [",
	  (defined($sup_suff_opt) ? $sup_suff_opt : 'undef'),"].");

    my $file_type_opt   = $usage_array->[$sup_suff_opt]->{PAIRID};
    my $file_type_index = $usage_array->[$file_type_opt]->{FILEID};
    my $suffix_index    = -1;
    #We want to reverse engineer the suffix index and we know that the index is
    #incremented from 0 for each suffix that is linked to the file type that the
    #suffix we found is linked to, so...
    #For each suffix linked to the same file type
    foreach my $uh (grep {$_->{OPTTYPE} eq 'suffix' &&
			    $_->{PAIRID} == $file_type_opt} @$usage_array)
      {
	$suffix_index++;
	last if($uh->{OPTION_ID} == $sup_suff_opt);
      }
    #TODO: We can probably just store this index in the usage array instead of
    #the suffix ID we had been saving.

    if(optvalReturnedBefore($sup_suff_opt))
      {
	if($iterate)
	  {nextFileCombo()}
	else
	  {warning("Repeated requests for the same file detected.  Call ",
		   "nextFileCombo() between calls to getOutfile().")}
	if(!defined($file_set_num))
	  {return(undef)}
      }

    if($file_type_index >= scalar(@{$output_file_sets->[$file_set_num]}) ||
       $suffix_index >=
       scalar(@{$output_file_sets->[$file_set_num]->[$file_type_index]}))
      {
	error("Output file was not set up.");
	return(undef);
      }

    #If the output file name is not defined and no output files of this type
    #were specified by the user, manipulate the file name to either '-' if the
    #suffix type is primary (otherwise, keep undef)
    my($convert_undefs);
    if(!defined($output_file_sets->[$file_set_num]->[$file_type_index]
		->[$suffix_index]) &&
       scalar(grep {scalar(@$_) &&
		      defined($_->[$file_type_index]->[$suffix_index])}
	      @$output_file_sets) == 0 &&
       defined($suff_opt) && $usage_array->[$suff_opt]->{PRIMARY})
      {$convert_undefs = '-'}

    debug({LEVEL => -99},"Returning outfile for set [$file_set_num], file ",
	  "type (index) [$file_type_index], and suffix index [$suffix_index",
	  "].");

    my $outfile = $output_file_sets->[$file_set_num]->[$file_type_index]
      ->[$suffix_index];

    $optval_returned_before->{OUT}->{$file_set_num}->{$sup_suff_opt} = 1;

    return($convert_undefs && !defined($outfile) ? $convert_undefs : $outfile);
  }

#This subroutine takes a tagteam ID and returns a suffix ID.  The suffix ID
#will either be the one created by addOutfileSuffixOption or (via)
#addOutfileOption.  It determines which to return by checking whether the
#suffix or outfile was actually supplied on the command line (assuming only one
#was because processCommandLine validates this).  If neither was explicitly
#supplied on the command line and one has a default value (assuming both can't
#have a default value - again because of validation elsewhere), the suffix ID
#of the one with the default is returned.  Note that the suffix stored for the
#OTSFOPTID key always has a default (an empty string), so only SUFFOPTID will be
#checked and if it does not have a default, the OTSFOPTID is returned without
#checking whether it has a default.
sub tagteamToSuffixID
  {
    my $ttid = $_[0];

    if(!defined($ttid))
      {
	if(scalar(keys(%$outfile_tagteams)) == 1)
	  {$ttid = (keys(%$outfile_tagteams))[0]}
	else
	  {
	    error("Invalid tagteam ID: [undef].");
	    return(undef);
	  }
      }

    if(!validateTagteam($ttid)) #Generates errors if invalid
      {return($ttid)}

    if(exists($tagteam_to_supplied_optid->{$ttid}))
      {return($usage_array->[$tagteam_to_supplied_optid->{$ttid}]->{OPTION_ID})}
    else
      {
	error("Tagteam ID: [$ttid] not found.");
	return(undef);
      }
  }

#Determines if the suffix of a tagteam partner is defined.  Takes a file index
#and suffix index of the suffix whose partner we want to look up.
#Globals used: $outfile_tagteams
sub isTagteamPartnerDefined
  {
    my $usg_hash = $_[0];

    if(!$usg_hash->{TAGTEAM})
      {
	#Suffix is not in a tagteam.  It doesn't have a partner, so it can't be
	#defined
	return(0);
      }

    my $tthash = $outfile_tagteams->{$usg_hash->{TAGTEAMID}};

    my($partner_defined);
    #If this suffix ID is for the suffix option (vs the outfile option)
    if($tthash->{SUFFOPTID} == $usg_hash->{OPTION_ID})
      {
	my $ofoptid = $usage_array->[$tthash->{OTSFOPTID}]->{PAIRID};
	$partner_defined = scalar(@{getVarref($usage_array->[$ofoptid])});
      }
    else
      {$partner_defined =
	 defined(getVarref($usage_array->[$tthash->{SUFFOPTID}],1))}

    debug({LEVEL => -1},"Partner of type [",
	  $usage_array->[$tthash->{SUFFOPTID}]->{OPTTYPE},"] is: [",
	  ($partner_defined ? 'defined' : 'undefined'),
	  "].  Returning [$partner_defined].");

    return($partner_defined);
  }

#This not only validates tagteams by checking that the supplied ID is present
#and by making sure the options that were made into a tagteam are compatible
#(taking default-added options into account), but also populates the
#tagteam_to_supplied_optid that is used by tagteamToSuffixID
sub validateTagteam
  {
    #Note: the tagteam ID could be a suffix ID depending on how it was created
    my $ttid = $_[0];

    #If the tagteam ID is not defined, return failure
    if(!defined($ttid))
      {return(0)}

    #If the tagteam ID doesn't exist return failure
    if(!exists($outfile_tagteams->{$ttid}))
      {
	error("Invalid tagteam ID: [$ttid].");
	return(0);
      }

    #If already validated, return success
    if(exists($tagteam_to_supplied_optid->{$ttid}))
      {return(1)}

    #Validate the suffix IDs for this tagteam
    if($outfile_tagteams->{$ttid}->{SUFFOPTID} > $#{$usage_array} ||
       $usage_array->[$outfile_tagteams->{$ttid}->{SUFFOPTID}]->{OPTTYPE} ne
       'suffix')
      {
	error("The suffix option ID: [",$outfile_tagteams->{$ttid}->{SUFFOPTID},
	      "] for tagteam ID: [$ttid] is invalid.");
	return(0);
      }
    elsif($outfile_tagteams->{$ttid}->{OTSFOPTID} > $#{$usage_array} ||
	  $usage_array->[$outfile_tagteams->{$ttid}->{OTSFOPTID}]->{OPTTYPE} ne
	  'suffix' ||
	  $usage_array->[$usage_array->[$outfile_tagteams->{$ttid}->{OTSFOPTID}]
			 ->{PAIRID}]->{OPTTYPE} ne 'outfile')
      {
	error("The outfile suffix option ID: [",
	      $outfile_tagteams->{$ttid}->{OTSFOPTID},"] for tagteam ID: ",
	      "[$ttid] is invalid.");
	return(0);
      }

    #Obtain the default for the suffix (unless superceded by a mutually
    #exclusive default or command line value)
    my $suff_uhash      = $usage_array->[$outfile_tagteams->{$ttid}
					 ->{SUFFOPTID}];
    my $sfin_uhash      = $usage_array->[$suff_uhash->{PAIRID}];
    my $suff_default    = (!exclusiveOptSupplied($suff_uhash->{OPTION_ID}) &&
			   defined($suff_uhash->{DEFAULT_USR}) ?
			   $suff_uhash->{DEFAULT_USR} :
			   (!exclusiveOptUserDefaulted($suff_uhash) &&
			    defined($suff_uhash->{DEFAULT_PRG}) ?
			    $suff_uhash->{DEFAULT_PRG} : undef));
    my $suff_value      = getVarref($suff_uhash,1);
    my $is_suff_default = defined($suff_default);

    #Obtain the default for the outfile (unless superceded by a mutually
    #exclusive default or command line value)
    my $otsf_uhash      = $usage_array->[$outfile_tagteams->{$ttid}
					 ->{OTSFOPTID}];
    my $outf_uhash      = $usage_array->[$otsf_uhash->{PAIRID}];
    my $outf_default    = (!exclusiveOptSupplied($outf_uhash->{OPTION_ID}) &&
			   defined($outf_uhash->{DEFAULT_USR}) &&
			   scalar(@{$outf_uhash->{DEFAULT_USR}}) ?
			   $outf_uhash->{DEFAULT_USR} :
			   (!exclusiveOptUserDefaulted($outf_uhash) &&
			    defined($outf_uhash->{DEFAULT_PRG}) &&
			    scalar(@{$outf_uhash->{DEFAULT_PRG}}) ?
			    $outf_uhash->{DEFAULT_PRG} : []));
    my $outf_value      = getVarref($outf_uhash,1);
    my $is_outf_default = scalar(@$outf_default);

    debug({LEVEL => -1},"Suffix [",
	  getFlag($usage_array->[$outfile_tagteams->{$ttid}->{SUFFOPTID}],-1),
	  "] default value in the tagteam pair, is [",
	  (defined($suff_default) ? $suff_default : 'undef'),"].  Suff val: [",
	  (defined($suff_value) ? $suff_value : 'undef'),"]  Outf val: [",
	  (defined($outf_value) ? $outf_value : 'undef'),"]  Is Suff def: ",
	  "[",($is_suff_default ? 1 : '0'),"]  Is outf def: [",
	  ($is_outf_default ? 1 : '0'),"]");

    #If the suffix has a value and it is not a default value and either outf
    #has no value (i.e. is empty) or is the default value
    if($suff_uhash->{SUPPLIED} && !$outf_uhash->{SUPPLIED})
      {
	$tagteam_to_supplied_optid->{$ttid} = $suff_uhash->{OPTION_ID};
	return(1);
      }
    #Else if the outfile has a value and it's not a default value and either
    #suff is not defined or is the default
    elsif(!$suff_uhash->{SUPPLIED} && $outf_uhash->{SUPPLIED})
      {
	$tagteam_to_supplied_optid->{$ttid} = $otsf_uhash->{OPTION_ID};
	return(1);
      }
    #Else if only the suffix has a defined default value
    elsif($is_suff_default && !$is_outf_default)
      {
	$tagteam_to_supplied_optid->{$ttid} = $suff_uhash->{OPTION_ID};
	return(1);
      }
    #Else if only the outfile has a defined default value
    elsif($is_outf_default && !$is_suff_default)
      {
	$tagteam_to_supplied_optid->{$ttid} = $otsf_uhash->{OPTION_ID};
	return(1);
      }
    #Else if both have default values
    elsif($is_outf_default && $is_suff_default)
      {
	error("Outfile tagteam options are mutually exclusive.  Cannot have ",
	      "default values for both an outfile suffix [",
	      getFlag($usage_array->[$outfile_tagteams->{$ttid}->{SUFFOPTID}]),
	      "] (default: [",
	      (defined($suff_default) ? $suff_default : 'undef'),
	      "]) and an outfile [",getFlag($outf_uhash),
	      "] (default: [(",join('),(',map {join(',',@$_)} @$outf_default),
	      ")]) at the same time.  ",
	      "Use --force to surpass this fatal error and arbitrarily use [",
	      ($suff_uhash->{OPTION_ID} < $otsf_uhash->{OPTION_ID} ?
	       getFlag($suff_uhash) : getFlag($otsf_uhash)),
	      "], ignoring the other option.");
	quit(-40);
	$tagteam_to_supplied_optid->{$ttid} =
	  ($suff_uhash->{OPTION_ID} < $otsf_uhash->{OPTION_ID} ?
	   $suff_uhash->{OPTION_ID} : $otsf_uhash->{OPTION_ID});
	return(0);
      }
    #Note: a check of *supplying* mutually exclusive opts is done elsewhere

    ##
    ## At this point, neither was supplied and neither have default values...
    ##

    #Else if only the suffix was default added
    elsif($default_outfile_suffix_added && !$default_outfile_added)
      {$tagteam_to_supplied_optid->{$ttid} = $otsf_uhash->{OPTION_ID}}
    #Else if the outfile only was default added
    elsif($default_outfile_added && !$default_outfile_suffix_added)
      {$tagteam_to_supplied_optid->{$ttid} = $suff_uhash->{OPTION_ID}}
    #Else both or neither were default added - return the lesser ID
    else
      {$tagteam_to_supplied_optid->{$ttid} =
	 ($suff_uhash->{OPTION_ID} < $otsf_uhash->{OPTION_ID} ?
	  $suff_uhash->{OPTION_ID} : $otsf_uhash->{OPTION_ID})}

    return(1);
  }

sub nextFileCombo
  {
    unless($command_line_stage)
      {processCommandLine()}

    my $extended = getVarref('extended',1,1);

    if($auto_file_iterate)
      {
	my $called_implicitly = 0;
	if(isCaller('getInfile','getOutfile'))
	  {$called_implicitly = 1}
	if(!$called_implicitly)
	  {
	    $auto_file_iterate = 0;
	    if(defined($file_set_num) &&
	       $file_set_num < scalar(@$input_file_sets))
	      {warning("File set iteration has gone from implicit to ",
		       "explicit.  ",
		       ($extended ?
			("Input and/or output files may have been skipped.  " .
			 "Please use nextFileCombo to iterate over all sets " .
			 "of files provided on the command that are " .
			 "processed together.  Do not call openOut, openIn, " .
			 "getInfile, or getOutfile before the first call to " .
			 "nextFileCombo.") :
			"Run with --extended for more detail."))}
	    debug({LEVEL=>-1},"nextFileCombo was called explicitly, not ",
		  "through getInfile or getOutfile.  Turning off auto-",
		  "iterate.");
	  }
	else
	  {$auto_file_iterate = 1}
      }

    if(!defined($file_set_num))
      {
	$file_set_num = 0;
	if(!defined($max_set_num))
	  {$max_set_num = 0}
      }
    elsif($file_set_num < $#{$input_file_sets})
      {
	$file_set_num++;
	if($max_set_num < $file_set_num)
	  {$max_set_num = $file_set_num}
      }
    else
      {
	$file_set_num           = undef;
	$optval_returned_before = {};
	$auto_file_iterate      = 1;
      }

    debug({LEVEL=>-1},"Returning file set num: [",
	  (defined($file_set_num) ? "$file_set_num + 1" : 'undef'),"].");

    #Must return a non-zero value for this to work in a while loop
    return(defined($file_set_num) ? $file_set_num + 1 : $file_set_num);
  }

sub optvalReturnedBefore
  {
    my $optid = $_[0];

    if(!defined($file_set_num))
      {
	$file_set_num = 0;
	if(!defined($max_set_num))
	  {$max_set_num = 0}
      }

    if(!defined($optid))
      {return(0)}
    else
      {
	if(exists($optval_returned_before->{IN}->{$file_set_num}) &&
	   exists($optval_returned_before->{IN}->{$file_set_num}->{$optid}) &&
	   $optval_returned_before->{IN}->{$file_set_num}->{$optid})
	  {return(1)}
	else
	  {
	    $optval_returned_before->{IN}->{$file_set_num}->{$optid} = 1;
	    return(0);
	  }
      }
  }

sub addDefaultFileOptions
  {
    my $success = 1;

    #If the programmer did not add any input file types, add a default
    if(getNumInfileTypes() == 0)
      {
        my $iid = addInfileOption();
        if(!defined($iid))
          {$success = 0}
      }

    my $def_prim_inf_optid = getDefaultPrimaryInfileID();

    #If the programmer did not assign a primary input file type and the number
    #of explicitly non-primary infile types is not all of the infile types,
    #pick a default
    if(!defined($primary_infile_optid) && defined($def_prim_inf_optid))
      {
	#We will mark this as the primary infile ID even if the programmer may
	#have explicitly said that it's not to be primary, just so we can do
	#default linking of outfile types.
	$primary_infile_optid = $def_prim_inf_optid;

	if(!defined($usage_array->[$def_prim_inf_optid]))
	  {error("The default primary infile type: [$def_prim_inf_optid] is ",
		 "not defined in the usage array.")}

	#If the non-primary status was not set explicitly to 0
	if($usage_array->[$def_prim_inf_optid]->{PRIMARY} ne '0')
	  {
	    $usage_array->[$def_prim_inf_optid]->{PRIMARY} = 1;
	    if(defined($usage_array->[$def_prim_inf_optid]->{DISPDEF}) &&
	       $usage_array->[$def_prim_inf_optid]->{DISPDEF} eq '')
	      {$usage_array->[$def_prim_inf_optid]->{DISPDEF} = "''"}
	  }
      }

    #If there was an error during setup (implied by cleanup_mode > 1) and there
    #is no usage entry for the primary infile type, skip all this and return
    if($cleanup_mode > 1 && $primary_infile_optid > $#{$usage_array})
      {return(0)}

    #If the programmer did not assign any multi-value option as 'flagless', set
    #the primary input file as flagless (if it is defined and not explicitly
    #set to not be flagless)
    if((!defined($flagless_multival_optid) || $flagless_multival_optid < 0) &&
       defined($primary_infile_optid) &&
       ((defined($usage_array->[$primary_infile_optid]->{FLAGLESS}) &&
	 $usage_array->[$primary_infile_optid]->{FLAGLESS}) ||
	!defined($usage_array->[$primary_infile_optid]->{FLAGLESS})))
      {
	#Keep track globally of which option is the multi-value flagless one
	$flagless_multival_optid = $primary_infile_optid;

	my $name = $usage_array->[$primary_infile_optid]->{USAGE_NAME};
	$GetOptHash->{'<>'} = getGetoptSub($name,1);

	$usage_array->[$primary_infile_optid]->{FLAGLESS} = 1;
      }

    my $num_outfile_types =
      scalar(grep {$_->{OPTTYPE} eq 'outfile'} @$usage_array);
    my $num_suffix_types  = getNumSuffixTypes();

    #Add a default outfile suffix type if none was added and either no outfile
    #types were added or the first primary outfile type has something other
    #than a 1:M relationship
    my $add_outf_suff =
      ($num_suffix_types == 0 &&
       ($num_outfile_types == 0 || (doesPrimaryOutOptExist(0) &&
                                    !isDefaultPrimaryOut1toMorUnrelated())));
    #Add a default outfile type if none was added and no primary suffix types
    #were added
    my $add_outf =
      ($num_outfile_types == 0 &&
       ($num_suffix_types == 0 || doesPrimaryOutOptExist(1)));

    #If the programmer did not add an outfile suffix option and one is
    #appropriate
    if($add_outf_suff)
      {
	debug({LEVEL => -1},"Adding default outfile suffix option because ",
	      "the number of suffix types added [$num_suffix_types] == 0 and ",
	      "(the number of outfile types [$num_outfile_types] == 0 or the ",
	      "first primary outfile type had [",
	      (isDefaultPrimaryOut1toMorUnrelated() ? 'at least 1' : 'no'),
	      "] 1:M relationships or no relationship defined with input ",
	      "files.");
	addOutfileSuffixOption();
      }
    else
      {debug({LEVEL => -1},"Not adding default outfile suffix option because ",
	     "the number of suffix types added [$num_suffix_types] != 0 or ",
	     "(the number of outfile types [$num_outfile_types] != 0 and the ",
	     "first primary outfile type had [",
	     (isDefaultPrimaryOut1toMorUnrelated() ? 'at least 1' : 'no'),
	     "] 1:M relationships or no relationship defined with input ",
	     "files.")}

    #If the programmer did not add an outfile option, add one for standard out
    if($add_outf)
      {
	debug({LEVEL => -1},"Adding default outfile option because the number ",
	      "of outile types added [$num_outfile_types] == 0 and (the ",
	      "number of suffix types [$num_suffix_types] == 0 or none of the ",
	      "existing suffix types were primary.");
	addOutfileOption();
      }
    else
      {debug({LEVEL => -1},"Not adding default outfile option because the ",
             "number of outile types added [$num_outfile_types] != 0 or (the ",
             "number of suffix types [$num_suffix_types] != 0 and at least ",
             "one of the existing suffix types is primary.")}

    #If one of the default outfile types was added, create a tagteam with it
    #and the first primary outfile/suffix type
    if($default_outfile_added || $default_outfile_suffix_added)
      {
	if($default_outfile_added && $default_outfile_suffix_added)
	  {
	    if(!$default_tagteam_added)
	      {
                my $ttid = createSuffixOutfileTagteam($default_suffix_optid,
                                                      $default_outfile_optid);
                if(!defined($ttid))
                  {$success = 0}
              }
	  }
	elsif($default_outfile_suffix_added)
	  {
	    my $def_suff_usg_hash  = $usage_array->[$default_suffix_optid];
	    my $prim_outf_usg_hash = getDefaultPrimaryOutUsageHash(0);

	    #If both outfile types are linked to the same input file type, go
	    #ahead and create the tagteam, otherwise, skip it.  Note: Defined
	    #state is checked because an outfile type can be created without
	    #linking it to an input file.
	    if(defined($prim_outf_usg_hash->{PAIRID}) &&
	       $prim_outf_usg_hash->{PAIRID} == $def_suff_usg_hash->{PAIRID})
	      {
                my $ttid = createSuffixOutfileTagteam($default_suffix_optid,
                                                      $prim_outf_usg_hash
                                                      ->{OPTION_ID});
                if(!defined($ttid))
                  {$success = 0}
              }
	    else
	      {debug({LEVEL => -1},"Skipping tagteam creation because each ",
		     "outfile type is linked to different infiles: outfile's ",
                     "infile ID: [$prim_outf_usg_hash->{PAIRID}] versus ",
                     "suffix's infile ID: [$def_suff_usg_hash->{PAIRID}].")}
	  }
	elsif($default_outfile_added)
	  {
	    my $prim_suff_optid = getDefaultPrimaryOutOptID(1);

            #If there aren't any primary out options (i.e. options that weren't
            #explicitly set as non-primary).
            if(defined($prim_suff_optid))
              {
                my $prim_suff_usg_hash = $usage_array->[$prim_suff_optid];
                my $def_outf_usg_hash  = $usage_array->[$default_outfile_optid];

                ##TODO: Note that I will have to make sure that I am comparing
                ##      infile option types once options can be paired to
                ##      something other than infile types.  See REQ #341.

                #If both outfile types are linked to the same input file type,
                #go ahead and create the tagteam, otherwise, skip it.
                if(defined($prim_suff_usg_hash) &&
                   scalar(keys(%$prim_suff_usg_hash)) &&
                   $prim_suff_usg_hash->{PAIRID} ==
                   $def_outf_usg_hash->{PAIRID})
                  {
                    my $ttid =
                      createSuffixOutfileTagteam($prim_suff_optid,
                                                 $default_outfile_optid);
                    if(!defined($ttid))
                      {$success = 0}
                  }
              }
	  }
      }

    #If the programmer did not add an outdir option, add a default
    if(!$outdirs_added)
      {
	my $od_optid = addOutdirOption();

	#If there was a problem adding the outdir, $od_optid will be undefined
	if(defined($od_optid))
	  {
	    my $od_usg_hash = $usage_array->[$od_optid];

	    #Append notes to detail_descs of default-added outfile types and
	    #outfile suffix types (if the outdir type created above is not
	    #hidden) to indicate that they will deposit their files in the
	    #supplied outdir

	    if(!$od_usg_hash->{HIDDEN})
	      {
		if($default_outfile_suffix_added)
		  {
		    my $suf_usg_hash = $usage_array->[$default_suffix_optid];
		    $suf_usg_hash->{DETAILS} .= "  Does not replace " .
		      "extensions.  Output files are placed in the same " .
			"directory as each input file (unless [" .
			  getOutdirFlag() . "] is supplied).  Will not " .
			    "overwrite without --overwrite.";
		  }

		if($default_outfile_added)
		  {
		    #This assumes there's only 1 (hidden) suffix when the type
		    #is outfile
		    my $of_usg_hash = $usage_array->[$default_outfile_optid];
		    $of_usg_hash->{DETAILS} .= "  Output files are placed in " .
		      "the current directory (unless [" . getOutdirFlag() .
			"] is supplied).  Will not overwrite without " .
			  "--overwrite.";
		  }
	      }
	  }
      }
    else
      {
	my $od_usg_hash = getOutdirUsageHash();

	#Tell user where output will go if hidden and there's a default
	if($od_usg_hash->{HIDDEN} && defined($od_usg_hash->{DISPDEF}) &&
	   $od_usg_hash->{DISPDEF} ne '')
	  {
	    if($default_outfile_suffix_added)
	      {
		my $suf_usg_hash = $usage_array->[$default_suffix_optid];
		$suf_usg_hash->{DETAILS} .= "\n\nOutput files will be " .
		  "placed in [$od_usg_hash->{DISPDEF}].";
	      }

	    if($default_outfile_added)
	      {
		#This assumes there's only 1 (hidden) suffix when the type is
		#outfile
		my $of_usg_hash = $usage_array->[$default_outfile_optid];
		$of_usg_hash->{DETAILS} .= "\n\nOutput files will be placed " .
		  "in [$od_usg_hash->{DISPDEF}].  Output file paths are not " .
		    "allowed unless the default output directory is removed.";
	      }
	  }
      }

    if(!$logfile_added && (!$logfile_suffix_added ||
                           !exists($exclusive_lookup->{$logfile_suffix_optid})))
      {
	addLogfileOption();
	$logfile_default_added = 1;
      }

    if($logfile_added && $logfile_suffix_added)
      {if(!createSuffixLogfileTagteam($logfile_optid,$logfile_suffix_optid))
         {$success = 0}}

    return($success);
  }

sub createSuffixLogfileTagteam
  {
    my $file_optid = $_[0];
    my $suff_optid = $_[1];

    my $of_usage = $usage_array->[$file_optid];
    my $sf_usage = $usage_array->[$suff_optid];

    my $required = $of_usage->{REQUIRED} || $sf_usage->{REQUIRED} ? 1 : 0;

    #Check whether any options are hidden
    my $hidden = $of_usage->{HIDDEN} + $sf_usage->{HIDDEN};
    if($required && !hasDefault($of_usage) && !hasDefault($sf_usage) &&
       $hidden == 2)
      {
	warning('Cannot hide both [',getBestFlag($sf_usage),'] and [',
		getBestFlag($of_usage),'] when required and no default ',
                'provided.  Unhiding.');
	$of_usage->{HIDDEN} = 0;
	$sf_usage->{HIDDEN} = 0;
      }

    my $mutex_success =
      makeMutuallyExclusive(OPTIONIDS   => [$file_optid,$suff_optid],
			    REQUIRED    => $required,
			    OVERRIDABLE => 1,
                            NAME        => 'logfile tagteam');

    if(!defined($mutex_success))
      {return(0)}

    return(1);
  }

#Returns true if the first (primary/required/unhidden) outfile type is 1:M or
#is not linked/related to an input file.  The purpose of this sub is to help
#decide whether to add the default outfile suffix, which is only added (among
#other requirements) when the "first"/primary outfile type the programmer
#manually added is NOT in a 1:M relationship with an infile or if the programmer
#has not added a relationship type (e.g. 1:1orM, 1:1, etc)
sub isDefaultPrimaryOut1toMorUnrelated
  {
    my $prim_outf_usg_hash = getDefaultPrimaryOutUsageHash(0);

    if(scalar(keys(%$prim_outf_usg_hash)) &&
       ($prim_outf_usg_hash->{RELATION} eq '1:M' ||
	$prim_outf_usg_hash->{RELATION} eq '1'   ||
	$prim_outf_usg_hash->{RELATION} eq ''))
      {return(1)}

    if(scalar(keys(%$prim_outf_usg_hash)) == 0)
      {debug({LEVEL => -1},"No primary outfile types defined.")}

    return(0);
  }

#Globals used: $usage_array
sub getDefaultPrimaryOutUsageHash
  {
    my $get_suffix = $_[0]; #Whether or not to retrieve suffix type (otherwise,
                            #get an outfile type)
    my $usage_index = getDefaultPrimaryOutOptID($get_suffix);
    if(defined($usage_index))
      {return($usage_array->[$usage_index])}

    return({});
  }

#Globals used: $usage_array
sub doesPrimaryOutOptExist
  {
    my $get_suffix = $_[0]; #Whether or not to test suffix type (otherwise, test
                            #an outfile type)
    my $usage_index = getDefaultPrimaryOutOptID($get_suffix);
    if(defined($usage_index))
      {return(1)}

    return(0);
  }

#Globals used: $usage_array
sub getDefaultPrimaryOutOptID
  {
    my $get_suffix = $_[0]; #Whether or not to retrieve suffix type (otherwise,
                            #get an outfile type)
    foreach my $usgid (sort {
      my $ah = $usage_array->[$a];
      my $bh = $usage_array->[$b];
      #Primary options first.  Of primary options, required first. Of primary-
      #required options, unhidden first.  The first primary required unhidden
      #option will be returned.  Explicitly non-primary options will be skipped.
      $bh->{PRIMARY} <=> $ah->{PRIMARY} ||
	$bh->{REQUIRED} <=> $ah->{REQUIRED} || $ah->{HIDDEN} <=> $bh->{HIDDEN}}
		       grep {($get_suffix ?
                              ($usage_array->[$_]->{OPTTYPE} eq 'suffix') :
                              ($usage_array->[$_]->{OPTTYPE} eq 'outfile')) &&
                             (!defined($usage_array->[$_]->{PRIMARY_PRG}) ||
                              $usage_array->[$_]->{PRIMARY_PRG})}
		       (0..$#{$usage_array}))
      {
	my $usage_hash = $usage_array->[$usgid];

	#If we're looking for a pure suffix type and this is the hidden
	#suffix type of an outfile type, skip it
	if($get_suffix &&
	   $usage_array->[$usage_hash->{PAIRID}]->{OPTTYPE} eq 'outfile')
	  {next}
	return($usgid);
      }

    debug({LEVEL => -1},"There were no suffix IDs found for outfile type ",
	  "defined by ",($get_suffix ? 'suffix' : 'outfile name'));

    return(undef);
  }

#This returns the default primary out's suffix type's FILETYPEID or outfile
#type's PAIR_WITH ID - whichever is the default primary out type.  Returns
#undef if PAIR_WITH is not defined or if no outfile types have been defined
sub getDefaultPrimaryLinkedInfileID
  {
    my $outfile_usage_hash = getDefaultPrimaryOutUsageHash(0);

    #Undefining an empty result to make it easier to determine
    if(scalar(keys(%$outfile_usage_hash)) == 0)
      {undef($outfile_usage_hash)}

    debug({LEVEL => -1},"Outfile option ID selected as default primary: [",
	  (defined($outfile_usage_hash) ? $outfile_usage_hash->{OPTION_ID} :
	   'undef'),"] which belongs to [",
	  (defined($outfile_usage_hash) ? getFlag($outfile_usage_hash,-1) :
	   'undef'),"] and [",(defined($outfile_usage_hash) &&
			       $outfile_usage_hash->{PRIMARY} ?
			       'is' : 'is not'),"] primary.");
    #I need to be able to tell which option is the lesser between the outfile &
    #suffix options...
    my $linked_index1 =
      (defined($outfile_usage_hash) && defined($outfile_usage_hash->{PAIRID}) ?
       $outfile_usage_hash->{PAIRID} : undef);

    my $suffix_usage_hash = getDefaultPrimaryOutUsageHash(1);

    #Undefining an empty result to make it easier to determine
    if(scalar(keys(%$suffix_usage_hash)) == 0)
      {undef($suffix_usage_hash)}

    debug({LEVEL => -1},"Suffix option ID selected as default primary: [",
	  (defined($suffix_usage_hash) ? $suffix_usage_hash->{OPTION_ID} :
	   'undef'),"] which belongs to [",
	  (defined($suffix_usage_hash) ? getFlag($suffix_usage_hash,-1) :
	   'undef'),"] and [",(defined($suffix_usage_hash) &&
			       $suffix_usage_hash->{PRIMARY} ?
			       'is' : 'is not'),"] primary.");

    my $linked_index2 = (defined($suffix_usage_hash) ?
			 $suffix_usage_hash->{PAIRID} : undef);

    #Select the infile option ID that was added earlier
    my($primary_linked_index);
    if(defined($outfile_usage_hash) && defined($suffix_usage_hash))
      {$primary_linked_index =
	 ($outfile_usage_hash->{OPTION_ID} < $suffix_usage_hash->{OPTION_ID} ?
	  $linked_index1 : $linked_index2)}
    elsif(defined($outfile_usage_hash))
      {$primary_linked_index = $linked_index1}
    #Else - either linked_index2 is defined and primary or undefined and there
    #is no primary
    else
      {$primary_linked_index = $linked_index2}

    debug({LEVEL => -1},"Returning primary linked index: [",
	  (defined($primary_linked_index) ? $primary_linked_index : 'undef'),
	  "] for infile type [",
	  (defined($primary_linked_index) ?
	   getFlag($usage_array->[$primary_linked_index]) : 'undef'),"].");

    return($primary_linked_index);
  }

sub getDefaultPrimaryInfileID
  {
    #If the primary infile type has already been defined
    if(defined($primary_infile_optid))
      {return($primary_infile_optid)}
    #If there are no input file types
    elsif(getNumInfileTypes() == 0)
      {return(undef)}

    #Return the first after sorting by ascending explicitly-set non-primary
    #status (i.e. if the programmer explicitly set a file type to not be
    #primary, it's the LAST choice if *every* file type is not primary),
    #descending primary status (though all should be 0 - we'll do this as a
    #safeguard), descending required status, ascending hidden status, or order
    #in which they were created
    return((sort {my $ua = $usage_array->[$a];
		  my $ub = $usage_array->[$b];
		  #'a' is explicitly non-primary
		  my $anp = defined($ua->{PRIMARY_PRG}) && !$ua->{PRIMARY_PRG};
		  #'b' is explicitly non-primary
		  my $bnp = defined($ub->{PRIMARY_PRG}) && !$ub->{PRIMARY_PRG};
		  #Make options that were not explicitly set as non-primary or
		  #are effectively primary, 1st
		  $anp <=> $bnp || $ub->{PRIMARY} <=> $ua->{PRIMARY} ||
		    $ub->{REQUIRED} <=> $ua->{REQUIRED} ||
		      $ua->{HIDDEN} <=> $ub->{HIDDEN} || $a <=> $b}
	    grep {$usage_array->[$_]->{OPTTYPE} eq 'infile'}
	    (0..$#{$usage_array}))[0]);
  }

sub getNumInfileTypes
  {return(scalar(grep {$_->{OPTTYPE} eq 'infile'} @$usage_array))}

sub getInfileIndexes
  {
    my $i = [map {$_->{FILEID}} grep {$_->{OPTTYPE} eq 'infile'} @$usage_array];
    return(wantarray ? @$i : $i);
  }

#Checks just the pure suffix types (not the hidden ones for outfiles)
sub getNumSuffixTypes
  {return(scalar(grep {$_->{OPTTYPE} eq 'suffix' &&
			 $usage_array->[$_->{PAIRID}]->{OPTTYPE} eq 'infile'}
		 @$usage_array))}

#Variable options are those whose visibility/availability varies based on their
#default values.  They include: --run, --dry-run, --usage, & --help.  This
#method adds --usage, --help, --run, and --dry-run.
#
#NOTE: various calls to addOption will set a value in the global GetOptHash,
#but those values already exist for the options this method adds (e.g. --help).
#That's fine.  The values were pre-added so that user defaults could be read in
#to establish a user-defined default run mode.
sub addRunModeOptions
  {
    my $def_mode_set = 0;
    my $errors       = 0;

    #This handles the override of the CLI class default with the programmer's
    #default.  This would otherwise fail in the mutex group processing.  The CLI
    #default is the value set (of $run, $dry_run, $usage, and $help) to 1 in the
    #_init method
    my $custom_prg_default_exists = 0;
    foreach my $opt (grep {$def_option_hash->{$_}->{ADDED}}
		     qw(usage help run dry_run))
      {
	if(defined($def_option_hash->{$opt}->{PARAMS}->{DEFAULT}) &&
	   $def_option_hash->{$opt}->{PARAMS}->{DEFAULT})
	  {
	    $custom_prg_default_exists = 1;
	    $def_mode_set              = 1;
	  }
      }

    #We have determined the run mode defaults above.  Now we need to set each
    #affected option's default.
    my $heading_added = 0;
    foreach my $opt (grep {!$def_option_hash->{$_}->{ADDED}}
		     qw(usage help run dry_run))
      {
	if(!$heading_added)
	  {
	    $heading_added = 1;
	    if(!defined($def_option_hash->{$opt}->{PARAMS}->{HEADING}) ||
	       $def_option_hash->{$opt}->{PARAMS}->{HEADING} eq '')
	      {$def_option_hash->{$opt}->{PARAMS}->{HEADING} =
		 'RUN MODE OPTIONS'}
	  }

	if($custom_prg_default_exists &&
	   defined($def_option_hash->{$opt}->{PARAMS}->{DEFAULT}) &&
	   $def_option_hash->{$opt}->{PARAMS}->{DEFAULT})
	  {
	    $def_option_hash->{$opt}->{PARAMS}->{DEFAULT} = 0;
	    $def_option_hash->{$opt}->{PARAMS}->{DISPDEF} = undef;
	  }
	elsif(defined($def_option_hash->{$opt}->{PARAMS}->{DEFAULT}) &&
	      $def_option_hash->{$opt}->{PARAMS}->{DEFAULT})
	  {$def_mode_set = 1}

	my $id = addBuiltinOption($opt);

        if(!defined($id))
          {$errors++}
      }

    if(!$def_mode_set)
      {
	error('No default run mode was set.  Falling back to usage as the ',
	      'default run mode.');
	$usage_lookup->{usage}->{DEFAULT_PRG} = 1;
      }

    my $mut_excl_array = [];
    foreach my $opt (qw(usage help run dry_run version))
      {push(@$mut_excl_array,$usage_lookup->{$opt}->{OPTION_ID})}

    #TODO: Make --version a run mode option

    my $mtx_success = makeMutuallyExclusive(OPTIONIDS   => $mut_excl_array,
                                            OVERRIDABLE => 1,
                                            REQUIRED    => 1,
                                            NAME        => 'run modes');
    if(!defined($mtx_success))
      {$errors++}

    #Return 0 for success, non-zero for failure
    return($errors);
  }

sub getDefaultRunMode
  {
    if($command_line_stage < DEFAULTED)
      {error('getDefaultRunMode called before processing user defaults.')}

    my $default_run_mode = '';
    foreach my $opt (qw(usage help run dry_run))
      {
	my $uh = getUsageHash($opt);
	if((defined($uh->{DEFAULT_USR}) && $uh->{DEFAULT_USR}) ||
	   ($default_run_mode eq '' &&
	    defined($uh->{DEFAULT_PRG}) && $uh->{DEFAULT_PRG}))
	  {$default_run_mode = $opt}
      }
    if($default_run_mode eq '')
      {
	error("No default run mode set.  Falling back to usage.");
	$default_run_mode = 'usage';
      }

    return($default_run_mode);
  }

#This is solely for backward compatibility with setDefaults()
sub setDefaultRunMode
  {
    my $run_mode = $_[0];
    $run_mode =~ s/-/_/; #For dry-run

    my $set = 0;
    foreach my $opt (qw(usage help run dry_run))
      {
	if($opt eq $run_mode)
	  {
	    $set = 1;
	    if($def_option_hash->{$opt}->{ADDED})
	      {
		my $uh = getUsageHash($opt);
		$uh->{DEFAULT_PRG} = 1;
	      }
	    else
	      {$def_option_hash->{$opt}->{PARAMS}->{DEFAULT} = 1}
	  }
      }
    if(!$set)
      {error("Could not match run mode [$run_mode].")}
    else
      {
	foreach my $opt (qw(usage help run dry_run))
	  {
	    if($opt ne $run_mode)
	      {
		if($def_option_hash->{$opt}->{ADDED})
		  {
		    my $uh = getUsageHash($opt);
		    $uh->{DEFAULT_PRG} = 0;
		  }
		else
		  {$def_option_hash->{$opt}->{PARAMS}->{DEFAULT} = 0}
	      }
	  }
      }

    return($set);
  }

#Performs updates to the usage output for the run mode options
sub updateRunModeOptions
  {
    my $status           = getRunStatus(1); #Returns: ready(0), not_ready(1)
    my $hidden_hash      = {usage   => 0,
			    help    => 0,
			    run     => 0,
			    dry_run => 0};
    my $default_run_mode = getDefaultRunMode();

    if($status == 1) #Required opts exist without default values
      {
	if($default_run_mode eq 'usage' || $default_run_mode eq 'run')
	  {
	    $hidden_hash->{usage}  = 1;
	    $hidden_hash->{run}    = 1;
	  }
	elsif($default_run_mode eq 'dry_run')
	  {
	    $hidden_hash->{usage}    = 1;
	    $hidden_hash->{dry_run}  = 1;
	  }
	elsif($default_run_mode eq 'help')
	  {
	    $hidden_hash->{help}  = 1;
	    $hidden_hash->{run}   = 1;
	  }
      }
    elsif($status == 0) #No required opts or all reqd opts have defaults
      {
	if($default_run_mode eq 'run')
	  {
	    $hidden_hash->{run}     = 1;
	    $hidden_hash->{dry_run} = 0;
	  }
	elsif($default_run_mode eq 'dry_run')
	  {
	    $hidden_hash->{run}     = 0;
	    $hidden_hash->{dry_run} = 1;
	  }
	else
	  {
	    $hidden_hash->{run}     = 0;
	    $hidden_hash->{dry_run} = 0;
	  }

	if($default_run_mode eq 'help')
	  {
	    $hidden_hash->{usage} = 0;
	    $hidden_hash->{help}  = 1;
	  }
	elsif($default_run_mode eq 'usage')
	  {
	    $hidden_hash->{usage} = 1;
	    $hidden_hash->{help}  = 0;
	  }
	else
	  {
	    $hidden_hash->{usage} = 0;
	    $hidden_hash->{help}  = 0;
	  }
      }
    else #status=-1 - Reqd opts exist but we don't know if they all have values
      {
	$hidden_hash->{usage}   = 0;
	$hidden_hash->{help}    = 0;
	$hidden_hash->{run}     = 0;
	$hidden_hash->{dry_run} = 0;
      }

    #We have determined the run mode defaults above.  Now we need to set each
    #affected option's default.
    my $heading_added = 0;
    foreach my $opt (qw(usage help run dry_run))
      {
	my $uh = getUsageHash($opt);
	#If the programmer didn't explicitly set this option as hidden
	if(!defined($def_option_hash->{$opt}->{PARAMS}->{HIDDEN}))
	  {$uh->{HIDDEN} = $hidden_hash->{$opt}}
      }
  }

#Globals used: $exclusive_options, $mutual_params
sub makeMutuallyExclusive
  {
    my @in = getSubParams([qw(OPTIONIDS|OPTIONS REQUIRED OVERRIDABLE
                              NAME MUTUAL_PARAMS|MUTUALS)],
			  [qw(OPTIONS|OPTIONIDS)],[@_]);
    my $option_ids          = $in[0]; #Ref to array of option IDs
    my $reqd_defd           = defined($in[1]) ? 1 : 0;
    my $required            = defined($in[1]) ? $in[1] : 0;
    my $overridable         = defined($in[2]) ? $in[2] : 0;
			              #cmdln > usrdef > progdef.  This sets
			              #mutex conflicts as undef. Warning: has
			              #potential to be confusing due to
			              #unintended multiple overrides.
    my $mutex_name          = (defined($in[3]) ? $in[3] :
                               'custom ' . (scalar(@$exclusive_options) + 1));
    my $local_mutual_params = $in[4]; #A hash, like a usage hash

    my $dupecounts = {};
    if(defined($option_ids) && ref($option_ids) eq 'ARRAY')
      {$dupecounts->{$_}++ foreach(grep {defined($_)} @$option_ids)}

    #Check the array supplied
    if(!defined($option_ids) || ref($option_ids) ne 'ARRAY' ||
       scalar(@$option_ids) < 2 ||
       scalar(grep {!defined($_) || ref($_) ne '' || $_ !~ /^\d+$/ ||
		      $_ > $#{$usage_array}} @$option_ids) ||
       scalar(grep {$_ > 1} values(%$dupecounts)))
      {
	error('Invalid or no array reference of option IDs supplied to ',
              'makeMutuallyExclusive: [',
	      (defined($option_ids) ? (ref($option_ids) eq 'ARRAY' ?
				       join(',',map {defined($_) ? $_ : 'undef'}
					    @$option_ids) : ref($option_ids)) :
	       'undef'),"].",
	      {DETAIL => ('A reference to an array of option IDs with 2 or ' .
	                  'more option IDs, as obtained from the add*Option ' .
			  'methods, is required.' .
                          (scalar(grep {$_ > 1} values(%$dupecounts)) ?
                           '  Duplicate IDs supplied: [' .
                           join(',',grep {$dupecounts->{$_} > 1}
                                keys(%$dupecounts)) . '].' : ''))});

        $num_setup_errors++;

	#In case the user supplies --force
	return(undef);
      }

    my @has_defs =
      grep {hasValue($usage_array->[$_]->{OPTTYPE},
		     $usage_array->[$_]->{DEFAULT_PRG})} @$option_ids;
    #Make sure that only 1 (or 0) has a default value
    if(scalar(@has_defs) > 1)
      {
	error("Cannot define default values for multiple mutually exclusive ",
	      "options: [",join(',',map {$usage_array->[$_]->{OPTFLAG_DEF}}
				@has_defs),"].",
	      {DETAIL => ('Make sure that not only there was no DEFAULT ' .
			  'value supplied, but that the variable referenced ' .
			  'by the VARREF parameter has not been initialized ' .
			  'with a (default) value.  Note, run mode options ' .
			  'like --usage can be automatically defaulted.')});

        $num_setup_errors++;

	return(undef);
      }

    #Make sure that options in over-ridable mutex sets do not exist in any other
    #mutex sets
    if($overridable && scalar(@$exclusive_options))
      {
        my $ineligible = [grep {exists($exclusive_lookup->{$_})} @$option_ids];
        #Check to make sure none of these options are in any other mutex sets
        if(scalar(@$ineligible))
          {
            my $mutex_set_ids = {map {$_ => 1}
                                 map {keys(%{$exclusive_lookup->{$_}})}
                                 grep {exists($exclusive_lookup->{$_})}
                                 @$option_ids};
            error("Overlapping options [",
                  join(', ',
                       map {$usage_array->[$_]->{OPTFLAG_DEF}} @$ineligible),
                  "] detected in overridable mutually-exclusive option sets ",
                  "[(overridable set '$mutex_name': ",
                  join(', ',
                       map {$usage_array->[$_]->{OPTFLAG_DEF}} @$option_ids),
                  "); (",
                  join('); (',
                       map {my $ary = [@{$exclusive_options->[$_]}];
                            ($mutual_params->{$_}->{OVERRIDABLE} ? '' : 'un') .
                              "overridable set '$mutual_params->{$_}->{NAME}'" .
                                ': ' .
                                join(', ',
                                     map {$usage_array->[$_]->{OPTFLAG_DEF}}
                                     @$ary)} sort {$a <=> $b}
                       keys(%$mutex_set_ids)),")].",
                  {DETAIL => ('Either make all of the sets unoverridable ' .
                              '(meaning the override of default values must ' .
                              'be explicit) or edit your sets to not contain ' .
                              'options that are in other overridable ' .
                              'mutually exclusive sets.')});

            $num_setup_errors++;

            return(undef);
          }
      }
    elsif(!$overridable && scalar(grep {$mutual_params->{$_}->{OVERRIDABLE}}
                                  keys(%$mutual_params)))
      {
        #Check over-ridable mutex sets to make sure that none of these options
        #are included in an over-ridable mutex set
        my $mtx_hash = {map {$_ => 1} @$option_ids};
        my $ineligible = [];
        foreach my $optid (@$option_ids)
          {
            if(exists($exclusive_lookup->{$optid}))
              {
                my $osets = [grep {$mutual_params->{$_}->{OVERRIDABLE}}
                             keys(%{$exclusive_lookup->{$optid}})];
                if(scalar(@$osets))
                  {push(@$ineligible,[$optid,$osets])}
              }
          }
        if(scalar(@$ineligible))
          {
            error("Unable to make mutually exclusive option set: [",
                  join(', ',
                       map {$usage_array->[$_]->{OPTFLAG_DEF}} @$option_ids),
                  "].  1 or more contained options already belong to an over-",
                  "ridable mutually exclusive set.",
                  {DETAIL => 'Options in an over-ridable mutually exclusive ' .
                   'set are only allowed to belong to one set of mutually ' .
                   "exclusive options.\n" .
                   join(".\n",
                        map {my $i = $_;
                             ($usage_array->[$i->[0]]->{OPTFLAG_DEF}) .
                               ' belongs to over-ridable set(s) [[' .
                                 join('],[',
                                      map {my $s = $_;
                                           join(',',
                                                map {$usage_array->[$_]
                                                       ->{OPTFLAG_DEF}}
                                                @{$exclusive_options->[$s]})}
                                      @{$i->[1]}) . ']]'} @$ineligible) . '.'});

            $num_setup_errors++;

            return(undef);
          }
      }

    my $opts_reqd = [];
    my $opts_optl = [];
    foreach my $uh (map {$usage_array->[$_]} @$option_ids)
      {
        if($uh->{REQUIRED})
          {push(@$opts_reqd,$uh->{OPTFLAG_DEF})}
        else
          {push(@$opts_optl,$uh->{OPTFLAG_DEF})}
      }
    #If there's a conflict
    if(scalar(@$opts_reqd) && scalar(@$opts_optl))
      {
        my $reqmsg = 'required';
        if($reqd_defd && !$required)
          {$reqmsg = 'optional'}
        elsif(!$reqd_defd)
          {$required = 1}
        warning("Conflicting required values for mutually exclusive set ",
                "[$mutex_name]: required: [",join(' ',@$opts_reqd),
                "] optional: [",join(' ',@$opts_optl),'].',
                {DETAIL => 'All options will be made individually optional' .
                 ($required ? (' and one of this mutually exclusive set will ' .
                               'be required') : '') . '.'});
      }
    #Else if this method's required parameter is explicitly false and all of the
    #supplied options are individually required, issue an error
    elsif($reqd_defd && !$required && scalar(@$opts_reqd))
      {warning("Mutually exclusive set [$mutex_name]: [",join(' ',@$opts_reqd),
               "] is explicitly set as optional, but the individual options ",
               "are set as required.",
               {DETAIL => 'All options will be made individually optional.'})}
    elsif(!$reqd_defd && scalar(@$opts_reqd))
      {$required = 1}

    #Set the options' required values
    foreach my $uh (map {$usage_array->[$_]} @$option_ids)
      {$uh->{REQUIRED} = 0}

    my $exclusive_id = scalar(@$exclusive_options);
    push(@$exclusive_options,[@$option_ids]);

    #Save the mutual parameters that the set of options shares (e.g. REQUIRED)
    foreach my $optid (@$option_ids)
      {$exclusive_lookup->{$optid}->{$exclusive_id} = 1}

    #Save the mutual parameters that the set of options shares (e.g. REQUIRED)
    if(defined($local_mutual_params))
      {$mutual_params->{$exclusive_id} = $local_mutual_params}

    $mutual_params->{$exclusive_id}->{REQUIRED}    = $required;
    $mutual_params->{$exclusive_id}->{OVERRIDABLE} = $overridable;
    $mutual_params->{$exclusive_id}->{VALIDATED}   = 0;
    $mutual_params->{$exclusive_id}->{NAME}        = $mutex_name;

    #If all the options are builtin options, make this a builtin mutex set
    if(scalar(@$option_ids) ==
       scalar(grep {exists($def_option_hash->{$usage_array->[$_]
					      ->{USAGE_NAME}})} @$option_ids))
      {$mutual_params->{$exclusive_id}->{BUILTIN} = 1}
    else
      {$mutual_params->{$exclusive_id}->{BUILTIN} = 0}

    return($exclusive_id);
  }

sub optionIDToMutualParam
  {
    my $optid = (defined($_[0]) ? $_[0] : return(undef));
    my $param = (defined($_[1]) ? $_[1] : return(undef));

    if(exists($exclusive_lookup->{$optid}))
      {
	my @matching_exclids = (grep {exists($mutual_params->{$_}->{$param})}
				keys(%{$exclusive_lookup->{$optid}}));
	if(scalar(@matching_exclids) == 1)
	  {return($mutual_params->{$matching_exclids[0]}->{$param})}
	elsif(scalar(@matching_exclids) > 1)
	  {error("Option ID [$optid] is a member of multiple mutually ",
		 "exclusive groups with parameter [$param] set.",
		 {DETAIL => ('Use the exclusive set ID to retrieve this ' .
			     'parameter value.')})}
	else
	  {warning("Option ID [$optid] is not a member of a mutually ",
		   "exclusive group or else no group has parameter [$param].")}
      }
    else
      {warning("Option ID [$optid] is not part of a mutually exclusive group.")}

    return(undef);
  }

sub exclusiveOptSupplied
  {
    my $option_id = $_[0];

    #Command line has to have been processed
    if(!$command_line_stage >= ARGSREAD)
      {
	error("Invalid call of exclusiveOptSupplied.  Command line must be ",
	      "processed first.");
	quit(-16);
      }

    if(!exists($exclusive_lookup->{$option_id}))
      {return(0)}

    #An option can belong to mutliple mutually exclusive groups
    foreach my $exclusive_id (keys(%{$exclusive_lookup->{$option_id}}))
      {
	#For each neighboring option in the exclusive group
	foreach my $mutual_optid (grep {$_ != $option_id}
				  @{$exclusive_options->[$exclusive_id]})
	  {return(1) if($usage_array->[$mutual_optid]->{SUPPLIED})}
      }

    return(0);
  }

#Globals used: $genopt_types, $exclusive_lookup, $exclusive_options
sub exclusiveOptUserDefaulted
  {
    my $opt_hash  = $_[0];
    my $option_id = $opt_hash->{OPTION_ID};

    #Command line has to have been processed
    if(!$command_line_stage >= ARGSREAD)
      {
	error("Invalid call of exclusiveOptSupplied.  Command line must be ",
	      "processed first.");
	quit(-41);
      }

    if(!exists($exclusive_lookup->{$option_id}))
      {return(0)}

    #An option can belong to mutliple mutually exclusive groups
    foreach my $exclusive_id (keys(%{$exclusive_lookup->{$option_id}}))
      {
	#If a neighboring option in the exclusive group has a default
	if(scalar(grep {$_ != $option_id && hasDefault($usage_array->[$_])}
		  @{$exclusive_options->[$exclusive_id]}))
	  {return(1)}
      }

    return(0);
  }

#This adds all the builtin options like verbose, overwrite, etc. if they have
#not already been added by the programmer.  It also adds/modifies headings to
#the usage.  All these options are highly integrated into all functionality and
#cannot be disabled.
#Globals used: $user_collide_mode,$def_collide_mode,$def_option_hash
sub addBuiltinOptions
  {
    editBuiltinOptions();

    my $errors = 0;
    my $saved_heading = '';
    foreach my $opt (qw(verbose quiet overwrite skip header version force debug
			pipeline error_lim append collision save_args extended))
      {
        if($def_option_hash->{$opt}->{ADDED})
          {
            if(exists($def_option_hash->{$opt}->{PARAMS}->{HEADINGBACKUP}) &&
               defined($def_option_hash->{$opt}->{PARAMS}->{HEADINGBACKUP}) &&
               $def_option_hash->{$opt}->{PARAMS}->{HEADINGBACKUP} ne '')
              {$saved_heading =
                 $def_option_hash->{$opt}->{PARAMS}->{HEADINGBACKUP}}
          }
        else
          {
            if($def_option_hash->{$opt}->{PARAMS}->{HEADING} eq '' &&
               $saved_heading ne '')
              {$def_option_hash->{$opt}->{PARAMS}->{HEADING} = $saved_heading}
            $saved_heading = '';

            if(!defined(addBuiltinOption($opt)))
              {$errors++}
          }
      }

    if($def_option_hash->{quiet}->{ADDED} && $def_option_hash->{debug}->{ADDED})
      {
        #Set the mutually exclusive options included in the builtins
        #quiet versus verbose and debug
        my $quiet_debug_opts = [$usage_lookup->{quiet}->{OPTION_ID},
                                $usage_lookup->{debug}->{OPTION_ID}];
        my $qdid = makeMutuallyExclusive(OPTIONIDS => $quiet_debug_opts,
                                         NAME      => 'quiet/debug');
        if(!defined($qdid))
          {
            #Make sure quiet default is 0 if there was a problem so errors print
            $usage_lookup->{quiet}->{DEFAULT_PRG} = 0;
            $errors++;
          }
      }
    else
      {$errors++}

    if($def_option_hash->{quiet}->{ADDED} &&
       $def_option_hash->{verbose}->{ADDED})
      {
        my $quiet_verbose_opts = [$usage_lookup->{quiet}->{OPTION_ID},
                                  $usage_lookup->{verbose}->{OPTION_ID}];
        my $qvid = makeMutuallyExclusive(OPTIONIDS => $quiet_verbose_opts,
                                         NAME      => 'quiet/verbose');
        #Make sure quiet default is 0 if there was a problem so errors are
        #printed
        unless(defined($qvid))
          {
            $usage_lookup->{quiet}->{DEFAULT_PRG} = 0;
            $errors++;
          }
      }
    else
      {$errors++}

    if($def_option_hash->{skip}->{ADDED} &&
       $def_option_hash->{append}->{ADDED} &&
       $def_option_hash->{overwrite}->{ADDED})
      {
        #overwrite versus skip versus append
        my $existing_out_opts = [$usage_lookup->{skip}->{OPTION_ID},
                                 $usage_lookup->{overwrite}->{OPTION_ID},
                                 $usage_lookup->{append}->{OPTION_ID}];
        my $soaid = makeMutuallyExclusive(OPTIONIDS => $existing_out_opts,
                                          NAME      => 'output modes');
        if(!defined($soaid))
          {$errors++}
      }
    else
      {$errors++}

    #If there were errors adding run mode options
    if(addRunModeOptions())
      {$errors++}

    if(!defined($builtin_add_failures) || $builtin_add_failures)
      {
	if(!$error_number)
	  {error("Unknown error occurred.")}
	elsif(defined($builtin_add_failures))
	  {error("CommandLineInterface config error: Unable to complete set ",
		 "up due to custom parameters used for builtin options.  ",
		 "Please address the errors described above.")}
        $errors++;
      }

    return($errors);
  }

#This method mainly looks for options already added by the user and implicitly
#over-rides every mutually exclusive option.  E.g. If they call
#editHelpOption(DEFAULT => 1), both usage (the class default) and help will have
#programmer defaults and will cause a fatal error
sub editBuiltinOptions
  {
    #This creates a lookup of builtin option name to an array of mutex set
    #arrays it belongs to.  This will allow us to check each added option's sets
    my $mns_lookup = {};
    foreach my $mutex_name_set (values(%$builtin_mutexes))
      {foreach my $bi_name (@$mutex_name_set)
	 {push(@{$mns_lookup->{$bi_name}},$mutex_name_set)}}

    #For each builtin option that has been customized, has a default, and whose
    #default is editable
    foreach my $bi_name (grep {$def_option_hash->{$_}->{CHANGED} &&
				 hasValue($def_option_hash->{$_}
					  ->{PARAMS}->{TYPE},
					  $def_option_hash->{$_}
					  ->{PARAMS}->{DEFAULT}) &&
			         scalar(grep {$_ eq 'DEFAULT'}
					@{$def_option_hash->{$_}->{EDITABLE}})}
			 keys(%$def_option_hash))
      {
	#Cycle through all of its mutually exclusive partner groups which may
	#have a class default among them
	foreach my $mns (@{$mns_lookup->{$bi_name}})
	  {
	    #Got through those that have not been customized, but have a default
	    #and unset them so they don't conflict with the class default
	    #(yes, whether it's editable or not)
	    foreach my $ucbi_name (grep {!$def_option_hash->{$_}->{CHANGED} &&
					   hasValue($def_option_hash->{$_}
						    ->{PARAMS}->{TYPE},
						    $def_option_hash->{$_}
						    ->{PARAMS}->{DEFAULT})}
				   @$mns)
	      {$def_option_hash->{$ucbi_name}->{PARAMS}->{DEFAULT} = undef}
	  }
      }
  }

sub getDesc
  {
    my $opt   = $_[0];
    my $short = $_[1];
    my $desc  = '';
    my $opts  = ['extended','verbose','quiet','overwrite','skip','header',
		 'version','force','debug','collision','save_args','error_lim',
		 'append','pipeline','run','dry_run','usage','help'];

    if(!defined($opt))
      {
	error('Invalid built-in option: [',(defined($opt) ? $opt : 'undef'),
	      '].',
	      {DETAIL => ('Must be one of [' . join(',',@$opts) . ']')});
	return('');
      }
    elsif($opt eq 'extended')
      {
	if($short)
	  {$desc = 'Print detailed usage/help/version/header/errors/warnings.'}
	else
	  {
	    $desc = << 'end_desc';
Print extended usage/help/version/header (and errors/warnings where noted).
end_desc
	  }
      }
    elsif($opt eq 'verbose')
      {
	if($short)
	  {$desc = ''}
        else
	  {$desc = 'Verbose mode.'}
      }
    elsif($opt eq 'quiet')
      {
	if($short)
	  {$desc = ''}
        else
	  {$desc = 'Quiet mode.'}
      }
    elsif($opt eq 'overwrite')
      {
	if($short)
	  {$desc = ''}
        else
	  {
	    $desc = << 'end_desc';
Overwrite existing output files.  By default, existing output files will not be over-written.
end_desc
	  }
      }
    elsif($opt eq 'skip')
      {
	if($short)
	  {$desc = ''}
        else
	  {
	    $desc = << 'end_desc';
Skip existing output files.
end_desc
	  }
      }
    elsif($opt eq 'header')
      {
	if($short)
	  {$desc = ''}
        else
	  {
	    $desc = << 'end_desc';
Outfile header flag.  Headers are commented with '#' and include script version, date, and command line call at the top of every output file.  See --extended.
end_desc
	  }
      }
    elsif($opt eq 'version')
      {
	if($short)
	  {$desc = ''}
        else
	  {$desc = 'Print version info.  See --extended.'}
      }
    elsif($opt eq 'force')
      {
	if($short)
	  {$desc = ''}
        else
	  {
	    $desc = << 'end_desc';
Prevent script-exit upon fatal error.  Use with extreme caution.  Will not override overwrite protection (see --overwrite or --skip).
end_desc
	  }
      }
    elsif($opt eq 'debug')
      {
	if($short)
	  {$desc = ''}
        else
	  {
	    $desc = << 'end_desc';
Debug mode.  Prepends trace to warning/error messages.  Prints debug() messages based on debug level.  Values less than 0 debug the CommandLineInterface module used by this script.
end_desc
	  }
      }
    elsif($opt eq 'save_args')
      {
	if($short)
	  {$desc = 'Save accompanying command line arguments as user defaults.'}
        else
	  {
	    $desc = << 'end_desc';
Save accompanying command line arguments as defaults to be used in every call of this script.  Replaces previously saved args.  Supply without other args to removed saved args.  When there are no user defaults set, this option will only appear in the advanced usage (--extended 2).
end_desc
	  }
      }
    elsif($opt eq 'pipeline')
      {
	if($short)
	  {$desc = ''}
        else
	  {
	    $desc = << 'end_desc';
Supply --pipeline to include the script name in errors, warnings, and debug messages.  If not supplied (and no default set), the script will automatically determine if it is running within a series of piped commands or as a part of a parent script.  Note, supplying either flag will prevent that check from happening.
end_desc
	  }
      }
    elsif($opt eq 'error_lim')
      {
	if($short)
	  {$desc = ''}
        else
	  {
	    $desc = << 'end_desc';
Limits each type of error/warning to this number of outputs.  Intended to declutter output.  Note, a summary of warning/error types is printed when the script finishes, if one occurred or if in verbose mode.  0 = no limit.  See also --quiet.
end_desc
	  }
      }
    elsif($opt eq 'append')
      {
	if($short)
	  {$desc = ''}
        else
	  {
	    $desc = << 'end_desc';
Append mode.  Appends output to all existing output files instead of skipping or overwriting them.  This is useful for checkpointed jobs on a cluster.
end_desc
	  }
      }
    elsif($opt eq 'run')
      {
	if($short)
	  {$desc = 'Run the script.'}
        else
	  {
	    $desc = << 'end_desc';
This option runs the script.  It is only necessary to supply this option if the script contains no required options or when all required options have default values that are either hard-coded, or provided via --save-args.
end_desc
	  }
      }
    elsif($opt eq 'dry_run')
      {
	if($short)
	  {$desc = ''}
        else
	  {$desc = 'Run without generating output files.'}
      }
    elsif($opt eq 'usage')
      {
	if($short)
	  {$desc = ''}
        else
	  {$desc = 'Print this usage message.'}
      }
    elsif($opt eq 'help')
      {
	if($short)
	  {$desc = 'Print general info and file formats.'}
        else
	  {
	    $desc = << 'end_desc';
Print general info and file format descriptions.  Includes advanced usage examples with --extended.
end_desc
	  }
      }
    elsif($opt =~ /^collision/)
      {
	if($short)
	  {$desc = ''}
        else
	  {
	    my $cd = (#Case 1: User default (set via --save-args)
		      defined($user_collide_mode) ? '' :
		      (#Case 2: Programmer default (set via setDefaults)
		       defined($def_collide_mode) ? '' :
		       #Case 3: Default depends on out type
		       "\n\n* The default differs based on whether the " .
		       "output file is specified by an outfile suffix (in " .
		       "which case the default is [$def_collide_mode_suff]) " .
		       "or by a full output file name (in which case the " .
		       "default is [$def_collide_mode_outf])."));
	    $desc = << "end_desc";
DEPRECATED.  When multiple input files output to the same output file, this option specifies what to do.  Merge mode will concatenate output in the common output file.  Rename mode (valid only if this script accepts multiple types of input files) will create a unique output file name by appending a unique combination ofinput file names together (with a delimiting dot).  Rename mode will throw an error if a unique file name cannot be constructed (e.g. when 2 input files of the same name in different directories are outputting to a common directory).  Error mode causes the script to quit with an error if multiple input files are detected to output to the same output file.$cd\n\nTHIS OPTION IS DEPRECATED AND HAS BEEN REPLACED BY 'SUPPLYING COLLISION MODE VIA addOutFileSuffixOptionAND addOutfileOption.  THIS OPTION HOWEVER WILL OVERRIDE THE COLLISION MODE OF ALL OUTFILE OPTIONS AND APPLY TO FILES THAT ARE NOT DEFINED BY addOutFileSuffixOption OR addOutfileOption IF OPENED MULTIPLE TIMES UNLESS SET EXPLICITLY IN THE openOut CALL.
end_desc
	  }
      }
    else
      {
	error("Invalid built-in option: [$opt].",
	      {DETAIL => ('Must be one of [' . join(',',@$opts) . ']')});
	return('');
      }

    return($desc);
  }

#This sub mainly adds little details to the usage and help output to explain
#various built-in behaviors, relationships, and settings.  Should only be
#called once.  E.g. It appends the location of the defaults_dir to the
#--save-args usage.
sub applyOptionAddendums
  {
    my $extended = getVarref('extended',1,1);

    #This must be set after user defaults have been loaded so that the usage can
    #display the user-set defaults
    $usage_lookup->{collision}->{DISPDEF} =
      (#Case 1: User default (set via --save-args)
       defined($user_collide_mode) ? $user_collide_mode :
       (#Case 2: Programmer default (set via setDefaults)
	defined($def_collide_mode) ? $def_collide_mode :
	#Case 3: Default depends on out type
	"$def_collide_mode_suff|$def_collide_mode_outf*"));

    #Update --save-args to show user defaults
    my $defdir = (defined($defaults_dir) ?
		  $defaults_dir : (sglob('~/.rpst',1))[0]);
    $defdir = 'undefined' if(!defined($defdir));
    my $saveargs_usg = getUsageHash('save_args');
    my $user_defaults = getUserDefaults();
    if(scalar(@$user_defaults))
      {
	$saveargs_usg->{ADVANCED} = 0;
	$saveargs_usg->{DISPDEF}  = join(' ',quoteArgs($user_defaults));
      }
    else
      {
	$saveargs_usg->{ADVANCED} = 1;
	$saveargs_usg->{DISPDEF}  = undef;
      }
    $saveargs_usg->{DETAILS} .= "  Values are stored in [$defdir].";

    updateRunModeOptions();

    #Append overwrite's outdir abilities if an outdir option exists
    my $odf = getOutdirFlag();
    if(defined($odf) && $odf ne '')
      {
	my $overwrite_usg = getUsageHash('overwrite');
	$overwrite_usg->{DETAILS} .=
	  join('',('  Supply twice to safely remove pre-existing output ',
		   "directories (See $odf).  This will not remove a directory ",
		   'containing manually touched files.'));
      }

    #Build 1 list of exclusive options per option (an option may belong to
    #multiple mutually exclusive sets)
    my $exclusives = {};
    foreach my $excl_id (0..$#{$exclusive_options})
      {
	foreach my $opt1idx (0..$#{$exclusive_options->[$excl_id]})
	  {
	    my $optid1 = $exclusive_options->[$excl_id]->[$opt1idx];
	    foreach my $opt2idx
	      (($opt1idx + 1)..$#{$exclusive_options->[$excl_id]})
	      {
		my $optid2 = $exclusive_options->[$excl_id]->[$opt2idx];
		$exclusives->{$optid1}->{$optid2} = 1;
		$exclusives->{$optid2}->{$optid1} = 1;
	      }
	  }
      }

    ##
    ## Make sure non-tagteamed outfile types are not hidden when required, non-
    ## primary, and un-defaulted.  This must be done before cross-referencing so
    ## that un-hidden options can be referenced.
    ##

    foreach my $usg (grep {$_->{OPTTYPE} =~ /^(outfile|suffix|logfile|logsuff)$/
                             && !$_->{TAGTEAM} && $_->{HIDDEN} && $_->{REQUIRED}
                               && !$_->{PRIMARY} && !hasDefault($_)}
                     @$usage_array)
      {
        warning('Cannot hide [',getBestFlag($usg),'] when required',
                ($usg->{OPTTYPE} =~ /^(outfile|suffix)$/ ? ', not primary ' .
                 "(i.e. doesn't take input on standard in)" : ''),
                ' and no default provided.  Unhiding.');
        $usg->{HIDDEN} = 0;
      }

    #Append a mutually exclusive message to the detailed usage descriptions
    foreach my $optid (keys(%$exclusives))
      {
	my $uh    = $usage_array->[$optid];
	my @flags = map {$usage_array->[$_]->{OPTFLAG_DEF}}
	  grep {($usage_array->[$_]->{HIDDEN} && $extended > 2) ||
                  (((!$usage_array->[$_]->{HIDDEN} &&
                     $usage_array->[$_]->{ADVANCED})) && $extended > 1) ||
                       (!$usage_array->[$_]->{HIDDEN} &&
                        !$usage_array->[$_]->{ADVANCED})}
	    keys(%{$exclusives->{$optid}});
	my @reqd_memberships =
	  grep {exists($mutual_params->{$_}) &&
		  exists($mutual_params->{$_}->{REQUIRED}) &&
		    $mutual_params->{$_}->{REQUIRED}}
	    keys(%{$exclusive_lookup->{$optid}});


	#If there is no mention of 'mutually exclusive' flags
	if(scalar(@flags) && $uh->{DETAILS} !~ /mutually exclusive/i)
	  {
	    $uh->{DETAILS} .=
	      ($uh->{DETAILS} =~ /\n\n/ ? "\n\n" :
	       ($uh->{DETAILS} =~ /\n/ ? "\n" : '  ')) .
		 'Mutually exclusive with [' . join(', ',@flags) . ']';

	    #Handle conditionally required (i.e. one of a mutually exclusive set
	    #is required)
	    if(scalar(keys(%{$exclusive_lookup->{$optid}})) == 1 &&
	       scalar(@reqd_memberships))
	      {$uh->{DETAILS} .= ', one of which is required.'}
	    elsif(scalar(keys(%{$exclusive_lookup->{$optid}})) > 1 &&
		  scalar(@reqd_memberships))
	      {
		foreach my $mutexid (@reqd_memberships)
		  {
		    my @rflags = map {$usage_array->[$_]->{OPTFLAG_DEF}}
		      grep {($usage_array->[$_]->{HIDDEN} &&
			     $usage_array->[$_]->{ADVANCED} && $extended > 2) ||
			       ((($usage_array->[$_]->{HIDDEN} &&
				  !$usage_array->[$_]->{ADVANCED}) ||
				 (!$usage_array->[$_]->{HIDDEN} &&
				  $usage_array->[$_]->{ADVANCED})) &&
				$extended > 1) ||
				  (!$usage_array->[$_]->{HIDDEN} &&
				   !$usage_array->[$_]->{ADVANCED})}
			@{$exclusive_options->[$mutexid]};
		    if(scalar(@rflags) > 1)
		      {$uh->{DETAILS} .=
			 '.  One of [' . join(', ',@rflags) . '] is required'}
		  }
                $uh->{DETAILS} .= '.';
	      }
	    else
	      {$uh->{DETAILS} .= '.'}
	  }
      }
  }

sub quoteArgs
  {
    my $arg_array = $_[0];
    my $str_array = [];

    foreach my $arg (@$arg_array)
      {
	if($arg =~ /(?<!\\)[\s\*"']/ || $arg =~ /^<|>|\|(?!\|)/ ||
	   $arg eq '' || $arg =~ /[\{\}\[\]\(\)]/)
	  {
	    if($arg =~ /(?<!\\)["]/)
	      {$arg = "'" . $arg . "'"}
	    else
	      {$arg = '"' . $arg . '"'}
	  }

	push(@$str_array,$arg);
      }

    return(wantarray ? @$str_array : $str_array);
  }

sub determineRunMode
  {
    my $determine_default_run_mode  = (defined($_[0]) ? $_[0] : 0);
    #This indicates whether a default infile name for a required infile type was
    #found to be missing in the file system or had a permissions error, etc.
    my $file_system_error           = (defined($_[1]) ? $_[1] : 0);

    #If the user explicitly set the run mode, there's nothing to be done
    if(setUserRunMode($determine_default_run_mode))
      {return()}

    my $mode = getRunMode($determine_default_run_mode,$file_system_error);

    my $usgref = getVarref('usage',  0,1);
    my $hlpref = getVarref('help',   0,1);
    my $runref = getVarref('run',    0,1);
    my $drnref = getVarref('dry_run',0,1);

    $$runref = 0;
    $$drnref = 0;
    $$usgref = 0;
    $$hlpref = 0;

    if($mode eq 'run')
      {$$runref = 1}
    elsif($mode eq 'dry-run')
      {$$drnref = 1}
    elsif($mode eq 'usage')
      {$$usgref = 1}
    elsif($mode eq 'help')
      {$$hlpref = 1}
    elsif($mode eq 'error')
      {$$usgref = 2}

    if((($$hlpref ? 1 : 0) + ($$usgref ? 1 : 0) + ($$runref ? 1 : 0) +
	($$drnref ? 1 : 0)) > 1)
      {error("Internal error(1): Ambiguous run mode.",
	     {DETAIL =>
	      "help:$$hlpref, usage:$$usgref, run:$$runref, dry-run:$$drnref"})}

    debug({LEVEL => -1},"Values of: --usage $$usgref --run $$runref --dry-run ",
	  "$$drnref --help $$hlpref.");

    return($mode);
  }

sub getRunMode
  {
    my $determine_default_run_mode = (defined($_[0]) ? $_[0] : 0);
    #This indicates whether a default infile name for a required infile type was
    #found to be missing in the file system or had a permissions error, etc.
    my $file_system_error          = (defined($_[1]) ? $_[1] : 0);

    #If the user explicitly set the run mode, there's nothing to be done
    my $user_mode = getUserRunMode($determine_default_run_mode);

    if(defined($user_mode))
      {return($user_mode)}

    my $real_args = $determine_default_run_mode ? 0 : argsOrPipeSupplied();
    my $status    = getRunStatus($determine_default_run_mode);

    debug({LEVEL => -1},"Default? [$determine_default_run_mode] Run status: ",
	  "[$status].");

    my($mode);
    my $default_run_mode = getDefaultRunMode();

    if($default_run_mode eq 'run')
      {
	if($status == 0) #No required opts or all have values - proceed
	  {$mode = 'run'}
	else #Required opts not supplied
	  {
	    #Set to run and expect an error if default files for a required
	    #option do not exist, e.g. file not found or permission error
	    if($file_system_error)
	      {$mode = 'run'}
	    elsif(!$real_args) #No opts supplied
	      {$mode = 'usage'}
	    else
	      {$mode = 'error'}
	  }
      }
    elsif($default_run_mode eq 'dry_run')
      {
	if($status == 0) #No required opts or all have values
	  {$mode = 'dry-run'}
	else #Required opts not supplied
	  {
	    if(!$real_args) #No opts supplied
	      {$mode = 'usage'}
	    else
	      {$mode = 'error'}
	  }
      }
    elsif($default_run_mode eq 'usage')
      {
	if($status == 0) #No required opts or all have values
	  {
	    if($real_args)
	      {$mode = 'run'}
	    else
	      {$mode = 'usage'}
	  }
	else #Required opts not supplied
	  {
	    if(!$real_args) #No opts supplied
	      {$mode = 'usage'}
	    else
	      {$mode = 'error'}
	  }
      }
    elsif($default_run_mode eq 'help')
      {
	if($status == 0) #No required opts or all have values
	  {
	    if($real_args)
	      {$mode = 'run'}
	    else
	      {$mode = 'help'}
	  }
	else #Required opts not supplied
	  {
	    if(!$real_args) #No opts supplied
	      {$mode = 'help'}
	    else
	      {$mode = 'error'}
	  }
      }

    return($mode);
  }

#This sub determines whether it's possible to run the script, whether it's
#before the command line has been processed or after.  To do this, it determines
#whether required options without (global or user) default or command-line
#supplied values exist.  Assumes all options have been added.
#Returns 0 = ready to run or 1 = not ready to run
sub getRunStatus
  {
    my $defaults_only = (defined($_[0]) ? $_[0] : 0);

    foreach my $usg_hash (grep {$_->{REQUIRED}} @$usage_array)
      {
	#If this is a general option type
	if(exists($genopt_types->{$usg_hash->{OPTTYPE}}))
	  {if(!isRequiredGeneralOptionSatisfied($usg_hash,$defaults_only))
	     {return(1)}}
	#Else if this is an outdir
	elsif($usg_hash->{OPTTYPE} eq 'outdir')
	  {
	    #TODO: Add support for more outdir types.  See req 212
	    #Currently only 1 outdir type is supported.
	    if(#There's no user default
	       (!defined($usg_hash->{DEFAULT_USR}) ||
		scalar(@{$usg_hash->{DEFAULT_USR}}) == 0) &&
	       #There's no programmer default
	       (!defined($usg_hash->{DEFAULT_PRG}) ||
		scalar(@{$usg_hash->{DEFAULT_PRG}}) == 0) &&
	       #The command line has not yet been processed or there's none
	       #supplied on the command line
	       ($defaults_only || $command_line_stage < ARGSREAD ||
		!$usg_hash->{SUPPLIED} ||
		scalar(@{getVarref($usg_hash,0,1)}) == 0))
	      {return(1)}
	  }
	#Else if this is an outfile or infile (same structure)
	elsif($usg_hash->{OPTTYPE} eq 'outfile' ||
	      $usg_hash->{OPTTYPE} eq 'infile'  ||
	      $usg_hash->{OPTTYPE} eq 'stub')
	  {
	    if(#There's no user default
	       (!defined($usg_hash->{DEFAULT_USR}) ||
		scalar(@{$usg_hash->{DEFAULT_USR}}) == 0) &&
	       #There's no programmer default
	       (!defined($usg_hash->{DEFAULT_PRG}) ||
		scalar(@{$usg_hash->{DEFAULT_PRG}}) == 0) &&
	       #The command line has not yet been processed or there's none
	       #supplied on the command line
	       ($defaults_only || $command_line_stage < ARGSREAD ||
		!$usg_hash->{SUPPLIED} ||
		scalar(@{getVarref($usg_hash,0,1)}) == 0))
	      {return(1)}
	  }
	elsif(exists($scalar_fileopt_types->{$usg_hash->{OPTTYPE}}))
	  {
	    if(#There's no user default
	       (!defined($usg_hash->{DEFAULT_USR}) ||
		!defined($usg_hash->{DEFAULT_USR})) &&
	       #There's no programmer default
	       (!defined($usg_hash->{DEFAULT_PRG}) ||
		!defined($usg_hash->{DEFAULT_PRG})) &&
	       #The command line has not yet been processed or there's none
	       #supplied on the command line
	       ($defaults_only || $command_line_stage < ARGSREAD ||
		!$usg_hash->{SUPPLIED} ||
		!defined(getVarref($usg_hash,1,1))))
	      {return(1)}
	  }
      }

    return(0);
  }

#Globals used: $GetOptHash
sub loadUserDefaults
  {
    my @user_defaults = getUserDefaults();
    my $status        = 0; #0=success

    if(scalar(@user_defaults) == 0)
      {return($status)}

    debug({LEVEL => -1},"Loading user defaults: [",join(' ',@user_defaults),
	  "].");

    #Suppress warnings from GetOptionsFromArray if we're not in a run mode
    my $orig_sig_warn = $SIG{__WARN__};
    my $warn_buffer   = [];
    $SIG{__WARN__}    = sub {push(@$warn_buffer,[@_])};

    #Set the getopt_default_mode global for the getopt subs
    $getopt_default_mode = 1;

    #Get the input options & catch any errors in option parsing
    if(!GetOptionsFromArray([@user_defaults],%$GetOptHash))
      {
        undef($getopt_default_mode);

        my $fallbacks_hash = getBuiltinFallbacks();
        my $arun_mode =
          ($fallbacks_hash->{run} || $fallbacks_hash->{dry_run}) ? 1 : 0;

        #If this is a run mode and (bad default values aren't over-ridden on the
        #command line or there were unrecognized flags)
	if($arun_mode &&
           (!areBadOptValsReplaced(undef,0) || areThereBadFlags($warn_buffer)))
	  {
            $status = 1;

	    if(scalar(@$warn_buffer))
	      {$orig_sig_warn->(@$_) foreach(@$warn_buffer)}

	    error('Getopt::Long::GetOptionsFromArray reported an error while ',
		  'parsing the user default arguments [',
		  join(' ',quoteArgs(\@user_defaults)),'].  The warning ',
		  'should be above.  Please remove the offending argument(s) ',
		  'by setting new defaults with --save-args and try again.');
            $SIG{__WARN__} = $orig_sig_warn;
	    quit(-9,0);
	  }
      }

    undef($getopt_default_mode);

    $SIG{__WARN__} = $orig_sig_warn;

    return($status);
  }

#This method checks if options whose user defaults are bad were explicitly
#supplied (i.e. replaced) by values on the command line
#This doesn't currently work for flagless-supplied options
#Globals used: $bad_user_opts, $active_args
sub areBadOptValsReplaced
  {
    my @bad_opt_hashes = (scalar(@_) > 0 && defined($_[0]) && scalar(@{$_[0]}) ?
                          @{$_[0]} : @$bad_user_opts);
    my $defaulted      = (scalar(@_) > 1 && defined($_[1]) ?
                          $_[1] : $command_line_stage >= DEFAULTED);

    #Create a hash of the strings from the command line
    my $stop = 0;
    my $arg_hash = {map {$_ => 1} grep {$stop = 1 if($_ eq '--');!$stop}
                    @$active_args};

    #If user defaults are not done (i.e. we're evaluating whether user defaults
    #are replaced on the command line) and the --save-args flag was supplied,
    #then all options are being replaced, whether they're on the command line or
    #not
    if(!$defaulted &&
       #User defaults are being replaced
       scalar(grep {exists($arg_hash->{$_})}
              @{$usage_lookup->{save_args}->{OPTFLAGS}}))
      {return(1)}

    #For each option that has an invalid user default value
    foreach my $opt_hash (@bad_opt_hashes)
      {
	my $replaced = 0;

	#For each flag of the option whose user default is bad
	foreach my $flag (@{$opt_hash->{OPTFLAGS}})
	  {
	    #If the flag exists on the command line
	    if(exists($arg_hash->{$flag}))
	      {
		$replaced = 1;
		last;
	      }
	  }

	#If this option was not supplied on the command line to replace the bad
	#user default, return false
	if(!$replaced)
	  {return(0)}
      }

    return(1);
  }

#Checks Getopt::Long warnings to see if it complains of an "Unknown option"
sub areThereBadFlags
  {
    my $gol_warnings = $_[0];
    return(scalar(grep {/Unknown option/} map {@$_} @$gol_warnings));
  }

#This gets the run mode based on flags supplied either on the command
#line or from user defaults.  If requested, it will get the run mode only from
#the user defaults and ignore the command line.
#Globals used: $command_line_stage
sub getUserRunMode
  {
    my $determine_default_run_mode = (defined($_[0]) ? $_[0] : 0);

    my($mode);
    my $usrdefopts           = [];
    my $cmdlnopts            = [];
    my $active_run_mode_opts = [];

    #If we're looking for an explicitly supplied mode and the command line has
    #not yet been parsed
    if(!$determine_default_run_mode && $command_line_stage < ARGSREAD)
      {
	my $mode_flags_hash =
	  {map {my $n = $_; map {$_ => $n} @{$usage_lookup->{$n}->{OPTFLAGS}}}
	   qw(help usage run dry_run)};
	if(scalar(grep {exists($mode_flags_hash->{$_})} @$active_args) == 1)
	  {foreach my $name (map {$mode_flags_hash->{$_}}
			     grep {exists($mode_flags_hash->{$_})}
			     @$active_args)
	     {push(@$cmdlnopts,getUsageHash($name))}}
      }
    #Else if we're looking for an explicitly supplied mode and the command line
    #has been processed
    elsif(!$determine_default_run_mode)
      {foreach my $uh (map {getUsageHash($_)}
		       qw(run dry_run usage help))
	 {if($uh->{SUPPLIED})
	    {push(@$cmdlnopts,$uh)}}}

    #Get the user defaults (assuming they have been loaded)
    foreach my $uh (map {getUsageHash($_)}
		    qw(run dry_run usage help))
      {if(defined($uh->{DEFAULT_USR}) && $uh->{DEFAULT_USR})
	 {push(@$usrdefopts,$uh)}}

    #Defer to the explicitly supplied options from the command line
    if(scalar(@$cmdlnopts))
      {$active_run_mode_opts = $cmdlnopts}
    elsif(scalar(@$usrdefopts))
      {$active_run_mode_opts = $usrdefopts}

    if(scalar(@$active_run_mode_opts) == 1)
      {
	my $uh = $active_run_mode_opts->[0];

	if($uh->{USAGE_NAME} eq 'run')
	  {$mode = 'run'}
	elsif($uh->{USAGE_NAME} eq 'dry_run')
	  {$mode = 'dry-run'}
	elsif($uh->{USAGE_NAME} eq 'help')
	  {$mode = 'help'}
	elsif($uh->{USAGE_NAME} eq 'usage')
	  {$mode = 'usage'}
      }
    else
      {debug({LEVEL => -1},scalar(@$active_run_mode_opts),
	     " run mode options are set.")}

    return($mode);
  }

sub getSavedUserRunMode
  {
    my $user_defaults_array = getUserDefaults();

    my $run_mode_flags_hash = {};
    foreach my $uhash (map {$usage_lookup->{$_}} qw(usage help run dry_run))
      {foreach my $flag (@{$uhash->{OPTFLAGS}})
	 {$run_mode_flags_hash->{$flag} = ($uhash->{USAGE_NAME} eq 'dry_run' ?
					   'dry-run' : $uhash->{USAGE_NAME})}}

    my $modes_hash = {};
    foreach my $arg (@$user_defaults_array)
      {if(exists($run_mode_flags_hash->{$arg}))
	 {$modes_hash->{$run_mode_flags_hash->{$arg}}++}}

    my($mode);
    if(scalar(keys(%$modes_hash)) > 1)
      {error("Ambiguous run modes among user-saved arguments: [",
	     join(',',keys(%$run_mode_flags_hash)),"].")}
    elsif(scalar(keys(%$modes_hash)) == 1)
      {$mode = (keys(%$modes_hash))[0]}

    return($mode);
  }

#This sets the run mode based on flags supplied either on the command
#line or from user defaults.  If requested, it will set the run mode only from
#the user defaults and ignore the command line.
sub setUserRunMode
  {
    my $determine_default_run_mode = (defined($_[0]) ? $_[0] : 0);

    my $setit = 0;
    my $mode  = getUserRunMode($determine_default_run_mode);

    my $usgref = getVarref('usage',  0,1);
    my $hlpref = getVarref('help',   0,1);
    my $runref = getVarref('run',    0,1);
    my $drnref = getVarref('dry_run',0,1);

    if(defined($mode) && scalar(grep {$mode eq $_} qw(run dry-run help usage)))
      {
	$setit = 1;

	$$runref = $$drnref = $$usgref = $$hlpref = 0;

	if($mode eq 'run')
	  {$$runref = 1}
	elsif($mode eq 'dry-run')
	  {$$drnref = 1}
	elsif($mode eq 'help')
	  {$$hlpref = 1}
	elsif($mode eq 'usage')
	  {$$usgref = 1}
      }

    if((($$hlpref ? 1 : 0) + ($$usgref ? 1 : 0) + ($$runref ? 1 : 0) +
	($$drnref ? 1 : 0)) > 1)
      {error("Internal error(2): Ambiguous run mode.",
	     {DETAIL =>
	      "help:$$hlpref, usage:$$usgref, run:$$runref, dry-run:$$drnref " .
	      "determine default:$determine_default_run_mode"})}

    return($setit);
  }

#This sets the default_run_mode based on flags supplied either on the command
#line or from a user saved default
#Globals used: $exclusive_options
sub processMutuallyExclusiveOptionSets
  {
    #Supply 1 to fill in DEFAULT_CLI based on user and programmer defaults
    #instead of VARREF_STG
    my $defaults_only = defined($_[0]) ? $_[0] : 0;
    my $status        = 0;

    if(!defined($exclusive_options) || ref($exclusive_options) ne 'ARRAY')
      {
	error("Invalid or no mutually exclusive options array supplied.",
	      {DETAIL => 'Not defined or not an array.'});
	return(1);
      }

    #This sub should only be called after the command line has been parsed
    if($command_line_stage < ARGSREAD)
      {
	error("Command line has not yet been parsed.");
	return(1);
      }

    if(scalar(@$exclusive_options) == 0)
      {return($status)}

    my %conflict_sets = ();
    my %status_hash   = ();

    if(scalar(@$exclusive_options) ==
       scalar(grep {ref($_) eq 'ARRAY'} @$exclusive_options))
      {
	my $mutex_opt_hash = {};

	#This records desired option states by each mutually exclusive set and
	#the desire to set a value trumps not setting a value
	foreach my $mutexid (0..$#{$exclusive_options})
	  {
            addMutexSettings($mutexid,$mutex_opt_hash,$defaults_only);
            $status_hash{$mutexid} = 0;
          }

	#This checks to see if all the set values are copacetic between the
	#mutex sets
	foreach my $mutexid (0..$#{$exclusive_options})
	  {
	    if(checkMutuallyExclusiveSettings($mutexid,
                                              $mutex_opt_hash,
                                              $defaults_only))
	      {
		$status                  = 1;
                $status_hash{$mutexid}   = 1;
		$conflict_sets{$mutexid} = 1
		  if($mutual_params->{$mutexid}->{BUILTIN});
	      }
	  }

        foreach my $mutexid (0..$#{$exclusive_options})
          {
            #If status is OK (0), set the values
            if(!$status_hash{$mutexid} &&
               setMutuallyExclusiveOptions($mutexid,
                                           $mutex_opt_hash,
                                           $defaults_only))
              {
                $status                  = 1;
                $status_hash{$mutexid}   = 1;
                next if($defaults_only); #No fallbacks staging when setting defs
                $conflict_sets{$mutexid} = 1
                  if($mutual_params->{$mutexid}->{BUILTIN});
              }
          }

        foreach my $mutexid (keys(%status_hash))
          {$mutual_params->{$mutexid}->{VALIDATED} = $status_hash{$mutexid}}
      }
    else
      {
	error("Invalid or no mutually exclusive options array supplied.",
	      {DETAIL => ('Not an array of scalars or an array of arrays of ' .
			  'scalars.')});
	$status = 1;
      }

    #If any builtin mutex sets had conflicts
    if(scalar(keys(%conflict_sets)))
      {
	#Force-set their options' values to CLI defaults from the
	#def_option_hash
        my $all_conflict_opts = {}; #conflicted opts regardless of mutex set
	foreach my $mutexid (keys(%conflict_sets))
	  {foreach my $uh (map {$usage_array->[$_]}
                           @{$exclusive_options->[$mutexid]})
             {$all_conflict_opts->{$uh->{USAGE_NAME}} = $uh}}

        my $one_set        = {}; #One of a mutex set has a CLI default value
        my $fallbacks_hash = getBuiltinFallbacks(keys(%$all_conflict_opts));
	foreach my $mutexid (keys(%conflict_sets))
	  {
            foreach my $uh (map {$usage_array->[$_]}
                            @{$exclusive_options->[$mutexid]})
              {
                my $optname = $uh->{USAGE_NAME};
                my $def     = (exists($fallbacks_hash->{$optname}) ?
                               $fallbacks_hash->{$optname} :
                               $def_option_hash->{$optname}->{DEFAULT});
                if(hasValue($uh->{OPTTYPE},$def))
                  {$one_set->{$mutexid} = 1}
              }
         }

        my $already_done = {};
        foreach my $optname (keys(%$all_conflict_opts))
          {
            my $uh  = $usage_lookup->{$optname};
            my $def = (exists($fallbacks_hash->{$optname}) ?
                       $fallbacks_hash->{$optname} :
                       $def_option_hash->{$optname}->{DEFAULT});
            $already_done->{$optname} = 1;
            debug("Setting CLI default [$def] for $uh->{OPTFLAG_DEF} due to ",
                  "conflict.",{LEVEL => -1});
            stageVarref($uh,$def);
          }

        #If the mutex set is required (i.e. one must have a value) but there's a
        #conflict potentially between options in the set, neither of whose CLI
        #default is "set" (implied by existence in the $one_set hash), set the
        #entire(/remainder of the) set
        foreach my $mutexid (grep {exists($mutual_params->{$_}->{REQUIRED}) &&
                                     $mutual_params->{$_}->{REQUIRED} &&
                                       !exists($one_set->{$_})}
                             keys(%conflict_sets))
          {
            foreach my $uh (grep {!exists($already_done->{$_->{USAGE_NAME}})}
                            map {$usage_array->[$_]}
                            @{$exclusive_options->[$mutexid]})
              {
                my $optname = $uh->{USAGE_NAME};
                my $def     = (exists($fallbacks_hash->{$optname}) ?
                               $fallbacks_hash->{$optname} :
                               $def_option_hash->{$optname}->{DEFAULT});
                $already_done->{$optname} = 1;
                debug("Setting CLI default [$def] for $uh->{OPTFLAG_DEF} due ",
                      "to conflict.",{LEVEL => -1});
                stageVarref($uh,$def);
              }
          }

	#Additionally set any undefined STG defaults to their CLI defaults,
	#since we are going to issue a fatal error (and we don't want it to spew
	#all sorts of debug junk (which may be desireable in other fatal error
	#contexts)
	foreach my $uh (grep {!hasValue($_->{OPTTYPE},$_->{VARREF_STG})}
			map {$usage_lookup->{$_}}
			grep {defined($def_option_hash->{$_}->{DEFAULT})}
			keys(%$fallbacks_hash))
	  {
            #Only stage the value if it doesn't create another mutex conflict
            my $mutex_partner_has_val =
              scalar(grep {my $meid=$_;scalar(grep {hasValue($usage_array->[$_]
                                                             ->{OPTTYPE},
                                                             $usage_array->[$_]
                                                             ->{VARREF_STG})}
                                              @{$exclusive_options->[$meid]})}
                     keys(%{$exclusive_lookup->{$uh->{OPTION_ID}}}));

            if(!$mutex_partner_has_val)
              {
                my $optname = $uh->{USAGE_NAME};
                my $def     = (exists($fallbacks_hash->{$optname}) ?
                               $fallbacks_hash->{$optname} :
                               $def_option_hash->{$optname}->{DEFAULT});
                stageVarref($uh,$def);
              }
          }
      }

    return($status);
  }

#This method records the settings dictated by mutually exclusive options WRT
#this hierarchy: command line, user defaults, and programmer defaults, but
#doesn't implement those changes.  It just records what each set wants.  Another
#sub checks if those desires conflict.  The reason to do this is that options
#can belong to multiple mutually exclusive sets and can conflict.
sub addMutexSettings
  {
    my $mutex_id         = $_[0];
    my $mutex_opt_states = $_[1];
    my $defaults_only    = defined($_[2]) ? $_[2] : 0;

    my $local_exclusives = $exclusive_options->[$mutex_id];

    if(!defined($local_exclusives) || ref($local_exclusives) ne 'ARRAY' ||
       scalar(@$local_exclusives) != scalar(grep {ref($_) eq ''}
					    @$local_exclusives))
      {
	error("Invalid or no mutually exclusive options array supplied.");
	return($mutex_opt_states);
      }

    #This sub should only be called after the command line has been parsed
    if($command_line_stage < ARGSREAD)
      {
	error("Command line has not yet been parsed.");
	return($mutex_opt_states);
      }

    if(scalar(@$local_exclusives) == 0)
      {return($mutex_opt_states)}

    #The set opts are the things we use to test mutual exclusivity
    my $num_sup             = 0;
    my $set_opts            = [];
    my $unset_opts          = [];
    my $cmdln_sup           = 0;
    my $cmdln_setopts       = [];
    my $cmdln_expunsetopts  = [];
    my $cmdln_unsetopts     = [];
    my $usrdef_sup          = 0;
    my $usrdef_setopts      = [];
    my $usrdef_expunsetopts = [];
    my $usrdef_unsetopts    = [];
    my $prgdef_sup          = 0;
    my $prgdef_setopts      = [];
    my $prgdef_unsetopts    = [];

    foreach my $uh (map {$usage_array->[$_]} @$local_exclusives)
      {
	if($uh->{SUPPLIED})
	  {
            $cmdln_sup++;
            if(hasValue($uh->{OPTTYPE},getVarref($uh,0,1)))
              {push(@$cmdln_setopts,$uh)}
            else
              {push(@$cmdln_expunsetopts,$uh)}
          }
	else
	  {push(@$cmdln_unsetopts,$uh)}

	if($uh->{SUPPLIED_UDF})
	  {
            $usrdef_sup++;
            if(hasValue($uh->{OPTTYPE},$uh->{DEFAULT_USR}))
              {push(@$usrdef_setopts,$uh)}
            else
              {push(@$usrdef_expunsetopts,$uh)}
          }
	else
	  {push(@$usrdef_unsetopts,$uh)}

        #Programmer defaults are not guaranteed to have been handled in a way
        #that we can just check if its defined (or call something like
        #hasActualDefinedDefault).  But that doesn't matter.  This is the bottom
        #of the hierarchy.  All that matters is if it has a positive value.
	if(hasValue($uh->{OPTTYPE},$uh->{DEFAULT_PRG}))
          {
            $prgdef_sup++;
            push(@$prgdef_setopts,$uh);
          }
	else
	  {push(@$prgdef_unsetopts,$uh)}
      }

    my $winner  = '';
    my $num_set = 0;
    #Figure out which set of options to use in order: supplied, user, programmer
    if($cmdln_sup && !$defaults_only)
      {
        $num_sup    = $cmdln_sup;
        $num_set    = scalar(@$cmdln_setopts);

	$set_opts   = $cmdln_setopts;

        #Save the explicitly unset values first
	$unset_opts = $cmdln_expunsetopts;
        #If anything was explicitly set, all the rest must be unset
        if($num_set && scalar(@$cmdln_unsetopts))
          {push(@$unset_opts,@$cmdln_unsetopts)}

	$winner     = 'c'; #Command line
      }
    elsif($usrdef_sup)
      {
        $num_sup    = $usrdef_sup;
        $num_set    = scalar(@$usrdef_setopts);

	$set_opts   = $usrdef_setopts;

        #Save the explicitly unset values first
	$unset_opts = $usrdef_expunsetopts;
        #If anything was explicitly set, all the rest must be unset
        if($num_set && scalar(@$usrdef_unsetopts))
          {push(@$unset_opts,@$usrdef_unsetopts)}

	$winner     = 'u'; #User defaults
      }
    elsif($prgdef_sup)
      {
        $num_sup    = $prgdef_sup;
        $num_set    = scalar(@$prgdef_setopts);

	$set_opts   = $prgdef_setopts;

	$unset_opts = $prgdef_unsetopts;

	$winner     = 'p'; #Programmer defaults
      }
    else
      {return($mutex_opt_states)}

    #We will ignore everything except valid settings
    if($num_set <= 1 && $num_sup)
      {
	#there should be only one "set" option, however, count options can be
	#explicitly set on the command line or in user defaults as "unset"
	#(i.e. 0), so we're going to mark all of them as being intentionally
	#"set"
        my($soid);
	foreach $soid (map {$_->{OPTION_ID}} @$set_opts)
	  {$mutex_opt_states->{$soid}->{1}->{$mutex_id} =
	     {WINNERTYPE => $winner,
	      WINNERID   => $soid}}

	#Options of type bool are the only ones we can set an actual "unset"
        #value to (i.e. '0')
        foreach my $uoid (map {$_->{OPTION_ID}} @$unset_opts)
	  {$mutex_opt_states->{$uoid}->{0}->{$mutex_id} =
	     {WINNERTYPE => $winner,
	      WINNERID   => $soid}} #$soid could be undef if 1 memb explty unset
      }

    return($mutex_opt_states);
  }

#This checks for conflicts between sets and what they want set/unset
sub checkMutuallyExclusiveSettings
  {
    my $mutex_id         = $_[0];
                                  #            SET?
    my $mutex_opt_states = $_[1]; #->{optid}->{0|1}->{$mutexid}={WINNERTYPE=> ?,
                                  #                              WINNERID  => ?}
    my $defaults_only    = defined($_[2]) ? $_[2] : 0;
    my $local_exclusives = $exclusive_options->[$mutex_id];
    my $status           = 0;

    if(!defined($local_exclusives) || ref($local_exclusives) ne 'ARRAY' ||
       scalar(@$local_exclusives) != scalar(grep {ref($_) eq ''}
					    @$local_exclusives))
      {
	error("Invalid mutex set ID supplied.");
	return(1);
      }

    #This sub should only be called after the command line has been parsed
    if($command_line_stage < ARGSREAD)
      {
	error("Command line has not yet been parsed.");
	return(1);
      }

    if(scalar(@$local_exclusives) == 0)
      {return($status)}

    #The set opts are the things we use to test mutual exclusivity
    my $num_chk             = 0;
    my $set_opts            = [];
    my $unset_opts          = [];
    my $cmdln_chk           = 0;
    my $cmdln_setopts       = [];
    my $cmdln_expunsetopts  = [];
    my $cmdln_unsetopts     = [];
    my $usrdef_chk          = 0;
    my $usrdef_setopts      = [];
    my $usrdef_expunsetopts = [];
    my $usrdef_unsetopts    = [];
    my $prgdef_chk          = 0;
    my $prgdef_setopts      = [];
    my $prgdef_unsetopts    = [];

    #This determines winners when you take into account saved winners of other
    #sets (according to mutex_opt_states).  Basically, it needs 2 passes due to
    #the order you go through the sets.  All conflicts will result in errors or
    #warnings (if validly over-ridden) in the bottom of this sub.  But for right
    #now, we're only deciding the winner of the current set if mutex_opt_states
    #"allows" it, i.e. the states show that this set wasn't over-ridden
    foreach my $uh (map {$usage_array->[$_]} @$local_exclusives)
      {
        #Don't need to check for conflicts, as this is the top of the hierarchy
	if($uh->{SUPPLIED})
	  {
            $cmdln_chk++;
            if(hasValue($uh->{OPTTYPE},getVarref($uh,0,1)))
              {push(@$cmdln_setopts,$uh)}
            else
              {push(@$cmdln_expunsetopts,$uh)}
          }
	else
	  {push(@$cmdln_unsetopts,$uh)}

	if($uh->{SUPPLIED_UDF} &&

           ## Only set as "set" if they made it through the hierarchical check
           ## as set

           #This option isn't in the states hash or it is in the states hash
           #(implied) and it is set consistent with the winning states
           (!exists($mutex_opt_states->{$uh->{OPTION_ID}}) ||

            (hasValue($uh->{OPTTYPE},$uh->{DEFAULT_USR}) &&
             exists($mutex_opt_states->{$uh->{OPTION_ID}}->{1})) ||

            (!hasValue($uh->{OPTTYPE},$uh->{DEFAULT_USR}) &&
             exists($mutex_opt_states->{$uh->{OPTION_ID}}->{0}))))
	  {
            $usrdef_chk++;
            if(hasValue($uh->{OPTTYPE},$uh->{DEFAULT_USR}))
              {push(@$usrdef_setopts,$uh)}
            else
              {push(@$usrdef_expunsetopts,$uh)}
          }
	else
	  {push(@$usrdef_unsetopts,$uh)}

        #Programmer defaults are not guaranteed to have been handled in a way
        #that we can just check if its defined (or call something like
        #hasActualDefinedDefault).  But that doesn't matter.  This is the bottom
        #of the hierarchy.  All that matters is if it has a positive value.
	if(hasValue($uh->{OPTTYPE},$uh->{DEFAULT_PRG}) &&

	   ## Only set as "set" if they made it through the hierarchical check
	   ## as set

	   #This option isn't in the states hash or it is in
	   #the states hash and it is set
	   (!exists($mutex_opt_states->{$uh->{OPTION_ID}}) ||
	    exists($mutex_opt_states->{$uh->{OPTION_ID}}->{1})))
          {
            $prgdef_chk++;
            push(@$prgdef_setopts,$uh);
          }
	else
	  {push(@$prgdef_unsetopts,$uh)}
      }

    my $message = '';
    my $winner  = '';
    my $num_set = 0;
    #Figure out which set of options to use in order: supplied, user, programmer
    if($cmdln_chk && !$defaults_only)
      {
        $num_chk    = $cmdln_chk;
        $num_set    = scalar(@$cmdln_setopts);

	$set_opts   = $cmdln_setopts;

        #Save the explicitly unset values first
	$unset_opts = $cmdln_expunsetopts;
        #If anything was set and other unset opts exist, they must be unset
        if($num_set && scalar(@$cmdln_unsetopts))
          {push(@$unset_opts,@$cmdln_unsetopts)}

	$winner     = 'c'; #Command line
	$message    = 'as supplied on the command line';
      }
    elsif($usrdef_chk)
      {
        $num_chk    = $usrdef_chk;
        $num_set    = scalar(@$usrdef_setopts);

	$set_opts   = $usrdef_setopts;

        #Save the explicitly unset values first
	$unset_opts = $usrdef_expunsetopts;
        #If anything was set and other unset opts exist, they must be unset
        if($num_set && scalar(@$usrdef_unsetopts))
          {push(@$unset_opts,@$usrdef_unsetopts)}

	$winner     = 'u'; #User defaults
	my $sauh    = getUsageHash('save_args');
	my $uuh     = getUsageHash('usage');
	$message = "as set by $sauh->{OPTFLAG_DEF} (see $uuh->{OPTFLAG_DEF})";
      }
    elsif($prgdef_chk)
      {
        $num_chk    = $prgdef_chk;
        $num_set    = scalar(@$prgdef_setopts);

	$set_opts   = $prgdef_setopts;

	$unset_opts = $prgdef_unsetopts;

	$winner     = 'p'; #Programmer defaults
	$message    = 'as set by the script author';
      }

    if($num_set > 1)
      {
	error("The following options ($message) are mutually exclusive: [",
	      join(',',map {getBestFlag($_)} @$set_opts),
	      '].',
	      {DETAIL =>
	       ($winner eq 'c' ? 'Please provide only one.' :
		($winner eq 'u' ?
		 join('',('You can either update the user defaults using ',
			  '--save-args to remove all but one of the listed ',
			  'options above, or over-ride the user defaults by ',
			  'supplying only one of the listed options on the ',
			  'command line.')) :
		 join('',('There are multiple defaults set in the creation of ',
			  'these mutually exclusive options.  Either the ',
			  'parameters to the add*Option calls should not ',
			  'supply a DEFAULT, the VARREF should not be ',
			  'initialized (treated as a default), or the ',
			  'indicated options should not be included in the ',
			  'call to makeMutuallyExclusive().  A user can over-',
			  'ride these incompatible defaults either by using ',
			  '--save-args to supply only one of the options ',
			  '(applies to all runs) or by supplying one of the ',
			  'options on the command line each time the script ',
			  'is run.'))))}) unless($defaults_only);
        $status = 1;
      }
    elsif($num_set == 1)
      {
	foreach my $soid (map {$_->{OPTION_ID}} @$set_opts)
	  {
	    #If we cannot implement the winner's setting and it's not overridden
	    if(!(#Everything is copacetic because...
		 #This option has no settings or
		 !exists($mutex_opt_states->{$soid}) ||
		 #nothing wants it to be unset or
		 !exists($mutex_opt_states->{$soid}->{0}) ||
		 #There are no mutex sets whose winner was decided at the same
		 #hierarchy level that want this unset (i.e. there's a clear
		 #winner)
		 scalar(grep {$_->{WINNERTYPE} eq $winner}
			values(%{$mutex_opt_states->{$soid}->{0}})) == 0))
	      {
		my $lfag1   = getBestFlag($usage_array->[$soid]);
		my $flag2s  = [map {getBestFlag($usage_array->[$_])}
			       map {$_->{WINNERID}}
			       values(%{$mutex_opt_states->{$soid}->{0}})];
		my $err_msg = "$lfag1 is mutually exclusive with [" .
		  join(', ',@$flag2s) . '], all of which were set via ' .
		    ($winner eq 'c' ? 'the command line' :
		     ($winner eq 'u' ? 'user' : 'programmer') . ' default') .
		       '.';
		my $detail =
		  "$lfag1 is a part of the mutually exclusive set(s): ";
		#Another mutex set (or sets) at the same hierarchy level
		#determined a different winner and thus they want this option to
		#be unset, so let's identify the winners of those sets to report
		#why there's a problem
		my @conf_sets = ();
		foreach my $mutex_conf (keys(%{$mutex_opt_states->{$soid}
						 ->{0}}))
		  {
		    my $winnr_info = $mutex_opt_states->{$soid}->{0}
		      ->{$mutex_conf};
		    my $excl_opt   = $winnr_info->{WINNERID};
		    my $flag2      = getBestFlag($usage_array->[$excl_opt]);
		    my $mutexflags = [map {getBestFlag($usage_array->[$_])}
				      @{$exclusive_options->[$mutex_conf]}];
		    push(@conf_sets,join(', ',@$mutexflags));
		  }
		$detail .= '[' . (scalar(@$flag2s) > 1 ? '(' : '') .
		  join('), (',@conf_sets) . (scalar(@$flag2s) > 1 ? ')' : '') .
		    '].';
		error({DETAIL => $detail},$err_msg) unless($defaults_only);
		$status = 1;
	      }
	  }

        #Check the options that should not be set as well
        foreach my $uoid (map {$_->{OPTION_ID}} @$unset_opts)
	  {
	    #If we cannot implement the winner's setting and it's not over-
	    #ridden
	    if(!(!exists($mutex_opt_states->{$uoid}) ||
		 #The value is not set (i.e. '1' as a key does not exist)
                 !exists($mutex_opt_states->{$uoid}->{1}) ||
                 #There are no mutex sets whose winner was decided at the same
                 #hierarchy level that want this set (i.e. there's a clear
                 #winner)
                 scalar(grep {$_->{WINNERTYPE} eq $winner}
                        values(%{$mutex_opt_states->{$uoid}->{1}})) == 0))
	      {$status = 1}
	  }

	#Check the programmer defaults
	if(scalar(grep {hasValue($_->{OPTTYPE},$_->{DEFAULT_PRG})}
		  map {$usage_array->[$_]} @$local_exclusives) > 1)
	  {
	    warning("The following options are supposed to be mutually ",
		    "exclusive, but they have all been configured in the ",
		    "script with default values: [",
		    join(',',map {$_->{OPTFLAG_DEF}}
                         grep {hasValue($_->{OPTTYPE},$_->{DEFAULT_PRG})}
                         map {$usage_array->[$_]} @$local_exclusives),'].',
		    {DETAIL =>
		     join('',('Either the parameters to the add*Option calls ',
			      'should not supply a DEFAULT, the VARREF should ',
			      'not be initialized (treated as a default), or ',
			      'the indicated options should not be included ',
			      'in the call to makeMutuallyExclusive().'))})
              unless($defaults_only);
	  }
	#Check the user defaults
	if(scalar(grep {$_->{SUPPLIED_UDF} &&
                          hasValue($_->{OPTTYPE},$_->{DEFAULT_USR})}
		  map {$usage_array->[$_]} @$local_exclusives) > 1)
	  {
	    warning("The following options are supposed to be mutually ",
		    "exclusive, but they have all been configured in the ",
		    "script with default values: [",
		    join(',',map {$_->{OPTFLAG_DEF}}
                         grep {$_->{SUPPLIED_UDF} &&
                                 hasValue($_->{OPTTYPE},$_->{DEFAULT_USR})}
		  map {$usage_array->[$_]} @$local_exclusives),'].',
		    {DETAIL =>
		     join('',('Please update the user defaults using ',
			      '--save-args to remove all but one of the ',
			      'listed options above.'))})
              unless($defaults_only);
	  }
      }
    #Else - there my be no values positively set because the user explicitly set
    #all values negatively, but there may be lower hierarchy problems, for which
    #we should issue warnings
    elsif($winner ne 'p')
      {
	#Check the programmer defaults
	if(scalar(grep {hasValue($_->{OPTTYPE},$_->{DEFAULT_PRG})}
		  map {$usage_array->[$_]} @$local_exclusives) > 1)
	  {
	    warning("The following options are supposed to be mutually ",
		    "exclusive, but they have all been configured in the ",
		    "script with default values: [",
		    join(',',map {$_->{OPTFLAG_DEF}}
                         grep {hasValue($_->{OPTTYPE},$_->{DEFAULT_PRG})}
                         map {$usage_array->[$_]} @$local_exclusives),'].',
		    {DETAIL =>
		     join('',('Either the parameters to the add*Option calls ',
			      'should not supply a DEFAULT, the VARREF should ',
			      'not be initialized (treated as a default), or ',
			      'the indicated options should not be included ',
			      'in the call to makeMutuallyExclusive().'))})
              unless($defaults_only);
	  }
	#Check the user defaults
	if(scalar(grep {$_->{SUPPLIED_UDF} &&
                          hasValue($_->{OPTTYPE},$_->{DEFAULT_USR})}
		  map {$usage_array->[$_]} @$local_exclusives) > 1)
	  {
	    warning("The following options are supposed to be mutually ",
		    "exclusive, but they have all been configured in the ",
		    "script with default values: [",
		    join(',',map {$_->{OPTFLAG_DEF}}
                         grep {$_->{SUPPLIED_UDF} &&
                                 hasValue($_->{OPTTYPE},$_->{DEFAULT_USR})}
		  map {$usage_array->[$_]} @$local_exclusives),'].',
		    {DETAIL =>
		     join('',('Please update the user defaults using ',
			      '--save-args to remove all but one of the ',
			      'listed options above.'))})
              unless($defaults_only);
	  }
      }

    return($status);
  }

#This sub takes the un-conflicting settings and tries to set them.  This could
#result in an error due to the over-ride settings.  I.e. if a winning set wants
#to implcitly change the setting of a lower hierarchy value (i.e. a default),
#but the set is not over-ridable, it will generate an error and propose a way to
#resolve the issue
sub setMutuallyExclusiveOptions
  {
    my $mutex_id         = $_[0];
                                  #            SET?
    my $mutex_opt_states = $_[1]; #->{optid}->{0|1}->{$mutexid}={WINNERTYPE=> ?,
                                  #                              WINNERID  => ?}
    my $defaults_only    = defined($_[2]) ? $_[2] : 0;

    my $local_exclusives = $exclusive_options->[$mutex_id];
    my $overridable      = (exists($mutual_params->{$mutex_id}) &&
                            exists($mutual_params->{$mutex_id}
                                   ->{OVERRIDABLE}) &&
                            defined($mutual_params->{$mutex_id}
                                    ->{OVERRIDABLE}) ?
                            $mutual_params->{$mutex_id}->{OVERRIDABLE} : 0);

    if(!defined($local_exclusives) || ref($local_exclusives) ne 'ARRAY' ||
       scalar(@$local_exclusives) != scalar(grep {ref($_) eq ''}
					    @$local_exclusives))
      {
	error("Invalid mutex set ID supplied.");
	return(1);
      }

    #This sub should only be called after the command line has been parsed
    if($command_line_stage < ARGSREAD)
      {
	error("Command line has not yet been parsed.");
	return(1);
      }

    if(scalar(@$local_exclusives) == 0)
      {return(0)}

    my $num_vld             = 0;
    my $set_opts            = [];
    my $unset_opts          = [];
    my $cmdln_vld           = 0;
    my $cmdln_setopts       = [];
    my $cmdln_expunsetopts  = [];
    my $cmdln_unsetopts     = [];
    my $usrdef_vld          = 0;
    my $usrdef_setopts      = [];
    my $usrdef_expunsetopts = [];
    my $usrdef_unsetopts    = [];
    my $prgdef_vld          = 0;
    my $prgdef_setopts      = [];
    my $prgdef_expunsetopts = [];
    my $prgdef_unsetopts    = [];

    foreach my $uh (map {$usage_array->[$_]} @$local_exclusives)
      {
	if($uh->{SUPPLIED})
	  {
            if(hasValue($uh->{OPTTYPE},getVarref($uh,0,1)) &&
               (!exists($mutex_opt_states->{$uh->{OPTION_ID}}) ||
                (exists($mutex_opt_states->{$uh->{OPTION_ID}}->{1}) &&
                 (!exists($mutex_opt_states->{$uh->{OPTION_ID}}->{0}) ||
                  #There are no other command line options that want this unset
                  scalar(grep {$_->{WINNERTYPE} eq 'c'}
                         values(%{$mutex_opt_states->{$uh->{OPTION_ID}}
                                    ->{0}})) == 0))))
              {
                $cmdln_vld++;
                push(@$cmdln_setopts,$uh);
              }
            elsif(!hasValue($uh->{OPTTYPE},getVarref($uh,0,1)) &&
                  (!exists($mutex_opt_states->{$uh->{OPTION_ID}}) ||
                   (exists($mutex_opt_states->{$uh->{OPTION_ID}}->{0}) &&
                    (!exists($mutex_opt_states->{$uh->{OPTION_ID}}->{1}) ||
                     #There are no other command line options that want this set
                     scalar(grep {$_->{WINNERTYPE} eq 'c'}
                            values(%{$mutex_opt_states->{$uh->{OPTION_ID}}
                                       ->{1}})) == 0))))
              {
                $cmdln_vld++;
                push(@$cmdln_expunsetopts,$uh);
              }
            else
              {push(@$cmdln_unsetopts,$uh)}
          }
	else
	  {push(@$cmdln_unsetopts,$uh)}

	if($uh->{SUPPLIED_UDF})
	  {
            if(## Only set as "set" if they made it through the hierarchical
               ## check as set or we're recording states to look for conflicts

               #This option isn't in the states hash or it is in
               #the states hash and it is set and is not unset by an over-riding
               #or conflicting mutex set
               hasValue($uh->{OPTTYPE},$uh->{DEFAULT_USR}) &&
               (!exists($mutex_opt_states->{$uh->{OPTION_ID}}) ||
                (exists($mutex_opt_states->{$uh->{OPTION_ID}}->{1}) &&
                 (!exists($mutex_opt_states->{$uh->{OPTION_ID}}->{0}) ||
                  #There are no other command line or user default options that
                  #want this option unset
                  scalar(grep {$_->{WINNERTYPE} ne 'p'}
                         values(%{$mutex_opt_states->{$uh->{OPTION_ID}}
                                    ->{0}})) == 0))))
              {
                $usrdef_vld++;
                push(@$usrdef_setopts,$uh);
              }
            elsif(!hasValue($uh->{OPTTYPE},$uh->{DEFAULT_USR}) &&
                  (!exists($mutex_opt_states->{$uh->{OPTION_ID}}) ||
                   (exists($mutex_opt_states->{$uh->{OPTION_ID}}->{0}) &&
                    (!exists($mutex_opt_states->{$uh->{OPTION_ID}}->{1}) ||
                     #There are no other command line or user default options
                     #that want this option unset
                     scalar(grep {$_->{WINNERTYPE} ne 'p'}
                            values(%{$mutex_opt_states->{$uh->{OPTION_ID}}
                                       ->{1}})) == 0))))
              {
                $usrdef_vld++;
                push(@$usrdef_expunsetopts,$uh);
              }
            else
              {push(@$usrdef_unsetopts,$uh)}
          }
	else
	  {push(@$usrdef_unsetopts,$uh)}

	if(hasValue($uh->{OPTTYPE},$uh->{DEFAULT_PRG}) &&

	   ## Only set as "set" if they made it through the hierarchical check
	   ## as set or we're recording states to look for conflicts

	   #This option isn't in the states hash or it is in
	   #the states hash and it is set and is not unset
	   (!exists($mutex_opt_states->{$uh->{OPTION_ID}}) ||
            (exists($mutex_opt_states->{$uh->{OPTION_ID}}->{1}) &&
             #There are no other options (regardless of level) that want this
             #unset
             !exists($mutex_opt_states->{$uh->{OPTION_ID}}->{0}))))
	  {
            $prgdef_vld++;
            push(@$prgdef_setopts,$uh);
          }
	else
	  {push(@$prgdef_unsetopts,$uh)}
      }

    my $message = '';
    my $winner  = '';
    my $num_set = 0;
    #Figure out which set of options to use in order: supplied, user, programmer
    if($cmdln_vld && !$defaults_only)
      {
	$set_opts = $cmdln_setopts;
        $num_set  = scalar(@$set_opts);

        #Save the explicitly unset values first
	$unset_opts = $cmdln_expunsetopts;
        #If anything was set and other unset opts exist, they must be unset
        if($num_set && scalar(@$cmdln_unsetopts))
          {push(@$unset_opts,@$cmdln_unsetopts)}

	$winner = 'c'; #Command line
      }
    elsif($usrdef_vld)
      {
	$set_opts = $usrdef_setopts;
        $num_set  = scalar(@$set_opts);

        #Save the explicitly unset values first
	$unset_opts = $usrdef_expunsetopts;
        #If anything was set and other unset opts exist, they must be unset
        if($num_set && scalar(@$usrdef_unsetopts))
          {push(@$unset_opts,@$usrdef_unsetopts)}

	$winner = 'u'; #User defaults
      }
    else
      {
	$set_opts   = $prgdef_setopts;
	$unset_opts = $prgdef_unsetopts;
	$winner     = 'p'; #Programmer defaults
      }

    #This determines the number of options that are being set to an actual value
    #as opposed to being unset (e.g. --verbose 0)
    my $num_set_opts = scalar(@$set_opts);

    #If any options were supplied or positively set
    if($num_set_opts)
      {
	foreach my $soid (0..$#{$set_opts})
	  {
            #If we're staging defaults only (for the usage output), or if the
            #option doesn't have a value and there was a selection made
            if($winner eq 'u' &&
               ($defaults_only ||
                (!$set_opts->[$soid]->{SUPPLIED} &&
                 !hasValue($set_opts->[$soid]->{OPTTYPE},
                           getVarref($set_opts->[$soid],0,1)))))
	      {stageVarref($set_opts->[$soid],
                           $set_opts->[$soid]->{DEFAULT_USR},
                           $defaults_only)}
            elsif($winner eq 'p' &&
                  ($defaults_only ||
                   (!$set_opts->[$soid]->{SUPPLIED} &&
                    !hasValue($set_opts->[$soid]->{OPTTYPE},
                              getVarref($set_opts->[$soid],0,1)))))
	      {stageVarref($set_opts->[$soid],
                           $set_opts->[$soid]->{DEFAULT_PRG},
                           $defaults_only)}
	  }
      }

    #If there are any unset options
    if(scalar(@$unset_opts))
      {
	#Options of type bool are the only ones we can set an actual "unset"
        #value to (i.e. '0')
        my $cannot_unset = [];
        foreach my $uh (@$unset_opts)
	  {
            my $cl = hasValue($uh->{OPTTYPE},getVarref($uh,0,1));
            my $ud = hasValue($uh->{OPTTYPE},$uh->{DEFAULT_USR});
            my $pd = hasValue($uh->{OPTTYPE},$uh->{DEFAULT_PRG});
            if(!$overridable &&
               (#The option to unset has a set value on the command line and
                #we're not setting defaults
                ($cl && !$defaults_only) ||
                #The option to unset was not supplied on the command line and
                #its user default has a set value
                ((!$uh->{SUPPLIED} || $defaults_only) && $ud) ||
                #The option to unset was not supplied on the command line,
                #was not supplied as a user default,
                #and its programmer default has a set value
                ((!$uh->{SUPPLIED} || $defaults_only) && !$uh->{SUPPLIED_UDF} &&
                 $pd)))
              {
                my $vsb = ($cl && !$defaults_only ? 'c' : ($ud ? 'u' : 'p'));
                push(@$cannot_unset,[$uh,$vsb]);
	      }
            else
              {
                my $unset_val = undef;
                if(($cl && !$defaults_only) ||
                   ((!$uh->{SUPPLIED} || $defaults_only) && $ud) ||
                   ((!$uh->{SUPPLIED} || $defaults_only) &&
                    !$uh->{SUPPLIED_UDF} && $pd))
                  {$unset_val = ($uh->{OPTTYPE} eq 'bool' ? 0 : undef)}
                elsif($uh->{OPTTYPE} eq 'bool' || $uh->{OPTTYPE} eq 'count')
                  {
                    #If there is a defined value
                    if(!$defaults_only &&
                       hasValue($uh->{OPTTYPE},getVarref($uh,0,1),1))
                      {$unset_val = getVarref($uh,0,1)}
                    elsif(hasValue($uh->{OPTTYPE},$uh->{DEFAULT_USR},1))
                      {$unset_val = $uh->{DEFAULT_USR}}
                    elsif(hasValue($uh->{OPTTYPE},$uh->{DEFAULT_PRG},1))
                      {$unset_val = $uh->{DEFAULT_PRG}}
                  }

                stageVarref($uh,$unset_val,$defaults_only);
              }
          }

        if(scalar(@$cannot_unset))
          {
	    #Remedies for the command line
	    my $fixcl =
	      join(' ',map {getBestFlag($_->[0]) . ' 0'}
		   grep {$_->[0]->{OPTTYPE} =~ /^(negbool|count)$/}
		   @$cannot_unset);
	    #Remedies via user default
	    my $fixud =
	      join(' ',map {getBestFlag($_->[0])}
		   grep {$_->[1] eq 'u' &&
			   $_->[0]->{OPTTYPE} !~ /^(negbool|count)$/}
		   @$cannot_unset);
	    #Warn about no remedy case
	    my $norem =
	      join(' ',map {getBestFlag($_->[0])}
		   grep {$_->[1] eq 'p' &&
			   $_->[0]->{OPTTYPE} !~ /^(negbool|count)$/}
		   @$cannot_unset);

            #The only mutex sets allowed to have overlapping members are non-
            #overridable sets.  The only way an option can be overridden is by
            #another option in the same set, however this may affect the
            #overridden option in other sets it may belong to. If this/these
            #option/s are in a set where no overriding option was set, do not
            #issue the error, because this set is not the source of the
            #conflict.  That conflict is guaranteed to be reported in the set
            #where it originated.  Also do not issue error when only checking
            #defaults (otherwise, we'd get the error twice).
            if($num_set_opts && !$defaults_only)
              {
                #Note, direct command line conflicts should have been caught
                #earlier
                error("Un-overridable mutually exclusive option(s) conflict: [",
                      ($num_set_opts == 1 ?
                       getBestFlag($set_opts->[0]) .
                       ($winner eq 'c' ? ' supplied on the command line' :
                        ($winner eq 'u' ? ' set via user-default' :
                         ' set by hard-coded default')) . ' cannot override ' :
                       ''),
                      join(', ',map {getBestFlag($_->[0]) .
                                       ($_->[1] eq 'c' ? ' supplied on the ' .
                                        'command line' :
                                        ($_->[1] eq 'u' ?
                                         ' set via user-default' :
                                         ' set by hard-coded default'))}
                           @$cannot_unset),"].",
                      {DETAIL =>
                       join('',
                            ($fixcl ne '' ? "Supply the following on the " .
                             "command line to perform a manual override: [" .
                             "$fixcl].\n" : ''),
                            ($fixud ne '' ? "These options must be removed " .
                             "from the user defaults (see --save-args): [" .
                             "$fixud].\n" : ''),
                            ($norem ne '' ? "The only way to unset a hard-" .
                             "coded, non-overridable default, such as " .
                             "[$norem], is to change the script code, " .
                             "because there's no flag to supply to un-set " .
                             "this default.\n" : '')) .
                       ('The non-overridable mutually exclusive set related ' .
                        'to this error is: [' .
                        join(', ',map {getBestFlag($usage_array->[$_])}
                             @$local_exclusives) . '].')});
                return(1);
              }
          }
      }

    #If nothing from this mutex group was set, but one from the set is required
    if(scalar(@$set_opts) == 0 &&
       exists($mutual_params->{$mutex_id}->{REQUIRED}) &&
       $mutual_params->{$mutex_id}->{REQUIRED})
      {
        my $num_set = scalar(grep {exists($mutex_opt_states->{$_}) &&
                                     exists($mutex_opt_states->{$_}->{1})}
                             @$local_exclusives);
        if($num_set)
          {
            my $set_opts   = [grep {exists($mutex_opt_states->{$_}) &&
                                      exists($mutex_opt_states->{$_}->{1})}
                              @$local_exclusives];
            my $num_unset  = scalar(grep {exists($mutex_opt_states->{$_}) &&
                                            exists($mutex_opt_states->{$_}
                                                   ->{0})} @$local_exclusives);

            foreach my $set_opt (@$set_opts)
              {
                my $overriders = [map {[#option ID,         MutexID it comes frm
                                        $_->[1]->{WINNERID},$_->[0]]}
                                  map {[each(%{$mutex_opt_states->{$_}->{0}})]}
                                  grep {exists($mutex_opt_states->{$_}->{0})}
                                  ($set_opt)];
                error("A default setting for [",
                      getBestFlag($usage_array->[$set_opt]),
                      "] from the required mutually exclusive option group: ",
                      "[",join(', ',map {getBestFlag($usage_array->[$_])}
                               @$local_exclusives),
                      "] appears to have been over-ridden by one of [",
                      join(', ',
                           map {my $i = $_;
                                getBestFlag($usage_array->[$i->[0]]) .
                                   ' in the mutually exclusive group: (' .
                                     join(', ',
                                          map {getBestFlag($usage_array->[$_])}
                                          @{$exclusive_options->[$i->[1]]}) .
                                            ')'}
                           @$overriders),"] in another mutually exclusive ",
                      "group, and there is no fallback default.  Please re-",
                      "run and supply one of [",
                      join(', ',map {getBestFlag($usage_array->[$_])}
                           grep {!exists($mutex_opt_states->{$_}) ||
                                   !exists($mutex_opt_states->{$_}->{0})}
                           @$local_exclusives),
                      "] (or if that list is empty, remove the settings for: [",
                      join(', ',map {getBestFlag($usage_array->[$_->[0]])}
                           @$overriders),"]).") unless($defaults_only);
              }
          }
      }

    return(0);
  }

#This returns either $uh->{VARREF_CLI} or the scalar it refers to.  Errors if
#called before validation of the command line - this is so I can find everywhere
#where values are inappropriately accessed too early
sub getVarref
  {
    my $arg   = $_[0];
    my $drf   = (defined($_[1]) ? $_[1] : 0); #De-reference scalar references
    my $stg   = (defined($_[2]) ? $_[2] : 0); #Whether the staged value is OK
    my $noerr = (defined($_[3]) ? $_[3] : 0); #Use when called from error()
    unless(defined($arg))
      {
	error('1st arg required.') unless($noerr);
	return($_[0]);
      }
    my $uh  = (ref($arg) eq 'HASH' ?
	       $arg : (ref($arg) eq '' && exists($usage_lookup->{$arg}) ?
		       $usage_lookup->{$arg} : undef));
    if(ref($arg) ne '' && ref($arg) ne 'HASH')
      {
	error('1st arg must be a usage hash or option name.') unless($noerr);
	return(undef);
      }
    elsif(ref($arg) eq '' && !exists($usage_lookup->{$arg}))
      {
        if(!$noerr && (!exists($def_option_hash->{$arg}) ||
                       $def_option_hash->{$arg}->{ADDED}))
          {error("1st arg [$arg] must be a usage hash or valid option name.")}
	return(undef);
      }

    my $vrk = 'VARREF_CLI';
    if($stg && $command_line_stage < COMMITTED)
      {$vrk = 'VARREF_STG'}
    elsif(!$stg && $command_line_stage < COMMITTED)
      {
	#This is mainly here for debugging the module
	error("VARREF for option [$uh->{USAGE_NAME}] accessed before ",
	      "validation $command_line_stage.") unless($noerr);
      }

    return($drf ? deRefVarref($uh->{$vrk}) : $uh->{$vrk});
  }

sub stageVarref
  {
    my $uh    = $_[0];
    my $val   = $_[1];
    my $dodef = defined($_[2]) ? $_[2] : 0;
    my $type  = $uh->{OPTTYPE};
    my $flag  = getBestFlag($uh);

    if(ref($val) ne 'ARRAY' && ref($val) ne 'SCALAR' && ref($val) ne '')
      {
	error("Invalid variable type supplied: [",ref($val),"].",
	      {DETAIL => 'Only SCALAR and ARRAY are supported.'});
	return(1);
      }

    if(exists($array_genopt_types->{$type}) ||
       exists($array2dopt_types->{$type}))
      {
	if(!defined($val))
	  {$val = []}

	if(ref($val) ne 'ARRAY')
	  {error("Variable and option type mismatch for option $flag: [",
		 ref($val),"] vs. [$type: ARRAY].")}
	elsif($dodef)
          {@{$uh->{DEFAULT_CLI}} = @{copyArray($val)}}
        else
	  {
            #Need to preserve the reference in the staged value so that
            #callGOLCodeRef will be able to identify which value is supplied
            #(programmer default, user default, or other value)
            #@{$uh->{VARREF_STG}}  = @{copyArray($val)};
            $uh->{VARREF_STG} = $val;
          }
      }
    elsif(exists($scalaropt_types->{$type}))
      {
	my $tvar = $val;
	if(ref($val) eq '')
	  {$tvar = \$val}

	if(ref($tvar) ne 'SCALAR')
	  {error("Variable and option type mismatch for option $flag: [",
		 ref($tvar),"] vs. [$type: SCALAR].")}
	elsif($dodef)
          {$uh->{DEFAULT_CLI}   = $$tvar}
	else
	  {${$uh->{VARREF_STG}} = $$tvar}
      }
    else
      {error("Type unrecognized for option $flag: [$type].")}

    return(0);
  }

#Copies values from VARREF_STG to the user's variable in main (VARREF_PRG) and
#CLI's copy (VARREF_CLI).  They will NOT be copied if 2 or more equivalent-level
#mutex options have values.
sub commitAllVarrefs
  {foreach my $uh (@$usage_array)
     {commitVarrefs($uh)}}

sub commitVarrefs
  {
    my $uh     = $_[0];
    my $var    = $uh->{VARREF_STG};
    my $type   = $uh->{OPTTYPE};
    my $flag   = getBestFlag($uh);

    my $DEBUG = getVarref('debug',1,1,1);

    if(ref($var) ne 'ARRAY' && ref($var) ne 'SCALAR' && ref($var) ne '')
      {
	error("Invalid staged reference variable: [",ref($var),"].",
	      {DETAIL => 'Must be SCALAR or ARRAY.'});
	return(1);
      }

    #Handle the special case where we do not want to initialize a value in main
    #(via a code ref) that is in a mutex set
    my $callcoderef = 1;
    if(!$uh->{SUPPLIED} && !$uh->{SUPPLIED_UDF} &&
       !hasValue($uh->{OPTTYPE},$uh->{DEFAULT_PRG},1) &&
       exists($exclusive_lookup->{$uh->{OPTION_ID}}))
      {
        #If any member of any mutex group this option belongs
        #to has a value.  We're treating the code ref differently
        #than we treat undefined defaults
        my $mutex_partner_has_val =
          scalar(grep {my $meid=$_;scalar(grep {hasValue($usage_array->[$_]
                                                         ->{OPTTYPE},
                                                         $usage_array->[$_]
                                                         ->{VARREF_STG})}
                                          @{$exclusive_options->[$meid]})}
                 keys(%{$exclusive_lookup->{$uh->{OPTION_ID}}}));

        if(!$mutex_partner_has_val)
          {$callcoderef = 0}
      }

    if(exists($array_genopt_types->{$type}) ||
       exists($array2dopt_types->{$type}))
      {
	if(!defined($var))
	  {$var = []}

	if(ref($var) ne 'ARRAY')
	  {error("Variable and option type mismatch for option $flag: [",
		 ref($var),"] vs. [$type: ARRAY].")}
	else
	  {
	    #Set the local copy
	    @{$uh->{VARREF_CLI}} = @{copyArray($var)};

            #If there was an explicitly set value either on the command line,
            #as a user default, or as a programmer default; or if this option is
            #being over-ridden as a part of a mutex set (inferred from
            #membership in a mutex set (because it's only staged if overridden))
            if($uh->{SUPPLIED} || $uh->{SUPPLIED_UDF} ||
               hasValue($uh->{OPTTYPE},$uh->{DEFAULT_PRG},1) ||
               exists($exclusive_lookup->{$uh->{OPTION_ID}}))
              {
                #Set the programmer's variable in main
                if(ref($uh->{VARREF_PRG}) eq 'CODE')
                  {
                    #If $var is a default being filled in
                    if($type =~ /array/ && $DEBUG &&
                       ((defined($uh->{DEFAULT_PRG}) &&
                         $var eq $uh->{DEFAULT_PRG}) ||
                        (defined($uh->{DEFAULT_USR}) &&
                         $var eq $uh->{DEFAULT_USR})))
                      {warning("Attempting to fill in default array for ",
                               "[$flag] without knowing if there is a pre-",
                               "existing default value.",
                               {DETAIL => "We are unable to determine if the " .
                                "programmer initialized the array with a " .
                                "default value because they submitted a code " .
                                "reference to handle option processing.  " .
                                "Default array contents were provided by the " .
                                "[" .
                                (defined($uh->{DEFAULT_PRG}) &&
                                 $var eq $uh->{DEFAULT_PRG} ?
                                 'programmer' : 'user') . '].  If the ' .
                                'programmer initialized the array handled by ' .
                                'the code reference and their code appends ' .
                                'to those values instead of sets them, this ' .
                                'may result in the default array contents ' .
                                'being appended to that array.'})}
                    elsif($type =~ /array/ && !$uh->{SUPPLIED} && $DEBUG &&
                          exists($exclusive_lookup->{$uh->{OPTION_ID}}) &&
                          $callcoderef)
                      {debug("Attempting to clear out the array for [$flag] ",
                             "without knowing if there is a pre-existing ",
                             "default value.",
                             {DETAIL => "We are unable to determine if the " .
                              "programmer initialized the array with a " .
                              "default value because they submitted a code " .
                              "reference to handle option processing.  Nor " .
                              "do we know how their code handles supplied " .
                              "values.  A mutually exclusive option was " .
                              "supplied, so any default the programmer had " .
                              "in main will be cleared out.  If the " .
                              'programmer initialized the array handled by ' .
                              'the code reference and their code appends to ' .
                              'those values instead of sets them, this may ' .
                              'result in the default array contents being ' .
                              'appended to that array.'})}

                    callGOLCodeRef($uh->{VARREF_PRG},$uh,$var)
                      if($callcoderef);
                  }
                #These may be the same reference, so don't copy twice if so
                elsif($uh->{VARREF_PRG} ne $uh->{VARREF_CLI})
                  {@{$uh->{VARREF_PRG}} = @{copyArray($var)}}
              }
	  }
      }
    elsif(exists($scalaropt_types->{$type}))
      {
	my $tvar = $var;
	if(ref($var) eq '')
	  {$tvar = \$var}

	if(ref($tvar) ne 'SCALAR')
	  {error("Variable and option type mismatch for option $flag: [",
		 ref($tvar),"] vs. [$type: SCALAR].")}
	else
	  {
	    ${$uh->{VARREF_CLI}} = $$tvar;

            #If there was an explicitly set value either on the command line,
            #as a user default, or as a programmer default; or if this option is
            #being over-ridden as a part of a mutex set (imferred from
            #membership in a mutex set (because it's only staged if overridden))
            if($uh->{SUPPLIED} || $uh->{SUPPLIED_UDF} ||
               hasValue($uh->{OPTTYPE},$uh->{DEFAULT_PRG},1) ||
               exists($exclusive_lookup->{$uh->{OPTION_ID}}))
              {
                #Set the programmer's variable in main
                if(ref($uh->{VARREF_PRG}) eq 'CODE')
                  {if($callcoderef)
                     {callGOLCodeRef($uh->{VARREF_PRG},$uh,$tvar)}}
                else
                  {${$uh->{VARREF_PRG}} = $$tvar}
              }
	  }
      }
    else
      {error("Type unrecognized for option [$flag]: [$type].")}

    return(0);
  }

#Takes the code reference, the associated usage hash, and an array or scalar
#reference value
sub callGOLCodeRef
  {
    my $sub = $_[0];
    my $uh  = $_[1];
    my $var = $_[2];

    my $supplied_opt_name = getBestFlag($uh);
    $supplied_opt_name =~ s/^-+//;

    if(ref($var) eq 'SCALAR')
      {$sub->($supplied_opt_name,$$var)}
    elsif(ref($var) eq 'ARRAY')
      {
        #If the reference of the supplied variable is the same reference as the
        #user default (i.e. it is the same array reference because the user
        #default is what was supplied as the $var being used to call $sub)
	if(defined($uh->{DEFAULT_USR}) && $var eq $uh->{DEFAULT_USR})
	  {
	    #Cycle through the saved user default arguments that were saved when
            #the user defaults were set (i.e. the delimited strings supplied to
            #each flag) and supply them to the programmer's sub
	    foreach my $gol_args_array (@{$uh->{SUPPLIED_ARGS_UDF}})
	      {$sub->(@$gol_args_array)}
	  }
        elsif(exists($uh->{SUPPLIED}) && defined($uh->{SUPPLIED}) &&
              $uh->{SUPPLIED} && scalar(@{$uh->{SUPPLIED_ARGS}}))
          {foreach my $gol_args_array (@{$uh->{SUPPLIED_ARGS}})
             {$sub->(@$gol_args_array)}}
        #Else, the programmer probably supplied a default array without a
        #delimiter
	else
	  {
	    #Build a getopt long argument list using the delimiter
	    my $delim = getDisplayDelimiter($uh->{DELIMITER},
					    $uh->{OPTTYPE},
					    $uh->{ACCEPTS});
            if(defined($delim) && $delim eq 'ERROR')
              {return(undef)}

	    if(exists($array2dopt_types->{$uh->{OPTTYPE}}))
	      {
                if(scalar(@$var))
                  {
                    foreach my $inner (@$var)
                      {
                        my $arg_str = join($delim,@$inner);
                        $sub->($supplied_opt_name,$arg_str);
                      }
                  }
                else
                  {
                    #All we can provide is a string. Test 869 demonstrates that
                    #doing so can be used to clear out the array, however it's
                    #debatable to possibly send undef if this is found to cause
                    #a problem in the future.  The undef would just have to be
                    #handled. This also presumes they treat the supplied value
                    #appropriately and not push it onto a pre-populated array
                    $sub->($supplied_opt_name,'');
                  }
	      }
	    elsif(defined($delim))
	      {
		my $arg_str = join($delim,@$var);
		$sub->($supplied_opt_name,$arg_str);
	      }
            else
              {
                #$uh->{DELIMITER} is always defined for 2D arrays, but may not
                #be defined for arrays, which forces a per-flag submission
                if(scalar(@$var))
                  {foreach my $elem (@$var)
                     {$sub->($supplied_opt_name,$elem)}}
                else
                  {
                    #See comment in the else above (inside the if)
                    $sub->($supplied_opt_name,'');
                  }
              }
	  }
      }
    else
      {error("Unsupported type: [",ref($var),"].")}
  }

#This is for VARREFs and DEFAULTs
#If definechk is true, it checks the definedness of bool and count values.
#Otherwise, it only returns true for those types when they have a non-zero value
sub hasValue
  {
    my $type      = $_[0];
    my $var       = $_[1];
    my $definechk = (defined($_[2]) ? $_[2] : 0); #Use to check var definedness
    my $has_value = 0; #undef = error

    if(ref($var) ne 'ARRAY' && ref($var) ne 'SCALAR' && ref($var) ne '')
      {
	error("Invalid variable type supplied: [",ref($var),"].",
	      {DETAIL => 'Only SCALAR and ARRAY are supported.'});
	return(undef);
      }
    elsif(!defined($type))
      {
        error("Type supplied to hasValue: [undef].",
	      {DETAIL => 'A defined type is required.'});
	return(undef);
      }

    if(exists($array_genopt_types->{$type}) ||
       exists($array2dopt_types->{$type}))
      {
	if(defined($var) && ref($var) ne 'ARRAY')
	  {error("Variable and option type [$type] mismatch: [",ref($var),
		 "] vs. [ARRAY].")}
	else
	  {$has_value = (defined($var) && scalar(@$var) ? 1 : 0)}
      }
    elsif(exists($scalaropt_types->{$type}))
      {
	#Note, if the type is bool, we will only say it has a value if it's true
	if(ref($var) eq 'SCALAR')
	  {
	    if($type eq 'bool' || $type eq 'count')
	      {$has_value = (defined($$var) && ($definechk || $$var) ? 1 : 0)}
	    elsif($type eq 'logfile' || $type eq 'logsuff')
	      {$has_value = (defined($$var) && $$var ne '' ? 1 : 0)}
	    else
	      {$has_value = (defined($$var) ? 1 : 0)}
	  }
	elsif(ref($var) eq '')
	  {$has_value = defined($var) &&
	     (!$definechk && ($type eq 'bool' || $type eq 'count') ?
              ($var ? 1 : 0) : 1)}
	else
	  {error("Variable and option type mismatch: [",ref($var),
		 "] vs. [$type: SCALAR].")}
      }
    else
      {error("Type unrecognized: [$type].")}

    return($has_value);
  }

#Returns (hierarchically) 2 if user default, 1 if programmr default, 0 otherwise
sub hasDefault
  {
    my $usg_hash = $_[0];
    my $pdef     = hasValue($usg_hash->{OPTTYPE},$usg_hash->{DEFAULT_PRG});
    my $udef     = hasValue($usg_hash->{OPTTYPE},$usg_hash->{DEFAULT_USR});
    return($udef ? 2 : ($pdef ? 1 : 0));
  }

sub getDefault
  {
    my $usg_hash = $_[0];

    if($command_line_stage < DEFAULTED)
      {
        warning('getDefault called before defaults have been fully processed.');
        return(hasValue($usg_hash->{OPTTYPE},$usg_hash->{DEFAULT_USR}) ?
               $usg_hash->{DEFAULT_USR} :
               (hasValue($usg_hash->{OPTTYPE},$usg_hash->{DEFAULT_PRG}) ?
                $usg_hash->{DEFAULT_PRG} : undef));
      }

    return(hasValue($usg_hash->{OPTTYPE},$usg_hash->{DEFAULT_CLI}) ?
           $usg_hash->{DEFAULT_CLI} : undef);
  }

sub getOptions
  {
    my $default_mode   = $_[0];
    my $initial_errors = defined($error_number) ? $error_number : 0;

    #Set the getopt_default_mode global for the getopt subs
    if(!defined($default_mode))
      {
        #Let the getopt subs know whether to initialize defaults or varrefs
        $getopt_default_mode = ($command_line_stage < DEFAULTED);
      }
    else
      {$getopt_default_mode = $default_mode}

    #Get the input options & catch any errors in option parsing
    if(!GetOptions(%$GetOptHash))
      {
        undef($getopt_default_mode);

	#This will set the usage, run, etc vars in a pinch based on the defaults
	determineRunMode(1);

	error('Getopt::Long::GetOptions() reported an error while parsing the ',
	      'command line arguments.  The warning should be above.  Please ',
	      'correct the offending argument(s) and try again.');
	quit(-12,0);
      }
    #Else if there are no flagless options but unprocessed arguments
    elsif((!defined($flagless_multival_optid) ||
	   $flagless_multival_optid < 0) && scalar(@ARGV))
      {
	my $argv_copy = [@ARGV];
	warning("Unprocessed/unrecognized command line arguments: [",
		join(' ',map {/\s/ ? "'$_'" : $_} @$argv_copy),"].");
      }

    undef($getopt_default_mode);

    if(defined($error_number) && $error_number > $initial_errors)
      {quit(-38)}

    ##TODO: See requirement #338 regarding this commented code
    #If pipeline mode is not defined and I know it will be needed (i.e. we
    #anticipate there will be messages printed on STDERR because either verbose
    #or DEBUG is true), guess - otherwise, do it lazily (in the warning or
    #error subs) because pgrep & lsof can be slow sometimes
#    if(!defined($pipeline) && ($verbose || $DEBUG))
#      {$pipeline = inPipeline()}

    return(0);
  }

sub processCommandLine
  {
    #Only ever run once (unless _init has been called)
    if($command_line_stage)
      {
	error("processCommandLine() has been called more than once ",
	      "without re-initializing.");
	return(0);
      }
    #This is in an else in case called in cleanup mode
    else
      {$command_line_stage = CALLED}

    #Keep track of errors during processing by saving the starting number
    my $initial_error_num = defined($error_number) ? $error_number : 0;

    #In case the programmer did not add any in/out files/dirs, add defaults
    my $fileopt_success = addDefaultFileOptions();

    $command_line_stage = STARTED;

    #Add the builtin options after the programmer's and default file opts, so
    #that files appear at the top of the usage
    if(addBuiltinOptions())
      {quit(-15)}

    #All necessary options added
    $command_line_stage = DECLARED;

    #Set user-saved defaults
    loadUserDefaults();

    #This is to indicate that all options are added and user defaults read in,
    #but the command line has not yet been processed.  This is above
    #applyOptionAddendums so it knows whether an outdir could still be added.
    $command_line_stage = DEFAULTED;

    #If there was a fatal error during the add default file options step, now is
    #the time to quit (after the defaults have been loaded and before the
    #command line is processed)
    if(!$fileopt_success)
      {quit(-7)}

    #Get the input options (0 means set varrefs, not defaults)
    getOptions(0);

    #Set the fact that the command line has been processed (after having added
    #the default options above with the calls to addDefaultFileOptions and
    #addRunModeOptions (because adding options checks this value to
    #decide whether adding options is valid))
    $command_line_stage = ARGSREAD;

    ##
    ## Validate Mutex Options and Set Defaults
    ##

    #Load all the previously saved default values for input files, output
    #files, output directories, arrays, and 2D arrays - Does not handle mutex
    #options
    my $fatal_def_req_file_errors = [fillInDefaults()];

    #Load defaults of mutex options and check for conflicts
    my $mutex_conflict = processMutuallyExclusiveOptionSets();

    #Determine actual run mode
    determineRunMode(0,scalar(@$fatal_def_req_file_errors));

    ##
    ## Edit options based on option values and option relationships
    ##

    #Certain options need to get addendums or be modified after user defaults &
    #command line options have been initialized.  Mostly, these are automated
    #notes added to the usage about mutually exclusive options, changes to
    #option visibility, and user defaults.  Some of these depend on the value of
    #--extended.
    applyOptionAddendums();

    $command_line_stage = VALIDATED;

    commitAllVarrefs();

    $command_line_stage = COMMITTED;

    #If we're in cleanup mode after a fatal error has occurred, quit has
    #already been called and all we needed to do was make sure all the command
    #line options had been added so that getOptions doesn't issue irrelevant
    #warnings.
    if($cleanup_mode > 1)
      {return(0)}

    my $force_ref      = getVarref('force');
    my $usage          = getVarref('usage',1);
    my $help           = getVarref('help',1);
    my $run            = getVarref('run',1);
    my $dry_run        = getVarref('dry_run',1);
    my $version        = getVarref('version',1);
    my $use_as_default = getVarref('save_args',1);

    #Don't allow saving of mutex conflicts
    if($use_as_default && $mutex_conflict)
      {quit(-11)}

    #Process & validate default options (supply whether there will be outfiles)
    my $done = processDefaultOptions(scalar(grep {$_->{OPTTYPE} eq 'suffix'}
                                            @$usage_array));
    if($done)
      {
        $command_line_stage = DONE;
        #1 = success, < 0 = fatal error
        quit($done < 0 ? $done : 0);
      }

    #If processCommandLine was called from quit (e.g. via the END block), calls
    #to quit (e.g. when usage or help modes are active) will not work (because
    #quit has already been called), so we must return here in either of those
    #cases to not generate weird errors.
    if($help || $usage == 1 || $use_as_default || $version)
      {return(0)}

    startLogging();

    $command_line_stage = LOGGING;

    #Now that all the vars are set, flush the buffer if necessary
    flushStderrBuffer();

    #If we are in either run or dry run mode, then any issues with default
    #files, directories, or mutex sets must now cause a fatal error
    if(scalar(@$fatal_def_req_file_errors) || $mutex_conflict)
      {
	error($_) foreach(@$fatal_def_req_file_errors);
	usage(1);
	quit(-19);
      }

    #The addRunModeOptions determineRunMode methods, (each
    #called earlier/above) establish whether the script should proceed or not
    #using $run and $dry_run.  We're going to evaluate the result here.
    if(!defined($run) || !defined($dry_run))
      {
	error("Fatal internal error - internal variables \$run and/or ",
	      "$dry_run should have had a default set.  Aborting run.  Use ",
	      "--force to get past this error.");
	quit(-13);
      }

    #If run and dry run are both false and this isn't an error state that will
    #be caught below (e.g. missing required params), error & quit
    if($usage != 2 && !$run && !$dry_run)
      {
	debug({LEVEL => -1},"Running with --usage [$usage] --help [$help] ",
	      "--run [$run] --dry-run [$dry_run]");

	#We're going to assume that this will only happen if --run is provided
	#as an option in the usage output.
	error("Either --run or --dry-run are required to run this script.  ",
	      "See --usage for details.  Note: --force will not circumvent ",
	      "this error.");
	#Do not allow the user to --force their way past this error
	$$force_ref = 0;
	quit(-14);
      }

    debug({LEVEL => -1},"Done processing default options.");

    ##
    ## Validate Required & Required Tagteam Options
    ##

    #Make sure that the tagteams' suffix and outfile options' mutual
    #exclusivity is enforced.  This also records which option was supplied on
    #the command line in tagteam_to_supplied_optid
    foreach my $ttkey (keys(%$outfile_tagteams))
      {validateTagteam($ttkey)}

    my $opts_sat = requiredOptionsSatisfied();
    my $rels_sat = requiredOptionRelationshipsSatisfied();
    if(!$opts_sat || !$rels_sat)
      {
	usage(1);
	quit(-17,0);
      }

    ##
    ## Validate Option Values
    ##

    #TODO: The outdir option will change.  See requirement 178.
    my $outdirs = [];
    my $oduhash = getOutdirUsageHash();
    if(defined($oduhash))
      {$outdirs = getVarref($oduhash)}

    #Require an outfile suffix if an outdir has been supplied
    if(scalar(@$outdirs) &&
       scalar(grep {$_->{OPTTYPE} eq 'suffix'} @$usage_array) == 0)
      {
	error("An outfile suffix is required if an output directory is ",
	      "supplied.");
	quit(-18,0);
      }

    unless(validateGeneralOptions())
      {quit(-48)}

    #If there are no files and we're in cleanup mode, we have already processed
    #the options to get things like verbose, debug, etc. and that's all we
    #need. We can assume that since quit has been called without having
    #processed the command line options, that the user is not using this module
    #for file processing, so return
    if($cleanup_mode &&
       scalar(grep {$_->{OPTTYPE} eq 'infile' &&
		      scalar(@{getVarref($_)})} @$usage_array) == 0)
      {
        #cleanup_mode 1 is when processCommandLine is never called.  >1 is from
        #a fatal error during setup
	$command_line_stage = $cleanup_mode == 1 ? DONE : LOGGING;
	return(0);
      }

    ##
    ## Check and prepare files for processing
    ##

    makeFileArrays();

    ($input_file_sets,   #getFileSets(3DinfileArray,2DsuffixArray,2DoutdirArray)
     $output_file_sets) = getFileSets($input_files_array,
				      $outfile_suffix_array,
				      $outdirs);

    #Create the output directories
    mkdirs(@$outdirs);

    my $header = getVarref('header',1,0);

    #If standard output is to a redirected file and the header flag has been
    #specified and there exists an undefined outfile suffix (which means that
    #output will go to STDOUT, print the header to STDOUT
    if($header && !isStandardOutputToTerminal() &&
       scalar(grep {!defined($_)} map {@$_} grep {defined($_)}
	      @$outfile_suffix_array))
      {
	#Open STDOUT to /dev/stdout because that's what the programmer's
	#supplied file handle will be opened to and we need it to go to the same
	#stream so that the header printed here is guaranteed to be at the top
	open(STDOUT,'>>/dev/stdout');
	print STDOUT (getHeader());
      }

    #Any/all errors during this sub should be followed by quit. If not, this
    #warning will be issued
    if(defined($error_number) && $initial_error_num != $error_number &&
       !$cleanup_mode && !$$force_ref)
      {warning("Uncaught fatal error during command-line processing.",
               {DETAIL => ('Fatal error numbers without exit or force: [' .
                           join(',',(($initial_error_num + 1)..$error_number)) .
                           '].')})}

    #Really done with command line processing
    $command_line_stage = DONE;

    #If there were errors during setup, quit with a bad exit status
    if($num_setup_errors)
      {quit(-2);}

    return(0);
  }

sub requiredOptionsSatisfied
  {
    #This makes sure that required tagteams had 1 of their 2 linked options
    #supplied
    my $missing_flags           = [];
    my $requirement_defficiency = 0;

    debug({LEVEL => -1},"Checking [",
	  scalar(grep {$_->{OPTTYPE} eq 'infile' && $_->{REQUIRED}}
		 @$usage_array),"] required input file types");

    #Now let's check other options
    #If there are unsatisfied required general or outdir options
    foreach my $usg_hash (grep {$_->{REQUIRED} && !optionSatisfied($_)}
			  @$usage_array)
      {
	$requirement_defficiency = 1;
	push(@$missing_flags,$usg_hash->{OPTFLAGS}->[0]);
      }

    foreach my $exclusive_set (map {$exclusive_options->[$_]}
			       grep {exists($mutual_params->{$_}) &&
				       exists($mutual_params->{$_}->{REQUIRED})
					 && $mutual_params->{$_}->{REQUIRED}}
			      (0..$#{$exclusive_options}))
      {
	my $one_supplied = 0;
	foreach my $optid (grep {optionSatisfied($usage_array->[$_])}
			   @$exclusive_set)
	  {
	    $one_supplied = 1;
	    last;
	  }

	if(!$one_supplied)
	  {
	    push(@$missing_flags,
		 [map {$usage_array->[$_]->{OPTFLAG_DEF}} @$exclusive_set]);
	    $requirement_defficiency = 1;
	  }
      }

    if($requirement_defficiency)
      {error('Missing required options: [',
             join(',',
                  map {ref($_) eq 'ARRAY' ? 'one of (' . join(',',@$_) . ')' :
                         $_} @$missing_flags),'].')}

    return(!$requirement_defficiency);
  }

#This does not check REQUIRED. It assumes the option is required. This is
#because an option's REQUIRED value may be 0, but may be in a required mutually
#exclusive set and is intended to be called for options in a set individually.
#See requiredOptionsSatisfied.  It is similar to hasValue when called with
#VARREF, but also checks standard in and out for PRIMARY options.  Also, this
#method assumes that default values have been filled in into the VARREF(_CPY)
sub optionSatisfied
  {
    my $usg_hash  = $_[0];
    my $satisfied = 1;

    #Allow the programmer to handle filling in the default, indicated by setting
    #a display default and not providing an actual default value
    if(defined($usg_hash->{DISPDEF}) &&
       !hasValue($usg_hash->{OPTTYPE},$usg_hash->{DEFAULT_PRG}))
      {
	debug("Allowing programmer to fill in default for option: [",
	      $usg_hash->{OPTFLAG_DEF},"] because display default (DISPDEF) ",
	      "is defined: [$usg_hash->{DISPDEF}] and no actual DEFAULT value ",
	      "was set.");
	return($satisfied);
      }

    if($usg_hash->{OPTTYPE} eq 'infile')
      {
	if(!hasValue($usg_hash->{OPTTYPE},getVarref($usg_hash)) &&
	   (!$usg_hash->{PRIMARY} || !isThereInputOnSTDIN()))
	  {$satisfied = 0}
      }
    elsif($usg_hash->{OPTTYPE} eq 'outfile' || $usg_hash->{OPTTYPE} eq 'suffix')
      {
	if(!hasValue($usg_hash->{OPTTYPE},getVarref($usg_hash)) &&
	   (!$usg_hash->{PRIMARY} || isStandardOutputToTerminal()))
	  {$satisfied = 0}
      }
    elsif(!hasValue($usg_hash->{OPTTYPE},getVarref($usg_hash)))
      {$satisfied = 0}

    return($satisfied)
  }

#This returns a flattened array of committed defined input files.  It is meant
#to be called after the command line options have been committed.  Note, we
#don't want a dash that's automatically added - we only want explicitly added
#dash(es).  This is so we can use the return of this method to check the
#validity of input present on STDIN.
sub getAllInfiles
  {
    if($command_line_stage < COMMITTED)
      {
        error("Internal method getAllInfiles called before the command line ",
              "options have been committed.");
        return(undef);
      }

    my $flat_infiles = [];

    foreach my $uhash (grep {$_->{OPTTYPE} eq 'infile'} @$usage_array)
      {
        my $inf_array2d = getVarref($uhash);
        if(defined($inf_array2d) && scalar(@$inf_array2d))
          {
            foreach my $inf_array (@$inf_array2d)
              {
                if(defined($inf_array) && scalar(@$inf_array))
                  {
                    foreach my $inf (@$inf_array)
                      {push(@$flat_infiles,$inf)}
                  }
              }
          }
      }

    return(wantarray ? @$flat_infiles : $flat_infiles);
  }

sub makeFileArrays
  {
    #For now, we will just populate the global variables:
    #  input_files_array        xx
    #  outfile_types_hash       xx
    #  outfile_suffix_array     xx
    #  file_indexes_to_usage    xx

    foreach my $uhash (grep {$_->{OPTTYPE} eq 'infile' ||
			       $_->{OPTTYPE} eq 'outfile' ||
				 $_->{OPTTYPE} eq 'suffix'} @$usage_array)
      {
	if($uhash->{OPTTYPE} eq 'infile')
	  {
	    my $file_type_index = scalar(@$input_files_array);
	    push(@$input_files_array,getVarref($uhash));
	    $uhash->{FILEID} = $file_type_index;
	  }
	elsif($uhash->{OPTTYPE} eq 'outfile')
	  {
	    my $file_type_index = scalar(@$input_files_array);
	    if(defined(getVarref($uhash)) && scalar(@{getVarref($uhash)}))
	      {push(@$input_files_array,getVarref($uhash))}
	    else
	      {push(@$input_files_array,[])}
	    $outfile_types_hash->{$file_type_index} = 1;
	    $uhash->{FILEID} = $file_type_index;
	  }
	elsif($uhash->{OPTTYPE} eq 'suffix')
	  {
	    my $file_type_index = $usage_array->[$uhash->{PAIRID}]->{FILEID};
	    my($suffix_index);
	    if((scalar(@$outfile_suffix_array) - 1) < $file_type_index ||
	       !defined($outfile_suffix_array->[$file_type_index]))
	      {
		$outfile_suffix_array->[$file_type_index] =
		  [getVarref($uhash,1)];
		$suffix_index = 0;
	      }
	    else
	      {
		$suffix_index =
		  scalar(@{$outfile_suffix_array->[$file_type_index]});
		push(@{$outfile_suffix_array->[$file_type_index]},
		     getVarref($uhash,1));
	      }
	    #Fix any subarrays in the middle that are undefined
	    foreach my $osi (0..$#{$outfile_suffix_array})
	      {if(!defined($outfile_suffix_array->[$osi]))
		 {$outfile_suffix_array->[$osi] = []}}

	    $file_indexes_to_usage->{$file_type_index}->{$suffix_index} =
	      $uhash->{OPTION_ID};
	  }
      }
  }

#This sub basically goes through the usage_array and preferentially assigns the
#user default or programmer default.
#Globals used: usage_array
sub fillInDefaults
  {
    my $fatal_errors = [];

    #Defaults of mutually exclusive options are handled in
    #processMutuallyExclusiveOptionSets because defaults should not be set if a
    #mutex option was supplied
    foreach my $usg_hash (grep {!exists($exclusive_lookup->{$_->{OPTION_ID}})}
			  @$usage_array)
      {
        #Set the final default value
        $usg_hash->{DEFAULT_CLI} =
          (defined($usg_hash->{DEFAULT_USR}) ?
           $usg_hash->{DEFAULT_USR} : $usg_hash->{DEFAULT_PRG});

        next if($usg_hash->{SUPPLIED});

	my($default);

	if(exists($scalaropt_types->{$usg_hash->{OPTTYPE}}))
	  {
	    #Select the default value
	    if(defined($usg_hash->{DEFAULT_USR}))
	      {$default = $usg_hash->{DEFAULT_USR}}
	    elsif(defined($usg_hash->{DEFAULT_PRG}))
	      {$default = $usg_hash->{DEFAULT_PRG}}

	    #If there's a defined default
	    if(defined($default))
	      {stageVarref($usg_hash,$default)}
	  }
	elsif((exists($array_genopt_types->{$usg_hash->{OPTTYPE}}) ||
	       exists($array2dopt_types->{$usg_hash->{OPTTYPE}})) &&
	      $usg_hash->{OPTTYPE} ne 'infile')
	  {
	    #Prefer the user's default, if present
	    if(defined($usg_hash->{DEFAULT_USR}) &&
	       scalar(@{$usg_hash->{DEFAULT_USR}}))
	      {$default = $usg_hash->{DEFAULT_USR}}
	    elsif(defined($usg_hash->{DEFAULT_PRG}) &&
		  scalar(@{$usg_hash->{DEFAULT_PRG}}))
	      {$default = $usg_hash->{DEFAULT_PRG}}

	    if(defined($default))
	      {stageVarref($usg_hash,$default)}
	  }
	elsif($usg_hash->{OPTTYPE} eq 'infile')
	  {
	    $default = [];
	    my($default,$glob_default,$twodarray);
	    #Prefer the user's default, if present
	    if(defined($usg_hash->{DEFAULT_USR}) &&
	       scalar(@{$usg_hash->{DEFAULT_USR}}))
	      {$glob_default = $usg_hash->{DEFAULT_USR}}
	    elsif(defined($usg_hash->{DEFAULT_PRG}) &&
		  scalar(@{$usg_hash->{DEFAULT_PRG}}))
	      {$glob_default = $usg_hash->{DEFAULT_PRG}}

	    #Globs should already have been expanded by the getoptSubHelper
	    if(defined($glob_default) && scalar(@$glob_default))
	      {
		my $got_some  = 0;
		my $err_globs = [];
		foreach my $glob_array (@$glob_default)
		  {
		    push(@$default,[]) if(scalar(@$glob_array));
		    foreach my $globstr (@$glob_array)
		      {
			my $files = [grep {-e $_} sglob($globstr,1)];
			if(scalar(@$files))
			  {
			    $got_some = 1;
			    push(@{$default->[-1]},@$files);
			  }
			else
			  {push(@$err_globs,$globstr)}
		      }
		  }

		if(scalar(@$err_globs) == 0 && scalar(@$default))
		  {stageVarref($usg_hash,$default)}
		elsif($got_some)
		  {
		    my $errmsg =
		      join('',
			   ("Some of the expected default input files were ",
			    "not found: [",join(' ',@$err_globs),"].  Unable ",
			    "to proceed.  Please create the default files."));
		    push(@$fatal_errors,$errmsg);
		  }
		elsif($usg_hash->{REQUIRED})
		  {
		    my $errmsg =
		      join('',
			   ("Expected required default input files were not ",
			    "found: [",join(' ',@$err_globs),"].  Unable to ",
			    "proceed.  Please create the default files."));
		    push(@$fatal_errors,$errmsg);
		  }
		#Else - quietly do not fill in default because it's not required
		#and the default glob didn't match anything
	      }
	  }
      }

    return(@$fatal_errors);
  }

sub requiredOptionRelationshipsSatisfied
  {
    my $relationship_violation = 0;

    #For every defined relationship pair. See REQ #341.
    foreach my $pair_from_id
      (grep {defined($usage_array->[$_]->{PAIRID})} (0..$#{$usage_array}))
      {
	my $pair_to_id   = $usage_array->[$pair_from_id]->{PAIRID};
	my $relationship = $usage_array->[$pair_from_id]->{RELATION};

	next unless(defined($pair_to_id));

	#If the relationship is infile-to-infile or outfile-to-infile
	if(($usage_array->[$pair_from_id]->{OPTTYPE} eq 'infile' ||
	    $usage_array->[$pair_from_id]->{OPTTYPE} eq 'outfile') &&
	   $usage_array->[$pair_to_id]->{OPTTYPE} eq 'infile')
	  {
	    ##TODO: Make this support more than just infile/outfile options
	    ##      See REQ #341

	    debug({LEVEL => -1},"Checking relationship of file options ",
		  "[$pair_from_id,",
		  (defined($pair_to_id) ? $pair_to_id : 'undef'),
		  "] is: [$relationship].");

	    my $test_files = getVarref($usage_array->[$pair_from_id]);

	    #If the test file type is not required and there are none, skip
	    if(scalar(@$test_files) == 0)
	      {
		if($usage_array->[$pair_from_id]->{REQUIRED})
		  {
		    my $hid = $usage_array->[$pair_from_id]->{HIDDEN};
		    if($hid && defined($primary_infile_optid) &&
		       $pair_from_id == $primary_infile_optid)
		      {error("Input file supplied via standard input redirect ",
			     "is required.")}
		    elsif(!$hid)
		      {error("Input file(s): [",
			     getFlag($usage_array->[$pair_from_id]),
			     "] are required.")}
		    else
		      {
			#This shouldn't happen, but putting it here just in case
			error("Input file supplied by hidden flag [",
			      getFlag($usage_array->[$pair_from_id],-1),
			      "] is required.");
		      }
		    $relationship_violation = 1;
		  }
		next;
	      }

	    #If the pair_to files do not matter
	    if($relationship =~ /^(\d+)$/)
	      {
		my $static_num_files = $1;
		if(scalar(@$test_files) != 1 ||
		   scalar(@{$test_files->[0]}) != $static_num_files)
		  {
		    my $numf = scalar(map {scalar(@$_)} @$test_files);
		    error("Exactly [$static_num_files] file",
			  ($static_num_files > 1 ? "s are " : " is "),
			  "expected via [",
			  getBestFlag($usage_array->[$pair_from_id]),"], but ",
			  "[$numf] (",join(',',map {scalar(@$_)} @$test_files),
			  ") ",($numf != 1 ? 'were' : 'was')," supplied.");
		    $relationship_violation = 1;
		  }
		next;
	      }

	    my $valid_files = [];
	    if(defined($pair_to_id))
	      {$valid_files = getVarref($usage_array->[$pair_to_id])}

	    ##TODO: The following logic does not make sense when the programmer CAN do something with the file type in question and the other type is not supplied (such as a secondary output file).  Case-in-point: codonHomologizer.pl can make a matrix file (1:1orM with sequence files) from a codon usage file, but the sequence files aren't needed to do that.  But is there any circumstance where this check makes sense?  Figure this out.
#	#If there are none of the files in the file type we're testing against,
#	#we cannot enforce the relationship.  This is an error.  Any of the
#	#relationship types require the one it's in a relationship with to be
#	#present.  Like, if file type 1 is supplied, file type 2 can be
#	#supplied with it in a specific relative number. Otherwise, file type 2
#	#by itself makes no sense. Note, it is assumed that global requirements
#	#are checked elsewhere.
#	if(scalar(@$valid_files) == 0)
#	  {
#	    error("File type: [",
#                 getFlag($usage_array->[fileIDToOptionID($test_ftype,'file')]),
#                 "] requires at least 1 file of type: [",
#                 getFlag($usage_array->[fileIDToOptionID($valid_ftype,'file')]),
#		  "] to be present, however none were supplied.");
#	    $relationship_violation = 1;
#	    next;
#	  }

	    if($relationship eq '1:M')
	      {
		if(!twoDArraysAre1toM($test_files,$valid_files))
		  {
		    error("There may be only 1 file supplied as: [",
			  getBestFlag($usage_array->[$pair_from_id]),
			  "] for each file group supplied as: [",
			  getBestFlag($usage_array->[$pair_to_id]),
			  "], however there were: [",
			  join(',',map {scalar(@$_)} @$test_files),"] files ",
			  "supplied with [",scalar(@$valid_files),"] files ",
			  "respectively.");
		    $relationship_violation = 1;
		  }
	      }
	    elsif($relationship eq '1:1')
	      {
		#If the outer arrays are not the same size or any of the inner
		#arrays are not the same size
		if(!twoDArraysAre1to1($test_files,$valid_files))
		  {
		    error("The number and group sizes of files supplied as [",
			  getBestFlag($usage_array->[$pair_from_id]),
			  "] and [",
			  getBestFlag($usage_array->[$pair_to_id]),
			  "] must be the same, but there were [",
			  join(',',map {scalar(@$_)} @$test_files),
			  "] and [",join(',',map {scalar(@$_)} @$valid_files),
			  "] files supplied.");
		    $relationship_violation = 1;
		  }
	      }
	    elsif($relationship eq '1:1orM')
	      {
		if(!twoDArraysAre1to1($test_files,$valid_files) &&
		   !twoDArraysAre1toM($test_files,$valid_files) &&
		   #Mixed state option:
		   #The outer arrays are the same size but inner test_files
		   #arrays are not a combo of equal and size 1
		   (scalar(@$test_files) == scalar(@$valid_files) &&
		    scalar(grep {scalar(@{$test_files->[$_]}) != 1 &&
				   scalar(@{$test_files->[$_]}) !=
				     scalar(@{$valid_files->[$_]})}
			   0..$#{$test_files})))
		  {
		    error("The number and group sizes of files supplied as [",
			  getBestFlag($usage_array->[$pair_from_id]),
			  "] and [",
			  getBestFlag($usage_array->[$pair_to_id]),
			  "] must either be the same or have a one to many ",
			  "relationship, but there were [",
			  join(',',map {scalar(@$_)} @$test_files),
			  "] and [",join(',',map {scalar(@$_)} @$valid_files),
			  "] files supplied.");
		    $relationship_violation = 1;
		  }
	      }
	    #NOTE: Requirement 140 needs to be implemented to properly support
	    #M:M
	    elsif($relationship eq 'M:M')
	      {
		#Since we already checked that some of each file are present,
		#there's nothing to check here.  Anything goes.
	      }
	    elsif($relationship ne '1' && $relationship ne '')
	      {error("Invalid relationship type (PAIR_RELAT): ",
		     "[$relationship].  Unable to enforce relationship ",
		     "between file types supplied as: [",
		     getBestFlag($usage_array->[$pair_from_id]),
		     "(ID:[$pair_from_id])",
		     getBestFlag($usage_array->[$pair_to_id]),
		     "(ID:[$pair_to_id])].")}
	  }
	elsif($usage_array->[$pair_from_id]->{OPTTYPE} eq 'logsuff' &&
	      $usage_array->[$pair_to_id]->{OPTTYPE} eq 'string')
	  {
	    #Relationship is irrelevant. Each opt is a scalar. Defaults should
	    #already be filled in.
	    if(($usage_array->[$pair_from_id]->{REQUIRED} ||
		$usage_array->[$pair_from_id]->{SUPPLIED}) &&
	       !hasValue($usage_array->[$pair_to_id]->{OPTTYPE},
			 getVarref($usage_array->[$pair_to_id])))
	      {
		error('Missing required dependent option: [',
                      getBestFlag($usage_array->[$pair_to_id]),'].',
                      {DETAIL =>
                       join('',("Option [",
                                getBestFlag($usage_array->[$pair_from_id]),
                                "] requires option [",
                                getBestFlag($usage_array->[$pair_to_id]),
                                "], but it was not supplied."))});
		$relationship_violation = 1;
	      }
	  }
	elsif($usage_array->[$pair_from_id]->{OPTTYPE} eq 'suffix' &&
	      $usage_array->[$pair_to_id]->{OPTTYPE} eq 'infile')
	  {
	    if(($usage_array->[$pair_from_id]->{REQUIRED} ||
		$usage_array->[$pair_from_id]->{SUPPLIED}) &&
	       !hasValue($usage_array->[$pair_to_id]->{OPTTYPE},
			 getVarref($usage_array->[$pair_to_id])) &&
	       (!$usage_array->[$pair_to_id]->{PRIMARY} ||
	        !isThereInputOnSTDIN()))
	      {
		error('Missing required dependent option: [',
                      getBestFlag($usage_array->[$pair_to_id]),'].',
                      {DETAIL =>
                       join('',("Option [",
                                getBestFlag($usage_array->[$pair_from_id]),
                                "] requires option [",
                                getBestFlag($usage_array->[$pair_to_id]),
                                "], but it was not supplied."))});
		$relationship_violation = 1;
	      }
	  }
	elsif($usage_array->[$pair_from_id]->{OPTTYPE} eq 'suffix' &&
	      $usage_array->[$pair_to_id]->{OPTTYPE} eq 'outfile')
	  {
	    #This is not a supported relationship for users.  It is a hidden/
	    #internally managed relationship
	  }
	else
	  {error("Unsupported option relationship: [",
		 $usage_array->[$pair_from_id]->{OPTTYPE},"] to [",
		 $usage_array->[$usage_array->[$pair_from_id]->{PAIRID}]
		 ->{OPTTYPE},"], [$usage_array->[$pair_from_id]->{RELATION}].")}
      }

    return(!$relationship_violation);
  }

#For use with testing the matching dimensionality of 2D file arrays
sub twoDArraysAre1toM
  {
    my $test_arrays  = $_[0];
    my $valid_arrays = $_[1];

    if((#There is 1 test group and multiple valid groups AND
	scalar(@$test_arrays) == 1 && scalar(@$valid_arrays) > 1 &&
	(#There is more than 1 file in the test group AND
	 scalar(@{$test_arrays->[0]}) > 1 &&
	 #The size of the test group is not equal to the number of grps
	 scalar(@{$test_arrays->[0]}) != scalar(@$valid_arrays))) ||
       (#There is 1 test group and 1 valid group AND
	scalar(@$test_arrays) == 1 && scalar(@$valid_arrays) == 1 &&
	#There is more than 1 test file
	scalar(@{$test_arrays->[0]}) > 1) ||
       (#There are multiple test groups AND
	scalar(@$test_arrays) > 1 &&
	(#A group is not equal to 1 in size OR
	 scalar(grep {scalar(@$_) != 1} @$test_arrays) ||
	 #The number of groups is not the same
	 scalar(@$test_arrays) != scalar(@$valid_arrays))))
      {return(0)}
    return(1);
  }

#For use with testing the matching dimensionality of 2D file arrays
sub twoDArraysAre1to1
  {
    my $test_arrays  = $_[0];
    my $valid_arrays = $_[1];

    if(scalar(@$test_arrays) != scalar(@$valid_arrays) ||
       scalar(grep {scalar(@{$test_arrays->[$_]}) !=
		      scalar(@{$valid_arrays->[$_]})} 0..$#{$test_arrays}))
      {return(0)}
    return(1);
  }

#This sub, given an input file type ID, will return the group of files that
#were all submitted with a single command line flag (e.g. -i 'file1 file2' -i
#'file3 file4') as an array of file names.
sub getNextFileGroup
  {
    my @in = getSubParams([qw(FILETYPEID)],[],[@_]);
    my $optid        = $in[0];
    my $file_type_id = (isInt($optid) && $optid >= 0 &&
			$optid <= $#{$usage_array} &&
			($usage_array->[$optid]->{OPTTYPE} eq 'infile' ||
			 $usage_array->[$optid]->{OPTTYPE} eq 'outfile') ?
			$usage_array->[$optid]->{FILEID} : undef);

    unless($command_line_stage)
      {processCommandLine()}

    if(defined($optid) && !defined($file_type_id))
      {
	error("Invalid infile option ID: [$optid].");
	return(undef);
      }

    #Allow file_type_id to be optional when there's only 1 infile type
    #OR allow file_type_id to be optional when called in list context
    ##TODO: Create an iterator to cycle through the types when no type ID is
    ##      supplied.  See requirement 181.
    if(!defined($file_type_id) && (getNumInfileTypes() == 1 || wantarray))
      {
	#Even if we're returning a list, we'll set a file that will
	#unnecessarily go through a conditional below to check for validity -
	#just so this sub will work in both contexts
	$file_type_id = (getInfileIndexes())[0];

	if(!defined($file_type_id))
	  {
	    error("No input file options could be found.");
	    return(undef);
	  }
      }

    if(!defined($file_group_num) || !defined($file_group_num->[$file_type_id]))
      {$file_group_num->[$file_type_id] = 0}
    else
      {$file_group_num->[$file_type_id]++}

    #If the file group number is greater than the number of groups of files
    #(i.e. the number of times the input file's flag was supplied) return undef
    if($file_group_num->[$file_type_id] >=
       scalar(@{$input_file_sets->[$file_type_id]}))
      {return(undef)}

    if(wantarray)
      {return(@{$input_files_array->[$file_type_id]
		  ->[$file_group_num->[$file_type_id]]})}

    return([@{$input_files_array->[$file_type_id]
		->[$file_group_num->[$file_type_id]]}]);
  }

sub resetFileGroupIterator
  {
    my @in = getSubParams([qw(FILETYPEID)],[],[@_]);
    my $optid        = $in[0];
    my $file_type_id = (isInt($optid) && $optid >= 0 &&
			$optid <= $#{$usage_array} &&
			($usage_array->[$optid]->{OPTTYPE} eq 'infile' ||
			 $usage_array->[$optid]->{OPTTYPE} eq 'outfile') ?
			$usage_array->[$optid]->{FILEID} : undef);

    unless($command_line_stage)
      {processCommandLine()}

    if(defined($optid) && !defined($file_type_id))
      {
	error("Invalid infile option ID: [$optid].");
	return(undef);
      }

    #Allow file_type_id to be optional when there's only 1 infile type
    #OR allow file_type_id to be optional when called in list context
    ##TODO: Create an iterator to cycle through the types when no type ID is
    ##      supplied.  See requirement 181.
    if(!defined($file_type_id) && (getNumInfileTypes() == 1 || wantarray))
      {
	#Even if we're returning a list, we'll set a file that will
	#unnecessarily go through a conditional below to check for validity -
	#just so this sub will work in both contexts
	$file_type_id = (getInfileIndexes())[0];

	if(!defined($file_type_id))
	  {
	    error("No input file options could be found.");
	    return(undef);
	  }
      }

    $file_group_num->[$file_type_id] = -1;
  }

#This sub, given an input file type ID, will return an array of groups of files
#that were submitted with all instances of a command line flag
#(e.g. -i 'file1 file2' -i 'file3 file4') results in a 2D array:
#[[file1,file2],[file3,file4]].
sub getAllFileGroups
  {
    my @in = getSubParams([qw(FILETYPEID)],[],[@_]);
    my $optid        = $in[0];
    my $file_type_id = (isInt($optid) && $optid >= 0 &&
			$optid <= $#{$usage_array} &&
			($usage_array->[$optid]->{OPTTYPE} eq 'infile' ||
			 $usage_array->[$optid]->{OPTTYPE} eq 'outfile') ?
			$usage_array->[$optid]->{FILEID} : undef);

    unless($command_line_stage)
      {processCommandLine()}

    if(defined($optid) && !defined($file_type_id))
      {
	error("Invalid infile option ID: [$optid].");
	return(undef);
      }

    #Allow file_type_id to be optional when there's only 1 infile type
    #OR allow file_type_id to be optional when called in list context
    ##TODO: Create an iterator to cycle through the types when no type ID is
    ##      supplied.  See requirement 181.
    if(!defined($file_type_id) && (getNumInfileTypes() == 1 || wantarray))
      {
	#Even if we're returning a list, we'll set a file that will
	#unnecessarily go through a conditional below to check for validity -
	#just so this sub will work in both contexts
	$file_type_id = (getInfileIndexes())[0];

	if(!defined($file_type_id))
	  {
	    error("No input file options could be found.");
	    return(undef);
	  }
      }

    #Do not warn about unprocessed file sets if this method is called
    $unproc_file_warn = 0;

    if(wantarray)
      {return(map {[@$_]} @{$input_files_array->[$file_type_id]})}

    return([map {[@$_]} @{$input_files_array->[$file_type_id]}]);
  }

sub getNumFileGroups
  {
    debug({LEVEL => -10},"getNumFileGroups called.");
    my @in = getSubParams([qw(FILETYPEID)],[],[@_]);
    my $optid        = $in[0];
    my $file_type_id = (isInt($optid) && $optid >= 0 &&
			$optid <= $#{$usage_array} &&
			($usage_array->[$optid]->{OPTTYPE} eq 'infile' ||
			 $usage_array->[$optid]->{OPTTYPE} eq 'outfile') ?
			$usage_array->[$optid]->{FILEID} : undef);

    unless($command_line_stage)
      {processCommandLine()}

    if(defined($optid) && !defined($file_type_id))
      {
	error("Invalid infile option ID: [$optid].");
	return(undef);
      }

    #Allow file_type_id to be optional when there's only 1 infile type
    #OR allow file_type_id to be optional when called in list context
    ##TODO: Create an iterator to cycle through the types when no type ID is
    ##      supplied.  See requirement 181.
    if(!defined($file_type_id) && (getNumInfileTypes()  == 1 || wantarray))
      {
	#Even if we're returning a list, we'll set a file that will
	#unnecessarily go through a conditional below to check for validity -
	#just so this sub will work in both contexts
	$file_type_id = (getInfileIndexes())[0];

	if(!defined($file_type_id))
	  {
	    error("No input file options could be found.");
	    return(undef);
	  }
      }

    debug({LEVEL => -10},"Returning number of files for type: ",
	  "[$file_type_id] as: [",
	  scalar(@{$input_files_array->[$file_type_id]}),
	  "] with first file: [$input_files_array->[$file_type_id]->[0]].");

    return(scalar(grep {my $a = $_;scalar(@$a) !=
			  scalar(grep {!defined($_)} @$a)}
		  @{$input_files_array->[$file_type_id]}));
  }

sub getFileGroupSizes
  {
    my @in = getSubParams([qw(FILETYPEID)],[],[@_]);
    my $optid        = $in[0];
    my $file_type_id = (isInt($optid) && $optid >= 0 &&
			$optid <= $#{$usage_array} &&
			($usage_array->[$optid]->{OPTTYPE} eq 'infile' ||
			 $usage_array->[$optid]->{OPTTYPE} eq 'outfile') ?
			$usage_array->[$optid]->{FILEID} : undef);

    unless($command_line_stage)
      {processCommandLine()}

    if(defined($optid) && !defined($file_type_id))
      {
	error("Invalid infile option ID: [$optid].");
	return(undef);
      }

    #Allow file_type_id to be optional when there's only 1 infile type
    #OR allow file_type_id to be optional when called in list context
    ##TODO: Create an iterator to cycle through the types when no type ID is
    ##      supplied.  See requirement 181.
    if(!defined($file_type_id) &&
       (getNumInfileTypes() == 1 || wantarray))
      {
	#Even if we're returning a list, we'll set a file that will
	#unnecessarily go through a conditional below to check for validity -
	#just so this sub will work in both contexts
	$file_type_id = (getInfileIndexes())[0];

	if(!defined($file_type_id))
	  {
	    error("No input file options could be found.");
	    return(undef);
	  }
      }

    if(wantarray)
      {return(map {scalar(@$_)} @{$input_files_array->[$file_type_id]})}

    return([map {scalar(@$_)} @{$input_files_array->[$file_type_id]}]);
  }

#Copies all hash arguments' contents from the parameter array into 1 hash.
#All other arguments must be scalars - otherwise generates an error.  This sub
#is intended to be used by methods which take a series of strings, such as
#error(), warning(), and debug().
sub getStrSubParams
  {
    my $keys_array = [];
    #If a list of keys to search for was not provided
    if(scalar(@_) < 1 || ref($_[0]) ne 'ARRAY' ||
       scalar(grep {ref(\$_) ne 'SCALAR'} @{$_[0]}))
      {
	#Issue a warning and allow it to proceed for backward compatibility
	warning("A minimum of 1 parameter is required, and the first must be ",
		"an array reference with scalar values.",
		(scalar(@_) ? ("  Returning the contents of all hashes for " .
			       "backward compatibility.") : ''));
      }
    else
      {$keys_array = shift(@_)}

    my $opts   = {};
    my @params = ();
    foreach my $param (@_)
      {
	if(!defined($param) || ref($param) ne 'HASH' ||
	   (scalar(@$keys_array) &&
	    scalar(grep {exists($param->{$_})} @$keys_array) == 0))
	  {
	    push(@params,$param);
	    next;
	  }
	my $opthash = $param;

	foreach my $optname (keys(%$opthash))
	  {
	    if(exists($opts->{$optname}))
	      {error("Multiple options with the same name: [$optname].  ",
		     "Overwriting.")}
	    $opts->{$optname} = $opthash->{$optname};
	  }
      }

    #If keys were not found, set them to undef
    foreach my $key (@$keys_array)
      {if(!exists($opts->{$key}))
	 {$opts->{$key} = undef}}

    return($opts,@params);
  }

#This method exists for backward compatibility - to support methods
#which expect parameters submitted in a specific order.  It processes
#parameters submitted to a method by taking those parameters and a list of
#hash keys (in order in which the method assigns the values in the returned
#array) and extracts the values to return them in an ordered array.  Undef is
#substituted for any missing parameters.
#It also checks for required parameters by taking a list of required hash keys.
#If the user has submitted parameters as an array instead of a hash, the number
#of required paraeters is used as a minimum number of parameters.
sub getSubParams
  {
    if(scalar(@_) < 3 || scalar(@_) > 5)
      {
	error("Three parameters are required: all keys, required keys, and ",
	      "the parameters submitted to the method.  A boolean ",
	      "'strict' parameter is an optional fourth parameter.  A scalar ",
              "reference to a boolean indicating whether no valid keys were ",
              "detected is an optional fifth parameter.");
	return(undef);
      }

    my $keys       = shift(@_);
    my $reqd       = shift(@_);
    my $unproc     = shift(@_);
    my $strict     = (scalar(@_) ? shift(@_) : 0);
    my $nokeys_ref = (scalar(@_) ? shift(@_) : \my $tmp);
    $$nokeys_ref = 0;
    my $sub;
    my $stack = 0;
    while(my @info = caller($stack))
      {
	$stack++;
	$sub = $info[3];
	$sub =~ s/.*://;
	last if($sub ne 'getSubParams');
      }
    $sub = '' unless($sub);
    my($params);

    debug({LEVEL => -9},"Keys passed in: [",join(',',@$keys),"].");
    debug({LEVEL => -9},"Required keys passed in: [",join(',',@$reqd),"].");

    if(ref($keys) ne 'ARRAY' || scalar(grep {ref($_) ne ''} @$keys))
      {
	error("Invalid keys parameter.  The first parameter must be a ",
	      "reference to an array of hash keys.");
	return(undef);
      }

    if(ref($reqd) ne 'ARRAY' || scalar(grep {ref($_) ne ''} @$reqd))
      {
	error("Invalid required keys parameter.  The second parameter must ",
	      "be a reference to an array of required hash keys.");
	return(undef);
      }

    #For backward-compatibility, assume this is a method call from a script
    #written using an older version of CommandLineInterface (or
    #perl_script_template.pl)
    if(!$strict && (scalar(@$unproc) % 2) == 1)
      {
	debug({LEVEL => -1},
	      "Returning params as-is for backward compatibility because ",
	      "there is an odd number: [",scalar(@$unproc),"] of parameters: ",
	      "[",join(',',map {defined($_) ? $_ : 'undef'} @$unproc),"].");

	if(scalar(@$unproc) < scalar(@$reqd))
	  {
	    error("$sub requires at least [",scalar(@$reqd),"] parameters (",
		  join(',',@$reqd),"), but only [",scalar(@$unproc),
		  "] were sent in.");
	    quit(-22);
	  }

	return(@$unproc);
      }
    elsif(defined($DEBUG) && $DEBUG <= -1)
      {debug({LEVEL => -9},"Returning parsed parameters: [",
	     join(',',map {defined($_) ? $_ : 'undef'} @$unproc),"].\n")}

    my $checks = {};

    foreach my $key (map {split(/\|/,$_)} @$keys)
      {$checks->{$key} = 0}

    if(scalar(map {split(/\|/,$_)} @$reqd) !=
       scalar(grep {exists($checks->{$_})} map {split(/\|/,$_)} @$reqd))
      {
	error("Invalid required keys parameter.  The required keys must be a ",
	      "subset of all keys provided in the first parameter, but these ",
	      "keys were not present: [",
	      join(',',(grep {!exists($checks->{$_})} map {split(/\|/,$_)}
			@$reqd)),"].");

	quit(-23);
      }

    #If the alleged keys in the hash are not scalars or are undefined
    if(scalar(grep {($_ % 2) == 0 && (!defined($unproc->[$_]) ||
				      ref($unproc->[$_]) ne '')}
	      (0..$#{$unproc})))
      {
	debug({LEVEL => -1},"Non-scalar or undefined keys found, so ",
	      "returning all params for backward compatibility.");

	if(scalar(@$unproc) < scalar(@$reqd))
	  {
	    error("$sub requires at least [",scalar(@$reqd),"] parameters (",
		  join(',',@$reqd),"), but only [",scalar(@$unproc),
		  "] were sent in.");
	    quit(-24);
	  }

	if($strict)
	  {
	    error("Invalid or undefined keys passed in.");
	    return(undef);
	  }
	return(@$unproc);
      }
    else
      {
	my $a_match    = scalar(grep {exists($checks->{$_})}
				map {$unproc->[$_]}
				grep {$_ % 2 == 0} (0..$#{$unproc}));
	my @nonmatches = grep {!exists($checks->{$_})} map {$unproc->[$_]}
	  grep {$_ % 2 == 0} (0..$#{$unproc});

	if(!$a_match)
	  {
            $$nokeys_ref = 1;
	    debug({LEVEL => -1},"No matching keys passed to $sub: [",
		  join(',',@$keys),"], so returning all params [",
		  join(',',map {defined($_) ? $_ : 'undef'} @$unproc),
		  "] for backward compatibility.\n") unless($strict);

	    if(scalar(@$unproc) < scalar(@$reqd))
	      {
		error("$sub requires at least [",scalar(@$reqd),
		      "] parameters (",join(',',@$reqd),"), but only [",
		      scalar(@$unproc),"] were sent in.");
		quit(-25);
	      }

	    if($strict)
	      {
		error("No matching keys passed to $sub: [",
		      join(',',@$keys),"] found.");
		return(undef);
	      }
	    elsif(scalar(@$unproc) &&
		  scalar(grep {$unproc->[$_] =~ /^[A-Z_]{3,}$/}
			 grep {$_ % 2 == 0} (0..$#{$unproc})) ==
		  scalar(grep {$_ % 2 == 0} (0..$#{$unproc})))
	      {
		warning("No matching keys passed to $sub: [",join(',',@$keys),
			"] found.  Assuming they are valid parameters not in ",
			"hash format.");
	      }

	    return(@$unproc);
	  }
	elsif(scalar(@nonmatches))
	  {
	    error("Unrecognized hash key(s) encountered in parameters passed ",
		  "to $sub: [",join(',',@nonmatches),"].");

	    if($strict)
	      {
		@$unproc = map {$unproc->[$_],$unproc->[$_ + 1]}
		  grep {exists($checks->{$unproc->[$_]})}
		    grep {$_ % 2 == 0} (0..$#{$unproc});
	      }
	  }
	debug({LEVEL => -9},"A match? [$a_match] Non-matches? [",
	      scalar(@nonmatches),"].");
      }

    #It should now be safe to instantiate a hash
    my $hash = {@$unproc};

    #Check for missing required parameters
    my @missing = ();
    foreach my $rkey (@$reqd)
      {
	my @aliases = split(/\|/,$rkey);
	my $occurrences = scalar(grep {exists($hash->{$_})} @aliases);
	if($occurrences == 0)
	  {push(@missing,$rkey)}
      }

    #Check for duplicate parameters that are the result of using multiple
    #aliases for the same parameter.
    my @dupes = ();
    foreach my $key (@$keys)
      {
	my @aliases = split(/\|/,$key);
	my $occurrences = scalar(grep {exists($hash->{$_})} @aliases);
	if($occurrences > 1)
	  {push(@dupes,$key)}
      }

    if(scalar(@missing) || scalar(@dupes))
      {
	if(scalar(@missing))
	  {error("$sub: Required parameters missing: [",join(',',@missing),
		 "].",($command_line_stage ?
		       '  Use --force to get past this error.' : ''))}
	if(scalar(@dupes))
	  {error("$sub: Duplicate parameter aliases encountered: [",
		 join(',',@missing),"].",
		 ($command_line_stage ?
		  '  Use --force to get past this error.  Note, the value ' .
		  'of the aliases will be randomly selected.' : ''))}
	quit(-26);
      }

    #Convert each key into its supplied value (or undef)
    $params = [map {my @als = split(/\|/,$_);my($r);
		    foreach my $flg (@als)
		      {if(exists($checks->{$flg}) && exists($hash->{$flg}))
			 {$r = $hash->{$flg};last;}}
		    $r}
	       @$keys];

    if(wantarray)
      {return(@$params)}

    return($params);
  }

##
## Method that prints formatted verbose messages.  Specifying a 1 as the
## first argument prints the message in overme mode (meaning subsequence
## verbose, error, warning, or debug messages will write over the message
## printed here.  However, specifying a hard return as the first character will
## override the status of the last line printed and keep it.  Global variables
## keep track of print length so that previous lines can be cleanly
## overwritten.  Note, this method buffers output until $verbose is defined
## in main.  The buffer will be emptied the first time verbose() is called
## after $verbose has been defined.  The purpose of this is to still output
## verbose messages that were generated before the command line --verbose flag
## has been processed.
##
sub verbose
  {
    #Flush the stderr buffer if it's populated and basic options have been set
    flushStderrBuffer() if($command_line_stage >= DONE);
    #Return if we know verbose mode is off
    my($verbose);
    if($command_line_stage >= DONE)
      {
	$verbose = getVarref('verbose',1);
	return(0) if(defined($verbose) && !$verbose);
      }

    #Grab the options from the parameter array
    my($opts,@params) =
      getStrSubParams([qw(OVERME LEVEL FREQUENCY COMMENT LOG)],@_);
    my $overme_flag   = (exists($opts->{OVERME}) && defined($opts->{OVERME}) ?
			 $opts->{OVERME} : 0);
    my $message_level = (exists($opts->{LEVEL}) && defined($opts->{LEVEL}) ?
			 $opts->{LEVEL} : 1);
    my $frequency     = (exists($opts->{FREQUENCY}) &&
			 defined($opts->{FREQUENCY}) &&
			 $opts->{FREQUENCY} > 0 ? $opts->{FREQUENCY} : 1);
    my $local_log_verbose = (exists($opts->{LOG}) && defined($opts->{LOG}) &&
			     $opts->{LOG} ? 1 : $log_verbose);
    my $local_log_only    = (exists($opts->{LOG}) && defined($opts->{LOG}) &&
			     $opts->{LOG} ? 1 : !$log_mirror);
    #If comment is a non-zero int, use '#', 0 use '', anything else - use it
    my $comment_char  =
      (exists($opts->{COMMENT}) && defined($opts->{COMMENT}) &&
       $opts->{COMMENT} ne '' ? (isInt($opts->{COMMENT}) ?
				 ($opts->{COMMENT} ? '#' : '') :
				 $opts->{COMMENT}) : '');

    if($frequency =~ /\./)
      {
	warning("The frequency value: [$frequency] must be an integer (e.g. ",
		"print every 100th line).");
	$frequency = ($frequency < 1 ? 1 : int($frequency));
      }

    #If we're not printing every one of these verbose messages
    if($frequency > 1)
      {
	#Determine what line the verbose call was made from so we can track
	#how many times it has been called
	my(@caller_info,$line_num);
	my $stack_level = 0;
	while(@caller_info = caller($stack_level))
	  {
	    $line_num = $caller_info[2];
	    last if(defined($line_num));
	    $stack_level++;
	  }

	#Initialize the frequency hash to track number of calls from this line
	#of code
	if(!defined($verbose_freq_hash))
	  {$verbose_freq_hash->{$line_num} = 1}
	else
	  {$verbose_freq_hash->{$line_num}++}

	#If the number of calls is evenly divisible by the frequency
	return(0) if($verbose_freq_hash->{$line_num} % $frequency != 0);
      }

    #Return if $verbose is greater than a negative level at which this message
    #is printed or if $verbose is less than a positive level at which this
    #message is printed.  Negative levels are for template diagnostics.
    return(0) if($command_line_stage >= DONE && defined($verbose) &&
		 (($message_level < 0 && $verbose > $message_level) ||
		  ($message_level > 0 && $verbose < $message_level)));

    #Grab the message from the parameter array
    my $verbose_message =
      $comment_char . join('',map {defined($_) ? $_ : 'undef'} @params);
    if($comment_char ne '')
      {
	$verbose_message =~ s/(?<!\A)\n(?!\z)/\n$comment_char/g;
	$verbose_message =~ s/$comment_char$//g;
      }

    #Turn on the overwrite flag automatically if carriage returns are found
    $overme_flag = 1 if(!$overme_flag && $verbose_message =~ /\r/);

    #Initialize globals if not done already
    $last_verbose_size  = 0 if(!defined($last_verbose_size));
    $last_verbose_state = 0 if(!defined($last_verbose_state));
    $verbose_warning    = 0 if(!defined($verbose_warning));

    #Determine the message length
    my($verbose_length);
    if($overme_flag)
      {
	$verbose_message =~ s/\r$//;
	if(defined($verbose) && $verbose && !$verbose_warning &&
	   $verbose_message =~ /\n|\t/)
	  {
	    warning('Hard returns and tabs cause overme mode to not work ',
		    'properly.');
	    $verbose_warning = 1;
	  }
      }
    else
      {chomp($verbose_message)}

    #If this message is not going to be over-written (i.e. we will be printing
    #a \n after this verbose message), we can reset verbose_length to 0 which
    #will cause $last_verbose_size to be 0 the next time this is called
    if(!$overme_flag)
      {$verbose_length = 0}
    #If there were \r's in the verbose message submitted (after the last \n)
    #Calculate the verbose length as the largest \r-split string
    elsif($verbose_message =~ /\r[^\n]*$/)
      {
	my $tmp_message = $verbose_message;
	$tmp_message =~ s/.*\n//;
	($verbose_length) = sort {$b <=> $a} map {length($_)}
	  split(/\r/,$tmp_message);
      }
    #Otherwise, the verbose_length is the size of the string after the last \n
    elsif($verbose_message =~ /([^\n]*)$/)
      {$verbose_length = length($1)}

    #If the buffer is not being flushed, the verbose output doesn't start with
    #a \n, and output is to the terminal, make sure we don't over-write any
    #STDOUT output
    #NOTE: This will not clean up verbose output over which STDOUT was written.
    #It will only ensure verbose output does not over-write STDOUT output
    #NOTE: This will also break up STDOUT output that would otherwise be on one
    #line, but it's better than over-writing STDOUT output.  If STDOUT is going
    #to the terminal, it's best to turn verbose off.
    if(!$| && $verbose_message !~ /^\n/ && isStandardOutputToTerminal())
      {
	#The number of characters since the last flush (i.e. since the last \n)
	#is the current cursor position minus the cursor position after the
	#last flush (thwarted if user prints \r's in STDOUT)
	#NOTE:
	#  tell(STDOUT) = current cursor position
	#  sysseek(STDOUT,0,1) = cursor position after last flush (or undef)
	my $num_chars = sysseek(STDOUT,0,1);
	if(defined($num_chars))
	  {$num_chars = tell(STDOUT) - $num_chars}
	else
	  {$num_chars = 0}

	#If there have been characters printed since the last \n, prepend a \n
	#to the verbose message so that we do not over-write the user's STDOUT
	#output
	if($num_chars > 0)
	  {$verbose_message = "\n$verbose_message"}
      }

    #Write over the previous verbose message by appending spaces before the
    #first hard return in the verbose message IF THE VERBOSE MESSAGE DOESN'T
    #BEGIN WITH A HARD RETURN.  However note that the length stored as the
    #last_verbose_size is the length of the last line printed in this message.
    if($verbose_message =~ /^([^\n]*)/ && $last_verbose_state &&
       $verbose_message !~ /^\n/)
      {
	my $spacelen = (defined($last_verbose_size) ? $last_verbose_size : 0) -
	  length($1);
	$spacelen = 0 if($spacelen < 0);
	my $addendum = ' ' x $spacelen;
	unless($verbose_message =~ s/\n/$addendum\n/)
	  {$verbose_message .= $addendum}
      }

    #If you don't want to write over the last verbose message in a series of
    #overwritten verbose messages, you can begin your verbose message with a
    #hard return.  This tells verbose() to not write over the last line
    #printed in overme mode.

    $verbose_message .= ($overme_flag ? "\r" : "\n");

    #If the command line has been sufficiently processed...  (Note, even if
    #verbose is defined, it could get changed by the user after the command line
    #is processed.  We check that command_line_stage is >= 6 because it means
    #that the verbose value has been validated.)
    if($command_line_stage >= DONE)
      {
	#Flush the buffer if it is defined
	flushStderrBuffer() if(defined($stderr_buffer));

	if($verbose &&
	   (($message_level < 0 && $verbose <= $message_level) ||
	    ($message_level > 0 && $verbose >= $message_level)))
	  {
	    #Print the current message to standard error
	    print STDERR ($verbose_message)
	      if(!(exists($opts->{LOG}) && defined($opts->{LOG}) &&
                   $opts->{LOG}) && (!$logging || !$local_log_only ||
                                     !$local_log_verbose));

	    #Only logs if in logging mode
	    logger($verbose_message) if(!$overme_flag && $local_log_verbose ||
					#Allow overme to be logged if local
				        (exists($opts->{LOG}) &&
					 defined($opts->{LOG}) &&
					 $opts->{LOG}));
	  }
      }
    else
      {
	#Store the message in the stderr buffer until $verbose has been defined
	#by the command line options (using Getopt::Long)
	push(@{$stderr_buffer},
	     ['verbose',
	      $message_level,
	      $verbose_message,
              undef,undef,undef,undef,undef,
              $opts,getTrace()]);
      }

    #Record the state
    $last_verbose_size  = $verbose_length;
    $last_verbose_state = $overme_flag;

    #Return success
    return(0);
  }

sub verboseOverMe
  {verbose({OVERME=>1},@_)}

#Logs messages that do not contain carriage returns (which are assumed to be
#from calls to verboseOverMe()
#Globals used: $logging, $log_handle
sub logger
  {
    my $message = $_[0];
    if(defined($logging) && $logging)
      {
	$message =~ s/ +\n/\n/g;
	print $log_handle ($message);
      }
  }

##
## Method that prints errors with a leading program identifier containing a
## trace route back to main to see where all the method calls were from,
## the line number of each call, an error number, and the name of the script
## which generated the error (in case scripts are called via a system call).
##
sub error
  {
    #Flush the stderr buffer if it's populated and basic options have been set
    flushStderrBuffer() if($command_line_stage >= DONE);

    #Determine behaviors from command line options, if CL has been processed
    my($quiet,$verbose,$DEBUG,$pipeline,$extended,$error_limit);
    my $clear_vom = 0;
    my $debug_ldr = 1;
    if($command_line_stage >= COMMITTED)
      {
	#Return if we know quiet mode is on
	$quiet = getVarref('quiet',1,0,1);
	return(0) if(defined($quiet) && $quiet);

	$verbose       = getVarref('verbose',  1,0,1);
	$DEBUG         = getVarref('debug',    1,0,1);
	$extended      = getVarref('extended', 1,1,1);
	$error_limit   = getVarref('error_lim',1,1,1);
	$pipeline      = getVarref('pipeline', 1,1,1);

	$clear_vom     = defined($verbose) && $verbose;
	$debug_ldr     = defined($DEBUG) && $DEBUG;

	if(!defined($pipeline))
	  {$pipeline = inPipeline()}
      }

    #Extract any possible parameters
    my($opts,@params) = getStrSubParams([qw(DETAIL)],@_);
    my $detail        = $opts->{DETAIL};
    my $detail_alert  = "Supply --extended for additional details.";

    #Gather and concatenate the error message and split on hard returns
    my @error_message = split(/\n/,join('',grep {defined($_)} @params));
    push(@error_message,'') unless(scalar(@error_message));
    pop(@error_message) if(scalar(@error_message) > 1 &&
			   $error_message[-1] !~ /\S/);

    #If DETAIL was supplied/defined and the command line has been processed),
    #append a detailed message based on the value of $extended
    if(defined($detail) && $command_line_stage >= DONE)
      {
	if($extended)
	  {push(@error_message,split(/(?<=\n)/,$detail))}
	else
	  {push(@error_message,$detail_alert)}
      }

    $error_number++;
    my $leader_string      = "ERROR$error_number:";
    my $simple_leader      = $leader_string;
    my $leader_string_pipe = $leader_string;
    my $simple_leader_pipe = $leader_string;

    my $caller_string = getTrace();
    my $script        = getScriptName();

    if($caller_string =~ /CommandLineInterface\.pm/)
      {$cli_error_num++}

    #If the command line has been parsed and we're in a pipeline,
    #prepend a call-trace
    if($command_line_stage >= ARGSREAD &&
       defined($pipeline) && $pipeline)
      {
	$leader_string .= "$script:";
	$simple_leader .= "$script:";
      }
    $leader_string_pipe .= "$script:";
    $simple_leader_pipe .= "$script:";

    if($debug_ldr)
      {$leader_string .= $caller_string}

    $leader_string      .= ' ';
    $simple_leader      .= ' ';
    $leader_string_pipe .= ' ';
    $simple_leader_pipe .= ' ';
    my $leader_length      = length($leader_string);
    my $simple_length      = length($simple_leader);
    my $leader_length_pipe = length($leader_string_pipe);
    my $simple_length_pipe = length($simple_leader_pipe);

    #Figure out the length of the first line of the error
    my $error_length        = length(($error_message[0] =~ /\S/ ?
                                      $leader_string : '') .
                                     $error_message[0]);
    my $simple_err_len      = length(($error_message[0] =~ /\S/ ?
                                      $simple_leader : '') .
                                     $error_message[0]);
    my $error_length_pipe   = length(($error_message[0] =~ /\S/ ?
                                      $leader_string_pipe : '') .
                                     $error_message[0]);
    my $simple_err_len_pipe = length(($error_message[0] =~ /\S/ ?
				      $simple_leader_pipe : '') .
				     $error_message[0]);

    #Clean up any previous verboseOverMe output that may be longer than the
    #first line of the error message, put leader string at the beginning of
    #each line of the message, and indent each subsequent line by the length
    #of the leader string
    my $tmp_msg_ln = shift(@error_message);
    my $error_string = $leader_string . $tmp_msg_ln .
      ($clear_vom && defined($last_verbose_state) && $last_verbose_state ?
       ' ' x ($last_verbose_size - $error_length) : '') . "\n";
    my $simple_string = $simple_leader . $tmp_msg_ln .
      ($clear_vom && defined($last_verbose_state) && $last_verbose_state ?
       ' ' x ($last_verbose_size - $simple_err_len) : '') . "\n";
    my $error_string_pipe = $leader_string_pipe . $tmp_msg_ln .
      ($clear_vom && defined($last_verbose_state) && $last_verbose_state ?
       ' ' x ($last_verbose_size - $error_length_pipe) : '') . "\n";
    my $simple_string_pipe = $simple_leader_pipe . $tmp_msg_ln .
      ($clear_vom && defined($last_verbose_state) && $last_verbose_state ?
       ' ' x ($last_verbose_size - $simple_err_len_pipe) : '') . "\n";
    foreach my $line (@error_message)
      {
	$error_string       .= (' ' x $leader_length) . $line . "\n";
	$simple_string      .= (' ' x $simple_length) . $line . "\n";
	$error_string_pipe  .= (' ' x $leader_length_pipe) . $line . "\n";
	$simple_string_pipe .= (' ' x $simple_length_pipe) . $line . "\n";
      }

    #If the global error hash does not yet exist, store the first example of
    #this error type
    if(!defined($error_hash) ||
       !exists($error_hash->{$caller_string}))
      {
	$error_hash->{$caller_string}->{EXAMPLE}    = $simple_string;
	$error_hash->{$caller_string}->{EXAMPLENUM} = $error_number;

	$error_hash->{$caller_string}->{EXAMPLE} =~ s/\n */ /g;
	$error_hash->{$caller_string}->{EXAMPLE} =~ s/ $//g;
	$error_hash->{$caller_string}->{EXAMPLE} =~ s/^(.{100}).+/$1.../;

	#If debug is not defined or is non-zero, the example will default to
	#debug-style leaders, otherwise.
	if($debug_ldr)
	  {
	    $error_hash->{$caller_string}->{EXAMPLEDEBUG} = $error_string;
	    $error_hash->{$caller_string}->{EXAMPLEDEBUG} =~ s/\n */ /g;
	    $error_hash->{$caller_string}->{EXAMPLEDEBUG} =~ s/ $//g;
	    $error_hash->{$caller_string}->{EXAMPLEDEBUG} =~
	      s/^(.{100}).+/$1.../;
	  }

	$error_hash->{$caller_string}->{EXAMPLEPIPE} = $simple_string_pipe;
	$error_hash->{$caller_string}->{EXAMPLEPIPE} =~ s/\n */ /g;
	$error_hash->{$caller_string}->{EXAMPLEPIPE} =~ s/ $//g;
	$error_hash->{$caller_string}->{EXAMPLEPIPE} =~ s/^(.{100}).+/$1.../;

	$error_hash->{$caller_string}->{EXAMPLEDEBUGPIPE} =
	  $error_string_pipe;
	$error_hash->{$caller_string}->{EXAMPLEDEBUGPIPE} =~
	  s/\n */ /g;
	$error_hash->{$caller_string}->{EXAMPLEDEBUGPIPE} =~
	  s/ $//g;
	$error_hash->{$caller_string}->{EXAMPLEDEBUGPIPE} =~
	  s/^(.{100}).+/$1.../;
      }

    #Increment the count for this error type
    $error_hash->{$caller_string}->{NUM}++;

    #Flush the buffer if there is something in it and there is enough info to
    #flush it (i.e. quiet is defined and true or both quiet and error_limit are
    #defined)
    if($command_line_stage >= DONE)
      {flushStderrBuffer() if(defined($quiet) &&
			      ($quiet || defined($error_limit)))}

    #Print the error unless it is over the limit for its type
    if(!defined($error_limit) || $error_limit == 0 ||
       $error_hash->{$caller_string}->{NUM} <= $error_limit)
      {
	#Let the user know if we're going to start suppressing errors of
	#this type
	if(defined($error_limit) && $error_limit &&
	   $error_hash->{$caller_string}->{NUM} == $error_limit)
	  {
            $error_limit_met = 1;

	    $error_string .=
	      join('',
		   ($leader_string,"NOTE: Further errors of this type will ",
		    "be suppressed.\n$leader_string",
		    "Set --error-limit to 0 to turn off error suppression\n"));
	    $simple_string .=
	      join('',
		   ($simple_leader,"NOTE: Further errors of this type will ",
		    "be suppressed.\n$simple_leader",
		    "Set --error-limit to 0 to turn off error suppression\n"));
	  }

	#If the command line has been sufficiently processed...  (Note, even if
	#verbose is defined, it could get changed by the user after the command
	#line is processed.  We check that command_line_stage is >= 6 because
	#it means that the verbose value has been validated.)
	if($command_line_stage >= DONE)
	  {
	    #If there's already been a fatal error, do not print warnings unless
	    #in debug mode.  This assumes a fatal error has already been printed
	    if($cleanup_mode == 2 && defined($DEBUG) && !$DEBUG)
	      {return(0)}

	    #The following assumes we'd not have gotten here if quiet was true
	    print STDERR ($error_string)
	      if(!$quiet && (!$logging || $log_mirror || !$log_errors));

	    logger($error_string) if($log_errors);
	  }
	else
	  {
	    #Store the message in the stderr buffer until $quiet has been
	    #defined by the command line options (using Getopts::Long)
	    push(@{$stderr_buffer},
		 ['error',
		  $error_hash->{$caller_string}->{NUM},
		  $error_string,
		  $leader_string,
		  $simple_string,
		  $simple_leader,
		  $detail,
		  $detail_alert,
                  $opts,
                  getTrace()]);
	  }
      }

    #Reset the verbose states
    if($clear_vom)
      {
	$last_verbose_size  = 0;
	$last_verbose_state = 0;
      }

    #Return success
    return(0);
  }

##
## Method that prints warnings with a leader string containing a warning
## number
##
sub warning
  {
    #Flush the stderr buffer if it's populated and basic options have been set
    flushStderrBuffer() if($command_line_stage >= DONE);

    #Determine behaviors from command line options, if CL has been processed
    my($quiet,$verbose,$DEBUG,$pipeline,$extended,$error_limit);
    my $clear_vom = 0;
    my $debug_ldr = 1;
    if($command_line_stage >= COMMITTED)
      {
	#Return if we know quiet mode is on
	$quiet = getVarref('quiet',1);
	return(0) if(defined($quiet) && $quiet);

	$verbose       = getVarref('verbose',  1);
	$DEBUG         = getVarref('debug',    1);
	$extended      = getVarref('extended', 1,1);
	$error_limit   = getVarref('error_lim',1,1);
	$pipeline      = getVarref('pipeline', 1,1);

	$clear_vom     = defined($verbose) && $verbose;
	$debug_ldr     = defined($DEBUG) && $DEBUG;

	if(!defined($pipeline))
	  {$pipeline = inPipeline()}
      }

    $warning_number++;

    #Extract any possible parameters
    my($opts,@params) = getStrSubParams([qw(DETAIL)],@_);
    my $detail        = $opts->{DETAIL};
    my $detail_alert  = "Supply --extended for additional details.";

    #Gather and concatenate the warning message and split on hard returns
    my @warning_message = split(/\n/,join('',grep {defined($_)} @params));
    push(@warning_message,'') unless(scalar(@warning_message));
    pop(@warning_message) if(scalar(@warning_message) > 1 &&
			     $warning_message[-1] !~ /\S/);

    #If DETAIL was supplied/defined and $quiet is defined (implying that the
    #command line has been processed), append a detailed message based on the
    #value of $extended
    if(defined($detail) && $command_line_stage >= DONE)
      {
	if($extended)
	  {push(@warning_message,split(/(?<=\n)/,$detail))}
	else
	  {push(@warning_message,$detail_alert)}
      }

    #If this is from our sig_warn handler, join the last 2 values of the array
    #(effectively chomping the warn message)
    if(defined($warning_message[0]) && scalar(@warning_message) > 1 &&
       $warning_message[0] =~ /^Runtime warning: \[/)
      {$warning_message[-2] .= pop(@warning_message)}

    my $leader_string      = "WARNING$warning_number:";
    my $simple_leader      = $leader_string;
    my $leader_string_pipe = $leader_string;
    my $simple_leader_pipe = $leader_string;

    my $caller_string      = getTrace();
    my $script             = getScriptName();

    #If the command line has been processed and we're in a pipeline,
    #prepend a call-trace
    if($command_line_stage >= ARGSREAD && defined($pipeline) && $pipeline)
      {
	$leader_string  .= "$script:";
	$simple_leader  .= "$script:";
      }
    $leader_string_pipe .= "$script:";
    $simple_leader_pipe .= "$script:";
    if($debug_ldr)
      {$leader_string   .= $caller_string}

    $leader_string      .= ' ';
    $simple_leader      .= ' ';
    $leader_string_pipe .= ' ';
    $simple_leader_pipe .= ' ';
    my $leader_length = length($leader_string);
    my $simple_length = length($simple_leader);
    my $leader_length_pipe = length($leader_string_pipe);
    my $simple_length_pipe = length($simple_leader_pipe);

    #Figure out the length of the first line of the error
    my $warning_length       = length(($warning_message[0] =~ /\S/ ?
				       $leader_string : '') .
				      $warning_message[0]);
    my $simple_warn_len      = length(($warning_message[0] =~ /\S/ ?
				       $simple_leader : '') .
				      $warning_message[0]);
    my $warning_length_pipe  = length(($warning_message[0] =~ /\S/ ?
				       $leader_string_pipe : '') .
				      $warning_message[0]);
    my $simple_warn_len_pipe = length(($warning_message[0] =~ /\S/ ?
				       $simple_leader_pipe : '') .
				      $warning_message[0]);

    #Clean up any previous verboseOverMe output that may be longer than the
    #first line of the warning message, put leader string at the beginning of
    #each line of the message and indent each subsequent line by the length
    #of the leader string
    my $tmp_msg_ln = shift(@warning_message);
    my $spacelen = (defined($last_verbose_size) ? $last_verbose_size : 0) -
      $warning_length;
    $spacelen = 0 if($spacelen < 0);
    my $warning_string = $leader_string . $tmp_msg_ln .
      ($clear_vom && defined($last_verbose_state) && $last_verbose_state ?
       ' ' x $spacelen : '') . "\n";
    $spacelen = (defined($last_verbose_size) ? $last_verbose_size : 0) -
      $simple_warn_len;
    $spacelen = 0 if($spacelen < 0);
    my $simple_string = $simple_leader . $tmp_msg_ln .
      ($clear_vom && defined($last_verbose_state) && $last_verbose_state ?
       ' ' x $spacelen : '') . "\n";
    $spacelen = (defined($last_verbose_size) ? $last_verbose_size : 0) -
      $warning_length_pipe;
    $spacelen = 0 if($spacelen < 0);
    my $warning_string_pipe = $leader_string_pipe . $tmp_msg_ln .
      ($clear_vom && defined($last_verbose_state) && $last_verbose_state ?
       ' ' x $spacelen : '') . "\n";
    $spacelen = (defined($last_verbose_size) ? $last_verbose_size : 0) -
      $simple_warn_len_pipe;
    $spacelen = 0 if($spacelen < 0);
    my $simple_string_pipe = $simple_leader_pipe . $tmp_msg_ln .
      ($clear_vom && defined($last_verbose_state) && $last_verbose_state ?
       ' ' x $spacelen : '') . "\n";
    foreach my $line (@warning_message)
      {
	$warning_string      .= (' ' x $leader_length) . $line . "\n";
	$simple_string       .= (' ' x $simple_length) . $line . "\n";
	$warning_string_pipe .= (' ' x $leader_length_pipe) . $line . "\n";
	$simple_string_pipe  .= (' ' x $simple_length_pipe) . $line . "\n";
      }

    #If the global warning hash does not yet exist, store the first example of
    #this warning type
    if(!defined($warning_hash) ||
       !exists($warning_hash->{$caller_string}))
      {
	$warning_hash->{$caller_string}->{EXAMPLE}    = $simple_string;
	$warning_hash->{$caller_string}->{EXAMPLENUM} = $warning_number;

	$warning_hash->{$caller_string}->{EXAMPLE} =~ s/\n */ /g;
	$warning_hash->{$caller_string}->{EXAMPLE} =~ s/ $//g;
	$warning_hash->{$caller_string}->{EXAMPLE} =~ s/^(.{100}).+/$1.../;

	#If debug is not defined or is non-zero, the example will default to
	#debug-style leaders, otherwise.
	if($debug_ldr)
	  {
	    $warning_hash->{$caller_string}->{EXAMPLEDEBUG} = $warning_string;
	    $warning_hash->{$caller_string}->{EXAMPLEDEBUG} =~ s/\n */ /g;
	    $warning_hash->{$caller_string}->{EXAMPLEDEBUG} =~ s/ $//g;
	    $warning_hash->{$caller_string}->{EXAMPLEDEBUG} =~
	      s/^(.{100}).+/$1.../;
	  }

	$warning_hash->{$caller_string}->{EXAMPLEPIPE} = $simple_string_pipe;
	$warning_hash->{$caller_string}->{EXAMPLEPIPE} =~ s/\n */ /g;
	$warning_hash->{$caller_string}->{EXAMPLEPIPE} =~ s/ $//g;
	$warning_hash->{$caller_string}->{EXAMPLEPIPE} =~ s/^(.{100}).+/$1.../;

	$warning_hash->{$caller_string}->{EXAMPLEDEBUGPIPE} =
	  $warning_string_pipe;
	$warning_hash->{$caller_string}->{EXAMPLEDEBUGPIPE} =~
	  s/\n */ /g;
	$warning_hash->{$caller_string}->{EXAMPLEDEBUGPIPE} =~
	  s/ $//g;
	$warning_hash->{$caller_string}->{EXAMPLEDEBUGPIPE} =~
	  s/^(.{100}).+/$1.../;
      }

    #Increment the count for this warning type
    $warning_hash->{$caller_string}->{NUM}++;

    #Flush the buffer if there is something in it and there is enough info to
    #flush it (i.e. quiet is defined and either quiet is true or error_limit is
    #also defined)
    flushStderrBuffer()
      if($command_line_stage >= DONE &&
	 (defined($quiet) && ($quiet || (defined($error_limit)))));

    #Print the warning unless it is over the limit for its type
    if(!defined($error_limit) || $error_limit == 0 ||
       $warning_hash->{$caller_string}->{NUM} <= $error_limit)
      {
	#Let the user know if we're going to start suppressing errors of
	#this type
	if(defined($error_limit) && $error_limit &&
	   $warning_hash->{$caller_string}->{NUM} == $error_limit)
	  {
            $error_limit_met = 1;

	    $warning_string .=
	      join('',
		   ((' ' x $leader_length),
                    "NOTE: Further warnings of this type will ",
		    "be suppressed.\n",(' ' x $leader_length),
		    "Set --error-limit to 0 to turn off error suppression\n"));
	    $simple_string .=
	      join('',
		   ((' ' x $simple_length),
                    "NOTE: Further warnings of this type will ",
		    "be suppressed.\n",(' ' x $simple_length),
		    "Set --error-limit to 0 to turn off error suppression\n"));
	  }

	#If the command line has been sufficiently processed...  (Note, even if
	#verbose is defined, it could get changed by the user after the command
	#line is processed.  We check that command_line_stage is >= 6 because
	#it means that the verbose value has been validated.)
	if($command_line_stage >= DONE)
	  {
	    #If there's already been a fatal error, do not print warnings unless
	    #in debug mode.  This assumes a fatal error has already been printed
	    if($cleanup_mode == 2 && defined($DEBUG) && !$DEBUG)
	      {return(0)}

	    #The following assumes we'd not have gotten here if quiet was true
	    print STDERR ($warning_string)
	      if(!$quiet && (!$logging || $log_mirror || !$log_warnings));

	    logger($warning_string) if($log_warnings);
	  }
	else
	  {
	    #Store the message in the stderr buffer until $quiet has been
	    #defined by the command line options (using Getopt::Long)
	    push(@{$stderr_buffer},
		 ['warning',
		  $warning_hash->{$caller_string}->{NUM},
		  $warning_string,
		  $leader_string,
		  $simple_string,
		  $simple_leader,
		  $detail,
		  $detail_alert,
                  $opts,
                  getTrace()]);
	  }
      }

    #Reset the verbose states
    if($clear_vom)
      {
	$last_verbose_size  = 0;
	$last_verbose_state = 0;
      }

    #Return success
    return(0);
  }

##
## Method that gets a line of input and accounts for carriage returns that
## many different platforms use instead of hard returns.  Note, it uses a
## global array reference variable ($infile_line_buffer) to keep track of
## buffered lines from multiple file handles.
##
sub getLine
  {
    my @in = getSubParams([qw(HANDLE VERBOSELEVEL VERBOSEFREQ)],
			  [qw(HANDLE)],
			  [@_]);
    my $file_handle   = $in[0];
    my $verbose_level = defined($in[1]) ? $in[1] : 2;
    my $verbose_freq  = defined($in[2]) ? $in[2] : 100;

    if(!defined($file_handle))
      {
	error("File handle sent in undefined.");
	return(undef);
      }

    #Set a global array variable if not already set
    $infile_line_buffer = {} if(!defined($infile_line_buffer));
    if(!exists($infile_line_buffer->{$file_handle}))
      {$infile_line_buffer->{$file_handle}->{FILE} = []}

    #If this sub was called in array context
    if(wantarray)
      {
	#Check to see if this file handle has anything remaining in its buffer
	#and if so return it with the rest
	if(scalar(@{$infile_line_buffer->{$file_handle}->{FILE}}) > 0)
	  {
	    return(@{$infile_line_buffer->{$file_handle}->{FILE}},
		   map
		   {
		     my $item = $_;

		     #If carriage returns were substituted and we haven't
		     #already issued a carriage return warning for this file
		     #handle
		     if(s/\r\n|\n\r|\r/\n/g &&
			!exists($infile_line_buffer->{$file_handle}->{WARNED}))
		       {
			 $infile_line_buffer->{$file_handle}->{WARNED}
			   = 1;
			 warning('Carriage returns were found in your file ',
				 'and replaced with hard returns.');
		       }

		     map {$infile_line_buffer->{$file_handle}->{COUNT}++;
			  verboseOverMe({LEVEL     => $verbose_level,
					 FREQUENCY => $verbose_freq},
					"Reading line ",$infile_line_buffer
					->{$file_handle}->{COUNT},".");
			  $_}
		     split(/(?<=\n)/,$item);
		   } <$file_handle>);
	  }

	#Otherwise return everything else
	return(map
	       {
		 my $item = $_;

		 #If carriage returns were substituted and we haven't already
		 #issued a carriage return warning for this file handle
		 if(s/\r\n|\n\r|\r/\n/g &&
		    !exists($infile_line_buffer->{$file_handle}->{WARNED}))
		   {
		     $infile_line_buffer->{$file_handle}->{WARNED}
		       = 1;
		     warning('Carriage returns were found in your file ',
			     'and replaced with hard returns.');
		   }

		 map {$infile_line_buffer->{$file_handle}->{COUNT}++;
		      verboseOverMe({LEVEL     => $verbose_level,
				     FREQUENCY => $verbose_freq},
				    "Reading line ",$infile_line_buffer
				    ->{$file_handle}->{COUNT},".");
		      $_}
		 split(/(?<=\n)/,$item);
	       } <$file_handle>);
      }

    #If the file handle's buffer is empty, put more on
    if(scalar(@{$infile_line_buffer->{$file_handle}->{FILE}}) == 0)
      {
	my $line = <$file_handle>;
	#The following is to deal with files that have the eof character at the
	#end of the last line.  I may not have it completely right yet.
	if(defined($line))
	  {
	    if($line =~ s/\r\n|\n\r|\r/\n/g &&
	       !exists($infile_line_buffer->{$file_handle}->{WARNED}))
	      {
		$infile_line_buffer->{$file_handle}->{WARNED} = 1;
		warning('Carriage returns were found in your file and ',
			'replaced with hard returns.');
	      }

	    @{$infile_line_buffer->{$file_handle}->{FILE}} =
	      map {$infile_line_buffer->{$file_handle}->{COUNT}++;
		   verboseOverMe({LEVEL     => $verbose_level,
				  FREQUENCY => $verbose_freq},"Reading line ",
				 $infile_line_buffer->{$file_handle}->{COUNT},
				 ".");
		   $_}
		split(/(?<=\n)/,$line);
	  }
	else
	  {@{$infile_line_buffer->{$file_handle}->{FILE}} = ($line)}
      }

    #Shift off and return the first thing in the buffer for this file handle
    return($_ = shift(@{$infile_line_buffer->{$file_handle}->{FILE}}));
  }

##
## This method allows the user to print debug messages containing the line
## of code where the debug print came from and a debug number.  Debug prints
## will only be printed (to STDERR) if the debug option is supplied on the
## command line.
##
sub debug
  {
    #Flush the stderr buffer if it's populated and basic options have been set
    flushStderrBuffer() if($command_line_stage >= DONE);
    #Return if we know debug mode is off
    my($DEBUG,$verbose);
    if($command_line_stage >= LOGGING)
      {
	$DEBUG   = getVarref('debug',1);
	$verbose = getVarref('verbose',1);
	return(0) if(defined($DEBUG) && !$DEBUG);
      }

    #Grab the options from the parameter array
    my($opts,@params)  = getStrSubParams([qw(LEVEL DETAIL)],@_);
    my $message_level  = (exists($opts->{LEVEL}) && defined($opts->{LEVEL}) ?
			  $opts->{LEVEL} : 1);
    my $detail         = $opts->{DETAIL};
    my $detail_alert   = "Supply --extended for additional details.";

    #Return if $DEBUG level is greater than a negative message level at which
    #this message is printed or if $DEBUG level is less than a positive message
    #level at which this message is printed.  Negative levels are for template
    #diagnostics.
    return(0) if($command_line_stage >= DONE && defined($DEBUG) &&
		 (($message_level < 0 && $DEBUG > $message_level) ||
		  ($message_level > 0 && $DEBUG < $message_level)));

    my($extended,$pipeline);
    if($command_line_stage >= ARGSREAD)
      {
	$extended = getVarref('extended',1,1);
	$pipeline = getVarref('pipeline',1,1);
      }

    $debug_number++;

    #Gather and concatenate the error message and split on hard returns
    my @debug_message =
      split(/\n/,join('',map {defined($_) ? $_ : 'undef'} @params));
    push(@debug_message,'') unless(scalar(@debug_message));
    pop(@debug_message) if(scalar(@debug_message) > 1 &&
			   $debug_message[-1] !~ /\S/);

    #If DETAIL was supplied/defined and $quiet is defined (implying that the
    #command line has been processed), append a detailed message based on the
    #value of $extended
    if(defined($detail) && $command_line_stage >= DONE)
      {
	if($extended)
	  {push(@debug_message,split(/(?<=\n)/,$detail))}
	else
	  {push(@debug_message,$detail_alert)}
      }

    my $leader_string = "DEBUG$debug_number:";
    my $simple_leader = $leader_string;

    my $caller_string = getTrace();
    my $script        = getScriptName();

    ##TODO: Add pipeline mode string later in flushStderrBuffer if true.  See
    ##      requirement 184
    if($command_line_stage >= ARGSREAD &&
       defined($pipeline) && $pipeline)
      {
	$leader_string .= "$script:";
	$simple_leader .= "$script:";
      }

    my $full_trace = $caller_string;
    my $short_trace = $caller_string;
    $short_trace =~ s/:.*/:/;
    $leader_string .= (defined($DEBUG) && abs($DEBUG) == 1 ?
		       $short_trace : $full_trace);
    $simple_leader .= $short_trace;

    #Figure out the length of the first line of the error
    my $debug_length = length(($debug_message[0] =~ /\S/ ?
			       $leader_string : '') .
			      $debug_message[0]);
    my $simple_dbg_length = length(($debug_message[0] =~ /\S/ ?
				    $simple_leader : '') .
				   $debug_message[0]);

    #Contstruct the debug message string
    #The first line should contain a trace and clean up verbose-over-me stuff
    my $tmp_msg_ln = shift(@debug_message);
    my $debug_str =
      join('',($leader_string,
	       $tmp_msg_ln,
	       (defined($verbose) && $verbose &&
		defined($last_verbose_state) &&
		$last_verbose_state ?
		' ' x ($last_verbose_size - $debug_length) : ''),
	       "\n"));
    my $simple_string =
      join('',($simple_leader,
	       $tmp_msg_ln,
	       (defined($verbose) && $verbose &&
		defined($last_verbose_state) &&
		$last_verbose_state ?
		' ' x ($last_verbose_size - $simple_dbg_length) : ''),
	       "\n"));
    #Subsequent lines will be indented by the length of the leader string
    my $leader_length = length($leader_string);
    my $simple_length = length($simple_leader);
    foreach my $line (@debug_message)
      {
	$debug_str      .= (' ' x $leader_length) . $line . "\n";
	$simple_string  .= (' ' x $simple_length) . $line . "\n";
      }

    #If the command line has been sufficiently processed...  (Note, even if
    #DEBUG is defined, it could get changed by the user after the command line
    #is processed.  We check that command_line_stage is >= 6 because it means
    #that the DEBUG value has been validated.)
    if($command_line_stage >= DONE)
      {
	flushStderrBuffer();

	#Print to stderr only when we are in debug mode... and the debug level
	#is satisfied
	if($DEBUG && (($message_level < 0 && $DEBUG <= $message_level) ||
		      ($message_level > 0 && $DEBUG >= $message_level)))
	  {
	    print STDERR ($debug_str)
	      if(!$logging || $log_mirror || !$log_debug);

	    #Log the debug messages if debug is on
	    logger($debug_str) if($log_debug);
	  }
      }
    else
      {
	#Store the message in the stderr buffer until $quiet has been
	#defined by the command line options (using Getopts::Long)
	push(@{$stderr_buffer},
	     ['debug',
	      $message_level,
	      $debug_str,
	      $leader_string,
	      $simple_string,
	      $simple_leader,
	      $detail,
	      $detail_alert,
              $opts,
              getTrace()]);
      }

    #Reset the verbose states if verbose is true
    if(defined($verbose) && $verbose)
      {
	$last_verbose_size  = 0;
	$last_verbose_state = 0;
      }

    #Return success
    return(0);
  }

##
## This sub marks the time (which it pushes onto an array) and in scalar
## context returns the time since the last mark by default or supplied mark
## (optional).
## A mark is not made if a mark index is supplied
## Uses a global time_marks array reference
##
sub markTime
  {
    my @in = getSubParams([qw(MARKINDEX)],[],[@_]);

    #Record the time
    my $time = time();

    #Set a global array variable if not already set to contain (as the first
    #element) the time the program started (NOTE: "$^T" is a perl variable that
    #contains the start time of the script)
    $time_marks = [$^T] if(!defined($time_marks));

    #Read in the time mark index or set the default value
    my $mark_index = (defined($in[0]) ? $in[0] : -1);  #Optional Default: -1

    #Error check the time mark index sent in
    if($mark_index > (scalar(@$time_marks) - 1))
      {
	error('Supplied time mark index is larger than the size of the ',
	      "time_marks array.\nThe last mark will be set.");
	$mark_index = -1;
      }

    #Calculate the time since the time recorded at the time mark index
    my $time_since_mark = $time - $time_marks->[$mark_index];

    #Add the current time to the time marks array
    push(@$time_marks,$time)
      if(!defined($in[0]) || scalar(@$time_marks) == 0);

    #Return the time since the time recorded at the supplied time mark index
    return($time_since_mark);
  }

##
## This method reconstructs the command entered on the command line
## (excluding standard input and output redirects).  The intended use for this
## method is for when a user wants the output to contain the input command
## parameters in order to keep track of what parameters go with which output
## files.
##
#Globals used: $preserve_args
sub getCommand
  {
    my @in = getSubParams([qw(INCLUDE_PERL_PATH NO_DEFAULTS
			      INC_DEFMODE)],[],[@_]);
    my $perl_path_flag        = $in[0];
    my $no_defaults           = $in[1];
    my $include_default_modes = $in[2];
    my($command);
    my @return_args = ();

    #Determine the script name
    my $script = getScriptName();

    #Put quotes around any parameters containing un-escaped spaces, asterisks,
    #or quotes
    my $arguments = quoteArgs([@$preserve_args]);

    #Determine the perl path used (dependent on the `which` unix built-in)
    if($perl_path_flag)
      {
	$command = `which $^X`;
	push(@return_args,$command);
	chomp($command);
	$command .= ' ';
      }

    #Build the original command
    $command .= join(' ',($0,@$arguments));
    push(@return_args,($0,@$arguments));

    #Add any default flags that were previously saved
    my @default_options = getUserDefaults();
    if(!$no_defaults && scalar(@default_options))
      {
	my(@tmp_default_options,@defrunmodes);
	if(!defined($include_default_modes) || !$include_default_modes)
	  {
	    @tmp_default_options =
	      grep {$_ ne '--usage' && $_ ne '--help' && $_ ne '--run' &&
		      $_ ne '--dry-run'} @default_options;
	  }
	else
	  {@tmp_default_options = @default_options}

	@defrunmodes =
	  grep {$_ eq '--usage' || $_ eq '--help' || $_ eq '--run' ||
		  $_ eq '--dry-run'} @default_options;

	$command .= ' -- [USER DEFAULTS ADDED: ';
	$command .= join(' ',@tmp_default_options);
	$command .= ']';

	if(scalar(@defrunmodes))
	  {
	    $command .= ' [USER DEFAULT RUN MODE: ';
	    $command .= join(' ',@defrunmodes);
	    $command .= ']';
	  }

	push(@return_args,@tmp_default_options);
      }

    return(wantarray ? @return_args : $command);
  }

##
## This method performs a more reliable glob than perl's built-in, which
## fails for files with spaces in the name, even if they are escaped.  The
## purpose is to allow the user to enter input files using double quotes and
## un-escaped spaces as is expected to work with many programs which accept
## individual files as opposed to sets of files.  If the user wants to enter
## multiple files, it is assumed that space delimiting will prompt the user to
## realize they need to escape the spaces in the file names.  This version
## works with a mix of unescaped and escaped spaces, as well as glob
## characters.  It will also split non-files on unescaped spaces and uses a
## helper sub (globCurlyBraces) to mitigate truncations from long strings.
##
sub sglob
  {
    #Convert possible 'Getopt::Long::CallBack' to SCALAR by wrapping in quotes:
    my $command_line_string = "$_[0]";
    my $notfromshell        = defined($_[1]) ? $_[1] : 0; #Internal-for handling
                                                          #  displayed quotes
    if(!defined($command_line_string))
      {
	warning("Undefined command line string encountered.");
	return($command_line_string);
      }
    #The command_line_string is 1 existing file (possibly w/ unescaped spaces)
    elsif(-e $command_line_string)
      {
	debug({LEVEL => -3},
	      "Returning argument string: [($command_line_string)].");
	return($command_line_string);
      }
    #Else if the string contains unescaped spaces, does not contain escaped
    #spaces, and does not contain quotes, see if it's a single file (possibly
    #with glob characters)
    elsif($command_line_string =~ /(?<!\\) / &&
	  $command_line_string !~ /\\ / && $command_line_string !~ /["']/)
      {
	my $x = [bsd_glob($command_line_string,GLOB_CSH)];

	#If glob didn't truncate a pattern, there were multiple things returned
	#or there was 1 thing returned that exists
	if(notAGlobTruncation($command_line_string,$x) &&
	   scalar(@$x) > 1 || ((scalar(@$x) == 1 && -e $x->[0])))
	  {
	    debug({LEVEL => -2},
		  "Returning files with spaces: [(@$x)].");
	    return(@$x);
	  }
      }

    my(@partials);

    #Sometimes, the glob string is larger than GLOB_LIMIT (even though
    #the shell sent in the long string to begin with).  When that
    #happens, bsd_glob just silently chops off everything except the
    #directory, so we will split the strings up here in perl (to expand
    #any '{X,Y,...}' patterns) before passing them to bsd_glob.  This
    #will hopefully shorten each individual file string for bsd_glob to
    #be able to handle.  Since doing this will break filenames/paths that have
    #spaces in them, we'll only do it if there are more than 1024 non-white-
    #space characters in a row.  It would be nice to handle escaped spaces too,
    #but se la vie.

    #If the command line string is short or doesn't contain curly braces
    if($command_line_string !~ /\S{1025}/ || $command_line_string !~ /\{.*\}/)
      {
        #Split on spaces

        #If this is not from a shell, it may have (or have had) quotes
        #containing unescaped spaces - because defaults are saved that way, so
        #remove the quotes and escape unescaped spaces
        #This assumes the presence of quotes means its a single argument string
        #from the user defaults
        if($notfromshell)
          {
            my $argwquotes = $command_line_string;
            #arg is quoted, remove the quotes and escape the spaces
            $argwquotes =~ s/(?<!\\)(\s)/\\$1/g;
            $argwquotes =~ s/^['"]//;
            $argwquotes =~ s/["']$//;
            @partials = $argwquotes;
          }
        else
          {@partials = split(/(?<!\\)\s+/,$command_line_string)}
      }
    #Else if there are curly braces anywhere, do the trick to expand them in
    #perl to avoid the glob limit issue
    else
      {@partials = map {sort {$a cmp $b} globCurlyBraces($_)}
	 split(/(?<!\\)\s+/,$command_line_string)}

    debug({LEVEL => -5},"Partials being sent to bsd_glob: [",
	  join(',',@partials),"] - ",
          ($notfromshell ? 'not from the shell' : 'as from the shell'),
          ": $command_line_string.");

    #Note, when bsd_glob gets a string with a glob character it can't expand,
    #it drops the string entirely.  Those strings are returned with the glob
    #characters so the surrounding script can report an error.  The GLOB_ERR
    #posix flag is not used because of the way the patterns are manipulated
    #before getting to bsd_glob - which could cause a valid expansion to
    #nothing that bsd_glob would complain about.
    my @arguments =
      map
	{
	  #Expand the string from the command line using a glob
	  my $v = $_;
	  my $x = [bsd_glob($v,GLOB_CSH)];
	  #If the expansion didn't truncate a file glob pattern to a directory
	  if(notAGlobTruncation($v,$x))
	    {
	      debug({LEVEL => -5},"Not a glob truncation: [$v] -> [@$x].");
	      @$x;
	    }
	  else
	    {
	      debug({LEVEL => -5},"Is a glob truncation: [$v] -> [@$x].");
	      $v;
	    }
	} @partials;

    #If the value was something like a perl regular expression (including curly
    #braces), then the above code would have expanded that to a number of non-
    #existing "files" with the curly braces removed.  This is to prevent that.
    #Test case: -s '(AUAU|UAUA).{25,50}GGG|GGG.{25,50}(AUAU|UAUA)'
    if($command_line_string =~ /\{.*\}/ &&
       scalar(grep {-e $_} @arguments) == 0)
      {
	#If the command line string had unescaped spaces (and the curlies
	#required above), then either the curlies were perl-expanded or glab-
	#expanded, but none of the resulting strings were existing files, so
	#let's just split on the unescaped spaces
	if($command_line_string =~ /(?<!\\)\s/)
	  {
	    debug({LEVEL => -2},"Returning original command line string ",
		  "split on unescaped spaces since it didn't expand to ",
		  "existing files: [$command_line_string].");
	    return(split(/(?<!\\)\s+/,$command_line_string));
	  }

	debug({LEVEL => -2},"Returning original command line string since it ",
	      "didn't expand to existing files and had no unescaped spaces: ",
	      "[$command_line_string].");
	return($command_line_string);
      }

    debug({LEVEL => -2},
	  "Returning split args: [(",join('),(',@arguments),
	  ")] parsed from string: [$command_line_string].");

    #Return the split arguments.  We're assuming that if the command line
    #string was a real file, it would not get here.
    return(@arguments);
  }

#This method takes a string and the result of calling bsd_glob on it and
#determines whether the expansion was successful or whether glob truncated the
#file name leaving just the directory.
sub notAGlobTruncation
  {
    my $preproc_str    = $_[0];
    my $expanded_array = $_[1];

    return(scalar(@$expanded_array) > 1 ||

	   (#There's only 1 expanded result and neither exists
	    scalar(@$expanded_array) == 1 && !-e $expanded_array->[0] &&
	    !-e $preproc_str) ||

	   (#There's only 1 expanded and existing result AND
	    scalar(@$expanded_array) == 1 && -e $expanded_array->[0] &&

	    #If the glob string was too long, everything after the last
	    #directory can be truncated, so we want to avoid returning
	    #that truncated value, thus...

	    (#The expanded value is not a directory OR
	     !-d $expanded_array->[0] ||

	     #Assumed: it is a directory and...

	     (#The pre-expanded value was a valid directory string already
	      #or ended with a slash (implying the dir had glob characters
	      #in its name/path) or the last expanded string's character
	      #is not a slash (implying the end of a pattern wasn't
	      #chopped off by bsd_glob, which would leave a slash).
	      -d $preproc_str || $preproc_str =~ m%/$% ||
	      $expanded_array->[0] !~ m%/$%))));
  }

sub globCurlyBraces
  {
    my $nospace_string = $_[0];

    if($nospace_string =~ /(?<!\\)\s+/)
      {
	error("Unescaped spaces found in input string: [$nospace_string].");
	return($nospace_string);
      }
    elsif(scalar(@_) > 1)
      {
	error("Too many [",scalar(@_),"] parameters sent in.  Expected 1.");
	return(@_);
      }

    #Keep updating an array to be the expansion of a file pattern to
    #separate files
    my @expanded = ($nospace_string);

    #If there exists a '{X,Y,...}' pattern in the string
    if($nospace_string =~ /\{[^\{\}]+\}/)
      {
	#While the first element still has a '{X,Y,...}' pattern
	#(assuming everything else has the same pattern structure)
	while($expanded[0] =~ /\{[^\{\}]+\}/)
	  {
	    #Accumulate replaced file patterns in @g
	    my @buffer = ();
	    foreach my $str (@expanded)
	      {
		#If there's a '{X,Y,...}' pattern, split on ','
		if($str =~ /\{([^\{\}]+)\}/)
		  {
		    my $substr     = $1;
		    my $before     = $`;
		    my $after      = $';
		    my @expansions = split(/,/,$substr);
		    push(@buffer,map {$before . $_ . $after} @expansions);
		  }
		#Otherwise, push on the whole string
		else
		  {push(@buffer,$str)}
	      }

	    #Reset @f with the newly expanded file strings so that we
	    #can handle additional '{X,Y,...}' patterns
	    @expanded = @buffer;
	  }
      }

    #Pass the newly expanded file strings through
    return(wantarray ? @expanded : [@expanded]);
  }

#Globals used: $script_version_number, $created_on_date
sub getVersion
  {
    my @in             = getSubParams([qw(COMMENT EXTENDED)],[],[@_]);
    my $comment        = defined($in[0]) ? $in[0] : 0;
    my $extended       = getVarref('extended',1,1);
    my $local_extended = defined($_[1]) ? $_[1] : $extended;

    my $version_message = '';
    my $script          = getScriptName();
    my $lmd             = (-e $script ?
			   localtime((stat($script))[9]) :
			   localtime(time()));

    if(!defined($script_version_number) || $script_version_number !~ /\S/)
      {
	warning("Script version number not supplied.");
	$script_version_number = 'unknown';
      }

    if((!defined($created_on_date) || $created_on_date eq 'DATE HERE') &&
       $0 !~ /perl_script_template$/)
      {
        #TODO: Change to use a DEBUG parameter
	warning('This script\'s $created_on_date variable unset/missing.  ',
		'Please edit the script to add a script creation date.')
	  if(isDebug());
	$created_on_date = 'unknown';
      }

    if(!defined($script_author))
      {$script_author = 'UNKNOWN'}
    if(!defined($script_contact))
      {$script_contact = 'UNKNOWN'}
    if(!defined($script_company))
      {$script_company = 'UNKNOWN'}
    if(!defined($script_license))
      {$script_license = 'UNKNOWN'}

    #If extended has any non-zero value, include the script name
    if($local_extended > 0)
      {$version_message = ($comment ? '#' : '') . "$script Version "}
    else
      {$version_message = ($comment ? '#' : '')}

    #Always include the version number
    $version_message .= $script_version_number;

    #If extended is 2 or larger, include more info about the script
    if($local_extended > 1)
      {
	$version_message .= "\n" . ($comment ? '#' : '') .
	  join("\n" . ($comment ? '#' : ''),
	       (" Created: $created_on_date",
		" Last modified: $lmd",
		" Author: $script_author",
		" Contact: $script_contact",
		" Company: $script_company",
		" License: $script_license"));
      }

    #If version is 3 or larger, include module info
    if($local_extended > 2)
      {
	#Add template version
	$version_message .= "\n" . ($comment ? '#' : '') .
	  "Generated using CommandLineInterface.pm Version $VERSION";

	$version_message .= "\n" . ($comment ? '#' : '') .
	  join("\n" . ($comment ? '#' : ''),
	       (' Created: 5/8/2006',
		' Author:  Robert W. Leach',
		' Contact: rleach@princeton.edu',
		' Company: Princeton University',
		' Copyright: 2018'));
      }

    return($version_message);
  }

#This method is a check to see if input is user-entered via a TTY (result
#is non-zero)
sub isStandardInputFromTerminal
  {return(-t STDIN)}

#This is not fool-proof.  If called in a script, it might pick up an STDIN
#handle on which no one is sending input.
sub isThereInputOnSTDIN
  {
    my $forced = defined($_[0]) ? $_[0] : 0;
    my $fn = fileno(STDIN);
    return(defined($fn) && $fn =~ /\d/ && $fn > -1 &&
	   !-t STDIN && (amIPipedTo($forced) || amIRedirectedTo($forced)));
  }

#This method is a check to see if prints are going to a TTY.  Note,
#explicit prints to STDOUT when another output handle is selected are not
#considered and may defeat this method.
sub isStandardOutputToTerminal
  {return(-t STDOUT && select() eq 'main::STDOUT')}

#This method exits the current process.  Note, you must clean up after
#yourself before calling this.  Does not exit if $force is true.  Takes the
#error number to supply to exit().
sub quit
  {
    my @in              = getSubParams([qw(ERRNO REPORT)],[],[@_]);
    my $errno           = $in[0];
    my $explicit_report = $in[1];
    my $report = (defined($explicit_report) ? $explicit_report : $runreport);

    my $forced_past = 0;

    #Only flush up to the errors/warnings that happened before a fatal quit (not
    #during cleanup)
    if(!defined($last_flush_error) && defined($errno) && $errno &&
       (!defined($command_line_stage) || $command_line_stage <= ARGSREAD))
      {
	$last_flush_error   = defined($error_number)   ? $error_number   : 0;
	$last_flush_warning = defined($warning_number) ? $warning_number : 0;
      }

    #If not in cleanup mode, explicit_quit is true, and force is not defined or
    #not true, it means quit has already been called and that subsequent calls
    #to quit are coming from printRunReport, flushStderrBuffer, or some deep
    #sub that they called, so just return so that the first call to quit can
    #finish.
    my $force = getVarref('force',1,1,1);
    if(!$cleanup_mode && $explicit_quit && (!defined($force) || !$force))
      {return($forced_past)}

    #If no exit code was provided, quit even if force is indicated.  We're over-
    #riding '-1' here, which is a special case for not quitting in an overwrite
    #situation
    if(!defined($errno))
      {$errno = -1}
    elsif($errno !~ /^[+\-]?\d+$/)
      {
	error("Invalid argument: [$errno].  Only integers are accepted.  Use ",
	      "error() or warning() to supply a message, then call quit() ",
	      "with an error number.");
	$errno = -1;
      }

    #We will not allow fatal quits to be forced
    if($errno && $cleanup_mode && defined($force) && $force)
      {error("Unable to force past a fatal error during command line cleanup/",
	     "exit.",
	     {DETAIL => join('',('To (possibly) force past this error, you ',
				 'must be sure to call processCommandLine ',
				 'explicitly in your code before quit is ',
				 'first called (which may be in the END ',
				 'block if you do not call it ',
				 'explicitly).'))})}

    my $fatal_error_during_pcl = $command_line_stage < ARGSREAD && $errno;

    #If there were no errors, we are not in force mode, (we are in force
    #mode and the error is -1 (meaning an overwrite situation)), or we're in
    #cleanup mode (i.e. we've been here before), allow quit to happen
    if($errno == 0 || !defined($force) || !$force ||
       (defined($force) && $force && $errno == -1) ||
       (defined($cleanup_mode) && $cleanup_mode))
      {
	#If quit is called and gets here, setting this value prevents END from
	#calling quit (creating a potential loop)
	$explicit_quit = 1;

	#Record whether or not we were in cleanup mode when we got here
	my $prior_cleanup_mode = $cleanup_mode;

	#The ultimate goal here is: don't print a run report if the programmer's
	#code has not executed.  It may have executed if we were called via the
	#END block, but we will assume at first that it did not and later see if
	#usage, help, or version was printed
	if($command_line_stage < ARGSREAD)
	  {$report = 0}

	#During quitting upon successful completion of the script, we need to
	#know whether to flush the buffer, print the run report, etc, so if the
	#command line options have not been processed (possibly because the
	#programmer didn't write any code to process files), and there was no
	#error, fully process the command line and allow the report to be
	#generated (if deemed necessary later)
	if(!$cleanup_mode && $errno == 0 && !$command_line_stage)
	  {
	    debug({LEVEL => -1},
		  "Calling processCommandLine during successful quit.");

	    #Set cleanup mode so that if a fatal error happens from here, it
	    #will cause an exit even if in force mode
	    $cleanup_mode = 1;

	    #Set the error code to whatever processCommandLine returns, in case
	    #a fatal error occurs
	    $errno = processCommandLine();

	    debug({LEVEL => -1},
		  "quit: processCommandLine returned [$errno].");
	  }
	#Fail-safe to determine whether to flush the buffer - It is inferred
	#that something went wrong in processing the default options or before
	#all the options were setup if we've gotten here and processCommandLine
	#was called, yet the command line wasn't processed.
	elsif(!$cleanup_mode && $command_line_stage < ARGSREAD)
	  {
	    #Set cleanup mode so that if a fatal error happens from here, it
	    #will cause an exit even if in force mode
	    $cleanup_mode = ($errno ? 2 : 1);

	    if(!$command_line_stage)
	      {
		if(!$errno)
		  {
		    debug({LEVEL => -1},
			  "Calling processCommandLine during quit($errno) and ",
			  "keeping track of possible fatal errors.");
		    $errno = processCommandLine();
		  }
		else
		  {
		    debug({LEVEL => -1},
			  "Calling processCommandLine during quit($errno) and ",
			  "keeping the current fatal error.");
		    processCommandLine();
		  }
	      }
	  }

	#Process the basic options unless we've already done that
	if($command_line_stage < ARGSREAD)
	  {
            if($command_line_stage < DEFAULTED)
              {
                #We need to set command_line_stage to DEFAULTED so it
                #doesn't just fill the defaults
                #$command_line_stage = DEFAULTED;
              }

            getOptions(0);
            processDefaultOptions(1) if(!$errno);
	  }

	my $use_as_default = getVarref('save_args',1,1,1);
	my $version        = getVarref('version',  1,1,1);
	my $help           = getVarref('help',     1,1,1);
	#If the user's code did execute (i.e. we weren't running in usage, help,
	#save-args, etc modes and there wasn't a fatal error during command line
	#processing), revert to the initial default behavior
	if(!$help && !$usage && !$version && !$use_as_default &&
	   !$fatal_error_during_pcl)
	  {$report = defined($explicit_report) ? $explicit_report : $runreport}

	#If there was no error, files were supplied by the user, but the file
	#sets were not all iterated over, issue a warning
	if($errno == 0 && scalar(@$input_file_sets) && $unproc_file_warn &&
	   ((!defined($max_set_num) &&
	     scalar(grep {my $s=$_;scalar(grep {defined($_)} @$s)}
		    @$input_file_sets)) ||
	    (defined($max_set_num) && $max_set_num < $#{$input_file_sets})))
	  {warning((scalar(@$input_file_sets) && defined($max_set_num) ?
		    $#{$input_file_sets} - $max_set_num :
		    scalar(@$input_file_sets))," of ",
		   scalar(@$input_file_sets)," file sets were not processed.",
		   {DETAIL =>
		    join('',('Unprocessed sets: [',
			     join(';',
				  map {my $s=$_;join(',',map {defined($_) ?
								$_ : 'undef'}
						     @$s)} @$input_file_sets),
			     '].  This can happen when input and/or output ',
			     'files supplied on the command line are not all ',
			     'retrieved for processing upon the successful ',
			     'end of the script.  If there was an error, ',
			     'quit(ERRNO => #) should be used to avoid this ',
			     'warning.  If there were no errors, and not ',
			     'processing all files is a valid outcome, use ',
			     'setDefaults(UNPROCFILEWARN => 0).'))})}

	#Re-check the same exit conditions as were checked to get in here, just
	#in case an error occurred during command line processing in the first
	#case above (in which case, prior_cleanup_mode will be true - instead
	#of cleanup_mode).
	if($errno == 0 || !defined($force) || !$force ||
	   (defined($force) && $force && $errno == -1) ||
	   (defined($prior_cleanup_mode) && $prior_cleanup_mode))
	  {
	    debug({LEVEL => -1},"Exit status: [$errno].  Report: [",
		  (defined($report) ? $report : 'undef'),"].");

	    #Force-flush the buffers before quitting
	    flushStderrBuffer(1);

            if(defined($compile_err) && scalar(@$compile_err))
              {
                print STDERR (join("\n",
                                   map {my $ce = $compile_err->[$_];
                                        my $cen = $_ + 1;
                                        my $jn =
                                          ##TODO: change this to set & check
                                          ##      $pipeline
                                          (!defined($DEBUG) || $DEBUG ?
                                           $ce->[0] : '') .

                                          (!defined($DEBUG)    || $DEBUG    ?
                                           $ce->[1] : '') .

                                          ' ';
                                        my $pfx = "INTERNAL ERROR[$cen]:";
                                        my $js = ' ' x length("$pfx$jn");

                                        "$pfx$jn" .
                                        join("\n$js",(split("\n",$ce->[2])))}

                                        (0..$#{$compile_err})),"\n",

                              "ERROR0: CommandLineInterface: Unable to ",
                              "complete set up.\n");
              }

	    printRunReport($errno) if((!defined($report) || $report) &&
				      ((!$usage && !$help && !$version) ||
                                       $error_limit_met) &&
                                      (!$num_setup_errors || $force) &&
                                      $command_line_stage == DONE);

	    #Doesn't hurt to be called in any case
	    stopLogging();

	    #Exit if there were no errors or we are not in force mode or (we
	    #are in force mode and the error is -1 (meaning an overwrite
	    #situation))
	    exit($errno);
	  }
	else
	  {$explicit_quit = 0}
      }

    $forced_past = 1;

    debug({LEVEL => -1},"quit returning.");

    return(1);
  }

#Generates/prints a report only if we're not in quiet mode and either we're in
#verbose mode, we're in debug mode, there was an error, or there was a warning.
#If $verbose is not defined and (local_quiet wasn't supplied as a parameter,
#we're not in debug mode, there were no errors, and there were no warnings), no
#report will be generated, nor is the report buffered (since this message can
#be considered a part of the warning/error output or verbose output).  If
#$quiet is not defined in main, it will be assumed to be false.
#Globals used: $log_report, $runreport
sub printRunReport
  {
    my @in             = getSubParams([qw(ERRNO)],[],[@_]);
    my $errno          = $in[0];
    my $verbose        = getVarref('verbose',1,0,1);
    my $global_verbose = defined($verbose) ? $verbose : 0;
    my $quiet          = getVarref('quiet',1,0,1);
    my $global_quiet   = defined($quiet)   ? $quiet   : 0;
    my $DEBUG          = getVarref('debug',1,0,1);
    my $global_debug   = defined($DEBUG)   ? $DEBUG   : 0;

    my $run = getVarref('run',1,0,1);

    #Return if quiet or there's nothing to report (or there's something to
    #report, but the programmer's code never ran, so all the user sees is the
    #error (i.e. $command_line_stage < 6))
    my $print_report = !($global_quiet || (!$global_verbose &&
					   !$global_debug &&
					   $runreport != 2 &&
					   (!defined($error_number) ||
					    $command_line_stage < DONE) &&
					   !defined($warning_number) &&
					   #We are exiting with success status
					   (!defined($errno) || $errno == 0 ||
					    $command_line_stage < DONE)));

    my $local_log_report = (defined($log_report) && defined($logging) &&
			    $log_report && $logging &&
			    #Log report if setup failed or run mode was true
			    (!defined($run) || $run));

    return(0) if(!$print_report && !$local_log_report);

    #Before printing a message saying to scroll up for error details, force-
    #flush the stderr buffer
    flushStderrBuffer(1) if($print_report);

    #If pipeline mode is not defined here, we can now define it without
    #potentially changing its default shown in the usage
    my $pipeline = getVarref('pipeline',1,1);
    if(!defined($pipeline))
      {$pipeline = inPipeline()}

    #Report the number of errors, warnings, and debugs on STDERR
    my $rpt     = join('',("\n",'Done.  STATUS: [',
                           (defined($errno) ? "EXIT-CODE: $errno " : ''),
                           'ERRORS: ',
                           ($error_number ? $error_number : 0),' ',
                           'WARNINGS: ',
                           ($warning_number ? $warning_number : 0),
                           ($global_debug ?
                            ' DEBUGS: ' .
                            ($debug_number ? $debug_number : 0) : ''),' ',
                           'TIME: ',markTime(0),"s]"));
    my $log_rpt = $rpt;

    #Print an extended report if requested or there was an error or warning
    $rpt     .= getErrorSummary((!$logging || $log_mirror || !$log_errors),
                                (!$logging || $log_mirror || !$log_warnings),
                                $pipeline,$global_verbose,$global_quiet,
                                $global_debug);
    $log_rpt .= getErrorSummary($log_errors,$log_warnings,$pipeline,
                                $global_verbose,$global_quiet,$global_debug);

    print STDERR ($rpt)
      if($print_report && ($log_mirror || !$local_log_report));

    logger($log_rpt) if($local_log_report);

    return(0);
  }

sub getErrorSummary
  {
    my $errors         = $_[0];
    my $warnings       = $_[1];
    my $pipeline       = $_[2];
    my $global_verbose = defined($_[3]) ? $_[3] : 0;
    my $global_quiet   = defined($_[4]) ? $_[4] : 0;
    my $global_debug   = defined($_[5]) ? $_[5] : 0;

    my $sum = '';

    if(($errors   && defined($error_number)   && $error_number) ||
       ($warnings && defined($warning_number) && $warning_number))
      {
	$sum .= " SUMMARY:\n";

	#If there were errors
	if(defined($error_number) && $error_number)
	  {
	    foreach my $err_type
	      (sort {$error_hash->{$a}->{EXAMPLENUM} <=>
		       $error_hash->{$b}->{EXAMPLENUM}}
	       keys(%$error_hash))
	      {$sum .= join('',("\t",$error_hash->{$err_type}->{NUM},
				" ERROR",
				($error_hash->{$err_type}->{NUM} > 1 ?
				 'S' : '')," LIKE: [",
				(defined($DEBUG) && !$DEBUG ?
				 (defined($pipeline) && !$pipeline ?
				  $error_hash->{$err_type}->{EXAMPLE} :
				  $error_hash->{$err_type}->{EXAMPLEPIPE}) :
				 (defined($pipeline) && !$pipeline ?
				  $error_hash->{$err_type}->{EXAMPLEDEBUG} :
				  $error_hash->{$err_type}
				  ->{EXAMPLEDEBUGPIPE})),"]\n"))}
	  }

	#If there were warnings
	if(defined($warning_number) && $warning_number)
	  {
	    foreach my $warn_type
	      (sort {$warning_hash->{$a}->{EXAMPLENUM} <=>
		       $warning_hash->{$b}->{EXAMPLENUM}}
	       keys(%$warning_hash))
	      {$sum .= join('',("\t",$warning_hash->{$warn_type}->{NUM},
				" WARNING",
				($warning_hash->{$warn_type}->{NUM} > 1 ?
				 'S' : '')," LIKE: [",
				(defined($DEBUG) && !$DEBUG ?
				 (defined($pipeline) && !$pipeline ?
				  $warning_hash->{$warn_type}->{EXAMPLE} :
				  $warning_hash->{$warn_type}->{EXAMPLEPIPE}) :
				 (defined($pipeline) && !$pipeline ?
				  $warning_hash->{$warn_type}->{EXAMPLEDEBUG} :
				  $warning_hash->{$warn_type}
				  ->{EXAMPLEDEBUGPIPE})),"]\n"))}
	  }

        $sum .= join('',("\tScroll up to inspect full errors/warnings in-",
			 "place.\n"));
      }
    else
      {$sum .= "\n"}

    return($sum);
  }

#This method takes multiple "types" of "sets of input files" in a 3D array
#and returns an array of combination arrays where a combination contains 1 file
#of each type.  The best way to explain the associations is by example.  Here
#are example input file associations without output suffixes or directories.
#Each type is a 2D array contained in the outer type array:

#Example 1:
#input files of type 1: [[1,2,3],[a,b,c]]
#input files of type 2: [[4,5,6],[d,e,f]]
#input files of type 3: [[x,y]]
#resulting associations: [[1,4,x],[2,5,x],[3,6,x],[a,d,y],[b,e,y],[c,f,y]]
#Example 2:
#input files of type 1: [[1,2,3],[a,b,c]]
#input files of type 2: [[4,5,6],[d,e,f]]
#input files of type 3: [[x,y,z]]
#resulting associations: [[1,4,x],[2,5,y],[3,6,z],[a,d,x],[b,e,y],[c,f,z]]
#Example 3:
#input files of type 1: [[1,2,3],[a,b,c]]
#input files of type 2: [[4,5,6],[d,e,f]]
#input files of type 3: [[x],[y]]
#resulting associations: [[1,4,x],[2,5,x],[3,6,x],[a,d,y],[b,e,y],[c,f,y]]
#Example 4:
#input files of type 1: [[1,2,3],[a,b,c]]
#input files of type 2: [[4,5,6],[d,e,f]]
#input files of type 3: [[x],[y],[z]]
#resulting associations: [[1,4,x],[2,5,y],[3,6,z],[a,d,x],[b,e,y],[c,f,z]]
#Example 5:
#input files of type 1: [[1,a],[2,b],[3,c]]
#input files of type 2: [[4,d],[5,e],[6,f]]
#input files of type 3: [[x],[y],[z]]
#resulting associations: [[1,4,x],[2,5,y],[3,6,z],[a,d,x],[b,e,y],[c,f,z]]
#Example 6:
#input files of type 1: [[1],[2]]
#input files of type 2: [[a]]
#resulting associations: [[1,a],[2,a]]

#If you submit a 2D array or 1D array, or even a single string, the method
#will wrap it up into a 3D array for processing.  Note that a 1D array mixed
#with 2D arrays will prompt the method to guess which way to associate that
#series of files in the 1D array(s) with the rest.
#The dimensions of the 2D arrays are treated differently if they are the same
#as when they are different.  First, the method will attempt to match array
#dimensions by transposing (and if a dimension is 1, it will copy elements to
#fill it up to match).  For example, the method detects that the second
#dimension in this example matches, so it will copy the 1D array:

#From this:
#input files of type 1: [[1,2],[a,b]]
#input files of type 2: [[4,5],[d,e]]
#input files of type 3: [[x,y]]       #[x,y] will be copied to match dimensions
#To this:
#input files of type 1: [[1,2],[a,b]]
#input files of type 2: [[4,5],[d,e]]
#input files of type 3: [[x,y],[x,y]]
#resulting associations: [[1,4,x],[2,5,y],[a,d,x],[b,e,y]]

#There are also 2 other optional inputs for creating the second return value
#(an array of output file stubs/names associated with each input file).  The
#two optional inputs are a 1D array of outfile suffixes and a 2D array of
#output directories.

#Associations between output directories will be made in the same way as
#between different input file types.  For example, when suffixes are provided
#for type 1:

#Example 1:
#input files of type 1: [[1,2,3],[a,b,c]]
#input files of type 2: [[4,5,6],[d,e,f]]
#outfile suffixes: [.txt,.tab]
#resulting input file associations: [[1,4],[2,5],[3,6],[a,d],[b,e],[c,f]]
#resulting outfile names:  [[1.txt,4.tab],[2.txt,5.tab],[3.txt,6.tab],
#                           [a.txt,d.tab],[b.txt,e.tab],[c.txt,f.tab]]

#Output directories are associated with combinations of files as if the output
#directory 2D array was another file type.  However, the most common expected
#usage is that all output will go to a single directory, so here's an example
#where only the first input file type generates an output file and all output
#goes to a single output directory:

#input files of type 1: [[1,2,3],[a,b,c]]
#input files of type 2: [[4,5,6],[d,e,f]]
#outfile suffixes: [.txt]
#output directories: [[out]]
#resulting input file associations: [[1,4],[2,5],[3,6],[a,d],[b,e],[c,f]]
#resulting outfile names:  [[1.txt,undef],[2.txt,undef],[3.txt,undef],
#                           [a.txt,undef],[b.txt,undef],[c.txt,undef]]

#Note that this method also detects input on standard input and treats it
#as an input of the same type as the first array in the file types array passed
#in.  If there is only one input file in that array, it will be considered to
#be a file name "stub" to be used to append outfile suffixes.
sub getFileSets
  {
    my $file_types_array = $_[0]; #A 3D array where the outer array specifies
                                  #file type (e.g. all files supplied by
                                  #instances of -i), the next array specifies
                                  #a specific instance of an option/flag (e.g.
                                  #the first instance of -i on the command
                                  #line) and the inner-most array contains the
                                  #arguments to that instance of that flag.
    my $outfile_suffixes = $_[1]; #OPTIONAL: An array (2D) no larger than
                                  #file_types_array's outer array (multiple
                                  #suffixes per input file type).  The order of
                                  #the suffix types must correspond to the
                                  #order of the input file types.  I.e. the
                                  #outer array of the file_types_array must
                                  #have the same corresponding order of type
                                  #elements (though it may contain fewer
                                  #elements if (e.g.) only 1 type of input file
                                  #has output files).  E.g. If the first type
                                  #in the file_types_array is files submitted
                                  #with -i, the first suffix will be appended
                                  #to files of type 1.  Note that if suffixes
                                  #are provided, any type without a suffix will
                                  #not be present in the returned outfile array
                                  #(there will be an undefined value as a
                                  #placeholder).  If no suffixes are provided,
                                  #the returned outfile array will contain
                                  #outfile stubs for every input file type to
                                  #which you must append your own suffix.
    my $outdir_array     = $_[2]; #OPTIONAL: A 2D array of output directories.
                                  #The dimensions of this array must either be
                                  #1x1, 1xN, or NxM where N or NxM must
                                  #correspond to the dimensions of one of the
                                  #input file types.  See notes above for an
                                  #example.  Every input file combination will
                                  #output to a single output directory.  Also
                                  #note that if suffixes are provided, any type
                                  #without a suffix will not be present in the
                                  #returned outfile array.  If no suffixes are
                                  #provided, the returned outfile array will
                                  #contain outfile stubs to which you must
                                  #append your own suffix.
    my $outfile_stub  = defined($default_stub) ? $default_stub : 'STDIN';
    my $skip_existing = getVarref('skip',1);

    debug({LEVEL => -1},"Collision mode sent in: [",
	  (defined($_[3]) ?
	   (ref($_[3]) eq 'SCALAR' ? $_[3] : '(' .
	    join('),(',map {my $tm=$_;(defined($tm) ?
				       join(',',map {defined($_) ?
						       $_ : 'undef'} @$tm) :
				       'undef')} @{$_[3]}) .
	    ')') : 'undef'),"].  Global collide mode: [",getCollisionMode(),
	  "].  User over-ridden collision-mode: [",
	  (defined($user_collide_mode) ? $user_collide_mode : 'undef'),"].  ",
	  "Programmer global collision-mode: [",
	  (defined($def_collide_mode) ? $def_collide_mode : 'undef'),"]");

    debug({LEVEL => -1},"Called with outfile suffixes: [[",
	  join('],[',map {my $a = $_;join(',',map {defined($_) ? $_ : 'undef'}
					  @$a)} @$outfile_suffixes),"]].");

    debug({LEVEL => -99},"Num initial arguments: [",scalar(@_),"].");

    debug({LEVEL => -99},"Initial size of file types array: [",
	  scalar(@$file_types_array),"].");

    ##
    ## Error check/fix the file_types_array (a 3D array of strings)
    ##
    if(ref($file_types_array) ne 'ARRAY')
      {
	#Allow them to submit scalars of everything
	if(ref(\$file_types_array) eq 'SCALAR')
	  {$file_types_array = [[[$file_types_array]]]}
	else
	  {
	    error("Expected an array for the first argument, but got a [",
		  ref($file_types_array),"].");
	    quit(-27);
	  }
      }
    elsif(scalar(grep {ref($_) ne 'ARRAY'} @$file_types_array))
      {
	my @errors = map {ref(\$_)} grep {ref($_) ne 'ARRAY'}
	  @$file_types_array;
	#Allow them to have submitted an array of scalars
	if(scalar(@errors) == scalar(@$file_types_array) &&
	   scalar(@errors) == scalar(grep {$_ eq 'SCALAR'} @errors))
	  {$file_types_array = [[$file_types_array]]}
	else
	  {
	    @errors = map {ref($_) eq '' ? ref(\$_) : ref($_)}
	      grep {ref($_) ne 'ARRAY'}
	      @$file_types_array;
	    error("Expected an array of arrays for the first argument, but ",
		  "found a [",join(',',@errors),"] inside the outer array.");
	    quit(-28);
	  }
      }
    elsif(scalar(grep {my @x=@$_;scalar(grep {ref($_) ne 'ARRAY'} @x)}
		 @$file_types_array))
      {
	#Look for SCALARs
	my @errors = map {my @x=@$_;map {ref(\$_)} @x}
	  grep {my @x=@$_;scalar(grep {ref($_) ne 'ARRAY'} @x)}
	    @$file_types_array;
	debug({LEVEL => -99},"ERRORS ARRAY: [",join(',',@errors),"].");
	#Allow them to have submitted an array of arrays of scalars
	if(scalar(@errors) == scalar(map {@$_} @$file_types_array) &&
	   scalar(@errors) == scalar(grep {$_ eq 'SCALAR'} @errors))
	  {$file_types_array = [$file_types_array]}
	else
	  {
	    #Reset the errors because I'm not looking for SCALARs anymore
	    @errors = map {my @x=@$_;'[' .
			     join('],[',
				  map {ref($_) eq '' ? 'SCALAR' : ref($_)} @x)
			       . ']'}
	      @$file_types_array;
	    error("Expected an array of arrays of arrays for the first ",
		  "argument, but got an array of arrays of [",
		  join(',',@errors),"].");
	    quit(-29);
	  }
      }
    elsif(scalar(grep {my @x = @$_;
		       scalar(grep {my @y = @$_;
				    scalar(grep {ref(\$_) ne 'SCALAR'}
					   @y)} @x)} @$file_types_array))
      {
	my @errors = map {my @x = @$_;map {my @y = @$_;map {ref($_)} @y} @x}
	  grep {my @x = @$_;
		scalar(grep {my @y = @$_;
			     scalar(grep {ref(\$_) ne 'SCALAR'} @y)} @x)}
	    @$file_types_array;
	error("Expected an array of arrays of arrays of scalars for the ",
	      "first argument, but got an array of arrays of [",
	      join(',',@errors),"].");
	quit(-30);
      }

    debug({LEVEL => -99},"Size of file types array after input check/fix: [",
	  scalar(@$file_types_array),"].");

    ##
    ## Error-check/fix the outfile_suffixes array (a 2D array of strings)
    ##
    my $suffix_provided = [map {0} @$file_types_array];
    if(defined($outfile_suffixes))
      {
	if(ref($outfile_suffixes) ne 'ARRAY')
	  {
	    #Allow them to submit scalars of everything
	    if(!defined($outfile_suffixes) ||
	       ref(\$outfile_suffixes) eq 'SCALAR')
	      {
		$suffix_provided->[0] = 1;
		$outfile_suffixes = [[$outfile_suffixes]];
	      }
	    else
	      {
		error("Expected an array for the second argument, but got a [",
		      ref($outfile_suffixes),"].");
		quit(-31);
	      }
	  }
	elsif(scalar(grep {!defined($_) || ref($_) ne 'ARRAY'}
		     @$outfile_suffixes))
	  {
	    my @errors = map {defined($_) ?
				(ref($_) eq '' ? ref(\$_) : ref($_)) : 'undef'}
	      grep {!defined($_) || ref($_) ne 'ARRAY'} @$outfile_suffixes;
	    #Allow them to have submitted an array of scalars
	    if(scalar(@errors) == scalar(@$outfile_suffixes) &&
	       scalar(@errors) == scalar(grep {!defined($_) || $_ eq 'SCALAR'}
					 @errors))
	      {$outfile_suffixes = [$outfile_suffixes]}
	    else
	      {
		error("Expected an array of arrays for the second argument, ",
		      "but got an array containing [",join(',',@errors),"].");
		quit(-32);
	      }
	  }
	elsif(scalar(grep {my @x=@$_;scalar(grep {ref(\$_) ne 'SCALAR'} @x)}
		     @$outfile_suffixes))
	  {
	    #Reset the errors because I'm not looking for SCALARs anymore
	    my @errors = map {my @x=@$_;map {ref($_) . ' REF'} @x}
	      grep {my @x=@$_;scalar(grep {ref($_) ne 'ARRAY'} @x)}
		@$outfile_suffixes;
	    error("Expected an array of arrays of raw scalars for the second ",
		  "argument, but got an array of arrays of [",
		  join(',',@errors),"].");
	    quit(-33);
	  }

	foreach my $suffix_index (0..$#{$outfile_suffixes})
	  {$suffix_provided->[$suffix_index] =
	     defined($outfile_suffixes->[$suffix_index]) &&
	       scalar(@{$outfile_suffixes->[$suffix_index]})}
      }

    ##
    ## Error-check/fix the outdir_array (a 2D array of strings)
    ##
    my $outdirs_provided = 0;
    if(defined($outdir_array) && scalar(@$outdir_array))
      {
	#Error check the outdir array to make sure it's a 2D array of strings
	if(ref($outdir_array) ne 'ARRAY')
	  {
	    #Allow them to submit scalars of everything
	    if(ref(\$outdir_array) eq 'SCALAR')
	      {
		$outdirs_provided = 1;
		$outdir_array     = [[$outdir_array]];
	      }
	    else
	      {
		error("Expected an array for the third argument, but got a [",
		      ref($outdir_array),"].");
		quit(-34);
	      }
	  }
	elsif(scalar(grep {ref($_) ne 'ARRAY'} @$outdir_array))
	  {
	    my @errors = map {ref(\$_)} grep {ref($_) ne 'ARRAY'}
	      @$outdir_array;
	    #Allow them to have submitted an array of scalars
	    if(scalar(@errors) == scalar(@$outdir_array) &&
	       scalar(@errors) == scalar(grep {$_ eq 'SCALAR'} @errors))
	      {
		$outdirs_provided = 1;
		$outdir_array = [$outdir_array];
	      }
	    else
	      {
		@errors = map {ref($_)} grep {ref($_) ne 'ARRAY'}
		  @$outdir_array;
		error("Expected an array of arrays for the third argument, ",
		      "but got an array of [",join(',',@errors),"].");
		quit(-35);
	      }
	  }
	elsif(scalar(grep {my @x=@$_;scalar(grep {ref(\$_) ne 'SCALAR'} @x)}
		     @$outdir_array))
	  {
	    #Look for SCALARs
	    my @errors = map {my @x=@$_;map {ref($_)} @x}
	      grep {my @x=@$_;scalar(grep {ref(\$_) ne 'SCALAR'} @x)}
		@$outdir_array;
	    error("Expected an array of arrays of scalars for the third ",
		  "argument, but got an array of arrays containing [",
		  join(',',@errors),"].");
	    quit(-36);
	  }
	else
	  {$outdirs_provided = 1}

	#If any outdirs are empty strings, error out & quit
	my $empties_exist = scalar(grep {my @x=@$_;scalar(grep {$_ eq ''} @x)}
				   @$outdir_array);
	if($empties_exist)
	  {
	    error("Output directories may not be empty strings.");
	    quit(-37);
	  }
      }

    ##
    ## Confirm the collision modes set, in case the user changed it on the
    ## command line
    ##

    debug({LEVEL => -1},"Filling in missing collision modes with default ",
	  "values.");
    foreach my $fti (0..$#{$outfile_suffixes})
      {
	foreach my $sti (0..$#{$outfile_suffixes->[$fti]})
	  {
	    my $suffuhash =
	      $usage_array->[$file_indexes_to_usage->{$fti}->{$sti}];

	    my $sf_or_of_uhash = $suffuhash;
	    if($usage_array->[$suffuhash->{PAIRID}]->{OPTTYPE} eq 'outfile')
	      {$sf_or_of_uhash = $usage_array->[$suffuhash->{PAIRID}]}

	    my $tmp_collide_mode = getCollisionMode(undef,
						    $sf_or_of_uhash->{OPTTYPE},
						    $suffuhash->{COLLIDE_MODE});

	    $sf_or_of_uhash->{COLLIDE_MODE} = $tmp_collide_mode;
	    $suffuhash->{COLLIDE_MODE}      = $tmp_collide_mode;
	  }
      }

    #If collision mode was not set during the creation of the option, set it now
    #that the command line has been processed.  If it was set, it could be over-
    #ridden by the user on the command line, so reset it.
    foreach my $ftkey (keys(%$file_indexes_to_usage))
      {
	my $suff_hash = $file_indexes_to_usage->{$ftkey};
	foreach my $stkey (keys(%$suff_hash))
	  {
	    my $usg_index = $suff_hash->{$stkey};
	    my $uhash = $usage_array->[$usg_index];

	    if(!defined($uhash->{COLLIDE_MODE}))
	      {$uhash->{COLLIDE_MODE} = getCollisionMode()}
	    else
	      {$uhash->{COLLIDE_MODE} =
		 getCollisionMode(undef,
				  $uhash->{OPTTYPE},
				  $uhash->{COLLIDE_MODE})}
	  }
      }

    debug({LEVEL => -99},
	  "Contents of file types array before adding dash file: [(",
	  join(')(',map {my $t=$_;'{' .
			   join('}{',map {my $e=$_;'[' . join('][',@$e) . ']'}
				@$t) . '}'} @$file_types_array),")].");

    ##
    ## If standard input is present, ensure it's in the file_types_array
    ##
    if(isThereInputOnSTDIN())
      {
	my $primary = (defined($primary_infile_optid) ?
		       $usage_array->[$primary_infile_optid]->{FILEID} :
		       (grep {!exists($outfile_types_hash->{$_})}
			(0..$#{$file_types_array}))[0]);

	#The first element of the file types array is specifically the type of
	#input file that can be provided via STDIN.  However, a user may
	#explicitly supply a dash on the command line to have the STDIN go to a
	#different parameter instead of the default
	debug({LEVEL => -99},"file_types_array->[$primary] is [",
	      (defined($file_types_array->[$primary]) ?
	       'defined' : 'undefined'),"].");

	if(!defined($file_types_array->[$primary]))
	  {$file_types_array->[$primary] = []}

	my $input_files = $file_types_array->[$primary];
	my $num_input_files = scalar(grep {$_ ne '-'} map {@$_} @$input_files);
	my $dash_was_explicit =
	  scalar(grep {my $t=$_;scalar(grep {my $e=$_;
					     scalar(grep {$_ eq '-'} @$e)}
				       @$t)} map {$file_types_array->[$_]}
		 grep {!exists($outfile_types_hash->{$_})}
		 (0..$#{$file_types_array}));
	my $type_index_of_dash = 0;
	if($dash_was_explicit)
	  {$type_index_of_dash =
	     (scalar(grep {my $t=$_;scalar(grep {my $e=$_;
						 scalar(grep {$_ eq '-'} @$e)}
					   @{$file_types_array->[$t]})}
		     grep {!exists($outfile_types_hash->{$_})}
		     (0..$#{$file_types_array})))[0]}

	debug({LEVEL => -99},"There are $num_input_files input files.");
	debug({LEVEL => -99},"Outfile stub: $outfile_stub.");

	#If there's only one input file detected, the dash for STDIN was not
	#explicitly provided, and an outfile suffix has been provided, use that
	#input file as a stub for the output file name construction
	if($num_input_files == 1 && !$dash_was_explicit &&
	   defined($outfile_suffixes) && scalar(@$outfile_suffixes) &&
	   defined($outfile_suffixes->[0]))
	  {
	    $outfile_stub = (grep {$_ ne '-'} map {@$_} @$input_files)[0];

	    #Unless the dash was explicitly supplied as a separate file, treat
	    #the input file as a stub only (not as an actual input file
	    @$input_files = ();
	    $num_input_files = 0;

	    #If the stub contains a directory path AND outdirs were supplied
	    if($outfile_stub =~ m%/% &&
	       defined($outdir_array) &&
	       #Assume the outdir is good if
	       ((ref($outdir_array) eq 'ARRAY' && scalar(@$outdir_array)) ||
		ref(\$outdir_array) eq 'SCALAR'))
	      {
		error("You cannot use an output directory [",
		      " ",(ref(\$outdir_array) eq 'SCALAR' ? $outdir_array :
			   join(' ',map {getOutdirFlag() . (ref($_) eq 'ARRAY' ?
							    join(',',@$_) : $_)}
					   @$outdir_array)),"] and embed a ",
		      "directory path in the file stub [$outfile_stub] at the ",
		      "same time.  Please use one or the other.",
		      {DETAIL =>
		       join('',
			    ('Any input file option (e.g. -i) can be treated ',
			     'as a stub for creating output file names when ',
			     'there is input on standard in and only one ',
			     'value is supplied to the input file option, ',
			     'but it cannot contain a directory path when an ',
			     'output directory is supplied.'))});
		quit(-42);
	      }
	  }
	#If standard input has been redirected in (which is true because we're
	#here) and an outfule_suffix has been defined for the type of files
	#that the dash is in or will be in, inform the user about the name of
	#the outfile using the default stub for STDIN
	elsif(defined($outfile_suffixes) &&
	      scalar(@$outfile_suffixes) > $type_index_of_dash &&
	      defined($outfile_suffixes->[$type_index_of_dash]))
	  {verbose("Input on STDIN will be referred to as [$outfile_stub].")}

	debug({LEVEL => -99},"Outfile stub: $outfile_stub.");

	#Unless the dash was supplied explicitly by the user, push it on
	unless($dash_was_explicit)
	  {
	    debug({LEVEL => -99},"Pushing on the dash file to the other ",
		  "$num_input_files files.");
	    debug({LEVEL => -99},
		  "input_files is ",(defined($input_files) ? '' : 'un'),
		  "defined, is of type [",ref($input_files),
		  "], and contains [",
		  (defined($input_files) ?
		   scalar(@$input_files) : 'undefined'),"] items.");

	    debug({LEVEL => -99},
		  ($input_files eq $file_types_array->[$primary] ?
		   'input_files still references the primary element in the ' .
		   'file types array' : 'input_files has gotten overwritten'));

	    #Create a new 1st input file set with it as the only file member
	    unshift(@$input_files,['-']);

	    debug({LEVEL => -99},
		  ($input_files eq $file_types_array->[$primary] ?
		   'input_files still references the primary element in the ' .
		   'file types array' : 'input_files has gotten overwritten'));
	  }
      }

    debug({LEVEL => -99},
	  "Contents of file types array after adding dash file: [(",
	  join(')(',map {my $t=$_;'{' .
			   join('}{',map {my $e=$_;'[' . join('][',@$e) . ']'}
				@$t) . '}'} @$file_types_array),")].");

    ##
    ## Error-check/fix the file_types_array with the outfile_suffixes array
    ##
    if(scalar(@$file_types_array) < scalar(@$outfile_suffixes))
      {
	error("More outfile suffixes (",scalar(@$outfile_suffixes),"): [",
	      join(',',map {defined($_) ? $_ : 'undef'} @$outfile_suffixes),
	      "] than file types [",scalar(@$file_types_array),"].");
	quit(-43);
      }
    #Elsif the sizes are different, top off the outfile suffixes with undefs
    elsif(scalar(@$file_types_array) > scalar(@$outfile_suffixes))
      {while(scalar(@$file_types_array) > scalar(@$outfile_suffixes))
	 {push(@$outfile_suffixes,undef)}}

    ##
    ## Special case (probably unnecessary now with upgrades in 6/2014)
    ##
    my $one_type_mode = 0;
    #If there's only 1 input file type and (no outdirs or 1 outdir), merge all
    #the sub-arrays
    if(scalar(@$file_types_array) == 1 &&
       (!$outdirs_provided || (scalar(@$outdir_array) == 1 &&
			       scalar(@{$outdir_array->[0]}) == 1)))
      {
	$one_type_mode = 1;
	debug({LEVEL => -99},"Only 1 type of file was submitted, so the ",
	      "array is being preemptively flattened.");

	my @merged_array = ();
	foreach my $row_array (@{$file_types_array->[0]})
	  {push(@merged_array,@$row_array)}
	$file_types_array->[0] = [[@merged_array]];
      }

    debug({LEVEL => -99},
	  "Contents of file types array after merging sub-arrays: [(",
	  join(')(',map {my $t=$_;'{' .
			   join('}{',map {my $e=$_;'[' . join('][',@$e) . ']'}
				@$t) . '}'} @$file_types_array),")].");

    debug({LEVEL => -99},
	  "OUTDIR ARRAY DEFINED?: [",defined($outdir_array),"] SIZE: [",
	  (defined($outdir_array) ? scalar(@$outdir_array) : '0'),"].");

    ##
    ## Prepare to treat outdirs the same as infiles
    ##
    #If output directories were supplied, push them onto the file_types_array
    #so that they will be error-checked and modified in the same way below.
    if($outdirs_provided)
      {push(@$file_types_array,$outdir_array)}

    debug({LEVEL => -99},
	  "Contents of file types array after adding outdirs: [(",
	  join(')(',map {my $t=$_;'{' .
			   join('}{',map {my $e=$_;'[' . join('][',@$e) . ']'}
				@$t) . '}'} @$file_types_array),")].");

    ##
    ## Prepare to error-check file/dir array dimensions
    ##
    my $twods_exist = scalar(grep {my @x = @$_;
			      scalar(@x) > 1 &&
				scalar(grep {scalar(@$_) > 1} @x)}
			     @$file_types_array);
    debug({LEVEL => -99},"2D? = $twods_exist");

    #Determine the maximum dimensions of any 2D file arrays
    my $max_num_rows = (#Sort on descending size so we can grab the largest one
			sort {$b <=> $a}
			#Convert the sub-arrays to their sizes
			map {scalar(@$_)}
			#Grep for arrays larger than 1 with subarrays larger
			#than 1
			grep {my @x = @$_;
			      !$twods_exist ||
				(scalar(@x) > 1 &&
				 scalar(grep {scalar(@$_) > 1} @x))}
			@$file_types_array)[0];

    $max_num_rows = 0 unless(defined($max_num_rows));

    my $max_num_cols = (#Sort on descending size so we can grab the largest one
			sort {$b <=> $a}
			#Convert the sub-arrays to their sizes
			map {my @x = @$_;(sort {$b <=> $a}
					  map {scalar(@$_)} @x)[0]}
			#Grep for arrays larger than 1 with subarrays larger
			#than 1
			grep {my @x = @$_;
			      !$twods_exist ||
				(scalar(@x) > 1 &&
				 scalar(grep {scalar(@$_) > 1} @x))}
			@$file_types_array)[0];

    $max_num_cols = 0 unless(defined($max_num_cols));

    debug({LEVEL => -99},
	  "Max number of rows and columns in 2D arrays: [$max_num_rows,",
	  "$max_num_cols].");

    debug({LEVEL => -99},"Size of file types array: [",
	  scalar(@$file_types_array),"].");

    debug({LEVEL => -99},
	  "Contents of file types array before check/transpose: [(",
	  join(')(',map {my $t=$_;'{' .
			   join('}{',map {my $e=$_;'[' . join('][',@$e) . ']'}
				@$t) . '}'} @$file_types_array),")].");

    ##
    ## Error-check/transpose file/dir array dimensions
    ##
    #Error check to make sure that all file type arrays are either the two
    #dimensions determined above or a 1D array equal in size to either of the
    #dimensions
    my $row_inconsistencies = 0;
    my $col_inconsistencies = 0;
    my $twod_col_inconsistencies = 0;
    my @dimensionalities    = (); #Keep track for checking outfile stubs later
    foreach my $file_type_array (@$file_types_array)
      {
	my @subarrays = @$file_type_array;

	#If it's a 2D array (as opposed to just 1 col or row), look for
	#inconsistencies in the dimensions of the array
	if(scalar(scalar(@subarrays) > 1 &&
		  scalar(grep {scalar(@$_) > 1} @subarrays)))
	  {
	    push(@dimensionalities,2);

	    #If the dimensions are not the same as the max
	    if(scalar(@subarrays) != $max_num_rows)
	      {
		debug({LEVEL => -99},"Row inconsistencies in 2D arrays found");
		$row_inconsistencies++;
	      }
	    elsif(scalar(grep {scalar(@$_) != $max_num_cols} @subarrays))
	      {
		debug({LEVEL => -99},"Col inconsistencies in 2D arrays found");
		$col_inconsistencies++;
		$twod_col_inconsistencies++;
	      }
	  }
	else #It's a 1D array (i.e. just 1 col or row)
	  {
	    push(@dimensionalities,1);

	    #If there's only 1 row
	    if(scalar(@subarrays) == 1)
	      {
		debug({LEVEL => -99},"There's only 1 row of size ",
		      scalar(@{$subarrays[0]}),". Max cols: [$max_num_cols]. ",
		      "Max rows: [$max_num_rows]");
		if(#$twods_exist &&
		   !$one_type_mode &&
		   scalar(@{$subarrays[0]}) != $max_num_rows &&
		   scalar(@{$subarrays[0]}) != $max_num_cols &&
		   scalar(@{$subarrays[0]}) > 1)
		  {
		    debug({LEVEL => -99},
			  "Col inconsistencies in 1D arrays found (size: ",
			  scalar(@{$subarrays[0]}),")");
		    $col_inconsistencies++;
		  }
		#If the 1D array needs to be transposed because it's a 1 row
		#array and its size matches the number of rows, transpose it
		elsif(#$twods_exist &&
		      !$one_type_mode &&
		      $max_num_rows != $max_num_cols &&
		      scalar(@{$subarrays[0]}) == $max_num_rows)
		  {@$file_type_array = transpose(\@subarrays)}
	      }
	    #Else if there's only 1 col
	    elsif(scalar(@subarrays) == scalar(grep {scalar(@$_) == 1}
					       @subarrays))
	      {
		debug({LEVEL => -99},
		      "There's only 1 col of size ",scalar(@subarrays),
		      "\nThe max number of columns is $max_num_cols");
		if(#$twods_exist &&
		   !$one_type_mode &&
		   scalar(@subarrays) != $max_num_rows &&
		   scalar(@subarrays) != $max_num_cols &&
		   scalar(@subarrays) > 1)
		  {
		    debug({LEVEL => -99},"Row inconsistencies in 1D arrays ",
			  "found (size: ",scalar(@subarrays),")");
		    $row_inconsistencies++;
		  }
		#If the 1D array needs to be transposed because it's a 1 col
		#array and its size matches the number of cols, transpose it
		elsif(#$twods_exist &&
		      !$one_type_mode &&
		      $max_num_rows != $max_num_cols &&
		      scalar(@subarrays) == $max_num_cols)
		  {@$file_type_array = transpose(\@subarrays)}
	      }
	    else #There must be 0 cols
	      {
		debug({LEVEL => -99},"Col inconsistencies in 0D arrays found");
		$col_inconsistencies++;
	      }

	    debug({LEVEL => -99},"This should be array references: [",
		  join(',',@$file_type_array),"].");
	  }
      }

    debug({LEVEL => -99},
	  "Contents of file types array after check/transpose: [(",
	  join(')(',map {my $t=$_;'{' .
			   join('}{',map {my $e=$_;'[' . join('][',@$e) . ']'}
				@$t) . '}'} @$file_types_array),")].");

    #Note that if the user has supplied multiple input files that create an
    #output file of the same name, there are a few possible outcomes.  If the
    #collide mode is merge, it is assumed that the user intends the output
    #to be concatenated in a single file.  If in rename mode, the script
    #compounds the the input file names and re-check for uniqueness.  If in
    #error mode, the script will quit with an error about conflicting outfile
    #names.

    ##
    ## Create sets/combos (handling the default stub and prepending outdirs)
    ##
    my($infile_sets_array,$outfiles_sets_array,$stub_sets_array);
    my $source_hash = {};
    if(defined($outdir_array) && scalar(@$outdir_array) &&
       scalar(grep {scalar(@$_)} @$outdir_array))
      {
	debug({LEVEL => -99},"outdir array has [",scalar(@$outdir_array),
	      "] members.");

	my $tmp_infile_sets_array = getMatchedSets($file_types_array);

	foreach my $infile_set (@$tmp_infile_sets_array)
	  {
	    debug({LEVEL => -99},"Infile set with dirname: [",
		  join(',',map {defined($_) ? $_ : 'undef'} @$infile_set),
		  "].");

	    my $stub_set = [];
	    my $dirname = defined($infile_set->[-1]) ? $infile_set->[-1] : '';
	    #For every file (except the last one (which is an output directory)
	    foreach my $fileidx (0..($#{$infile_set} - 1))
	      {
		my $file = $infile_set->[$fileidx];
		my $stub = $file;
		if(defined($stub))
		  {
		    #Use the default outfile stub if this is a redirect
		    $stub = $outfile_stub if($stub eq '-');

		    #Eliminate any path strings from the file name
		    $stub =~ s/.*\///;

		    #Prepend the outdir path
		    my $new_outfile_stub = $dirname .
		      ($dirname =~ /\/$/ ? '' : '/') . $stub;

		    debug({LEVEL => -99},
			  "Prepending directory $new_outfile_stub using [",
			  "$file].");

		    push(@$stub_set,$new_outfile_stub);

		    $source_hash->{$new_outfile_stub}->{$file}++;
		  }
		else
		  {push(@$stub_set,$stub)}
	      }
	    push(@$infile_sets_array,
		 [@{$infile_set}[0..($#{$infile_set} - 1)]]);
	    push(@$stub_sets_array,$stub_set);
	  }
      }
    else
      {
	$infile_sets_array = getMatchedSets($file_types_array);
	$stub_sets_array   = copyArray($infile_sets_array);

	#Replace any dashes with the outfile stub
	foreach my $stub_set (@$stub_sets_array)
	  {
	    foreach my $stub (grep {defined($_)} @$stub_set)
	      {
		$stub = $outfile_stub if(defined($stub) && $stub eq '-');

		$source_hash->{$stub}->{$stub}++;
	      }
	  }
      }

    #makeCheckOutputs returns an outfiles_sets_array and stub_sets_array that
    #have been confirmed to not overwrite each other or existing files.  It
    #quits the script if it finds a conflict.  It uses the output conf mode
    #variable to know when to compound file names to avoid potential
    #overwrites, but either compounds or quits with an error based on the mode
    #(merge, rename, or error).
    my($skip_sets);
    ($outfiles_sets_array,
     $stub_sets_array,
     $skip_sets) = makeCheckOutputs($stub_sets_array,
				    $outfile_suffixes,
				    $source_hash);

    if($skip_existing && scalar(grep {$_} @$skip_sets))
      {
	@$infile_sets_array = (map {$infile_sets_array->[$_]}
			       grep {!$skip_sets->[$_]}
			       (0..$#{$infile_sets_array}));
	@$outfiles_sets_array = (map {$outfiles_sets_array->[$_]}
				 grep {!$skip_sets->[$_]}
				 (0..$#{$outfiles_sets_array}));
	@$stub_sets_array = (map {$stub_sets_array->[$_]}
			     grep {!$skip_sets->[$_]}
			     (0..$#{$stub_sets_array}));
      }

    debug({LEVEL => -1},"Processing input file sets: [(",
	  join('),(',(map {my $a = $_;join(',',map {defined($_) ? $_ : 'undef'}
					   @$a)} @$infile_sets_array)),
	  ")] and output files: [(",
	  join('),(',
               (map {my $a = $_;
                     join(',',map {my $b = $_;defined($b) ?
				     scalar(@$b) == 0 ? '[EMPTY]' :
				       '[' .
					 join('],[',map {defined($_) ?
							   ($_ eq '' ?
							    'EMPTY-STRING' :
							    $_) :
							      'undef'} @$b) .
								']' : 'undef'}
		@$a)} @$outfiles_sets_array)),")].");

    recordOutfileModes($outfiles_sets_array);

    return($infile_sets_array,$outfiles_sets_array,$stub_sets_array);
  }

#This saves the collision mode for each individual file, so the programmer can
#call openOut using only a file name and we will know how to open it
#Globals used: $usage_array, $file_indexes_to_usage, $outfile_mode_lookup,
#              $output_file_sets
sub recordOutfileModes
  {
    my $outfiles_sets_array = (defined($_[0]) ? $_[0] : $output_file_sets);

    foreach my $set (grep {scalar(@$_)} @$outfiles_sets_array)
      {
	foreach my $type_index (grep {defined($set->[$_]) &&
					scalar(@{$set->[$_]})} (0..$#{$set}))
	  {
	    foreach my $suff_index (grep {defined($set->[$type_index]->[$_])}
				    (0..$#{$set->[$type_index]}))
	      {
		my $outfile   = $set->[$type_index]->[$suff_index];
		my $usg_index = fileIndexesToOptionID($type_index,$suff_index);

		if(defined($usg_index))
		  {
		    my $uhash = $usage_array->[$usg_index];
		    $outfile_mode_lookup->{$outfile} = $uhash->{COLLISION_MODE};
		  }
		else
		  {$outfile_mode_lookup->{$outfile} = getCollisionMode()}
	      }
	  }
      }
  }

#Globals used: $user_collide_mode
sub getCollisionMode
  {
    my $outfile       = $_[0];
    my $outfile_type  = $_[1]; #outfile, suffix, logfile, or logsuff i.e. called
                               #from add{Out,Log}file[Suffix]Option
    my $supplied_mode = $_[2];

    if(defined($supplied_mode) && ref($supplied_mode) ne '')
      {error("getCollisionMode - Third option must be a scalar.")}

    #Return the default collision mode if no file name supplied
    if(!defined($outfile))
      {
	if($command_line_stage >= ARGSREAD)
	  {
	    #If the user set the collision mode using --collision-mode
	    if(defined($user_collide_mode))
	      {return($user_collide_mode)}
	    #Else if the mode was defined in the call
	    elsif(defined($supplied_mode))
	      {return($supplied_mode)}
	    #Else if the programmer defined a global mode
	    elsif(defined($def_collide_mode) && $def_collide_mode ne '')
	      {return($def_collide_mode)}
	    #Else if this is being called for a default from an
	    #addOutfile[Suffix]Option method
	    elsif(defined($outfile_type))
	      {
		if($outfile_type eq 'suffix')
		  {return($def_collide_mode_suff)}
		elsif($outfile_type eq 'outfile')
		  {return($def_collide_mode_outf)}
		elsif($outfile_type eq 'logfile' || $outfile_type eq 'logsuff')
		  {return($def_collide_mode_logf)}
		else
		  {
		    error("Invalid output file type: [$outfile_type].  ",
			  "Returning collision mode: [error]");
		    return('error');
		  }
	      }
	    #Else it's assumed this is a tracked output file type being 'set
	    #later' - return the outfile collide mode default (legacy: error)
	    else
	      {return($def_collide_mode_suff)}
	  }
	else
	  {
	    #If the mode was defined in the call
	    if(defined($supplied_mode))
	      {return($supplied_mode)}
	    #Else if the programmer set the collision mode using setDefaults
	    elsif(defined($def_collide_mode) && $def_collide_mode ne '')
	      {return($def_collide_mode)}
	    #Else if this is a tracked outfile type (implied by a defined type)
	    elsif(defined($outfile_type))
	      {
		#Return undef, meaning determine later via command line setting
		if($outfile_type eq 'suffix'  || $outfile_type eq 'outfile' ||
		   $outfile_type eq 'logfile' || $outfile_type eq 'logsuff')
		  {return(undef)}
		else
		  {
		    error("Invalid output file type: [$outfile_type].  ",
			  "Returning collision mode: [error]");
		    return('error');
		  }
	      }
	    #Else it's assumed this is an untracked output file type - return
	    #the outfile collision mode default (legacy: merge)
	    else
	      {return($def_collide_mode_outf)}
	  }
      }
    else
      {
	#Treat standard out and /dev/null specially
	if($outfile eq '-' || $outfile eq '/dev/null')
	  {return('merge')}
	#Else if the user (or programmer) has set the collide mode explicitly
	##TODO: This will change with requirement 114.  Also see comments in
	##      requirement 219
	elsif(defined($user_collide_mode))
	  {return($user_collide_mode)}
	#Else if the command line has been processed
	elsif($command_line_stage >= ARGSREAD)
	  {
	    #If this is a tracked file
	    if(exists($outfile_mode_lookup->{$outfile}) &&
		  defined($outfile_mode_lookup->{$outfile}))
	      {return($outfile_mode_lookup->{$outfile})}
	    elsif(defined($outfile_type))
	      {
		if($outfile_type eq 'suffix')
		  {return($def_collide_mode_suff)}
		elsif($outfile_type eq 'outfile')
		  {return($def_collide_mode_outf)}
		elsif($outfile_type eq 'logfile' || $outfile_type eq 'logsuff')
		  {return($def_collide_mode_logf)}
		else
		  {
		    error("Invalid output file type: [$outfile_type].  ",
			  "Returning collision mode: [error]");
		    return('error');
		  }
	      }
	    else
	      {return($def_collide_mode_outf)}
	  }
	#Else the command line has not been processed
	else
	  {
	    #It is assumed to be an untracked file
	    return($def_collide_mode_outf);
	  }
      }
  }

#This method transposes a 2D array (i.e. it swaps rows with columns).
#Assumes argument is a 2D array.  If the number of columns is not the same from
#row to row, it fills in missing elements with an empty string.
sub transpose
  {
    my $twod_array    = $_[0];
    debug({LEVEL => -99},"Transposing: [(",
	  join('),(',map {join(',',@$_)} @$twod_array),")].");
    my $transposition = [];
    my $last_row = scalar(@$twod_array) - 1;
    my $last_col = (sort {$b <=> $a} map {scalar(@$_)} @$twod_array)[0] - 1;
    debug({LEVEL => -99},"Last row: $last_row, Last col: $last_col.");
    foreach my $col (0..$last_col)
      {push(@$transposition,
	    [map {$#{$twod_array->[$_]} >= $col ?
		    $twod_array->[$_]->[$col] : ''}
	     (0..$last_row)])}
    debug({LEVEL => -99},"Transposed: [(",
	  join('),(',map {join(',',@$_)} @$transposition),")].");
    return(wantarray ? @$transposition : $transposition);
  }

#This method takes a 1D or 2D array of output directories and creates them
#(Only works on the last directory in a path.)  Returns non-zero if successful
sub mkdirs
  {
    my @dirs            = @_;
    my $status          = 1;
    my @unwritable      = ();
    my @errored         = ();
    my @undeleted       = ();
    my $overwrite       = getVarref('overwrite',1);
    my $local_overwrite = defined($overwrite) ? $overwrite : 0;
    my $dry_run         = getVarref('dry_run',1);
    my $local_dry_run   = defined($dry_run)   ? $dry_run   : 0;
    my $seen            = {};

    my $use_as_default  = getVarref('save_args',1);

    #If --save-args was supplied, do not create any directories unless it is
    #just the defaults directory, because otherwise the script is only going to
    #save the command line options & quit
    return($status) if(defined($use_as_default) && $use_as_default &&
		       (scalar(@dirs) != 1 || $dirs[0] ne $defaults_dir));

    #Create the output directories
    if(scalar(@dirs))
      {
	foreach my $dir_set (@dirs)
	  {
	    my @dirlist = (ref($dir_set) eq 'ARRAY' ? @$dir_set : $dir_set);

	    foreach my $dir (@dirlist)
	      {
		if(!defined($dir))
		  {
		    error("Undefined directory sent to mkdirs.");
		    next;
		  }

		next if(exists($seen->{$dir}));

		#If the directory exists and we're not going to overwrite it,
		#check it to see if we'll have a problem writing files to it
		#Note: overwrite has to be 2 or more to delete a directory
		if(-e $dir && $local_overwrite < 2)
		  {
		    #If the directory is not writable
		    if(!(-w $dir))
		      {push(@unwritable,$dir)}
		    #Else if we are in overwrite mode
		    elsif($local_overwrite && isDebug())
		      {warning('The --overwrite flag will not empty or ',
			       'delete existing output directories.  If ',
			       'you wish to delete existing output ',
			       'directories, you must do it manually.')}
		  }
		#Else if this isn't a dry run
		elsif(!$local_dry_run)
		  {
		    if($overwrite > 1 && -e $dir)
		      {
			#We're only going to delete files if they have headers
			#indicating that they were created by a previous run of
			#this script

			deletePrevRunDir($dir);
		      }

		    #We didn't delete manually created files above, so the
		    #directory may still exist and not need recreated
		    if(-e $dir)
		      {push(@undeleted,$dir)}
		    else
		      {
			my $tmp_status = mkdir($dir);
			if(!$tmp_status)
			  {
			    $status = 0;
			    push(@errored,"[$dir]: $!");
			  }
		      }
		  }
		#Else, check to see if creation is feasible in dry-run mode
		else
		  {
		    my $encompassing_dir = $dir;
		    $encompassing_dir =~ s%/$%%;
		    $encompassing_dir =~ s/[^\/]+$//;
		    $encompassing_dir = '.'
		      unless($encompassing_dir =~ /./);

		    if(!(-w $encompassing_dir))
		      {error("Unable to create directory: [$dir].  ",
			     "Encompassing directory is not writable.")}
		    else
		      {verbose("[$dir] Directory created.")}
		  }

		$seen->{$dir} = 1;
	      }
	  }

	if(scalar(@unwritable))
	  {error("These output directories do not have write permission: [",
		 join(',',@unwritable),
		 "].  Please change the permissions to proceed.")}

	if(scalar(@errored))
	  {error("These output directories could not be created: [",
		 join(',',@errored),"].")}

	if(scalar(@undeleted))
	  {error("These pre-existing output directories could not be deleted ",
		 "because they contain unverified safe-to-delete files (see ",
		 "--help or --overwrite in the usage): [",join(',',@undeleted),
		 "].")}

	quit(-46)
	  if(scalar(@errored) || scalar(@errored) || scalar(@undeleted));
      }

    return($status);
  }

#This method will crawl through a directory and unlink any files that have
#headers indicating they were created by this script, and the directory itself
#if nothing is left
#Globals used: $overwrite
sub deletePrevRunDir
  {
    my $dir       = $_[0];
    my $status    = 1;      #SUCCESS = 1, FAILURE = 0
    my $overwrite = getVarref('overwrite',1);

    if($overwrite < 2)
      {
	$status = 0;
	warning("Removing an existing output directory such as [$dir] ",
		"requires --overwrite to be supplied more then once.");
	return($status);
      }

    my($dh);
    unless(opendir($dh, $dir))
      {
	error("Unable to open directory: [$dir]");
	$status = 0;
	return($status);
      }

    my $total = 0;
    my $deleted = 0;
    while(my $f = readdir($dh))
      {
	next if($f eq '.' || $f eq '..');

	$total++;

	if(-d $f)
	  {$deleted += deletePrevRunDir("$dir/$f")}
	else
	  {
	    my $imadethis = iMadeThisBefore("$dir/$f");
	    if($imadethis && !unlink("$dir/$f"))
	      {
		error("Unable to delete file [$dir/$f] from previous run.  ",
		      $!);
		$status = 0;
	      }
	    elsif($imadethis)
	      {$deleted++}
	  }
      }

    closedir($dh);

    #If everything in the directory was successfully deleted, but we could not
    #delete this directory
    if($total == $deleted && !rmdir($dir))
      {$status = 0}

    return($status)
  }

sub iMadeThisBefore
  {
    my $file            = $_[0];
    my $imadethisbefore = 0;

    #Determine if the file was created while or after this script started
    my $lmdsecs = (stat($file))[9];
    if($lmdsecs > $^T)
      {
	$imadethisbefore = 0;
	return($imadethisbefore);
      }

    #Guess whether the header in this file indicates that this script created
    #the file.  (Depends on whether the run included the header)
    unless(openIn(*DEL,$file,1))
      {
	error("Unable to determine if file [$file] was from a previous run.");
	return($imadethisbefore);
      }

    my $script     = getScriptName();
    my $script_pat = quotemeta($script);
    my $match_name = 0;
    my $match_pid  = 0;
    my $pid        = '';

    while(getLine(*DEL))
      {
	last unless(/^\s*#/);

	if(/$script_pat/)
	  {$match_name = 1}
	if(/^#PID: (\d+)/)
	  {
	    $pid = $1;
	    $match_pid = 1;
	  }
	last if($match_name && $match_pid);
      }

    $imadethisbefore = ($match_name && $match_pid && $pid ne $$);

    closeIn(*DEL);

    return($imadethisbefore);
  }

#This method checks for existing output files
#Globals used: $overwrite, $skip_existing
sub checkFile
  {
    my $output_file         = defined($_[0]) ? $_[0] : return(1);
    my $input_file_set      = $_[1]; #Optional: Used for verbose/error messages
    my $local_quiet         = scalar(@_) > 2 && defined($_[2]) ? $_[2] : 0;
    my $quit                = scalar(@_) > 3 && defined($_[3]) ? $_[3] : 1;
    my $status              = 1;
    my $overwrite           = getVarref('overwrite',1);
    my $local_overwrite     = defined($overwrite) ? $overwrite : 0;
    my $skip_existing       = getVarref('skip',1);
    my $local_skip_existing = defined($skip_existing) ? $skip_existing : 0;

    if(-e $output_file && $output_file ne '/dev/null')
      {
	debug({LEVEL => -2},"Output file: [$output_file] exists.");

	if($local_skip_existing)
	  {
	    verbose("[$output_file] Output file exists.  Skipping",
		    (defined($input_file_set) ?
                     (" input file(s): [",join(',',@$input_file_set),"]") :
                     ''),".") unless($local_quiet);
	    $status = 0;
	  }
	elsif(!$local_overwrite)
	  {
	    error("[$output_file] Output file exists.  Unable to ",
		  "proceed.  ",
                  (defined($input_file_set) ?
                   ("Encountered while processing input file(s): [",
		    join(',',grep {defined($_)} @$input_file_set),
		    "].  ") : ''),
                  "This may have been caused by multiple input files ",
		  "writing to one output file because there were not ",
		  "existing output files when this script started.  If any ",
		  "input files are writing to the same output file, you ",
		  "should have seen a warning about this above.  Otherwise, ",
		  "you may have multiple versions of this script running ",
		  "simultaneously.  Please check your input files and ",
		  "outfile suffixes to fix any conflicts or supply one of ",
		  "the --skip, --overwrite, or --append flags.")
	      unless($local_quiet);

	    #An exit code of -1 will quit even if --force is supplied.  --force
	    #is intended to over-ride programmatic errors.  --overwrite is
	    #intended to over-ride existing files.
	    quit(-1) if($quit);

	    $status = 0;
	  }
      }
    else
      {debug({LEVEL => -2},"Output file: [$output_file] does not exist yet.")}

    return($status);
  }

sub openOut
  {
    unless($command_line_stage)
      {processCommandLine()}
    my @in = getSubParams([qw(HANDLE FILE SELECT QUIET HEADER APPEND MERGE)],
			  [qw(HANDLE FILE)],
			  [@_]);
    my $file_handle     = $in[0];
    my $output_file     = $in[1];
    my $local_select    = (scalar(@in) >= 3 ? $in[2] : undef);
    my $local_quiet     = (scalar(@in) >= 4 && defined($in[3]) ? $in[3] : 0);
    my $local_verbose   = getVarref('verbose',1,0);
    my $header          = getVarref('header',1,0);
    my $local_header    = (scalar(@in) >= 5 && defined($in[4]) ? $in[4] :
			   $header);
    my $explicit_append = $in[5];  #May be undefined
    my $merge_mode      = (scalar(@in) >= 7 && defined($in[6]) ? $in[6] :
			   getCollisionMode($output_file) =~ /^m/i ? 1 : 0);
                          #0 = never append
                          #1 = append after initial open, based on collide_mode
    my $dry_run         = getVarref('dry_run',1);
    my $local_dry_run   = defined($dry_run) ? $dry_run : 0;
    my $status          = 1;
    my($select);

    debug({LEVEL => -1},"Collision mode: [",getCollisionMode($output_file),
	  "] for file: [",(defined($output_file) ? $output_file : 'undef'),
	  "] Resulting merge mode: [$merge_mode].");

    #If local_quiet is negative, treat it as verbose=0, not quiet
    if($local_quiet < 0)
      {
        $local_quiet   = 0;
        $local_verbose = 0;
      }
    elsif($local_quiet)
      {$local_verbose = 0}

    if(!defined($output_file))
      {
	#Quietly open /dev/null if not defined so that the programmer doesn't
	#have to check if the user supplied an optional non-primary file type
	$output_file   = '/dev/null';
	$status        = 0;
	$local_quiet   = 1;
        $local_verbose = 0;
      }

    debug({LEVEL=>-1},"openOut collision mode: [",
	  getCollisionMode($output_file),"] Global append mode: [",
	  getVarref('append',1),"] Append mode: [",
	  (defined($explicit_append) ? $explicit_append : 'undef'),
	  "] Merge mode: [$merge_mode] Original: [",
	  (defined($explicit_append) ? $explicit_append : 'undef'),"].");

    if($output_file ne '-')
      {
	#Silently remove a single leading '>' character
	if($output_file =~ /^\s*>[^>]/)
	  {$output_file =~ s/^\s*>//}
	elsif($output_file =~ /^\s*(\||\+|<|>)/)
	  {
	    if($output_file =~ /^\s*>/)
	      {
		warning("An attempt to enter append mode using '>>' in the ",
			"file name argument was detected in [$output_file].  ",
			"Switching to append mode.  Please edit the code to ",
			"use the append parameter to this method.")
		  unless(defined($explicit_append) && $explicit_append);
		$explicit_append = 1;
	      }
	    else
	      {
		my $errfound = $1;
		error("openOut only supports write mode and expects an ",
		      "output file name as the second argument.  Leading ",
		      "characters to control the output mode, such as ",
		      "[$errfound] in [$output_file] are not supported.");
		$status = 0;
		return($status);
	      }
	  }
	elsif($output_file =~ /\|\s*$/)
	  {
	    my $errfound = $1;
	    error("openOut only supports write mode and expects an output ",
		  "file name as the second argument.  Trailing characters to ",
		  "control the output, such as [$errfound] in [$output_file] ",
		  "are not supported.");
	    $status = 0;
	    return($status);
	  }
      }

    #Determine if we should select the output handle: default to user-specified
    #If not, select the handle if current default is STDOUT, else don't select
    if(defined($local_select) && $local_select != 0)
      {
	debug({LEVEL=>-1},"Explicit select.");
	#An explicit select
	$select = 2;

	my $selected_handle = '*' . select();
	#Confirm that this handle was/is selected before selecting STDOUT
	if(defined($selected_handle) && $selected_handle ne *STDOUT)
	  {
	    if(exists($open_out_handles->{$selected_handle}))
	      {
		my $selected_file =
		  $open_out_handles->{$selected_handle}->{CURFILE};
		debug("WARNING: Only 1 output handle should be selected at a ",
		      "time.  Selecting handle for output file [",
		      ($output_file ne '-' ? $output_file : 'STDOUT'),
		      "] and throwing out the select of the tracked file ",
		      "[$selected_file].");
	      }
	    else
	      {
		debug("WARNING: Only 1 output handle should be selected at a ",
		      "time.  Selecting handle for output file [",
		      ($output_file ne '-' ? $output_file : 'STDOUT'),
		      "] and ignoring the select of the untracked file ",
		      "handle [$selected_handle].");
	      }
	  }
      }
    elsif(defined($local_select) && $local_select == 0)
      {
	debug({LEVEL=>-1},"Explicit no select.");
	#Set an explicit select
	$select = 0;
      }
    #Else if STDOUT is currently selected or the output file is '-'
    #(implying an anonymous file handle is being opened & selected)
    elsif(select() eq *STDOUT || '*' . select() eq *STDOUT ||
	  $output_file eq '-')
      {
	debug({LEVEL=>-1},"Implicit select.");
	#Set an implicit select
	$select = 1;

	if($output_file eq '-')
	  {
	    my $selected_handle = '*' . select();
	    #Confirm that this handle was/is selected before selecting STDOUT
	    if(!defined($selected_handle) || $selected_handle eq *STDOUT)
	      {$select = 1}
	    elsif(exists($open_out_handles->{$selected_handle}))
	      {
		my $selected_file =
		  $open_out_handles->{$selected_handle}->{CURFILE};
		error("Cannot select an anonymous file handle because a ",
		      "handle for output file [$selected_file] is already ",
		      "selected.");
		$status = 0;
		return($status);
	      }
	    else
	      {
		error("Cannot select an anonymous file handle because an ",
		      "untracked file handle [$selected_handle] has been ",
		      "selected.");
		$status = 0;
		return($status);
	      }
	  }
      }
    #Else another handle is currently selected and select is supposed to be
    #implicit, so throw a warning and don't select
    else
      {
	debug({LEVEL=>-1},"No select.");
	my $selected_handle = '*' . select();
	my($selected_file);
	if(exists($open_out_handles->{$selected_handle}))
	  {
	    $selected_file = $open_out_handles->{$selected_handle}->{CURFILE};
	    warning("Only 1 output handle can be selected at a time.",
		    {DETAIL =>
		     join('',("Not selecting handle for output file ",
			      "[$output_file] because an open selected ",
			      "handle exists [$selected_handle] for file ",
			      "[$selected_file].  A code edit to add `SELECT ",
			      "=> 0` to the call to openOut using file ",
			      "handle [$file_handle]."))});
	  }
	else
	  {
	    debug("Rejected outfile handles: [",
		  join(',',keys(%$rejected_out_handles)),"].\n",
		  "Open outfile handles: [",
		  join(',',keys(%$open_out_handles)),"].",{LEVEL => -1});
	    warning("Only 1 output handle can be selected at a time.",
		    {DETAIL =>
		     join('',("Not selecting handle for output file ",
			      "[$output_file] because an untracked file ",
			      "handle [$selected_handle] has been ",
			      "selected.  A code edit to either not call ",
			      "`select($selected_handle)` or to add `SELECT ",
			      "=> 0` to the call to openOut using file ",
			      "handle [$file_handle]."))});
	  }
	$select = 0;
      }

    debug({LEVEL => -3},"Output file is of type [",
	  (ref($output_file) eq '' ? 'SCALAR' : ref($output_file)),'].');

    #If the output file is '-' or they explicitly sent in the STDOUT file
    #handle, assume user is outputting to STDOUT
    if($output_file eq '-' || $file_handle eq *STDOUT)
      {
	debug({LEVEL => -1},"Accepting output file handle(1): [STDOUT]",
	      ($file_handle eq *STDOUT ? '' :
	       " in leiu of [$file_handle], since no outfile provided"),".");
	debug({LEVEL=>-1},"Actually selecting STDOUT");
        select(STDOUT) if($select);

	#Reject/ignore the handle that was passed in.  STDOUT will be opened
	#instead
	if($file_handle ne *STDOUT)
	  {
	    ##TODO: See requirement #312
	    open($file_handle,'>>/dev/stdout');
	    #open(STDOUT,'>>/dev/stdout');
	    $rejected_out_handles->{$file_handle}->{CURFILE} = 'STDOUT';
	    $rejected_out_handles->{$file_handle}->{QUIET}   = !$local_verbose;
	    $rejected_out_handles->{$file_handle}->{FILES}->{STDOUT} = 0;
	  }

        #If this is the first time encountering the STDOUT open
        if(!defined($open_out_handles) ||
           !exists($open_out_handles->{*STDOUT}))
          {
            verbose('[STDOUT] Opened for all output.') if($local_verbose);

            #Store info. about the run as a comment at the top of the output
            #file if STDOUT has been redirected to a file and it wasn't already
	    #output via processCommandLine.  processCommandLine does it is the
	    #global $header variable is true.  If it's false, but the local
	    #version of the header variable was explicitly supplied, then print
	    #the header here
            if(!isStandardOutputToTerminal() && ($local_header && !$header))
              {
		my $tfh = (defined($file_handle) ? $file_handle : *STDOUT);
		print $tfh (getHeader());
	      }
          }

	$file_handle = *STDOUT;

	$open_out_handles->{$file_handle}->{CURFILE} = 'STDOUT';
	$open_out_handles->{$file_handle}->{QUIET}   = !$local_verbose;
	$open_out_handles->{$file_handle}->{SELECT}  = $select;
	$open_out_handles->{$file_handle}->{FILES}->{STDOUT} = 0;
      }
    #else if we're not in append mode and the output file fails the overwrite
    #protection check
    elsif(!isAppendMode($explicit_append,$merge_mode,$file_handle,
			$output_file) &&
	  !checkFile($output_file,undef,$local_quiet,0))
      {
	debug({LEVEL => -1},"Rejecting output file handle(1): ",
	      "[$file_handle].");
	$status = 0;
	$rejected_out_handles->{$file_handle}->{CURFILE} = $output_file;
	$rejected_out_handles->{$file_handle}->{QUIET}   = !$local_verbose;
	$rejected_out_handles->{$file_handle}->{FILES}->{$output_file} = 0;
      }
    #Else if this isn't a dry run and opening the output file fails
    elsif(!$local_dry_run &&
	  !open($file_handle,
		(isAppendMode($explicit_append,$merge_mode,$file_handle,
			      $output_file) ?
		 '>' : '') . ">$output_file"))
      {
	debug({LEVEL => -1},"Rejecting output file handle(2): ",
	      "[$file_handle].");
	#Report an error and iterate if there was an error
	error("Unable to open output file: [$output_file].\n",$!)
          unless($local_quiet);
	$status = 0;
	$rejected_out_handles->{$file_handle}->{CURFILE} = $output_file;
	$rejected_out_handles->{$file_handle}->{QUIET}   = !$local_verbose;
	$rejected_out_handles->{$file_handle}->{FILES}->{$output_file} = 0;
      }
    else
      {
	debug({LEVEL => -2},"Accepting output file handle(2): ",
	      "[$file_handle].");
	$open_out_handles->{$file_handle}->{CURFILE} = $output_file;
	$open_out_handles->{$file_handle}->{QUIET}   = !$local_verbose;
	$open_out_handles->{$file_handle}->{SELECT}  = $select;
	$open_out_handles->{$file_handle}->{FILES}->{$output_file} = 0;

	if($local_dry_run)
	  {
	    my $encompassing_dir = $output_file;
	    $encompassing_dir =~ s/[^\/]+$//;
	    $encompassing_dir =~ s%/%%;
	    $encompassing_dir = '.' unless($encompassing_dir =~ /./);

	    debug({LEVEL => -1},"Pretending to open output file in --dry-run ",
		  "mode");

	    if(-e $output_file && !(-w $output_file))
	      {error("Output file exists and is not writable: ",
		     "[$output_file].") unless($local_quiet)}
	    elsif(-e $encompassing_dir && !(-w $encompassing_dir))
	      {error("Encompassing directory of output file: ",
		     "[$output_file] exists and is not writable.")
                 unless($local_quiet)}
	    else
	      {verbose("[$output_file] Opened output file.")
                 if($local_verbose && $status)}

	    return($status);
	  }

	verbose("[$output_file] Opened output file.")
	  if($local_verbose && $status);

	#Select the output file handle
	select($file_handle) if($select);

	#Store info about the run as a comment at the top of the output
	print $file_handle (getHeader($local_header)) if($local_header);
      }

    #If we succeeded and there was a selection made, clean up other selection
    #states (should only be one, but just to be safe, we'll check all possible)
    if($status && $select)
      {
	#Mark any other file handles as not selected
	map {$open_out_handles->{$_}->{SELECT} = 0}
	  grep {$_ ne $file_handle && $open_out_handles->{$_}->{SELECT}}
	    keys(%{$open_out_handles});
      }

    return($status);
  }

#Globals: $closed_out_handles
sub isAppendMode
  {
    #>0 = append, 0 = no append, <0 = no append first, append subsequently
    my $explicit_append = $_[0];
    my $merge_mode      = $_[1]; #Whether collision mode is 'merge' or not
    my $file_handle     = $_[2];
    my $output_file     = $_[3];

    #If the command line has not been processed and this wasn't an explicit one-
    #off append
    if(!$command_line_stage && !defined($explicit_append))
      {
	warning("isAppendMode called before command line has been processed.");
	processCommandLine();
      }

    if(!defined($merge_mode) || !defined($file_handle) ||
       !defined($output_file))
      {
	error("Invalid parameters sent in.  4 parameters are required.  Only ",
	      "the first one (explicit_append) is allowed to be undefined.");
	quit(-49);
      }

    #Opened (& closed) before
    my $opened_before = defined($closed_out_handles) &&
      exists($closed_out_handles->{$file_handle}) &&
	exists($closed_out_handles->{$file_handle}->{$output_file});

    my $append_mode =
      #This allows the user to over-ride what the programmer may have indicated
      #However it only applies to the first open of a file.
      ($append && !$opened_before) ||
	#Subsequent opens fall back to what the programmer has indicated or...
	(defined($explicit_append) && $explicit_append) ||
	  #what the collision mode is set to (as passed in as $merge_mode)
	  ($merge_mode && $opened_before);

    debug({LEVEL=>-1},"Append mode is [",
	  (defined($append_mode) ? ($append_mode ? 'on' : 'off') : 'undef'),
	  "] for file [$output_file].  Merge mode passed in: [$merge_mode].");

    return($append_mode);
  }

sub closeOut
  {
    my @in = getSubParams([qw(HANDLE)],[qw(HANDLE)],[@_]);
    my $file_handle   = $in[0];
    my $status        = 1;
    my $dry_run       = getVarref('dry_run',1);
    my $local_dry_run = defined($dry_run) ? $dry_run : 0;

    debug({LEVEL => -1},"closeOut called with ",
	  (defined($file_handle) ? $file_handle : 'undef'));

    return($status) unless(defined($file_handle));

    #If we're printing to STDOUT, don't close - just issue a checkpoint message
    if($file_handle eq *STDOUT ||
       #Special case for STDOUT opened via filename '-' using a different
       #handle name
       (exists($rejected_out_handles->{$file_handle}) &&
	$rejected_out_handles->{$file_handle}->{CURFILE} eq 'STDOUT'))
      {
	    debug({LEVEL => -1},"STDOUT Checkpoint.");

	verbose("[STDOUT] Output checkpoint.  ",
		"Time taken: [",markTime(),' Seconds].')
	  if(!exists($open_out_handles->{$file_handle}) ||
	     !$open_out_handles->{$file_handle}->{QUIET} ||
	     (exists($rejected_out_handles->{$file_handle}) &&
	      $rejected_out_handles->{$file_handle}->{CURFILE} eq 'STDOUT'));
      }
    #Else if the file handle is rejected or already closed
    elsif(exists($rejected_out_handles->{$file_handle}) ||
	  (!$local_dry_run && (!defined(fileno($file_handle)) ||
			       tell($file_handle) == -1)))
      {
	$status = 0;

	#If we knew it wasn't open because it was rejected
	if(exists($rejected_out_handles->{$file_handle}))
	  {
	    debug({LEVEL => -1},"Cleaning up rejected handle: ",
		  "[$file_handle].");

	    #Assuming this is from a loop, clean up 'closed/rejected' handles
	    delete($rejected_out_handles->{$file_handle});
	  }
	#Else the file handle closed unexpectedly, so report it
	else
	  {
	    error("File handle [$file_handle] submitted to closeOut",
		  (!exists($open_out_handles->{$file_handle}) ? '' :
		   " for file [$open_out_handles->{$file_handle}->{CURFILE}]"),
		  " was not open",
		  (exists($open_out_handles->{$file_handle}) ?
		   "." : " and is untracked."));
	    debug({LEVEL => -1},"Tracked open file handles: [",
		  join(',',keys(%$open_out_handles)),"].\n",
		  "Tracked rejected file handles: [",
		  join(',',keys(%$rejected_out_handles)),"]\n");

	    if(exists($open_out_handles->{$file_handle}))
	      {
		warning("Untracking previously closed (or unopened) file ",
			"handle: ",
			"[$open_out_handles->{$file_handle}->{CURFILE}].");

		my $selected_handle = select();
		#Confirm that this handle was/is supposed to have been selected
		#before selecting STDOUT - if it actually is selected, but is
		#not tracked as such, then they're doing things manually - do
		#not interfere by selecting STDOUT.
		if($open_out_handles->{$file_handle}->{SELECT} &&
		   $selected_handle eq $file_handle && $selected_handle ne
		   *STDOUT)
		  {
		    #Select standard out
		    select(STDOUT);
		  }

		#Copy the handle info to the closed handles and then delete
		$closed_out_handles->{$file_handle}
		  ->{$open_out_handles->{$file_handle}->{CURFILE}} =
		    {%{$open_out_handles->{$file_handle}}};

		delete($open_out_handles->{$file_handle}->{FILES}
		       ->{$open_out_handles->{$file_handle}->{CURFILE}});
		delete($open_out_handles->{$file_handle}->{CURFILE});
		delete($open_out_handles->{$file_handle}->{QUIET});
		delete($open_out_handles->{$file_handle}->{SELECT});
	      }
	    else
	      {
		my $selected_handle = select();
		#Confirm that this handle is selected before selecting STDOUT
		if($selected_handle eq $file_handle &&
		   $selected_handle ne *STDOUT)
		  {
		    #Select standard out
		    select(STDOUT);
		  }
	      }
	  }
      }
    #Else close the handle
    else
      {
	if(!$local_dry_run)
	  {
	    my $selected_handle_pat = '\*?' . quotemeta(select());

	    #Confirm that this handle was/is selected before selecting STDOUT
	    if($file_handle =~ /^$selected_handle_pat$/ &&
	       $file_handle ne *STDOUT)
	      {
		#Select standard out
		select(STDOUT);
	      }

	    #Close the output file handle
	    close($file_handle);
	  }

	verbose("[$open_out_handles->{$file_handle}->{CURFILE}] Output ",
		"file done.  Time taken: [",markTime(),' Seconds].')
	  if(!exists($open_out_handles->{$file_handle}) ||
	     !$open_out_handles->{$file_handle}->{QUIET});

	#Copy the handle info to the closed handles and then delete
	$closed_out_handles->{$file_handle}
	  ->{$open_out_handles->{$file_handle}->{CURFILE}} =
	    {%{$open_out_handles->{$file_handle}}};

	delete($open_out_handles->{$file_handle}->{FILES}
	       ->{$open_out_handles->{$file_handle}->{CURFILE}});
	delete($open_out_handles->{$file_handle}->{CURFILE});
	delete($open_out_handles->{$file_handle}->{QUIET});
	delete($open_out_handles->{$file_handle}->{SELECT});
      }

    return($status);
  }

#Globals used: $default_stub
sub openIn
  {
    unless($command_line_stage)
      {processCommandLine()}

    my @in = getSubParams([qw(HANDLE FILE QUIET)],
			  [qw(HANDLE FILE)],
			  [@_]);
    my $file_handle   = $in[0];
    my $input_file    = $in[1];
    my $local_quiet   = (scalar(@in) >= 3 && defined($in[2]) ? $in[2] : 0);
    my $status        = 1;     #Returns true if successful or $force > 1
    my $dry_run       = getVarref('dry_run',1);
    my $local_dry_run = defined($dry_run) ? $dry_run : 0;
    my $force         = getVarref('force',1);

    if(!defined($input_file))
      {
	#We will return a bad status, but quietly open /dev/null to allow the
	#programmer to not have to check the return value for non-primary
	#optional files
	$input_file = '/dev/null';
	$status = 0;
      }

    #Open the input file
    if(!open($file_handle,$input_file))
      {
	#Report an error and iterate if there was an error
	error("Unable to open input file: [$input_file].  $!") if($status);

	#If force is supplied less than twice, set status to
	#unsuccessful/false, otherwise pretend everything's OK
	$status = 0 if(!defined($force) || $force < 2);
      }
    else
      {
	verbose('[',($input_file eq '-' ?
		     (defined($default_stub) ? $default_stub : 'STDIN') :
		     $input_file),
		'] Opened input file.') if(!$local_quiet && $status);

	$open_in_handles->{$file_handle}->{CURFILE} = $input_file;
	$open_in_handles->{$file_handle}->{QUIET}   = $local_quiet || !$status;
      }

    return($status);
  }

#Given an open input file handle, returns the name and path of the file
#Returns an empty string if it was not found in the open input handles hash
sub getInHandleFileName
  {
    my @in = getSubParams([qw(HANDLE)],[qw(HANDLE)],[@_]);
    my $handle = $in[0];
    if(defined($open_in_handles) && exists($open_in_handles->{$handle}) &&
       exists($open_in_handles->{$handle}->{CURFILE}) &&
       defined($open_in_handles->{$handle}->{CURFILE}))
      {return($open_in_handles->{$handle}->{CURFILE})}
    return('');
  }

sub getOutHandleFileName
  {
    my @in = getSubParams([qw(HANDLE)],[qw(HANDLE)],[@_]);
    my $handle = $in[0];
    if(defined($open_out_handles) && exists($open_out_handles->{$handle}) &&
       exists($open_out_handles->{$handle}->{CURFILE}) &&
       defined($open_out_handles->{$handle}->{CURFILE}))
      {return($open_out_handles->{$handle}->{CURFILE})}
    return('');
  }

#Globals used: $default_stub
sub closeIn
  {
    my @in = getSubParams([qw(HANDLE)],[qw(HANDLE)],[@_]);
    my $file_handle = $in[0];

    if(!defined($file_handle))
      {
	error("File handle sent in undefined.");
	return(undef);
      }

    #Close the input file handle
    close($file_handle);

    verbose('[',($open_in_handles->{$file_handle}->{CURFILE} eq '-' ?
		 (defined($default_stub) ? $default_stub : 'STDIN') :
		 $open_in_handles->{$file_handle}->{CURFILE}),
	    '] Input file done.  Time taken: [',markTime(),
	    ' Seconds].') if(!exists($open_in_handles->{$file_handle}) ||
			     !$open_in_handles->{$file_handle}->{QUIET});

    delete($open_in_handles->{$file_handle});
  }

#Copies an N-dimensional array of scalars.  DO NOT USE THIS SUB.  IT HAS A BUG
#THAT CANNOT BE FIXED.  SEE COMMENT FROM 6/28/2019 IN ISSUE 341.  OTHER CODE
#THAT HAS USED THIS SUB HAS WORKED AROUND THE ISSUE. IT IS ONLY RELIABLE WHEN
#CALLED IN SCALAR CONTEXT WITH AN ARRAY REFERENCE AS AN ARGUMENT
#Note: Creates a surrounding reference to the submitted array if called in
#scalar context and there are more than 1 elements in the parameter array
sub copyArray
  {
    if(scalar(grep {ref(\$_) ne 'SCALAR' && ref($_) ne 'ARRAY'} @_))
      {
	error("Invalid argument - not an array of scalars.");
	quit(-50);
      }
    my(@copy);
    foreach my $elem (@_)
      {push(@copy,(defined($elem) && ref($elem) eq 'ARRAY' ?
		   [copyArray(@$elem)] : $elem))}
    debug({LEVEL => -99},"Returning array copy of [",
	  join(',',map {defined($_) ? $_ : 'undef'} @copy),"].");
    return(wantarray ? @copy : (scalar(@copy) > 1 ? [@copy] : $copy[0]));
  }

#Note, getUserDefaults is called from inside init() when initializing the
#--save-args option, which means that setDefaults() has not yet been called and
#$defaults_dir cannot have been updated, thus the defaults checked/returned will
#not be correct.  Thus this method needs to be called again, sometime between
#the command line being processed and the usage being printed.  After that, the
#applyOptionAddendums must be called.
#Globals used: $defaults_dir
sub getUserDefaults
  {
    my @in = getSubParams([qw(REMOVE_QUOTES)],[],[@_]);
    my $remove_quotes = defined($in[0]) ? $in[0] : 0;
    my $script        = getScriptName();
    my $defaults_file = (defined($defaults_dir) ?
			 $defaults_dir : (sglob('~/.rpst',1))[0]) . "/$script";
    my $return_array  = [];

    if(open(DFLTS,$defaults_file))
      {
        # Each line is either a flag or arguments to that flag
	@$return_array = map {chomp;if($remove_quotes){s/^['"]//;s/["']$//}
			      join(' ',grep {defined($_)} sglob($_,1))} <DFLTS>;
	close(DFLTS);
      }
    elsif(-e $defaults_file)
      {error("Unable to open user defaults file: [$defaults_file].  $!")}

    debug({LEVEL=>-2},"User defaults retrieved from [$defaults_file]: [",
	  join(' ',@$return_array),"].");

    return(wantarray ? @$return_array : $return_array);
  }

#Assumes that options have already been read in
#Globals used: $defaults_dir
sub saveUserDefaults
  {
    my @in     = getSubParams([qw(ARGV)],[],[@_]);
    my $argv   = $in[0]; #OPTIONAL
    my $status = 1;

    my $use_as_default = getVarref('save_args',1);

    return($status) if(!defined($use_as_default) || !$use_as_default);

    #Grab defaults from getCommand, because it re-adds quotes & other niceties
    if(!defined($argv))
      {
	$argv = [getCommand(0,1)];
	#Remove the script name
	shift(@$argv);
      }

    my $orig_defaults = getUserDefaults();

    #Determine original and new default run mode
########## I should add a 'flag used' key to the mutual_params for each DEFAULT_PRG, DEFAULT_USR, and SUPPLIED values.  I can then use the default logic below to set orig_mode
    my $orig_mode = getDefaultRunMode();
########## 'flag used' for SUPPLIED can be used to set new_mode
    my $new_mode  = ($usage_lookup->{help}->{SUPPLIED} ? 'help' :
		     ($usage_lookup->{usage}->{SUPPLIED} ? 'usage' :
		      ($usage_lookup->{run}->{SUPPLIED} ? 'run' :
		       ($usage_lookup->{dry_run}->{SUPPLIED} ? 'dry_run' :
		        $orig_mode))));

    #The current actual ready status is what the new default ready status will
    #be, but the current default ready status is what the old default ready
    #status was untill now
    my $ready         = getRunStatus(0);
    my $orig_ready    = getRunStatus(1);

    my $script        = getScriptName();
    my $defaults_file = (defined($defaults_dir) ?
			 $defaults_dir : (sglob('~/.rpst',1))[0]) . "/$script";

    #Remove disallowed options (assumes bool).  Run mode and save-args.
    my $remove_flags =
      {map {my $n=$_;map {$_ => 1} @{$usage_lookup->{$n}->{OPTFLAGS}}}
       qw(save_args)};
    my $save_argv = [grep {!exists($remove_flags->{$_})} @$argv];

    debug({LEVEL => -99},"Defaults dir: [",
	  (defined($defaults_dir) ? $defaults_dir : 'undef'),"].");

    #If the defaults directory does not exist and mkdirs returns an error
    if(defined($defaults_dir) && !(-e $defaults_dir) && !mkdirs($defaults_dir))
      {
	error("Unable to create defaults directory: [$defaults_dir].  $!");
	$status = 0;
      }
    else
      {
	if(open(DFLTS,">$defaults_file"))
	  {
	    print DFLTS (join("\n",@$save_argv));
	    close(DFLTS);
	  }
	else
	  {
	    error("Unable to write to defaults file: [$defaults_file].  $!");
	    $status = 0;
	  }
      }

    if($status)
      {
	print("Old user defaults: [",join(' ',@$orig_defaults),"].\n",
	      "New user defaults: [",join(' ',getUserDefaults()),"].\n");

	my $changing_mode = defined($new_mode) && $orig_mode ne $new_mode;

	my $msg = "will be added-to/remain-in the usage output.\n";

	if($changing_mode)
	  {print("Changing default run mode from [$orig_mode] to [$new_mode].",
		 "\n")}

	if($changing_mode || $orig_ready != $ready)
	  {
	    if($ready == 1) #Required opts without defaults exist
	      {
		if($new_mode eq 'help')
		  {
		    print("  --dry-run $msg");
		    print("  --usage   $msg");
		  }
		elsif($new_mode eq 'usage')
		   {
		     print("  --dry-run $msg");
		     print("  --help    $msg");
		   }
		elsif($new_mode eq 'run')
		  {
		    print("  --dry-run $msg");
		    print("  --usage   $msg");
		    print("  --help    $msg");
		  }
		elsif($new_mode eq 'dry-run')
		  {
		    print("  --run   $msg");
		    print("  --usage $msg");
		    print("  --help  $msg");
		  }
	      }
	    else #No ready = 0  - required opts or all have defaults
	      {  #Or ready = -1 - required opts exist, but cannot determine def
		if($new_mode eq 'help')
		  {
		    print("  --run     $msg");
		    print("  --usage   $msg");
		    print("  --dry-run $msg");
		    print("Note: To run with no options other than the ",
			  "defaults, given that there are either no required ",
			  "options or all required options have default ",
			  "values, you must supply (at least) --run or ",
			  "--dry-run.\n");
		  }
		elsif($new_mode eq 'usage')
		  {
		    print("  --run     $msg");
		    print("  --help    $msg");
		    print("  --dry-run $msg");
		    print("Note: To run with no options other than the ",
			  "defaults, given that there are either no required ",
			  "options or all required options have default ",
			  "values, you must supply (at least) --run or ",
			  "--dry-run.\n");
		  }
		elsif($new_mode eq 'run')
		  {
		    print("  --dry-run $msg");
		    print("  --usage   $msg");
		    print("  --help    $msg");
		  }
		elsif($new_mode eq 'dry-run')
		  {
		    print("  --run     $msg");
		    print("  --usage   $msg");
		    print("  --help    $msg");
		  }
	      }

	    if($ready == -1) #Required opts exist, but cannot determine def
	      {
		warning("Unable to determine if custom options have default ",
			"values or not.  This is a current limitation of ",
			"CommandLineInterface.  This issue will be addressed ",
			"in requirement number 214.  Until then, options ",
			"with unknown default value status will be assumed ",
			"to have a value.");
	      }
	  }

	#Report if the new user default implicitly over-rides a programmer
	#default and report it
	my $overrides = {};
	foreach my $opth (grep {$_->{SUPPLIED} &&
				  exists($exclusive_lookup->{$_->{OPTION_ID}})}
			  @$usage_array)
	  {
	    #For each mutex set that this optin belongs to
	    foreach my $mutexset (map {$exclusive_options->[$_]}
				  keys(%{$exclusive_lookup
					   ->{$opth->{OPTION_ID}}}))
	      {
		#For each option (hash) that's mutex with an option being set as
		#a user default which was not supplied, is not this option, and
		#has a programmer default mark it as an over-ride
		foreach my $mtxoh (map {$usage_array->[$_]}
				   grep {my $h = $usage_array->[$_];
					 $_ != $opth->{OPTION_ID} &&
					   !$h->{SUPPLIED} &&
					     hasValue($h->{OPTTYPE},
						      $h->{DEFAULT_PRG})}
				   @$mutexset)
		  {push(@{$overrides->{$mtxoh->{OPTION_ID}}},
			$opth->{OPTION_ID})}
	      }
	  }

	#If any programmer defaults have been implicitly over-ridden
	if(scalar(keys(%$overrides)))
	  {
	    print("Note, the following options' hard-coded default values ",
		  'have been over-ridden by the mutually exclusive options ',
		  "supplied:\n");

	    foreach my $oroid (keys(%$overrides))
	      {
		print("  $usage_array->[$oroid]->{OPTFLAG_DEF} (overridden by ",
		      (scalar(@{$overrides->{$oroid}}) > 1 ?
		       '[' . join(',',map {$usage_array->[$_]->{OPTFLAG_DEF}}
				  @{$overrides->{$oroid}}) . ']' :
		       $usage_array->[$overrides->{$oroid}->[0]]
		       ->{OPTFLAG_DEF}),")\n");
	      }
	  }
      }

    return($status);
  }

sub getHeader
  {
    my $header = defined($_[0]) ? $_[0] : getVarref('header',1,0);

    return('') if(!defined($header) || !$header);

    debug({LEVEL => -99},"getHeader called.");

    my $version_str = getVersion(1,2);
    $version_str =~ s/\n(?!#|\z)/\n#/sg;

    my $user = exists($ENV{USER}) ? $ENV{USER} : `whoami`;
    chomp($user);
    my $host = exists($ENV{HOST}) ? $ENV{HOST} : `hostname`;
    chomp($host);
    my $pwd = exists($ENV{PWD}) ? $ENV{PWD} : (exists($ENV{CWD}) ? $ENV{CWD} :
					       `pwd`);
    chomp($pwd);

    $header_str = "$version_str\n" .
      "#User: $user\n" .
	'#Time: ' . scalar(localtime($^T)) . "\n" .
	  "#Host: $host\n" .
	    "#PID: $$\n" .
	      "#Directory: $pwd\n" .
		'#Command: ' . scalar(getCommand(1)) . "\n\n";

    return($header_str);
  }

#This sub takes an array reference (which should initially point to an empty
#array) and a reference to an array containing a series of numbers indicating
#the number of available items to choose from for each position.  It returns,
#in order, an array (the size of the second argument (pool_sizes array))
#containing an as-yet unseen combination of values where each value is selected
#from 1 to the pool size at that position.  E.g. If the pool_sizes array is
#[2,3,1], the combos will be ([1,1,1],[1,2,1],[1,3,1],[2,1,1],[2,2,1],[2,3,1])
#on each subsequent call.  Returns undef when all combos have been generated
sub GetNextIndepCombo
  {
    #Read in parameters
    my $combo      = $_[0];  #An Array of numbers
    my $pool_sizes = $_[1];  #An Array of numbers indicating the range for each
                             #position in $combo

    if(ref($combo) ne 'ARRAY' || scalar(grep {/\D/} @$combo))
      {
	error("The first argument must be an array reference to an array of ",
	      "integers.");
	return(0);
      }
    elsif(ref($pool_sizes) ne 'ARRAY' || scalar(grep {/\D/} @$pool_sizes))
      {
	error("The second argument must be an array reference to an array of ",
	      "integers.");
	return(0);
      }

    my $set_size   = scalar(@$pool_sizes);

    #Initialize the combination if it's empty (first one) or if the set size
    #has changed since the last combo
    if(scalar(@$combo) == 0 || scalar(@$combo) != $set_size)
      {
	#Empty the combo
	@$combo = ();
	#Fill it with zeroes
        @$combo = (split('','0' x $set_size));
	#Return true
        return(1);
      }

    my $cur_index = $#{$combo};

    #Increment the last number of the combination if it is below the pool size
    #(minus 1 because we start from zero) and return true
    if($combo->[$cur_index] < ($pool_sizes->[$cur_index] - 1))
      {
        $combo->[$cur_index]++;
        return(1);
      }

    #While the current number (starting from the end of the combo and going
    #down) is at the limit and we're not at the beginning of the combination
    while($combo->[$cur_index] == ($pool_sizes->[$cur_index] - 1) &&
	  $cur_index >= 0)
      {
	#Decrement the current number index
        $cur_index--;
      }

    #If we've gone past the beginning of the combo array
    if($cur_index < 0)
      {
	@$combo = ();
	#Return false
	return(0);
      }

    #Increment the last number out of the above loop
    $combo->[$cur_index]++;

    #For every number in the combination after the one above
    foreach(($cur_index+1)..$#{$combo})
      {
	#Set its value equal to 0
	$combo->[$_] = 0;
      }

    #Return true
    return(1);
  }

#This method returns 3 arrays.  It creates an array of output file names, an
#array of output file stubs from the input file names and output directories
#(in case the coder wants to handle output file name construction on their
#own), and a skips array denoting which sets should be skipped because the
#output file already exists.  It checks all the future output files for
#possible overwrite conflicts and checks for existing output files.  It quits
#if it finds a conflict.  It uses the user_collide_modes array to determine
#whether a conflict is actually a conflict or just should be appended to when
#encountered.  If the collision mode is rename, it tries to avoid conflicting
#non-merging output files by joining the input file names with delimiting dots
#(in the order supplied in the stubs array).  It smartly compounds with a
#single file name if that file name is unique, otherwise, it joins all file
#names.
#ASSUMES that user_collide_modes 2D array is properly populated.
sub makeCheckOutputs
  {
    my $stub_sets           = copyArray($_[0]);#REQUIRD 2D array of stub combos
    my $suffixes            = $_[1]; #OPTIONAL (Requires $_[2])
    my $stub_source_hash    = $_[2];
    my $skip_existing       = getVarref('skip',1);
    my $append              = getVarref('append',1);
    my $DEBUG               = getVarref('debug',1);

    my $outfile_source_hash = {};
    my $index_uniq          = [map {{}} @{$stub_sets->[0]}]; #Array of hashes
    my $is_index_unique     = [map {1} @{$stub_sets->[0]}];
    my $delim               = '.';

    debug({LEVEL => -2},"Called.");

    if($DEBUG < 0 && eval('use Data::Dumper;1'))
      {
	my $sd = '';
	my $td = '';
	my $cd = '';
	eval('use Data::Dumper;$sd = Dumper($suffixes);1');
	eval('use Data::Dumper;$td = Dumper($stub_sets);1');
	debug({LEVEL=>-99},"Stub sets:\n$td\nSuffixes:\n",
	      "$sd\nCollide modes:\n$cd\n");
      }

    #Build the is_index_unique array
    foreach my $stub_set (@$stub_sets)
      {
	foreach my $type_index (0..$#{$stub_set})
	  {
	    if($#{$index_uniq} < $type_index)
	      {
		error("Critical internal error: type index too big.");
		quit(-53);
	      }
	    #Only interested in stubs with defined values
	    if(defined($stub_set->[$type_index]))
	      {
		if(exists($index_uniq->[$type_index]
			  ->{$stub_set->[$type_index]}))
		  {
		    $is_index_unique->[$type_index] = 0;
		    debug({LEVEL => -99},"Index [$type_index] is not unique");
		  }
		$index_uniq->[$type_index]->{$stub_set->[$type_index]} = 1;
	      }
	    else
	      {$is_index_unique->[$type_index] = 0}
	  }
      }

    #Find the first unique index with defined values if one exists.
    #We'll use it to hopefully make other stubs unique
    my($first_unique_index);
    foreach my $index (0..$#{$is_index_unique})
      {
	if($is_index_unique->[$index])
	  {
	    $first_unique_index = $index;
	    debug({LEVEL => -2},"Unique index: [$index].");
	    last;
	  }
      }

    my $outfiles_sets = [];    #This will be the returned 3D outfiles array
    my $unique_hash   = {};    #This will be the check for outfile uniqueness
                               #$unique_hash->{$outfile}->{$type}->{$mrgmode}++
                               #Quit if any file has multiple types or
                               #$unique_hash->{$outfile}->{$type}->{error} > 1

    #For each stub set
    foreach my $stub_set (@$stub_sets)
      {
	push(@$outfiles_sets,[]);
	my $saved_stub_set = copyArray($stub_set);

	#For each file-type/stub index
	foreach my $type_index (0..$#{$stub_set})
	  {
	    push(@{$outfiles_sets->[-1]},[]);

	    debug({LEVEL => -2},"Index $type_index is ",
		  ($is_index_unique->[$type_index] ? '' : 'not '),"unique.");

	    my $name          = $stub_set->[$type_index];
	    my $compound_name = $stub_set->[$type_index];

	    #If a collide mode is set for this infile type, there exists a
	    #rename collide mode for a suffix under this input file type, the
	    #stubs @ this index are not unique, AND this stub is defined,
	    #compound the name
	    if(defined($file_indexes_to_usage) &&
	       exists($file_indexes_to_usage->{$type_index}) &&
	       defined($file_indexes_to_usage->{$type_index}) &&
	       scalar(grep {defined($_) && $_ eq 'rename'}
		      map {$usage_array->[$_]->{COLLIDE_MODE}}
		      values(%{$file_indexes_to_usage->{$type_index}})) &&
	       !$is_index_unique->[$type_index] &&
	       defined($stub_set->[$type_index]))
	      {
		debug({LEVEL => -2},
		      "Creating compund name for index $type_index.");
		my $stub = $stub_set->[$type_index];
		$stub =~ s/.*\///;
		my $dir = $stub_set->[$type_index];
		unless($dir =~ s/^(.*\/).*/$1/)
		  {$dir = ''}

		if(defined($first_unique_index))
		  {
		    my $unique_name = $stub_set->[$first_unique_index];
		    $unique_name =~ s/.*\///;

		    #Compound the stub with the unique one in index order

		    #For backward compatibility, change stub in-place
		    if(!defined($file_indexes_to_usage))
		      {$stub_set->[$type_index] = $dir .
			 ($type_index < $first_unique_index ?
			  $stub . $delim . $unique_name :
			  $unique_name . $delim . $stub)}

		    $compound_name = $dir .
		      ($type_index < $first_unique_index ?
		       $stub . $delim . $unique_name :
		       $unique_name . $delim . $stub);
		  }
		else
		  {
		    #Don't worry if not enough files exist to create a unique
		    #compound name.  Uniqueness is checked after compounding.

		    my $tmp_stub = $stub_set->[0];
		    $tmp_stub =~ s/(.*\/).*/$1/;

		    #For backward compatibility, change stub in-place
		    if(!defined($file_indexes_to_usage))
		      {$stub_set->[$type_index] =
			 $tmp_stub . join($delim,
					  map {s/.*\///;$_} grep {defined($_)}
					  @$saved_stub_set)}

		    $compound_name =
		      $tmp_stub . join($delim,
				       map {s/.*\///;$_} grep {defined($_)}
				       @$saved_stub_set);
		  }
		debug({LEVEL => -2},"New stub: [$compound_name].");
	      }

	    debug({LEVEL => -2},"Creating file names.");
	    #Create the file names using the suffixes and compound name (though
	    #note that the compound name might not be compounded)
	    #If the stub is defined
	    if(defined($stub_set->[$type_index]))
	      {
		#If suffixes is defined & there are suffixes for this index
		if(defined($suffixes) && $#{$suffixes} >= $type_index &&
		   defined($suffixes->[$type_index]) &&
		   scalar(@{$suffixes->[$type_index]}))
		  {
		    my $cnt = 0;
		    #For each suffix available for this file type
		    foreach my $suff_index (0..$#{$suffixes->[$type_index]})
		      {
			my $suffix = $suffixes->[$type_index]->[$suff_index];
			my $uindex =
			  $file_indexes_to_usage->{$type_index}->{$suff_index};
			my $usg_hash = $usage_array->[$uindex];
			my $partner_defined =
			  isTagteamPartnerDefined($usg_hash);

			#Don't add standard out if a suffix has been defined
			#for either this outfile type or of a possible tagteam
			#partner outfile type
			if(!isSuffixDefined($type_index,$suff_index) &&
			   ($partner_defined || !$usg_hash->{PRIMARY}))
			  {
			    debug({LEVEL => -99},"Suffix is not defined.");
			    push(@{$outfiles_sets->[-1]->[$type_index]},
				 $suffix);
			    $cnt++;
			    next;
			  }
			elsif(!isSuffixDefined($type_index,$suff_index) &&
			      !$partner_defined && $usg_hash->{PRIMARY})
			  {
			    #When no suffix is supplied, yet the output type is
			    #a primary type, set the output file name to dash
			    #('-') to indicate output should go to STDOUT
##TODO: This should really also be checking for merge collision mode and erroring out if there is more than one output file going to STDOUT and the mode is not merge.  See requirement 11b.
			    push(@{$outfiles_sets->[-1]->[$type_index]},'-');
			    $cnt++;
			    next;
			  }
			elsif(!defined($suffix))
			  {
			    error('Internal error 44: Should not have gotten ',
				  'here.');
			    quit(-5);
			  }

			my $usg_index    = $file_indexes_to_usage->{$type_index}
			  ->{$cnt};
			my $uhash        = $usage_array->[$usg_index];
			my $collide_mode = $uhash->{COLLIDE_MODE};

			#Concatenate the possibly compounded stub and suffix to
			#the new stub set
			push(@{$outfiles_sets->[-1]->[$type_index]},
			     ($collide_mode eq 'rename' ?
			      $compound_name . $suffix : $name . $suffix));

			$unique_hash
			  ->{$outfiles_sets->[-1]->[$type_index]->[-1]}
			    ->{$type_index}->{$collide_mode}++;

			$outfile_source_hash
			  ->{$outfiles_sets->[-1]->[$type_index]->[-1]} =
			    $stub_source_hash->{$stub_set->[$type_index]};

			$cnt++;
		      }
		  }
	      }
	    else
	      {
		if(defined($suffixes->[$type_index]))
		  {
		    #The stub is added to the new stub set unchanged
		    #For each suffix available for this file type
		    foreach my $suff_index (0..$#{$suffixes->[$type_index]})
		      {
			my $suffix = $suffixes->[$type_index]->[$suff_index];
			debug({LEVEL => -99},"Suffix is not defined 2.  ",
			      "Suffix: [",(defined($suffix) ?
					   $suffix : 'undef'),"].");
			my $usg_index =
			  $file_indexes_to_usage->{$type_index}->{$suff_index};
			my $usg_hash = $usage_array->[$usg_index];
			#If the suffix is not defined, but it is primary, add
			#STDOUT to the outfile stubs.  Otherwise, the stub set
			#is not even defined, so add undef, just so we have a
			#placeholder (i.e. can guarantee that a place exists in
			#the suffix array for every suffix that was defined by
			#the programmer)
			push(@{$outfiles_sets->[-1]->[$type_index]},
			     (!isSuffixDefined($type_index,$suff_index) &&
			      $usg_hash->{PRIMARY} ? '-' : undef));
		      }
		  }
	      }
	  }
      }

    #Let's make sure that the suffixes for each type are unique
    if(defined($suffixes))
      {
	debug({LEVEL => -2},"Checking suffixes.");
	my $unique_suffs = {};   #$unique_suffs->{$type}->{$suffix}++
	                         #Quit if $unique_suffs->{$type}->{$suffix} > 1
	my $dupe_suffs   = {};
	foreach my $type_index (0..$#{$suffixes})
	  {
	    foreach my $suffix (grep {defined($_)} @{$suffixes->[$type_index]})
	      {
		$unique_suffs->{$type_index}->{$suffix}++;
		if($unique_suffs->{$type_index}->{$suffix} > 1)
		  {$dupe_suffs->{$type_index + 1}->{$suffix} = 1}
	      }
	  }

	if(scalar(keys(%$dupe_suffs)))
	  {
	    my @report_errs = map {my $k = $_;"$k:" .
				     join(",$k:",keys(%{$dupe_suffs->{$k}}))}
	      keys(%$dupe_suffs);
	    @report_errs = (@report_errs[0..8],'...')
	      if(scalar(@report_errs) > 10);
	    error("The following input file types have duplicate output file ",
		  "suffixes (type:suffix): [",join(',',@report_errs),"].  ",
		  "This is a predicted overwrite situation that can only be ",
		  "surpassed by providing unique suffixes for each file type ",
		  "or by using --force combined with either --overwrite or ",
		  "--skip.");
	    quit(-47);
	  }
      }

    my $skip_sets = [map {0} (0..$#{$outfiles_sets})];

    #Now we shall check for uniqueness using unique_hash and the suffixes
    #$unique_hash->{$outfile}->{$type}->{$mrgmode}++
    #Quit if any file has multiple types or
    #$unique_hash->{$outfile}->{$type}->{error} > 1
    if(#The unique hash is populated
       scalar(keys(%$unique_hash)) &&
       #If any file has multiple types
       scalar(grep {scalar(keys(%$_)) > 1} values(%$unique_hash)))
      {
	my @report_errs = grep {scalar(keys(%{$unique_hash->{$_}})) > 1}
	  keys(%$unique_hash);
	@report_errs = (@report_errs[0..8],'...')
	  if(scalar(@report_errs) > 10);
	error("The following output files have conflicting file names from ",
	      "different input file types: [",join(',',@report_errs),"].  ",
	      "Please make sure the corresponding similarly named input ",
	      "files output to different directories.  This error may be ",
	      "circumvented by --force and either --overwrite or ",
	      "--skip, but it is heavily discouraged - only use for testing.");
	quit(-45);
      }
    #Quit if $unique_hash->{$outfile}->{$type}->{error} > 1 or
    #$unique_hash->{$outfile}->{$type}->{rename} (i.e. compounded names are
    #not unique)
    elsif(#The unique hash is populated
	  scalar(keys(%$unique_hash)) &&
	  #There exist error or rename modes
	  scalar(grep {defined($_) && ($_ eq 'error' || $_ eq 'rename')}
		 map {my $ai = $_;map {$usage_array->[$_]->{COLLIDE_MODE}}
			values(%$ai)}
		 grep {defined($_)} values(%$file_indexes_to_usage)) &&
	  #There exists an output filename duplicate for an error mode outfile
	  scalar(grep {$_ > 1} map {values(%$_)}
		 grep {exists($_->{error}) || exists($_->{rename})}
		 map {values(%$_)} values(%$unique_hash)))
      {
	my $all_collide_modes_str = '(' .
	  join('),(',
	       map {my $ai = $_;defined($ai) ?
		      join(',',map {$usage_array->[$_]->{COLLIDE_MODE}}
			   values(%$ai)) :
			     'undef'} values(%$file_indexes_to_usage)) . ')';
	my @report_errs =
	  grep {my $k = $_;scalar(grep {(exists($_->{error}) &&
					 $_->{error} > 1) ||
					   (exists($_->{rename}) &&
					    $_->{rename} > 1)}
				  values(%{$unique_hash->{$k}}))}
	    keys(%$unique_hash);
	@report_errs = (@report_errs[0..2],'...')
	  if(scalar(@report_errs) > 3);
	error("Output file name conflict",
	      (scalar(@report_errs) > 1 ? 's' : '')," detected: [",
	      join(',',@report_errs),"].  ",
	      (scalar(@report_errs) > 1 ? 'These files are' : 'This file is'),
	      " generated by multiple input files of the same name: [",
	      join(',',map {'(' .
			      join(',',keys(%{$outfile_source_hash->{$_}})) .
				") -> $_"} grep {$_ ne '...'} @report_errs),
	      "].",
	      {DETAIL =>
	       join('',("Please make sure each input file (from a different ",
			"source directory) outputs to a different output ",
			"directory and that the input file names are not the ",
			"same.  Also, when submitting multiple types of ",
			"input files, there must be a different output file ",
			"associated with each combination of input files.  ",
			"Check your input files for duplicates and that your ",
			"output file type is associated with input files in ",
			"a ONETOONE relationship.  Behavior upon file name ",
			"conflict detection is determined by the collision ",
			"mode set when the output file type was created (see ",
			"addOutfileOption, addOutfileSuffixOption, and ",
			"addOutfileTagteamOption).  At least one of the ",
			"collision modes for the affected files: [",
			"$all_collide_modes_str] is set to cause an ",
			"error if multiple input files output to the same ",
			"output file.  This error may be circumvented by ",
			"setting the COLLISIONMODE to either 'merge' or ",
			"'rename' via either those methods or by changing ",
			"the default using setDefaults if its not set in one ",
			"of those methods.  Note, 'rename' will only resolve ",
			"conflicts involving multiple types of input files.  ",
			"It will not rename input files that have the same ",
			"name but reside in different source directories, ",
			"even if multiple file types' renamed files ",
			"conflict.  To temporarily change the collision mode ",
			"globally for all output file types, supply ",
			"`--collision-mode VALUE`, where VALUE={error,merge,",
			"rename}.  To force past this error without changing ",
			"the collision mode, use --force and either ",
			"--overwrite or --skip, but this is heavily ",
			"discouraged - only use for testing."))});

	#An exit code of -1 will quit even if --force is supplied.  --force
	#is intended to over-ride programmatic errors.  --overwrite is
	#intended to over-ride existing files.
	quit(-1);
      }
    #Quit if any of the outfiles created already exist
    else
      {
	my(%exist);
	foreach my $i (0..$#{$outfiles_sets})
	  {
	    my $outfile_arrays_combo = $outfiles_sets->[$i];
	    foreach my $outfile_array (@$outfile_arrays_combo)
	      {
		foreach my $outfile (@$outfile_array)
		  {
		    unless(checkFile($outfile,undef,1,0))
		      {
			$exist{$outfile}++;
			$skip_sets->[$i] = 1 unless($append);
		      }
		  }
	      }
	  }

	if(scalar(keys(%exist)))
	  {
	    my $report_exist = [scalar(keys(%exist)) > 10 ?
				((keys(%exist))[0..8],'...') : keys(%exist)];
	    if($skip_existing)
	      {warning("Processing for these pre-existing output files will ",
		       "be skipped: [",join(',',@$report_exist),"].")}
	    elsif($append)
	      {
		debug({LEVEL => -1},"These pre-existing output files will be ",
		      "appended to: [",join(',',@$report_exist),"].");
		if($dry_run)
		  {warning("NOTE: There are pre-existing output files will ",
			   "be appended to: [",join(',',@$report_exist),"].")}
	      }
	    else
	      {
		error("Output files exist: [",join(',',@$report_exist),
		      "].  Use --overwrite, --append, or --skip to continue.");
		quit(-10);
	      }
	  }
      }

    #If no suffixes were provided, the outfile_sets will essentially be the
    #same as the stubs, only with subarrays inserted.
    return($outfiles_sets,$stub_sets,$skip_sets);
  }

sub getMatchedSets
  {
    my $array = $_[0]; #3D array
    my $force = getVarref('force',1);

    debug({LEVEL => -99},"getMatchedSets called");

    #First, create a list of hashes that contain the effective and actual
    #dimension size and the file type index, as well as the 2D array of file
    #names themselves.  The number of rows is the actual and effective first
    #dimension size and the the number of columns is the second dimension size.
    #The number of columns may be variable.  If the number of columns is the
    #same for every row, the effective and actual second dimension size is the
    #same.  If they are different, the actual second dimension size is a series
    #of number of columns for each row and the effective dimension size is as
    #follows: If The numbers of columns across all rows is either 1 or N, the
    #effective second dimension size is N, else it is the series of numbers of
    #columns across each row (a comma-delimited string).  If an array is empty
    #or contains undef, it will be treated as 1x1.

    #When the effective second dimension size is variable, but only contains
    #sizes of 1 & N, then the first element of each row is copied until all
    #rows have N columns.

    #Create an array of hashes that store the dimension sizes and 2D array data
    my $type_container = [];
    #For each file type index
    foreach my $type_index (0..$#{$array})
      {
	#If any rows are empty, create a column containing a single undef
	#member
	foreach my $row (@{$array->[$type_index]})
	  {push(@$row,undef) if(scalar(@$row) == 0)}
	if(scalar(@{$array->[$type_index]}) == 0)
	  {push(@{$array->[$type_index]},[undef])}

	my $first_dim_size = scalar(@{$array->[$type_index]});

	#A hash tracking the number of second dimension sizes
	my $sd_hash = {};

	#A list of the second dimension sizes
	my $second_dim_sizes = [map {my $s=scalar(@$_);$sd_hash->{$s}=1;$s}
				@{$array->[$type_index]}];

	#Ignore second dimension sizes of 1 in determining the effective second
	#dimension size
	delete($sd_hash->{1});

	#Grab the first second dimension size (or it's 1 if none are left)
	my $first_sd_size =
	  scalar(keys(%$sd_hash)) == 0 ? 1 : (keys(%$sd_hash))[0];

	#The effective second dimension size is the first one from above if
	#there's only 1 of them, otherwise it's variable and stored as a comma-
	#delimited string.  Note, if it's a mix of 1 & some dimension N, the
	#effective second dimension size is N.
	my($effective_sd_size);
	if(scalar(keys(%$sd_hash)) == 1 || scalar(keys(%$sd_hash)) == 0)
	  {$effective_sd_size = $first_sd_size}
	else
	  {$effective_sd_size = join(',',@$second_dim_sizes)}

	debug({LEVEL => -98},"Type [$type_index] is $first_dim_size x ",
	      "$effective_sd_size or [$first_dim_size] x ",
	      "[@$second_dim_sizes]");

	#Change each 2D file array into a hash which stores its type index,
	#actual row size(s), effective row sizes, actual column sizes,
	#effective column sizes, and the actual 2D array of file names
	push(@$type_container,
	     {AF   => [$first_dim_size],       #Actual first dimension sizes
	      AS   => $second_dim_sizes,       #Actual second dimension sizes
	      EF   => $first_dim_size,         #Effective first dimension size
	      ES   => $effective_sd_size,      #Effective second dimension size
	      TYPE => $type_index,             #Type of files contained
	      DATA => scalar(copyArray($array->[$type_index]))});
	                                       #2D array of file names
      }

    #Next, we transpose any arrays based on the following criteria.  Assume FxS
    #is the effective first by second dimension sizes and that the type
    #container array is ordered by precedence(/type).  The first array will not
    #be transposed to start off and will be added to a new synced group.  For
    #each remaining array, if effective dimensions match an existing synced
    #group (in order), it is added to that synced group.  If it matches none,
    #it is the first member of a new synced group.  A group's dimensions match
    #if they are exactly the same, if they are reversed but exactly the same,
    #or 1 dimension is size 1 and the other dimension is not size 1 and matches
    #either F or S.  If a matching array's dimensions are reversed (i.e. F1xS1
    #= S2xF2 or (F1=1 and S1!=1 and S1=F2) or (S1=1 and F1!=1 and F1=S2)) and
    #it can be transposed, transpose it, else if a matching array's dimensions
    #are reversed and all the members of the synced group can be transposed,
    #transpose the members of the synced group.  Then the current array is
    #added to it.  Otherwise, the array is added as the first member of a new
    #synced group.  If the second dimension is a mix of sizes 1 & N only and N
    #matches F or S in the synced group, the 1 member is duplicated to match
    #the other dimension (F or S).

    my $synced_groups = [{EF    => $type_container->[0]->{EF},
			  ES    => $type_container->[0]->{ES},
			  AF    => [@{$type_container->[0]->{AF}}],
			  AS    => [@{$type_container->[0]->{AS}}],
			  GROUP => [$type_container->[0]]  #This is a hash like
			                                   #in the type_
			                                   #container array
			 }];

    #For every type_hash_index in the type container except the first one
    foreach my $type_hash_index (1..$#{$type_container})
      {
	my $type_hash = $type_container->[$type_hash_index];

	my $found_match = 0;

	my $candidate_ef = $type_hash->{EF};
	my $candidate_es = $type_hash->{ES};
	my $candidate_af = $type_hash->{AF};
	my $candidate_as = $type_hash->{AS};

	debug({LEVEL => -99},
	      "candidate_ef $candidate_ef candidate_es $candidate_es ",
	      "candidate_af @$candidate_af candidate_as @$candidate_as");

	foreach my $group_hash (@$synced_groups)
	  {
	    my $group_ef = $group_hash->{EF};
	    my $group_es = $group_hash->{ES};
	    my $group_af = $group_hash->{AF};
	    my $group_as = $group_hash->{AS};

	    debug({LEVEL => -99},
		  "group_ef $group_ef group_es $group_es group_af @$group_af ",
		  "group_as @$group_as");

	    #If the candidate and group match (each explained in-line below)
	    if(#Either candidate or group is 1x1 (always a match)
	       ($candidate_ef eq '1' && $candidate_es eq '1') ||
	       ($group_ef     eq '1' && $group_es eq '1') ||

	       #Exact or reverse exact match
	       ($candidate_ef eq $group_ef && $candidate_es eq $group_es) ||
	       ($candidate_ef eq $group_es && $candidate_es eq $group_ef) ||

	       #candidate_ef is 1 and candidate_es is not 1 but matches either
	       ($candidate_ef eq '1' && $candidate_es ne '1' &&
		($candidate_es eq $group_es || $candidate_es eq $group_ef)) ||

	       #candidate_es is 1 and candidate_ef is not 1 but matches either
	       ($candidate_es eq '1' && $candidate_ef ne '1' &&
		($candidate_ef eq $group_es || $candidate_ef eq $group_ef)) ||

	       #group_ef is 1 and group_es is not 1 but matches either
	       ($group_ef eq '1' && $group_es ne '1' &&
		($group_es eq $candidate_es || $group_es eq $candidate_ef)) ||

	       #group_es is 1 and group_ef is not 1 but matches either
	       ($group_es eq '1' && $group_ef ne '1' &&
		($group_ef eq $candidate_es || $group_ef eq $candidate_ef)) ||

	       #First dimensions match exactly and each second dimension is
	       #either an exact corresponding match or one of them is a 1
	       ($candidate_ef eq $group_ef &&
		scalar(grep {$group_as->[$_] == $candidate_as->[$_] ||
			       $group_as->[$_] == 1 ||
				 $candidate_as->[$_] == 1}
		       (0..($group_ef - 1))) == $group_ef))
	      {
		$found_match = 1;

		#If the candidate's dimensions are not the same, the group's
		#dimensions are not the same, and the candidate's dimensions
		#are reversed relative to the group, we need to transpose
		#either the candidate or the group.
		if(#Neither the candidate nor group is a square
		   $candidate_ef ne $candidate_es && $group_ef ne $group_es &&
		   #Either the candidate or group is not variable dimension
		   ($candidate_es !~ /,/ || $group_es !~ /,/) &&
		   #The matching dimension is opposite & not size 1
		   (($candidate_ef eq $group_es && $group_es ne '1') ||
		    ($candidate_es eq $group_ef && $group_ef ne '1')))
		  {
		    #We need to transpose either the candidate or group

		    #If the candidate can be transposed
		    if($candidate_es !~ /,/)
		      {
			#Assuming the number of columns varies between 1 & M,
			#fill up the rows of size 1 to match M before
			#transposing. (Won't hurt if they don't)
			foreach my $row (@{$type_hash->{DATA}})
			  {while(scalar(@$row) < $candidate_es)
			     {push(@$row,$row->[0])}}

			debug({LEVEL => -99},"Transposing candidate.");
			@{$type_hash->{DATA}} = transpose($type_hash->{DATA});
			my $tmp = $candidate_ef;
			$candidate_ef = $type_hash->{EF} = $candidate_es;
			$candidate_es = $type_hash->{ES} = $tmp;
			$candidate_af = $type_hash->{AF} =
			  [scalar(@{$type_hash->{DATA}})];
			$candidate_as = $type_hash->{AS} =
			  [map {scalar(@$_)} @{$type_hash->{DATA}}];
		      }
		    #Else if the group can be transposed
		    elsif($group_es !~ /,/)
		      {
			debug({LEVEL => -99},"Transposing group.");
			#For every member of the group (which is a type hash)
			foreach my $member_type_hash (@{$group_hash->{GROUP}})
			  {
			    #Assuming the number of columns varies between 1 &
			    #M, fill up the rows of size 1 to match M before
			    #transposing. (Won't hurt if they don't)
			    foreach my $row (@{$member_type_hash->{DATA}})
			      {while(scalar(@$row) < $group_es)
				 {push(@$row,$row->[0])}}

			    @{$member_type_hash->{DATA}} =
			      transpose($member_type_hash->{DATA});

			    #Update the type hash's metadata
			    my $tmp = $member_type_hash->{EF};
			    $member_type_hash->{EF} = $member_type_hash->{ES};
			    $member_type_hash->{ES} = $tmp;
			    $member_type_hash->{AF} =
			      [scalar(@{$member_type_hash->{DATA}})];
			    $member_type_hash->{AS} =
			      [map {scalar(@$_)} @{$member_type_hash->{DATA}}];
			  }

			#Update the group metadata (using the first member of
			#the group)
			my $tmp = $group_ef;
			$group_ef = $group_hash->{EF} = $group_es;
			$group_es = $group_hash->{ES} = $tmp;
			$group_af = $group_hash->{AF} =
			  [scalar(@{$group_hash->{GROUP}->[0]->{DATA}})];
			$group_as = $group_hash->{AS} =
			  [map {scalar(@$_)}
			   @{$group_hash->{GROUP}->[0]->{DATA}}];
		      }
		    else
		      {
			error("Critical internal error: Transpose not ",
			      "possible.  This should not be possible.");
			quit(-39);
		      }
		  }

		#Anything that needed transposed has now been transposed, so
		#now we need to even things up by filling any 1-dimensional
		#arrays to match their 2D matches.

		debug({LEVEL => -99},
		      "Add rows if(candidate_ef eq '1' && group_ef ne '1' && ",
		      "group_es ne '1'): if($candidate_ef eq '1' && ",
		      "$group_ef ne '1' && $group_es ne '1')");

		#If we need to add any rows to the candidate
		if($candidate_ef eq '1' && $group_ef ne '1')
		  {
		    debug({LEVEL => -99},"Adding rows to candidate.");
		    foreach(2..$group_ef)
		      {push(@{$type_hash->{DATA}},
			    [@{copyArray($type_hash->{DATA}->[0])}])}

		    #Update the metadata
		    $candidate_ef = $type_hash->{EF} = $group_ef;
		    #The effective second dimension size did not change
		    $candidate_af = $type_hash->{AF} = [$group_ef];
		    $candidate_as = $type_hash->{AS} =
		      [map {scalar(@$_)} @{$type_hash->{DATA}}];
		  }

		debug({LEVEL => -99},
		      "Add columns if(candidate_es eq '1' && group_es ne ",
		      "'1': if($candidate_es eq '1' && $group_es ne '1')");

		#If we need to add any columns to the candidate
		my $col_change = 0;
		foreach my $i (0..$#{$group_as})
		  {
		    my $num_cols = $group_as->[$i];
		    my $row = $type_hash->{DATA}->[$i];
		    while(scalar(@$row) < $num_cols)
		      {
			$col_change = 1;
			push(@$row,$row->[0]);
		      }
		  }
		if($col_change)
		  {
		    debug({LEVEL => -99},"Added columns to candidate.");
		    #Update the metadata
		    #The effective first dimension size did not change
		    $candidate_es = $type_hash->{ES} = $group_es;
		    #The actual first dimension size did not change
		    $candidate_as = $type_hash->{AS} =
		      [map {scalar(@$_)} @{$type_hash->{DATA}}];
		  }
		#If we need to add any rows to the group
		if($group_ef eq '1' && $candidate_ef ne '1')
		  {
		    debug({LEVEL => -99},"Adding rows to group.");
		    foreach my $member_type_hash (@{$group_hash->{GROUP}})
		      {
			#Copy the first row up to the effective first
			#dimension size of the candidate
			foreach(2..$candidate_ef)
			  {push(@{$member_type_hash->{DATA}},
				[@{copyArray($member_type_hash->{DATA}
					     ->[0])}])}

			#Update the member metadata
			$member_type_hash->{EF} = $candidate_ef;
			#Effective second dimension size did not change
			$member_type_hash->{AF} = [$candidate_ef];
			$member_type_hash->{AS} =
			  [map {scalar(@$_)} @{$member_type_hash->{DATA}}];
		      }

		    #Update the group metadata
		    $group_ef = $group_hash->{EF} = $candidate_ef;
		    #Effective second dimension size did not change
		    $group_af = $group_hash->{AF} =
		      [scalar(@{$group_hash->{GROUP}->[0]->{DATA}})];
		    #The actual second dimension size could be different if the
		    #candidate has a variable second dimension size
		    $group_as = $group_hash->{AS} =
		      [map {scalar(@$_)} @{$group_hash->{GROUP}->[0]->{DATA}}];
		  }

		#If we need to add any columns to the group
		$col_change = 0;
		foreach my $member_type_hash (@{$group_hash->{GROUP}})
		  {
		    foreach my $i (0..$#{$candidate_as})
		      {
			my $num_cols = $candidate_as->[$i];
			my $row = $member_type_hash->{DATA}->[$i];
			while(scalar(@$row) < $num_cols)
			  {
			    $col_change = 1;
			    push(@$row,$row->[0]);
			  }
		      }

		    if($col_change)
		      {
			#Update the member metadata
			#The effective first dimension size did not change
			$member_type_hash->{ES} = $candidate_es;
			#The actual first dimension size did not change
			$member_type_hash->{AS} =
			  [map {scalar(@$_)} @{$member_type_hash->{DATA}}];
		      }
		    else #Assume everything in a group is same dimensioned
		      {last}
		  }

		if($col_change)
		  {
		    debug({LEVEL => -99},"Added columns to group.");
		    #Update the metadata
		    #The effective first dimension size did not change
		    $group_es = $group_hash->{ES} = $candidate_es;
		    #The actual first dimension size did not change
		    $group_as = $group_hash->{AS} =
		      [map {scalar(@$_)} @{$group_hash->{GROUP}->[0]->{DATA}}];
		  }

		#Put this candidate in the synced group
		push(@{$group_hash->{GROUP}},$type_hash);

		#We stop when we find a match so that we don't put this
		#candidate in multiple synced groups
		last;
	      }
	  }

	unless($found_match)
	  {
	    #Create a new synced group
	    push(@$synced_groups,{EF    => $candidate_ef,
				  ES    => $candidate_es,
				  AF    => $candidate_af,
				  AS    => $candidate_as,
				  GROUP => [$type_hash]});
	  }
      }

    #Now I have a set of synced groups, meaning every hash in the group has the
    #same dimensions described by the group's metadata.  However, I don't need
    #that metadata anymore, so I can condense the groups into 1 big array of
    #type hashes and all I need from those is the TYPE (the first index into
    #$array) and the DATA (The 2D array of files).

    #Each group has F * S paired combos.  In order to generate all possible
    #combinations, I need to string them along in a 1 dimensional array

    my $flattened_groups = []; #Each member is an unfinished combo (a hash with
                               #2 keys: TYPE & ITEM, both scalars

    foreach my $synced_group (@$synced_groups)
      {
	push(@$flattened_groups,[]);
	foreach my $row_index (0..($synced_group->{EF} - 1))
	  {
	    foreach my $col_index (0..($synced_group->{AS}->[$row_index] - 1))
	      {
		my $unfinished_combo = [];

		#foreach type hash in GROUP, add the item at row/col index to a
		#combo
		foreach my $type_hash (@{$synced_group->{GROUP}})
		  {
		    debug({LEVEL => -99},"ITEM should be type '': [",
			  ref($type_hash->{DATA}->[$row_index]->[$col_index]),
			  "].");

		    push(@$unfinished_combo,
			 {TYPE => $type_hash->{TYPE},
			  ITEM => $type_hash->{DATA}->[$row_index]
			  ->[$col_index]});
		  }

		push(@{$flattened_groups->[-1]},$unfinished_combo);
	      }
	  }
      }

    my $combos = [];
    my $combo  = [];
    while(GetNextIndepCombo($combo,
			    [map {scalar(@$_)} @$flattened_groups]))
      {
	#The index of combo items corresponds to the index of flattened_groups
	#The values of combo correspond to the index into the array member of
	#flattened_groups

	#Construct this combo from the unfinished combos
	my $finished_combo = [];
	foreach my $outer_index (0..$#{$combo})
	  {
	    my $inner_index = $combo->[$outer_index];

	    push(@$finished_combo,
		 @{$flattened_groups->[$outer_index]->[$inner_index]});
	  }

	#Check the finished combo to see that it contains 1 file of each type
	my $check = {map {$_ => 0} (0..$#{$array})};
	my $unknown = {};
	foreach my $type_index (map {$_->{TYPE}} @$finished_combo)
	  {
	    if(exists($check->{$type_index}))
	      {$check->{$type_index}++}
	    else
	      {$unknown->{$type_index}++}
	  }
	my @too_many = grep {$check->{$_} > 1} keys(%$check);
	if(scalar(@too_many))
	  {
	    error("Critical Internal error: Bad Option Combo.  These option ",
		  "types had more than 1 value: [",join(',',@too_many),
		  "].  Use --force to include all combos by attempting to ",
		  "repair it.");

	    #Jump to the next iteration unless the user chose to force it
	    next if(!defined($force) || !$force);

	    #If they force it, try to repair by eliminating extra ones
	    my $fixed_fin_combo = [];
	    my $done = {};
	    foreach my $hash (@$finished_combo)
	      {
		next if(exists($done->{$hash->{TYPE}}));
		$done->{$hash->{TYPE}} = 1;
		push(@$fixed_fin_combo,$hash);
	      }
	    @$finished_combo = @$fixed_fin_combo;
	  }
	my @missing = grep {$check->{$_} == 0} keys(%$check);
	if(scalar(@missing))
	  {
	    error("Critical Internal error: Bad Option Combo.  These option ",
		  "types were missing: [",join(',',@missing),
		  "].  Use --force to include all combos by attempting to ",
		  "repair it.");

	    next if(!defined($force) || !$force);

	    #If they force it, try to repair by adding undefs
	    foreach my $type_index (@missing)
	      {push(@$finished_combo,{TYPE => $type_index,ITEM => undef})}
	  }
	if(scalar(keys(%$unknown)))
	  {
	    error("Critical Internal error: Bad Option Combo.  These option ",
		  "types are unknown: [",join(',',keys(%$unknown)),
		  "].  Use --force to include all combos by attempting to ",
		  "repair it.");

	    next if(!defined($force) || !$force);

	    #If they force it, try to repair by eliminating unknowns
	    my $fixed_fin_combo = [];
	    foreach my $hash (@$finished_combo)
	      {push(@$fixed_fin_combo,$hash)
		 unless(exists($unknown->{$hash->{TYPE}}))}
	    @$finished_combo = @$fixed_fin_combo;
	  }

	#Save the combo to return it
	push(@$combos,
	     [map {$_->{ITEM}}
	      sort {$a->{TYPE} <=> $b->{TYPE}} @$finished_combo]);
      }

    return(wantarray ? @$combos : $combos);
  }

#This method is specifically for use with the '<>' Getopt::Long operator
#(which catches flagless options) when used to capture files.  Since all
#unknown options go here, this sub watches for values that do not exist as
#files and begin with a dash followed by a non-number (to be rather forgiving
#of stub usages).  It just issues a warning, but if in strict mode, it will
#call quit.
sub checkFileOpt
  {
    my $alleged_file = $_[0];
    my $strict       = defined($_[1]) ? $_[1] : 0;
    if($alleged_file =~ /^-\D/ && !(-e $alleged_file))
      {
	if($strict)
	  {
	    error("Unknown option: [$alleged_file].");
	    quit(-52);
	  }
	else
	  {warning("Potentially unknown option assumed to be a file name: ",
		   "[$alleged_file].")}
      }
  }

sub processDefaultOptions
  {
    my $outfiles_defined = $_[0];

    #If there's anything in the stderr buffer, it will get emptied from
    #verbose calls below.

    debug({LEVEL => -1},"Processing default options.");

    my $use_as_default = getVarref('save_args',1);
    my $version        = getVarref('version',1);
    my $help           = getVarref('help',1);
    my $run            = getVarref('run',1);
    my $dry_run        = getVarref('dry_run',1);
    my $verbose        = getVarref('verbose',1);
    my $DEBUG          = getVarref('debug',1);
    my $header         = getVarref('header',1);
    my $quiet_ref      = getVarref('quiet');

    my $quiet_warning = '';

    #Do not allow a default quiet to affect non-run modes
    if((!($run || $dry_run) || $version || $use_as_default) &&
       hasDefault($usage_lookup->{quiet}) &&
       !$usage_lookup->{quiet}->{SUPPLIED})
      {
        #This is the only explicit change of a committed varref allowed.
	$$quiet_ref = 0;

        $quiet_warning =
          join('',("$usage_lookup->{quiet}->{OPTFLAG_DEF} cannot be ",
                   "defaulted to true in a non-run mode (e.g. usage, help, ",
                   "etc).  Quiet has been turned off."));

	#If an error or warning has occurred and debug is non-zero
        #OR abs(debug) > 1.  Note, an error or warning may occur after this and
        #this won't be printed
	if(#!$usage_lookup->{usage}->{SUPPLIED} &&
	   #!$usage_lookup->{help}->{SUPPLIED}  &&
	   #!$usage_lookup->{version}->{SUPPLIED} &&
	   #!$usage_lookup->{save_args}->{SUPPLIED} &&
           (($error_number || $warning_number) && $DEBUG) || abs($DEBUG) > 1)
	  {
            ##TODO: Add hash param to only warn in debug mode and remove $DEBUG
            ##      from the surrounding conditional
            warning("$usage_lookup->{quiet}->{OPTFLAG_DEF} cannot be ",
                    "defaulted to true in a non-run mode (e.g. usage, help, ",
                    "etc).  Quiet has been turned off.");
            $quiet_warning = '';
          }
      }

    #If there has been a compile error, catch it here and do not proceed
    #Do not return if force has been supplied
    if(defined($compile_err) && scalar(@$compile_err))
      {quit(-54)}

    #If the user has asked to save the options, save them & quit.  Saving of
    #--help, --dry-run, --usage, or --run are allowed, so this must be
    #processed before help or usage is printed.
    if($use_as_default)
      {
	saveUserDefaults() && quit(0);

        warning($quiet_warning) if($quiet_warning ne '' &&
                                   ($error_number || $warning_number));

        return(-8); #QUIT(-8)
      }

    #Print the usage if there are no non-user-default arguments (or it's just
    #the extended flag) and no files directed or piped in.
    #We're going to assume that if not all required options were supplied,
    #specific errors with an exit will be issued below (i.e. when $usage == 2)
    if($usage && $usage != 2)
      {
	usage(0);
	debug({LEVEL => -1},"Quitting with usage.");

        warning($quiet_warning) if($quiet_warning ne '' &&
                                   ($error_number || $warning_number));

        return($cli_error_num ? -3 : 1); #QUIT(-3)
      }

    #If the user has asked for the script version, print it & quit
    if($version)
      {
	print(getVersion(),"\n");

        warning($quiet_warning) if($quiet_warning ne '' &&
                                   ($error_number || $warning_number));

        return($cli_error_num ? -6 : 1); #QUIT(-6)
      }

    #If the user has asked for help, call the help method & quit
    if($help)
      {
	my $extended = getVarref('extended',1,1);

	help($extended);

        warning($quiet_warning) if($quiet_warning ne '' &&
                                   ($error_number || $warning_number));

        return($cli_error_num ? -51 : 1); #QUIT(-51)
      }

    if(defined($user_collide_mode) && $user_collide_mode !~ /^[mer]/i)
      {
	error("Invalid --collision-mode: [$user_collide_mode].  Acceptable ",
	      "values are: [merge, rename, or error].  Check usage for an ",
	      "explanation of what these modes do.");
	quit(-21);
      }

    #Warn users when they turn on verbose and output is to the terminal
    #(implied by no outfile suffix & no redirect out) that verbose messages may
    #be messy
    if($verbose && !$outfiles_defined && isStandardOutputToTerminal())
      {warning('You have enabled --verbose, but appear to be outputting to ',
	       'the  terminal.  Verbose messages may interfere with ',
	       'formatting of terminal output making it difficult to read.  ',
	       'You may want to either turn verbose off, redirect output to ',
	       'a file, or supply output files by other means.')}

    if($dry_run)
      {verbose('Starting dry run.')}

    verbose({LEVEL => 2},'Run conditions: ',scalar(getCommand(1)));
    verbose({LEVEL => 2},"Verbose level:  [$verbose].");
    verbose({LEVEL => 2},'Header:         [on].')           if($header);
    verbose({LEVEL => 2},"Debug level:    [$DEBUG].")       if($DEBUG);
    verbose({LEVEL => 2},"Force level:    [$force].")       if($force);
    verbose({LEVEL => 2},"Overwrite:      [$overwrite].")   if($overwrite);
    verbose({LEVEL => 2},'Skip Existing:  [on].')           if($skip_existing);
    verbose({LEVEL => 2},'Append:         [on].')           if($append);
    verbose({LEVEL => 2},"Dry run mode:   [$dry_run].")     if($dry_run);
    verbose({LEVEL => 2},"Collision mode: [$user_collide_mode].")
      if(defined($user_collide_mode));
    verbose({LEVEL => 2},"Error level:    [$error_limit].")
      if($error_limit != $error_limit_default);

    return(0);
  }

sub argsOrPipeSupplied
  {
    my $got_input = isThereInputOnSTDIN();

    my $ignore_opts = [qw(extended debug run dry_run usage help)];
    #ignore_flags_hash = {flag => option type}
    my $ignore_flags_hash =
      {map {my $name = $_;
            map {$_ => {TYPE    => $def_option_hash->{$name}->{PARAMS}->{TYPE},
                        ACCEPTS => ($def_option_hash->{$name}->{PARAMS}
                                    ->{ACCEPTS})}}
              getOptStrFlags($def_option_hash->{$name}->{PARAMS}->{FLAG})}
       @$ignore_opts};

    #Filter out the ignored option flags and their arguments
    my $filtered_opts =
      [grep {my $i = $_;my $arg = $active_args->[$_];
             my $parg = ($i > 0 ? $active_args->[$_ - 1] : undef);
             (exists($ignore_flags_hash->{$arg}) ||
              (defined($parg) && exists($ignore_flags_hash->{$parg}) &&
               argMatchesType($arg,$ignore_flags_hash->{$parg}->{TYPE})) ?
              0 : 1)}
       (0..$#{$active_args})];

    #Should print if run mode is usage and any option other than extended &
    #debug are supplied
    return($got_input || scalar(@$filtered_opts));
  }

#Only works with scalar args (i.e. parsed from the command line)
sub argMatchesType
  {
    my $arg     = $_[0];
    my $type    = $_[1];
    my $accepts = $_[2];
    if(ref($arg) ne '')
      {
        error('Non-scalar argument supplied.');
        return(0);
      }
    if($type eq 'count' || $type eq 'integer')
      {return(isInt($arg))}
    elsif($type eq 'float')
      {return(isFloat($arg))}
    elsif($type eq 'bool')
      {return(0)}
    else
      {error("Type [$type] not supported yet.")}
    return(0);
  }

sub isExtendedFlag
  {
    my $flag = $_[0];

    foreach my $eflag (@{$usage_lookup->{extended}->{OPTFLAGS}})
      {return(1) if($eflag eq $flag)}

    return(0);
  }

sub isInt
  {
    my $val = $_[0];
    if(defined($val) && ref($val) eq '' &&
       $val =~ /^[+\-]?\d+([eE][+\-]?(\d+))?$/)
      {return(1)}
    return(0);
  }

sub isFloat
  {
    my $val = $_[0];
    my $np = '\d+|\d+\.|\d+\.\d+|\.\d+';
    if(defined($val) && ref($val) eq '' &&
       $val =~ /^[+\-]?($np)([eE][+\-]?($np))?$/)
      {return(1)}
    return(0);
  }

#We're going to literally treat any undefined value or defined scalar as a valid
#boolean
sub isBool
  {
    my $val = $_[0];
    if(!defined($val) || ref($val) eq '')
      {return(1)}
    return(0);
  }

#We're going to treat defined scalars that are an int or an empty string as a
#valid count
sub isCount
  {
    my $val = $_[0];
    if(defined($val) && ref($val) eq '' && ($val eq '' || isInt($val)))
      {return(1)}
    return(0);
  }

#Globals used: $flushing, $debug_number
sub flushStderrBuffer
  {
    #Return if there is nothing in the buffer
    return(0) if(!defined($stderr_buffer));

    my %in = scalar(@_) % 2 == 0 ? @_ : ();

    #Use the local_force parameter to flush even if the required flags are not
    #defined
    my $local_force = (exists($in{FORCE}) ? $in{FORCE} :
		       (scalar(@_) == 1 && defined($_[0]) && $_[0] ne 'FORCE' ?
			$_[0] : 0));

    my $forced          = 0;
    my $cli_errors_only = ($local_force && $command_line_stage != DONE ? 1 : 0);
    my $miscompile      = defined($compile_err) && scalar(@$compile_err);
    my($extended,$error_limit,$quiet,$verbose,$DEBUG);
    if($command_line_stage >= DEFAULTED)
      {
	$extended    = getVarref('extended',1,1);
	$error_limit = getVarref('error_lim',1,1);
      }
    if($command_line_stage == VALIDATED && !$miscompile)
      {
	$quiet       = getVarref('quiet',1,1);
	$verbose     = getVarref('verbose',1,1);
	$DEBUG       = getVarref('debug',1,1);
      }
    elsif($command_line_stage >= COMMITTED && !$miscompile)
      {
	$quiet       = getVarref('quiet',1);
	$verbose     = getVarref('verbose',1);
	$DEBUG       = getVarref('debug',1);
      }
    elsif($local_force)
      {
        my $fallbacks    = getBuiltinFallbacks();
        $quiet           = $fallbacks->{quiet};
	$verbose         = $fallbacks->{verbose};
	$DEBUG           = $fallbacks->{debug};
	$extended        = $fallbacks->{extended};
	$error_limit     = $fallbacks->{error_lim};
        $forced          = (defined($quiet) && defined($verbose) &&
                            defined($DEBUG) && defined($error_limit) ? 0 : 1);
        $cli_errors_only = ($DEBUG < 2); #processCommandLine in trace implies
      }

    #This checks the error/warning number in case the buffer has to be flushed
    #more than once
    my $prints_exist =
      scalar(grep {((#There is a defined error limit
		     (($local_force && !defined($error_limit)) ||
		      defined($error_limit)) &&
		     #There are error or warning messages in the buffer
		     ($_->[0] eq 'error' || $_->[0] eq 'warning') &&
		     #The error/warning number is =to|under the error limit
		     (!defined($error_limit) ||
		      $error_limit == 0 || $_->[1] <= $error_limit)) ||

		    (#There is a defined verbose level
		     defined($verbose) &&
		     #There are verbose messages in the buffer
		     $_->[0] eq 'verbose' &&
		      #The message level is =|under the verbose level
		     (($verbose > 0 && $_->[1] <= $verbose) ||
		      ($verbose < 0 && $_->[1] >= $verbose))) ||

		    (#There is a defined debug level
		     defined($DEBUG) &&
		     #There are debug messages in the buffer
		     $_->[0] eq 'debug' &&
		      #The message level is under the debug level
		     (($DEBUG > 0 && $_->[1] <= $DEBUG) ||
		      ($DEBUG < 0 && $_->[1] >= $DEBUG))))}

	     @{$stderr_buffer});

    my $semsg = '';

    my $printing =
      ($command_line_stage >= LOGGING || $local_force) && $prints_exist &&
	(!defined($logging) ||
	 (defined($logging) && (!$logging || $log_mirror || !$log_errors ||
                                !$log_warnings || !$log_verbose ||
                                !$log_debug))) ? 1 : 0;
    my $lognow =
      ($command_line_stage >= LOGGING || $local_force) && $prints_exist;

    if($local_force && $prints_exist && $forced && !$miscompile)
      {
        my $unprocs = [grep {!defined(getVarref($_,1,0,1))}
                       qw(verbose quiet debug error_lim)];
        if(!scalar(@$unprocs))
          {$unprocs = [qw(verbose quiet debug error_lim)]}
	$semsg = join('',
		      ("\nForce-flushing the STDERR buffer because the ",
		       'following command line options [',join(' ',@$unprocs),
		       '] were not fully processed/validated in time to be ',
		       "applied to some standard error output.\n"));
	if(!defined($extended) || $extended)
	  {$semsg .=
	     join('',('If you get this flush every time, you can likely ',
		      'prevent it by adding a call to one or more of the ',
		      'following methods earlier in your code: [',
		      'nextFileCombo(), getInfile(), getOutfile(), ',
		      'getNextFileGroup(), getAllFileGroups(), or optionally ',
		      '(if your script does not process files): ',
		      "processCommandLine()].\n\n"))}
	elsif(defined($extended))
	  {$semsg .= "Supply --extended for additional details.\n\n"}
	else
	  {$semsg .= "\n"}

	print STDERR ($semsg) if($printing);
	logger($semsg) if($log_warnings);

	#For debugging purposes...
	if(!defined($DEBUG) || $DEBUG < 0)
	  {
	    $semsg = "DEBUG-FLUSH-TRACE1:" . getTrace() . "\n\n";

	    print STDERR ($semsg) if($printing &&
                                     (!$logging || $log_mirror || !$log_debug));

	    logger($semsg) if($lognow && $log_debug);
	  }
      }

    #Return if we're not in force mode and either there's nothing in the buffer
    #to print or none of the stderr variables are set/validated
    if(!$local_force &&
       (!$prints_exist ||
        $command_line_stage < LOGGING))
      {
        #If no debugs were flushed, no prints exist, and stage is past LOGGING
        if(!$prints_exist && $command_line_stage >= LOGGING &&
           $command_line_stage < DONE && !$flushing)
          {$debug_number = 0}
        return(0);
      }

    if($cli_errors_only && !$miscompile && $DEBUG < 2 && $DEBUG > -2)
      {
        #Only issue the "only fatal errors" message if something else would be
        #printed otherwise
        if(scalar(grep {($_->[0] eq 'error' &&
                         $_->[9] !~ /CommandLineInterface\.pm/) ||
                           ($_->[0] eq 'warning' &&
                            $_->[9] !~ /Long\.pm|Runtime warning/) ||
                              ($DEBUG && $_->[0] eq 'debug' &&
                               (($_->[1] < 0 && $DEBUG <= $_->[1]) ||
                                ($_->[1] > 0 && $DEBUG >= $_->[1]))) ||
                                  ($verbose && $_->[0] eq 'verbose' &&
                                   (($_->[1] < 0 && $verbose <= $_->[1]) ||
                                    ($_->[1] > 0 && $verbose >= $_->[1])))}
                  @$stderr_buffer))
          {
            my $feomsg = "Only printing fatal errors. Set debug to greater " .
              "than 1 to see all possible standard error output.\n\n";

            print STDERR ($feomsg)
              if($printing && (!$logging || $log_mirror || !$log_debug));

            logger($feomsg) if($lognow && $log_debug);
          }
      }

    my $script = getScriptName();

    #Don't initialize pipeline_mode if printing usage so the default printed is
    #accurate
    my $pipeline = getVarref('pipeline',1,1);
    my $local_pipeline_mode = $pipeline;
    if(!defined($local_pipeline_mode))
      {
	$local_pipeline_mode = inPipeline();
	if(!$usage)
	  {$pipeline = $local_pipeline_mode}
      }

    my $debug_num         = $flushing ? $flushing : 0;
    my $replace_debug_num = $flushing ? 1 : 0;
    my $first_error       =
      defined($last_flush_error) && !$last_flush_error ? 1 : 0;
    my $first_warn        =
      defined($last_flush_warning) && !$last_flush_warning ? 1 : 0;
    foreach my $message_array (@{$stderr_buffer})
      {
	if(ref($message_array) ne 'ARRAY' || scalar(@$message_array) < 3)
	  {
	    $semsg = join('',"ERROR: Invalid message found in standard error ",
			  "buffer.  Must be an array with at least 3 ",
			  "elements, but ",
			  (ref($message_array) eq 'ARRAY' ?
			   "only [" . scalar(@$message_array) .
			   "] elements were present." :
			   "a [" . ref($message_array) .
			   "] was sent in instead."));

	    print STDERR ($semsg) if($printing &&
                                     (!$logging || $log_mirror ||
                                      !$log_errors));

	    logger($semsg) if($lognow && $log_errors);
	  }

	my($type,$level,$message,$leader,$smpl_msg,$smpl_ldr,$detail,
	   $detail_alert,$opts_hash,$trace) = @$message_array;

	if($type ne 'verbose' &&
	   (!defined($local_pipeline_mode) || $local_pipeline_mode))
	  {
	    my $pat = quotemeta($script);
	    if($message !~ /(?:DEBUG|WARNING|ERROR)\d+:$pat:/)
	      {$message  =~ s/^((DEBUG|WARNING|ERROR)\d+:)/$1$script:/g}
	    if($smpl_msg !~ /(?:DEBUG|WARNING|ERROR)\d+:$pat:/)
	      {$smpl_msg =~ s/^((DEBUG|WARNING|ERROR)\d+:)/$1$script:/g}
	    if($leader !~ /(?:DEBUG|WARNING|ERROR)\d+:$pat:/)
	      {$leader  =~ s/^((DEBUG|WARNING|ERROR)\d+:)/$1$script:/g}
	    if($smpl_ldr !~ /(?:DEBUG|WARNING|ERROR)\d+:$pat:/)
	      {$smpl_ldr =~ s/^((DEBUG|WARNING|ERROR)\d+:)/$1$script:/g}
	  }

	if(defined($detail) && $detail ne '' &&
	   defined($extended) && $extended)
	  {
	    $smpl_msg .= (' ' x length($smpl_ldr)) .
              join("\n" . (' ' x length($smpl_ldr)),split(/\n/,$detail)) . "\n";
	    $message  .= (' ' x length($leader))   .
              join("\n" . (' ' x length($leader)),split(/\n/,$detail)) . "\n";
	  }
	elsif(defined($detail) && $detail ne '')
	  {
	    $smpl_msg .= (' ' x length($smpl_ldr)) . $detail_alert . "\n";
	    $message  .= (' ' x length($leader))   . $detail_alert . "\n";
	  }

	if($type eq 'verbose')
	  {
	    if(!$cli_errors_only &&
               (!defined($verbose) || $level == 0 ||
                ($level < 0 && $verbose <= $level) ||
                ($level > 0 && $verbose >= $level)))
	      {
                my $log_only = 0;
                if(defined($opts_hash) && exists($opts_hash->{LOG}))
                  {$log_only = $opts_hash->{LOG}}

		print STDERR ($message) if($printing && !$log_only &&
                                           (!$logging || $log_mirror ||
                                            !$log_verbose));

		logger($message) if($lognow && ($log_verbose || $log_only));
	      }
	  }
	elsif($type eq 'debug')
	  {
            if(!$cli_errors_only)
              {
                my $tmp_msg = $message;
                if(defined($DEBUG) && abs($DEBUG) < 2)
                  {
                    if(defined($smpl_msg) && defined($smpl_ldr))
                      {$tmp_msg = $smpl_msg}
                  }

                if(!defined($DEBUG) || $level == 0  ||
                   ($level < 0 && $DEBUG <= $level) ||
                   ($level > 0 && $DEBUG >= $level))
                  {
                    if($replace_debug_num)
                      {$tmp_msg =~ s/^DEBUG\d+/DEBUG$debug_num/}
                    if($debug_num == 0 && $tmp_msg =~ /^DEBUG(\d+)/)
                      {$debug_num = $1}

                    print STDERR ($tmp_msg) if($printing &&
                                               (!$logging || $log_mirror ||
                                                !$log_debug));

                    logger($tmp_msg) if($lognow && $log_debug);

                    $debug_num++ if($printing &&
                                    (!$logging || $log_mirror || !$log_debug));
                  }
                elsif($debug_num == 0 && $tmp_msg =~ /^DEBUG(\d+)/)
                  {
                    my $tnum = $1;
                    if($tnum == 1)
                      {$debug_num = 1}
                    $replace_debug_num = 1;
                  }
                else
                  {$replace_debug_num = 1}
              }
	  }
	elsif($type eq 'error' || $type eq 'warning')
	  {
            if(!$cli_errors_only ||
               ($type eq 'error' && $trace =~ /CommandLineInterface\.pm/) ||
               #Getopt::Long warning is the 1 exception bec I treat it as fatal
               #Not sure why, but it sometimes presents generically as a
               #"runtime error" without a trace including CLI
               ($type eq 'warning' &&
                "$trace$message" =~ /Long\.pm|Runtime warning/))
              {
                if(scalar(@$message_array) < 4)
                  {
                    #Print the error without using the error function so as to
                    #avoid a potential infinite loop.
                    $semsg = join('',
                                  ("ERROR: Parameter array too small.  Must ",
                                   "contain at least 4 elements, but it has [",
                                   scalar(@$message_array),"].\n"));
                    print STDERR ($semsg)
                      if($printing &&
                         (!$logging ||
                          ($type eq 'warning' &&
                           ($log_mirror || !$log_warnings)) ||
                          ($type eq 'error' && ($log_mirror || !$log_errors))));

                    logger($semsg) if($lognow &&
                                      (($type eq 'warning' && $log_warnings) ||
                                       ($type eq 'error' && $log_errors)));
                    $leader = '';
                  }

                #Skip this one if it is above the error_limit
                next if(defined($error_limit) && $error_limit != 0 &&
                        $level > $error_limit);

                my $tmp_msg     = $message;
                my $tmp_ldr     = $leader;
                my $tmp_ldr_spc = ' ' x length($leader);
                if(defined($DEBUG) && !$DEBUG)
                  {
                    if(defined($smpl_msg) && defined($smpl_ldr))
                      {
                        $tmp_msg     = $smpl_msg;
                        $tmp_ldr     = $smpl_ldr;
                        $tmp_ldr_spc = ' ' x length($smpl_ldr);
                      }
                  }

                #Notify when going above the error limit
                if(defined($error_limit) && $level == $error_limit)
                  {
                    $tmp_msg .=
                      join('',($tmp_ldr_spc,"NOTE: Further ",
                               ($type eq 'error' ? 'error': "warning"),"s of ",
                               "this type will be suppressed.\n$tmp_ldr_spc",
                               "Set --error-limit to 0 to turn off error ",
                               "suppression\n"));
                    $error_limit_met = 1;
                  }

                #If there's already been a fatal error, only print the first
                #error and any warnings leading up to it unless in debug mode.
                #This assumes the first error was a fatal error and that all
                #subsequent
                #errors were during the cleanup
                ##TODO: Save the cleanup_mode state with each error and warning
                ##      so I don't have to assume the first error is the fatal
                ##      error.
                ##      See requirement #339
                if(!defined($cleanup_mode) || $cleanup_mode != 2 ||
                   !defined($DEBUG) || $DEBUG ||
                   ($cleanup_mode == 2 && (!$first_error || !$first_warn)))
                  {
                    if($tmp_msg =~ /^ERROR(\d+):/)
                      {
                        my $eno = $1;
                        if(defined($last_flush_error) &&
                           $eno >= $last_flush_error)
                          {$first_error = 1}
                      }
                    elsif($tmp_msg =~ /^WARNING(\d+):/)
                      {
                        my $wno = $1;
                        if(defined($last_flush_warning) &&
                           $wno >= $last_flush_warning)
                          {$first_warn = 1}
                      }
                    if(!defined($quiet) || !$quiet)
                      {
                        print STDERR ($tmp_msg)
                          if($printing &&
                             (!$logging ||
                              ($type eq 'warning' &&
                               ($log_mirror || !$log_warnings)) ||
                              ($type eq 'error' &&
                               ($log_mirror || !$log_errors))));

                        logger($tmp_msg) if($lognow && $log_errors);
                      }
                  }
              }
	  }
	else
	  {
	    #Print the error without using the error function so as to avoid a
	    #potential infinite loop if error() ever sends an invalid type.
	    $semsg =
	      "ERROR: Invalid type found in standard error buffer: [$type].\n";

	    print STDERR ($semsg) if($printing &&
                                     (!$logging || $log_mirror ||
                                      !$log_errors));

	    logger($semsg) if($lognow && $log_errors);
	  }
      }

    if($replace_debug_num)
      {
	$debug_number = $debug_num - 1;
	$flushing     = $debug_number + 1;
      }
    else
      {$debug_number = 0}

    if(defined($DEBUG) && $DEBUG < 0)
      {
	$semsg = "\nDONE-DEBUG-FLUSH-TRACE3:" . getTrace() . "\n\n";

	print STDERR ($semsg) if($printing &&
                                 (!$logging || $log_mirror || !$log_debug));

	logger($semsg) if($lognow && $log_debug);
      }

    undef($stderr_buffer) if($printing || $lognow);
  }

#Call this sub when a fatal error has occurred during setup in order to set
#builtin options' values.  It will return a hash of those values.  These options
#may or may not have even been added to the script's options yet and their flags
#may not even be set correctly since the programmer may have encountered an
#error before their edits to the builtins have happened.
#This will stage and commit all builtin options with non-problematic user-
#supplied options or fallback defaults.  Run mode option problems are always
#resolved.  Logging is also turned on if not on already.
sub getBuiltinFallbacks
  {
    #Option names that have a conflict or need a fallback. Default: all.  Use
    #this only if you're sure of all but the supplied values.  You can supply
    #options this doesn't control, but unless you supply at least 1 of verbose,
    #quiet, debug, extended, error_lim, or force, it will default to all.
    #Supplying any values will also cause the command_line_stage to not change
    #because it is assumed that you are fine-tuning option values for a recovery
    #and continuation of a valid mode (e.g. usage)
    my $problems = [@_];

    my $fallbacks =
      {verbose   => $def_option_hash->{verbose}  ->{DEFAULT},
       quiet     => $def_option_hash->{quiet}    ->{DEFAULT},
       debug     => $def_option_hash->{debug}    ->{DEFAULT},
       extended  => $def_option_hash->{extended} ->{DEFAULT},
       error_lim => $def_option_hash->{error_lim}->{DEFAULT},
       force     => $def_option_hash->{force}    ->{DEFAULT},
       run       => $def_option_hash->{run}      ->{DEFAULT},
       dry_run   => $def_option_hash->{dry_run}  ->{DEFAULT},
       usage     => $def_option_hash->{usage}    ->{DEFAULT},
       help      => $def_option_hash->{help}     ->{DEFAULT}};

    my $problem_hash =
      {map {$_ => 1} grep {exists($fallbacks->{$_})} @$problems};
    if(scalar(keys(%$problem_hash)) == 0)
      {$problem_hash = {map {$_ => 1} keys(%$fallbacks)}}

    if((defined($compile_err) && scalar(@$compile_err)) ||
       $command_line_stage < DONE)
      {
        my $dflags =
          [getOptStrFlags($def_option_hash->{debug}->{PARAMS}->{FLAG})];
        my @debug_nums =
          map {isInt($active_args->[$_]) ? $active_args->[$_] - 1 : 1}
            grep {my $i = $_;
                  scalar(grep {$active_args->[$i] eq $_} @$dflags) ||
                    ($i > 0 && isInt($active_args->[$i]) &&
                     scalar(grep {$active_args->[$i - 1] eq $_} @$dflags))}
              (0..$#{$active_args});

        if(scalar(@debug_nums) < 2 &&
           defined($compile_err) && scalar(@$compile_err))
          {
            print STDERR ("DEBUG: Standard error output suppressed due to ",
                          "setup error.  Supply [$dflags->[0] 2] (or greater ",
                          "than 1) to see all STDERR output.\n")
              if(scalar(@debug_nums) == 1);

            return($fallbacks);
          }
      }

    #quiet
    my $qflags =
      [getOptStrFlags($def_option_hash->{quiet}->{PARAMS}->{FLAG})];
    if(scalar(grep {my $f = $_;scalar(grep {$f eq $_} @$qflags)}
              @$active_args))
      {$fallbacks->{quiet} = 1}
    #Note, quiet will be turned off below if there's a conflict, thus over-
    #rides will be allowed, yet the script will fail and exit with an error.
    #This allows the user to see the problem.

    my $expmodes   = {run => 0,dry_run => 0,help => 0,usage => 0};
    my $expmodesum = 0;
    #run
    my $rflags =
      [getOptStrFlags($def_option_hash->{run}->{PARAMS}->{FLAG})];
    if(scalar(grep {my $f = $_;scalar(grep {$f eq $_} @$rflags)}
              @$active_args))
      {
        $fallbacks->{run} = $expmodes->{run} = 1;
        $expmodesum++;
      }
    #dry run
    my $yflags =
      [getOptStrFlags($def_option_hash->{dry_run}->{PARAMS}->{FLAG})];
    if(scalar(grep {my $f = $_;scalar(grep {$f eq $_} @$yflags)}
              @$active_args))
      {
        $fallbacks->{dry_run} = $expmodes->{dry_run} = 1;
        $expmodesum++;
      }
    #usage
    my $uflags =
      [getOptStrFlags($def_option_hash->{usage}->{PARAMS}->{FLAG})];
    if(scalar(grep {my $f = $_;scalar(grep {$f eq $_} @$uflags)}
              @$active_args))
      {
        $fallbacks->{usage} = $expmodes->{usage} = 1;
        $expmodesum++;
      }
    #help
    my $hflags =
      [getOptStrFlags($def_option_hash->{help}->{PARAMS}->{FLAG})];
    if(scalar(grep {my $f = $_;scalar(grep {$f eq $_} @$hflags)}
              @$active_args))
      {
        $fallbacks->{help} = $expmodes->{help} = 1;
        $expmodesum++;
      }
    #Resolve problems with the run modes
    my $modesum = 0;
    $modesum += $_ foreach(map {$fallbacks->{$_}} qw(run dry_run usage help));
    if($modesum != 1)
      {
        if($expmodesum == 1)
          {
            foreach(qw(run dry_run usage help))
              {$fallbacks->{$_} = $expmodes->{$_}}
          }
        else
          {
            my $defmsum = 0;
            $defmsum += $_ foreach(map {$def_option_hash->{$_}->{DEFAULT}}
                                   qw(run dry_run usage help));
            if($defmsum == 1)
              {foreach(qw(run dry_run usage help))
                 {$fallbacks->{$_} = $def_option_hash->{$_}->{DEFAULT}}}
            else
              {
                foreach(qw(run dry_run usage help))
                  {$fallbacks->{$_} = 0}
                $fallbacks->{usage} = 2;
              }
          }
      }

    #verbose
    my $vflags =
      [getOptStrFlags($def_option_hash->{verbose}->{PARAMS}->{FLAG})];
    my @verbose_nums =
      map {isInt($active_args->[$_]) ? $active_args->[$_] - 1 : 1}
        grep {my $i = $_;
              scalar(grep {$active_args->[$i] eq $_} @$vflags) ||
                ($i > 0 && isInt($active_args->[$i]) &&
                 scalar(grep {$active_args->[$i - 1] eq $_} @$vflags))}
          (0..$#{$active_args});
    if(scalar(@verbose_nums))
      {$fallbacks->{verbose} = sum(@verbose_nums)}

    #DEBUG
    my $dflags =
      [getOptStrFlags($def_option_hash->{debug}->{PARAMS}->{FLAG})];
    my @debug_nums =
      map {isInt($active_args->[$_]) ? $active_args->[$_] - 1 : 1}
        grep {my $i = $_;
              scalar(grep {$active_args->[$i] eq $_} @$dflags) ||
                ($i > 0 && isInt($active_args->[$i]) &&
                 scalar(grep {$active_args->[$i - 1] eq $_} @$dflags))}
          (0..$#{$active_args});
    if(scalar(@debug_nums))
      {$fallbacks->{debug} = sum(@debug_nums)}

    #error_lim
    my $lflags =
      [getOptStrFlags($def_option_hash->{error_lim}->{PARAMS}->{FLAG})];
    my @elim_nums =
      map {isInt($active_args->[$_]) ? $active_args->[$_] : 0}
        grep {my $i = $_;
              scalar(grep {$active_args->[$i] eq $_} @$lflags) ||
                ($i > 0 && isInt($active_args->[$i]) &&
                 scalar(grep {$active_args->[$i - 1] eq $_} @$lflags))}
          (0..$#{$active_args});
    if(scalar(@elim_nums))
      {$fallbacks->{error_lim} = pop(@elim_nums)}

    #extended
    my $eflags =
      [getOptStrFlags($def_option_hash->{extended}->{PARAMS}->{FLAG})];
    my @extended_nums =
      map {isInt($active_args->[$_]) ? $active_args->[$_] - 1 : 1}
        grep {my $i = $_;
              scalar(grep {$active_args->[$i] eq $_} @$eflags) ||
                ($i > 0 && isInt($active_args->[$i]) &&
                 scalar(grep {$active_args->[$i - 1] eq $_} @$eflags))}
          (0..$#{$active_args});
    if(scalar(@extended_nums))
      {$fallbacks->{extended} = sum(@extended_nums)}

    #force
    my $fflags =
      [getOptStrFlags($def_option_hash->{force}->{PARAMS}->{FLAG})];
    my @force_nums =
      map {isInt($active_args->[$_]) ? $active_args->[$_] - 1 : 1}
        grep {my $i = $_;
              scalar(grep {$active_args->[$i] eq $_} @$fflags) ||
                ($i > 0 && isInt($active_args->[$i]) &&
                 scalar(grep {$active_args->[$i - 1] eq $_} @$fflags))}
          (0..$#{$active_args});
    if(scalar(@force_nums))
      {$fallbacks->{force} = sum(@force_nums)}

    #If there's a conflict on the command line
    if($fallbacks->{quiet} && ($fallbacks->{debug} || $fallbacks->{verbose}))
      {$fallbacks->{quiet} = 0}

    if($fallbacks->{quiet} && $command_line_stage >= DEFAULTED &&
       $def_option_hash->{verbose}->{ADDED})
      {
        #See if quiet/debug/verbose have a conflict with a programmer or user
        #default, because they have to be explicitly over-ridable
        my $vdef = hasDefault($usage_lookup->{verbose});
        if($vdef)
          {$fallbacks->{quiet} = 0}
      }
    elsif($fallbacks->{quiet} && $command_line_stage >= DEFAULTED &&
          $def_option_hash->{debug}->{ADDED})
      {
        #See if quiet/debug/verbose have a conflict with a programmer or user
        #default, because they have to be explicitly over-ridable
        my $ddef = hasDefault($usage_lookup->{debug});
        if($ddef)
          {$fallbacks->{quiet} = 0}
      }

    #logfile - if the log file or the log file suffix option was created and
    #supplied, the following will work if the options made it through validation
    if($command_line_stage < VALIDATED)
      {
        #Re-initialize any options that were already added
        #$command_line_stage = ARGSREAD if($command_line_stage < ARGSREAD);
        stageVarref($usage_lookup->{verbose},$fallbacks->{verbose})
          if(defined($usage_lookup->{verbose}) &&
             exists($problem_hash->{verbose}));
        stageVarref($usage_lookup->{quiet},$fallbacks->{quiet})
          if(defined($usage_lookup->{quiet}) &&
             exists($problem_hash->{quiet}));
        stageVarref($usage_lookup->{debug},$fallbacks->{debug})
          if(defined($usage_lookup->{debug}) &&
             exists($problem_hash->{debug}));
        stageVarref($usage_lookup->{extended},$fallbacks->{extended})
          if(defined($usage_lookup->{extended}) &&
             exists($problem_hash->{extended}));
        stageVarref($usage_lookup->{error_lim},$fallbacks->{error_lim})
          if(defined($usage_lookup->{error_lim}) &&
             exists($problem_hash->{error_lim}));

	#Commit what we can (this will not set options that had a mutex
	#conflict - only those that have been properly staged)
	commitAllVarrefs();
      }
    if($command_line_stage < LOGGING && scalar(@$problems) == 0)
      {startLogging(1)}

    return($fallbacks);
  }

#This method creates a single-line trace.  It skips the call to this method and
#to the warning, error, or debug methods at the start of the trace.  Each
#element in the trace shows the subroutine and the line number inside the
#subroutine where the call was made.  The first element in the trace is the
#most recent call.  The last element in the trace is the oldest call (e.g. from
#main).  If the most recent call is from the main script, the script name is
#omitted, otherwise the file name where the call is is prepended.  When
#multiple sequential methods are called from the same file, the file name is
#skipped.  The format of the trace is:
#[file if not main/]calling_method(LINEline_number):[file if not the same as
#the last element and not in main of parent script/]calling_method(LINE
#line_number):...
#Example: CommandLineInterface.pm/openOut(LINE7479):MAIN(LINE53):
#Does not include script name for pipeline mode - call trace only.
sub getTrace
  {
    my @caller_info = caller(0);

    my $trace = '';

    #If any of these subs are the first in the trace, skip them
    my $skip_hash = {error => 1, warning => 1, debug => 1, __ANON__ => 1};
    my $skip_end_hash = {'(eval)' => 1, MAIN => 1};

    #Do not include the script name in the trace if the trace starts out from
    #the programmer's script.  They don't need a reminder of where their own
    #errors, warnings, and debugs, called directly from their script, are
    #coming from (unless in pipeline mode).
    my $script        = getScriptName();
    my $last_filename = $script;

    #For each sub, report the line inside the sub where the call originated
    my $filename = $caller_info[1] || '';
    my $line_num = $caller_info[2] || '';

    my $end_called = 0;

    my $stack_level = 1;
    while(@caller_info = caller($stack_level))
      {
	my $calling_sub = $caller_info[3] || '';

	$filename =~ s%.*/%%;

	if(defined($calling_sub))
	  {$calling_sub =~ s/^.*::(.+)$/$1/}
	else
	  {$calling_sub = 'MAIN'}

	if($calling_sub eq 'END')
	  {$end_called = 1}

	#Only add to the trace if the line number is defined and the first
	#trace element is not one of the ones we're skipping
	if(defined($line_num) &&
	   ($trace ne '' || !exists($skip_hash->{$calling_sub})) &&
	   (!$end_called || ($end_called && $line_num ne '' &&
			     !exists($skip_end_hash->{$calling_sub}))))
	  {
	    if($trace ne '')
	      {$trace .= ':'}

	    if($filename eq $script && $trace eq '')
	      {$trace .= "$calling_sub(LINE$line_num)"}
	    elsif($filename ne $last_filename)
	      {$trace .= "$filename/$calling_sub(LINE$line_num)"}
	    else
	      {$trace .= "$calling_sub(LINE$line_num)"}
	  }

	$stack_level++;
	$last_filename = $filename unless($trace eq '');

	$filename = $caller_info[1] || '';
	$line_num = $caller_info[2] || '';
      }

    $trace .= ':' if($trace ne '');

    if(!$end_called || ($end_called && $line_num ne '' &&
			!exists($skip_end_hash->{MAIN})))
      {$trace .= "MAIN(LINE$line_num):"}

    return($trace);
  }

#This method guesses whether this script is running with concurrent or
#serially run siblings (i.e. in a script).  It uses pgrep and (indirectly) lsof.
#Cases where the script is intended to return true: 1. when the script is being
#piped to or from another command (i.e. not a file). 2. when the script is being
#run from inside another script.  In both cases, it is useful to know so that
#messages on STDERR can be prepended with the script name so that the user
#knows the source of any message
#WARNING: Called from flushStderrBuffer.  DO NOT PUT calls to debug in here.
sub inPipeline
  {
    if(defined($pipeline_auto))
      {return($pipeline_auto)}

    my $ppid     = getppid();
    my $siblings = `pgrep -P $ppid -l`;

    #Return true if any sibling processes were detected
    if($siblings =~ /\d/)
      {
        if(!isCaller('flushStderrBuffer','debug'))
          {debug("inPipeline - siblings detected.",
                 {LEVEL => -1,DETAIL => "pgrep output: [$siblings]."})}
        $pipeline_auto = 1;
        return(1);
      }

    #True if the parent is a script
    $pipeline_auto = calledInsideAScript($ppid);

    return($pipeline_auto);
  }

#This method guesses whether this script is running with serially run siblings
#(i.e. in a script).  It uses lsof.  Cases where the script is intended to
#return true: 1. 2. when the script is being run from inside a script being read
#by an interpreter.  It is useful to know so that messages on STDERR can be
#prepended with the script name so that the user knows the source of any message
#and in determining the source of STDIN (e.g. not connected to a tty and
#(possibly) not a pipe, but rather: inherited from the parent
#WARNING: Called from flushStderrBuffer via inPipeline.  DO NOT PUT calls to
#debug in here.
sub calledInsideAScript
  {
    my $ppid = $_[0];

    #Find out what file handles the parent process has open
    my $parent_data = `lsof -w -b -p $ppid`;

    #Return true if the parent has a read-only handle open on a regular file
    #(implying it's reading a script - the terminal/shell does a read/write
    #(mode 'u'))
    if($parent_data =~ /\s+\d+r\s+REG\s+/)
      {
        if(!isCaller('flushStderrBuffer','debug'))
          {debug("inPipeline - called inside a script.",
                 {LEVEL => -1,DETAIL => "lsof output: [$parent_data]."})}
        return(1);
      }

    return(0);
  }

sub amIPipedTo
  {return(isDebug(1) ? amIPipedToDebug(@_) : !-t STDIN && -p STDIN)}

#This method is actually better for debugging purposes because lsof shows me
#what pipe is being detected on STDIN.
sub amIPipedToDebug
  {
    my $forced = defined($_[0]) ? $_[0] : 0;
    my $pipes  = getMyPipeData($forced);
    return($pipes->[0]);
  }

sub amIRedirectedTo
  {return($command_line_stage >= COMMITTED && isDebug(1) ?
          amIRedirectedToDebug(@_) : !-t STDIN && -f STDIN)}

#This method is actually better for debugging purposes because lsof shows me
#what file is being detected on STDIN.
sub amIRedirectedToDebug
  {
    my $forced = defined($_[0]) ? $_[0] : 0;

    my $handle_data = getMyLsofData($forced);

    #Get the file descriptors
    my $fdin = fileno(STDIN);

    if(defined($fdin) && $fdin =~ /\d/ && $fdin > -1 &&
       $handle_data =~ /\s${fdin}r\s+REG\s+\S+\s+\S+\s+\S+\s+(\S+)/)
      {
	my $infile = $1;

	#Ignore lsof read lines that are this script
	my $script    = getScriptName();
	my $scriptpat = quotemeta($script);

	if($infile !~ m%/$scriptpat$%)
	  {
            if(!$lsof_debugged && isDebug(1))
              {
                $lsof_debugged = 1;
                debug("Standard input is redirected from: [$infile].",
                      {DETAIL => 'If you did not provide this file on ' .
                       'redirect, make sure you have not closed STDIN in the ' .
                       "parent process.  This file was found in lsof output:" .
                       "\n" . $handle_data});
              }

            return(1);
          }
      }

    return(0);
  }

#Calls lsof
#Globals used: $pipe_cache
sub getMyPipeData
  {
    my $forced = defined($_[0]) ? $_[0] : 0;

    #Return what was previously determined
    if(!$forced && defined($pipe_cache))
      {return(wantarray ? @$pipe_cache : $pipe_cache)}

    #Initialize the pipe boolean values
    $pipe_cache = [0,0,0];

    #Get the data necessary to determine piping of standard file handles
    my $handle_data = getMyLsofData($forced);

    #Get the file descriptors
    my $fdin = fileno(STDIN);
    my $fdot = fileno(STDOUT);
    my $fder = fileno(STDERR);

    if(defined($fdin) && $fdin =~ /\d/ && $fdin > -1 &&
       $handle_data =~ /\s$fdin\s+PIPE\s+/)
      {$pipe_cache->[0] = 1}
    if(defined($fdot) && $fdot =~ /\d/ && $fdot > -1 &&
       $handle_data =~ /\s$fdot\s+PIPE\s+/)
      {$pipe_cache->[1] = 1}
    if(defined($fder) && $fder =~ /\d/ && $fder > -1 &&
       $handle_data =~ /\s$fder\s+PIPE\s+/)
      {$pipe_cache->[2] = 1}

    return(wantarray ? @$pipe_cache : $pipe_cache);
  }

sub getMyLsofData
  {
    my $forced = defined($_[0]) ? $_[0] : 0;

    #Return what was previously determined
    if(!$forced && defined($lsof_cache) && $lsof_cache ne '')
      {return($lsof_cache)}

    my $lsof_cmd = "lsof -w -b -p $$";
    $lsof_cache = `$lsof_cmd 2> /dev/null`;

    return($lsof_cache);
  }

#Do not call this method internally.  Instead, check $force
#Globals used: $command_line_stage
sub isForced
  {
    unless($command_line_stage)
      {
	warning("isForced called before command line has been processed.");
	processCommandLine();
      }
    return(getVarref('force',1));
  }

#Do not call this method internally.  Instead, check $verbose
#Globals used: $command_line_stage
sub isVerbose
  {
    unless($command_line_stage)
      {
	warning("isVerbose called before command line has been processed.");
	processCommandLine();
      }
    return(getVarref('verbose',1));
  }

#Do not call this method internally.  Instead, check $DEBUG
#Globals used: $command_line_stage
sub isDebug
  {
    my $stgok = defined($_[0]) ? $_[0] : 0; #Internal usage only
    unless($command_line_stage)
      {
	warning("isDebug called before command line has been processed.");
	processCommandLine();
      }
    return(getVarref('debug',1,$stgok));
  }

#Do not call this method internally.  Instead, check $header
sub headerRequested
  {
    unless($command_line_stage)
      {
	warning("headerRequested called before command line has been ",
		"processed.");
	processCommandLine();
      }
    return(getVarref('header',1,0));
  }

#Do not call this method internally.  Instead, check $dry_run
#Globals used: $dry_run
sub isDryRun
  {
    unless($command_line_stage)
      {
	warning("isDryRun called before command line has been processed.");
	processCommandLine();
      }
    return(getVarref('dry_run',1));
  }

sub setDefaults
  {
    my @in = getSubParams([qw(HEADER ERRLIMIT COLLISIONMODE DEFRUNMODE|RUNMODE
			      DEFSDIR UNPROCFILEWARN REPORT VERBOSE QUIET
			      DEBUG)],
			  [],[@_]);
    my $header_def     = $in[0];
    my $errlimit_def   = $in[1];
    my $colmode_def    = $in[2];
    my $runmode_def    = $in[3];
    my $defs_dir       = $in[4];
    my $unprocwarn_def = $in[5];
    my $report_def     = $in[6];
    my $verbose_def    = $in[7];
    my $quiet_def      = $in[8];
    my $debug_def      = $in[9];

    my $errors = 0;

    if($command_line_stage >= ARGSREAD)
      {
	error("Cannot call setDefaults after the command line has been ",
	      "processed.");
	quit(-20);
	return(1);
      }

    if(defined($header_def) && ($header_def == 0 || $header_def == 1))
      {
	if(!$def_option_hash->{header}->{ADDED})
	  {$def_option_hash->{header}->{PARAMS}->{DEFAULT} = $header_def}
	else
	  {$usage_lookup->{header}->{DEFAULT_PRG} = $header_def}
      }
    elsif(defined($header_def))
      {
	error("Invalid HEADER value: [$header_def].  Must be 0 or 1.");
	$errors++;
      }

    if(defined($errlimit_def) && $errlimit_def =~ /^\d+$/)
      {
	if(!$def_option_hash->{error_lim}->{ADDED})
	  {$def_option_hash->{error_lim}->{PARAMS}->{DEFAULT} = $errlimit_def}
	else
	  {$usage_lookup->{error_lim}->{DEFAULT_PRG} = $errlimit_def}
      }
    elsif(defined($errlimit_def))
      {
	error("Invalid ERRLIMIT value: [$errlimit_def].  Must be an unsigned ",
	      "integer.");
	$errors++;
      }

    if(defined($colmode_def) &&
       ($colmode_def eq 'error' || $colmode_def eq 'merge' ||
	$colmode_def eq 'rename'))
      {$def_collide_mode = $colmode_def}
    elsif(defined($colmode_def))
      {
	error("Invalid COLLISIONMODE value: [$colmode_def].  Must be one of ",
	      "['error','merge','rename'].");
	$errors++;
      }

    if(defined($runmode_def) &&
       ($runmode_def eq 'run'  || $runmode_def eq 'dry-run' ||
	$runmode_def eq 'help' || $runmode_def eq 'usage'))
      {setDefaultRunMode($runmode_def)}
    elsif(defined($runmode_def))
      {
	error("Invalid DEFRUNMODE value: [$runmode_def].  Must be one of ",
	      "['run','dry-run','usage','help'].");
	$errors++;
      }

    if(defined($defs_dir) && (!-e $defs_dir || (-w $defs_dir && -x $defs_dir)))
      {$defaults_dir = $defs_dir}
    elsif(defined($defs_dir))
      {
	error("Invalid DEFSDIR (user defaults directory): [$defs_dir].  Must ",
	      "either not already exist or be writable/executable.");
	$errors++;
      }

    if(defined($unprocwarn_def) && $unprocwarn_def =~ /^\d+$/)
      {$unproc_file_warn = $unprocwarn_def}
    elsif(defined($unprocwarn_def))
      {
	error("Invalid UNPROCFILEWARN: [$unprocwarn_def].  Must be 0 or 1.");
	$errors++;
      }

    if(defined($report_def) &&
       ($report_def == 0 || $report_def == 1 || $report_def == 2))
      {$runreport = $report_def}
    elsif(defined($report_def))
      {
	error("Invalid REPORT: [$report_def].  Must be 0 or 1.");
	$errors++;
      }

    if(defined($quiet_def) && ($quiet_def == 0 || $quiet_def == 1))
      {
	if(!$def_option_hash->{quiet}->{ADDED})
	  {$def_option_hash->{quiet}->{PARAMS}->{DEFAULT} = $quiet_def}
	else
	  {$usage_lookup->{quiet}->{DEFAULT_PRG} = $quiet_def}
      }
    elsif(defined($quiet_def))
      {
	error("Invalid QUIET: [$quiet_def].  Must be 0 or 1.");
	$errors++;
      }

    if(defined($quiet_def) && $quiet_def &&
       ((defined($verbose_def) && $verbose_def) ||
	(defined($debug_def) && $debug_def)))
      {
	error("QUIET and VERBOSE or DEBUG conflict.  Cannot be in quiet mode ",
	      "when also in verbose and/or debug mode.");
	$errors++;
      }

    if(defined($verbose_def) && isInt($verbose_def))
      {
	if(!$def_option_hash->{verbose}->{ADDED})
	  {$def_option_hash->{verbose}->{PARAMS}->{DEFAULT} = $verbose_def}
	else
	  {$usage_lookup->{verbose}->{DEFAULT_PRG} = $verbose_def}
      }
    elsif(defined($verbose_def))
      {
	error("Invalid VERBOSE: [$verbose_def].  Must be an integer.");
	$errors++;
      }

    if(defined($debug_def) && isInt($debug_def))
      {
	if(!$def_option_hash->{debug}->{ADDED})
	  {$def_option_hash->{debug}->{PARAMS}->{DEFAULT} = $debug_def}
	else
	  {$usage_lookup->{debug}->{DEFAULT_PRG} = $debug_def}
      }
    elsif(defined($debug_def))
      {
	error("Invalid DEBUG: [$debug_def].  Must be an integer.");
	$errors++;
      }

    if($errors > 0)
      {
	quit(-44);
	return(1);
      }

    return(0);
  }

#Globals used: $log_handle, $logging, $logfile_suffix_added, $logfile_added,
#$logfile_optid, $logfile_suffix_optid, $log_header
sub startLogging
  {
    my $override_stage = defined($_[0]) ? $_[0] : 0;

    if(!$command_line_stage && !$override_stage)
      {processCommandLine()}

    my $stgok = $override_stage ? 1 : undef;

    $logging = 0;

    my($logfile,$usg_hash);
    if($logfile_suffix_added && $logfile_added)
      {
        if(optionIDToMutualParam($logfile_optid,'VALIDATED'))
          {return($logging)}

	my $lf_uhash = $usage_array->[$logfile_optid];
	my $ls_uhash = $usage_array->[$logfile_suffix_optid];
	my $st_uhash = $usage_array->[$ls_uhash->{PAIRID}];
	if(hasValue('logfile',getVarref($lf_uhash,undef,$stgok)) &&
	   hasValue('logsuff',getVarref($ls_uhash,undef,$stgok)) &&
	   hasValue($st_uhash->{OPTTYPE},getVarref($st_uhash,undef,$stgok)))
	  {
	    error('Logfile and logfile suffix both supplied.  Only 1 is ',
		  'allowed.');
	    return($logging);
	  }
	elsif(hasValue('logfile',getVarref($lf_uhash,undef,$stgok)))
	  {
	    $logfile = getVarref($lf_uhash,1,$stgok);
	    $usg_hash = $lf_uhash;
	  }
	elsif(hasValue('logsuff',getVarref($ls_uhash,undef,$stgok)) &&
	      hasValue($st_uhash->{OPTTYPE},getVarref($st_uhash,undef,$stgok)))
	  {
	    $logfile = getVarref($st_uhash,1) . getVarref($ls_uhash,1,$stgok);
	    $usg_hash = $ls_uhash;
	  }
	else
	  {return($logging)}
      }
    elsif($logfile_added)
      {
	my $lf_uhash = $usage_array->[$logfile_optid];
	if(hasValue('logfile',getVarref($lf_uhash,undef,$stgok)))
	  {
	    $logfile = getVarref($lf_uhash,1,$stgok);
	    $usg_hash = $lf_uhash;
	  }
	else
	  {return($logging)}
      }
    elsif($logfile_suffix_added)
      {
	my $ls_uhash = $usage_array->[$logfile_suffix_optid];
	my $st_uhash = $usage_array->[$ls_uhash->{PAIRID}];
	if(hasValue('logsuff',getVarref($ls_uhash,undef,$stgok)) &&
	   hasValue($st_uhash->{OPTTYPE},getVarref($st_uhash,undef,$stgok)))
	  {
	    $logfile = getVarref($st_uhash) . getVarref($ls_uhash,undef,$stgok);
	    $usg_hash = $ls_uhash;
	  }
	else
	  {return($logging)}
      }
    else
      {return($logging)}

    my $handle = *LOG;

    $logging = openOut(HANDLE => $handle,
		       FILE   => $logfile,
		       SELECT => 0,
		       QUIET  => -1,
		       HEADER => $log_header,
		       APPEND => $usg_hash->{APPEND_MODE},
		       MERGE  => 1);

    if($logging)
      {$log_handle = $handle}
    elsif($error_number)
      {
        #Logging will be attempted a second time in cleanup mode, which will
        #thwart forcing, so do not call a second time (in cleanup_mode)
        my $force = getVarref('force',1,0);
        quit(-4) if(!$force && $cleanup_mode);
      }

    return($logging);
  }

#Globals used: $log_handle, $logging
sub stopLogging
  {closeOut($log_handle) if($logging)}

##
## This method prints a description of the script and it's input and output
## files.
##
#Globals used: $script_version_number, $created_on_date
sub help
  {
    ##TODO: Give the programmer a way to set IGNORE_UNSUPPLIED in all
    ##      instances.  See requirement 185
    my @in       = getSubParams([qw(ADVANCED IGNORE_UNSUPPLIED)],[],[@_]);
    my $script   = getScriptName();
    my $advanced = $in[0];
    my $ignore   = $in[1];
    my @stat     = stat($script);
    my $ctime    = @stat && defined($stat[9]) ? $stat[9] : scalar(time);
    my $lmd      = localtime($ctime);

    unless($command_line_stage)
      {processCommandLine()}

    $script_version_number = 'UNKNOWN'
      if(!defined($script_version_number));

    $created_on_date = 'UNKNOWN' if(!defined($created_on_date) ||
				    $created_on_date eq 'DATE HERE');

    my $custom_help = customHelp($ignore,$advanced);

    my $drm = getDefaultRunMode();

    #Print a description of this program
    print << "end_print";

$script version $script_version_number
Created: $created_on_date
Last Modified: $lmd

$custom_help
end_print

    if($advanced > 1)
      {
	my $legend = "USAGE LEGEND\n\n";
	$legend .=
	  alignCols(['*','=','Required option.'],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(['~','=',
		     join('',('Required option, but it (or a mutually ',
                              'exclusive partner) has a default value, thus ',
                              'is effectively optional.'))],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(['^','=',
		     join('',("Conditionally required option.  E.g. When 1 of ",
			      "2 mutually exclusive options must be ",
			      "supplied.  Note, if one of the 2 options has a ",
			      "default value, '~' will be preferentially ",
			      "displayed."))],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(['...','=',
		     join('',('Multiple flags or flag arguments may be ',
			      'supplied.  E.g.:'))],
		    [11,1],[0,1,1],[0,0,0]) . "\n";
	$legend .=
	  alignCols(['','','-f...','=',
		     'Multiple instances of "-f" can be supplied.'],
		    [11,1,14,1],[0,1,1,1,1],[0,0,0,0,0]);
	$legend .=
	  alignCols(['','','-f <arg...>','=',
		     join('',('Multiple arguments can be supplied to "-f".'))],
		    [11,1,14,1],[0,1,1,1,1],[0,0,0,0,0]);
	$legend .=
	  alignCols(['','','-f <arg...>...','=',
		     join('',('Multiple instances of "-f" can be supplied, ',
			      'each with multiple arguments.'))],
		    [11,1,14,1],[0,1,1,1,1],[0,0,0,0,0]) . "\n";
	$legend .=
	  alignCols(['','',
		     join('',("Argument delimiters may be displayed between ",
			      "the argument and the ellipsis (e.g. comma ",
			      "delimited would be displayed as: ",
			      "'<arg,...>').   If the the delimiter is a ",
			      "space, the arguments must all be grouped ",
			      "inside a single pair of quotes or be escaped.  ",
			      "Multiple sequential delimiters are all ",
			      "condensed to 1 (e.g. '1,,,2' = '1,2').  A ",
			      "special delimiting character of '*' indicates ",
			      "that the argument will be (bsd) globbed (glob ",
			      "patterns recognized: *,?,[],{}).  Only <file> ",
			      "and <dir> types are globbed.  Glob patterns ",
			      "must be inside quotes to associate all files ",
			      "with the preceding flag.  If multi-character ",
			      "delimiters are used, they will be detailed in ",
			      "the description."))],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(['[<arg>]','=',
		     join('',('Flags with optional arguments (e.g. <cnt>) are ',
			      'displayed inside square brackets.'))],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(['[default]','=',
		     join('',("An option's description starts with a ",
			      "description of its default value, if it has a ",
			      "default.  Note, default values are not ",
			      "displayed if they are not defined.  ",
			      "Additionally default values for flags that do ",
			      "not take arguments are always false and are ",
			      "not shown.  If negatable options (options that ",
			      'have flags starting with or without "no" - ',
			      'e.g. --flag or --noflag) have a default, only ',
			      'the flag that is the opposite of the default ',
			      'will be shown in the flag column.'))],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(["<enum>\n<a,b,c>",'=',
		     join('',("A flag that takes only one of a set of ",
			      "specific strings is an 'enumeration' and is ",
			      "indicated by the argument being represetned as ",
			      "a list of acceptable values inside angle ",
			      "brackets and delimited by '|'.  Long lists ",
			      "will be truncated and appended to the ",
			      "description."))],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(['<cnt>','=',
		     join('',('Count ("cnt") arguments are integer arguments ',
			      'whose flags can be supplied multiple times ',
			      'with or without the count argument argument ',
			      "(i.e. they're always optional and shown inside ",
			      'square brackets (see "[<arg>]" above)).  Each ',
			      'occurrence of the flag without an argument ',
			      'increments the count (from left to right) or ',
			      'can be statically set by providing the integer ',
			      'argument (negative values allowed).  Mixing ',
			      'flags with and without the count argument can ',
			      'produce unexpected results, so only use one ',
			      'style or the other.  If the flag has a default ',
			      'value, the count starts at that value.'))],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(['<dir>','=',
		     join('',('Directory.  Any dir type argument can be ',
			      'supplied a BSD glob pattern (though they must ',
			      'be inside quotes to associate them with the ',
			      'accompanying flag).'))],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(['<file>','=',
		     join('',('Any file type argument can be given a single ',
			      "dash character ('-') as an argument, which ",
			      'stands for either "read from STDIN" or "write ',
			      'to STDOUT", depending on the file flag type.  ',
			      (!defined($primary_infile_optid) ? '' :
			       "Infile option " .
			       getFlag($usage_array->[$primary_infile_optid]) .
			       " will recognize input on standard in " .
			       "automatically and thus does not require a " .
			       "dash to be supplied" .
			       (getNumInfileTypes() < 2 ? '.  ' :
				' (unless a dash is supplied to one of the ' .
				'other infile options).  ')),
			      'Only one infile option can read from STDIN in ',
			      'one run.  Any file type argument can be ',
			      'supplied a BSD glob pattern (inside quotes).'))],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(['<flt>','=',
		     join('',('Float.  E.g. a number with a decimal value.  ',
			      'Signed or unsigned.  Scientific notation is ',
			      'allowed.'))],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(['<int>','=',
		     join('',('Integer argument.  Signed or unsigned.  ',
			      'Scientific notation (without a decimal) is ',
			      'allowed.'))],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(['<sfx>','=',
		     join('',('Suffix appended to input file names.  Note, a ',
			      'dot is not added by default.  Providing an ',
			      'empty string essentially creates an output ',
			      'file name that is the same as the input file ',
			      'name, but you will get an error unless ',
			      '--overwrite is also provided.'))],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(['<stub>','=',
		     join('',('A stub argument must always be accompanied by ',
			      'input on standard in.  A stub is used as a ',
			      'file name prefix for input on standard in.  ',
			      'Stubs get <sfx> appended to them, defined by ',
			      'suffix options, to create an output file ',
			      'name.  If no stub is provided, the default ',
			      'stub used for input on standard in is ',
			      '"STDIN".'))],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(['< <file>','=',
		     join('',('If a redirect (i.e. "<") is shown among an ',
			      "option's flags, it means that it can read from ",
			      'standard in (but if no input is detected, the ',
			      'script will not wait for input).  Only 1 ',
			      'input file option can read from STDIN.'))],
		    [11,1],[0,1,1],[0,0,0]) . "\n";
	$legend .=
	  alignCols(['','','-f <stub> < <file>','=',
		     join('',('-f has the built-in ability to read from STDIN ',
			      '(without the need to supply "-") & a stub can ',
			      'optionally be supplied to name the input ',
			      'file.'))],
		    [11,1,18,1],[0,1,1,1,1],[0,0,0,0,0]);
	$legend .=
	  alignCols(['','','-f - < <file>','=',
		     join('',('Any file option has the ability to read from ',
			      'standard input if a dash is supplied to the ',
			      'flag as an argument, but note no stub can ',
			      '(yet) be set for the input file name when a ',
			      'dash is required.'))],
		    [11,1,18,1],[0,1,1,1,1],[0,0,0,0,0]) . "\n";
	$legend .=
	  alignCols(['STDIN','=',
		     join('',('"STDIN" may be mentioned in numerous places.  ',
			      'Only one input file type can take standard in ',
			      'at a time.  If an input file type has the ',
			      'built-in ability to read from standard input, ',
			      'a flag option will be presented as `< ',
			      '<file>`.  You can choose to send standard in ',
			      'to other input file types by supplying a dash ',
			      'as the file argument.  Note there is a ',
			      'difference between the built-in ability to ',
			      'read standard input and reading from STDIN ',
			      'being a default.  If the default value is ',
			      '"STDIN", the script will wait for user input ',
			      'if no file was provided.  The built-in ability ',
			      'to read from STDIN however will not wait for ',
			      'user input if no file is provided and no input ',
			      'is detected on standard in (i.e. no redirected ',
			      'input).  See "<file>" for more details.'))],
		    [11,1],[0,1,1],[0,0,0]);
	$legend .=
	  alignCols(['STDOUT','=',
		     join('',('If "STDOUT" is listed as a default for an ',
			      'output file or outfile suffix, it means that ',
			      'output will go to standard out by default ',
			      '(when no file name or suffix is defined).'))],
		    [11,1],[0,1,1],[0,0,0]);

	print($legend,"\n\n");
      }

    if($advanced > 1 ||
       ($advanced == 1 && (!defined($advanced_help) || $advanced_help eq '')))
      {
	my $header = '                 ' .
	  join("\n                 ",split(/\n/,getHeader()));

	my $odf = getOutdirFlag(undef,2);

	print("ADVANCED\n========\n\n",
	      alignCols(['* HEADER FORMAT:',
			 join('',('Unless --noheader is supplied or STANDARD ',
				  'output is going to the terminal (and not ',
				  'redirected into a file), every output ',
				  'file, including output to standard out, ',
				  'will get a header that is commented using ',
				  "the '#' character (i.e. each line of the ",
				  "header will begin with '#').  The format ",
				  'of the standard header looks like this:'))],
			[16],[0,1],[0,0]),"\n",
	      $header,"\n\n",
	      "                 The header is important for 2 reasons:\n\n",
	      alignCols(['1.',
			 join('',('It records information about how the file ',
				  'was created: user name, time, script ',
				  'version information, and the command line ',
				  'that was used to create it.'))],
			[2],[17,1],[0,0]),"\n",
	      alignCols(['2.',
			 join('',('The header is used to confirm that a file ',
				  'inside a directory that is to be output to ',
				  '(using $odf) was created by this script ',
				  'before deleting it when in overwrite ',
				  'mode.  See OVERWRITE PROTECTION below.'))],
			[2],[17,1],[0,0]),"\n",
	      alignCols(['* OVERWRITE PROTECTION:',
			 join('',('This script prevents the over-writing of ',
				  'files (unless --overwrite is provided).  A ',
				  'check is performed for pre-existing files ',
				  'before any output is generated.  It will ',
				  'even check if future output files will be ',
				  'over-written in case two input files from ',
				  'different directories have the same name ',
				  'and a common $odf.  Furthermore, before ',
				  'output starts to a given file, a last-',
				  'second check is performed in case another ',
				  'program or script instance is competing ',
				  'for the same output file.  If such a case ',
				  'is encountered, an error will be generated ',
				  "and the file will always be skipped.\n\n",
				  'Directories: When $odf is supplied with ',
				  '--overwrite, the directory and its ',
				  'contents will not be deleted.  If you ',
				  'would like an output directory to be ',
				  'automatically removed, supply --overwrite ',
				  'twice on the command line.  The directory ',
				  'will be removed, but only if all of the ',
				  'files inside it can be confirmed to have ',
				  'been created by a previous run of this ',
				  'script.  For this, headers are required to ',
				  'be in the files (i.e. the previous run ',
				  'must not have included the --noheader ',
				  'flag.  This requirement ensures that it is ',
				  'very unlikely to accidentally delete ',
				  'anything that is not intended to have been ',
				  'deleted.  If a directory cannot be ',
				  'emptied, the script will proceed with a ',
				  'warning about any files in the output ',
				  "directory it could not clean out.\n\nNote ",
				  'that individual files bearing the same ',
				  'name as a current output file will be ',
				  'overwritten regardless of a header.'))],
			[23],[0,1],[0,0]),"\n",
	     );

	print << "end_print";
* ADVANCED USER DEFAULTS:

If you find you are always supplying the same option over and over, you can save it as a default using the --save-args flag.  Run the script with --save-args along with the options and their values that you want to save and they will be included every time the script runs.  To clear the defaults, run the script with --save-args as the only parameter.

Saving *one* of the following flags changes the "default run mode":

    --usage
    --help
    --run
    --dry-run

Note: These options are not always visible in the usage output because they may be irrelevant given the defaults saved, however they are always recognized options.

The default run mode, put simply, determines what the script does when no options are provided on the command line.  Although note, the script will not run if any required options do not have values, so if the default run mode is --run, a usage (along with an error) will be printed.

Only one mode may be saved as a default run mode.

* ADVANCED FILE I/O FEATURES:

Sets of input files, each with different output directories can be supplied.  Supply each file set with an additional (e.g.) -i flag.  Wrap each set of files in quotes and separate them with spaces.

Output directories (e.g.) --outdir can be supplied multiple times in the same order so that each input file set can be output into a different directory.  If the number of files in each set is the same, you can supply all output directories as a single set instead of each having a separate --outdir flag.

Examples:

  $0 -i 'a b c' --outdir '1' -i 'd e f' --outdir '2'

    Resulting file sets: 1/a,b,c  2/d,e,f

  $0 -i 'a b c' -i 'd e f' --outdir '1 2 3'

    Resulting file sets: 1/a,d  2/b,e  3/c,f

If the number of files per set is the same as the number of directories in 1 set are the same, this is what will happen:

  $0 -i 'a b' -i 'd e' --outdir '1 2'

    Resulting file sets: 1/a,d  2/b,e

NOT this: 1/a,b 2/d,e  To do this, you must supply the --outdir flag for each set, like this:

  $0 -i 'a b' -i 'd e' --outdir '1' --outdir '2'

Other examples:

  $0 -i 'a b c' -i 'd e f' --outdir '1 2'

    Result: 1/a,b,c  2/d,e,f

  $0 -i 'a b c' --outdir '1 2 3' -i 'd e f' --outdir '4 5 6'

    Result: 1/a  2/b  3/c  4/d  5/e  6/f

If this script has multiple types of file options (which are processed together), the files which are associated with one another will be associated in the same manner as the output directories above.  Basically, if the number of files or sets of files match, they will be automatically associated in the order in which they were provided on the command line.

end_print
      }

    if($advanced == 1)
      {print('Supply `',($drm ne 'help' ? '--help ' : ''),'--extended 2` ',
             "for details on advanced interface options.\n")}
    elsif($advanced == 0)
      {print('Supply ',($drm ne 'help' ? '--help ' : ''),'--extended for ',
             "detailed help.\n")}

    if(getRunStatus() != 1 || $drm ne 'usage')
      {print("Supply --usage to see list of options.\n\n")}
    else
      {print("\n")}

    return(0);
  }

sub customUsage
  {
    my $extended       = getVarref('extended',1,1);
    my $local_extended = (defined($_[0]) ? $_[0] :
			  (defined($extended) ? $extended : 0));

    my $short = '';
    my $long  = '';

    my($short_flag_col_width,$long_flag_col_width) =
      getUsageFlagColWidths();

    assignUsageOrder();

    my $current_heading = '';
    my($flags_remainder,$short_desc_remainder,$long_desc_remainder);
    foreach my $usage_hash (sort {$a->{USAGE_ORDER} <=> $b->{USAGE_ORDER}}
			    @$usage_array)
      {
	#If there's a heading
	if($usage_hash->{HEADING} ne '')
	  {$current_heading = $usage_hash->{HEADING}}

	#Skip options based on HIDDEN, ADVANCED, and value of $extended
	next if(($usage_hash->{HIDDEN}   && $extended < 3) ||
                ($usage_hash->{ADVANCED} && $extended < 2));

	#If a heading was in a hidden or advanced option's settings and that
	#option is not a part of this usage message, it will be held onto until
	#something in that section is encountered that will be displayed
	if($current_heading ne '')
	  {
	    $long .= "$current_heading\n\n";
	    $current_heading = '';
	  }

	my $short_flags = getUsageFlags($usage_hash,1);
	my $long_flags  = getUsageFlags($usage_hash);
	my $short_desc  = $usage_hash->{SUMMARY};
	my $long_desc   = $usage_hash->{DETAILS};
	#If the enum values are too long to be displayed in the flags column &
	#were truncated (i.e. replaced with an ellipsis)
	if($usage_hash->{OPTTYPE} =~ /enum/ && $long_flags =~ /\.{3}>/)
	  {
	    my $enumvals = join(',',@{$usage_hash->{ACCEPTS}});
	    $long_desc .= "\n\nFull list of acceptable values: [$enumvals].";
	  }
	#If the array value delimiter is multi-character or otherwise does not
	#match a display value and the description doesn't mention 'delim',
	#append the delimiter pattern
	if($usage_hash->{OPTTYPE} =~ /_array/ && $long_desc !~ /delim/i)
	  {
	    my $disp_delim = getDisplayDelimiter($usage_hash->{DELIMITER},
						 $usage_hash->{OPTTYPE},
						 $usage_hash->{ACCEPTS});

	    if(defined($disp_delim) && length($disp_delim) > 1)
	      {
		my $qm = quotemeta($disp_delim);
		#This assumes the presence of any regular expression character
		#means it's a regular expression
		$long_desc .= "\n\nDelimiting " .
		  ($qm ne $disp_delim ? 'pattern' : 'string') .
		    ": [$disp_delim].";
	      }
	  }

	my $mutually_required = 0;
	my $hidden_mutexes    = 0;
	my $default_mutexes   = 0;
	if(exists($exclusive_lookup->{$usage_hash->{OPTION_ID}}))
	  {
	    my $optid = $usage_hash->{OPTION_ID};

	    foreach my $exclid (keys(%{$exclusive_lookup->{$optid}}))
	      {
		my $num_hidden = 0;

		#If this option is part of a mutually exclusive group where one
		#is required
		if(exists($mutual_params->{$exclid}) &&
		   exists($mutual_params->{$exclid}->{REQUIRED}) &&
		   $mutual_params->{$exclid}->{REQUIRED})
		  {$mutually_required = 1}

		my $num = scalar(@{$exclusive_options->[$exclid]}) - 1;
		foreach my $oid (@{$exclusive_options->[$exclid]})
		  {
		    if($usage_array->[$oid]->{HIDDEN})
		      {$num_hidden++}
		    if(hasDefault($usage_array->[$oid]))
		      {$default_mutexes = 1}
		  }
		if($num_hidden >= $num)
		  {$hidden_mutexes = 1}
	      }
	  }
	my $required = '';
	if((exists($usage_hash->{REQUIRED}) &&
	    defined($usage_hash->{REQUIRED}) && $usage_hash->{REQUIRED}) ||
	   $mutually_required)
	  {
	    if($mutually_required)
	      {
		if($default_mutexes)
		  {
                    #Only show the ~ in advanced mode
                    $required = $local_extended > 1 ? '~' : '';
                  }
		#1 of 2 tagteam options is required and 1 is hidden
		elsif($hidden_mutexes)
		  {$required = '*'}
		else
		  {$required = '^'}
	      }
	    elsif(hasDefault($usage_hash))
	      {
                #Only show the ~ in advanced mode
                $required = $local_extended > 1 ? '~' : '';
              }
	    else
	      {$required = '*'}
	  }

	#Add the default string if it's defined and not already manually added
	#to the short description
	my $default = displayDefault($usage_hash);
	if($default ne '' && defined($short_desc) && $short_desc ne '' &&
	   $short_desc !~ /^\[/)
	  {
	    $short_desc = $default . $short_desc;

	    if($short_desc =~ /^\[[^\]\}]*\]\s*\{[^\}]*\}/ &&
	       $short_desc !~ /^\[[^\]\}]*\]\s*\{[^\}]*\}\s/)
	      {$short_desc =~ s/\}\s*/\} /}
	    elsif($short_desc =~ /^\[[^\]]*\]\s*[^\{]/ &&
	       $short_desc !~ /^\[[^\]]*\]\s/)
	      {$short_desc =~ s/\]\s*/\] /}
	  }

	#Add the default string if it's defined and not already manually added
	#to the long description
	if($default ne '' && $long_desc !~ /^\[/)
	  {
	    $long_desc = $default . $long_desc;

	    if($long_desc =~ /^\[[^\]\}]*\]\s*\{[^\}]*\}/ &&
	       $long_desc !~ /^\[[^\]\}]*\]\s*\{[^\}]*\}\s/)
	      {$long_desc =~ s/\}\s*/\} /}
	    elsif($long_desc =~ /^\[[^\]]*\]\s*[^\{]/ &&
	       $long_desc !~ /^\[[^\]]*\]\s/)
	      {$long_desc =~ s/\]\s*/\] /}
	  }

	if(defined($short_desc) && $short_desc ne '')
	  {$short .= alignCols([$required,$short_flags,$short_desc],
			       [1,$short_flag_col_width],
			       [0,1,2],
			       [0,2,0])}
	if(defined($long_desc) && $long_desc ne '')
	  {$long .= alignCols([$required,$long_flags,$long_desc],
			      [1,$long_flag_col_width],
			      [0,1,2],
			      [0,2,0]) . "\n"}
	elsif(defined($short_desc) && $short_desc ne '')
	  {$long .= alignCols([$required,$long_flags,$short_desc],
			      [1,$long_flag_col_width],
			      [0,1,2],
			      [0,2,0]) . "\n"}
      }

    $short .= "\n";

    return($short,$long);
  }

sub isEffectivelyRequired
  {
    my $usage_hash = $_[0];

    my $required          = 0;
    my $mutually_required = 0;
    my $hidden_mutexes    = 0;
    my $default_mutexes   = 0;
    if(exists($exclusive_lookup->{$usage_hash->{OPTION_ID}}))
      {
        my $optid = $usage_hash->{OPTION_ID};

        foreach my $exclid (keys(%{$exclusive_lookup->{$optid}}))
          {
            my $num_hidden = 0;

            #If this option is part of a mutually exclusive group where one
            #is required
            if(exists($mutual_params->{$exclid}) &&
               exists($mutual_params->{$exclid}->{REQUIRED}) &&
               $mutual_params->{$exclid}->{REQUIRED})
              {$mutually_required = 1}

            my $num = scalar(@{$exclusive_options->[$exclid]}) - 1;
            foreach my $oid (@{$exclusive_options->[$exclid]})
              {
                if($usage_array->[$oid]->{HIDDEN})
                  {$num_hidden++}
                if(hasDefault($usage_array->[$oid]))
                  {$default_mutexes = 1}
              }
            if($num_hidden >= $num)
              {$hidden_mutexes = 1}
          }
      }

    if((exists($usage_hash->{REQUIRED}) &&
        defined($usage_hash->{REQUIRED}) && $usage_hash->{REQUIRED}) ||
       $mutually_required)
      {
        if(($mutually_required && !$default_mutexes) ||
           (!$mutually_required && !hasDefault($usage_hash)))
          {$required = 1}
      }

    return($required);
  }

sub assignUsageOrder
  {
    my $num_options = scalar(@$usage_array);
    my %taken_nums  = ();
    my $warned      = 0;
    foreach my $uh (grep {defined($_->{USAGE_ORDER})} @$usage_array)
      {
	my $position = $uh->{USAGE_ORDER};
	if($position < 0)
	  {
	    $position = ($uh->{USAGE_ORDER} < 0 ?
			 $num_options + 1 + $uh->{USAGE_ORDER} :
			 $uh->{USAGE_ORDER});
	    if($position < 0)
	      {
		warning("Negative usage order out of bounds.  Using modulus.");
		$position = $num_options + 1 + ($position % $num_options);
	      }
	    $uh->{USAGE_ORDER} = $position;
	  }
	if(!$warned && exists($taken_nums{$position}))
	  {
	    warning("Multiple options assigned to the same position in the ",
		    "usage order.");
	    $warned = 1;
	  }
	$taken_nums{$position} = 0;
      }
    my @avail_nums  = (grep {!exists($taken_nums{$_})}
		       (1..scalar(@$usage_array)));
    foreach my $uh (grep {!defined($_->{USAGE_ORDER})} @$usage_array)
      {$uh->{USAGE_ORDER} = shift(@avail_nums)}
  }

##TODO: Add support for setting multiple times. (Currently only called by usage/
##      help.)
sub getWindowWidth
  {
    if(!defined($window_width))
      {
	$window_width = $window_width_def;
	#If the output is piped, or to a file, return the default
	if(isStandardOutputToTerminal())
	  {
            my $orig_sigd = $SIG{__DIE__};
            $SIG{__DIE__} = sub {debug({DETAIL => 'Term::ReadKey eval ERROR: ',
                                        LEVEL  => -2},@_)};
	    my $present   = eval('use Term::ReadKey;1');
            $SIG{__DIE__} = $orig_sigd;
            if(!$present)
              {return($window_width)}
	    $window_width = (GetTerminalSize())[0];
	  }
	return($window_width);
      }
    return($window_width);
  }

sub getUsageFlagColWidths
  {
    my $extended             = getVarref('extended',1,1);
    my $max_flag_col_width   = 24;
    my $short_flag_col_width = 0;
    my $long_flag_col_width  = 0;

    foreach my $usage_hash (grep {(!$_->{HIDDEN} && !$_->{ADVANCED}) ||
				    ($_->{HIDDEN} && $extended > 2) ||
				       ($_->{ADVANCED} && !$_->{HIDDEN} &&
					$extended > 1)} @$usage_array)
      {
	my $short_flags = getUsageFlags($usage_hash,1);
	my $long_flags  = getUsageFlags($usage_hash);

	if(defined($usage_hash->{SUMMARY}) && $usage_hash->{SUMMARY} ne '' &&
	   length($short_flags) > $short_flag_col_width)
	  {$short_flag_col_width = length($short_flags)}

	if($long_flag_col_width < $max_flag_col_width)
	  {
	    foreach my $long_flag (split(/\n/,$long_flags))
	      {
		if(length($long_flag) > $long_flag_col_width)
		  {
		    $long_flag_col_width = length($long_flag);
		    last if($long_flag_col_width >= $max_flag_col_width);
		  }
	      }
	  }

	last if($long_flag_col_width  >= $max_flag_col_width &&
	        $short_flag_col_width >= $max_flag_col_width);
      }

    if($long_flag_col_width >= $max_flag_col_width)
      {$long_flag_col_width = $max_flag_col_width}
    if($short_flag_col_width >= $max_flag_col_width)
      {$short_flag_col_width = $max_flag_col_width}

    return($short_flag_col_width,$long_flag_col_width);
  }

#Takes the usage hash of 1 option and returns the flags with arguments as they
#are to be displayed in the detailed usage output.
sub getUsageFlags
  {
    my $usghash = $_[0];
    my $minmode = $_[1];

    #Prepare the list of flags
    my @flaglist = @{$usghash->{OPTFLAGS}};
    if($usghash->{FLAGLESS})
      {unshift(@flaglist,'')}

    debug({LEVEL => -1},"Starting flag list: [",join(',',@flaglist),"].");

    my $flagstr =
      join("\n",
	   map {
	     #append a space unless it's an empty string.  This allows us to
	     #process the flagless options the same as the flagged options
	     $_ .= ($_ eq '' ? '' : ' ');

	     #Prepare the enumeration string
	     my $en = '';
	     if($usghash->{OPTTYPE} =~ /enum/)
	       {
		 $en = join(',',@{$usghash->{ACCEPTS}});
		 if(length($en) > 60)
		   {$en =~ s/(.{57}).*/$1.../}
	       }

	     my $dl = '';
	     if($usghash->{OPTTYPE} =~ /_array/)
	       {
		 $dl = getDisplayDelimiter($usghash->{DELIMITER},
					   $usghash->{OPTTYPE},
					   $usghash->{ACCEPTS});
		 if(defined($dl))
		   {
		     if(length($dl) > 1)
		       {$dl = '...'}
		     else
		       {$dl = "$dl..."}
		   }
		 else
		   {$dl = ''}
	       }

	     if($usghash->{OPTTYPE} eq 'bool')
	       {
		 s/ $//;
		 $_;
	       }
	     elsif($usghash->{OPTTYPE} eq 'negbool')
	       {
		 s/ $//;
		 my $f  = $_;
		 my $nf = $_;
		 $nf =~ s/^-+//;
		 #If flag is 1 character or already has dashes, prepend w/ dash
		 if($nf =~ /-/ || length($nf) == 1)
		   {$nf = "--no-$nf"}
		 else
		   {$nf = "--no$nf"}
		 my $def = defined($usghash->{DEFAULT_USR}) ?
		   $usghash->{DEFAULT_USR} : $usghash->{DEFAULT_PRG};
		 if(!defined($def))
		   {($f,$nf)}
		 elsif($def)
		   {$nf}
		 else
		   {$f}
	       }
	     elsif($usghash->{OPTTYPE} eq 'count')
	       {$_ . "[<cnt>]"}
	     elsif($usghash->{OPTTYPE} eq 'string')
	       {"$_<str>"}
	     elsif($usghash->{OPTTYPE} eq 'integer')
	       {"$_<int>"}
	     elsif($usghash->{OPTTYPE} eq 'float')
	       {"$_<flt>"}
	     elsif($usghash->{OPTTYPE} eq 'enum')
	       {"$_<$en>"}

	     elsif($usghash->{OPTTYPE} eq 'string_array' ||
		   $usghash->{OPTTYPE} eq 'string_array2d')
	       {"$_<str$dl>..."}
	     elsif($usghash->{OPTTYPE} eq 'integer_array' ||
		   $usghash->{OPTTYPE} eq 'integer_array2d')
	       {"$_<int$dl>..."}
	     elsif($usghash->{OPTTYPE} eq 'float_array' ||
		   $usghash->{OPTTYPE} eq 'float_array2d')
	       {"$_<flt$dl>..."}
	     elsif($usghash->{OPTTYPE} eq 'enum_array' ||
		   $usghash->{OPTTYPE} eq 'enum_array2d')
	       {"$_<{$en}$dl>..."}

	     elsif($usghash->{OPTTYPE} eq 'infile' ||
		   $usghash->{OPTTYPE} eq 'outfile')
	       {"$_<file*...>..."}
	     elsif($usghash->{OPTTYPE} eq 'logfile')
	       {"$_<file>"}
	     elsif($usghash->{OPTTYPE} eq 'outdir')
	       {"$_<dir*...>..."}
	     elsif($usghash->{OPTTYPE} eq 'suffix' ||
		   $usghash->{OPTTYPE} eq 'logsuff')
	       {"$_<sfx>"}
	     else
	       {"$_ ?ERROR?"}
	   } @flaglist) .

	     #Append stdin & stub/dash for primary/non-primary input files
	     ($usghash->{OPTTYPE} eq 'infile' ?
	      ($usghash->{PRIMARY} ? "\n< <file>\n" .
	       (hasLinkedSuffix($usghash) ?
		getDefaultFlag($usghash->{OPTFLAGS}) . ' <stub> < <file>' :
		'') : "\n" . getDefaultFlag($usghash->{OPTFLAGS}) .
	       ' - < <file>') : '') .

		 ($usghash->{HIDDEN} ? "\n[HIDDEN-OPTION]" : '');

    if($minmode)
      {$flagstr =~ s/\n.*//s}

    debug({LEVEL => -1},"Returning flagstr: [$flagstr].");

    return($flagstr);
  }

#This sub takes a usage hash and determines whether there exists an outfile
#suffix type that is linked to it.
sub hasLinkedSuffix
  {
    my $usghash = $_[0];
    if($usghash->{OPTTYPE} ne 'infile')
      {
	error("Option type not infile: [$usghash->{OPTTYPE}].");
	return(0);
      }

    return(scalar(grep {$_->{OPTTYPE} eq 'suffix' &&
			  $_->{PAIRID} == $usghash->{OPTION_ID}}
		  @$usage_array));
  }

sub showDefault
  {
    my $usg_hash = $_[0];

    my $type     = $usg_hash->{OPTTYPE};
    my $is_udef  = $usg_hash->{SUPPLIED_UDF};
    my $def      = getDefault($usg_hash);
    my $dispdef  = $usg_hash->{DISPDEF};

    #Always show a defined display default
    if(!$is_udef && defined($dispdef))
      {return(1)}
    elsif($type ne 'bool' && $type ne 'negbool' && $type ne 'count')
      {return(1)}
    elsif($type eq 'bool')
      {return(defined($def) && $def ne '' && $def ne '0')}
    #Never show a negbool default (unless dispdef is true above)
    elsif($type eq 'negbool')
      {return(0)}
    #Only show a count's def if it is non-0
    elsif($type eq 'count')
      {return(defined($def) && $def != 0)}

    return(1);
  }

sub displayDefault
  {
    my $usage_hash = $_[0];
    my $disp       = '';

    if(showDefault($usage_hash))
      {
	my $undef    = '';
        my $emptystr = '[] ';
        #Empty string defaults for these types make no sense and imply the
        #default is undefined, so don't display square brackets
        if($usage_hash->{OPTTYPE} =~ /file/ ||
           $usage_hash->{OPTTYPE} =~ /integer/ ||
           $usage_hash->{OPTTYPE} =~ /float/ ||
           $usage_hash->{OPTTYPE} =~ /enum/ ||
           $usage_hash->{OPTTYPE} eq 'outdir')
          {$emptystr = ''}

        my $defval = getDefault($usage_hash);

	if(defined($defval) && hasValue($usage_hash->{OPTTYPE},
                                        $usage_hash->{DEFAULT_USR},
                                        1))
	  {
	    if(ref($defval) eq '')
	      {
		if($defval eq '')
		  {$disp = $emptystr}
		else
		  {
		    if($usage_hash->{OPTTYPE} eq 'bool' && $defval)
		      {$disp = "[On] "}
		    else
		      {$disp = "[$defval] "}
		  }
	      }
	    elsif(ref($defval) eq 'ARRAY')
	      {
		$disp = displayDefaultArray($defval);
		if(defined($disp))
		  {$disp = "[$disp] "}
		else
		  {$disp = $undef}
	      }
	    else
	      {error("Invalid/unsupported user default reference.")}
	  }
	elsif(!$usage_hash->{SUPPLIED_UDF} && defined($usage_hash->{DISPDEF}))
	  {
	    if($usage_hash->{DISPDEF} eq '')
	      {
		#Special case: treat empty string as no default if the
		#programmer supplied a code reference and no DEFAULT, regardless
		#of option type
		if(!canGetRealDefault($usage_hash) && !defined($defval))
		  {$disp = ''}
		else
		  {$disp = $emptystr}
	      }
	    else
	      {$disp = "[$usage_hash->{DISPDEF}] "}
	  }
	elsif(defined($defval))
	  {
	    if(ref($defval) eq '')
	      {
		if($defval eq '')
		  {$disp = $emptystr}
		else
		  {
		    if($usage_hash->{OPTTYPE} eq 'bool' && $defval)
		      {$disp = "[On] "}
		    else
		      {$disp = "[$defval] "}
		  }
	      }
	    elsif(ref($defval) eq 'ARRAY')
	      {
		$disp = displayDefaultArray($defval);
		if(defined($disp))
		  {$disp = "[$disp] "}
		else
		  {$disp = $undef}
	      }
	    else
	      {error("Invalid/unsupported default reference.")}
	  }
	elsif(!canGetRealDefault($usage_hash))
	  {
            #TODO: Add DEBUG param to warning() params
	    if(isDebug())
	      {warning('Cannot retrieve display default value for [',
		       getBestFlag($usage_hash),'].  Default in usage will be ',
		       'displayed as "default unknown".',
		       {DETAIL => ('The script author supplied a subroutine ' .
				   'reference for this option and did not ' .
				   'supply a display default value ' .
				   '(DISPDEF).  Users can supply a default ' .
				   'using [' .
				   getBestFlag($usage_lookup->{save_args}) .
				   '].')})}
	    $disp = '[default unknown] ';
	  }
	else
	  {$disp = $undef}
      }

    return($disp);
  }

sub displayDefaultArray
  {
    my $default  = $_[0];
    my $extended = getVarref('extended',1,1);
    my($def_str);

    if(defined($default) && ref($default) eq 'ARRAY' &&
       scalar(grep {ref($_) ne 'ARRAY'} @$default) == 0 &&
       scalar(grep {my $a=$_;scalar(grep {ref($_) ne ''} @$a)} @$default) == 0)
      {
	my $addparens =
	  (scalar(@$default) > 1 ||
	   (scalar(@$default) == 1 && scalar(@{$default->[0]}) > 1));
	$def_str = ($addparens ? '(' : '') .
	  join('),(',map {my $a = $_;
			  join(',',map {defined($_) ? $_ : 'undef'} @$a)}
	       @$default) . ($addparens ? ')' : '');
      }
    elsif(defined($default) && ref($default) eq 'ARRAY' &&
	  scalar(grep {ref($_) ne ''} @$default) == 0)
      {
	$def_str  = join(',',map {defined($_) ? $_ : 'undef'} @$default);
      }
    elsif(defined($default))
      {
	warning("Default array value supplied to displayDefaultArray must be ",
		"a reference to an array of scalars or a reference to an ",
		"array of references to arrays of scalars.");
      }

    #If the default string is defined, extended is < 3, and the length is less
    #than the default display max, shorten the string with an ellipsis
    if(defined($def_str) && $extended < 3 && length($def_str) < $dispdef_max)
      {$def_str = clipStr($def_str,$dispdef_max)}

    return($def_str);
  }

#$usage_hash->{DISPDEF} is only for display purposes. This sub checks the actual
#default value either in the reference variable or the default saved elsewhere
sub hasDefinedDefault
  {
    my $usage_hash = $_[0];

    #For now, we will assume that the display default having a defined value
    #that's not an empty string means that there really is a default set (which
    #may not be true)
    ##TODO: Check the actual default, which includes checking things like the
    #default_infiles_array, etc.
    if(hasDefinedDisplayDefault($usage_hash) ||
       hasDefinedActualDefault($usage_hash))
      {return(1)}

    return(0);
  }

sub hasDefinedDisplayDefault
  {
    my $usage_hash = $_[0];
    return(defined($usage_hash->{DISPDEF}) && $usage_hash->{DISPDEF} ne '');
  }

sub hasDefinedActualDefault
  {
    my $usage_hash = $_[0];

    if(!canGetRealDefault($usage_hash))
      {
	debug("Unable to determine default value for option [",
	      getDefaultFlag($usage_hash->{OPTFLAGS}),"].");
	return(0);
      }

    my $def = getRealDefault($usage_hash);

    if($usage_hash->{OPTTYPE} eq 'string'  ||
       $usage_hash->{OPTTYPE} eq 'integer' ||
       $usage_hash->{OPTTYPE} eq 'float'   ||
       $usage_hash->{OPTTYPE} eq 'enum'    ||
       $usage_hash->{OPTTYPE} eq 'bool'    ||
       $usage_hash->{OPTTYPE} eq 'negbool' ||
       $usage_hash->{OPTTYPE} eq 'count'   ||
       $usage_hash->{OPTTYPE} eq 'suffix'  ||
       $usage_hash->{OPTTYPE} eq 'logfile' ||
       $usage_hash->{OPTTYPE} eq 'logsuff')
      {return(defined($def))}
    elsif($usage_hash->{OPTTYPE} eq 'string_array'  ||
	  $usage_hash->{OPTTYPE} eq 'integer_array' ||
	  $usage_hash->{OPTTYPE} eq 'float_array'   ||
	  $usage_hash->{OPTTYPE} eq 'enum_array')
      {return(defined($def) && scalar(@$def))}
    elsif($usage_hash->{OPTTYPE} eq 'string_array2d'  ||
	  $usage_hash->{OPTTYPE} eq 'integer_array2d' ||
	  $usage_hash->{OPTTYPE} eq 'float_array2d'   ||
	  $usage_hash->{OPTTYPE} eq 'enum_array2d'    ||
	  $usage_hash->{OPTTYPE} eq 'infile'          ||
	  $usage_hash->{OPTTYPE} eq 'outfile'         ||
	  $usage_hash->{OPTTYPE} eq 'outdir')
      {return(defined($def) && scalar(@$def) &&
	      scalar(grep {scalar(@$_)} @$def))}

    debug("Unknown option type [",getDefaultFlag($usage_hash->{OPTTYPE}),"].");

    return(0);
  }

sub getRealDefault
  {
    my $usage_hash = $_[0];

    if(scalar(grep {$usage_hash->{OPTTYPE} eq $_}
	      ('string','integer','float','bool','negbool','count','enum',
	       'suffix','logfile','logsuff')))
      {
	#If the supplied reference is to a scalar, return the scalar value
	if(defined($usage_hash->{VARREF_PRG}) &&
	   ref($usage_hash->{VARREF_PRG}) eq 'SCALAR' &&
	   defined(${$usage_hash->{VARREF_PRG}}))
	  {return(${$usage_hash->{VARREF_PRG}})}

	#Otherwise (i.e. it's a CODE reference), return undef
	return(undef);
      }
    elsif(scalar(grep {$usage_hash->{OPTTYPE} eq $_}
		 ('string_array','integer_array','float_array',
		  'string_array2d','integer_array2d','float_array2d',
		  'infile','outfile','outdir')))
      {
	if(defined($usage_hash->{VARREF_PRG}) &&
	   ref($usage_hash->{VARREF_PRG}) eq 'ARRAY')
	  {return(scalar(copyArray($usage_hash->{VARREF_PRG})))}
	return(undef);
      }
    else
      {
	debug("Unknown option type for flag [",
	      getDefaultFlag($usage_hash->{OPTFLAGS}),
	      "]: [$usage_hash->{OPTTYPE}].");

	return($usage_hash->{VARREF_PRG});
      }
  }

#Takes: usage hash
#This says whether or not it's possible to access the real default value.  The
#real default value is the value assigned to the variable the programmer is
#using in main and which they supplied to one of the add*Option methods.  We
#cannot access that value only if the programmer supplied a code reference using
#addOption or addOptions (i.e. types 'string', 'integer', 'float', 'bool',
#'negbool', 'count', or 'enum').  Other types can have code references supplied
#to Getopt::Long because we maintain their defaults internally
sub canGetRealDefault
  {return(ref($_[0]->{VARREF_PRG}) ne 'CODE')}

#Globals used: $help_summary, $advanced_help
sub customHelp
  {
    my $ignore = defined($_[0]) ? $_[0] : 0;  #Ignore unset FORMAT descriptions

    my $extended       = getVarref('extended',1,1);
    my $local_extended = (defined($_[1]) ? $_[1] :               #Advanced help
			  (defined($extended) ? $extended : 0));

    my $out = '';

    my $summary_flag = 'WHAT IS THIS:';
    my $summary = (defined($help_summary) ? $help_summary :
		   join('','No script description available.'));

    $out .= alignCols(['*',$summary_flag,$summary],
		      [1,14],
		      [0,1,2],
		      [0,0,0]) . "\n" if(defined($help_summary) || !$ignore);

    #Now let's construct the custom advanced help string.
    if($local_extended && defined($advanced_help) && $advanced_help ne '')
      {
	$out .= alignCols(['*','DETAILS:',$advanced_help],
			  [1,14],
			  [0,1,2],
			  [0,0,0]) . "\n";
      }

    #For each input file type that is not hidden or is primary (of which there
    #can be only 1, BTW)
    foreach my $usage_hash (grep {$_->{OPTTYPE} eq 'infile' &&
				    ($local_extended > 1 || !$_->{HIDDEN} ||
				     $_->{PRIMARY})}
			    @$usage_array)
      {
	my $flag = "INPUT FORMAT:\n" . join(',',@{$usage_hash->{OPTFLAGS}});
	if($usage_hash->{HIDDEN} && $usage_hash->{PRIMARY})
	  {
	    $flag = "STDIN FORMAT:";
	    #Include the hidden flags if extended > 1
	    if($local_extended > 1)
	      {$flag .= "\n" . join(',',@{$usage_hash->{OPTFLAGS}})}
	    if($usage_hash->{HIDDEN})
	      {$flag .= ($usage_hash->{FLAGLESS} || $local_extended <= 1 ?
			 "\n" : ',') . '[HIDDEN-OPTION]'}
	  }
	elsif($usage_hash->{HIDDEN})
	  {$flag .= ($usage_hash->{FLAGLESS} ? '' : ',') . '[HIDDEN-OPTION]'}

	my $desc = $usage_hash->{FORMAT};
	if(!defined($desc) || $desc eq '')
	  {
	    next if($ignore);
	    $desc = join('','No format description available.');
	  }

	$out .= alignCols(['*',$flag,$desc],
			  [1,14],
			  [0,1,2],
			  [0,0,0]) . "\n";
      }

    #Keep track of the tagteam output options that have been processed
    my $seen_ttids = {};

    #For each output file type that is either part of a tagteam, is not hidden,
    #or is primary.  (We'll worry about hidden tagteams inside the loop.)
    foreach my $usage_hash (grep {($_->{OPTTYPE} eq 'outfile' ||
				   $_->{OPTTYPE} eq 'suffix') &&
				     ($_->{TAGTEAM} || !$_->{HIDDEN} ||
				      $_->{PRIMARY} || $local_extended > 1)}
			    @$usage_array)
      {
	#If this is a suffix linked to an outfile type, skip it completely -
	#This is just an internal way of code re-use
	if($usage_hash->{HIDDEN} && $usage_hash->{OPTTYPE} eq 'suffix' &&
	   $usage_array->[$usage_hash->{PAIRID}]->{OPTTYPE} eq 'outfile')
	  {next}

	#If this option is a part of a tagteam
	if($usage_hash->{TAGTEAM})
	  {
	    my $ttid = $usage_hash->{TAGTEAMID};

	    #If this tagteam has already been done, skip it
	    next if(exists($seen_ttids->{$ttid}));
	    $seen_ttids->{$ttid}++;

	    #Obtain the usage information from the tagteam hash
	    $usage_hash = $outfile_tagteams->{$ttid};

	    #The tagteam usage hash has its own hidden value (if both of its
	    #options are hidden), so we need to check HIDDEN again
	    next if($usage_hash->{HIDDEN} && $local_extended < 2 &&
                    !$usage_hash->{PRIMARY});
	  }

	my $flag = '';

	#Create the section title in the header
	if($usage_hash->{HIDDEN} && $usage_hash->{PRIMARY})
	  {$flag .= "STDOUT FORMAT:"}
	else
	  {$flag .= "OUTPUT FORMAT:"}

	#Append the flags to the header as a sub-title if not hidden
	if(!$usage_hash->{HIDDEN} || $local_extended > 1)
	  {$flag .= "\n" . join(',',@{$usage_hash->{OPTFLAGS}})}
	if($usage_hash->{HIDDEN})
	  {$flag .= "\n[HIDDEN-OPTION]"}

	my $desc = $usage_hash->{FORMAT};

	if(!defined($desc) || $desc eq '')
	  {
	    next if($ignore);
	    $desc = join('',('The author of this script has not provided ',
			     'a format description for this output file ',
			     'type.  Please add a description using one of ',
			     'the addOutfileOption or addOutfileSuffixOption ',
			     'methods.'));
	  }

	$out .= alignCols(['*',$flag,$desc],
			  [1,14],
			  [0,1,2],
			  [0,0,0]) . "\n";
      }

    return($out);
  }

sub sum
  {
    my $sum = 0;
    $sum += $_ foreach(@_);
    return($sum);
  }

sub alignCols
  {
    my $column_vals  = $_[0]; #array - 1 row, but cells may have hard returns
    my $col_widths   = $_[1]; #array - may leave off last col or all but 1
    my $gap_widths   = $_[2]; #array - starts with the indent size
    my $wrap_indents = $_[3]; #array - soft-wrap indent sizes

    my $term_width = getWindowWidth();

    #Validate the gap widths
    if(!defined($gap_widths))
      {$gap_widths = [0,map {1} 1..$#{$column_vals}]}
    elsif(scalar(@$gap_widths) == 1)
      {
	if(scalar(@$column_vals) > 1)
	  {
	    my $tmp = $gap_widths->[0];
	    $gap_widths = [0,map {$tmp} 1..$#{$column_vals}];
	  }
      }
    elsif(scalar(@$gap_widths) == $#{$column_vals})
      {unshift(@$gap_widths,0)}
    elsif(scalar(@$gap_widths) != scalar(@$column_vals))
      {
	error("Invalid number of gap widths [",scalar(@$gap_widths),
	      "] versus number of column values: [",scalar(@$column_vals),"].");
	return('');
      }

    #Validate the column widths
    if(scalar(@$column_vals) != scalar(@$col_widths))
      {
	if($#{$column_vals} == scalar(@$col_widths))
	  {push(@$col_widths,$term_width - sum(@$col_widths,@$gap_widths))}
	elsif(scalar(@$col_widths) == 1)
	  {
	    my $tmp = $col_widths->[0];
	    $col_widths = [(map {$tmp} 1..$#{$column_vals}),
			   $term_width - sum(@$col_widths,@$gap_widths)];
	  }
	else
	  {
	    error("Invalid number of column widths [",scalar(@$col_widths),"] ",
		  "versus number of column values [",scalar(@$column_vals),
		  "].");
	    return('');
	  }

	if($col_widths->[-1] < 1)
	  {
	    warning("Window width [$term_width] too small for specified ",
		    "column widths [",
		    join(',',(@$col_widths)[0..($#{$col_widths}-1)]),"].",
		    {DETAIL => 'No room is left for the last column'});
	    return('');
	  }
      }

    #Validate the soft-wrap indents
    if(!defined($wrap_indents))
      {$wrap_indents = [map {0} 0..$#{$column_vals}]}
    elsif(scalar(@$wrap_indents) < scalar(@$column_vals))
      {
	while(scalar(@$wrap_indents) < scalar(@$column_vals))
	  {push(@$wrap_indents,0)}
      }
    elsif(scalar(@$wrap_indents) > scalar(@$column_vals))
      {
	error("Invalid number of soft-wrap indents [",scalar(@$wrap_indents),
	      "] versus number of column values: [",scalar(@$column_vals),"].");
	return('');
      }

    my($line,$out);
    my @remainders = @$column_vals;
    while(scalar(grep {$_ ne ''} @remainders))
      {
	$line = '';

	foreach my $index (0..$#{$column_vals})
	  {
	    my $remainder   = $remainders[$index];
	    my $gap_width   = $gap_widths->[$index];
	    my $col_width   = $col_widths->[$index];
	    my $wrap_indent = $wrap_indents->[$index];

	    if($index > 0)
	      {
		#Append spaces to fill up to the current column
		$line .= ' ' x (sum((@$col_widths)[0..($index - 1)],
				    (@$gap_widths)[0..($index - 1)]) -
				length($line));
	      }

	    #Add the gap
	    $line .= ' ' x $gap_width;

	    if(length($remainder) > $col_width ||
	       $remainder !~ /^[^\n]{$col_width}\n./s)
	      {
		my $soft_wrap = 1;
		my $current = substr($remainder,0,$col_width);
		my $next_char =
		  length($remainder) > $col_width ?
		    substr($remainder,$col_width,1) : '';
		my $added_hyphen = 0;
		if($current =~ /^[^\n]*\n\n/)
		  {
		    $current =~ s/(?<=\n)\n.*//s;
		    $soft_wrap = 0;
		  }
		elsif($current =~ /\n/)
		  {
		    $current =~ s/(?<=\n).*//s;
		    $soft_wrap = 0;
		  }
		elsif(#The random chop didn't just happened to be a valid spot
		      $next_char ne "\n" && $next_char ne '' &&
		      $next_char ne ' ' &&
		      !($current =~ /(?<=[a-zA-Z])-$/ &&
			$next_char =~ /[a-zA-Z]/))
		  {
		    #$current =~ s/(.*)\b\{lb}\s*\S+/$1/;
		    if(length($current) == $col_width)
		      {
			my($dashwrap,$commawrap,$spacewrap);
			$dashwrap = $commawrap = $spacewrap = $current;

			#Try to break up the current cell value at the last
			#dash, if one exists that's between letters of a
			#reasonable-long word (don't break on really-long words,
			#which might be aligned DNA or some other block of
			#characters)
			$dashwrap =~ s/(.*[a-zA-Z]-)(?=[a-zA-Z])\S{1,20}$/$1/;

			#Try to break up the current cell value at the last
			#comma, if one exists and is not followed by any of the
			#following: close-bracket, comma, quote, colon, dot, or
			#semicolon
			my $nowrapcomma = '[\.,\'";:\)\]\}\>]';
			$commawrap =~ s/(.*[^,],)(?!$nowrapcomma)\S.*/$1/;

			#Unless the string ends with spaces
			unless($spacewrap =~ s/\s+$//)
			  {
			    #Try to break up the current cell value at the last
			    #space, if one exists that's not followed by
			    #something that looks longer than a real word or a
			    #line- or thought-ending character, like a period,
			    #close-bracket, colon, comma, semicolon, exclamation
			    #point - or event what may be considered a footnote,
			    #like asterisk, up-arrow, or tilde.
			    my $nowrapspc = '[\.,;:\)\]\}\>\!\*\^\~]';
			    $spacewrap =~
			      s/(.*\S)\s+((?!$nowrapspc)\S.{0,20})$/$1/;
			  }

			#If both were trimmed
			if(length($dashwrap) < length($current) &&
			   length($commawrap) < length($current))
			  {
			    #Keep the longer one
			    $current = (length($dashwrap) > length($commawrap) ?
					$dashwrap : $commawrap);
			  }
			elsif(length($dashwrap) < length($current))
			  {$current = $dashwrap}
			else
			  {$current = $commawrap}

			if(length($spacewrap) < $col_width &&
			   (length($current) == $col_width ||
			    length($spacewrap) > length($current)))
			  {$current = $spacewrap}
		      }
		    if(length($current) == $col_width && $col_width > 1 &&
		       $current !~ /\s$/ && $current !~ /^\s/)
		      {
			#Force a dash if valid
			if($current =~ s/[A-Za-z]$/-/)
			  {$added_hyphen = 1}
		      }
		  }

		if(length($current) == $col_width && $next_char eq "\n")
		  {$soft_wrap = 0}

		$current =~ s/[ \t]+$//;
		#If the line was empty (i.e. the only character was \n)
		if($current eq '')
		  {
		    if($remainder =~ /^\n(.*)/s)
		      {$remainder = $1}
		  }
		else
		  {
		    my $pattern = $current;
		    chop($pattern) if($added_hyphen);
		    if($remainder =~ /\Q$pattern\E *(.*)/s)
		      {
			$remainder = $1;
			$remainder =~ s/^ *// unless($current =~ /\n/);
			if($soft_wrap && $wrap_indent && length($remainder) &&
			   $remainder ne "\n")
			  {$remainder = (' ' x $wrap_indent) . $remainder}
			chomp($current);
		      }
		  }

		if(length($current) == $col_width && $next_char eq "\n")
		  {$remainder =~ s/^\n//}

		debug("Next portion colidx [$index]: [$current]\n",
		      "Remainder: [$remainder].",{LEVEL => -1});

		$line .= $current;
	      }
	    else
	      {
		debug("Next portion colidx [$index]: [$remainder]\n",
		      "Remainder: [].",{LEVEL => -1});

		$line .= $remainder;
		$remainder = '';
	      }

	    if($index == $#{$column_vals})
	      {$line =~ s/\s*$/\n/s}

	    $remainders[$index] = $remainder;
	  }

	$out .= $line;
      }

    $out =~ s/\s*$/\n/;

    debug({LEVEL => -1},"Returning: [$out]");

    return($out);
  }

sub getSummaryUsageOptStr
  {
    my $extended       = getVarref('extended',1,1);
    my $local_extended = scalar(@_) > 0 && defined($_[0]) ? $_[0] :
      (defined($extended) ? $extended : 0);

    my $script             = getScriptName();
    my $optionals          = ' [OPTIONS]';
    my $optionals_wo_prim  = $optionals;
    my $requireds          = '';
    my $requireds_wo_prim  = '';
    my $primary_inf_exists = 0;
    my $primary_hidden     = 0;
    my $first_reqd         = 1;
    my $all_hidden         = 1;

    #The following is to treat optional options paired to from REQUIRED options
    #as required
    my $effective_reqd_hash = {};
    foreach my $usage_hash (@$usage_array)
      {
        if(defined($usage_hash->{REQUIRED}) && $usage_hash->{REQUIRED})
          {
            $effective_reqd_hash->{$usage_hash->{OPTION_ID}} = 1;
            #If this option is paired with another option that is optional
            if(defined($usage_hash->{PAIRID}) &&
               !$usage_array->[$usage_hash->{PAIRID}]->{REQUIRED})
              {$effective_reqd_hash->{$usage_hash->{PAIRID}} = 1}
          }
        elsif(!exists($effective_reqd_hash->{$usage_hash->{OPTION_ID}}))
          {$effective_reqd_hash->{$usage_hash->{OPTION_ID}} = 0}
      }

    #Add visible options
    foreach my $usage_hash (grep {!defined($_->{HIDDEN}) ||
				    !$_->{HIDDEN} ||
				      ($_->{HIDDEN} &&
				       $_->{OPTTYPE} eq 'infile' &&
				       $_->{PRIMARY})}
			    @$usage_array)
      {
        if(!defined($usage_hash->{HIDDEN}) || !$usage_hash->{HIDDEN})
          {$all_hidden = 0}

	my $prim = 0;
	#If this is an input file type and it is primary
	if($usage_hash->{OPTTYPE} eq 'infile' &&
	   exists($usage_hash->{PRIMARY}) &&
	   defined($usage_hash->{PRIMARY}) && $usage_hash->{PRIMARY})
	  {
	    $primary_inf_exists = 1;
	    $prim               = 1;
	    $primary_hidden     = $usage_hash->{HIDDEN};
	  }

	#Add to the required options string
	if($effective_reqd_hash->{$usage_hash->{OPTION_ID}} &&
	   (!exists($usage_hash->{HIDDEN}) || !defined($usage_hash->{HIDDEN}) ||
	    !$usage_hash->{HIDDEN}))
	  {
	    my($reqd,$reqdwp) = addOptToSumUsgStr($usage_hash);
	    $requireds .= ($first_reqd ? '' : ' ') . $reqd;
	    if(!$prim)
	      {$requireds_wo_prim .= ($first_reqd ? '' : ' ') . $reqdwp}
	    $first_reqd = 0;
	  }
      }

    if($all_hidden)
      {$optionals = $optionals_wo_prim = ''}

    #Add required mutually exclusive options to the required options string
    #First collect them to know whether there's only 1 that's visible
    my $mutex_required_optids         = [];
    my $mutex_required_optids_wo_prim = [];
    foreach my $exclusive_set (map {$exclusive_options->[$_]}
			       grep {exists($mutual_params->{$_}) &&
				       exists($mutual_params->{$_}->{REQUIRED})
					 && $mutual_params->{$_}->{REQUIRED}}
			       (0..$#{$exclusive_options}))
      {
	my $ids_to_add         = [];
	my $ids_to_add_wo_prim = 0;
	foreach my $optid (grep {isEffectivelyRequired($usage_array->[$_])}
                           grep {!defined($usage_array->[$_]->{HIDDEN}) ||
				   !$usage_array->[$_]->{HIDDEN} ||
                                     $local_extended >= 3}
			   @$exclusive_set)
	  {
	    push(@$ids_to_add,$usage_array->[$optid]);
	    $ids_to_add_wo_prim++ if(!$usage_array->[$optid]->{PRIMARY});
	  }
	if(scalar(@$ids_to_add) == 0)
	  {
            #Issue an error for all being hidden unless all members are PRIMARY
            #or one has a default
            if(scalar(grep {!defined($usage_array->[$_]->{HIDDEN}) ||
                              !$usage_array->[$_]->{HIDDEN} ||
                                $local_extended >= 3}
                      @$exclusive_set) == 0 &&
               scalar(@$exclusive_set) !=
                scalar(grep {$usage_array->[$_]->{PRIMARY}} @$exclusive_set) &&
               scalar(grep {hasDefault($usage_array->[$_])} @$exclusive_set) !=
               1)
              {error('All options in a mutually exclusive option set are ',
                     'hidden without a default: [',
                     join(',',map {$usage_array->[$_]->{OPTFLAG_DEF}}
                          @$exclusive_set),"].")}
          }
	else
	  {
	    push(@$mutex_required_optids,$ids_to_add);
	    push(@$mutex_required_optids_wo_prim,$ids_to_add_wo_prim);
	  }
      }
    foreach my $seti (0..$#{$mutex_required_optids})
      {
	my $set            = $mutex_required_optids->[$seti];
	my $wo_prim_parens = ($mutex_required_optids_wo_prim->[$seti] == 1);
	my($reqd,$reqdwp);
	$requireds .=
	  ($first_reqd ? '' : ' ') . (scalar(@$set) == 1 ? '' : '(');
	$requireds_wo_prim .=
	  ($first_reqd ? '' : ' ') . ($wo_prim_parens    ? '' : '(');
	$first_reqd = 0;

	foreach my $i (0..$#{$set})
	  {
	    my $join = ($i == $#{$set} ? '' :
			(scalar(@$set) == 2 ? ' or ' :
			 ($i == ($#{$set} - 1) ? ', or ' : ', ')));

	    ($reqd,$reqdwp) = addOptToSumUsgStr($set->[$i]);
	    $requireds .= $reqd . $join;
	    if(!$set->[$i]->{PRIMARY})
	      {$requireds_wo_prim .= $reqdwp . $join}
	  }

	$requireds         .= (scalar(@$set) == 1 ? '' : ')');
	$requireds_wo_prim .= (scalar(@$set) == 1 ? '' : ')');
      }

    #Hidden only refers to the flags and thus the usage entries.  If a primary
    #infile option is hidden, this summary string is the only indication that
    #the script can take anything on STDIN.
    my $summary_str = (!$primary_inf_exists ||
		       ($primary_inf_exists && !$primary_hidden) ?
		       $script . ($requireds ne '' ? " $requireds" : '') .
		       "$optionals\n" : '');
    if(($local_extended && $primary_inf_exists) ||
       ($primary_inf_exists && $primary_hidden))
      {$summary_str .= "$script" . ($requireds_wo_prim ne '' ?
				     " $requireds_wo_prim" : '') .
				       "$optionals_wo_prim < input_file\n"}
    $summary_str .= "\n";

    return($summary_str);
  }

sub addOptToSumUsgStr
  {
    my $usage_hash        = $_[0];
    my $requireds         = '';
    my $requireds_wo_prim = '';

    my $flag = getDefaultFlag($usage_hash->{OPTFLAGS});
    if($usage_hash->{OPTTYPE} eq 'negbool')
      {
	my $def = getRealDefault($usage_hash);
	if(defined($def) && ref($def) ne '')
	  {$def = undef}
	if(!defined($def))
	  {$flag =~ s/^-+/--[no]/}
	elsif($def)
	  {
	    my $nf = $flag;
	    $nf =~ s/^-+//;
	    $nf = "--[no]$nf";
	    $flag = $nf;
	  }
      }

    my $prim = ($usage_hash->{OPTTYPE} eq 'infile' &&
		exists($usage_hash->{PRIMARY}) &&
		defined($usage_hash->{PRIMARY}) && $usage_hash->{PRIMARY});

    $requireds = $flag;
    if(!$prim)
      {$requireds_wo_prim .= $flag}

    #Add a required input file's example argument
    if($usage_hash->{OPTTYPE} eq 'infile')
      {
	$requireds .= " <file*...>...";
	$requireds_wo_prim .= " <file*...>..." unless($prim);
      }
    #Add a required output file's example argument
    elsif($usage_hash->{OPTTYPE} eq 'outfile')
      {
	$requireds .= " <file*...>...";
	$requireds_wo_prim .= " <file*...>...";
      }
    #Add a required output log file's example argument
    elsif($usage_hash->{OPTTYPE} eq 'logfile')
      {
	$requireds .= " <file>";
	$requireds_wo_prim .= " <file>";
      }
    #Add a required output file's example argument
    elsif($usage_hash->{OPTTYPE} eq 'suffix' ||
	  $usage_hash->{OPTTYPE} eq 'logsuff')
      {
	$requireds .= " <sfx>";
	$requireds_wo_prim .= " <sfx>";
      }
    #Add a required output directory's example argument
    elsif($usage_hash->{OPTTYPE} eq 'outdir')
      {
	$requireds .= " <dir*...>";
	$requireds_wo_prim .= " <dir*...>";
      }
    #Add a required integer array option's example argument
    elsif($usage_hash->{OPTTYPE} eq 'integer_array')
      {
	$requireds .= " <int...>";
	$requireds_wo_prim .= " <int...>";
      }
    #Add a required float array option's example argument
    elsif($usage_hash->{OPTTYPE} eq 'float_array')
      {
	$requireds .= " <flt...>";
	$requireds_wo_prim .= " <flt...>";
      }
    #Add a required string array option's example argument
    elsif($usage_hash->{OPTTYPE} eq 'string_array')
      {
	$requireds .= " <str...>";
	$requireds_wo_prim .= " <str...>";
      }
    #Add a required enum array option's example argument
    elsif($usage_hash->{OPTTYPE} eq 'enum_array')
      {
	my $acc = $usage_hash->{ACCEPTS};
	if(defined($acc) && ref($acc) eq 'ARRAY' && scalar(@$acc))
	  {
	    $acc = join('|',@$acc);
	    if(length($acc) > 20)
	      {$acc =~ s/(.{17}).*/$1.../}
	  }
	else
	  {$acc = 'str'}
	$requireds .= " <$acc...>";
	$requireds_wo_prim .= " <$acc...>";
      }
    #Add a required integer array option's example argument
    elsif($usage_hash->{OPTTYPE} eq 'integer_array2d')
      {
	$requireds .= " <int...>...";
	$requireds_wo_prim .= " <int...>...";
      }
    #Add a required float array option's example argument
    elsif($usage_hash->{OPTTYPE} eq 'float_array2d')
      {
	$requireds .= " <flt...>...";
	$requireds_wo_prim .= " <flt...>...";
      }
    #Add a required string array option's example argument
    elsif($usage_hash->{OPTTYPE} eq 'string_array2d')
      {
	$requireds .= " <str...>...";
	$requireds_wo_prim .= " <str...>...";
      }
    #Add a required enum array option's example argument
    elsif($usage_hash->{OPTTYPE} eq 'enum_array2d')
      {
	my $acc = $usage_hash->{ACCEPTS};
	if(defined($acc) && ref($acc) eq 'ARRAY' && scalar(@$acc))
	  {
	    $acc = join('|',@$acc);
	    if(length($acc) > 20)
	      {$acc =~ s/(.{17}).*/$1.../}
	  }
	else
	  {$acc = 'str'}
	$requireds .= " <$acc...>...";
	$requireds_wo_prim .= " <$acc...>...";
      }
    #Add a required count option's example optional argument
    elsif($usage_hash->{OPTTYPE} eq 'count')
      {
	$requireds .= " [<cnt>]";
	$requireds_wo_prim .= " [<cnt>]";
      }
    #Add a required integer option's example argument
    elsif($usage_hash->{OPTTYPE} eq 'integer')
      {
	$requireds .= " <int>";
	$requireds_wo_prim .= " <int>";
      }
    #Add a required float option's example argument
    elsif($usage_hash->{OPTTYPE} eq 'float')
      {
	$requireds .= " <flt>";
	$requireds_wo_prim .= " <flt>";
      }
    #Add a required string option's example argument
    elsif($usage_hash->{OPTTYPE} eq 'enum')
      {
	my $acc = $usage_hash->{ACCEPTS};
	if(defined($acc) && ref($acc) eq 'ARRAY' && scalar(@$acc))
	  {
	    $acc = join('|',@$acc);
	    if(length($acc) > 20)
	      {$acc =~ s/(.{17}).*/$1.../}
	    $acc = "<$acc>";
	  }
	else
	  {$acc = 'str'}
	$requireds .= " $acc";
	$requireds_wo_prim .= " $acc";
      }
    #Add a required string option's example argument
    elsif($usage_hash->{OPTTYPE} eq 'string')
      {
	$requireds .= " <str>";
	$requireds_wo_prim .= " <str>";
      }
    #Add a required unknown option's example argument
    elsif($usage_hash->{OPTTYPE} eq 'unk')
      {
	$requireds .= " <val>";
	$requireds_wo_prim .= " <val>";
      }
    #Nothing to be added to negbool

    return($requireds,$requireds_wo_prim);
  }

##
## This method prints a usage statement in long or short form depending on
## whether "no descriptions" is true.
##
#Globals used: $explicit_quit
sub usage
  {
    my @in = getSubParams([qw(ERROR_MODE EXTENDED)],[],[@_]);
    my $error_mode     = $in[0]; #Don't print full usage in error mode
    my $extended       = getVarref('extended',1,1);
    my $local_extended = (scalar(@in) > 1 && defined($in[1]) ? $in[1] :
			  (defined($extended) ? $extended : 0));

    unless($command_line_stage)
      {processCommandLine()}

    debug({LEVEL => -1},"Value of usage: [",
	  (defined($usage) ? $usage : 'undef'),"].");

    #Don't print a usage after quit has been called unless $usage == 1
    if($explicit_quit && $usage != 1 && !$error_mode)
      {return(0)}

    #Make sure the defaults will display correctly
    processMutuallyExclusiveOptionSets(1);

    print(($error_mode ? "\n" : ''),getSummaryUsageOptStr($local_extended));

    if($error_mode)
      {print("Run with ",(getDefaultRunMode() eq 'usage' ?
			  "no options" : '--usage'),
	     " for usage.\n")}
    else
      {
        #Obtain the custom user options
        my($short,$long) = customUsage();

	if(!$local_extended)
	  {print($short)}
	else #Advanced options/extended usage output
	  {print($long)}

	if($short =~ /(\A|\n)\*/ || $long =~ /(\A|\n)\*/)
	  {print("* Required.\n")}
	if($short =~ /(\A|\n)~/ || $long =~ /(\A|\n)~/)
	  {print('~ Required but satisfied by a default',
                 ($local_extended < 3 ? ' (supply `' .
                  $usage_lookup->{extended}->{OPTFLAG_DEF} . ' 3` for more)' :
                  ' either of the indicated option or of one of a set of ' .
                  'mutually exclusive options that is required').".\n")}
	if($short =~ /(\A|\n)\^/ || $long =~ /(\A|\n)\^/)
	  {print("^ 1 of multiple mutually exclusive options required.\n")}
      }

    return(0);
  }

sub getScriptName
  {
    my $exclude_extension = $_[0];
    my $script = $0;
    $script =~ s/^.*\/([^\/]+)$/$1/;
    if($exclude_extension)
      {$script =~ s/(.*)\..*$/$1/}
    return($script);
  }

BEGIN
  {
    #This allows us to track runtime warnings about undefined variables, etc.
    $SIG{__WARN__} = sub {warning("Runtime warning: [",@_,"].")};
    $SIG{__DIE__}  = sub
      {
        my $err = join('',@_);
        $@ = '';
        push(@$compile_err,["$0:",getTrace(),$err]);
        #Calling die() suppresses the output of unwrapped fatal errors.
        die();
      };

    #Enable export of subs & vars
    require Exporter;
    our @ISA       = qw(Exporter);
    our @EXPORT    = qw(openIn                       openOut
			closeIn                      closeOut
			getLine                      verbose
			verboseOverMe                quit
			error                        warning
			debug                        nextFileCombo
			getInfile                    getOutfile
			addInfileOption              addOutfileSuffixOption
			addOutdirOption              addOutfileOption
			addOption                    addOutfileTagteamOption
			addLogfileOption             addLogfileSuffixOption
			addOptions                   addArrayOption
			add2DArrayOption             getOutHandleFileName
			getNextFileGroup             getAllFileGroups
			getNumFileGroups             getFileGroupSizes
                        setScriptInfo                getInHandleFileName
                        processCommandLine           resetFileGroupIterator
                        isForced                     headerRequested
                        isDryRun                     setDefaults
                        isDebug                      isVerbose
                        makeMutuallyExclusive        isOverwrite
                        isSkip                       isQuiet);
    our @EXPORT_OK = qw(markTime                     getCommand
			sglob                        getVersion
			isThereInputOnSTDIN          isStandardOutputToTerminal
			printRunReport               getHeader
			flushStderrBuffer            inPipeline
                        usage                        help
                        addVerboseOption             editVerboseOption
                        addQuietOption               editQuietOption
                        addOverwriteOption           editOverwriteOption
                        addSkipOption                editSkipOption
                        addHeaderOption              editHeaderOption
                        addVersionOption             editVersionOption
                        addExtendedOption            editExtendedOption
                        addForceOption               editForceOption
                        addDebugOption               editDebugOption
                        addSaveArgsOption            editSaveArgsOption
                        addPipelineOption            editPipelineOption
                        addErrorLimitOption          editErrorLimitOption
                        addAppendOption              editAppendOption
                        addRunOption                 editRunOption
                        addDryRunOption              editDryRunOption
                        addUsageOption               editUsageOption
                        addHelpOption                editHelpOption
			addCollisionOption           editCollisionOption
		        getUserDefaults);

    _init();
  }

END
  {
    my $force = getVarref('force',1,1,1);
    #If the user did not call quit explicitly or force is defined and true
    if(!$explicit_quit || (defined($force) && $force))
      {
	#We're definitely quitting, so if force is undefined or true, set false
	$force = 0 if(!defined($force) || $force);

	#Unless there was a compilation or setup error error, quit cleanly.
        #Note that setup errors would have already been printed and that the
        #error() method (in the event of a compile_err) has likely not been
        #compiled yet
	if((defined($compile_err) && scalar(@$compile_err)) ||
           (defined($num_setup_errors) && $num_setup_errors))
	  {
	    #An exit code of -1 will quit even if --force is supplied.  --force
	    #is intended to over-ride programmatic errors.  --overwrite is
	    #intended to over-ride existing files.
	    quit(-1);
	  }
	elsif(!defined($cleanup_mode) || !$cleanup_mode)
	  {quit(0)}
      }
  }

=head1 NAME

CommandLineInterface - Give your script the behaviors of a unix builtin tool.

=head1 SYNOPSIS

CommandLineInterface allows you to instantly give any script a unix-like command-line interface.

=head2 EXAMPLE 1 - SIMPLE USAGE

    #cat.pl
    use CommandLineInterface;
    while(my $inputFile = getInfile())
      {
        my $outputFile = getOutfile();
        openOut(*OUT,$outputFile);
        openIn(*IN,$inputFile) || next;
        while(getLine(*IN))
          {print}
        closeIn(*IN);
        closeOut(*OUT);
      }

    #USAGE
    #>cat.pl --verbose -i in.txt -o .out -- plus usage, redirect, adv opts, etc

=head2 EXAMPLE 2 - COMMON USAGE

    #catpairs.pl
    use CommandLineInterface;
    setScriptInfo(VERSION => '1.0',
                  CREATED => '9/25/2016',
                  AUTHOR  => 'Robert Leach',
                  CONTACT => 'rleach@princeton.edu',
                  COMPANY => 'Princeton University',
                  LICENSE => 'Copyright 2018',
                  HELP    => 'Concatenates pairs of files.');

    my $filetype1 = addInfileOption(FLAG       => 'i',
                                    REQUIRED   => 1,
                                    DEFAULT    => undef,
                                    PRIMARY    => 1,
                                    SHORT_DESC => 'First input file type.',
                                    LONG_DESC  => 'First input file type.  ' .
                                    'Put at the begining of the output file.',
                                    FORMAT     => 'Ascii text.');

    my $filetype2 = addInfileOption(FLAG       => 'j',
                                    REQUIRED   => 1,
                                    SHORT_DESC => 'Second input file type.',
                                    LONG_DESC  => 'Second input file type.' .
                                    '  Put at the end of the output file.',
                                    FORMAT     => 'Ascii text.',
                                    PAIR_WITH  => $filetype1,
                                    PAIR_RELAT => 'ONETOONE');

    my $outftype1 = addOutfileOption(FLAG          => 'o',
                                     COLLISIONMODE => 'merge',
                                     SHORT_DESC    => 'Output file name.',
                                     LONG_DESC     => 'Provide a name for ' .
                                     'the output file.  An output file name ' .
                                     'for each pair of input files may be ' .
                                     'provided (see -i and -j).',
                                     FORMAT        => 'Same as the input file',
                                     PAIR_WITH     => $filetype1,
                                     PAIR_RELAT    => 'ONETOONE');

    while(nextFileCombo())
      {
        my $inputFile1 = getInfile($filetype1);
        my $inputFile2 = getInfile($filetype2);
        my $outputFile = getOutfile($outftype1);

        openOut(*OUT,$outputFile) || next; #'merge' mode set above
                                           #automatically opens 1st in write,
                                           #then in append

        openIn(*IN1,$inputFile1)  || next;
        while(getLine(*IN1))
          {print}
        closeIn(*IN1);

        openIn(*IN2,$inputFile2)  || next;
        while(getLine(*IN2))
          {print}
        closeIn(*IN2);

        closeOut(*OUT);
      }

    #USAGE
    #>catpairs.pl -i '1.txt 2.txt 3.txt' -j '4.txt 5.txt 6.txt' -o '14.txt 25.txt 36.txt'

=head1 DESCRIPTION

CommandLineInterface (henceforth, 'CLI') basically gives any file processing script an instant command line interface with all the standard bells and whistles.

I<File Processing Features>

CLI makes processing of ordered pairs or groups of files a breeze with 2-dimensional file parameters, enforced relationships between file types (e.g. 1:1, 1:M, or 1:1orM), over-write protection, automatic construction of output file names and stubs (including output directories, compounded file names, outfile suffixes, or appended numbers), the ability to skip pairs/groups of files when their output file already exists, automatic outfile headers containing dated run, version, user, etc. information.  Since the package generates the outfile names ahead of time, it gives it the ability to check for pre-existing output files, even predicted outfile name conflicts that don't yet exist, right at the beginning of the script, without having to wait through any file processing and with no to little coding effort on your part.

The ability to handle 2-dimensional file parameters is probably the most useful feature of CLI.  Each file flag can be supplied multiple times and each instance can take multiple input files.  It can do this because it bsd_globs each file string, supporting any glob character supported by bsd (e.g. {}, [], *, ?).  It even has the ability to overcome some limitations on command line length.  CLI takes the 2-dimensional file parameters and can mix & match them in multiple ways, enforcing the file type relationships along the way.  For example, these commands are equivalent:

    example.pl -i '1.txt 2.txt' -i '3.txt 4.txt' -i '5.txt 6.txt' -j a.txt -j b.txt -j c.txt

    example.pl -i '1.txt 2.txt' -i '3.txt 4.txt' -i '5.txt 6.txt' -j 'a.txt b.txt c.txt'

CLI sees that there are 3 groups of type -i, 3 files of type -j, and whether you provide those files each with a separate instance of -j or all in one, it will process the pairs in the same way:

    1.txt a.txt
    3.txt b.txt
    5.txt c.txt
    2.txt a.txt
    4.txt b.txt
    6.txt c.txt

Through some design examples in the discussion, you can see ways in which processing of the repeated files can be handled (e.g. 'a.txt').

CLI comes with a suite of standard command-line flags (and accompanying methods):

=over 4

=item B<Simple Flags>

Basic flags for verbosity, help, info, headers, and script control.


=over 4

=item --verbose           Use verbose(), verboseOverMe()

=item --quiet             quiets verbose(), warning(), error()

=item --help              automatic or use help()

=item --version           automatic or use getVersion()

=item --force             automatic; errors state when applicable

=item --header            automatic or use openOut(), getHeader()

=item --extended          more/advanced usage/help/version/header

=item --save-args         save command line options as defaults

=back

=item B<Overwrite Protection Flags>

Flags to help deal with pre-existing output files, all of which apply to all files opened by openOut() and pre-checked during processCommandLine().  Using perl's open() function circumvents overwrite protection:


=over 4

=item --overwrite         automatically handled

=item --skip              automatically handled

=item --append            automatically handled

=back


=item B<Debug Flags>

These flags help to figure out bugs.


=over 4

=item --debug             Use debug(). <0 = package debugging

=item --error-limit       suppress repeated error/warning types

=item --dry-run           prevents openIn & openOut operations

=item --pipeline          automatic; prepend script name to msgs

=back

=back

Simply by using CommandLineInterface, your script will have these options available on the command line.  Some of them require your input or the usage of certain methods to be useful.  E.g. Call error() instead of printing to STDERR, add options using the add*Option methods, call openIn() and openOut() instead of open(), etc.

=head2 Limitations

Bundling of options is not supported.  Option bundling is where `-x -v -f` can be abbreviated as `-xvf`.

Flags must have a dash (for single character flags) or a double-dash, e.g. "--flag", for multi-character flags.

While support for array type options is provided, support for hash type options is not yet implemented.

=head2 Methods

=over 12

=item C<add2DArrayOption> FLAG VARREF [TYPE REQUIRED DEFAULT HIDDEN SHORT_DESC LONG_DESC ACCEPTS FLAGLESS DELIMITER ADVANCED HEADING DISPDEF]

Add an option/flag to the command line interface that a user can supply on the command line either multiple times, once with multiple values, or both.  Each instance of the FLAG on the command line defines a sub-array and the space-delimited values (wrapped in quotes) will be pushed onto the inner array.  E.g. -a '1 2 3' -a 'a b c' creates the following 2D array: [['1','2','3'],['a','b','c']].

It returns an option ID that can be used in makeMutuallyExclusive().

FLAG is the name or names of the flag the user supplies on the command line (with or without an argument as defined by TYPE).  You can supply a single FLAG or a reference to an array of FLAGs.  Only alpha-numeric characters, dashes, and underscores are permitted.  Single character flags will be prepended with a single dash '-' and multi-character flags will get a double dash '--'.

VARREF takes a reference to an array onto which values supplied on the command line will be pushed.  The reference must be defined before passing it to add2DArrayOption.

TYPE can be any of:

    integer - signed or unsigned integer (exponents like 10e10 allowed)
    float   - float (exponents like 10.0e10 allowed)
    string  - string
    enum    - enumeration (values defined using the ACCEPTS array)

If not supplied, the default TYPE is str if ACCEPTS is also not supplied, or enum if ACCEPTS is supplied.

If REQUIRED is a non-zero value (e.g. '1'), the script will quit with an error and a usage message if at least 1 value is not supplied by the user on the command line.  If required is not supplied or set to 0, the flag will be treated as optional.

The DEFAULT parameter can be given a reference to an array such that when a value is not supplied by the user, the default will be assigned.  If no DEFAULT is set, but the VARREF array reference has a value, the DEFAULT value is automatically set to the value referenced by VARREF.  If both VARREF and DEFAULT have differing values, a fatal error will be generated.

If HIDDEN is a non-zero value (e.g. '1'), the flag/option created by this method will not be a part of the usage output.  Note that if HIDDEN is non-zero, a DEFAULT must be supplied.

SHORT_DESC is the short version of the usage message for this output file type.  An empty string will cause this option to not be in the short version of the usage message.

LONG_DESC is the long version of the usage message for this output file type.  If LONG_DESC is not defined/supplied and SHORT_DESC has a non-empty string, SHORT_DESC is copied to LONG_DESC.

Note, both SHORT_DESC and LONG_DESC have auto-generated formatting which includes whether or not the option is REQUIRED.

ACCEPTS takes a reference to an array of scalar values.  If defined/supplied, the list of acceptable values will be shown in the usage message for this option after the default value and before the description.  This parameter is intended for short lists of discrete values (i.e. enumerations) only.  Descriptions of acceptable value ranges should instead be incorporated into the LONG_DESC.

FLAGLESS, if non-zero, indicates that arguments without preceding flags are to be assumed to belong to this option.  Note, only 1 option may currently be flagless.

DELIMITER is the character between multiple values supplied to a single FLAG.  Note, if you use a space as your DELIMITER, the arguments must be wrapped in quotes.  Multiple character DELIMITERs are allowed.  Empty values (between multiple instances of contiguous delimiters) are skipped.  A perl regular expression is allowed (e.g. '\s+').  The default is based on TYPE.  Defaults of DELIMITER for each TYPE are:

    integer - Non-number characters (i.e. not 0-9, '+', '-', or 'e' (exponent).
    float   - Same as int, but decimals are included.
    string  - No delimiting is done.
    enum    - Any character not in the ACCEPTS values.

If ADVANCED is non-zero, this option will only display in the advanced usage (i.e. when --extended is 3).

A HEADING string can be supplied to any option to have a section heading appear above the defined option.  Options appear in the usage in the order they are created, but note that required options without default values will appear at the top.

The DISPDEF parameter is the "display default" describing the default in the usage.  Optionally, a reference to an array of references to arrays of scalars may be supplied.  The 2D array will be converted into a string using delimiting paranthases and commas, e.g.: "((1,2),(3,4)),((5),(6,7,8))", when displayed in the usage output's default for the given option.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -a '1 2 three four' -a "5 6"

I<Code>

    my $array2d = [];
    add2DArrayOption(FLAG       => 'a',
                     VARREF     => $array2d,
                     TYPE       => 'string',
                     REQUIRED   => 1,
                     DEFAULT    => '',
                     HIDDEN     => 0,
                     SHORT_DESC => 'A series of numbers.',
                     LONG_DESC  => 'A space-delimited series of numbers.');
    processCommandLine();
    foreach my $sub_array (@$array2d)
    print(join(' ',@$sub_array),"\n");

I<Output>

    1 2 three four
    5 6

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all error, warning, verbose, & debug messages.

Default file options that are added if none defined (which also affect the behavior of this method):

    None

I<LIMITATIONS>

There's currently no way to require a minimum, maximum, or exact number of required values - only at least 1.

There is not yet a way to pair a 2D array option with input or output files.

If a VARREF array reference is initialized with default values, the value is replaced by supplied values during the processCommandLine call.  However, it is recommended that the prgrammer use the DEFAULT parameter instead of initializing the value supplied to VARREF.

While VARREF may be a code reference, note that the supplied sub may be called to unset any potentially initialized array values by passing an empty string.  This is done even if no DEFAULT is set in order to satisfy a mutually exclusive option set (see makeMutuallyExclusive()).

I<ADVANCED>

FLAG strings are used as a key in the hash passed to Getopt::Long's GetOptions method.  As such, a type could be specified in the FLAG string, however since this is an array option with a delimiter, appending a type string in the flag string, such as 'a=i', cannot be used due to the parsing of delimited values.  So using the TYPE parameter is preferable.

VARREF is the value that is supplied as a value in the hash passed to Getopt::Long's GetOptions method.  Note that the VARREF array variable supplied is not populated until processCommandLine() has been called.  Once processCommandLine() has been called, no further calls to add2DArrayOption() are allowed.

If an array is pre-populated with default values, the default is not replaced, but rather is added to.  In order to set a default value, the prgrammer must set the default after the command line has been processed, if the user did not set a value.

VARREF may be a code reference (i.e. a reference to a subroutine (named or anonymous)) (e.g. `ref($value) eq 'CODE'`).  See the underlying module documentation by running `perldoc Getopt::Long` on the command line for details on the arguments, however the value supplied to the FLAG on the command line is either $_[0] (for FLAGLESS options supplied without a flag) or $_[1] (for options that are not FLAGLESS).

Note that any variable a subroutine (supplied to VARREF) modifies, will not be visible to CommandLineInterface.  CommandLineInterface however calls the subroutine for a number of reasons other than explicit values supplied on the command line in any particular run.  It will be called for the following reasons:

 1. To set an option supplied on the command line (as many times as it is
    supplied)
 2. To set the supplied DEFAULT value (if appropriate)
 3. To set a previously user-supplied default (if appropriate)
 4. To clear out a potential value initialized in main (by passing undef) if
    there is no default and a mutually exclusive partner option is supplied.

A VARREF subroutine is not called to set (or clear out) a default value if no DEFAULT was supplied and a mutually exclusive option was not supplied.

A VARREF subroutine is not called to set the supplied DEFAULT value if a user default for that option exists.

If REQUIRED is true, but the array reference provided is populated with default values, the option is essentially optional.  Setting REQUIRED to true only forces the user to supply a value if the array reference refers to an empty array.  Note also that if the user provides no options on the command line, a general usage is printed, but if other options are supplied, and error about missing required options is generated.

=item C<addAppendOption> [FLAG DEFAULT DISPDEF REQUIRED HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This is a builtin option of type bool (see addOption() and addBuiltinOption()).  It controls whether openOut will open in append mode or not.  There is no getter method for this option.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameters values:

    FLAG        => 'append'
    DEFAULT     => 0
    DISPDEF     => undef
    REQUIRED    => 0
    HIDDEN      => 0
    ADVANCED    => 1
    SHORT_DESC  => undef
    LONG_DESC   => "Append mode.  Appends output to all existing output files
                    instead of skipping or overwriting them.  This is useful for
                    checkpointed jobs on a cluster."
    HEADING     => ''

I<EXAMPLE>

=over 4

I<Command>

    echo "Pre-existing content." > out.txt
    example.pl --append --outfile out.txt

I<Code>

    addAppendOption();
    processCommandLine();
    openOut(*OUT,getOutfile());
    print("New output appended to file.\n");

I<Output> (cat out.txt)

    Pre-existing content.
    New output appended to file.

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --append            Renamable flag.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addArrayOption> FLAG VARREF [TYPE REQUIRED DEFAULT HIDDEN SHORT_DESC LONG_DESC DELIMITER ACCEPTS FLAGLESS INTERPOLATE ADVANCED HEADING DISPDEF]

Add an option/flag to the command line interface that a user can supply on the command line either multiple times, once with multiple values (if DELIMITER is defined), or both, and each value will be pushed onto the VARREF array reference.

It returns an option ID that can be used in makeMutuallyExclusive().

FLAG is the name or names of the flag the user supplies on the command line (with or without an argument as defined by TYPE).  You can supply a single FLAG or a reference to an array of FLAGs.  Only alpha-numeric characters, dashes, and underscores are permitted.  Single character flags will be prepended with a single dash '-' and multi-character flags will get a double dash '--'.

VARREF takes a reference to an array onto which values supplied on the command line will be pushed.  The reference must be defined before passing it to addArrayOption.

TYPE can be any of:

    integer - signed or unsigned integer (exponents like 10e10 allowed)
    float   - signed or unsigned decimal value (exponents like 10.0e10 allowed)
    string  - string
    enum    - enumeration (values defined using the ACCEPTS array)

If not supplied, the default TYPE is str if ACCEPTS is also not supplied, or enum if ACCEPTS is supplied.

If REQUIRED is a non-zero value (e.g. '1'), the script will quit with an error and a usage message if at least 1 value is not supplied by the user on the command line.  If required is not supplied or set to 0, the flag will be treated as optional.

The DEFAULT parameter can be given a reference to an array such that when a value is not supplied by the user, the default will be assigned.  If no DEFAULT is set, but the VARREF array reference has a value, the DEFAULT value is automatically set to the value referenced by VARREF.  If both VARREF and DEFAULT have differing values, a fatal error will be generated.

If HIDDEN is a non-zero value (e.g. '1'), the flag/option created by this method will not be a part of the usage output.  Note that if HIDDEN is non-zero, a DEFAULT must be supplied.

SHORT_DESC is the short version of the usage message for this output file type.  An empty string will cause this option to not be in the short version of the usage message.

LONG_DESC is the long version of the usage message for this output file type.  If LONG_DESC is not defined/supplied and SHORT_DESC has a non-empty string, SHORT_DESC is copied to LONG_DESC.

Note, both SHORT_DESC and LONG_DESC have auto-generated formatting which includes whether or not the option is REQUIRED.

FLAGLESS, if non-zero, indicates that arguments without preceding flags are to be assumed to belong to this option.  Note, only 1 option may currently be flagless.

DELIMITER is the character between multiple values supplied to a single FLAG.  Note, if you use a space as your DELIMITER, the arguments must be wrapped in quotes.  Multiple character DELIMITERs are allowed.  Empty values (between multiple instances of contiguous delimiters) are skipped.  A perl regular expression is allowed (e.g. '\s+').  The default is based on TYPE.  There is no default delimiter for addArrayOption() (though there is for add2DArrayOption()).  Without supplying a delimiter, each value must be submitted with a flag.  If you do provide a delimiter, multiple flags are still allowed, but all values are pushed onto the same array from left to right, as they appear in order on the command line.

INTERPOLATE: Deprecated.  Present for backward compatibility.

If ADVANCED is non-zero, this option will only display in the advanced usage (i.e. when --extended is 3).

ACCEPTS takes a reference to an array of scalar values.  If defined/supplied, the list of acceptable values will be shown in the usage message for this option after the default value and before the description.  This parameter is intended for short lists of discrete values (i.e. enumerations) only.  Descriptions of acceptable value ranges should instead be incorporated into the LONG_DESC.

A HEADING string can be supplied to any option to have a section heading appear above the defined option.  Options appear in the usage in the order they are created, but note that required options without default values will appear at the top.

The DISPDEF parameter is the "display default" simply describing the default in the usage message for this parameter.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -a '1 2 three four' -a "5 6"

I<Code>

    my $array = [];
    addArrayOption(FLAG       => 'a',
                   VARREF     => $array,
                   REQUIRED   => 1,
                   DEFAULT    => '',
                   HIDDEN     => 0,
                   SHORT_DESC => 'A series of numbers.',
                   LONG_DESC  => '   space-delimited series of numbers.',
                   DELIMITER  => ' ');
    processCommandLine();
    print(join("\n",@$array),"\n");

I<Output>

    1
    2
    three
    four
    5
    6

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all error, warning, verbose, & debug messages.

Default file options that are added if none defined (which also affect the behavior of this method):

    None

I<LIMITATIONS>

There's currently no way to require a minimum, maximum, or exact number of required values - only at least 1.  This will be addressed when requirement 172 is implemented.

There is not yet a way to pair an array option with input or output files.  This will be addressed when requirement 15 is implemented.

If a VARREF array reference is initialized with default values, the value is replaced by supplied values during the processCommandLine call.  However, it is recommended that the prgrammer use the DEFAULT parameter instead of initializing the value supplied to VARREF.

While VARREF may be a code reference, note that the supplied sub may be called to unset any potentially initialized array values by passing an empty string.  This is done even if no DEFAULT is set in order to satisfy a mutually exclusive option set (see makeMutuallyExclusive()).

I<ADVANCED>

VARREF is the value that is supplied as a value in the hash that is passed to Getopt::Long's GetOptions method.  Note that the VARREF array variable supplied is not populated until processCommandLine() has been called.  Once processCommandLine() has been called, no further calls to addArrayOption() are allowed.

VARREF may be a code reference (i.e. a reference to a subroutine (named or anonymous)) (e.g. `ref($value) eq 'CODE'`).  See the underlying module documentation by running `perldoc Getopt::Long` on the command line for details on the arguments, however the value supplied to the FLAG on the command line is either $_[0] (for FLAGLESS options supplied without a flag) or $_[1] (for options that are not FLAGLESS).

Note that any variable a subroutine (supplied to VARREF) modifies, will not be visible to CommandLineInterface.  CommandLineInterface however calls the subroutine for a number of reasons other than explicit values supplied on the command line in any particular run.  It will be called for the following reasons:

 1. To set an option supplied on the command line (as many times as it is
    supplied)
 2. To set the supplied DEFAULT value (if appropriate)
 3. To set a previously user-supplied default (if appropriate)
 4. To clear out a potential value initialized in main (by passing undef) if
    there is no default and a mutually exclusive partner option is supplied.

A VARREF subroutine is not called to set (or clear out) a default value if no DEFAULT was supplied and a mutually exclusive option was not supplied.

A VARREF subroutine is not called to set the supplied DEFAULT value if a user default for that option exists.

The DELIMITER will be shown in the script's usage in the flags column, inside the argument, between the argument type and an ellipsis, e.g. "--flag <int ...>".  In this case, the delimiter is a space.  If a multi-character delimiter is provided, the flag column will appear as "--flag <int...>" and an addendum will be appended to the LONG_DESC.  If a perl regular expression is used, a representative DELIMITER will be shown in the flags column, if an arbitrary example will be used and an addendum placed in the description.

If REQUIRED is true, but the array reference provided is populated with default values, the option is essentially optional.  Setting REQUIRED to true only forces the user to supply a value if the array reference refers to an empty array.  Note also that if the user provides no options on the command line, a general usage is printed, but if other options are supplied, and error about missing required options is generated.

=item C<add*Builtin*Option> [FLAG DEFAULT DISPDEF REQUIRED HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This method cannot be called directly, but is described here to reduce redundancy.  It is called by the following methods.

    addVerboseOption
    addQuietOption
    addOverwriteOption
    addSkipOption
    addHeaderOption
    addVersionOption
    addExtendedOption
    addForceOption
    addDebugOption
    addSaveArgsOption
    addPipelineOption
    addErrorLimitOption
    addAppendOption
    addRunOption
    addDryRunOption
    addUsageOption
    addHelpOption
    addCollisionOption

addBuiltinOption() checks the parameters supplied (via the editBuiltinOption method), fills in default values, and in turn, calls addOption().

Options appear in the usage in the order in which they were added (with the exception of required options without default values, which appear first).  Unless each add___Option() is explicitly called, all builtin options will appear at the end of the usage among the other implicitly added builtin options.  If you wish to edit the parameters, but not change an option's position in the usage output, refer its edit___Option() method.  To only change the position of a builtin option in the usage, call its add___Option() method without any parameters.

Refer to addOption() for a description of the parameters.

I<ADVANCED>

If not explicitly called, this method will be implicitly called for each builtin option the moment before values from the command line are processed.

=item C<addCollisionOption> [FLAG REQUIRED HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This is a deprecated builtin option of type enum (see addOption() and addBuiltinOption()) that accepts arguments 'merge', 'rename', or 'error'.  It controls what will happen if multiple output files end up with the same file name.  There is no getter method for this option.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameters values:

    FLAG        => 'collision-mode'
    REQUIRED    => 0
    HIDDEN      => 1
    ADVANCED    => 1
    SHORT_DESC  => undef
    LONG_DESC   => "DEPRECATED.  When multiple input files output to the same
                    output file, this option specifies what to do.  Merge mode
                    will concatenate output in the common output file.  Rename
                    mode (valid only if this script accepts multiple types of
                    input files) will create a unique output file name by
                    appending a unique combination ofinput file names together
                    (with a delimiting dot).  Rename mode will throw an error if
                    a unique file name cannot be constructed (e.g. when 2 input
                    files of the same name in different directories are
                    outputting to a common directory).  Error mode causes the
                    script to quit with an error if multiple input files are
                    detected to output to the same output file.

                    * The default differs based on whether the output file is
                    specified by an outfile suffix (in which case the default is
                    [error]) or by a full output file name (in which case the
                    default is [merge]).

                    THIS OPTION IS DEPRECATED AND HAS BEEN REPLACED BY
                    'SUPPLYING COLLISION MODE VIA addOutFileSuffixOption AND
                    addOutfileOption.  THIS OPTION HOWEVER WILL OVERRIDE THE
                    COLLISION MODE OF ALL OUTFILE OPTIONS AND APPLY TO FILES
                    THAT ARE NOT DEFINED BY addOutFileSuffixOption OR
                    addOutfileOption IF OPENED MULTIPLE TIMES UNLESS SET
                    EXPLICITLY IN THE openOut CALL."

    HEADING     => ''

I<EXAMPLE>

=over 4

I<Command>

    echo "1" > dir1/in.txt
    echo "2" > dir2/in.txt
    example.pl --collision-mode merge -i dir1/in.txt -i dir2/in.txt --outdir outputs --outfile-suffix .out

I<Code>

    addCollisionOption();
    processCommandLine();
    while(nextFileCombo())
      {
        openIn(*IN,getInfile());
        openOut(*OUT,getOutfile());
        print(<IN>);
        closeOut(*OUT);
        closeIn(*IN);
      }

I<Output> (outputs/in.txt.out)

    1
    2

=back

I<ASSOCIATED FLAGS>

None.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addDebugOption> [FLAG DEFAULT DISPDEF REQUIRED HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This is a builtin option of type count (see addOption() and addBuiltinOption()).  It controls output of the debug() method and its user-supplied (or default) value is retrievable via the isDebug() getter method (after processCommandLine() has been explicitly or implicitly called) which returns the debug level integer value.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameters values:

    FLAG        => 'debug'
    DEFAULT     => 0
    DISPDEF     => undef
    REQUIRED    => 0
    HIDDEN      => 0
    ADVANCED    => 1
    SHORT_DESC  => undef
    LONG_DESC   => "Debug mode.  Prepends trace to warning/error messages.
                    Prints debug() messages based on debug level.  Values less
                    than 0 debug the CommandLineInterface module used by this
                    script."
    HEADING     => ''

I<EXAMPLE>

=over 4

I<Command>

    example.pl --debug 2

I<Code>

    addDebugOption(ADVANCED => 0);
    processCommandLine();
    debug({LEVEL => 2},"This is level 2 debug output.");
    debug({LEVEL => 1},"This is level 1 debug output.");
    debug({LEVEL => 3},"This is level 3 debug output.");

I<Output> (mised stderr & stdout)

    DEBUG1: This is level 2 debug output.
    DEBUG2: This is level 1 debug output.

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --debug             Renamable flag.  See debug()

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addDryRunOption> [FLAG DISPDEF HIDDEN ADVANCED SHORT_DESC LONG_DESC]

This is a builtin option of type bool (see addOption() and addBuiltinOption()).  It controls whether openOut() will actually create files, whether openIn() will actually read files, whether --outdir will create output directories, and whether closeIn and closeOut will close file handles or not.  The value of the option supplied by the user or defaulted via --save-args can be retrieved using the isDryRun() getter method.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameters values:

    FLAG        => 'dry-run'
    DISPDEF     => undef
    REQUIRED    => 0
    HIDDEN      => dynamically determined
    ADVANCED    => 0
    SHORT_DESC  => undef
    LONG_DESC   => "Run without generating output files."

I<EXAMPLE>

=over 4

I<Command>

    example.pl --dry-run --verbose --outfile out.txt

I<Code>

    addDryRunOption(HIDDEN => 0);
    processCommandLine();
    openOut(*OUT,getOutfile());
    unless(isDryRun())
      {print("Real output.\n")}
    closeOut(*OUT);

I<Output> (standard error - no out.txt file created)

    Starting dry run.
    [out.txt] Opened output file.
    [out.txt] Output file done.  Time taken: [0 Seconds].

    Done.  STATUS: [EXIT-CODE: 0 ERRORS: 0 WARNINGS: 0 TIME: 0s]

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --run               Renamable flag.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addErrorLimitOption> [FLAG DEFAULT DISPDEF REQUIRED HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This is a builtin option of type integer (see addOption() and addBuiltinOption()).  It controls how many times a specific warning or error is allowed to be printed (identified by the code line number).  There is no getter for this option.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameters values:

    FLAG        => 'error-limit'
    DEFAULT     => 0
    DISPDEF     => undef
    REQUIRED    => 0
    HIDDEN      => 0
    ADVANCED    => 1
    SHORT_DESC  => undef
    LONG_DESC   => "Limits each type of error/warning to this number of outputs.
                    Intended to declutter output.  Note, a summary of warning/
                    error types is printed when the script finishes, if one
                    occurred or if in verbose mode.  0 = no limit.  See also
                    --quiet."
    HEADING     => ''

I<EXAMPLE>

=over 4

I<Command>

    example.pl --error-limit 2

I<Code>

    addErrorLimitOption();
    processCommandLine();
    foreach(1..3)
      {error("Problem in loop.")}

I<Output>

    ERROR1: Problem in loop.
    ERROR2: Problem in loop.
    ERROR2: NOTE: Further errors of this type will be suppressed.
    ERROR2: Set --error-limit to 0 to turn off error suppression

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --error-limit       Renamable flag.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addExtendedOption> [FLAG DEFAULT DISPDEF REQUIRED HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This is a builtin option of type count (see addOption() and addBuiltinOption()).  It affects a number of options:

    Increases --help detail level
    Increases warning & error detail level.
    Increases --version information output.
    Increases --usage detail level.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameters values:

    FLAG        => 'extended'
    REQUIRED    => 0
    DISPDEF     => undef
    DEFAULT     => 0
    HIDDEN      => 0
    SHORT_DESC  => "Print detailed usage."
    LONG_DESC   => "Print extended usage/help/version/header (and errors/
                    warnings where noted).  Supply alone for extended usage.
                    Includes extended version in output file headers.
                    Incompatible with --noheader.  See --help & --version."
    ADVANCED    => 0
    HEADING     => ''

I<EXAMPLE>

=over 4

I<Command>

    example.pl --version --extended

I<Code>

    setScriptInfo(VERSION => '1.0.1');
    addVersionOption(FLAG => 'v');
    warning("This is a simple warning.",
            {DETAIL => "These are further details about the warning."});
    processCommandLine();

I<Output> (mixed standard error and standard out)

    WARNING1: This is a simple warning.
              These are further details about the warning.
    example.pl Version 1.0.1

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --version           Renamable flag.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addForceOption> [FLAG DEFAULT DISPDEF REQUIRED HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This is a builtin option of type count (see addOption() and addBuiltinOption()).  It controls whether the quit() method will actually exit the script or return and continue running when a fatal error is encountered.  The value of the flag can be retrieved via the isForced() getter method.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameters values:

    FLAG        => 'force'
    REQUIRED    => 0
    DISPDEF     => undef
    DEFAULT     => 0
    HIDDEN      => 0
    SHORT_DESC  => undef
    LONG_DESC   => "Prevent script-exit upon fatal error.  Use with extreme
                    caution.  Will not override overwrite protection (see
                    --overwrite or --skip)."
    ADVANCED    => 1
    HEADING     => ''

I<EXAMPLE>

=over 4

I<Command>

    example.pl --force

I<Code>

    setScriptInfo(VERSION => '1.0.1');
    addForceOption(ADVANCED => 0);
    processCommandLine();
    error("Something went horribly wrong.");
    quit(1);
    print("You will not see this output unless you provided --force.");

I<Output>

    You will not see this output unless you provided --force.

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --force           Renamable flag.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addHeaderOption> [FLAG DEFAULT DISPDEF REQUIRED HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This is a builtin option of type negbool (see addOption() and addBuiltinOption()).  It controls whether headers will be added to all output files or not.  Its user-supplied (or default) value is retrievable via the headerRequested() getter method (after processCommandLine() has been explicitly or implicitly called) which returns a 0 or 1.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameter values:

    FLAG        => 'header'
    REQUIRED    => 0
    DISPDEF     => undef
    DEFAULT     => undef
    HIDDEN      => 0
    SHORT_DESC  => undef
    LONG_DESC   => "Outfile header flag.  Headers are commented with '#' and
                    include script version, date, and command line call at the
                    top of every output file.  See --extended."
    ADVANCED    => 0
    HEADING     => ''

I<EXAMPLE>

=over 4

I<Command>

    example.pl --no-header > out.txt

I<Code>

    addHeaderOption(DEFAULT => 1);
    processCommandLine();
    print("1");

I<Output> (out.txt)

    1

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --header            Renamable flag.  See headerRequested()

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addHelpOption> [FLAG DISPDEF HIDDEN ADVANCED SHORT_DESC LONG_DESC]

This is a builtin option of type bool (see addOption() and addBuiltinOption()).  It controls whether the script will print a help message and exit or not.  The help message contains a description of what the script does and other basic information set via setScriptInfo() and the input and output file formats.  Input and output file formats are set by the FORMAT option of the addInfileOption(), addOutfileOption() and other file methods.  There is no getter method for this option, as the script immediately exits after the --help flag has been processed.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameters values:

    FLAG        => 'help'
    DISPDEF     => undef
    REQUIRED    => 0
    HIDDEN      => dynamically determined
    ADVANCED    => 0
    SHORT_DESC  => "Print general info and file formats."
    LONG_DESC   => "Print general info and file format descriptions.  Includes
                    advanced usage examples with --extended."

I<EXAMPLE>

=over 4

I<Command>

    example.pl --help

I<Code>

    setScriptInfo(AUTHOR  => "Rob",
                  CREATED => "11/5/2019",
                  VERSION => "1.0",
                  HELP    => "This is an example script.");
    addInfileOption(FLAG   => "infile",
                    FORMAT => "Free form ascii text file.");
    addOutfileOption(FLAG   => "outfile",
                     FORMAT => "Free form ascii text file.");
    addHelpOption(FLAG => ['h','help','info']);
    processCommandLine();

I<Output>

    example.pl version 1.0
    Created: 11/5/2019
    Last Modified: Tue Nov  5 16:13:37 2019

    * WHAT IS THIS:   This is an example script.

    * INPUT FORMAT:   Free form ascii text file.
      ---infile

    * OUTPUT FORMAT:  Free form ascii text file.
      --outfile


    Supply --usage to see usage output.

    Supply `--help --extended` for advanced help.

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --help              Renamable flag.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addInfileOption> FLAG [REQUIRED DEFAULT PRIMARY HIDDEN SHORT_DESC LONG_DESC FORMAT PAIR_WITH PAIR_RELAT FLAGLESS ADVANCED HEADING DISPDEF]

Adds an input file option to the command line interface.

FLAG is the name or names of the flag the user supplies on the command line with file, space-delimited list of files inside quotes, or a glob pattern inside quotes.  You can supply a single FLAG or a reference to an array of FLAGs.  Only alpha-numeric characters, dashes, and underscores are permitted.  Single character flags will be prepended with a single dash '-' and multi-character flags will get a double dash '--'.

The return value is an option ID that is later used to obtain the files that the user has supplied on the command line (see getInfile(), getNextFileGroup(), getAllFileGroups()).  It can also be used to supply to makeMutuallyExclusive().  Files for each input file type are kept in a 2D array where the outer array is indexed by the number of occurrences of the flag on the command line (e.g. '-i') and the inner array is all the files supplied to that flag instance.  Note, CommandLineInterface globs input files, so to supply multiple files to a single instance of -i, you have to wrap the file names/glob pattern(s) in quotes.

REQUIRED indicates whether CommandLineInterface should fail with an error if the user does not supply a required file type.  The value can be either 0 (false) or non-zero (e.g. "1") (true).

A DEFAULT file name or glob pattern can be provided.  The value supplied to DEFAULT may be a glob/string (interpreted as a series of files supplied to the first instance of the associated flag on the command line), a reference to an array of globs/strings (also interpreted as a series of files), or a 2D array of globs/strings (where each inner array is considered as a series of globs/strings supplied via a different instance of the associated flag on the command line).  If the user explicitly supplies any number of files on the command line, all default files will be ignored (not added).

There can be only one PRIMARY input file type.  Making an input file type 'PRIMARY' (0 (false) or non-zero (e.g. "1") (true)) does 2 things: 1. PRIMARY files can be submitted without the indicated flag.  (Note, they are still grouped by wrapping in quotes and they are still globbed.)  2. The PRIMARY file type can be supplied on STDIN (standard in, via a pipe or redirect).  Note, if there is a single value supplied to a PRIMARY file type's flag and STDIN is present, the value supplied to the flag is treated as a stub for creating output files with the outfile suffix option(s).

If HIDDEN is a non-zero value (e.g. '1'), the flag/option created by this method will not be a part of the usage output.  Note that if HIDDEN is non-zero, a DEFAULT must be supplied.  If HIDDEN is unsupplied, the default will be 0 if the file type is not linked to another file type that is itself HIDDEN.  If the linked file is HIDDEN, the default will be HIDDEN for this option as well.

SHORT_DESC is the short version of the usage message for this file type.  An empty string will cause this option to not be in the short version of the usage message.

LONG_DESC is the long version of the usage message for this file type.  If LONG_DESC is not defined/supplied and SHORT_DESC has a non-empty string, SHORT_DESC is copied to LONG_DESC.

Note, both SHORT_DESC and LONG_DESC have auto-generated formatting which includes details on the REQUIRED and PRIMARY states as well as the flag(s) parsed from FLAG.

FORMAT is the description of the input file format that is printed when --help is provided by the user.  The auto-generated details for input format descriptions includes the applicable flag(s) and whether or not the flag is necessary.

PAIR_WITH and PAIR_RELAT allow the programmer to require a certain relative relationship with other input (or output) file parameters (already added).  PAIR_WITH takes the input (or output) file type ID (returned by the previous call to addInfileOption() or addOutfileOption()) and PAIR_RELAT takes one of 'ONETOONE', 'ONETOMANY', or 'ONETOONEORMANY'.  For example, if there should be one output file for every group of input files of type $intype1, then PAIR_WITH and PAIR_RELAT should be $intype1 and 'ONETOMANY', respectively.

FLAGLESS, if non-zero, indicates that arguments without preceding flags are to be assumed to belong to this option.  Note, only 1 option may currently be flagless.

If ADVANCED is non-zero, this option will only display in the advanced usage (i.e. when --extended is 3).

All calls to addInfileOption() must occur before any/all calls to processCommandLine(), nextFileCombo(), getInfile, getNextFileGroup(), openOut(), openIn(), and getAllFileGroups().  If you wish to put calls to the add*Option methods at the bottom of the script, you must put them in a BEGIN block.

The returned input file type ID must also be used when calling addOutfileSuffixOption() so that the interface can automatically construct output file names for you and perform overwrite checks.

A HEADING string can be supplied to any option to have a section heading appear above the defined option.  Options appear in the usage in the order they are created, but note that required options without default values will appear at the top.

The DISPDEF parameter is the "display default" simply describing the default in the usage message for this parameter.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt' -j 'file.tab'

I<Code>

    my $id1 = addInfileOption(FLAG       => 'i',
                              REQUIRED   => 1,
                              DEFAULT    => undef,
                              PRIMARY    => 1,
                              HIDDEN     => 0,
                              SHORT_DESC => 'Input file(s).',
                              LONG_DESC  => '1 or more text input files.',
                              FORMAT     => 'ASCII text.');
    my $id2 = addInfileOption(FLAG       => 'j',
                              REQUIRED    => 0,
                              DEFAULT     => undef,
                              PRIMARY     => 0,
                              HIDDEN      => 0,
                              SHORT_DESC  => 'Input file(s).',
                              LONG_DESC   => '1 or more tabbed input files.',
                              FORMAT      => 'Tab delimited ASCII text, 1 ' .
                                             'tab per line.  First column ' .
                                             'is a unique ID and the second ' .
                                             'column is a value.',
                              PAIR_WITH   => $id1,
                              PAIR_RELAT  => 'ONETOMANY');

I<Output>

    n/a

=back

I<ASSOCIATED FLAGS>

A default file option is added if addInfileOption is never called:

    -i                  Input file.

I<LIMITATIONS>

A 'MANYTOMANY' PAIR_RELAT is not supported yet.  This will be addressed when requirement 140 is implemented.  See the DISCUSSION for hints on getting MANYTOMANY behavior.

The only supported static number of files for PAIR_RELAT is 'ONE'.  While strings like '1:1', '1:M', and '1:1orM' are supported, '1' and 'M' cannot be replaced by some other static integer, e.g. to require one file type to be supplied 1 file for every 4 of another file.  This may be implemented in the future.

I<ADVANCED>

addInfileOption() is called automatically with a default input file flag (-i, and other alternate flags) at runtime if no input file option was explicitly added.  If a flag (e.g. '-i') was already used for another option, it is removed and an alternate flag is used.

Multiple values supplied to a PRIMARY file type's flag when STDIN is present causes STDIN to be treated as an additional file parameter to the flag, mixed in with the named input files (i.e. there is no stub).  In these instances, the STDIN input will be named 'STDIN' when used to create output file names with the outfile suffix option(s).

PAIR_RELAT can be instructed to only allow 1 instance of an input file type (by supplying the string 'ONE') without needing PAIR_WITH to be defined.

=item C<addLogfileOption> [FLAG APPEND REQUIRED DEFAULT SHORT_DESC LONG_DESC HIDDEN ADVANCED HEADING DISPDEF VERBOSE DEBUG WARN ERROR MIRROR HEADER RUNREPORT]

This option and the option created by addLogfileSuffixOption allow logging of all error(), warning(), verbose(), debug(), and printRunReport() messages.  It is added by default (with FLAG=logfile, in APPEND mode, no mirroring, an header, and all output types selected) if not otherwise added.

It is not possible to not add this option, but it can be added as a HIDDEN option.  Only a single logfile option is allowed, but both logfile and logfile suffix options can exist as a tagteam.  If the user supplies a log file or if a default is defined, all output is written to the log file.

An option ID that can be used in makeMutuallyExclusive() is returned.

The log file is managed automatically.  You do not need to open or close it.  Note, it is not the same as redirecting standard error.  Any thing explicitly printed to standard error will not go into the log file.

To only print a message to the log and not to standard error, refer to the LOG hash parameter of verbose().  Supplying LOG to verbose() over-rides the VERBOSE argument to this method.

FLAG is the name or names of the flag the user supplies on the command line with a log file path/name.  You can supply a single FLAG or a reference to an array of FLAGs.  Only alpha-numeric characters, dashes, and underscores are permitted.  Single character flags will be prepended with a single dash '-' and multi-character flags will get a double dash '--'.

APPEND indicates whether the supplied log file will, by default, be appended to on each run, or over-written.

REQUIRED indicates whether the option is required on the command line when the user runs the script.  If true and this option is not supplied, the user will either get an error (if any options were supplied) to indicate the missing required options, or the usage message if no options were supplied at all.

Supplying a file path/name as a DEFAULT value means that logging will be turned on.  If the default file name is long or random, you can use DISPDEF to set the "display default" to be shown in the usage output.

SHORT_DESC is the short version of the description of this option.  If set to undefined or an empty string, this option will not appear in the short usage message.  The short usage message is what the user will see if they run the script with no options.

LONG_DESC is the long version of the description of this option.  If set to undefined or an empty string, this option will be set to a warning that the programmer has not provided a description of this option.  The long usage message is what the user will see if they run the script with only the --extended flag.

If HIDDEN is set to a non-zero value, the option will not be included in the usage message.

If ADVANCED is non-zero (e.g. 1), this option will not be shown in the usage unless --extended is greater than 1 (i.e. supplied more than once or with an integer value).

A HEADING string can be supplied to any option to have a section heading appear above the defined option.  Options appear in the usage in the order they are created, but note that required options without default values will appear at the top.

A non-zero value to MIRROR indicates that the output should also go to standard error when logging.  Default is false/0.  Each output type can be specifically selected to be included in the log via non-zero or zero values to VERBOSE, DEBUG, WARN, ERROR, HEADER, and RUNREPORT.  If not included in the log, those output types will continue to be printed to standard error despite the value of MIRROR.

HEADER and RUNREPORT indicate whether a header containing run information should be the first log output and a footer containing a summary of errors, warnings, and run time should be the last log output.  The HEADER (if non-zero) will be printed each time the script is run with the same log file, despite the value of APPEND and the user's use of the global --header/--noheader option.

I<EXAMPLE>

=over 4

I<Command>

    example.pl --logfile ../log.txt

I<Code>

    my $default = $0 . '.' . time() . '.log';
    addLogfileOption(FLAG       => undef,
                     APPEND     => 1,

                     MIRROR     => 0,
                     VERBOSE    => 1,
                     DEBUG      => 1,
                     WARN       => 1,
                     ERROR      => 1,
                     HEADER     => 1,
                     RUNREPORT  => 1,

                     REQUIRED   => 0,
                     DEFAULT    => $default,
                     DISPDEF    => 'example.pl.<date-time>.log',
                     HIDDEN     => 0,
                     SHORT_DESC => 'Log file.',
                     LONG_DESC  => 'Log file.  Supply an empty string to ' .
                                   'turn off logging.',
                     ADVANCED   => 0,
                     HEADING    => undef);
    verbose('Test verbose message.');

I<Output>

    >cat ../log.txt
    #your_version_number
    #User: your_username
    #Time: Thu Feb  9 15:43:36 2017
    #Host: your_hostname
    #PID: your_process_id
    #Directory: /where/you/ran/the/script
    #Command: /usr/bin/perl example.pl -i in.txt
    Test verbose message.

    Done.  STATUS: [EXIT-CODE: 0 ERRORS: 0 WARNINGS: 0 TIME: 0s]

=back

I<ASSOCIATED FLAGS>

    --verbose         Verbose level is effectively equivalent to log level.
    --debug           Debug level affects what debug message go into the log.
    --error-limit     Error limit suppresses repeated error output.
    --logfile-suffix  This option is mutually exclusive with --logfile.

I<LIMITATIONS>

The logfile is not a redirect of all standard error output.  It only gets output from the verbose(), warning(), error(), and debug() methods.

There is no way to output messages to both standard error and the log file.

Only 1 logfile option can be created and it cannot be removed (though it can be hidden).

Log files are not put in the directory specified by --outdir (because multiple output directories can be specified).

I<ADVANCED>

If a DEFAULT log file is defined, the user can supply an empty string (e.g. --logfile '') to disable logging.

If a --logfile-suffix (see addLogfileSuffixOption()) is added, it is automatically mutually exclusive with this option.

Note, --header and --no-header do not control header output in the log file.  The header will always output to the log file to record run parameters.

A run report will be included in the log file output.

=item C<addLogfileSuffixOption> PAIRID [FLAG VARREF REQUIRED DEFAULT HIDDEN SHORT_DESC LONG_DESC APPEND ADVANCED HEADING DISPDEF VERBOSE DEBUG WARN ERROR MIRROR HEADER RUNREPORT]

This option and the option created by addLogfileOption allow logging of all error(), warning(), verbose(), debug(), and printRunReport() messages.  It is not added by default.

This option, if added, is mutually exclusive with --logfile.  It must be paired with a string option added by addOption().  PAIRID is the value returned by addOption() and when both the paired option and the logfile suffix options have values, a log file is created with a name constructed by concatenating the string option's value and the logfile suffix option's value.

An option ID that can be used in makeMutuallyExclusive() is returned.

The log file is managed automatically.  You do not need to open or close it.  Note, it is not the same as redirecting standard error.  Any thing explicitly printed to standard error will not go into the log file.

To only print a message to the log and not to standard error, refer to the LOG hash parameter of verbose().  Supplying LOG to verbose() over-rides the VERBOSE argument to this method.

The default of APPEND is true (i.e. non-zero).  There can only be a single logfile suffix option.  If the user supplies a string to the paired option and a log file suffix or a default logfile suffix is defined, all error, warning, verbose, and debug output is written to the log file.  A header and run report is also always written to the log file.  The log level is the verbose level (see --verbose).  The debug level also reflects what debug output goes to the log file.  When a log file is supplied, error, warning, verbose, and debug messages will not go to standard error.

FLAG is optional.  If not supplied, the default is "logfile-suffix" and results in a --logfile-suffix option that takes a string to be appended to the paired option's value.  FLAG is the name or names of the flag the user supplies on the command line with a log file path/name.  You can supply a single FLAG or a reference to an array of FLAGs.  Only alpha-numeric characters, dashes, and underscores are permitted.  Single character flags will be prepended with a single dash '-' and multi-character flags will get a double dash '--'.

VARREF is a scalar reference to the supplied argument to the --logfile-suffix option.  If a user supplies --logfile-suffix, the scalar value referred to will have that value.

REQUIRED indicates whether the option is required on the command line when the user runs the script.  If true and this option is not supplied, the user will either get an error (if any options were supplied) to indicate the missing required options, or the usage message if no options were supplied at all.

Supplying a file suffix (e.g. ".log") as a DEFAULT value and supplying a DEFAULT for the paired string option (e.g. "myscript") means that logging will be turned on.  You can use DISPDEF to set the "display default" to be shown in the usage output if the value changes dynamically (e.g. ".<date>").

If HIDDEN is set to a non-zero value, the option will not be included in the usage message.

SHORT_DESC is the short version of the description of this option.  If set to undefined or an empty string, this option will not appear in the short usage message.  The short usage message is what the user will see if they run the script with no options.

LONG_DESC is the long version of the description of this option.  If set to undefined or an empty string, this option will be set to a warning that the programmer has not provided a description of this option.  The long usage message is what the user will see if they run the script with only the --extended flag.

APPEND indicates whether the supplied log file will, by default, be appended to on each run, or over-written.

If ADVANCED is non-zero (e.g. 1), this option will not be shown in the usage unless --extended is greater than 1 (i.e. supplied more than once or with an integer value).

A HEADING string can be supplied to any option to have a section heading appear above the defined option.  Options appear in the usage in the order they are created, but note that required options without default values will appear at the top.

A non-zero value to MIRROR indicates that the output should also go to standard error when logging.  Default is false/0.  Each output type can be specifically selected to be included in the log via non-zero or zero values to VERBOSE, DEBUG, WARN, ERROR, HEADER, and RUNREPORT.  If not included in the log, those output types will continue to be printed to standard error despite the value of MIRROR.

HEADER and RUNREPORT indicate whether a header containing run information should be the first log output and a footer containing a summary of errors, warnings, and run time should be the last log output.  The HEADER header (if non-zero) will be printed each time the script is run with the same log file, despite the value of APPEND and the user's use of the global --header/--noheader option.

I<EXAMPLE>

=over 4

I<Command>

    example.pl --run-name attempt1 --logfile-suffix .log

I<Code>

    my($name);
    my $nid = addOption(FLAG   => 'run-name',
                        VARREF => \$name,
                        TYPE   => 'string');
    my($logsuff);
    addLogfileSuffixOption(FLAG       => 'exhaustive',
                           PAIRID     => $nid,
                           VARREF     => \$logsuff,
                           APPEND     => 1,

                           MIRROR     => 0,
                           VERBOSE    => 1,
                           DEBUG      => 1,
                           WARN       => 1,
                           ERROR      => 1,
                           HEADER     => 1,
                           RUNREPORT  => 1,

                           REQUIRED   => 0,
                           DEFAULT    => '.txt',
                           DISPDEF    => undef,
                           HIDDEN     => 0,
                           SHORT_DESC => 'Log file suffix.',
                           LONG_DESC  => 'Log file suffix appended to the ' .
                                         'value supplied to --run-name.  ' .
                                         'Supply an empty string to turn off ' .
                                         'logging.',
                           ADVANCED   => 0,
                           HEADING    => undef);
    verbose('Test verbose message.');

I<Output>

    >cat attempt1.log
    #your_version_number
    #User: your_username
    #Time: Thu Feb  9 15:43:36 2017
    #Host: your_hostname
    #PID: your_process_id
    #Directory: /where/you/ran/the/script
    #Command: /usr/bin/perl example.pl -i in.txt
    Test verbose message.

    Done.  STATUS: [EXIT-CODE: 0 ERRORS: 0 WARNINGS: 0 TIME: 0s]

=back

I<ASSOCIATED FLAGS>

    --verbose         Verbose level is effectively equivalent to log level.
    --debug           Debug level affects what debug message go into the log.
    --error-limit     Error limit suppresses repeated error output.
    --logfile         This option is mutually exclusive with --logfile-suffix.

I<LIMITATIONS>

The logfile is not a redirect of all standard error output.  It only gets output from the verbose(), warning(), error(), and debug() methods.

There is no way to output messages to both standard error and the log file.

Only 1 logfile suffix option can be created and it cannot be removed (though it can be hidden).

Log files are not put in the directory specified by --outdir (because multiple output directories can be specified).

I<ADVANCED>

If a DEFAULT log file is defined, the user can supply an empty string (e.g. --logfile '') to disable logging.

If --logfile-suffix is added, it is automatically mutually exclusive with the --logfile option (see addLogfileOption()).

Note, --header and --no-header do not control header output in the log file.  The header will always output to the log file to record run parameters.

A run report will be included in the log file output.

=item C<addOption> FLAG VARREF [TYPE REQUIRED DISPDEF HIDDEN SHORT_DESC LONG_DESC ACCEPTS ADVANCED HEADING DEFAULT]

This method allows the programmer to create simple options on the command line.  The values of user-supplied options are available after processCommandLine() is called.

It returns an option ID that can be used in makeMutuallyExclusive().

FLAG is the name or names of the flag the user supplies on the command line (with or without an argument as defined by TYPE).  You can supply a single FLAG or a reference to an array of FLAGs.  Only alpha-numeric characters, dashes, and underscores are permitted.  Single character flags will be prepended with a single dash '-' and multi-character flags will get a double dash '--'.

VARREF is a reference to the variable where the user's supplied value will be stored (e.g. $variable).

TYPE can be any of the following:

    bool    - FLAG does not take an argument and sets VARREF to 1 if supplied.
    negbool - A 'negatable' FLAG that does not take an argument.  The user can supply the flag as-is, which sets VARREF to 1, or they can supply --no<FLAG> to set VARREF to 0.  Usage will show the flag which is the opposite of the value referred to in VARREF.  If the value referred to by VARREF is undefined, the usage will show both flags.
    integer - signed or unsigned integer (exponents like 10e10 allowed)
    float   - signed or unsigned decimal value (exponents like 10.0e10 allowed)
    string  - string
    enum    - enumeration where the argument can be one of a set of acceptable values defined by ACCEPTS.
    count   - A 'count' FLAG that can either be set with an integer argument or incremented by multiple instances of FLAG without an argument.  Do not mix FLAGs with and without arguments.

If a TYPE is defined and an option takes an argument, values supplied by the user will be automatically subject to validation.  If an argument is invalid, it will cause a fatal error.

REQUIRED indicates whether the option is required on the command line when the user runs the script.  If it is not supplied, the user will either get an error (if other options were supplied) to indicate the missing required options, or the usage message if no options were supplied at all.

DISPDEF is a "display default" shown in the usage.  Use this when a value is dynamically assigned, random, or long.

If HIDDEN is set to a non-zero value, the option will not be included in the usage message.

SHORT_DESC is the short version of the description of this option.  If set to undefined or an empty string, this option will not appear in the short usage message.  The short usage message is what the user will see if they run the script with no options.

LONG_DESC is the long version of the description of this option.  If set to undefined or an empty string, this option will be set to a warning that the programmer has not provided a description of this option.  The long usage message is what the user will see if they run the script with only the --extended flag.

ACCEPTS takes a reference to an array of scalar values.  If defined/supplied, the list of acceptable values will be shown in the usage message for this option after the default value and before the description.  This parameter is intended for short lists of discrete values (i.e. enumerations) only.  Descriptions of acceptable value ranges should instead be incorporated into the LONG_DESC.

If ADVANCED is non-zero, this option will only display in the advanced usage (i.e. when --extended is 3).

A HEADING string can be supplied to any option to have a section heading appear above the defined option.  Options appear in the usage in the order they are created, but note that required options without default values will appear at the top.

The DEFAULT parameter can be given a value such that when a value is not supplied by the user, the default will be assigned.  If no DEFAULT is set, but the variable referenced by the VARREF scalar reference has a value, the DEFAULT value is automatically set to the value referenced by VARREF.  If both VARREF and DEFAULT have differing values, a fatal error will be generated.

I<EXAMPLE>

=over 4

I<Command>

    example.pl --exhaustive yes

I<Code>

    my $answer = 'no';
    addOption(FLAG       => 'exhaustive',
              VARREF     => \$answer,
              REQUIRED   => 1,
              DEFAULT    => 'no',
              HIDDEN     => 0,
              SHORT_DESC => 'Whether or not to calculate exhaustively.',
              LONG_DESC  => 'Whether or not to calculate exhaustively.  ' .
                            'maybe=flip a coin.',
              ACCEPTS    => ['yes','no','maybe']);
    processCommandLine();
    print("$answer\n");

I<Output>

    yes

=back

I<ASSOCIATED FLAGS>

n/a

I<LIMITATIONS>

n/a

I<ADVANCED>

VARREF may be a code reference (i.e. a reference to a subroutine (named or anonymous)) (e.g. `ref($value) eq 'CODE'`).  See the underlying module documentation by running `perldoc Getopt::Long` on the command line for details on the arguments, however the value supplied to the FLAG on the command line is either $_[0] (for FLAGLESS options supplied without a flag) or $_[1] (for options that are not FLAGLESS).

Note that any variable a subroutine (supplied to VARREF) modifies, will not be visible to CommandLineInterface.  CommandLineInterface however calls the subroutine for a number of reasons other than explicit values supplied on the command line in any particular run.  It will be called for the following reasons:

 1. To set an option supplied on the command line (as many times as it is
    supplied)
 2. To set the supplied DEFAULT value (if appropriate)
 3. To set a previously user-supplied default (if appropriate)
 4. To clear out a potential value initialized in main (by passing undef) if
    there is no default and a mutually exclusive partner option is supplied.

A VARREF subroutine is not called to set (or clear out) a default value if no DEFAULT was supplied and a mutually exclusive option was not supplied.

A VARREF subroutine is not called to set the supplied DEFAULT value if a user default for that option exists.

If REQUIRED is true, but the reference provided is populated with a default value, the option is essentially optional.  Setting REQUIRED to true only forces the user to supply a value if the reference refers to an undefined or empty variable.  Note also that if the user provides no options on the command line, a general usage is printed, but if other options are supplied, and error about missing required options is generated.

=item C<addOptions> GETOPTHASH [REQUIRED OVERWRITE RENAME ADVANCED HEADING]

Add an existing Getopt::Long hash.  This method mainly serves to help facilitate quick conversion of existing scripts which already use Getopt::Long.

It returns a list (or reference to an array) of option IDs that can be used in makeMutuallyExclusive().

GETOPTHASH is a reference to the hash that is supplied to Getopt::Long's GetOptions() method.  See `perldoc Getopt::Long` for details on the structure of the hash.

addOptions can be called multiple times to add to the hash that will be eventually supplied to Getopt::Long's GetOptions() method.

REQUIRED is the value indicating whether all of the options provided in the hash are required on the command line or not.

If ADVANCED is non-zero, these options will only display in the advanced usage (i.e. when --extended is 3).

A HEADING string can be supplied to any option to have a section heading appear above the defined option.  Options appear in the usage in the order they are created, but note that required options without default values will appear at the top.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -e 2 -k test

I<Code>

    my $e_int = 3;
    my $k_str = 'default';
    addOptions(GETOPTHASH => {'e=i' => \$e_int,
                              'k=s' => \$k_str});
    processCommandLine();
    print("$k_str : $e_int\n");

I<Output>

    test : 2

=back

I<ASSOCIATED FLAGS>

n/a

I<LIMITATIONS>

This method does not convert input and output file options of existing scripts to utilize this module, nor does it convert output directory or output file suffix options.  It does not provide a means of setting the usage message.  It is only intended to provide a quick means to get an existing script that uses Getopt::Long already to quickly be able to use this module.

I<ADVANCED>

The GETOPTHASH may contain a code reference value (i.e. a reference to a subroutine (named or anonymous)) (e.g. `ref($value) eq 'CODE'`).  See the underlying module documentation by running `perldoc Getopt::Long` on the command line for details on the arguments, however the value supplied to the FLAG on the command line is either $_[0] (for FLAGLESS options supplied without a flag) or $_[1] (for options that are not FLAGLESS).

Note that any variable a subroutine (supplied via GETOPTHASH) modifies, will not be visible to CommandLineInterface.  CommandLineInterface however calls the subroutine for a number of reasons other than explicit values supplied on the command line in any particular run.  It will be called for the following reasons:

 1. To set an option supplied on the command line (as many times as it is
    supplied)
 2. To set the supplied DEFAULT value (if appropriate)
 3. To set a previously user-supplied default (if appropriate)
 4. To clear out a potential value initialized in main (by passing undef) if
    there is no default and a mutually exclusive partner option is supplied.

A subroutine in GETOPTHASH is not called to set (or clear out) a default value if no DEFAULT was supplied and a mutually exclusive option was not supplied.

A subroutine in GETOPTHASH is not called to set the supplied DEFAULT value if a user default for that option exists.

2 advanced/hidden parameters to this method exist:

OVERWRITE deactivates a default option that you wish to handle yourself.  The key must be an exact match and thus is intended for advanced users only, as it requires looking at the source code of this module.

RENAME: [in development/experimental] If a reference to a value in the GetOptions hash already exists, delete and remake the key-value pair using the associated key.

If REQUIRED is true, but the reference provided is populated with a default value, the option is essentially optional.  Setting REQUIRED to true only forces the user to supply a value if the reference refers to an undefined or empty variable.  Note also that if the user provides no options on the command line, a general usage is printed, but if other options are supplied, and error about missing required options is generated.

=item C<addOutdirOption> FLAG [REQUIRED DEFAULT HIDDEN SHORT_DESC LONG_DESC FLAGLESS ADVANCED HEADING DISPDEF]

Adds an output directory option to the command line interface.  All output files generated through the addOutfileSuffixOption() and addOutfileOption() methods will be put in the output directory if it is supplied.  The entire path (if any) is replaced with a path to the supplied output directory.  If an outdir is not provided by the user, the supplied path of the outfile or the input file (to which a suffix is added) is where the output file will go.

FLAG is the name or names of the flag the user supplies on the command line with a directory argument.  FLAG can be a single scalar value or a reference to an array of FLAGs.  Only alpha-numeric characters, dashes, and underscores are permitted.  Single character flags will be prepended with a single dash '-' and multi-character flags will get a double dash '--'.

It returns an option ID that can be used in makeMutuallyExclusive().

The output directory(/ies) that the user supplies are stored in a 2 dimensional array and are paired with the other file options in a 1:1 or 1:M relationship.  The file names/paths returned by getOutfile() will include the output directory that was supplied by the user via this option.

CLI requires that the user supply either a named output file or both an outfile suffix and input file(s) if they supply an output directory.

CLI creates directories supplied by the user automatically, before any file processing occurs and will issue an error if creation fails.  Creation happens when the command line options are processed, as a last step, after all other options are processed and outfile conflicts evaluated.

REQUIRED indicates whether CommandLineInterface should fail with an error if the user does not supply an output directory.  The REQUIRED value can be either 0 (false) or non-zero (e.g. "1") (true).

A DEFAULT output directory can be provided.  If the user does not supply an output directory, the default will be used.  If there is no default desired, do not include the DEFAULT key or supply it as undef (the builtin perl function).

To create an output directory with an immutable, always-present value (e.g. 'output') that the user should not see as an option in the usage or help output, set HIDDEN to a non-zero value.

SHORT_DESC is the short version of the usage message for this output directory option.  An empty string will cause this option to not be in the short version of the usage message.

LONG_DESC is the long version of the usage message for this output directory option.  If LONG_DESC is not defined/supplied and SHORT_DESC has a non-empty string, SHORT_DESC is copied to LONG_DESC.

Note, both SHORT_DESC and LONG_DESC have auto-generated formatting which includes details on the REQUIRED state as well as the flag(s) parsed from FLAG.

FLAGLESS, if non-zero, indicates that arguments without preceding flags are to be assumed to belong to this option.  Note, only 1 option may currently be flagless.

If ADVANCED is non-zero, this option will only display in the advanced usage (i.e. when --extended is 3).

A HEADING string can be supplied to any option to have a section heading appear above the defined option.  Options appear in the usage in the order they are created, but note that required options without default values will appear at the top.

DISPDEF is a "display default" shown in the usage.  Use this when a value is dynamically assigned, random, or long.

All calls to addOutdirOption() must occur before any/all calls to processCommandLine(), nextFileCombo(), getInfile, getNextFileGroup(), openOut(), openIn(), and getAllFileGroups().  If you wish to put calls to the add*Option methods at the bottom of the script, you must put them in a BEGIN block.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt' -o .out --outdir myoutput
    #or...
    example.pl --outfile test.out --outdir myoutput

I<Code>

    addOutdirOption(FLAG       => 'outdir',
                    REQUIRED   => 0,
                    DEFAULT    => undef,
                    HIDDEN     => 0,
                    SHORT_DESC => 'Output directory.',
                    LONG_DESC  => 'Output directory.  Will be created if ' .
                                  'it does not already exist.');

I<Output>

    myoutput/*.out

=back

I<ASSOCIATED FLAGS>

Default file options that are added if none defined (which also affect the behavior of this method):

    --outdir            Output directory. see addOutdirOption()

I<LIMITATIONS>

The programmer cannot require a 1:1, 1:M, or 1:1orM relationship between supplied directories and other file options (yet).  Requirement number 149, once implemented, will provide this capability.  Refer to the PAIR_WITH and PAIR_RELAT options in addInfileOption() to get an idea of how this eventual feature will be implemented.

Currently, there is no way to force the deletion of a directory.  Requirement 69, once implemented will always delete a pre-existing directory if 3 --overwrite flags are provided.

There is currently no way to obtain the output directory(/ies) that the user supplied on the command line alone, unless you parse them from the getOutfile() return string.  Requirement 150 will add this method.

There's no current hook for the programmer to obtain the status of directory creation (yet).  The only way to determine such a failure is by the return status of openOut().  Requirement 151 will add this hook.

Automatic creation of nested directories is not supported.  Requirement 152, once implemented will allow the programmer to specify that automatic creation of nested directories is allowed.

I<ADVANCED>

The relationship between the number of outdir flags and outdirs supplied to each outdir flag with the input files and named output files is enforced to be either ONETOMANY (1:M) or ONETOONE (1:1).  Typical usage is to either supply a single output directory or to supply as many directories as there are instances of input file flags.

An alternative usage is to supply as many directories as match the number of files supplied to a single input file flag (as long as all occurrences of the same input file flag and other types of input file flags have either the same number of files or 1 file.

One could also supply an output directory for each and every input file.

=item C<addOutfileOption> FLAG [COLLISIONMODE REQUIRED PRIMARY DEFAULT SHORT_DESC LONG_DESC FORMAT HIDDEN PAIR_WITH PAIR_RELAT FLAGLESS ADVANCED HEADING DISPDEF]

FLAG is the name or names of the flag the user supplies on the command line with a file argument.  FLAG can be a single scalar value or a reference to an array of FLAGs.  Only alpha-numeric characters, dashes, and underscores are permitted.  Single character flags will be prepended with a single dash '-' and multi-character flags will get a double dash '--'.

The return value is an option ID that is later used to obtain the output file names constructed from the output file names and output directory name(s) that the user has supplied on the command line (see getOutfile() and getNextFileGroup()).  It can also be used in a call to makeMutuallyExclusive() with IDs from other options.

COLLISIONMODE is an advanced feature that determines how to handle situations where 2 or more combinations of input files end up generating output into the same output file.

For example, if a pair of files has a ONETOMANY relationship, and the 'one' file is what has been assigned an outfile suffix, multiple combinations of that file with different input files of the 'many' type will have the same output file.  Or, if 2 input files in different source directories are being appended a suffix and an output directory has been supplied, those output file names will collide.  COLLISIONMODE is what determines what will happen in that situation.

COLLISIONMODE can be set to 1 of 3 modes/strategies, each represented by a string: 'error', 'merge', or 'rename' to handle these situations.  The default for addOutfileOption() is 'merge', which notably differs from the default for addOutfileSuffixOption() because it assumes that the user uses a suffix when each input file has an output file and uses an outfile option when multiple input files have a single output file (even though each mode supports both strategies).  A COLLISIONMODE of 'error' indicates that an error should be printed and the script should quit (if caught before file processing starts - if caught after file processing starts, only an error is issued and its up to the programmer to decide what to do with the failure status returned by openOut()).  A COLLISIONMODE of 'merge' means that pre-existing output files or output file names generated with the same name/path should be appended-to or concatenated together.  A COLLISIONMODE of 'rename' indicates that if 2 or more output file names have the same path/name, their file names will be manipulated to not conflict.  See the ADVANCED section for more details.

The COLLISIONMODE set here is over-ridden by the COLLISIONMODE set by setDefaults().  This is because the user is intended to use --collision-mode on the command line to change the behavior of the script and setDefaults is supplying a default value for that flag.  This behavior will change when requirement 114 is implemented.

REQUIRED indicates whether CommandLineInterface should fail with an error if the user does not supply a required output file type.  The value can be either 0 (false) or non-zero (e.g. "1") (true).

There may be any number of PRIMARY output file types.  Setting PRIMARY to a non-zero value indicates that if no output file suffix is supplied by the user and there is no default set, output to this output file type should be printed to STDOUT.

A DEFAULT output file can be provided.  If there is no DEFAULT, output will go to STDOUT.  If there is no default desired, do not include the DEFAULT key or supply it as undef (the builtin perl function).  Note, setting a DEFAULT suffix will cause output for this output file type to never be printed to STDOUT.

SHORT_DESC is the short version of the usage message for this output file type.  An empty string will cause this option to not be in the short version of the usage message.

LONG_DESC is the long version of the usage message for this output file type.  If LONG_DESC is not defined/supplied and SHORT_DESC has a non-empty string, SHORT_DESC is copied to LONG_DESC.

Note, both SHORT_DESC and LONG_DESC have auto-generated formatting which includes details on the REQUIRED state as well as the flag(s) parsed from FLAG.

FORMAT is the description of the output file format that is printed when --help is provided by the user.  The auto-generated details for output format descriptions includes the applicable flag(s).

To construct output file names with an immutable, always-present output file name (e.g. 'always_output.txt') that the user should not see as an option in the usage or help output, set HIDDEN to a non-zero value.  If HIDDEN is unsupplied, the default will be 0 if the file type is not linked to another file type that is itself HIDDEN.  If the linked file is HIDDEN, the default will be HIDDEN for this option as well.

PAIR_WITH and PAIR_RELAT allow the programmer to require a certain relative relationship with other input (or output) file parameters (already added).  PAIR_WITH takes the input (or output) file type ID (returned by the previous call to addInfileOption() or addOutfileOption()) and PAIR_RELAT takes one of 'ONETOONE', 'ONETOMANY', or 'ONETOONEORMANY'.  For example, if there should be one output file for every group of input files of type $intype1, then PAIR_WITH and PAIR_RELAT should be $intype1 and 'ONETOMANY', respectively.

FLAGLESS, if non-zero, indicates that arguments without preceding flags are to be assumed to belong to this option.  Note, only 1 option may currently be flagless.

If ADVANCED is non-zero, this option will only display in the advanced usage (i.e. when --extended is 3).

A HEADING string can be supplied to any option to have a section heading appear above the defined option.  Options appear in the usage in the order they are created, but note that required options without default values will appear at the top.

DISPDEF is a "display default" shown in the usage.  Use this when a value is dynamically assigned, random, or long.

All calls to addOutfileOption() must occur before any/all calls to processCommandLine(), nextFileCombo(), getInfile, getNextFileGroup(), openOut(), openIn(), and getAllFileGroups().  If you wish to put calls to the add*Option methods at the bottom of the script, you must put them in a BEGIN block.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt' -j output.out

I<Code>

    my $id1 = addInfileOption(FLAG       => 'i',
                              REQUIRED   => 1,
                              DEFAULT    => undef,
                              PRIMARY    => 1,
                              SHORT_DESC => 'Input file(s).',
                              LONG_DESC  => '1 or more text input files.',
                              FORMAT     => 'ASCII text.');
    my $oid = addOutfileOption(FLAG       => 'j',
                               REQUIRED   => 0,
                               PRIMARY    => 1,
                               DEFAULT    => undef,
                               HIDDEN     => 0,
                               SHORT_DESC => 'Output file.',
                               LONG_DESC  => 'ASCII Text output file.',
                               FORMAT     => 'Tab delimited ASCII text.',
                               PAIR_WITH  => $id1,
                               PAIR_RELAT => 'ONETOMANY');

I<Output>

    output.out

=back

I<ASSOCIATED FLAGS>

Default file options that are added if none defined (which also affect the behavior of this method):

    --outfile           Output file.
    --outdir            Output directory. see addOutdirOption()

I<LIMITATIONS>

None.

I<ADVANCED>

A COLLISIONMODE of 'rename' handles conflicting output file names by appending the input file names they are associated with.  All of the files in the file set returned by the nextFileCombo() iterator are evaluated, and the fewest number of input file names are concatenated together with the output file name as is needed to make the output file names unique.

=item C<addOutfileSuffixOption> FLAG FILETYPEID [VARREF REQUIRED PRIMARY DEFAULT HIDDEN SHORT_DESC LONG_DESC FORMAT COLLISIONMODE ADVANCED HEADING DISPDEF]

Adds an output file suffix option to the command line interface.

FLAG is the name or names of the flag the user supplies on the command line with a suffix argument.  FLAG can be a single scalar value or a reference to an array of FLAGs.  Only alpha-numeric characters, dashes, and underscores are permitted.  Single character flags will be prepended with a single dash '-' and multi-character flags will get a double dash '--'.

The return value is an option ID that is later used to obtain the output file names constructed from the input file names and output directory name(s) that the user has supplied on the command line (see getOutfile() and getNextFileGroup()).  It can also be used in a call to makeMutuallyExclusive() with IDs from other options.  Only one suffix is allowed per flag on the command line.  Note, CommandLineInterface appends only.

FILETYPEID is the ID of the input file type returned by addInfileOption() indicating the files to which the suffix provided by the user on the command line will be appended.

Since output file names are constructed automatically and retrieved by getOutfile(), the VARREF option is not required (and is in fact discouraged).  But if you want to be able to obtain the suffix to construct custom file names (which note, will not have the full overwrite protection provided by CommandLineInterface), you can provide a reference to a scalar so that after the command line is processed, you will have the suffix provided by the user.  Note also that DEFAULT is what is used as the suffix when the user does not provide one.  The pre-existing value of VARREF is ignored.

REQUIRED indicates whether CommandLineInterface should fail with an error if the user does not supply a required suffix type.  The value can be either 0 (false) or non-zero (e.g. "1") (true).

There may be any number of PRIMARY output file types.  Setting PRIMARY to a non-zero value indicates that if no output file suffix is supplied by the user and there is no default set, output to this output file type should be printed to STDOUT.

A DEFAULT output file suffix can be provided.  If the user does not supply a suffix, the default will be used to construct output file names.  If there is no default desired, do not include the DEFAULT key or supply it as undef (the builtin perl function).  Note, setting a DEFAULT suffix will cause output for this output file type to never be printed to STDOUT.

To construct output file names with an immutable, always-present suffix (e.g. '.out') that the user should not see as an option in the usage or help output, set HIDDEN to a non-zero value.  If HIDDEN is unsupplied, the default will be 0 if the file type is not linked to another file type that is itself HIDDEN.  If the linked file is HIDDEN, the default will be HIDDEN for this option as well.

SHORT_DESC is the short version of the usage message for this output file type.  An empty string will cause this option to not be in the short version of the usage message.

LONG_DESC is the long version of the usage message for this output file type.  If LONG_DESC is not defined/supplied and SHORT_DESC has a non-empty string, SHORT_DESC is copied to LONG_DESC.

Note, both SHORT_DESC and LONG_DESC have auto-generated formatting which includes details on the REQUIRED and PRIMARY states as well as the flag(s) parsed from FLAG.

FORMAT is the description of the output file format that is printed when --help is provided by the user.  The auto-generated details for output format descriptions includes the applicable flag(s).

COLLISIONMODE is an advanced feature that determines how to handle situations where 2 or more combinations of input files end up generating output into the same output file.

For example, if a pair of files has a ONETOMANY relationship, and the 'one' file is what has been assigned an outfile suffix, multiple combinations of that file with different input files of the 'many' type will have the same output file.  Or, if 2 input files in different source directories are being appended a suffix and an output directory has been supplied, those output file names will collide.  COLLISIONMODE is what determines what will happen in that situation.

COLLISIONMODE can be set to 1 of 3 modes/strategies, each represented by a string: 'error', 'merge', or 'rename' to handle these situations.  The default for addOutfileOption() is 'merge', which notably differs from the default for addOutfileSuffixOption() because it assumes that the user uses a suffix when each input file has an output file and uses an outfile option when multiple input files have a single output file (even though each mode supports both strategies).  A COLLISIONMODE of 'error' indicates that an error should be printed and the script should quit (if caught before file processing starts - if caught after file processing starts, only an error is issued and its up to the programmer to decide what to do with the failure status returned by openOut()).  A COLLISIONMODE of 'merge' means that pre-existing output files or output file names generated with the same name/path should be appended-to or concatenated together.  A COLLISIONMODE of 'rename' indicates that if 2 or more output file names have the same path/name, their file names will be manipulated to not conflict.  See the ADVANCED section for more details.

The COLLISIONMODE set here is over-ridden by the COLLISIONMODE set by setDefaults().  This is because the user is intended to use --collision-mode on the command line to change the behavior of the script and setDefaults is supplying a default value for that flag.  This behavior will change when requirement 114 is implemented.

DISPDEF is a "display default" shown in the usage.  Use this when a value is dynamically assigned, random, or long.

If ADVANCED is non-zero, this option will only display in the advanced usage (i.e. when --extended is 3).

A HEADING string can be supplied to any option to have a section heading appear above the defined option.  Options appear in the usage in the order they are created, but note that required options without default values will appear at the top.

All calls to addOutfileSuffixOption() must occur before any/all calls to processCommandLine(), nextFileCombo(), getOutfile, getNextFileGroup(), openIn(), openOut(), and getAllFileGroups().  If you wish to put calls to the add*Option methods at the bottom of the script, you must put them in a BEGIN block.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt' -o .out

I<Code>

    my $id1 = addInfileOption(FLAG       => 'i',
                              REQUIRED   => 1,
                              DEFAULT    => undef,
                              PRIMARY    => 1,
                              SHORT_DESC => 'Input file(s).',
                              LONG_DESC  => '1 or more text input files.',
                              FORMAT     => 'ASCII text.');
    my $oid = addOutfileSuffixOption(FLAG       => 'o',
                                     FILETYPEID => $id1,
                                     VARREF     => undef,
                                     REQUIRED   => 0,
                                     PRIMARY    => 1,
                                     DEFAULT    => undef,
                                     HIDDEN     => 0,
                                     SHORT_DESC => 'Outfile suffix.',
                                     LONG_DESC  => ('Suffix appended to file '.
                                                    'submitted via -i.'),
                                     FORMAT     => ('Tab delimited ASCII ' .
                                                    'text, 1 tab per line.  ' .
                                                    'First column is a ' .
                                                    'unique ID and the  ' .
                                                    'secondcolumn is a ' .
                                                    'value.');

I<Output>

    *.txt.out

=back

I<ASSOCIATED FLAGS>

Default file options that are added if none defined (which also affect the behavior of this method):

    -o                  Output file suffix. See addOutfileSuffixOption()
    -i                  Input file. See addInfileOption()


I<LIMITATIONS>

Does not replace existing extensions at the end of input file names (yet).  This will be addressed when requirement 171 is implemented.  Nor does it insert a dot between the input file and the supplied suffix.  If the user wants the suffix to be appended with a dot, the dot must be supplied as a part of the suffix.

I<ADVANCED>

The user can supply an empty string ('') as an output file suffix which would cause an over-write situation (unless an output directory was specified (see addOutdirOption())), however this would trigger an overwrite error and the script would quit before processing any files.  The user could supply --overwrite to allow the input file to be overwritten, but note that the code would have to be written in a way such that the input is fully read in and the output buffered, in order for this to work properly.  To prevent a user from creating overwrite situations like this, you must validate the output file name returned by getOutfile() is different from the file name returned by getInfile().

Note that addOutfileOption() is a wrapper for a hidden and specially treated call to addInfileOption() containing the output file name as what is read in with the supplied flag, followed by a call to addOutfileSuffixOption() with a default set as an empty string.  The return value of addOutfileOption() is what is returned by the internal call to addOutfileSuffixOption().  In this way, getOutfile works for both output file suffix IDs and output file IDs.

A COLLISIONMODE of 'rename' handles conflicting output file names by compounding input file names.  This requires multiple types of input files.  All of the files in the file set advanced to by the nextFileCombo() iterator are evaluated and the fewest number of input file names are concatenated together as is needed to make the output file names unique.

=item C<addOutfileTagteamOption> FLAG_SUFF FLAG_FILE FILETYPEID|PAIR_WITH [PAIR_RELAT VARREF_SUFF REQUIRED PRIMARY FORMAT DEFAULT DEFAULT_IS_FILE HIDDEN_SUFF HIDDEN_FILE SHORT_DESC_SUFF SHORT_DESC_FILE LONG_DESC_SUFF LONG_DESC_FILE COLLISIONMODE_SUFF COLLISIONMODE_FILE ADVANCED_SUFF ADVANCED_FILE DISPDEF HEADING]

Adds an output file suffix option and an output file option to the command line interface.  The resulting 2 options are mutually exclusive and allow the user to either specify a full output file name or an output file suffix (appended to an input file name) for the same generated output.

The return value is an output type ID that behaves exactly the same way as the returned ID from either addOutfileOption() or addOutfileSuffixOption(), and is later used to obtain the output file names that were either fully supplied or constructed from the input file names, both of which are put into any output directory name(s) that the user has supplied on the command line (see getOutfile() and getNextFileGroup()).  The programmer does not have to be concerned with how the user supplied the output file names.

Note, the interface will create a default outfile tagteam by if addOutfileOption() or addOutfileSuffixOption() (or both) are never called.

Note, this method is essentially a wrapper to both of the addOutfileOption() and addOutfileSuffixOption() methods, thus for each parameter below, please refer to that method's parameter description..

FLAG_SUFF & FLAG_FILE - See addOutfileSuffixOption's & addOutfileOption's FLAG parameter (respectively).

FILETYPEID - See addOutfileSuffixOption's FILETYPEID & addOutfileOption's PAIR_WITH parameters.

PAIR_RELAT - See addOutfileOption's PAIR_RELAT parameter.

VARREF - See addOutfileSuffixOption's VARREF parameter.

REQUIRED - See addOutfileSuffixOption's & addOutfileOption's REQUIRED parameter.

PRIMARY - See addOutfileSuffixOption's & addOutfileOption's PRIMARY parameter.

FORMAT - See addOutfileSuffixOption's & addOutfileOption's FORMAT parameter.

DEFAULT - See addOutfileSuffixOption's DEFAULT parameter.

DEFAULT_IS_FILE - If this is a non-zero value, the DEFAULT parameter (above) is supplied to addOutfileOption's DEFAULT parameter and addOutfileSuffixOption's DEFAULT parameter is supplied as undefined.  Only one or the other can have a default value, not both.

DISPDEF - See addOutfileSuffixOption's DISPDEF parameter.

HIDDEN_SUFF & HIDDEN_FILE - See addOutfileSuffixOption's & addOutfileOption's HIDDEN parameter (respectively).  Briefly - whether or not the option is hidden in the usage output.

SHORT_DESC_SUFF & SHORT_DESC_FILE - See addOutfileSuffixOption's & addOutfileOption's SHORT_DESC parameter (respectively).

LONG_DESC_SUFF & LONG_DESC_FILE - See addOutfileSuffixOption's & addOutfileOption's LONG_DESC parameter (respectively).

COLLISIONMODE_SUFF & COLLISIONMODE_FILE - See addOutfileSuffixOption's & addOutfileOption's COLLISIONMODE parameter (respectively).

All calls to addOutfileTagteamOption() must occur before any/all calls to processCommandLine(), nextFileCombo(), getOutfile, getNextFileGroup(), openIn(), openOut(), and getAllFileGroups().  If you wish to put calls to the add*Option methods at the bottom of the script, you must put them in a BEGIN block.

If ADVANCED_FILE & ADVANCED_SUFF are non-zero, thed outfile and outfile suffix options will only display in the advanced usage (i.e. when --extended is 3).

A HEADING string can be supplied to any option to have a section heading appear above the defined option.  Options appear in the usage in the order they are created, but note that required options without default values will appear at the top.

I<EXAMPLE>

=over 4

I<Command>

    #EXAMPLE1:
    example.pl -i '*.txt' -o .out

    #EXAMPLE2:
    example.pl -i '*.txt' --outfile combined.out

    #EXAMPLE3:
    example.pl -i '*.txt'

I<Code>

    my $id1 = addInfileOption(FLAG       => 'i',
                              REQUIRED   => 1,
                              DEFAULT    => undef,
                              PRIMARY    => 1,
                              SHORT_DESC => 'Input file(s).',
                              LONG_DESC  => '1 or more text input files.',
                              FORMAT     => 'ASCII text.');
    my $oid = addOutfileTagteamOption(FLAG_SUFF       => 'o',
                                      FLAG_FILE       => 'outfile',
                                      FILETYPEID      => $id1,
                                      PRIMARY         => 1,
                                      FORMAT          => 'Tab delimited.',
                                      SHORT_DESC_SUFF => 'Outfile suffix.',
                                      SHORT_DESC_FILE => 'Outfile.',
                                      LONG_DESC_SUFF  => ('Suffix appended ' .
                                                          'to file submitted '.
                                                          'via -i'),
                                      LONG_DESC_FILE => 'Outfile.  See ' .
                                                        '--help for format.');

I<Output>

    #EXAMPLE1:
    *.txt.out

    #EXAMPLE2:
    combined.out

    #EXAMPLE3:
    All output goes to STDOUT

=back

I<ASSOCIATED FLAGS>

Default file options that are added if none defined (which also affect the behavior of this method):

    -o                  Output file suffix. See addOutfileSuffixOption()
    --outfile           Output file. See addOutfileOption()
    -i                  Input file. See addInfileOption()


I<LIMITATIONS>

See LIMITATIONS for each of the wrapped methods: addOutfileOption() and addOutfileSuffixOption().

I<ADVANCED>

The output file ID that is returned is actually a tagteam ID.  When getOutfile() is called with the ID, it checks the ID to see if it is a tagteam ID.  If it is, it checks to see which of the two options in the tagteam were supplied by the user and returns the corresponding output file name (whether it was created using an input file name, or supplied as a full output file name by the user.

The default COLLISIONMODE_* is different for the 2 types of options.  The default mode for the suffix option is 'error'.  I.e. If 2 file names are constructed with the same name/path, a fatal error occurs, preventing the script from processing any files.  The default mode for the create outfile option is 'merge', meaning if an output file name is supplied multiple times, the output is aggregated in that file (not overwritten).

You can actually call addOutfileTagteamOption() once with no parameters to create the default output file options as long as addOutfileOption() and addOutfileSuffixOption() have not been called without any parameters.  If either addOutfileOption() or addOutfileSuffixOption() have not been called before processCommandLine() is called, they are called without any options and made into a tagteam with the first outfile option of the opposing type.  For example, if you call addOutfileSuffixOption() and never call addOutfileOption(), it is automatically called with no parameters and made into a tagteam with the -o option you explicitly created.  There is currently no way to prevent this automatic option creation, but if you do not want to allow a user to supply output files by one or the other method, you can create a hidden version of that option.

FILETYPEID can actually be an optional parameter is there has only been 1 call to addInfileOption().  If there have been multiple input file options created, the FILETYPEID is required.

=item C<addOverwriteOption> [FLAG DEFAULT DISPDEF REQUIRED HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This is a builtin option of type count (see addOption() and addBuiltinOption()).  It affects whether or not pre-existing output files will generate an error or not and its user-supplied (or default) value is retrievable via the isOverwrite() getter method (after processCommandLine() has been explicitly or implicitly called) which returns the overwrite level integer value.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameter values:

    FLAG        => 'overwrite'
    REQUIRED    => 0
    DISPDEF     => undef
    DEFAULT     => 0
    HIDDEN      => 0
    SHORT_DESC  => undef
    LONG_DESC   => "Overwrite existing output files.  By default, existing
                    output files will not be over-written.  Supply twice to
                    safely remove pre-existing output directories (See
                    --outdir).  This will not remove a directory containing
                    manually touched files."
    ADVANCED    => 0
    HEADING     => ''

I<EXAMPLE>

=over 4

I<Command>

    example.pl --overwrite --outfile out.txt

I<Code>

    addOutfileOption();
    addOverwriteOption();
    processCommandLine();
    openOut(*OUT,getOutfile());
    print("1");

I<Output> (out.txt)

    1

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --overwrite         Renamable flag.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addPipelineOption> [FLAG DEFAULT DISPDEF REQUIRED HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This is a builtin option of type negbool (see addOption() and addBuiltinOption()).  It controls the inclusion of the script name in errors, warnings, and debug messages in order to know where those prints are coming from when mixed with other output.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameters values:

    FLAG        => 'pipeline'
    DEFAULT     => undef
    DISPDEF     => undef
    REQUIRED    => 0
    HIDDEN      => 0
    ADVANCED    => 1
    SHORT_DESC  => undef
    LONG_DESC   => "Supply --pipeline to include the script name in errors,
                    warnings, and debug messages.  If not supplied (and no
                    default set), the script will automatically determine if it
                    is running within a series of piped commands or as a part of
                    a parent script.  Note, supplying either flag will prevent
                    that check from happening."
    HEADING     => 'USER DEFAULTS'

I<EXAMPLE>

=over 4

I<Command>

    example.pl --pipeline

I<Code>

    addSaveArgsOption();
    processCommandLine();
    warning("Invalid option.");

I<Output>

    WARNING1:example.pl: Invalid option.

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --debug             Renamable flag.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addQuietOption> [FLAG DEFAULT DISPDEF HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This is a builtin option of type bool (see addOption() and addBuiltinOption()).  It controls output of the verbose(), debug(), warning(), and error() methods and its user-supplied (or default) value is retrievable via the isQuiet() getter method (after processCommandLine() has been explicitly or implicitly called) which returns a 0 or 1.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameters values:

    FLAG        => 'quiet'
    DISPDEF     => undef
    DEFAULT     => 0
    HIDDEN      => 0
    SHORT_DESC  => undef
    LONG_DESC   => "Quiet mode."
    ADVANCED    => 0
    HEADING     => ''

I<EXAMPLE>

=over 4

I<Command>

    example.pl --silent

I<Code>

    addQuietOption(FLAG => 'silent');
    processCommandLine();
    verbose("This is verbose level 1 (the default).");
    warning("Meh, this is just a warning.");
    error("Danger Will Robinson!");
    print(isQuiet());

I<Output> (mised stderr & stdout)

    0

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --quiet             Renamable flag.  See isQuiet()

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addRunOption> [FLAG DISPDEF HIDDEN ADVANCED SHORT_DESC LONG_DESC]

This is a builtin option of type bool (see addOption() and addBuiltinOption()).  It explicitly controls whether the script will run or not when the default run mode (set by setDefaults()) is either usage, help, or dry-run.  By default, run mode is determined based on the default run mode and the assortment of options supplied.  The only time the --run option is necessary is when the default run mode is not 'run' and all options are optional or have default values.  There is no getter method for this option.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameters values:

    FLAG        => 'run'
    DISPDEF     => undef
    REQUIRED    => 0
    HIDDEN      => dynamically determined
    ADVANCED    => 0
    SHORT_DESC  => "Run the script."
    LONG_DESC   => "This option runs the script.  It is only necessary to supply
                    this option if the script contains no required options or
                    when all required options have default values that are
                    either hard-coded, or provided via --save-args."

I<EXAMPLE>

=over 4

I<Command>

    example.pl --run

I<Code>

    addRunOption(HIDDEN => 0);
    processCommandLine();
    print("Ran.\n");

I<Output>

    Ran.

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --run               Renamable flag.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addSaveArgsOption> [FLAG HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This is a builtin option of type bool (see addOption() and addBuiltinOption()).  It controls the storage of user defaults and its user-supplied (or default) value is not retrievable since the script exits immediately after processing.

It returns an option ID that can be used in makeMutuallyExclusive().

Options saved as user defaults by --saved-args will be reflected in the default values displayed in the usage.  If saved options exist, the --save-args option will appear in all usage outputs (except the error usage) and will be shown in the command displayed in any output file headers (inside square brackets at the end of the command).

Defaults are stored in ~/.rpst/$0.  Note, if the user adds default flags, it will change the default run mode from --usage to --run and will change the run mode flags shown in the usage (--run, --dry-run, --usage, & --help).

Default parameters values:

    FLAG        => 'save-args'
    DEFAULT     => 0
    HIDDEN      => 0
    ADVANCED    => ($user_defaults_exist ? 0 : 1)
    SHORT_DESC  => "Save accompanying command line arguments as user defaults."
    LONG_DESC   => "Save accompanying command line arguments as defaults to be
                    used in every call of this script.  Replaces previously
                    saved args.  Supply without other args to removed saved
                    args.  When there are no user defaults set, this option will
                    only appear in the advanced usage (--extended 2).  Values
                    are stored in [/path/to/.rpst]."
    HEADING     => 'USER DEFAULTS'

I<EXAMPLE>

=over 4

I<Command>

    example.pl --save-args --verbose

I<Code>

    addSaveArgsOption(ADVANCED => 0);
    processCommandLine();

I<Output>

    Old user defaults: [].
    New user defaults: [--verbose].
    Changing default run mode to 'run'
      --dry-run will be added-to/remain-in the usage output.
      --usage   will be added-to/remain-in the usage output.
      --help    will be added-to/remain-in the usage output.

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --run               Renamable flag.
    --dry-run           Renamable flag.
    --usage             Renamable flag.
    --help              Renamable flag.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addSkipOption> [FLAG DEFAULT DISPDEF REQUIRED HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This is a builtin option of type bool (see addOption() and addBuiltinOption()).  It affects whether or not pre-existing output files will be skipped or not by the nextFileCombo() iterator.

It returns an option ID that can be used in makeMutuallyExclusive().

If any output file among multiple output file types already exists when --skip is true, the entire set of files is skipped.  E.g. if input file 1 is processed to create output files 'A' and 'B', and output file 'A' exists and 'B' does not, input file 1 is not processed and output files 'A' and 'B' are not touched/created.  Input file 2 however will proceed to be processed to generate output files of types 'A' and 'B' of its own.

The user-supplied (or default) value of the --skip option is retrievable via the isSkip() getter method (after processCommandLine() has been explicitly or implicitly called) which returns a 0 or 1 value.

Default parameter values:

    FLAG        => 'skip'
    REQUIRED    => 0
    DISPDEF     => undef
    DEFAULT     => 0
    HIDDEN      => 0
    SHORT_DESC  => undef
    LONG_DESC   => "Skip existing output files."
    ADVANCED    => 0
    HEADING     => ''

I<EXAMPLE>

=over 4

I<Command>

    echo "test" > out.txt
    example.pl --skip-existing --outfile out.txt

I<Code>

    addOutfileOption();
    addOverwriteOption();
    processCommandLine();
    if(openOut(*OUT,getOutfile)))
      {print("1")}

I<Output> (out.txt)

    test

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --skip              Renamable flag.

I<LIMITATIONS>

There is no way to prevent print statements when openOut does not open a skipped file, so the return of openOut() must be checked before printing.

I<ADVANCED>

n/a

=item C<addUsageOption> [FLAG DISPDEF HIDDEN ADVANCED SHORT_DESC LONG_DESC]

This is a builtin option of type bool (see addOption() and addBuiltinOption()).  It controls whether the script will prin the usage and exit or not.  There is no getter method to retrieve the value of this option, as the script automatically exits when this option is encountered.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameters values:

    FLAG        => 'usage'
    DISPDEF     => undef
    REQUIRED    => 0
    HIDDEN      => dynamically determined
    ADVANCED    => 0
    SHORT_DESC  => undef
    LONG_DESC   => "Print this usage message."

I<EXAMPLE>

=over 4

I<Command>

    example.pl --usage

I<Code>

    addUsageOption(HIDDEN => 0);
    processCommandLine();

I<Output> (standard error - no out.txt file created)

    example.pl [OPTIONS]

      <file*...>...       Input file(s).
      -o <sfx>            [STDOUT] Outfile suffix appended to file names
                          supplied to [-i].
      --help              Print general info and file formats.
      --run               Run the script.
      --extended [<cnt>]  Print detailed usage.

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --usage             Renamable flag.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addVerboseOption> [FLAG DEFAULT DISPDEF REQUIRED HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This is a builtin option of type count (see addOption() and addBuiltinOption()).  It controls output of the verbose() method and its user-supplied (or default) value is retrievable via the isVerbose() getter method (after processCommandLine() has been explicitly or implicitly called) which returns the verbose level integer value.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameters values:

    FLAG        => 'verbose'
    REQUIRED    => 0
    DISPDEF     => undef
    DEFAULT     => 0
    HIDDEN      => 0
    SHORT_DESC  => undef
    LONG_DESC   => "Verbose mode."
    ADVANCED    => 0
    HEADING     => 'UNIVERSAL BASIC OPTIONS'

I<EXAMPLE>

=over 4

I<Command>

    example.pl --verbosity

I<Code>

    addVerboseOption(FLAG => 'verbosity');
    processCommandLine();
    verbose("This is verbose level 1 (the default).");
    verbose({LEVEL => 2},"This is verbose level 2.");
    print(isVerbose());

I<Output> (mised stderr & stdout)

    This is verbose level 1 (the default).
    1

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --verbose           Renamable flag.  See verbose() and verboseOverMe()

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<addVersionOption> [FLAG DISPDEF HIDDEN ADVANCED SHORT_DESC LONG_DESC HEADING]

This is a builtin option of type bool (see addOption() and addBuiltinOption()).  It causes the script to output version information set by setScriptInfo().  There is no getter for this option, as when the flag is provided, the script exits immediately after the flag is encountered during command line processing.

It returns an option ID that can be used in makeMutuallyExclusive().

Default parameters values:

    FLAG        => 'version'
    DISPDEF     => undef
    HIDDEN      => 0
    SHORT_DESC  => undef
    LONG_DESC   => "Verbose mode."
    ADVANCED    => 0
    HEADING     => ''

I<EXAMPLE>

=over 4

I<Command>

    example.pl -v

I<Code>

    setScriptInfo(VERSION => '1.0.1');
    addVersionOption(FLAG => 'v');
    processCommandLine();

I<Output>

    1.0.1

=back

I<ASSOCIATED FLAGS>

The following default options are affected by this method:

    --version           Renamable flag.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<closeIn> HANDLE

Closes and untracks the file connected to HANDLE.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt'

I<Code>

    closeIn(HANLDE => *INP);

    #or

    closeIn(*INP);

I<Output>

    n/a

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all errors, warnings, & debugs.  See isQuiet()
    --verbose           Prints status.  See verbose() and verboseOverMe()
    --debug             Prints debug messages.  See debug()

I<LIMITATIONS>

None.

I<ADVANCED>

Generates verbose messages if --verbose is supplied on the command line and QUIET was not supplied to openIn (or was 0).

=item C<closeOut> HANDLE

Closes, de-selects, and untracks the file connected to HANDLE.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt'

I<Code>

    closeIn(*OUTP);

    #or

    openOut(HANLDE => *OUTP);

I<Output>

    n/a

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all errors, warnings, & debugs.  See isQuiet()
    --verbose           Prints status.  See verbose() and verboseOverMe()
    --debug             Prints debug messages.  See debug()

I<LIMITATIONS>

None.

I<ADVANCED>

Generates verbose messages if --verbose is supplied on the command line and QUIET was not supplied to openOut (or was 0).

Will not close STDOUT.

=item C<debug> EXPRs [{LEVEL DETAIL}]

Print messages along with line numbers.  Messages are prepended with 'DEBUG#: ' where # indicated the order in which the debug calls were made.

Multiple instances of --debug (or a value supplied to --debug) increases the debug level.

LEVEL (which defaults to 1) indicates the minimum value of --debug (supplied by the user) at which this message will print.  E.g. If the message this prints is assigned level 2 and the user supplies `--debug 2` on the command line (or higher), the message will print.  Any lower, and it will not print.

A debug LEVEL greater than 1 also inserts a call trace in front of the debug message (and after the debug number).

Note that if logging of debug messages is enabled and log output is not being mirrored to standard error (see addLogfileOption() and/or addLogfileSuffixOption()), all debug output to standard error will be suppressed.

I<EXAMPLE>

=over 4

I<Command>

    example.pl '*.txt'

I<Code>

    debug({LEVEL=>1},"This is a debug message.");

I<Output>

    DEBUG1: This is a debug message.

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --debug             Prints debug messages.
    --quiet             Suppress all error, warning, verbose, & debug messages.
    --pipeline          Prepends script name to errors, warnings, & debugs.
    --logfile           Can redirect verbose output to a log file
    --logfile-suffix    Can redirect verbose output to a log file

I<LIMITATIONS>

The call trace currently indicates method name and line number, but does not yet indicate file name.  This will be addresses requirement 170 is implemented.

I<ADVANCED>

Supplying a negative level to --debug on the command line debugs the CommandLineInterface inner-workings.  The debug level of CommandLineInterface that produces the most debug output is -99.

=item C<editAppendOption>

See C<addAppendOption> for parameters and C<editBuiltinOption> for functionality.

=item C<edit*Builtin*Option>

See C<addOption> for parameters.

This method cannot be called directly.  It is called by the following methods.

    editVerboseOption
    editQuietOption
    editOverwriteOption
    editSkipOption
    editHeaderOption
    editVersionOption
    editExtendedOption
    editForceOption
    editDebugOption
    editSaveArgsOption
    editPipelineOption
    editErrorLimitOption
    editAppendOption
    editRunOption
    editDryRunOption
    editUsageOption
    editHelpOption
    editCollisionOption

For each builtin option, it checks a stored global list of editable options (a subset of addOption()'s parameters) to validate the options provided and calls addOption() with the validated parameters.  Using the above "edit" option methods does not change the position of the option in the usage.  To change the order of the builtin options, see the add___Option() methods and the addBuiltinOption() method.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<editCollisionOption>

=item C<editDebugOption>

=item C<editDryRunOption>

=item C<editErrorLimitOption>

=item C<editExtendedOption>

=item C<editForceOption>

=item C<editHeaderOption>

=item C<editHelpOption>

=item C<editOverwriteOption>

=item C<editPipelineOption>

=item C<editQuietOption>

=item C<editRunOption>

=item C<editSaveArgsOption>

=item C<editSkipOption>

=item C<editUsageOption>

=item C<editVerboseOption>

=item C<editVersionOption>

For all above edit*Option() methods, see C<add*Option> for parameters and C<editBuiltinOption> for functionality.

=item C<error> EXPRs

See C<warning>.

=item C<flushStderrBuffer> [FORCE]

This method flushes any debug, error, warning, or verbose messages that might be in the buffer, if the flags linked to those messages (e.g. --verbose, --debug, --error-limit) have been read from the command line and their associated class variables defined.  This method is called automatically, thus you never need to call it explicitly.  It's only useful when debugging fatal errors that occur before processCommandLine() is called.

Standard error messages only get buffered if they are generated before the command line arguments have been processed.  The reason for this is to wait until flags such as --quiet have been processed so that CommandLineInterface knows whether it should print its buffer or suppress it.  processCommandLine() calls flushStderrBuffer().

By default, flushStderrBuffer() does not print messages if the associated flag's variable (e.g. $verbose) is defined and true.  To force the flushing of messages awaiting the definition of such variables, use the FORCE parameter, set to a non-zero value.

flushStderrBuffer() is not exported by default, thus you must either supply it in your `use CommandLineInterface qw(... flushStderrBuffer);` statement or call it using the package name: `CommandLineInterface::flushStderrBuffer();`.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt'

I<Code>

    error("Something went wrong in pre-processing");
    CommandLineInterface::flushStderrBuffer(1);
    processCommandLine();

I<Output>

    ERROR: Something went wrong in pre-processing.

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all error, warning, verbose, & debug messages.
    --error-limit       Suppress some errors & warnings.  See error()/warning()
    --verbose           Prints status.  See verbose() and verboseOverMe()
    --debug             Prints debug messages.  See debug()

I<LIMITATIONS>

None.

I<ADVANCED>

Upon successful exit, flushStderrBuffer(1) is called via the quit() method (which is called in the END block).  If not previously called elsewhere, processCommandLine() is called just before the flush, meaning that if there was not a problem processing the command line arguments, the buffer should be empty.  If you see messages on STDERR even though you supplied the --quiet flag, something has gone wrong with command line argument processing.

=item C<getAllFileGroups> [FILETYPEID*]

getAllFileGroups returns a 2D array of input files provided by all instances of the flag defined by addInfileOption.  The inner arrays each hold all files specified by a single instance of a flag on the command line, provided space-delimited or globbed file names.  In scalar context, it returns a reference to an array of arrays of file names.  In list context, it returns an array of arrays of file names.

FILETYPEID is the ID returned by addInfileOption().  Supply it to specify the type of input files supplied by the flag defined by addInfileOption().

* FILETYPEID is optional when there is only 1 input file type, in which case, it defaults to the single input file type.  It is required otherwise.

I<EXAMPLE>

=over 4

I<Command>

    #>ls
    #1.txt 2.txt 3.txt a.text b.text c.text

    example.pl -i '*.txt' -i '*.text'

I<Code>

    my $fid = addInfileOption(FLAG => 'i');
    processCommandLine();
    foreach my $inf_group (getAllFileGroups())
      {print(join(' ',@$inf_group),"\n")}

I<Output>

    1.txt 2.txt 3.txt
    a.text b.text c.text

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all error, warning, verbose, & debug messages.

Default file options that are added if none defined (which also affect the behavior of this method):

    -i                  Input file. see addInfileOption()

I<LIMITATIONS>

This method can only be used to retrieve input files, not output files, nor is there yet a way to retrieve outfile stubs or suffixes.  Until these functions have been implemented, it is highly recommended to use the nextFileCombo() iterator in combination with getInfile() and getOutfile() instead of this method.

This method does not skip any input files that may be associated with existing output files when --skip is provided.

I<ADVANCED>

n/a

=item C<getCommand> [INCLUDE_PERL_PATH NO_DEFAULTS INC_DEFMODE]

Returns a string containing the command that was issued on the command line (without input or output redirects).  It (by default) incorporates command line parameters that were previously saved using the --save-args flag.  Added defaults are commented at the end of the command to denote that they were added by the script.  This method is called automatically to generate output file headers containing the command that generated them and when --verbose is supplied.

The command returned by getCommand() is what the shell gives it, thus unless glob characters such as '*', '?', etc. are wrapped in quotes, the command returned will be post-shell expansion/interpolation.  You do not have to call processCommandLine() before calling getCommand().

If INCLUDE_PERL_PATH has a non-zero value, the path to the perl executable is placed in front of the script call.  This allows the user to know which of possibly multiple perl installations ran the script.

If NO_DEFAULTS has a non-zero value, the user saved defaults, previously saved using --save-args, will be omitted from the returned command.  Note, in string context, the returned command separates user defaults from manually supplied options with '--' and a comment and encapsulates the defaults in square brackets.  To run the command in the same way, the defaults must either be saved and the command omit the defaults or the defaults must be cleared and manually supplied.

Any options such as --run, --dry-run, --usage, and --help that were supplied via saved defaults (see --save-args) are not actually used in runs of the script, but they are stored with default options and affect the DEFRUNMODE (see setDefaults()).  One of these 4 options will change the default run mode.

INC_DEFMODE

getCommand() is not exported by default, thus you must either supply it in your `use CommandLineInterface qw(... getCommand);` statement or call it using the package name: `CommandLineInterface::getCommand();`.

I<EXAMPLE>

=over 4

I<Command>

    #Previous command to save default arguments:
    example.pl --verbose 3 --save-args
    #Command related to output below:
    example.pl -i '*.txt' file{1,2}.tab

I<Code>

    print("My command: ",CommandLineInterface::getCommand());

I<Output>

    My command: example.pl -i '*.txt' file1.tab file2.tab -- [USER DEFAULTS ADDED: --verbose 3]

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --save-args        Save current options for inclusion in every run.

I<LIMITATIONS>

getCommand() has no way to know what glob string was provided to the shell before shell expansion (unless the glob was wrapped in quotes).

getCommand() does not know about pipes, shell variables, or input and output redirects.

Multiple spaces between arguments are not preserved.

Currently, if the user has set any default parameters, the command output will not run the same via simple copy and paste if you include the commented default parameters.  Also, if defaults have changed, that will affect the way the pasted command behaves, so check your defaults (at the bottom of the usage output) before rerunning a command.  The ability to ignore defaults for a script run will be addressed when requirement 66 is implemented.

I<ADVANCED>

n/a

=item C<getFileGroupSizes> [FILETYPEID*]

This method returns the numbers of files supplied to each instance of the flag defined by addInfileOption that were provided by the user on the command line.  In scalar context, it returns a reference to an array of sizes.  In list context, it returns an array of sizes.

FILETYPEID is the ID returned by addInfileOption().  Supply it to specify the type of input files supplied by the flag defined by addInfileOption().

* FILETYPEID is optional when there is only 1 input file type, in which case, it defaults to the single input file type.  It is required otherwise.

I<EXAMPLE>

=over 4

I<Command>

    #>ls
    #1.txt 2.txt 3.txt a.text b.text c.text

    example.pl -i '*.txt' -i '*.text'

I<Code>

    my $fid = addInfileOption(FLAG => 'i');
    processCommandLine();
    print(join("\n",getFileGroupSizes()),"\n");

I<Output>

    3
    3

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all error, warning, verbose, & debug messages.

Default file options that are added if none defined (which also affect the behavior of this method):

    -i                  Input file. see addInfileOption()

I<LIMITATIONS>

This method can only be used to retrieve a number of input files per flag for a single input file type, not for output files.

This method does not skip any input files that may be associated with existing output files when --skip is provided.

I<ADVANCED>

n/a

=item C<getHeader>

Returns a multi-line string with leading comment characters containing various info about the run.  The purpose of such a header is to be able to know how a file was generated.

getHeader() is called by default in openOut (unless --no-header is supplied on the command line), so you should never need to call this method.

getHeader() is not exported by default, thus you must either supply it in your `use CommandLineInterface qw(... getHeader);` statement or call it using the package name: `CommandLineInterface::getHeader();`.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i in.txt

I<Code>

    print("The outfile header:\n",CommandLineInterface::getHeader());

I<Output>

    The outfile header:
    #your_version_number
    #User: your_username
    #Time: Thu Feb  9 15:43:36 2017
    #Host: your_hostname
    #PID: your_process_id
    #Directory: /where/you/ran/the/script
    #Command: /usr/bin/perl example.pl -i in.txt

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --header            Print commented header to outfiles.  See getHeader()

I<LIMITATIONS>

getHeader fills in some information using environment variables like USER, HOST, and PWD.  If those variables are not defined in the user's environment, those fields in the header will be empty.

There is no way to select specific output files to get headers and others to not get headers.

Reading of input files does not skip automatically generated headers by default.

See the LIMITATIONS section of processCommandLine() for information on headers output to STDOUT.

I<ADVANCED>

Note that CommandLineInterface knows if you are redirecting output via a pipe or out to a file, in which case the header is printed.  Every output file gets a header.  When output is going to a terminal session (i.e. a tty), header output is withheld.

To skip headers when reading in a file generated by a script using CommandLineInterface, you must skip the header during file processing, e.g. `next if(/^#/)`.

=item C<getInfile> [FILETYPEID* ITERATE]

Returns the file of type FILETYPEID (the ID returned by addInfileOption) that is among the current combination of files that are being processed together (see nextFileCombo()).

If ITERATE supplied and non-zero, multiple calls with the same FILETYPEID will advance the nextFileCombo() iterator.  The entire combination is advanced.

If ITERATE is not supplied, iteration is set to automatic and the behavior depends on whether the nextFileCombo() iterator has been called or not.  Calling nextFileCombo puts automatic iteration control under it's control.  Without calling nextFileCombo(), iteration is controlled by getInfile() and/or getOutfile().  A warning will be issued about possible skipped file combinations if getInfile() and the nextFileCombo() is called.  See the ADVANCED section below for notes on how this relates to files that have a ONETOMANY relationship with other files.

* FILETYPEID is optional when there is only 1 input file type, in which case, it defaults to the single input file type.  It is required otherwise.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '1.txt 2.txt'

I<Code>

    while(my $f = getInfile($fid,1))
      {print($f,"\n")}

I<Output>

    1.txt
    2.txt

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --skip              Skip file set w/ existing outfiles. See nextFileCombo()

Default file options that are added if none defined (which also affect the behavior of this method):

    -i                  Input file. see addInfileOption()

I<LIMITATIONS>

None.

I<ADVANCED>

If there is only one input file type, the FILETYPEID is optional.  Without ITERATE, or with ITERATE => 0, the same file will be returned each time and the file set iterator will not advance.

getInfile() must always be called inside a loop controlled by nextFileCombo() (if you use nextFileCombo() at all.  This is because every file type is included in the nextFileCombo() iterator, even those which have a ONETOMANY relationship.  What this means is that the same ONETOMANY file will be returned with every one of the other files.  The reasons for this are 1. to support the novel feature of a ONETOONEORMANY relationship and 2. to allow any number of sets of ONETOMANY pairs of file types to be processed.

What this means is that you cannot as of yet process the ONETOMANY 'one' file outside of the loop that returns that file repeatedly.  Requirement 132 will address this limitation.  Until then, the 'one' file in a ONETOMANY relationship must be tracked so that it is processed only once.  For example:

=over 4

    my($onedata);
    while(nextFileCombo())
      {
        my $manyfile = getInfile($id1);
        my $onefile  = getInfile($id2);

        unless(exists($seen->{$onefile}))
          {$onedata = processOneFile($onefile)}
        $seen->{$onefile}++;

        processManyFile($manyfile,$onedata);
      }

=back

=item C<getInHandleFileName> HANDLE

Returns the file name (and path as supplied) associated with the input file handle.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i ../in.txt

I<Code>

    openIn(*INPUT,getInfile());
    print("Input file: ",getInHandleFileName(*INPUT));

I<Output>

    Input file: ../in.txt

=back

I<ASSOCIATED FLAGS>

Default file options that are added if none defined (which affect the behavior of this method):

    -i                  Input file. see addInfileOption()

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<getLine> HANDLE VERBOSELEVEL VERBOSEFREQ

In SCALAR context, returns the next line of the file connected to HANDLE (see openIn()).

In LIST context, returns all lines (or all remaining lines).

The advantage of using getLine over <INP> is that it recognizes carriage returns (\r) and off combinations of them with newlines (\n).

VERBOSELEVEL determines how many verbose flags the user must supply before a verbose message about the current line number being read will be printed to STDERR.  Default value is 2.

VERBOSEFREQ is a number that indicates how many lines to read between verbose message printings.  E.g. The value '100' will print a verbose messages every 100th line read.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt'

I<Code>

    getLine(HANLDE => *INP);

    #or

    getLine(*INP);

I<Output>

    n/a

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all errors, warnings, & debugs.  See isQuiet()
    --verbose           Prints status.  See verbose() and verboseOverMe()
    --debug             Prints debug messages.  See debug()

Default file options that are added if none defined (which also affect the behavior of this method):

    -i                  Input file. see addInfileOption()

I<LIMITATIONS>

None.

I<ADVANCED>

This method handles files containing carriage returns, newlines, or both.  It does this by reading lines into a buffer and shifting lines off as they are requested.

=item C<getNextFileGroup> [FILETYPEID*]

getNextFileGroup is an iterator that retrieves an array of input files all provided by a single instance of a flag defined by addInfileOption.  In scalar context, it returns a reference to an array of file names.  In list context, it returns an array of file names.

FILETYPEID is the ID returned by addInfileOption().  Supply it to specify the type of input files supplied by the flag defined by addInfileOption().

* FILETYPEID is optional when there is only 1 input file type, in which case, it defaults to the single input file type.  It is required otherwise.

Note that it is highly recommended to use the nextFileCombo() iterator instead of the getNextFileGroup iterator, because it associates input files with their corresponding output files and when there are multiple types of input files, it associates them in order.  It's a much more robust iterator.

I<EXAMPLE>

=over 4

I<Command>

    #>ls
    #1.txt 2.txt 3.txt a.text b.text c.text

    example.pl -i '*.txt' -i '*.text'

I<Code>

    my $fid = addInfileOption(FLAG => 'i');
    processCommandLine();
    while(my $inf_group = getNextFileGroup())
      {print(join(' ',@$inf_group),"\n")}

I<Output>

    1.txt 2.txt 3.txt
    a.text b.text c.text

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all error, warning, verbose, & debug messages.

Default file options that are added if none defined (which also affect the behavior of this method):

    -i                  Input file. see addInfileOption()

I<LIMITATIONS>

This method can only be used to retrieve input files, not output files, thus it is highly recommended to use the nextFileCombo() iterator in combination with getInfile() and getOutfile() instead of this method.

There is currently no way as of yet to reset this iterator explicitly, though it automatically resets after having returned an undefined value indicating that no more file groups are present.  A reset method will be provided when requirement 173 is implemented.

This method does not skip any input files that may be associated with existing output files when --skip is provided.  --skip functionality is implemented in the openOut() method.

I<ADVANCED>

Note, when the iterator has nothing more to return, it returns an undefined value, however it automatically resets, so if it is called again after having returned an undefined value, it starts back over from the beginning.

=item C<getNumFileGroups> [FILETYPEID*]

This method returns the number of times a flag defined by addInfileOption was provided by the user on the command line.  If the input file type is PRIMARY and input is detected on standard in, the number returned accounts for it as if there was a flag supplied.

FILETYPEID is the ID returned by addInfileOption().  Supply it to specify the type of input files supplied by the flag defined by addInfileOption().

* FILETYPEID is optional when there is only 1 input file type, in which case, it defaults to the single input file type.  It is required otherwise.

I<EXAMPLE>

=over 4

I<Command>

    #>ls
    #1.txt 2.txt 3.txt a.text b.text c.text

    example.pl -i '*.txt' -i '*.text'

I<Code>

    my $fid = addInfileOption(FLAG => 'i');
    processCommandLine();
    print(getNumFileGroups(),"\n");

I<Output>

    2

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all error, warning, verbose, & debug messages.

Default file options that are added if none defined (which also affect the behavior of this method):

    -i                  Input file. see addInfileOption()

I<LIMITATIONS>

This method can only be used to retrieve a number of input file flags for a single input file type, not for output files.

This method does not skip any input file groups that may be associated with existing output files when --skip is provided.

I<ADVANCED>

n/a

=item C<getOutfile> SUFFIXID [ITERATE]

Returns a file name for the output file type specified by SUFFIXID (the ID returned by addOutfileSuffixOption()) that is in the current file set (see nextFileCombo()).

If ITERATE supplied and non-zero, multiple calls with the same SUFFIXID will advance the nextFileCombo() iterator.  The entire combination is advanced.

If ITERATE is not supplied, iteration is set to automatic and the behavior depends on whether the nextFileCombo() iterator has been called or not.  Calling nextFileCombo puts automatic iteration control under it's control.  Without calling nextFileCombo(), iteration is controlled by getInfile() and/or getOutfile().  A warning will be issued about possible skipped file combinations if getOutfile() and the nextFileCombo() is called.  See the ADVANCED section below for notes on how this relates to files that have a ONETOMANY relationship with other files.

I<EXAMPLE>

=over 4

I<Command>

     example.pl -i '1.txt 2.txt' -o .out

I<Code>

    while(my $f = getInfile($fid,1))
      {
        my $o = getOutfile($oid);
        print($o,"\n");
      }

I<Output>

    1.txt.out
    2.txt.out

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --skip              Skip file set w/ existing outfiles. See nextFileCombo()

Default file options that are added if none defined (which also affect the behavior of this method):

    -o                  Output file suffix. see addOutfileSuffixOption()
    --outfile           Output file. see addOutfileOption()
    --outdir            Output directory. see addOutdirOption()

I<LIMITATIONS>

The returned file name has the suffix appended to the full input file name it was connected to when addOutfileSuffixOption() was called.  It does not replace an existing extension (yet).  This will be addressed when requirement 171 is implemented.

While the file will have been checked for pre-existing files by the same name or even checked for predicted future output file name conflicts, the check is performed at the beginning of the script, so the file could have been already created by another process or by code that doesn't use openOut by the time the file is opened.  Thus an output file must be opened by openOut to guarantee overwrite protection.

I<ADVANCED>

addOutFileSuffixOption() and addOutfileOption() both return an ID that is accepted by getOutfile using its SUFFIXID parameter (even though it refers to it as a suffix and addOutfileOption ostensibly returns an output file ID).  This is actually because of code re-use.  addOutfileOption is really a wrapper for the creation of a hidden input file type (which is presented in the usage as an output file) and a call to addOutfileSuffixOption(), where the default value for the suffix is set to an empty string.  The input file types that are actually output files are tracked so that they are not processed as input files.

getOutfile() must always be called inside a loop controlled by nextFileCombo() (if you use nextFileCombo() at all.  This is because every file type is included in the nextFileCombo() iterator, even those which have a ONETOMANY relationship.  What this means is that the same ONETOMANY file will be returned with every one of the other files.  The reasons for this are 1. to support the novel feature of a ONETOONEORMANY relationship and 2. to allow any number of sets of ONETOMANY pairs of file types to be processed.

What this means is that you cannot as of yet process the ONETOMANY 'one' file outside of the loop that returns that file repeatedly.  Requirement 132 will address this limitation.  Until then, the 'one' file in a ONETOMANY relationship must be tracked so that it is processed only once.  For example:

=over 4

    while(nextFileCombo())
      {
        my $manyfile = getInfile($id1);
        my $onefile  = getOutfile($id2);

        unless(exists($seen->{$onefile}))
          {openOut(*OUT,$onefile)}
        $seen->{$onefile}++;

        processManyFile($manyfile,$onedata);
      }

=back

Note that if you set the COLLISIONMODE to 'merge' in the call to addOutfileOption() earlier during the command line interface definition section of code, then the output file check (as above) is unnecessary.  openOut() and closeOut() will allow output to concatenate in the file, but without --append specified by the user, it will not append to a file that existed before the script started.  For example:

=over 4

    while(nextFileCombo())
      {
        my $manyfile = getInfile($id1);
        my $onefile  = getOutfile($id2);

        openOut(*OUT,$onefile);

        processManyFile($manyfile,$onedata);

        closeOut(*OUT);
      }

=back

=item C<getOutHandleFileName> HANDLE

Returns the file name (and path as supplied) associated with the output file handle.

I<EXAMPLE>

=over 4

I<Command>

    example.pl --outfile out.txt

I<Code>

    openIn(*OUT,getOutfile());
    print("Output file: ",getInHandleFileName(*OUT));

I<Output>

    Output file: out.txt

=back

I<ASSOCIATED FLAGS>

Default file options that are added if none defined (which affect the behavior of this method):

    -o                  Output file suffix. see addOutfileSuffixOption()
    --outfile           Output file. see addOutfileOption()

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<getUserDefaults> [REMOVE_QUOTES]

In list context, returns an array of saved default arguments.  In scalar context, it returns a reference to said array.

By default, defaults are saved with quotes if the supplied values have white spaces.  The returned array elements will strip off their quotes if REMOVE_QUOTES has a non-zero value.

I<EXAMPLE>

=over 4

I<Command>

    example.pl --save-args --verbose --debug 2 -i 'test1.txt test2.txt'
    example.pl --run

I<Code>

    print("Saved args1: ",join(' ',getUserDefaults()),"\n");
    print("Saved args2: ",join(';',getUserDefaults(REMOVE_QUOTES => 1)),"\n");

I<Output>

    Saved args1: --save-args --verbose --debug 2 -i 'test1.txt test2.txt'
    Saved args2: --save-args;--verbose;--debug;2;-i;test1.txt test2.txt

=back

I<ASSOCIATED FLAGS>

Default file options that are added if none defined (which affect the behavior of this method):

    --save-args         Save current options for inclusion in every run.

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<getVersion> [COMMENT EXTENDED]

Returns the version number of the script (set by setScriptInfo()) in which CommandLineInterface is being used.  If the script author did not seet a version number, the string 'UNKNOWN' will be returned.

If --extended is supplied on the command line, multi-line output is generated including script name, creation date, last modified date, author, company, license, and similar information about the version of CommandLineInterface.

If COMMENT is supplied and non-zero, the returned string will be commented.

If EXTENDED is 1 or greater, the script name is included, e.g. "example.pl Version 1.0".  If EXTENDED is 2 or larger, a multi-line string is returned that includes information such as autheor, last modified date, etc..  If EXTENDED is 3 or larger, version information about CommandLineInterface is also included.  Supplying EXTENDED over-rides the user's setting of --extended on the command line (even if set to 0).  The number of times --extended is supplied (or if a single instance is given a value (e.g. --extended 2) and EXTENDED is not supplied, the value supplied by the user on the command line is used.

getVersion() is not exported by default, thus you must either supply it in your `use CommandLineInterface qw(... getVersion);` statement or call it using the package name: `CommandLineInterface::getVersion();`.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i in.txt

I<Code>

    setScriptInfo(VERSION => '1.2');
    print(getVersion());

I<Output>

    1.2

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --extended          Print extended usage/help/version/header.

I<LIMITATIONS>

None

I<ADVANCED>

n/a

=item C<headerRequested>

This method returns the value of the --header (or --no-header) flag.  The value will be 1 if --header was provided on the command line, 0 if --no-header was supplied once, or 1 if neither was supplied nor saved as a default (see --save-args).

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i in.txt --no-header

I<Code>

    print("Value of --header: ",headerRequested());

I<Output>

    Value of --header: 1

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --header            Print commented header to outfiles.  See getHeader()

I<LIMITATIONS>

headerRequested() calls processCommandLine() to get the value of the flag if the command line has not yet been processed, thus you cannot call headerRequested() before you have finished all calls to the add*Options methods.

I<ADVANCED>

n/a

=item C<help> [ADVANCED IGNORE_UNSUPPLIED]

The help() method prints information about the script that is set by setScriptInfo() and the input and output file formats (whose information is set by calls to addInfileOption(), addOutfileOption(), and addOutfileSuffixOption().

ADVANCED mode (supplied & non-zero) prints detailed information about overwrite protection and advanced file IO features.  CommandLineInterface calls the help() method automatically when --help is supplied and ADVANCED is set to non-zero if --extended is also supplied.

If IGNORE_UNSUPPLIED is supplied & non-zero and the author of the script has not provided information on input and output file formats, or a description of what the script does, those sections of the help output will be skipped.  Otherwise, a message that the author has not yet supplied the information is printed.

help() is not exported by default, thus you must either supply it in your `use CommandLineInterface qw(... help);` statement or call it using the package name: `CommandLineInterface::help();`.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt'

I<Code>

    setScriptInfo(VERSION => "1.0a",
                  CREATED => "11/28/2016",
                  HELP    => "This script does x and y.");
    processCommandLine();
    CommandLineInterface::help();

I<Output>


    example.pl version 1.0a
    Created: 11/28/2016
    Last Modified: Fri Feb 10 09:55:47 2017

    * WHAT IS THIS: This script does x and y.
    * INPUT FORMAT:   The author of this script has not provided a format
      -i,--infile,    description for this input file type.  Please add a
      --stub          description using the addInfileOption method.
    * OUTPUT FORMAT:  The author of this script has not provided a format
      -o,             description for this input file type.  Please add a
      --suffix        description using one of the addOutfileOption or
                      addOutfileSuffixOption methods.



=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --help              Print help message and quit.  See help()
    --extended          Print extended usage/help/version/header.

Default file options that are added if none defined (which also affect the behavior of this method):

    -i                  Input file. see addInfileOption()
    -o                  Output file suffix. see addOutfileSuffixOption()
    --outfile           Output file. see addOutfileOption()

I<LIMITATIONS>

It is not possible to set the input & output format help messages of the default -i and -o/--outfile options.  In order to provide these messages, you must create the options using addInfileOption(), addOutfileOption(), and addOutfileSuffixOption().  When these options are provided, they replace the default options.

I<ADVANCED>

n/a

=item C<inPipeline>

This method guesses whether the script is running from within another script or whether it is being piped to or from another command (i.e. not a file).  It is used internally to know whether its STDERR messages might be mixed with those from other commands.  It uses this awareness to prepence warnings, errors, and debug messages with the script name so that the user knows the source of any message.

It returns 1 if it thinks it is not being run as part of a pipeline.  It returns 0 if it thinks it is being run manually & by itself.

Pipeline mode modifications to messages can be explicitly set by the user by supplying --pipeline or --no-pipeline.

inPipeline() is not exported by default, thus you must either supply it in your `use CommandLineInterface qw(... inPipeline);` statement or call it using the package name: `CommandLineInterface::inPipeline();`.

I<EXAMPLE 1>

=over 4

I<Command>

    example.pl -i in.txt

I<Code>

    print("In pipeline?: ",CommandLineInterface::inPipeline());

I<Output>

    In pipeline?: 0

=back

I<EXAMPLE 2>

=over 4

I<Command>

    cat in.txt | example.pl

I<Code>

    print("In pipeline?: ",CommandLineInterface::inPipeline());

I<Output>

    In pipeline?: 1

=back

I<ASSOCIATED FLAGS>

The following default option does not affect the behavior of this method, but rather affects whether the method is called automatically:

    --pipeline          Prepends script name to errors, warnings, & debugs.

I<LIMITATIONS>

This method is experimental and should not be relied upon for serious logic decisions.  For example, processes running in the background may result in pipeline mode being enabled.  It is only used in CommandLineInterface to prepend the script name to various STDERR messages and may not behave as expected on some systems.

I<ADVANCED>

This method is used to set a class variable which a user can set explicitly by supplying either --pipeline or --no-pipeline.  If the user does not supply either of those flags, inPipeline is called only once to set the class variable.  It is called the first time a debug, warning, or error message is printed.  It uses pgrep and lsof and parses the output to determine whether there exist any sibling processes with the same parent process or if the parent process is reading a script input file.

=item C<isDebug>

This method returns the value of the --debug flag.  The value will be 0 if --debug was not provided on the command line, 1 if --debug was supplied once, 2 if supplied twice, etc..  The --debug flag can also take a value (e.g. --debug 3) in which case, that is the value that is returned.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i in.txt --debug

I<Code>

    print("Value of --debug: ",isDebug());

I<Output>

    Value of --debug: 1

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --debug             Prints debug messages.  See debug()

I<LIMITATIONS>

isDebug() calls processCommandLine() to get the value of the flag if the command line has not yet been processed, thus you cannot call isDebug() before you have finished all calls to the add*Options methods.

I<ADVANCED>

n/a

=item C<isDryRun>

This method returns the value of the --dry-run flag.  The value will be 0 if --dry-run was not provided on the command line or 1 if it was supplied.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i in.txt --dry-run

I<Code>

    print("Value of --dry-run: ",isDryRun());

I<Output>

    Value of --dry-run: 1

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --dry-run           Skip all directory and outfile creation steps.

I<LIMITATIONS>

isDryRun() calls processCommandLine() to get the value of the flag if the command line has not yet been processed, thus you cannot call isDryRun() before you have finished all calls to the add*Options methods.

I<ADVANCED>

n/a

=item C<isForced>

This method returns the value of the --force flag.  The value will be 0 if --force was not provided on the command line, 1 if --force was supplied once, 2 if supplied twice, etc..  The --force flag can also take a value (e.g. --force 3) in which case, that is the value that is returned.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i in.txt --force

I<Code>

    print("Value of --force: ",isForced());

I<Output>

    Value of --force: 1

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --force             Prevent quit upon critical errors.

I<LIMITATIONS>

isForced() calls processCommandLine() to get the value of the flag if the command line has not yet been processed, thus you cannot call isForced() before you have finished all calls to the add*Options methods.

I<ADVANCED>

n/a

=item C<isOverwrite>

This method returns the value of the --overwrite flag.  The value will be 0 if --overwrite was not provided on the command line, 1 if --overwrite was supplied once, 2 if supplied twice, etc..  The --overwrite flag can also take a value (e.g. --overwrite 3) in which case, that is the value that is returned.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i in.txt --overwrite

I<Code>

    print("Value of --overwrite: ",isOverwrite());

I<Output>

    Value of --overwrite: 1

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --overwrite           Overwrites existing output files.

I<LIMITATIONS>

isOverwrite() calls processCommandLine() to get the value of the flag if the command line has not yet been processed, thus you cannot call isOverwrite() before you have finished all calls to the add*Options methods.

I<ADVANCED>

n/a

=item C<isQuiet>

This method returns the value of the --quiet flag.  The value will be 0 if --quiet was not provided on the command line, 1 if --quiet was supplied.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i in.txt --quiet

I<Code>

    print("Value of --quiet: ",isQuiet());

I<Output>

    Value of --quiet: 1

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet               Suppress all errors, warnings, & debugs.

I<LIMITATIONS>

isOverwrite() calls processCommandLine() to get the value of the flag if the command line has not yet been processed, thus you cannot call isOverwrite() before you have finished all calls to the add*Options methods.

I<ADVANCED>

n/a

=item C<isSkip>

This method returns the value of the --skip flag.  The value will be 0 if --skip was not provided on the command line, 1 if --skip was supplied.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i in.txt --skip

I<Code>

    print("Value of --skip: ",isSkip());

I<Output>

    Value of --skip: 1

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --skip               Skip file set w/ existing outfiles. See nextFileCombo()

I<LIMITATIONS>

isOverwrite() calls processCommandLine() to get the value of the flag if the command line has not yet been processed, thus you cannot call isOverwrite() before you have finished all calls to the add*Options methods.

I<ADVANCED>

n/a

=item C<isStandardOutputToTerminal>

This method returns true (/non-zero) if output has not been piped or redirected out from the script.  If output has been redirected to a file or piped into another command, it returns false (/0).

isStandardOutputToTerminal() is not exported by default, thus you must either supply it in your `use CommandLineInterface qw(... isStandardOutputToTerminal);` statement or call it using the package name: `CommandLineInterface::isStandardOutputToTerminal();`.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i in.txt > out.txt

I<Code>

    print("Output going to TTY?: ",
          CommandLineInterface::isStandardOutputToTerminal());

I<Output>

    Output going to TTY?: 0

=back

I<ASSOCIATED FLAGS>

n/a

I<LIMITATIONS>

None

I<ADVANCED>

n/a

=item C<isThereInputOnSTDIN>

This method returns true (/non-zero) if input has been piped or redirected into the script.  If input is not present on STDIN, it returns false (/0).

isThereInputOnSTDIN() is not exported by default, thus you must either supply it in your `use CommandLineInterface qw(:DEFAULT isThereInputOnSTDIN);` statement or call it using the package name: `CommandLineInterface::isThereInputOnSTDIN();`.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i in.txt

I<Code>

    print("Input coming in on standard in?: ",
          CommandLineInterface::isThereInputOnSTDIN());

I<Output>

    Input coming in on standard in?: 0

=back

I<ASSOCIATED FLAGS>

n/a

I<LIMITATIONS>

None.

I<ADVANCED>

n/a

=item C<isVerbose>

This method returns the value of the --verbose flag.  The value will be 0 if --verbose was not provided on the command line, 1 if --verbose was supplied once, 2 if supplied twice, etc..  The --verbose flag can also take a value (e.g. --verbose 3) in which case, that is the value that is returned.  This method is useful if for example, you are making a system call and need to know whether to provide a verbose or quiet flag.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i in.txt --verbose

I<Code>

    print("Value of --verbose: ",isVerbose());

I<Output>

    Value of --verbose: 1

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --verbose           Prints verbose messages.  See verbose()

I<LIMITATIONS>

isVerbose() calls processCommandLine() to get the value of the flag if the command line has not yet been processed, thus you cannot call isVerbose() before you have finished all calls to the add*Options methods.

I<ADVANCED>

n/a

=item C<makeMutuallyExclusive> OPTIONIDS [REQUIRED OVERRIDABLE NAME]

This method enforces mutual exclusivity of options provided by the user on the command line.  It takes a reference to an array of option IDs (as are returned by any of the add*Option() methods, e.g. addOption() or addInfileOption()).  More than 1 option ID is required.  If the user supplies flags on the command line for more than one of the options indicated, the script will automatically exit with an error message indicating that the flags cannot be supplied together.

REQUIRED indicates that one of the options must be supplied.  It will be set automatically if any option supplied among the OPTIONIDS is marked as REQUIRED (as was supplied to the add*Option method that created it).  Such options will automatically be treated as optional, if supplied to makeMutuallyExclusive.

OVERRIDABLE defaults to false/0 and refers to whether DEFAULT values for included options can be over-ridden (or unset/turned-off) by one another in the following ways:

    User default of any option over-rides programmer default (see --save-args)
    Any option supplied on the command line over-rides both user & programmer defaults

For example.  Let's say --verbose and --quiet were made mutually exclusive and the programmer set a default for --verbose to 2, yet the user supplies --quiet.  If the set of mutually exclusive options were supplied with OVERRIDABLE as true/non-zero, --verbose is set to 0 automatically and the script proceeds.  If OVERRIDABLE was false, the user would get an error, notifying them that --verbose must be explicitly turned off by supplying `--verbose 0` in order to supply --quiet.

OVERRIDABLE is useful when options are incompatible, but allowing them to silently change one another can lead to inexplicable side effects.  Only set OVERRIDABLE to true/non-zero when the options included are obviously linked.

Similarly, if the user tries to save --quiet as a default, by supplying it with --save-args, they will get the same error & suggestion.

NAME is the name of the mutually exclusive set of options used in errors.  It defaults to "custom #", where "#" is a number indicating the set number in the order in which they were created (starting from 1).

I<EXAMPLE>

=over 4

I<Command>

    example.pl -x 1 -y 2

I<Code>

    my($x,$y);
    my $xid = addOption(FLAG => 'x',VARREF => \$x);
    my $yid = addOption(FLAG => 'y',VARREF => \$y);
    makeMutuallyExclusive(OPTIONIDS => [$xid,$yid]);

I<Output>

    ERROR1: The following options (as supplied on the command line) are mutually exclusive: [x,y].  Please provide only one.

=back

I<ASSOCIATED FLAGS>

n/a

I<LIMITATIONS>

The only option types that can currently be explicitly over-ridden (when OVERRIDABLE is false/0) are: negbool and count.  User defaults in those cases can be eliminated by changing the user defaults with --save-args, but programmer defaults cannot be explicitly over-ridden unless the code is changed.  Until a means to unset other option types is designed, the only work-arounds are to either not set DEFAULT values for option types other than negbool and count, or to set OVERRIDABLE to true/1 when the mutually exclusive set is created (this works because the values of over-ridden options are simply left undefined).

I<ADVANCED>

n/a

=item C<markTime> [MARKINDEX]

If not provided a MARKINDEX, this method marks the time, adding it to an array.  In scalar context, it returns the time (in seconds) since the last mark.  If a MARKINDEX is supplied, (starting from 0) no mark is added to the marks array and it returns the time since the supplied mark.

The first mark is always the start time of the script.

markTime() is not exported by default, thus you must either supply it in your `use CommandLineInterface qw(... markTime);` statement or call it using the package name: `CommandLineInterface::markTime();`.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i in.txt

I<Code>

    sleep(2);
    print("Elapsed time (s): ",CommandLineInterface::markTime());

I<Output>

    Elapsed time (s): 2

=back

I<ASSOCIATED FLAGS>

n/a

I<LIMITATIONS>

Only whole seconds are reported.

There is currently no way to obtain the MARKINDEX that was created when markTime() is called.  One must keep a cound if specific marks are desired.  Note, you can also use negative indexes.

I<ADVANCED>

n/a

=item C<nextFileCombo>

CommandLineInterface processes files in pairs, or more generally, in sets of files of different types which we will refer to here as a file set.  The nextFileCombo() iterator advances through a 2 dimensional array of files that as a set are processed together.  There is one file of each type (both input and output) in a set/combination.  If multiple files are supplied to a flag "-i" and multiple files are supplied to flag "-j" (as long as they each are supplied with the same number of files), the first file of each group of files supplied to each flag, put together, is the first file set.  nextFileCombo() is an iterator that advances through all of those "pairs", so it is usually called within a while loop.

Returns true until there are no more input file sets to advance to.

File names can be retrieved using getInfile() and getOutfile() by simply supplying the file type as the only argument.  Hint: if you're unsure of the order the files will come out in, you can use --verbose --dry-run with your file options to see the order in which the files are returned.

getInfile() and getOutfile(), if nextFileCombo() has not been called, will call it implicitly each time one of them is prompted to return the same member of a combination twice.  If nextFileCombo() has been called before either of these methods has, getInfile() and getOutfile() will not auto-iterate.  See getInfile() and getOutfile() for more information.

Input files can be added with relationships to other input files, such as is described above (1:1 or "one-to-one") or in one of any of these relationships: 1:M (one-to-many) or 1:1orM (one-to-one-or-many).  The 1:M relationship affects the file sets in the following manner, best seen by example:

I<EXAMPLE 1> One-to-many

=over 4

I<Command>

    example.pl -i '1.txt 2.txt' -j a.txt

I<Code>

    while(nextFileCombo())
      {print(getInfile($fid1)," ",getInfile($fid2),"\n")}

I<Output>

    1.txt a.txt
    2.txt a.txt

=back

For tips on how to avoid processing the same file multiple times, refer to the DISCUSSION section below, under 1:1orM, or take a look at the ADVANCED section of each of the getInfile() and getOutfile() methods.

I<EXAMPLE 2> One-to-one

=over 4

I<Command>

    example.pl -i '1.txt 2.txt' -j 'a.txt b.txt'

I<Code>

    while(nextFileCombo())
      {print(getInfile($fid1)," ",getInfile($fid2),"\n")}

I<Output>

    1.txt a.txt
    2.txt b.txt

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --skip              Skips file sets if 1 or more output files exists.

Default file options that are added if none defined (which also affect the behavior of this method):

    -i                  Input file. see addInfileOption()
    -o                  Output file suffix. see addOutfileSuffixOption()
    --outfile           Output file. see addOutfileOption()
    --outdir            Output directory. see addOutdirOption()

These and any other options added using the indicated add*Option methods define the files that nextFileCombo() uses for iterating.  Note, --outdir only changes the strings returned when retrieving the output files.

I<LIMITATIONS>

M:M "many-to-many" is not currently fully supported.  Refer to the DISCUSSION section, under the heading M:M for more information.  This will be addressed when requirement 140 is implemented.

There is currently no means of sub-iterating based on file relationships (e.g. files that have a ONETOMANY relationship with other files.  This will be addressed once requirement 132 has been implemented.  Requirement 264 will also address this limitation.

I<ADVANCED>

Calling nextFileCombo() triggers the processing of the command line options (if they have not been processed already).

The iterator will start over the next time it is called after having returned undef.

=item C<openIn> HANDLE FILE [QUIET]

Opens FILE for input to be read on HANDLE unless --dry-run was supplied.

Returns non-zero if successful (or if --force was supplied).  0 otherwise.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt'

I<Code>

    my $myfile = getInfile();

    openIn(HANLDE => *INP,
           FILE   => $myfile,
           QUIET  => 1);

    #or

    openIn(*INP,$myfile,1);

I<Output>

    n/a

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all errors, warnings, & debugs.  See isQuiet()
    --error-limit       Suppress some errors & warnings.  See error()/warning()
    --verbose           Prints open message.  See verbose()
    --debug             Prints debug messages.  See debug()

Default file options that are added if none defined (which also affect the behavior of this method):

    -i                  Input file. see addInfileOption()

I<LIMITATIONS>

Only designed to handle files and STDIN.  Piping and/or system call behavior not supported.

I<ADVANCED>

Tracks open file handles.  Generates verbose messages if --verbose is supplied on the command line and QUIET is not supplied (or 0).  Supplying QUIET => 1 will also cause closeIn to be quiet as well.

If --dry-run was supplied, the file is opened, but immediately closed (in order to catch potential errors with a real run).

Opens STDIN if FILE is '-'.

=item C<openOut> HANDLE [FILE SELECT QUIET HEADER APPEND MERGE]

Opens FILE for writing through HANDLE unless --dry-run was supplied.  Opens STDOUT if FILE is not supplied.

Returns non-zero if successful (or if --force was supplied).  0 otherwise.

If SELECT is non-zero, the handle is selected.  Generates verbose messages if --verbose is supplied on the command line and QUIET is not supplied (or 0).

If --header is supplied (or --noheader is not supplied, depending on the default), the first time a file is opened for writing, a header will be printed to the output file.  See getHeader().

If APPEND is non-zero, a file will be opened in append mode.  0 = open for writing from the beginning of the file.  0 is subject to over-write protection.  APPEND differs from MERGE in that it only applies to the first time it is opened.  The number of times a file is opened is tracked in order to support output files that have a ONETOONEORMANY relationship with input files.  Different input files which generate output to the same file is what MERGE is for, which is distinct from APPENDing to pre-existing files before the script was run.

If MERGE has a non-zero value, subsequent times a file is opened (after the first open), it is opened in append mode.  Note that an error will be generated in if the file being written to already exists the first time it is opened unless APPEND is non-zero.

I<EXAMPLE 1>

I<Command>

    example.pl -i '*.txt' -o .out

I<Code>

=over 4

    while(nextFileCombo())
      {
        my $infile = getInfile();
        my $myfile = getOutfile();

        openOut(HANLDE => *OUTP,
                FILE   => $myfile,
                SELECT => 1,
                QUIET  => 1,
                HEADER => 1,
                APPEND => 0,
                MERGE  => 0);

        ...

        closeOut(*OUTP);
      }

I<Output>

    *.txt.out

=back

I<EXAMPLE 2>

I<Command>

    example.pl -i '*.txt' --outfile merged_output.out

I<Code>

=over 4

    while(nextFileCombo())
      {
        my $infile = getInfile();
        my $myfile = getOutfile();

        openOut(*OUTP,$myfile,1,1,1,0,1);

        ...

        closeOut(*OUTP);
      }


I<Output>

    merged_output.out

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all errors, warnings, & debugs.  See isQuiet()
    --verbose           Print close message.  See verbose() and verboseOverMe()
    --debug             Prints debug messages.  See debug()
    --overwrite         Overwrites existing output files.
    --skip              Skip file set w/ existing outfiles. See nextFileCombo()
    --append            Append to existing outfiles.
    --dry-run           Skip all directory and outfile creation steps.
    --force             Prevent quit upon critical errors.
    --header            Print commented header to outfiles.  See getHeader()

Default file options that are added if none defined (which also affect the behavior of this method):

    -o                  Output file suffix. see addOutfileSuffixOption()
    --outfile           Output file. see addOutfileOption()
    --outdir            Output directory. see addOutdirOption()

I<LIMITATIONS>

Only designed to handle files and STDOUT.  Piping and/or system call behavior not supported.

I<ADVANCED>

Tracks open file handles.  Generates verbose messages if --verbose is supplied on the command line and --quiet is not supplied.  Supplying QUIET => 1 will also cause closeOut to be quiet as well.

If --dry-run was supplied, the file is not opened, but a successful open status is returned.

Overwrite protection is implemented in this method.  If --overwrite is not supplied, this method will not open a pre-existing file and will return a status of 0 with an error.

Opens STDOUT if FILE is '-'.  See the PRIMARY parameter to the addOutfileOption() and addOutfileSuffixOption() methods for information on how '-' can be automatically set when no method of generating output files is supplied on the command line by the user.

Quits with a critical error if FILE is undefined.

=item C<printRunReport> [ERRNO]

This method will print a run report if it is deemed that a run report is desireable.  A run report is deemed desireable if --quiet was not supplied and either --verbose was supplied, --debug was supplied, there was at least 1 warning or error, or ERRNO is non-zero.

printRunReport is automatically called when the script exits if (when in a run mode) there were any errors or warnings.  When the script is in a non-run mode, the report will only print if the number of errors exceeds the error limit (see --error-limit).  Thus you only need to call it yourself if you want a run report in any other case.

ERRNO is assumed to be the exit code that will be used upon exit of the script.

If an error or warning occurred during execution, a summary of each error/warning type that occurred is also printed, containing the number of errors of the specified type and an example snippet of one of the errors.

Output goes to standard error and is never buffered.  An empty line preceeds the run report.

This method is called automatically in the quit() method (which is called in the END block.

printRunReport() is not exported by default, thus you must either supply it in your `use CommandLineInterface qw(... printRunReport);` statement or call it using the package name: `CommandLineInterface::printRunReport();`.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i in.txt

I<Code>

    error("Something bad happened");
    CommandLineInterface::printRunReport(4);

I<Output>

    ERROR1: Something bad happened

    Done.  STATUS: [EXIT-CODE: 4 ERRORS: 1 WARNINGS: 0 TIME: 0s] SUMMARY:
    	1 ERROR LIKE: [ERROR1: Something bad happened]
    	Scroll up to inspect full errors/warnings in-place.

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all error, warning, verbose, & debug messages.
    --verbose           Prints status.  See verbose() and verboseOverMe()
    --debug             Prints debug messages.  See debug()

I<LIMITATIONS>

Exit code must be supplied.  There's no way to not print the message about the exit code.

Output is not buffered (in case the class variables are not defined for --verbose, --debug, etc.).

If --error-limit is set to 0, the format and content of the output will be sub-optimal.  Use --quiet instead.

I<ADVANCED>

Error types are tracked by the line on which error() or warning() is called.

The example of errors/warnings given in the summary is the first occurrence of that type of error.

Long errors and warnings in the summary are truncated.

=item C<processCommandLine>

processCommandLine() triggers the arguments on the command line to be processed.  All options are handled automatically.  For example, if --help was supplied, the help message is printed and the script exits.

CommandLineInterface was designed primarily for file processing scripts, thus if no input files or options are provided, a usage is printed and the script exits.

If your script does processing of input files, it is not necessary to call this method.  It will be called implicitly the first time you access an input file.  If your script does not actually process any input files, you must call this method to trigger the processing of the command line.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -j "Hello World"

I<Code>

    my $string = '';
    addOption(FLAG   => 'j',
              VARREF => \$string,
              TYPE   => 'string');
    processCommandLine();
    print($string);

I<Output>

    Hello World

=back

I<ASSOCIATED FLAGS>

processCommandLine uses/sets every default option provided by CommandLineInterface.  If --verbose is supplied, all option settings are reported on STDERR.

The following default options affect the behavior of this method:

    --quiet             Suppress all error, warning, verbose, & debug messages.
    --error-limit       Suppress some errors & warnings.  See error()/warning()
    --verbose           Prints status.  See verbose() and verboseOverMe()
    --pipeline          Prepends script name to errors, warnings, & debugs.
    --debug             Prints debug messages.  See debug()
    --overwrite         Overwrites existing output files.
    --skip              Skip file set w/ existing outfiles. See nextFileCombo()
    --append            Append to existing outfiles.
    --dry-run           Skip all directory and outfile creation steps.
    --force             Prevent quit upon critical errors.
    --help              Print help message and quit.  See help()
    --extended          Print extended usage/help/version/header.
    --version           Print version message and quit.  See getVersion()
    --header            Print commented header to outfiles.  See getHeader()
    --save-args         Save current options for inclusion in every run.

Default file options that are added if none defined (which also affect the behavior of this method):

    -i                  Input file. see addInfileOption()
    -o                  Output file suffix. see addOutfileSuffixOption()
    --outfile           Output file. see addOutfileOption()
    --outdir            Output directory. see addOutdirOption()

I<LIMITATIONS>

There is currently no way to use CommandLineInterface in a script in a mode where it operates when nothing is supplied on the command line because when processCommandLine() is called, it will automatically print a usage and exit.  This will be addressed when requirement 157 is implemented.

Likewise, there is no way to remove the default input or output file/directory options without adding your own version of those options.  This will be addressed when requirement 174 is implemented.

If the --header (or --noheader) flag is not provided on the command line, processCommandLine() tries to predict if script output is being redirected into a file and if so, it prints the header to STDOUT, but it is only a guess and sometimes gets it wrong.  The logic used is whether the output is going to a TTY or not and whether a suffix has been provided.

I<ADVANCED>

processCommandLine triggers most of the default functionality, such as overwrite protection.  All anticipated output files are checked up-front for possible overwrite and collision situations.

=item C<quit> [ERRNO REPORT]

The quit() method, aside from exiting the script with the given ERRNO exit code (default: 0), does 3 things:

    1. Flushes the standard error buffer (if called before the command line parameters have been processed).
    2. Prints a run report summarizing errors, warnings, etc..
    3. Skips the exit if --force was supplied and ERRNO is non-zero

The run report will print (at a minimum) a summary of the exit status if the conditions upon quitting include a non-zero (or undefined) exit code, any errors or warnings were printed, --verbose was supplied, or if any debug statements were printed.

REPORT can be supplied as 0 or non-zero (e.g. 1) to explicitly control whether a run report will be printed.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt'

I<Code>

    quit(1);

I<Output>


    Done.  STATUS: [EXIT-CODE: 1 ERRORS: 0 WARNINGS: 0 TIME: 0s]

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all error, warning, verbose, & debug messages.
    --verbose           Prints status.  See verbose() and verboseOverMe()
    --debug             Prints debug messages.  See debug()
    --force             Prevent quit upon critical errors.

I<LIMITATIONS>

None.

I<ADVANCED>

quit(0) is called inside the END block in order to clean up the STDERR buffer, any remaining unclosed file handles, print the run report (if necessary), etc.

=item C<resetFileGroupIterator> [FILETYPEID*]

getNextFileGroup() is an iterator that cycles through groups of files provided by a number of instances of the same input file flag (e.g. -i).  Each flag can take a group of input files, which is what getNextFileGroup() returns.  Each call to getNextFileGroup() returns the next group in the order they occur on the command line.  resetFileGroupIterator() allows you to reset that iterator so that the next call to getNextFileGroup() will return the first group of files.

Note that the iterator resets on its own after having returned undef after the last groupd was returned.

FILETYPEID indicates the input file type (it's what's returned by addInfileOption()).

Note that it is highly recommended to use the nextFileCombo() iterator instead of the getNextFileGroup iterator, because it associates input files with their corresponding output files and when there are multiple types of input files, it associates them in order.  It's a much more robust iterator.

* FILETYPEID is optional when there is only 1 input file type, in which case, it defaults to the single input file type.  It is required otherwise.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '{1,2}.txt' -i '{a,b}.txt' -i 'alpha.txt'

I<Code>

    @files1 = getNextFileGroup();
    @files2 = getNextFileGroup();
    resetFileGroupIterator();
    @files3 = getNextFileGroup();
    print(@files1,"\n",@files2,"\n",@files3);

I<Output>

    1.txt 2.txt
    a.txt b.txt
    1.txt 2.txt

=back

I<ASSOCIATED FLAGS>

Default file options that are added if none defined (which affect the behavior of this method):

    -i                  Input file. see addInfileOption()

I<LIMITATIONS>

This iterator does not associate input files with corresponding output files, such as those defined by addOutfileOption() and addOutfileSuffixOption(), thus getOutfile() will not return files in an order associated with the files returned by the file group iterators.  Output files must be handled manually if you use this iterator.

I<ADVANCED>

n/a

=item C<setDefaults> [HEADER ERRLIMIT COLLISIONMODE DEFRUNMODE DEFSDIR UNPROCFILEWARN REPORT VERBOSE QUIET DEBUG]

Use this method to set default values for some command line flags that CommandLineInterface provides (or doesn't provide).

HEADER sets --header.  Can be 0 or 1.  See headerRequested().  Default is 0.

ERRLIMIT sets --error-limit.  Unsigned integer.  See error() and warning().  Default is 5.  0 is unlimited.

COLLISIONMODE is an advanced feature that determines what the script does when outfile names conflict/collide.  Possible values are:

    error  = an error will be generated
    merge  = output is merged/concatenated together in processing order
    rename = composite output filenames are constructed by combining input file names (joined with a '.')

COLLISIONMODE sets the default behavior for all output file types that do not specify a COLLISIONMODE explicitly.  This differs from supplying --collision-mode on the command line (see `--usage --extended --extended`), which over-rides the modes set by all of the addOutfile*Option methods.

The default value for each output file type depends on how the outfile option was defined.  Output file types defined by the addOutfileOption method, default to a collision mode of 'merge' and output file types defined by addOutfileSuffixOption default to a collision mode of 'error'.  Setting this value changes the default for both types.  This will change when requirement 114 is implemented.

For functionality related to COLLISIONMODE for files not controlled by the user on the command line, see the APPEND parameter to the openOut method.  Setting COLLISIONMODE to 'merge' is the same as setting openOut's APPEND parameter explicitly to -1.  In fact, explicitly setting openOut's APPEND parameter to anything else over-rides all COLLISIONMODE settings, regardless of how they are specified.

DEFRUNMODE (i.e. 'Default Run Mode') in short, determines how the script behaves either when no arguments are supplied on the command-line and all the conditions required to run are met.

For example, running a script without any arguments provided on the command line can have a couple desireable outcomes (and what is desireable depends on the script):

    1. Generate a usage message
    2. Generate a help message
    3. Run the script (e.g. if required options have values*)
    4. Run the script in dry-run mode (e.g. if required options have values*)

* A required option can have either a hard-coded default value (see the various add*Option methods) or a user-saved default value (see --save-args).  The above behaviors apply only when no options are supplied on the command line.

Possible values of DEFRUNMODE and the resultant script behavior when no arguments are supplied are:

    usage   = Prints usage & exits [DEFAULT]
    run     = Runs script
    dry-run = Runs script without writing to output files
    help    = Prints help & exits

Each mode adds flags for the other modes to the command line interface (e.g. --run, --dry-run, --usage, or --help).  Note that if required options without defaults exist, --run is omitted as an option because the default behavior of all modes is to run when all required options have values and an argument is explicitly supplied on the command line.  --extended and --debug options are the exception - they will not trigger a script to run by themselves unless DEFRUNMODE is 'run'.

A main goal of DEFRUNMODE is to not get in the way.  In any mode, if there are required options, and they all have values defined by any means, execution will not be halted by a usage or help message.

See notes in ADVANCED about how required options with default values or how required options set via --save-args can affect script running.

DEFSDIR is the user defaults directory (used by all scripts that use CommandLineInterface).  If the user saves some parameters as defaults (e.g. `--verbose --save-args`), a file containing the defaults for the specific script is saved in this directory.

Set UNPROCFILEWARN to 0 to turn off warnings about unprocessed input/output file sets when your script exits (successfully).  A file set is a group of input files that are processed together (see PAIR_WITH parameter of addInfileOption and addOutfileOption).  A file set is considered processed when the set is iterated (either explicitly by calling nextFileCombo() or implicitly by calling getInfile(), getOutfile(), or getOutdir() (on the same file type ID)).  Warnings about unprocessed file sets can usually be avoided by either looping, like `while(nextFileCombo())` or by calling quit(ERRNO => 1).  The only time you should need to set UNPROCFILEWARN to 0 is when a valid/successful outcome of a script involves not retrieving all files supplied on the command line.

REPORT controls whether a run report will be printed to standard error at the end of a script run.  It can be 0 (for never), 1 (for auto), 2 (for always when in run or dry-run mode).  1 (auto) is the default and determines whether a run report should be printed, in which case, it prints when verbose is non-zero, warnings or errors occurred, or when debug mode is non-zero.

VERBOSE sets the default verbose mode (unless the user explicitly sets it).  Note that if verbose mode is set to non-zero, --quiet cannot be supplied unless `--verbose 0` is explicitly supplied by the user.

QUIET sets the default quiet mode.  Note that if quiet mode is set to 1, --verbose cannot be supplied by the user or they will get an error about being in both verbose and quiet modes at the same time.  It is thus best to not use this unless you know what you're doing.

DEBUG sets the default debug mode (unless the user explicitly sets it).  Note that if debug mode is set to non-zero, --quiet cannot be supplied unless `--debug 0` is explicitly supplied by the user.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt'

I<Code>

    setDefaults(HEADER => 0);
    print("Header?: ",headerRequested());

I<Output>

    Header?: 0

=back

I<ASSOCIATED FLAGS>

The following default options are affected by the behavior of this method:

    --error-limit       Suppress some errors & warnings.  See error()/warning()
    --header            Print commented header to outfiles.  See getHeader()
    --save-args         Save current options for inclusion in every run.

Setting the DEFRUNMODE in this method also affects the visibility and values of these flags:

    --run
    --dry-run
    --usage
    --help

I<LIMITATIONS>

The ERRLIMIT set here is over-ridden by the user supplying --error-limit, but only for errors occurring after the command line has been processed.  Repeated errors or warnings which occur after setDefaults() and before processCommandLine is called will be suppressed based on the value supplied to this method.  repeated errors or warnings occurring outside of that window will be subject to the hard-coded default or the user's --error-limit value.  This is because until the command line is processed, all STDERR output is buffered, but only if the limit is undefined.  This will be fixed when requirement 257 is implemented.

I<ADVANCED>

With regard to DEFRUNMODE, note that a required option with a default value is essentially optional because a value has already been supplied.  This can be true if the call to one of the add*Option() methods included a hard-coded default value (there are some exceptions: see documentation for each method) or if the user has used --save-args to save a value for a required option.

If all required options have default values (either hard-coded or user-saved), then CommandLineInterface will treat the script as if there are no required options.  For example, if DEFRUNMODE is set to 'usage', the --run flag will be added to the interface.  This means that if a required option without a hard-coded default exists, the user will not see --run in the usage output, but after they add their own saved defaults to the required options, --run will be added to the usage as a required option (alternatively --dry-run in this case will run the script too, albeit without creating output files).

The user will not be allowed to save the --run flag, thus if you want the script to be able to run without the user supplying any options, you must set DEFRUNMODE to 'run'.

=item C<setScriptInfo> [VERSION HELP CREATED AUTHOR CONTACT COMPANY LICENSE DETAILED_HELP]

This is the first method that should be called and is where you set information that a user can retrieve using the --help and --version flags.  This information is also used when the --header flag is supplied to create a header that includes the script version and creation date.

VERSION is a free-form string you can use to set a version number that will be printed when --version or --help is supplied or included in file headers when --header is supplied.

HELP is the text that is included in the --help output after the "WHAT IS THIS" bullet at the top of the help output.

CREATED is a free-form string you can use to set a creation date that will be printed when --help or --version --extended is supplied.  It is also included in file headers when --header is supplied.

AUTHOR is the name or names of the author of the script.

CONTACT is the contact information (e.g. email address) of the point(s) of contact or author(s) of the script.

COMPANY is where the script was developed.

LICENSE is a string indicating the license type.

DETAILED_HELP is what is printed if the user runs the script with the --help and --extended flags together.

I<EXAMPLE>

=over 4

I<Command>

    example.pl --version

I<Code>

    setScriptInfo(VERSION => "1.0a",
                  CREATED => "11/28/2016",
                  HELP    => "This script does x and y.");
    processCommandLine();

I<Output>

    1.0a

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --help              Print help message and quit.  See help()
    --extended          Print extended usage/help/version/header.
    --version           Print version message and quit.  See getVersion()
    --header            Print commented header to outfiles.  See getHeader()

I<LIMITATIONS>

None

I<ADVANCED>

n/a

=item C<sglob> EXPR

sglob(), standing for "safe glob", performs a bsd_glob using the GLOB_CSH argument.  It's more reliable than perl's built-in glob method, which fails for files with spaces in the name (even if they are escaped).  The purpose of this method is to allow the user to enter input files using double quotes and un-escaped spaces, as is expected to work with many programs which accept individual files as opposed to sets of files.  This version works with a mix of unescaped and escaped spaces, as well as glob characters [*, ?, [], {,,,}].  It will also split non-files on unescaped spaces and uses a helper sub (globCurlyBraces) to mitigate truncations from long strings that is an issue on some systems.

sglob() takes (EXPR) a single string (the command line argument(s)) and returns a list of the parsed/separated arguments.

sglob() is used by CommandLineInterface to parse arguments given to the various file options, such as those added by addInfileOption(), addOutfileOption(), addOutfileSuffixOption(), and addOutdirOption().

sglob() is not exported by default, thus you must either supply it in your `use CommandLineInterface qw(... sglob);` statement or call it using the package name: `CommandLineInterface::sglob();`.

I<EXAMPLE>

=over 4

I<Command>

    #Given files: 1.txt, 2.txt, a.tab, and b.tab
    example.pl -j '*.txt' -j '*.tab'

I<Code>

    my $custom_handled_files = [];
    addOption(FLAG   => 'j',
              VARREF => sub {push(@$custom_handled_files,[sglob($_[1])])});
    processCommandLine();
    print(join("\n",map {join(' ',@$_)} @$custom_handled_files));

I<Output>

    1.txt 2.txt
    a.tab b.tab

=back

I<ASSOCIATED FLAGS>

n/a

I<LIMITATIONS>

While sglob peforms better than perl's built-in glob and bsd_glob, it is still limited by the allowed number of characters in a shell command.  Behavior can be unexpected if the shell truncates a long series of arguments.  The limit on the command line length imposed by the shell is inversely affected by the size of the environment.

I<ADVANCED>

n/a

=item C<usage> [ERROR_MODE EXTENDED]

usage() is called automatically when the command line arguments are processed (see processCommandLine()), whose initial call is triggered by numerous methods, e.g. getInfile().  usage() prints a formatted message about available options in the script.

Descriptions of options printed by usage() are set by the various add*Option() methods, such as addOption(), addArrayOption(), add2DArrayOption(), addInfileOption(), addOutfileOption(), addOutfileSuffixOption(), addOutdirOption(), etc..  Each of these methods has a FLAG, REQUIRED, DEFAULT, SHORT_DESC, and LONG_DESC argument, along with other option-type-specific arguments (such as TYPE, PRIMARY, HIDDEN, ACCEPTS, FORMAT, and DELIMITER) that affect the content of the usage message.

usage() is called implicitly, so you should never need to call it unless you would like the usage to accompany an error.  However, this depends on the default RUNMODE (see setDefaults()).  If the default RUNMODE is anything other than 'usage', then the --usage flag must be supplied to see the usage output.

usage() outputs a usage message in one of the following modes:

    1. error mode, ERROR_MODE=1  - shows the script and options on a single line
    2. summary mode, EXTENDED=0  - shows succinctly described common options
    3. detailed mode, EXTENDED=1 - shows more options with long descriptions
    4. advanced mode, EXTENDED=2 - includes advanced options
    5. hidden mode, EXTENDED=3+  - shows all options including hidden/deprecated

The default mode is the summary mode.  Error mode only prints a sample command with a list of acceptable short flags and is only shown when the ERROR_MODE parameter is non-zero.  The detailed mode is triggered either by the EXTENDED parameter being 1 or by the user by supplying --extended with no other options (see above) on the command line.  Supplying the EXTENDED argument over-rides the command line --extended option.

ERROR_MODE is specified by a non-zero value and over-rides the EXTENDED mode.

The default behavior is summary mode, which uses the SHORT_DESC values specified in the add*Option methods.  If the value of SHORT_DESC is undefined or an empty string, the option is not included in the short usage summary (with the exception of REQUIRED options, which are always included).  The first shortest flag specified in the FLAG values supplied to the add*Option methods is what is reported in both the ERROR_MODE and in the short usage summary mode.  The EXTENDED mode reports all flag values specified in the FLAG string supplied to the add*Option methods as well as the LONG_DESC.

SHORT_DESC and LONG_DESC (see add*Option() methods) are not concatenated together.  They are independent descriptions.  If a description is not supplied, this description will appear in summary mode: "No usage summary provided for this option." or this description will appear in other modes: "No usage provided for this option.".

The top of the usage message shows the script name and required options (similar to what you would see with an error).  The bottom of the usage may show a legend or other messages necessary to interpret the usage content.

The body of the usage has 2 columns: flags and description.  If a DEFAULT is defined for an option (either in the add*Option() call or by the user via the --save-args option), the first part of the description contains the default value enclosed in square brackets '[]'.  If an option has an ACCEPTS value set, those values will appear after the default, surrounded by curly braces '{}'.

If an option has multiple flag aliases, each flag is displayed on a separate line in the flags column.  The best way to describe how flags and their argument types are displayed is by example:

    <file>                  Takes a single file without a flag (see FLAGLESS)
    < <file>                Takes a file on standard input (see PRIMARY)
    -i <stub> < <file>      Takes a file on standard input that can be named by
                            giving a stub string to the -i flag
    -i <file*...>...        -i can be supplied multiple times and each arg can
                            be a glob of multiple files
    -x <str>                -x takes a single string
    -x <str>...             -x can be supplied N times and takes a single string
    -x <str,...>...         -x takes a (,) delimited string, supplied N times
    -o <sfx>                -o takes a suffix (appended to an input file name)
    --help                  --help takes no argument (i.e. is a boolean)
    --no-pipeline           --pipeline is a negatable boolean, defaulted to true
    --extended [<cnt>]      --extended takes an optional count argument (count
                            options can be supplied multiple times to increment
                            the value)
    --error-limit <int>     --error-limit takes an integer argument
    --collision-mode        --collision-mode is an enumeration that takes one of
      <merge,rename,error>  the following arguments: merge, rename, or error
    --usage                 --usage is a hidden option
    [HIDDEN-OPTION]

See --help --extended 2 for a more detailed description (e.g. perl -MCommandLineInterface -e '' -- --help --extended 2).

If an option is required, one of the following symbols will appear to the left of the flags:

    * Required
    ~ Required, but has default (so essentially "not required")
    ^ One of multiple mutually exclusive options required

These symbols will be described in a legend below the usage if one or more options meets the criteria for it.  Note, when one of a set of mutually exclusive options is required, the option description will get an addendum showing the inter-related options.

Options will have addendums automatically concatenated to their LONG_DESC descriptions in the following cases:

    1. A reference to --help for defined FORMAT descriptions (see add*Option())
    2. A reference to mutually exclusive options (see makeMutuallyExclusive())
    3. A mention of when one of a list of mutually exclusive options is REQUIRED
    4. A full DEFAULT value (for DEFAULTs truncated for length)
    5. Assorted other cases where an option is affected by other options

usage() is not exported by default, thus you must either supply it in your `use CommandLineInterface qw(:DEFAULT usage);` statement or call it using the package name: `CommandLineInterface::usage();`.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt'

I<Code>

    CommandLineInterface::usage();

I<Output>


    example.pl -i "input file(s)" [...]

      <file*...>...       Input file(s).
      -o <sfx>            [STDOUT] Outfile suffix appended to file names
                          supplied to [-i].
      --help              Print general info and file formats.
      --run               Run the script.
      --extended [<cnt>]  Print detailed usage.

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --extended          Print extended usage/help/version/header.
    --save-args         Save current options for inclusion in every run.

I<LIMITATIONS>

usage() is called (and the script exits) when no options are (or only --extended is) provided and by default, when a critical error is ecountered during command line processing.  There is currently no way to not print the usage, but the exit can be skipped in the event of an error by providing --force.  Running without arguments instead of generating a usage message will be addressed when requirement 157 is implemented.

Unless you have the Term::ReadKey module installed & configured and are running this script inside a compatible terminal window, the width of the usage output is static, set at 80 characters.  There is currently no way to set this.

I<ADVANCED>

n/a

=item C<verbose> EXPRs [{OVERME LEVEL FREQUENCY COMMENT LOG}]

Prints EXPR to STDERR (unless a log file has been defined (see addLogfileOption() and addLogfileSuffixOption())).  Multiple EXPRs are all printed (similar to print()) except for hash references.

A newline character is added to the end of the message if none was supplied.

A hash reference can be supplied anywhere in the argument list, containing the keys OVERME, LEVEL, FREQUENCY, COMMENT, and/or, LOG.

For the effect of OVERME, see verboseOverMe().

A verbose message's LEVEL refers to when a it should be printed and depends on the verbose level (i.e. how many times --verbose was supplied on the command line (or what number was supplied to it)).  A message will be printed if the verbose level is greater than or equal to the message LEVEL.  For example, `verbose({LEVEL=>2},"Hello world.");` will print if --verbose is supplied at least 2 times on the command line, but not when supplied only once.

A verbose message's FREQUENCY refers to when a repeated call to verbose (e.g. in a loop) should be printed.  The message will be printed on every FREQUENCY'th call from the same line of code.  E.g. `

If COMMENT is a non-zero integer, each verbose line will be commented with a '#' character.  If it is undefined or 0, no comment character will be prepended.  If a character or string is provided, it will be used as the comment character and prepended to each line.

If LOG is non-zero, the verbose message will only be printed to the log (if logging is enabled), regardless of addLogfileOption or addLogfileSuffixOption's VERBOSE setting and will not print to standard error.  If a log file is not supplied, the message will not print anywhere.

Note that if logging of verbose messages is enabled and log output is not being mirrored to standard error (see addLogfileOption() and/or addLogfileSuffixOption()), all verbose output to standard error will be suppressed.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt' --verbose --verbose

    #or

    example.pl -i '*.txt' --verbose 2

I<Code>

    verbose({LEVEL => 1},"Currently on line:");
    my $cnt = 0;
    while($cnt < 30)
      {verbose({LEVEL => 2,FREQUENCY=>10},++$cnt)}
    verbose({LEVEL => 3},"Done"); #Will not print, bec. LEVEL = 3 & verbose = 2

I<Output>

    Currently on line:
    10
    20
    30

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all error, warning, verbose, & debug messages.
    --verbose           Prints status.  See verbose() and verboseOverMe()
    --pipeline          Prepends script name to errors, warnings, & debugs.
    --logfile           Can redirect verbose output to a log file
    --logfile-suffix    Can redirect verbose output to a log file

I<LIMITATIONS>

There is currently no way to prevent the automatic appending of a newline character.  Requirement 169 will address this.

Verbose messages do not cleanly write over previous verboseOverMe messages (or any other output ending in a carriage return) which contain tab characters.

I<ADVANCED>

verbose() removes the last newline character at the end of every verbose message (e.g. verbose("...\n")) before appending its default newline character.  Therefore, if you append multiple newline characters at the end of your message, the output will effectively contain all newline characters.

=item C<verboseOverMe> EXPRs [{LEVEL FREQUENCY}]

Same functionality as verbose().  Prints EXPR to STDERR, but tells the next call of verbose(), verboseOverMe(), debug(), warning(), or error() to print over top of the message printed here.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt' --verbose --verbose

    #or

    example.pl -i '*.txt' --verbose 2

I<Code>

    verboseOverMe({LEVEL => 1},"Currently on line: 0");
    my $cnt = 0;
    while($cnt < 30)
      {verboseOverMe({LEVEL => 2,FREQUENCY=>10},"Currently on line: ",++$cnt)}
    verbose("Done");

I<Output>

#It's hard to represent real-time appearance, but when the script completes,
#the final output will look like this:

    Done

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all error, warning, verbose, & debug messages.
    --verbose           Prints status.  See verbose() and verboseOverMe()
    --pipeline          Prepends script name to errors, warnings, & debugs.

I<LIMITATIONS>

Verbose messages do not cleanly write over previous verboseOverMe messages (or any other output ending in a carriage return) which contain tab characters.

CommandLineInterface currently knows nothing about your terminal's window width.  If a verboseOverMe message is printed which is longer than the window width, the next message (depending on the behavior of your terminal app, may only overwrite the last portion of the previous message that was soft-wrapped from the previous line.  This can cause unsightly mass output if large messages are printed to a norrow terminal window.  This will be addressed when requirement 176 is implemented.

If EXPR contains newline characters (\n), only the last line will be printed over on the next call.

I<ADVANCED>

All STDERR messages printed by verbose(), verboseOverMe(), debug(), warning(), or error() keep track of the length of the last line so that if the next message printed is shorter, spaces will be printed to clear the prior line.

This method simply passes its parameters to verbose(), but adds {OVERME=>1} to the parameters.

Messages printed via verboseOverMe simply append a carriage return at the end.  Any last newline character in the message is replaced with a carriage return.

Hint: To not print over the last verboseOverMe message printed, call verbose with a message that starts with a newline character (\n).

=item C<warning> EXPRs [{DETAIL}]

=item C<error> EXPRs [{DETAIL}]

Prints EXPR(s) to STDERR.  Multiple EXPRs are all printed (similar to print()).  Messages are prepended by 'ERROR#: ' or 'WARNING#: ' where '#' is the sequential error/warning number (indicating the order in which the errors/warnings occurred).

Note that if logging of warning/error messages is enabled and log output is not being mirrored to standard error (see addLogfileOption() and/or addLogfileSuffixOption()), all error/warning output to standard error will be suppressed.

I<EXAMPLE>

=over 4

I<Command>

    example.pl -i '*.txt'

I<Code>

    error("An error occurred.");
    warning("A warning occurred.");

I<Output>

    ERROR1: An error occurred.
    WARNING1: A warning occurred.

=back

I<ASSOCIATED FLAGS>

The following default options affect the behavior of this method:

    --quiet             Suppress all error, warning, verbose, & debug messages.
    --error-limit       Suppress some errors & warnings.
    --pipeline          Prepends script name to errors, warnings, & debugs.
    --debug             Prepends call trace.  See debug()
    --logfile           Can redirect verbose output to a log file
    --logfile-suffix    Can redirect verbose output to a log file

I<LIMITATIONS>

The call trace currently indicates method name and line number, but does not yet indicate file name.  This will be addresses requirement 170 is implemented.

I<ADVANCED>

The number supplied to --error-limit indicates how many times each instance of a call to error() may be called before its output is suppressed.  The first time its output is suppressed a suppression warning message is printed to STDERR.  `--error-limit 0` turns off error suppression.

--pipeline is detected automatically by detection of sibling processes (assumed to be involved in a pipe of input or output) or by the fact that the parent prcess is not a shell/tty.  Explicitly setting --pipeline or --no-pipeline turns off automatic detection.

If --debug is supplied on the command line once, error messages will contain the calling block name (i.e. method name) and the originating line number of where the error/warning was called.  If --debug is supplied more than once, a full call trace after the error number and before the error message is included.  Call traces from left to right proceed from child/last call to parent/first caller methods.

=back

=head1 DISCUSSION

=head2 Combining single character flags not allowed

Many unix tools allow a series of options to be abbreviated in such a way that instead of supplying -x -y -z, a user could supply -xyz or even just xyz (without the dash).  However CommandLineInterface prohibits this because the combination of long option flags with bundled options (e.g. -xyz) can lead to unexpected result.  Refer to the bundling and bundling_override sections of Getopt::Long's perldoc for further details.

=head2 1:1orM (Processing repeated input files)

nextFileCombo() is an iterator that allows you to process pairs of files together (abstracted to "sets" of files for more than 2 types of input file).  It supports the ability for users to run (serially) many batches of files in a single command by supplying the same flags multiple times.  For example:

example.pl -i '1*.txt' -j a.txt -i '2*.txt' -j b.txt).

The sets (or pairs) of input files are pre-organized, processed, validated, checked to see that their output files have overwrites/collisions, etc..  Each pair/set of input files that go together (or rather, are processed together) are kept in a 2D array, and it's the index of the outer array that nextFileCombo() advances.  Using the example above, that array might look something like this:

[['1_1.txt', 'a.txt'],
 ['1_2.txt', 'a.txt'],
 ['1_3.txt', 'a.txt'],
 ['2_1.txt', 'b.txt'],
 ['2_2.txt', 'b.txt'],
 ['2_3.txt', 'b.txt'],
 ['2_4.txt', 'b.txt']]

If you have an input file type that has a 1:M or 1:1orM relationship with another type of input file (as in the example above), nextFileCombo() will end up returning the 1 file repeatedly because it's a part of multiple sets.  Thus, code that processes that file, if no special steps are taken to only process such a file once, will process the same file multiple times.  For example:

BAD EXAMPLE:

my $fidi = addInfileOption('i');
my $fidj = addInfileOption(FLAG       => 'j',
                           PAIR_WITH  => $fidj,
                           PAIR_RELAT => 'ONETOMANY');
while(nextFileCombo())
  {
    my $ifile = getInfile($fidi);
    my $jfile = getInfile($fidj);

    my $jdata  = processFileTypeJ($jfile);
    my $result = processFileTypeI($ifile,$jdata);
  }

The above example is poorly written because it processes the same -j file for each file provided to -i in cases like this:

example.pl -i '1.txt 2.txt 3.txt' -j lookup.txt

The file 'lookup.txt' ends up getting processed 3 times, one time for each of the 3 -i files.

On the other hand, you can write your code in a way that processes single files paired with multiple files once:

GOOD EXAMPLE:

my $fidi = addInfileOption('i');
my $fidj = addInfileOption(FLAG       => 'j',
                           PAIR_WITH  => $fidj,
                           PAIR_RELAT => 'ONETOONEORMANY');
my $jprocessed = {};
my $jdata;
while(nextFileCombo())
  {
    my $ifile = getInfile($fidi);
    my $jfile = getInfile($fidj);

    if(exists($jprocessed->{$jfile}))
      {$jdata = $jprocessed->{$jfile}}
    else
      {
        $jdata = processFileTypeJ($jfile);
        $jprocessed->{$jfile} = $jdata;
      }

    my $result = processFileTypeI($ifile,$jdata);
  }

This code would work both in the case of 'ONETOMANY' or 'ONETOONEORMANY'.  The purpose of 'ONETOONEORMANY' is to support cases where a user can decide that they want to use the same data provided to -j for all files provided to -i or if they want a different -j file for each file provided to -i.

There is a new feature on the way that will make the ONETOMANY case a lot easier and allow you to create nested loops, using iterators that account for 1:M relationships.  Until then, checking files to see if they've been processed before, as demonstrated above, is a simple way to make your file processing more efficient.  There are of course, more ways to do it.  This is just one example.

=head2 M:M

If you want to process all combinations of 2 (or more) types of input files, the code actually can do it, but currently it is caught and prohibited because there are cases that are not supported, and it's because of the built-in flexibility that allows users to do things like this:

example.pl -i '1.txt 2.txt 3.txt' -i 'a.txt b.txt' -j 'nums.txt letters.txt'

example.pl -i '1.txt 2.txt 3.txt' -i 'a.txt b.txt' -j nums.txt -j letters.txt

Each of the above commands results in the same pairings of files of type -i and -j.  CommandLineInterface searches for and finds the "matching dimensions".  By dimensions, I mean the number of instances of a type of flag versus the number of files supplied to that flag.  The processing of the parameters creates a 2D array of files for each flag type and it transposes any types when there is not a matching dimension.

The code, as it's currently written, would (without the catching of the case where there are no matching dimensions) output all combinations of input files.  However, it's not an explicit behavior, and that's the code that needs to be added.  Because as it stands right now, it cannot output all possible combinations whenever there is a matching dimension between the 2, 2D arrays of types of input files.

=head1 LICENSE

This is released under the GNU Public License 3.0.

=head1 AUTHOR

Robert W. Leach - L<http://http://lsi.princeton.edu/directory/robert-w.-leach/>

=head1 SEE ALSO

L<GetOpt::Long>

=cut

1;
