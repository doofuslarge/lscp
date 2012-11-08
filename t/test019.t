#!/usr/bin/perl

# Tests file extensions

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;
use File::Spec;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test019");
$preprocessor->setOption("outPath", "t/out/test019");

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("fileExtensions", "java txt");

$preprocessor->preprocess();

# Just make sure the right files are present in the output dir
my $dir = File::Spec->catdir ( 't', 'out', 'test019');
dir_only_contains_ok($dir, [qw(file1.txt file2.java)], "directory contents ok.");
