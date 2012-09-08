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
use Regexp::Common qw /comment/;

require Exporter;
use AutoLoader qw(AUTOLOAD);
our @ISA = qw(Exporter);
our @EXPORT_OK = ( );
our $VERSION = '0.01';

## Global Package Variables

# Hash table to hold preprocessing options, in the form
# of $options{optionName}=$optionValue. The new() method sets the default values
# for each optionName; users set option with the setOption() method. 
my %options;

# Will hold the stopwords, for faster lookup later
my %stopwordsEnglish;
my %stopwordsKeywords;

# Holds all the files names in the input directory
my @FILES;

# Holds the number of files seen so far
my $fileCounter=0;

# Logger instance for logging messages of different levels
my $logger;


## Package member functions

=head2 new
 Title    : new
 Usage    : my $results = $lscp=>new()
 Function : creates a lcsp obejct, with default option values
 Returns  : reference to a lscp object
 Args     : named arguments:
          : none.
=cut
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

    $options{"isCode"}              = 1;
    $options{"doIdentifiers"}       = 1;
    $options{"doStringLiterals"}    = 1;
    $options{"doComments"}          = 1;

    $options{"doRemoveDigits"}      = 0;
    $options{"doLowerCase"}         = 0;
    $options{"doStemming"}          = 0;
    $options{"doTokenize"}          = 0;
    $options{"doRemovePunctuation"} = 0;
    $options{"doRemoveSmallWords"}  = 0;
    $options{"smallWordSize"}       = 1;

    $options{"doStopwordsEnglish"}  = 0;
    $options{"doStopwordsKeywords"} = 0;
    $options{"doStopwordsCustom"}   = 0;
    $options{"ref_stopwordsCustom"} = 0;

    $options{"doRemoveEmailAddresses"}   = 0;
    $options{"doRemoveEmailSignatures"}  = 0;
    $options{"doRemoveURLs"}             = 0;
    $options{"doRemoveWroteLines"}       = 0;
    $options{"doRemoveQuotedEmails"}     = 0;
    $options{"doRemoveEmailHeaders"}     = 0;

    # Define and build hash tables of stopwords, for speed later
    buildStopwordTables();

    # Initialze the logger
    Log::Log4perl->easy_init($ERROR);
    $logger = get_logger();
    $logger->level($ERROR);

    return bless {}, $class;
}


=head2 setOption
 Title    : setOption
 Usage    : $results = $lscp=>setOption(optionName, optionValue)
 Function : Sets a new value for the desired preprocessing option
 Returns  : none.
 Args     : named arguments:
          : optionName => string
          : optionValue => any type, depending on optionName
=cut
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


=head2 preprocess
 Title    : preprocess
 Usage    : $results = $lscp=>preprocess
 Function : Runs the preprocessing process, with the current options
 Returns  : none.
 Args     : named arguments:
          : none.
=cut
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
    # Each thread will return an array of log lines (strings ending with"\n")
    # that we can gather into a big "@all_info" array, to print later.
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
    
        $logger->info("Writing info file.\n");
        my $outFileName = $options{"logFilePath"};
        open (LOG, ">$outFileName") or die "Error: unable to open log file";
        my @sort = sort(@all_info);
        my $j = 0;
        foreach my $infoString (@sort){
            print LOG "$j, $infoString";
            ++$j;
        }
        close (LOG);
    }
}


=head2 addFileToArray
 Title    : addFileToArray
 Usage    : addFileToArray() 
 Function : Adds a single file to the array of all input files. Called by the
          : Find funciton.
 Returns  : none.
 Args     : named arguments:
          : none.
=cut
sub addFileToArray {
    my $fileFull = $File::Find::name;
    return if (-d $fileFull);
    $FILES[$fileCounter] = $fileFull;
    $fileCounter++;
}


=head2 worker
 Title    : worker
 Usage    : worker($threadID, $startFileID, $endFileID) 
 Function : A threads routine to preprocess a range of file ids.
 Returns  : none.
 Args     : named arguments:
          : $threadID => the ID of this thread
          : $startFileID => the ID (i.e. index in global @FILES) of the file to start with
          : $endFileID => the ID (i.e., index in global @FILES) of the file to end with
