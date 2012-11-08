#!/usr/bin/perl

# Tests keyword removal

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test005");
$preprocessor->setOption("outPath", "t/out/test005");
$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doStopwordsKeywords", 1);

$preprocessor->preprocess();

compare_ok("t/out/test005/file1.txt", "t/oracle/test005/file1.txt", "file1.txt contents");
