#!/usr/bin/perl

# Tests removing small words

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test10");
$preprocessor->setOption("outPath", "t/out/test10");

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doRemoveSmallWords", 1);
$preprocessor->setOption("smallWordSize", 4);

$preprocessor->preprocess();

compare_ok("t/out/test10/file1.txt", "t/oracle/test10/file1.txt", "file1.txt contents");