=cut
sub worker{
    my $threadID = shift;
    my $startFileID    = shift;
    my $endFileID      = shift;
    my $logger   = get_logger();

    $logger->info("Thread $threadID is doing file IDs $startFileID to $endFileID.\n");

    # Contains metrics on the preprocssing
    my @info; 
    my $fileCounter = 0;

    for (my $i = $startFileID; $i <= $endFileID; ++$i){
        my $fileFull = $FILES[$i];
        my $fileBase = basename($fileFull);

        # Full path to output file
        my $outPath = "$options{\"outPath\"}/$fileBase";

        (my $words, my $numWordsFinal, my $numComments, my $numIdentifiers, 
                my $numStopwordsRemoved, my $numSmallWordsRemoved)
            = extractWords($fileFull);


        #Output the document (use slurp for speed)
        $words = join("\n", split(/\s+/,$words));
        chomp $words;
        write_file($outPath, "$words\n");

        # Output some info on the document.
        # DEPRECATED
        #my $versionDate = getVersionDate($fileFull);
        #my $packageName = getPackageName($fileFull);
        #my $longName    = getLongName($fileFull);
        #my $shortName   = getShortName($fileFull);

        # Write to log file
        my $infoString = "$fileFull, $numWordsFinal, $numComments, $numIdentifiers, $numStopwordsRemoved, $numSmallWordsRemoved\n";

        push @info, $infoString;

        $fileCounter++;
    }
    $logger->info("Thread $threadID is finished.\n");
    return \@info;
}


=head2 extractWords
 Title    : extractWords
 Usage    : extractWords($inFilePath)
 Function : Extracts and preprocesses all the words from file '$inFilePath'
 Returns  : $words => string, The extract words.
 Args     : named arguments:
          : $inFilePath => string, the path of the input file to process
