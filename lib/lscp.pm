package lscp;

use 5.010001;
use strict;
use warnings;
use File::Basename;
use File::Find;
use File::Slurp;
use Lingua::Stem;
use FindBin;
use POSIX qw/ceil/;
use threads;
use threads::shared;
use Log::Log4perl qw(:easy);

require Exporter;
use AutoLoader qw(AUTOLOAD);
our @ISA = qw(Exporter);
our @EXPORT_OK = ( );
our $VERSION = '0.01';

# NOTE: stemming implies lowercase

# Hash table to hold preprocessing options, in the form
# of $options{optionName}=$optionValue. The new() method sets the default values
# for each optionName; users set option with the setOption() method. 
my %options;


# English list borrowed from MALLET source code file:
# src/cc/mallet/pipe/TokenSequenceRemoveStopwords.java 
my @english  = qw( 
a able about above according accordingly across actually after afterwards
again against all allow allows almost alone along already also although
always am among amongst an and another any anybody anyhow anyone anything anyway
anyways anywhere apart appear appreciate appropriate are around as aside
ask asking associated at available away awfully b be became because become
becomes
becoming been before beforehand behind being believe below beside besides best
better
between beyond both brief but by c came can cannot cant cause causes certain
certainly
changes clearly co com come comes concerning consequently consider considering
contain 
containing contains corresponding could course currently
d definitely described despite did different do does doing done down downwards
during e each
edu eg eight either else elsewhere enough entirely especially et etc even ever
every 
everybody everyone everything everywhere ex exactly example except f far few
fifth first five followed following follows for former formerly forth four from
further 
furthermore g get gets getting given
gives go goes going gone got gotten greetings h had happens hardly has have
having he hello
help hence her here hereafter hereby herein hereupon hers herself hi him himself
his hither 
hopefully how howbeit however i ie if
ignored immediate in inasmuch inc indeed indicate indicated indicates inner
insofar instead into inward is
it its itself j just k keep keeps kept know knows known l
last lately later latter latterly least less lest let like liked likely little
look looking looks ltd m mainly many may maybe me mean meanwhile merely
might more moreover most mostly much must my myself n name namely nd
near nearly necessary need needs neither never nevertheless new next nine no
nobody
non none noone nor normally not nothing novel now nowhere o obviously of
off often oh ok okay old on once one ones only onto or
other others otherwise ought our ours ourselves out outside over overall own p
particular particularly per perhaps placed please plus possible presumably
probably provides q que
quite qv r rather rd re really reasonably regarding regardless regards
relatively respectively
right s said same saw say saying says second secondly see seeing seem
seemed seeming seems seen self selves sensible sent serious seriously seven
several shall
she should since six so some somebody somehow someone something sometime
sometimes somewhat
somewhere soon sorry specified specify specifying still sub such sup sure t take
taken tell tends th than thank thanks thanx that thats the their theirs
them themselves then thence there thereafter thereby therefore therein theres
thereupon these they
think third this thorough thoroughly those though three through throughout thru
thus to
together too took toward towards tried tries truly try trying twice two u
un under unfortunately unless unlikely until unto up upon us use used useful
uses using usually uucp v value various very via viz vs w want
wants was way we welcome well went were what whatever when whence whenever
where whereafter whereas whereby wherein whereupon wherever whether which while
whither who whoever
whole whom whose why will willing wish with within without wonder would would
x y yes yet you your yours yourself yourselves z zero);

# Taken from various websites (Java, C, C++)
my @keywords = qw(
abstract  do import public throws boolean double instanceof return transient
break  else  int short  try byte  extends interface  static void
case  final  long  strictfp  volatile catch  finally native super  while
char  float  new switch  class  for package synchronized   
continue  if private this   default implements protected  throw
const goto null true false

auto break case char const continue default do double else enum extern float for
goto if int
long register return short signed sizeof static struct switch typedef union
unsigned void volatile while

asm         dynamic_cast  namespace  reinterpret_cast  try
bool        explicit      new        static_cast       typeid
catch       false         operator   template          typename
class       friend        private    this              using
const_cast  inline        public     throw             virtual
delete      mutable       protected  true              wchar_t

and      bitand   compl   not_eq   or_eq   xor_eq
and_eq   bitor    not     or       xor

cin   endl     int_min   iomanip    main      npos  std
cout  include  int_max   iostream   max_rand  null  string
);

