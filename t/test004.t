#!/usr/bin/perl

# Tests stopword removal

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test004");
$preprocessor->setOption("outPath", "t/out/test004");
$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doTokenize", 0);
$preprocessor->setOption("doStemming", 0);
$preprocessor->setOption("doRemovePunctuation", 1);
$preprocessor->setOption("doRemoveDigits", 1);
$preprocessor->setOption("doStopwordsEnglish", 1);
$preprocessor->setOption("doLowerCase", 1);

$preprocessor->preprocess();

compare_ok("t/out/test004/file1.txt", "t/oracle/test004/file1.txt", "file1.txt contents");
