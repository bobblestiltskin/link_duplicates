#!/usr/bin/perl -w
# 
# reads a serialised hash file  - size, md5sum, [filenames]
# writes a serialised hash file - size, shasum, [filenames]
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
  my $odata = shasum_data($idata);
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
