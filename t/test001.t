#!/usr/bin/perl

# Tests comment extraction

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test001");
$preprocessor->setOption("outPath", "t/out/test001");

$preprocessor->setOption("isCode", 1);
$preprocessor->setOption("doIdentifiers", 0);
$preprocessor->setOption("doStringLiterals", 0);
$preprocessor->setOption("doComments", 1);
$preprocessor->setOption("doTokenize", 0);
$preprocessor->setOption("doStemming", 0);
$preprocessor->setOption("doRemoveDigits", 0);
$preprocessor->setOption("doRemovePunctuation", 1);
$preprocessor->setOption("doLowerCase", 0);
$preprocessor->setOption("doStopwordsKeywords", 0);

$preprocessor->preprocess();

compare_ok("t/out/test001/file1.java", "t/oracle/test001/file1.java", "file1.java contents");
