#!/usr/bin/perl -w
# 
# reads a serialised hash file  - size, md5sum, [filenames]
# writes a serialised hash file - size, shasum, [filenames]
#
use strict;
#
use Unique qw(checksum_files shasum_data);
#
my ($INFILE, $OUTFILE) = @ARGV;
die "Need serialised hash files to process" unless ($INFILE and $OUTFILE);
#
$| = 1;
Unique::checksum_files(\&Unique::shasum_data, $INFILE, $OUTFILE);
