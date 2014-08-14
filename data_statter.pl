#!/usr/bin/perl -w
# 
# takes a serialised hash file of size v filenames
#
# filters out single filenames and further hashes by inode
#
use strict;
#
use Unique qw(stat_files);
#
my ($INFILE, $OUTFILE) = @ARGV;
die "Need serialised hash files to process" unless ($INFILE and $OUTFILE);
#
$| = 1;
Unique::stat_files($INFILE, $OUTFILE);
