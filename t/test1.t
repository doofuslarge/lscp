#!/usr/bin/perl

# Basic test to make sure everything is running correctly.

use warnings;
use strict;
use lscp;
use Test::More tests => 2;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test1");
$preprocessor->setOption("outPath", "t/out/test1");

$preprocessor->setOption("isCode", 1);
$preprocessor->setOption("doTokenize", 0);
$preprocessor->setOption("doStemming", 0);
$preprocessor->setOption("doLowerCase", 1);
$preprocessor->setOption("doStopwordsEnglish", 0);
$preprocessor->setOption("doStopwordsKeywords", 1);
$preprocessor->setOption("doStopwordsCustom", 0);
$preprocessor->setOption("doStopPhrases", 0);
$preprocessor->setOption("doEmailReply", 0);

$preprocessor->preprocess();

compare_ok("t/out/test1/file1.java", "t/oracle/test1/file1.java", "file1.java contents");
compare_ok("t/out/test1/file2.java", "t/oracle/test1/file2.java", "file2.java contents");