=cut
sub extractWords{
    my $inFilePath = shift;

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

    # If we're not doing code, just grab all the words.
    if ($options{"isCode"} == 0){
        $words = read_file($inFilePath) ;

    # If we are doing code, just grab identifiers and/or comments
    } else {
        if ($options{"doIdentifiers"} == 1){
            ($numIdentifiers, my $newWords) = getIdentifiers($inFilePath);
            $words = "$words $newWords";
        }
        
        # TODO: string literals
    
        if ($options{"doComments"} == 1){
            ($numComments, my $newWords) = getComments($inFilePath);
            $words = "$words $newWords";
        }
    }

    if ($options{"doRemoveEmailAddresses"} == 1){
        $words = removeEmailAddresses($words);
    }

    if ($options{"doRemoveEmailSignatures"} == 1){
        $words = removeEmailSignatures($words);
    }

    if ($options{"doRemoveURLs"} == 1){
        $words = removeURLs($words);
    }

    if ($options{"doRemoveWroteLines"} == 1){
        $words = removeWroteLines($words);
    }

    if ($options{"doRemoveQuotedEmails"} == 1){
        $words = removeQuotedEmails($words);
    }

    if ($options{"doRemoveEmailHeaders"} == 1){
        $words = removeEmailHeaders($words);
    }

    if ($options{"doRemovePunctuation"} == 1){
        $words = removePunctuation($words);
    }

    if ($options{"doTokenize"} == 1){
        $words = tokenize($words);
    }
    
    if ($options{"doRemoveDigits"} == 1){
        $words = removeDigits($words);
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
    
    if ($options{"doStopwordsCustom"} == 1 && @{$options{"ref_stopwordsCustom"}}){
        (my $numRemoved, $words) = removeStopwordsCustom($words, $options{"ref_stopwordsCustom"});
        $numStopwordsRemoved += $numRemoved;
    }
    
    if ($options{"doStemming"} == 1){
        $words = stemWords($words);
    }
    
    if ($options{"doRemoveSmallWords"} == 1){
        ($numSmallWordsRemoved, $words) = removeSmallWords($words, $options{"smallWordSize"});
    }
    
    my $numWords = getNumWords($words);
    return (removeDuplicateSpaces($words), $numWords, $numComments,
                                        $numIdentifiers, $numStopwordsRemoved,
    $numSmallWordsRemoved);

}


=head2 getComments
 Title    : getComments
 Usage    : getComments($fileName)
 Function : Extracts all the comments from source code file $fileName
 Returns  : $number => int, the number of words extracted
          : $wordsOut => string, the extracted words
 Args     : named arguments:
          : $fileName => string, the name of the file to extract from
=cut
sub getComments{
    my $fileName = shift;
    my $wordsIn = "";
    my $numRemoved = 0;

    #$wordsOut = `xscc.awk extract=comment prune=copyright $fileName`;
    $wordsIn = read_file($fileName) ;
    # Find all matches of comments, and put them into @arr
    my @arr = $wordsIn =~  m/$RE{comment}{Java}/g;
    my $wordsOut = join(" ", @arr);

    return (getNumWords($wordsOut), removeDuplicateSpaces($wordsOut));
}


=head2 getIdentifiers
 Title    : getIdentifiers
 Usage    : getIdentifiers($fileName)
 Function : Extracts all the identifier names from source code file $fileName
 Returns  : $number => int, the number of words extracted
          : $wordsOut => string, the extracted words
 Args     : named arguments:
          : $fileName => string, the name of the file to extract from
=cut
sub getIdentifiers{
    my $fileName = shift;
    my $wordsIn = "";

    $wordsIn = read_file($fileName) ;
    # Remove all comments
    # TODO: what about string literals? Don't want to include those here.
    $wordsIn =~ s/$RE{comment}{Java}//g;

    return (getNumWords($wordsIn), $wordsIn);
}

=head2 stem
 Title    : stem
 Usage    : stem($word)
 Function : Applies the Porter stemming algorithm to $word
 Returns  : $word => string, the stemmed word
 Args     : named arguments:
          : $word => string, the word to stem
=cut
sub stem {
    my ($word) = @_;
    my $stemref = Lingua::Stem::stem( $word );
    return $stemref->[0];
}




=head2 removeStopwordsCustom
 Title    : removeStopwordsCustom
 Usage    : removeStopwordsCustom($wordsIn, $ref_stops)
 Function : Removes the stop words in $ref_stops from $wordsIn
 Returns  : $numRemoved => int, the number of stopwords removed
          : $wordsOut => string, the remaining words from $wordsIn
 Args     : named arguments:
          : $wordsIn => string, the white-space delimited words to process
          : $ref_stops => a reference to the array of stop words to remove
=cut
sub removeStopwordsCustom{
    my $wordsIn = shift;
    my $ref_stops = shift;

    my $wordsOut = $wordsIn;
    my $numRemoved = 0;
    foreach my $stop (@{$ref_stops}){
        $wordsOut =~ s/$stop//gs;
    }

    return ($numRemoved, removeDuplicateSpaces($wordsOut));
}


=head2 removeStopwords
 Title    : removeStopwords
 Usage    : removeStopwords($wordsIn, $stops)
 Function : Removes the stop words in $stops from $wordsIn
 Returns  : $numRemoved => int, the number of stopwords removed
          : $wordsOut => string, the remaining words from $wordsIn
 Args     : named arguments:
          : $wordsIn => string, the white-space delimited words to process
          : $stops => a hash table of stop words to remove
=cut
sub removeStopwords{
    my $wordsIn = shift;
    my $stops = shift;

    my $wordsOut = "";
    my $numRemoved = 0;

    # Make sure to lowercase the wordsIn, because the stopwords are themselves
    # lowercase.
    for my $w (split /\s+/, lc($wordsIn)) {
        if (exists($stops->{$w})) {++$numRemoved}
        else {
            $wordsOut = "$wordsOut $w";
        }
    }
    return ($numRemoved, removeDuplicateSpaces($wordsOut));
}


=head2 stemWords
 Title    : stemWords
 Usage    : stemWords($wordsIn)
 Function : Stems all the words in $wordsIn
 Returns  : $wordsOut => string, the stemmed words
 Args     : named arguments:
          : $wordsIn => string, the white-space delimited words to process
=cut
sub stemWords{
    my $wordsIn  = shift;
    my $wordsOut = "";

    for my $w (split /\s+/, $wordsIn) {
        $wordsOut = "$wordsOut ".stem($w);
    }

    return removeDuplicateSpaces($wordsOut);
}


=head2 removePunctuation
 Title    : removePunctuation
 Usage    : removePunctuation($wordsIn)
 Function : Removes all puncuation characters from the words in $wordsIn
 Returns  : $wordsOut => string, the remaining words
 Args     : named arguments:
          : $wordsIn => string, the white-space delimited words to process
=cut
sub removePunctuation{
    my $wordsIn  = shift;
    $wordsIn =~ s/[^[:ascii:]]//g; # remove weird language stuff
    $wordsIn =~ s/[\@\[\]\<\>\.\,\=\/\#\-\+\{\}\!\~\:\;\(\)\\\'\"\?\*\&\%\|]/ /g;
    return removeDuplicateSpaces($wordsIn);
}


=head2 removeDigits
 Title    : removeDigits
 Usage    : removeDigits($wordsIn)
 Function : Removes all digits 0-9 from $wordsIn
 Returns  : $wordsOut => string, the remaining words
 Args     : named arguments:
          : $wordsIn => string, the white-space delimited words to process
=cut
sub removeDigits{
    my $wordsIn  = shift;
    $wordsIn =~ s/[0-9]//g;
    return $wordsIn;
}

=head2 tokenize
 Title    : tokenize
 Usage    : tokenize($wordsIn)
 Function : Splits words based on camelCase, under_scores, and dot.notation.
          : Leaves other words alone.
 Returns  : $wordsOut => string, the tokenized words
 Args     : named arguments:
          : $wordsIn => string, the white-space delimited words to process
=cut
sub tokenize{
    my $wordsIn  = shift;
    my $wordsOut = "";

    for my $w (split /\s+/, $wordsIn) {
        # Split up camel case: aaA ==> aa A
        $w =~ s/([a-z]+)([A-Z])/$1 $2/g;

        # Split up camel case: AAa ==> AA a
        $w =~ s/([A-Z]{2,100})([a-z]+)/$1 $2/g;

        # Split up underscores 
        $w =~ s/_/ /g;

        # Split up dots
        $w =~ s/([a-zA-Z0-9])\.+([a-zA-Z0-9])/$1 $2/g;

        $wordsOut = "$wordsOut $w";
    }

    return removeDuplicateSpaces($wordsOut);
}



=head2 removeSmallWords
 Title    : removeSmallWords
 Usage    : removeSmallWords($wordsIn, $length)
 Function : Removes all words less than or equal to lenght $length
          : Leaves other words alone.
 Returns  : $wordsOut => string, the remaining words
 Args     : named arguments:
          : $wordsIn => string, the white-space delimited words to process
=cut
sub removeSmallWords{
    my $wordsIn  = shift;
    my $length   = shift;
    my $wordsOut = "";

    my $numRemoved = 0;
    for my $w (split /\s+/, $wordsIn) {
        if (length($w) > $length){
            $wordsOut = "$wordsOut $w";
        } else {
            ++$numRemoved;
        }
    }

    return ($numRemoved, removeDuplicateSpaces($wordsOut));
}

=head2 removeDuplicateSpaces
 Title    : removeDuplicateSpaces
 Usage    : removeDuplicateSpaces($wordsIn)
 Function : A helper function to remove duplicate whitespace in $wordsIn
          : Leaves words alone.
 Returns  : $wordsOut => string, the remaining words
 Args     : named arguments:
          : $inWords => string, the white-space delimited words to process
=cut
sub removeDuplicateSpaces{
    my $inWords  = shift;
    $inWords =~ s/\r/ /g;
    $inWords =~ s/\n/ /g;
    $inWords =~ s/\t/ /g;
    $inWords =~ s/  +/ /g;
    $inWords =~ s/^ +//g;
    return $inWords;
}


=head2 getNumWords
 Title    : getNumWords
 Usage    : getNumWords($inWords)
 Function : counts the number of white-space delimited words
 Returns  : $number => int, the number of words 
 Args     : named arguments:
          : $inWords => string, the words to count
=cut
sub getNumWords{
    my $inWords = shift;
    my $num = ($inWords =~ tr/ +//);
    return ++$num;
}


=head2 removeEmailAddresses
 Title    : removeAddresses
 Usage    : removeAddresses($inWords)
 Function : Removes email addresses, e.g., sthomas@cs.queensu.ca
 Returns  : $wordsOut => string, the remaining words 
 Args     : named arguments:
          : $inWords => string, the white-space delimited words to process
=cut
sub removeEmailAddresses{
    my $inWords = shift;
    $inWords =~ s/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}//g;
    return $inWords;
}

=head2 removeEmailSignatures
 Title    : removeSignatures
 Usage    : removeSignatures($inWords)
 Function : Removes email signatures, for example:
          : --
          : Stephen W. Thomas, PhD
          : "My favorite saying goes with every email I send!"
 Returns  : $wordsOut => string, the remaining words 
 Args     : named arguments:
          : $inWords => string, the white-space delimited words to process
=cut
sub removeEmailSignatures{
    my $inWords = shift;
    $inWords =~ s/(>+ )?--\s*\n(.*\n?)*//g;
    return $inWords;
}

=head2 removeURLs
 Title    : removeURLs
 Usage    : removeURLs($inWords)
 Function : Removes URLS, e.g., http://www.something.com
 Returns  : $wordsOut => string, the remaining words 
 Args     : named arguments:
          : $inWords => string, the white-space delimited words to process
=cut
sub removeURLs{
    my $inWords = shift;
    $inWords =~ s|http\://\S+\b||g;
    return $inWords
}

=head2 removeWroteLines
 Title    : removeWroteLines
 Usage    : removeWroteLines($inWords)
 Function : Removes lines that have "On X, Y wrote:" (useful for emails)
 Returns  : $wordsOut => string, the remaining words 
 Args     : named arguments:
          : $inWords => string, the white-space delimited words to process
=cut
sub removeWroteLines{
    my $inWords = shift;
    # Multi-line wrotes
    $inWords =~ s/On.*\n.*wrote://g;
    $inWords =~ s/At.*\n.*wrote://g;

    # Single line wrotes
    $inWords =~ s/On .*wrote://g;
    $inWords =~ s/At .*wrote://g;
    $inWords =~ s/.*wrote://g;
    return $inWords
}

=head2 removeQuotedEmails
 Title    : removeQuotedEmails
 Usage    : removeQuotedEmails($inWords)
 Function : Removes all lines beginning with " *>"
 Returns  : $wordsOut => string, the remaining words 
 Args     : named arguments:
          : $inWords => string, the white-space delimited words to process
=cut
sub removeQuotedEmails{
    my $inWords = shift;
    $inWords =~ s/ *>.*//g;
    return $inWords
}

=head2 removeEmailHeaders
 Title    : removeEmailHeaders
 Usage    : removeEmailHeaders($inWords)
 Function : Removes all email headers that may be in the message
 Returns  : $wordsOut => string, the remaining words 
 Args     : named arguments:
          : $inWords => string, the white-space delimited words to process
=cut
sub removeEmailHeaders{
    my $inWords = shift;
    $inWords =~ s/.*Original Message.*//g;
    $inWords =~ s/^\s*From:.*//mig;
    $inWords =~ s/^\s*Sent:.*//mig;
    $inWords =~ s/^\s*To:.*//mig;
    $inWords =~ s/^\s*Cc:.*//mig;
    $inWords =~ s/^\s*Bcc:.*//mig;
    $inWords =~ s/^\s*Subject:.*//mig;
    # Remove Disclaimers messages
    $inWords =~ s/^\s*DISCLAIMER.*//mig;
    $inWords =~ s/^\s*CAUTION.*//mig;
    return $inWords
}


=head2 buildStopwordTables
 Title    : buildStopwordTables
 Usage    : buildStopwordTables()
 Function : Defines and builds two hash tables of stopwords: one for Enlgish
          : language, and one for programming keywords.
 Returns  : none.
 Args     : named arguments:
          : none.
=cut
sub buildStopwordTables{

    # English list borrowed from MALLET source code file:
    # src/cc/mallet/pipe/TokenSequenceRemoveStopwords.java 
    my @english  = qw( 
    a able about above according accordingly across actually after afterwards
    again against all allow allows almost alone along already also although
    always am among amongst an and another any anybody anyhow anyone anything anyway
    anyways anywhere apart appear appreciate appropriate are around as aside
    ask asking associated at available away awfully b be became because become
    becomes becoming been before beforehand behind being believe below beside besides best
    better between beyond both brief but by c came can cannot cant cause causes certain
    certainly changes clearly co com come comes concerning consequently consider considering
    contain containing contains corresponding could course currently
    d definitely described despite did different do does doing done down downwards
    during e each edu eg eight either else elsewhere enough entirely especially et etc even ever
    every everybody everyone everything everywhere ex exactly example except f far few
    fifth first five followed following follows for former formerly forth four from
    further furthermore g get gets getting given
    gives go goes going gone got gotten greetings h had happens hardly has have
    having he hello help hence her here hereafter hereby herein hereupon hers herself hi him himself
    his hither hopefully how howbeit however i ie if
    ignored immediate in inasmuch inc indeed indicate indicated indicates inner
    insofar instead into inward is it its itself j just k keep keeps kept know knows known l
    last lately later latter latterly least less lest let like liked likely little
    look looking looks ltd m mainly many may maybe me mean meanwhile merely
    might more moreover most mostly much must my myself n name namely nd
    near nearly necessary need needs neither never nevertheless new next nine no
    nobody non none noone nor normally not nothing novel now nowhere o obviously of
    off often oh ok okay old on once one ones only onto or
    other others otherwise ought our ours ourselves out outside over overall own p
    particular particularly per perhaps placed please plus possible presumably probably provides q que
    quite qv r rather rd re really reasonably regarding regardless regards
    relatively respectively right s said same saw say saying says second secondly see seeing seem
    seemed seeming seems seen self selves sensible sent serious seriously seven
    several shall she should since six so some somebody somehow someone something sometime
    sometimes somewhat somewhere soon sorry specified specify specifying still sub such sup sure t take
    taken tell tends th than thank thanks thanx that thats the their theirs
    them themselves then thence there thereafter thereby therefore therein theres
    thereupon these they think third this thorough thoroughly those though three through throughout thru
    thus to together too took toward towards tried tries truly try trying twice two u
    un under unfortunately unless unlikely until unto up upon us use used useful
    uses using usually uucp v value various very via viz vs w want
    wants was way we welcome well went were what whatever when whence whenever
    where whereafter whereas whereby wherein whereupon wherever whether which while
    whither who whoever whole whom whose why will willing wish with within without wonder would would
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
    goto if int long register return short signed sizeof static struct switch typedef union
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

    foreach my $w (@english){
        $stopwordsEnglish{$w} = 1;
    }   
    foreach my $w (@keywords){
        $stopwordsKeywords{$w} = 1;
    }   
}


=head2 getOutName
 Title    : getOutName
 Usage    : getOutName($path, $prefix)
 Function : DEPRECATED. Generates an output path, assuming a specific form of
          :  the input path, i.e., '/one/two/three.txt' => 'one#two.three.txt'
 Returns  : $out => string, the generated output path
 Args     : named arguments:
          : $in => string, the input path (e.g., '/one/two/three.txt')
          : $prefix => string, a prefix to apped to the out path. If empty,
          :   then the extract package name will be prepended.
=cut
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


#############################################################################
#############################################################################
## The remaining functions are all DEPRECATED. I leave them here for backward
## compatibility with old scripts.
#############################################################################
#############################################################################
sub getDiffLDAType{
    my $in = shift;
    my @c  = split(/\./, basename($in));
    return $c[-1];
}
sub getVersionDate{
    my $in = shift;
    my @c  = split(/\#/, basename($in));
    return $c[0];
}
sub removeChangeType{
    my $in = shift;

    $in =~ s/\.add$//g;
    $in =~ s/\.delete$//g;
    $in =~ s/\.change$//g;

    return $in;
}
sub removeDate{
    my $in = shift;

    my @c  = split(/\#/, $in);
    my $bad = $c[0];
    $in =~ s/^$bad\#//g;

    return $in;
}
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
sub getShortName{
    my $in = shift;
    $in =~ s/\#/\//g;
    $in = basename($in);
    return $in;
}
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


1;
__END__


=head1 NAME

lscp - Lightweight source code preprocesser

=head1 SYNOPSIS

  use lscp;
  
  my $preprocessor = lscp->new;

  $preprocessor->setOption("logLevel", "error");
  $preprocessor->setOption("inPath", "t/in/test2");
  $preprocessor->setOption("outPath", "t/out/test2");
  $preprocessor->setOption("isCode", 0);
  $preprocessor->setOption("doTokenize", 0);
  $preprocessor->setOption("doStemming", 1);
  # And any other options you wish to set

  $preprocessor->preprocess();


=head1 DESCRIPTION

lscp is a lightweight source code preprocessor, used to isolate the linguistic data
(i.e., identifier names, comments, and string literals) from source code files.
This is useful, for example, for building IR models on source code. 

lscp was developed with the following goals:

- Speed. We need to process millions of files in no time. We achieve this by:
  - Not parsing the source code. Instead, we rely on heuristics to
    isolate identifier names, comments, and string literals, and discard the rest.
  - Using multiple threads, so that I/O and CPU can be maximized concurrently.
  - Using File::Slurp module for fast I/O times.
 
- Flexibility. We need to support a wide range of preprocessing options and steps. 
  (See below for a full list of supported options.)

- Simplicity. We need the code to be straightforward and easy to extend, because
  we're always changing things.

lscp can also be used to preprocess other document kinds, such as bug reports
and emails. See the options below.

lscp is implemented in Perl, because Perl is well-suited for this sort of task.
Regular expressions, text parsing, reading files? EASY and FAST for the
programmer. Yes, a small performance hit; but we will make that sacrafice for
readable and editible code. 

Here is the list of preprocessing options, and their defaults. These are all set
via the setOptions(optionName, newValue) subroutine.

inPath ==> "./in" 
  The directory containing the input files.

outPath ==> "./out" 
  The directory for the output files.

numberOfThreads ==> 1 
  Number of threads to employ.

logLevel ==> "error"
  The verbosity of the program. 
  Options: "info", "warn", "error", "fatal"

doOutputLogFile ==> 0
  Should the program output a log file of file sizes?

logFilePath ==> ""
  If doOutputLogFile==1, the name of the log file to output

isCode ==> 1
  Are the input files source code (1), or regular text files (0)?

doIdentifiers ==> 1
  If isCode==1, should the program include identifier names?

doStringLiterals ==> 1
  If isCode==1, should the program include string literals?

doComments ==> 1
  If isCode==1, should the program include comments?

doRemoveDigits ==> 0
  Should the program remove digits [0-9]?

doLowerCase ==> 0
  Should the program create all lower case output?

doStemming ==> 0
  Should the program perform word stemming?
  Note that stemming==1 implies doLowerCase==1. 

doTokenize ==> 0
  Should the program split identifier names, such as:
  camelCase, under_scores, dot.notation?

doRemovePunctuation ==> 0
  Should the program remove puncuation symbols?

doRemoveSmallWords ==> 0
  Should the program remove small words?

smallWordSize ==> 1
  If doRemoveSmallWords==1, what is the minumum size of words to keep?

doStopwordsEnglish ==> 0
  Should the program remove English stopwords?

doStopwordsKeywords ==> 0
  Should the program remove programming language keywords?

doStopwordsCustom ==> 0
  Should the program remove a custom stopword list?

ref_stopwordsCustom ==> 0
  If doStopwordsCustom==1, what is the list (array reference). 

doRemoveEmailAddresses ==> 0
  Should the program remove email addresses?

doRemoveEmailSignatures ==> 0
  Should the program remove email signatures?

doRemoveURLs ==> 0
  Should the program remove URLs?

doRemoveWroteLines ==> 0
  Should the program remove "On <date>, <person> wrote:" lines?

doRemoveQuotedEmails ==> 0
  Should the program remove quoted emails?

doRemoveEmailHeaders ==> 0
  Should the program remove email headers?



=head2 EXPORT

None by default.



=head1 SEE ALSO

None.

=head1 AUTHOR

Stephen W. Thomas, <lt>sthomas@cs.queensu.ca<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Stephen W. Thomas

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut

