#!/usr/bin/perl -w
# 
# reads a serialised hash file - size, csum, [filenames]
#
use strict;
#
use Data::Dumper;
use Data::Serializer;
use IO::File;
use Unique;
#
my $INFILE = shift;
die "Need serialised hash files to process" unless $INFILE;
#
$| = 1;
#
my $ifh = IO::File->new($INFILE, "r");
if (defined $ifh) {
  my $obj = Data::Serializer->new();
  my $idata = $obj->retrieve($ifh);
  print Data::Dumper->Dump([$idata]);
  link_files($idata);
  undef $ifh;
}
