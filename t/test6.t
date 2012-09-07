#!/usr/bin/perl

# Tests threading. This test is the same as test 1, except with two threads

use warnings;
use strict;
use lscp;
use Test::More tests => 2;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test6");
$preprocessor->setOption("outPath", "t/out/test6");

$preprocessor->setOption("numberOfThreads", 2);
$preprocessor->setOption("isCode", 1);
$preprocessor->setOption("doTokenize", 0);
$preprocessor->setOption("doStemming", 0);
$preprocessor->setOption("doLowerCase", 1);
$preprocessor->setOption("doStopwordsEnglish", 0);
$preprocessor->setOption("doStopwordsKeywords", 1);
$preprocessor->setOption("doStopwordsCustom", 0);
$preprocessor->setOption("doStopPhrases", 0);
$preprocessor->setOption("doEmail", 0);

$preprocessor->preprocess();

compare_ok("t/out/test6/file1.java", "t/oracle/test6/file1.java", "file1.java contents");
compare_ok("t/out/test6/file2.java", "t/oracle/test6/file2.java", "file2.java contents");
