lscp version 0.01
=================

AUTHOR

    Stephen W. Thomas <sthomas@cs.queensu.ca> 


DESCRIPTION

lscp: A lightweight source code preprocesser

lscp can be used to isolate the linguistic data
(i.e., identifier names, comments, and string literals) from source code files,
which is useful for building IR models on source code. 

lscp was developed with the following goals:

- Speed. It does not parse the source code. Instead, it relies on heuristics to
  isolate identifier names, comments, and string literals, and discard the rest.
  Further, it can run in a multi-threaded mode to increase throughput. 

- Flexibility. It can support a range of preprocessing options and steps. (See below.)

- Simplicity. The code is straightforward and hence easy to extend.

lscp can also be used to preprocess other document kinds, such as bug reports
and emails. 

List of options, and their defaults:

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

doComments ==> 1
  If isCode==1, should the program include comments?

doRemoveDigits ==> 1
  Should the program remove digits [0-9]?

doLowerCase ==> 1
  Should the program create all lower case output?

doStemming ==> 1
  Should the program perform word stemming?
  Note that stemming==1 implies doLowerCase==1. 

doTokenize ==> 1
  Should the program split identifier names, such as:
  camelCase, under_scores, dot.notation?

doRemoveSmallWords ==> 0
  Should the program remove small words?

smallWordSize ==> 1
  If doRemoveSmallWords==1, what is the minumum size of words to keep?

doStopwordsEnglish ==> 1
  Should the program remove English stopwords?

doStopwordsKeywords ==> 1
  Should the program remove programming language keywords?

doStopwordsCustom ==> 0
  Should the program remove a custom stopword list?

ref_stopwordsCustom ==> 0
  If doStopwordsCustom==1, what is the list (array reference). 

doEmail ==> 0
  Should the program remove common noise in emails?


USAGE

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


  (See more usage patterns in the "t" directory.)



INSTALLATION

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

DEPENDENCIES

This module requires these other modules and libraries:

  File::Basename
  File::Find
  File::Slurp
  Lingua::Stem
  FindBin
  Log::Log4perl qw(:easy)
  Regexp::Common::URI

COPYRIGHT AND LICENCE

Copyright (C) 2012 by Stephen W. Thomas <sthomas@cs.queensu.ca>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


