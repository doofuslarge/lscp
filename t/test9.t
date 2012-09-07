#!/usr/bin/perl

# Tests removing digits

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test9");
$preprocessor->setOption("outPath", "t/out/test9");

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doRemoveDigits", 1);

$preprocessor->preprocess();

compare_ok("t/out/test9/file1.txt", "t/oracle/test9/file1.txt", "file1.txt contents");
