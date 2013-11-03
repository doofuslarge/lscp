#!/usr/bin/perl

use warnings;
use strict;
use lscp;
use Test::More tests => 1;
use Test::Files;

my $preprocessor = lscp->new;

$preprocessor->setOption("logLevel", "error");
$preprocessor->setOption("inPath", "t/in/test025/posts.csv");
$preprocessor->setOption("outPath", "t/out/test025/posts_pre.csv");
$preprocessor->setOption("oneInputFile", 1);
$preprocessor->setOption("oneOutputFile", 1);
$preprocessor->setOption("doOutputOneWordPerLine", 0);

$preprocessor->setOption("isCode", 0);
$preprocessor->setOption("doTokenize", 0);
$preprocessor->setOption("doStemming", 1);
$preprocessor->setOption("doRemoveDigits", 1);
$preprocessor->setOption("doLowerCase", 1);
$preprocessor->setOption("doRemovePunctuation", 1);
$preprocessor->setOption("doRemoveSmallWords", 1);
$preprocessor->setOption("doStopwordsEnglish", 1);
$preprocessor->setOption("doRemoveURLs", 1);
$preprocessor->setOption("doRemoveCodeTags", 1);
$preprocessor->setOption("doRemoveHTMLTags", 1);
$preprocessor->setOption("doExpandContractions", 1);
$preprocessor->setOption("doOutputOneWordPerLine", 0);


$preprocessor->preprocess();

compare_ok("t/out/test025/posts_pre.csv", "t/oracle/test025/posts_pre.csv", "posts_pre.csv contents");
