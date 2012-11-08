#!/usr/bin/perl

# Tests removing email addresses

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test013");
$preprocessor->setOption("outPath", "t/out/test013");

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doRemoveEmailAddresses", 1);

$preprocessor->preprocess();

compare_ok("t/out/test013/file1.txt", "t/oracle/test013/file1.txt", "file1.txt contents");
