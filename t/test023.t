#!/usr/bin/perl

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test023");
$preprocessor->setOption("outPath", "t/out/test023");

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doRemoveCodeTags", 1);
$preprocessor->setOption("doRemoveHTMLTags", 1);

$preprocessor->preprocess();

compare_ok("t/out/test023/file1.txt", "t/oracle/test023/file1.txt", "file1.txt contents");
