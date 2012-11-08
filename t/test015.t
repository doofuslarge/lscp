#!/usr/bin/perl

# Tests quoted emails

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test015");
$preprocessor->setOption("outPath", "t/out/test015");

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doRemoveQuotedEmails", 1);

$preprocessor->preprocess();

compare_ok("t/out/test015/file1.txt", "t/oracle/test015/file1.txt", "file1.txt contents");
