#!/usr/bin/perl

# Tests stopwords, and case preservation

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test017");
$preprocessor->setOption("outPath", "t/out/test017");

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doStopwordsEnglish", 1);
$preprocessor->setOption("doLowerCase", 0);

$preprocessor->preprocess();

compare_ok("t/out/test017/file1.txt", "t/oracle/test017/file1.txt", "file1.txt contents");
