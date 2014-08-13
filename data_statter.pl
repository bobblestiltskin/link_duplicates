#!/usr/bin/perl -w
# 
# takes a serialised hash file of size v filenames
#
# filters out single filenames and further hashes by inode
#
use strict;
#
use Data::Dumper;
use Data::Serializer;
use IO::File;
use Unique;
#
my $INFILE = shift;
my $OUTFILE = shift;
die "Need serialised hash files to process" unless ($INFILE and $OUTFILE);
#
$| = 1;
#
my $ifh = IO::File->new($INFILE, "r");
if (defined $ifh) {
  my $obj = Data::Serializer->new();
  my $idata = $obj->retrieve($ifh);
  print Data::Dumper->Dump([$idata]);
  my $odata = stat_data($idata);
  if (defined $odata) {
    print Data::Dumper->Dump([$odata]);
    my $ofh = IO::File->new($OUTFILE, "w");
    if (defined $ifh) {
      $obj->store($odata, $ofh);
      undef $ofh;
    }
  }
  undef $ifh;
}
