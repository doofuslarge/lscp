#!/usr/bin/perl

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test021");
$preprocessor->setOption("outPath", "t/out/test021");

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doRemoveCodeTags", 1);

$preprocessor->preprocess();

compare_ok("t/out/test021/file1.txt", "t/oracle/test021/file1.txt", "file1.txt contents");
