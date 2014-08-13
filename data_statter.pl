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
  print Data::Dumper->Dump([$odata]);
  my $ofh = IO::File->new($OUTFILE, "w");
  if (defined $ifh) {
    $obj->store($odata, $ofh);
    undef $ofh;
  }
  undef $ifh;
}
#
sub stat_data {
  my $idata = shift;
  my $odata;
  while (my ($k, $v) = each $idata) {
    if (@$v > 1) {
      print "processing ",$k, "\n";
      foreach my $file (@$v) {
        print "FILE is ", $file,"\n";
        my $inode = (stat($file))[1];
        print "INODE - $inode\n";
 
        if (defined $odata->{$k}->{$inode}) {
          push @{$odata->{$k}->{$inode}}, $file;
        } else {
          $odata->{$k}->{$inode} = [ $file ];
        }
      }
    }
  }
  return $odata;
}
