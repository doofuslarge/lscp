#!/usr/bin/perl

# Tests tokenizing capability

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test3");
$preprocessor->setOption("outPath", "t/out/test3");
$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doTokenize", 1);
$preprocessor->setOption("doStemming", 0);
$preprocessor->setOption("doLowerCase", 0);
$preprocessor->setOption("doStopwordsEnglish", 0);
$preprocessor->setOption("doStopwordsKeywords", 0);
$preprocessor->setOption("doStopwordsCustom", 0);
$preprocessor->setOption("doStopPhrases", 0);
$preprocessor->setOption("doEmail", 0);

$preprocessor->preprocess();

compare_ok("t/out/test3/file1.txt", "t/oracle/test3/file1.txt", "file1.txt contents");