# Taken from TODO
my @custom   = qw( 
mozilla chrome google firefox
http org com www edu
);

my %stopwordsEnglish;
my %stopwordsKeywords;
my %stopwordsCustom;

# Holds all the files names in the input directory
my @FILES;

# Holds the number of files seen so far
my $fileCounter=0;

# Logger instance for logging messages of different levels
my $logger;


sub new{
    my $self  = shift;
    my $class = ref($self) || $self;

    # Set default preprocessing options
    $options{"inPath"}              = "./in";
    $options{"outPath"}             = "./out";

    $options{"numberOfThreads"}     = 1;

    $options{"logLevel"}            = "error";
    $options{"doOutputLogFile"}     = 0;
    $options{"logFilePath"}         = "";

    $options{"doIdentifiers"}       = 1;
    $options{"doComments"}          = 1;

    $options{"doRemoveDigits"}      = 1;
    $options{"doLowerCase"}         = 1;
    $options{"doStemming"}          = 1;
    $options{"doTokenize"}          = 1;
    $options{"doRemoveSmallWords"}  = 0;

    $options{"doStopwordsEnglish"}  = 1;
    $options{"doStopwordsKeywords"} = 1;
    $options{"doStopwordsCustom"}   = 1;
    $options{"doStopPhrases"}       = 0;

    $options{"isCode"}              = 1;
    $options{"doEmailReply"}        = 0;
    $options{"ref_stopPhrases"}     = 0;

    # Build hash tables of stopwords, for speed later
    foreach my $w (@english){
        $stopwordsEnglish{$w} = 1;
    }   
    foreach my $w (@keywords){
        $stopwordsKeywords{$w} = 1;
    }   
    foreach my $w (@custom){
        $stopwordsCustom{$w} = 1;
    }   

    # Initialze the logger
    Log::Log4perl->easy_init($ERROR);
    $logger = get_logger();
    $logger->level($ERROR);

    return bless {}, $class;
}

sub setOption{
    my $self        = shift;
    my $optionName  = shift;
    my $optionValue = shift;

    if (exists $options{$optionName}){
        $logger->info("Setting option \'$optionName\' to \'$optionValue\'\n");
        $options{$optionName} = $optionValue;
    } else {
        $logger->warn("Option \'$optionName\' does not exist.\n");
    }

    # Special case: changing the log level. Log4J does not have a built-in
    # function to handle string levels, so we have to loop through the options.
    if ($optionName eq "logLevel"){
       if ($optionValue eq "warn"){
           $logger->level($WARN);
       } elsif ($optionValue eq "info"){
           $logger->level($INFO);
       } elsif ($optionValue eq "error"){
           $logger->level($ERROR);
       } elsif ($optionValue eq "fatal"){
           $logger->level($FATAL);
       } else {
           $logger->error("Value \'$optionValue\' not valid for \'$optionName\'.\n");
       }
    }
             
}

