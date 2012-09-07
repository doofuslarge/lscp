#!/usr/bin/perl

# Tests stopword removal

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test4");
$preprocessor->setOption("outPath", "t/out/test4");
$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doTokenize", 0);
$preprocessor->setOption("doStemming", 0);
$preprocessor->setOption("doLowerCase", 0);
$preprocessor->setOption("doStopwordsEnglish", 1);
$preprocessor->setOption("doStopwordsKeywords", 0);
$preprocessor->setOption("doStopwordsCustom", 0);
$preprocessor->setOption("doStopPhrases", 0);
$preprocessor->setOption("doEmailReply", 0);

$preprocessor->preprocess();

compare_ok("t/out/test4/file1.txt", "t/oracle/test4/file1.txt", "file1.txt contents");
