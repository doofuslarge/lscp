#!/usr/bin/perl

# Tests "On X, Y wrote:" lines

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test014");
$preprocessor->setOption("outPath", "t/out/test014");

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doRemoveWroteLines", 1);

$preprocessor->preprocess();

compare_ok("t/out/test014/file1.txt", "t/oracle/test014/file1.txt", "file1.txt contents");
