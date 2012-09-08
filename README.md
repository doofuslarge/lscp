lscp version 0.01
=================

AUTHOR
------

[Stephen W. Thomas](http://research.cs.queensu.ca/~sthomas/) <sthomas@cs.queensu.ca> 


DESCRIPTION
-----------

lscp: A lightweight source code preprocesser

lscp can be used to isolate the linguistic data
(i.e., identifier names, comments, and string literals) from source code files.
This is useful, for example, for building IR models on source code.

lscp was developed with the following goals:

* Speed. We need to process millions of files in no time. We achieve this by:
  * Not parsing the source code. Instead, we rely on heuristics to
    isolate identifier names, comments, and string literals, and discard the rest.
  * Using multiple threads, so that I/O and CPU can be maximized concurrently.
  * Using File::Slurp module for fast I/O times.
 
* Flexibility. We need to support a wide range of preprocessing options and steps. 
  (See below for a full list of supported options.)

* Simplicity. We need the code to be straightforward and easy to extend, because
  we're always changing things.

lscp can also be used to preprocess other document kinds, such as bug reports
and emails. See the options below.

lscp is implemented in Perl, because Perl is well-suited for this sort of task.
Regular expressions, text parsing, reading files? EASY and FAST for the
programmer. Yes, a small performance hit; but we will make that sacrafice for
readable and editible code. 

Here is the list of preprocessing options, and their defaults. These are all set
via the `setOptions(optionName, newValue)` subroutine.

    inPath ==> "./in" 
The directory containing the input files.

    outPath ==> "./out" 
The directory for the output files.

    numberOfThreads ==> 1 
Number of threads to employ.

    logLevel ==> "error"
The verbosity of the program. 
Options: `"info"`, `"warn"`, `"error"`, `"fatal"`

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


USAGE
-----

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


(See more usage patterns in the `t` directory.)



INSTALLATION
------------

To install this module type the following:

    perl Makefile.PL
    make
    make test
    make install

Or, if you need to install it to your local directory, type:

    perl Makefile.PL PREFEX /usr/home/USERNAME/usr/local
    make
    make test
    make install

Feel free to modify the functionality in lib/lscp.pm, which we hope you'll find
straightforward. Also, feel free to add additional test cases in the "t"
directory. To do so, perform the following steps.

1. Create a .t script in the ./t directory, with similar structure to an
existing test script.

2. Input files into the `./t/in/testX` directory, which your test will use as
input file to preprocess.

3. Put the desired result of the preprocessing in `./t/oracle/testX` directory.

This way, your script can match the actual output against the desired output to
determine if the test passes or not, using the `Test::Files::compare_ok()` sub.


DEPENDENCIES
------------

This module requires these other modules and libraries:

    File::Basename
    File::Find
    File::Slurp
    Lingua::Stem
    FindBin
    Log::Log4perl qw(:easy)
    Regexp::Common::URI

Easily install these on your system with:

    cpanm Module::Name

COPYRIGHT AND LICENCE
---------------------

Copyright (C) 2012 by Stephen W. Thomas <sthomas@cs.queensu.ca>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