sub preprocess{
    # Check if input directory exists, is a directory, and is readable
    if (! -e $options{"inPath"}){
       $logger->fatal("Directory \'$options{\"inPath\"}\' does not exist.\n");
    } 
    if (! -d $options{"inPath"}){
       $logger->fatal("File \'$options{\"inPath\"}\' is not a directory.\n");
    } 
    if (! -r $options{"inPath"}){
       $logger->fatal("Directory \'$options{\"inPath\"}\' is not readable.\n");
    } 

    # Check if output directory exists and is writable
    if (! -e $options{"outPath"}){
       mkdir $options{"outPath"};
    } 
    if (! -w $options{"outPath"}){
       $logger->fatal("Directory \'$options{\"outPath\"}\' is not writable.\n");
    } 

    # Create an array of file names in the input directory
    $logger->info("Reading input directory and making list of files.\n");
    find({wanted=>\&addFileToArray,no_chdir=>1}, $options{"inPath"});
    my $numFiles = scalar @FILES;
    $logger->info("Found $numFiles files.\n");
       

    # Spawn threads, each with its own range of ids into the @FILE array
    # Each thread will return an array of #TODO
    my @threads;
    my $numFilesEach = ceil($numFiles/$options{"numberOfThreads"});
    for (my $count = 1; $count <= $options{"numberOfThreads"}; $count++) {
        my $startID = ($count-1)*$numFilesEach;
        my $endID   =  $startID+$numFilesEach-1;
        if ($endID >= $numFiles) {$endID = $numFiles-1;}
    
        # Spawn the thread!
        my $t = threads->new(\&worker, $count, $startID, $endID);
        push(@threads,$t);
    }
    
    # Wait for each thread to finish
    my @all_info;
    foreach (@threads) {
        my @info = @{$_->join;};
        @all_info = (@all_info, @info);
    }

    $logger->info("All threads complete.\n");
    
    # Output log file, if we want
    if ($options{"doOutputLogFile"} == 1){
    
        # TODO
        $logger->info("Writing info file.\n");
        open (INFO, ">$options{\"logFilePath\"}") or die "$0: Error: unable to open \"$options{\"logFilePath\"}\": $!";
        my @sort = sort(@all_info);
        my $j = 0;
        foreach my $infoString (@sort){
            print INFO "$j, $infoString\n";
            ++$j;
        }
        close (INFO);
    }
}


sub addFileToArray {
    my $fileFull = $File::Find::name;
    return if (-d $fileFull);
    $FILES[$fileCounter] = $fileFull;
    $fileCounter++;
}



sub worker{
    my $num = shift;
    my $start = shift;
    my $end = shift;
    my $logger = get_logger();

    $logger->info("Thread $num is doing file IDs $start to $end.\n");

    my @info; # Contains metrics on the preprocssing
    my $fileCounter = 0;

    for (my $i = $start; $i <= $end; ++$i){
        my $fileFull = $FILES[$i];
        my $fileBase = basename($fileFull);

        # Full path to output file
        my $outPath = "$options{\"outPath\"}/$fileBase";

        (my $words, my $numWordsFinal, my $numComments, my $numIdentifiers, 
                my $numStopwordsRemoved, my $numSmallWordsRemoved)
            = extractWords($fileFull);


        #Output the document (use slurp for speed)
        $words = join("\n", split(/ /,$words));
        chomp $words;
        write_file($outPath, "$words\n");

        # Output some info on the document.
        # TODO
        my $versionDate = getVersionDate($fileFull);
        my $packageName = getPackageName($fileFull);
        my $longName    = getLongName($fileFull);
        my $shortName   = getShortName($fileFull);

        # Write to log file
        my $infoString = "$versionDate, $fileBase, $packageName, $longName, 
                $shortName, $numWordsFinal, $numComments, $numIdentifiers, 
                $numStopwordsRemoved, $numSmallWordsRemoved";

        push @info, $infoString;

        $fileCounter++;
    }
    $logger->info("Thread $num is finished.\n");
    return \@info;
}


