#!/usr/bin/perl -w
# 
# reads a serialised hash file  - size, inode,  [filenames]
# writes a serialised hash file - size, md5sum, [filenames]
#
use strict;
#
use Unique qw(checksum_files md5sum_data);
#
my ($INFILE, $OUTFILE) = @ARGV;
die "Need serialised hash files to process" unless ($INFILE and $OUTFILE);
#
$| = 1;
Unique::checksum_files(\&Unique::md5sum_data, $INFILE, $OUTFILE);
