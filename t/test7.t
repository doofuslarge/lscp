#!/usr/bin/perl

# Tests custom stopword list

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test7");
$preprocessor->setOption("outPath", "t/out/test7");

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doLowerCase", 1);
$preprocessor->setOption("doStopwordsCustom", 1);

my @stopphrases = ("hello world", "coca cola", "cat cat cat", "downtown city lights");
$preprocessor->setOption("ref_stopwordsCustom", \@stopphrases);

$preprocessor->preprocess();

compare_ok("t/out/test7/file1.txt", "t/oracle/test7/file1.txt", "file1.txt contents");