sub extractWords{
    my $inPath = shift;

    # $words is a string that will hold the individual words in the file.
    # Each preprocessing step takes $words as input, and overwrites $words as
    # output. Thus, returning $words will return the final, parsed text.
    # The actual words in $words will be seperated by a newline.
    my $words  = "";

    # Keep track of how many comments, identifiers, stopwords, etc. that we find
    my $numComments                 = 0;
    my $numIdentifiers              = 0;
    my $numStopwordsRemoved         = 0;
    my $numSmallWordsRemoved        = 0;

    # Useful to preprocessing non-source code files, like bug reports or emails
    if ($options{"isCode"} == 0){
        $words = read_file($inPath) ;
        if ($options{"doEmailReply"} == 1){
            $words = removeEmailReply($words);
        }
        $words = removePunctuation($words);
        $words = removeDigits($words);
        # NOTE: Stopwords will be removed later, in common code

    # If we're preprocessing source code
    } else {
    
        if ($options{"doIdentifiers"} == 1){
            ($numIdentifiers, my $newWords) = getIdentifiers($inPath);
            $words = "$words $newWords";
        }
    
        if ($options{"doComments"} == 1){
            ($numComments, my $newWords) = getComments($inPath);
            $words = "$words $newWords";
        }
    }
    
    if ($options{"doRemoveDigits"} == 1){
        $words = removeDigits($words);
    }

    if ($options{"doTokenize"} == 1){
        $words = tokenize($words);
    }
    
    if ($options{"doLowerCase"} == 1){
        $words = lc($words);
    }
    
    if ($options{"doStopwordsEnglish"} == 1){
        (my $numRemoved, $words) = removeStopwords($words, \%stopwordsEnglish);
        $numStopwordsRemoved += $numRemoved;
    }
    
    if ($options{"doStopwordsKeywords"} == 1){
        (my $numRemoved, $words) = removeStopwords($words, \%stopwordsKeywords);
        $numStopwordsRemoved += $numRemoved;
    }
    
    if ($options{"doStopwordsCustom"} == 1){
        (my $numRemoved, $words) = removeStopwords($words, \%stopwordsCustom);
        $numStopwordsRemoved += $numRemoved;
    }
    
    if ($options{"doStopPhrases"} == 1 && @{$options{"ref_stopPhrases"}}){
        (my $numRemoved, $words) = removeStopPhrases($words, $options{"ref_stopPhrases"});
        $numStopwordsRemoved += $numRemoved;
    }
    
    if ($options{"doStemming"} == 1){
        $words = stemWords($words);
    }
    
    if ($options{"doRemoveSmallWords"} == 1){
        ($numSmallWordsRemoved, $words) = removeSmallWords($words, 2);
    }
    
    my $numWords = getNumWords($words);
    return (removeDuplicateSpaces($words), $numWords, $numComments,
                                        $numIdentifiers, $numStopwordsRemoved,
    $numSmallWordsRemoved);

}

##########################################################
##########################################################
sub stem {
    my ($word) = @_;
    my $stemref = Lingua::Stem::stem( $word );
    return $stemref->[0];
}


##########################################################
##########################################################
sub getOutName{
    my $in=shift;
    my $prefix=shift;
    my $out = "";


    my ($file, $packageName) = fileparse($in);
    $packageName =~ s/\//./g;       # replace "/" with "."
    $packageName =~ s/\.\././g;     # replace double .
    $packageName =~ s/\.$//g;       # remove trailing .
    $packageName =~ s/^\.//g;       # replace leading .
    $packageName =~ s/\r//g;        # windows newline
    $packageName =~ s/ /_/g;        # remove spaces

    if ($prefix eq ""){
        $out = "$$packageName#$file";
    } else {
        $out = "$prefix#$packageName#$file";
    }

    return $out;
}


##########################################################
##########################################################
sub getDiffLDAType{
    my $in = shift;
    my @c  = split(/\./, basename($in));
    return $c[-1];
}

