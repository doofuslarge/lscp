#!/usr/bin/perl

# Tests removing URLs

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test012");
$preprocessor->setOption("outPath", "t/out/test012");

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doRemoveURLs", 1);

$preprocessor->preprocess();

compare_ok("t/out/test012/file1.txt", "t/oracle/test012/file1.txt", "file1.txt contents");
