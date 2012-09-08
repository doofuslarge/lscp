#!/usr/bin/perl

# Tests removing email addresses

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test13");
$preprocessor->setOption("outPath", "t/out/test13");

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doRemoveEmailAddresses", 1);

$preprocessor->preprocess();

compare_ok("t/out/test13/file1.txt", "t/oracle/test13/file1.txt", "file1.txt contents");