##########################################################
##########################################################
sub getVersionDate{
    my $in = shift;
    my @c  = split(/\#/, basename($in));
    return $c[0];
}

##########################################################
##########################################################
sub removeChangeType{
    my $in = shift;

    $in =~ s/\.add$//g;
    $in =~ s/\.delete$//g;
    $in =~ s/\.change$//g;

    return $in;
}

##########################################################
##########################################################
sub removeDate{
    my $in = shift;

    my @c  = split(/\#/, $in);
    my $bad = $c[0];
    $in =~ s/^$bad\#//g;

    return $in;
}

##########################################################
##########################################################
sub getLongName{
    my $in = shift;
    my $out = getPackageName($in).".".getShortName($in);
    return $out;
}

sub getLongName2{
    my $in = shift;
    my $out = getPackageName($in)."#".getShortName($in);
    return $out;
}

##########################################################
##########################################################
sub getShortName{
    my $in = shift;
    $in =~ s/\#/\//g;
    $in = basename($in);
    return $in;
}


##########################################################
##########################################################
# Package name is everything except basename
sub getPackageName{
    my $in = shift;

    # Remove the date, if present
    if ($in =~ /^[\d]{4}-[\d]{2}-[\d]{2}/){
        $in = removeDate($in);
    }

    # Remove the actual filename
    $in =~ s/\#/\//g;
    my $basename = basename($in);
    $in =~ s/\/$basename$//g;

    # Remove leading dot, if any
    $in =~ s/\//\./g;
    $in =~ s/^\.//g;

    return $in;
}
##########################################################
##########################################################
sub removeStopPhrases{
    my $wordsIn = shift;
    my $ref_stops = shift;

    my $wordsOut = $wordsIn;
    my $numRemoved = 0;
    foreach my $stop (@{$ref_stops}){
        $wordsOut =~ s/$stop//gs;
    }

    return ($numRemoved, removeDuplicateSpaces($wordsOut));
}



##########################################################
##########################################################
sub removeStopwords{
    my $wordsIn = shift;
    my $stops = shift;

    my $wordsOut = "";

    my $numRemoved = 0;

    # Make sure to lowercase the wordsIn, because the stopwords are themselves
    # lowercase.
    for my $w (split / +/, lc($wordsIn)) {
        if (exists($stops->{$w})) {++$numRemoved}
        else {
            $wordsOut = "$wordsOut $w";
        }
    }

    return ($numRemoved, removeDuplicateSpaces($wordsOut));
}

##########################################################
##########################################################
sub stemWords{
    my $wordsIn  = shift;
    my $wordsOut = "";

    for my $w (split / +/, $wordsIn) {
        $wordsOut = "$wordsOut ".stem($w);
    }

    return removeDuplicateSpaces($wordsOut);
    #return $wordsOut;
}

##########################################################
##########################################################
sub removePunctuation{
    my $wordsIn  = shift;
    $wordsIn =~ s/[^[:ascii:]]//g; # remove weird language stuff
    $wordsIn =~ s/[\@\[\]\<\>\.\,\=\/\#\-\+\{\}\!\~\:\;\(\)\\\'\"\?\*\&\%\|]/
/g;
    return removeDuplicateSpaces($wordsIn);
    #return $wordsIn;
}


##########################################################
##########################################################
sub removeDigits{
    my $wordsIn  = shift;
    $wordsIn =~ s/[0-9]//g;
    return $wordsIn;
}
##########################################################
##########################################################
sub tokenize{
    my $wordsIn  = shift;
    my $wordsOut = "";

    for my $w (split / +/, $wordsIn) {

        # Split up camel case: aaA ==> aa A
        $w =~ s/([a-z]+)([A-Z])/$1 $2/g;

        # Split up camel case: AAa ==> AA a
        $w =~ s/([A-Z]{2,100})([a-z]+)/$1 $2/g;

        # Split up underscores 
        $w =~ s/_/ /g;

        # Remove punctionation, syntax stuff
        $w = removePunctuation($w);

        # Remove digits
        $w =~ s/[0-9]//g;

        $wordsOut = "$wordsOut $w";
    }

    return removeDuplicateSpaces($wordsOut);
    #return $wordsOut;
}


##########################################################
##########################################################
sub removeSmallWords{
    my $wordsIn  = shift;
    my $length   = shift;
    my $wordsOut = "";

    my $numRemoved = 0;
    for my $w (split / +/, $wordsIn) {
        if (length($w) > $length){
            $wordsOut = "$wordsOut $w";
        } else {
            ++$numRemoved;
        }
    }

    return ($numRemoved, removeDuplicateSpaces($wordsOut));
    #return $wordsOut;
}

##########################################################
##########################################################
sub removeDuplicateSpaces{
    my $wordsIn  = shift;
    $wordsIn =~ s/\r/ /g;
    $wordsIn =~ s/\n/ /g;
    $wordsIn =~ s/  +/ /g;
    $wordsIn =~ s/^ +//g;
    return $wordsIn;
}

##########################################################
##########################################################
sub getComments{
    my $fileName = shift;
    my $wordsOut = "";
    my $numRemoved = 0;

    $wordsOut = `xscc.awk extract=comment prune=copyright $fileName`;
    $wordsOut = removePunctuation($wordsOut);
    (my $dummy, $wordsOut) = removeStopwords($wordsOut, \%stopwordsKeywords);

    return (getNumWords($wordsOut), removeDuplicateSpaces($wordsOut));
}

##########################################################
##########################################################
# Use library to do the magic
sub getIdentifiers{
    my $fileName = shift;
    my $wordsOut = "";

    $wordsOut = `xscc.awk $fileName`;

    $wordsOut = removePunctuation($wordsOut);
    (my $dummy, $wordsOut) = removeStopwords($wordsOut, \%stopwordsKeywords);

    return (getNumWords($wordsOut), $wordsOut);
}
##########################################################
##########################################################
# Use library to do the magic
sub getNumWords{
    my $inWords = shift;
    my $num = ($inWords =~ tr/ +//);
    ++$num;
    return $num;
}
##########################################################
##########################################################
# Removes lines in emails like:
# On 2/14/07, Greg Marr <gregm@alum.wpi.edu> wrote:
# At 08:33 AM 2/14/2007, Garrett Rooney wrote:
# 
# Also remove any email addresses or URLS
sub removeEmailReply{
    my $in = shift;

    # First, remove ">" operator to make life easier
    $in =~ s/>+ ?//g;

    # Multi-line wrotes
    $in =~ s/On.*\n.*wrote://g;
    $in =~ s/At.*\n.*wrote://g;

    # Single line wrotes
    $in =~ s/On .*wrote://g;
    $in =~ s/At .*wrote://g;
    $in =~ s/.*wrote://g;


    # Remove URLS
    $in =~ s|(\w+)://([^/:]+)(:\d+)?/(.*)||g;

    # Remove email addresses
    $in =~ s/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}//g;

    # Remove old messages
    $in =~ s/.*Original Message.*//g;
    $in =~ s/From:.*//g;
    $in =~ s/Sent:.*//g;
    $in =~ s/To:.*//g;
    $in =~ s/Cc:.*//g;
    $in =~ s/Subject:.*//g;

    # Remove Disclaimers messages
    $in =~ s/DISCLAIMER.*//sg;
    $in =~ s/CAUTION.*//sg;
    # Remove Signatures: handles  2 cases (first up until two newlines):
    #-- 
    #BOYA SUN
    #Computer Science Division
    #Electrical Engineering & Computer Science Department
    #513 Olin Building
    #Case Western Reserve University
    #10900 Euclid Avenue
    #Cleveland, OH 44106
    #
    #
    # > --
    #> Nick Kew

    $in =~ s/(>+ )?--\s*\n((>+ )?[a-zA-Z0-9].*\n)+//g;

    # Special cases for PSQL
    $in =~ s/tom lane//ig;
    $in =~ s/\btom\b|bruce|andrew|gavin|zdenek|momjian|nick|merlin|alvaro|herrera//ig;
    $in =~ s/david|peter|pete|joshua|josh|drake|jim|berkus|gregory|greg|stark|stefan//ig;
    $in =~ s/heikki|michael|fournier|marc|simon|jose|hamlet|vince|kevin|karel|karen|mike//ig;
    $in =~ s/baccus|\bdon\b|robert||joseph|josef|\bjoe\b|neil|christopher|chris|\bbob\b|andrea|donb//ig;
    $in =~ s/afaict|afaik|imo|hmmm|fwiw|btw|brb|imho|fyi//ig;
    $in =~ s/kinda|yep|yessir|yeah|sure|till//ig;
    $in =~ s/hello|hiya|\bhi\b|heya|\bhey\b|\bdear\b//ig;
    $in =~ s/\bdon\b|\bnt\b|\bdo\b|\bnot\b|\bweren\b//ig;
    $in =~ s/xxx+//ig;  # From Unix directory listings
    $in =~ s/thanks|cheers|regards|bye|sincere?ly|best,//ig;
    $in =~ s/kirjutas|kell|kenal//ig;   # Some language?

    return $in;
}




1;
__END__


# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

lscp - Lightweight source code preprocesser

=head1 SYNOPSIS

  use lscp;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for lscp, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Stephen W. Thomas, <lt>sthomas@cs.queensu.ca<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Stephen W. Thomas

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
