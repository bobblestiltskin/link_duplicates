#!/usr/bin/perl -w
# 
# reads a serialised hash file - size, csum, [filenames]
#
use strict;
#
use Unique qw(link_all);
#
my ($INFILE) = @ARGV;
die "Need serialised hash files to process" unless $INFILE;
#
$| = 1;
Unique::link_all($INFILE);
