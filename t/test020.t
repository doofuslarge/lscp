#!/usr/bin/perl

# Tests comment extraction

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test020");
$preprocessor->setOption("outPath", "t/out/test020");

$preprocessor->setOption("isCode", 1);
$preprocessor->setOption("doIdentifiers", 1);
$preprocessor->setOption("doStringLiterals", 0);
$preprocessor->setOption("doComments", 0);
$preprocessor->setOption("doTokenize", 1);
$preprocessor->setOption("doStemming", 0);
$preprocessor->setOption("doRemoveSmallWords", 0);
$preprocessor->setOption("doStopwordsEnglish", 0);
$preprocessor->setOption("doRemoveDigits", 1);
$preprocessor->setOption("doRemovePunctuation", 1);
$preprocessor->setOption("doLowerCase", 1);
$preprocessor->setOption("doStopwordsKeywords", 1);

$preprocessor->preprocess();

compare_ok("t/out/test020/file1.java", "t/oracle/test020/file1.java", "file1.java contents");
