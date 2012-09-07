#!/usr/bin/perl

# Tests email replies

use warnings;
use strict;
use lscp;
use Test::More tests => 4;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test8");
$preprocessor->setOption("outPath", "t/out/test8");

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doTokenize", 0);
$preprocessor->setOption("doStemming", 0);
$preprocessor->setOption("doLowerCase", 0);
$preprocessor->setOption("doStopwordsEnglish", 0);
$preprocessor->setOption("doStopwordsKeywords", 0);
$preprocessor->setOption("doStopwordsCustom", 0);
$preprocessor->setOption("doEmail", 1);

$preprocessor->preprocess();

compare_ok("t/out/test8/file1.txt", "t/oracle/test8/file1.txt", "file1.txt contents");
compare_ok("t/out/test8/file2.txt", "t/oracle/test8/file2.txt", "file2.txt contents");
compare_ok("t/out/test8/file3.txt", "t/oracle/test8/file3.txt", "file3.txt contents");
compare_ok("t/out/test8/file4.txt", "t/oracle/test8/file4.txt", "file4.txt contents");
