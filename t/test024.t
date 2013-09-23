#!/usr/bin/perl

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test024");
$preprocessor->setOption("outPath", "t/out/test024");

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doOutputOneWordPerLine", 0);

$preprocessor->preprocess();

compare_ok("t/out/test024/file1.txt", "t/oracle/test024/file1.txt", "file1.txt contents");
