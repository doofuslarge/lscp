#!/usr/bin/perl

# Tests stemming capability

use warnings;
use strict;
use lscp;
use Test::More tests => 2;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test002");
$preprocessor->setOption("outPath", "t/out/test002");
$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doStemming", 1);

$preprocessor->preprocess();

compare_ok("t/out/test002/file1.txt", "t/oracle/test002/file1.txt", "file1.txt contents");
compare_ok("t/out/test002/file2.txt", "t/oracle/test002/file2.txt", "file2.txt contents");

