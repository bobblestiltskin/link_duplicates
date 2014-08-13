#!/usr/bin/perl -w
# 
# reads a serialised hash file - size, csum, [filenames]
#
use strict;
#
use Data::Dumper;
use Data::Serializer;
use IO::File;
#
my $INFILE = shift;
die "Need serialised hash files to process" unless $INFILE;
#
$| = 1;
#
my $ifh = IO::File->new($INFILE, "r");
if (defined $ifh) {
  my $obj = Data::Serializer->new();
  my $data = $obj->retrieve($ifh);
  print Data::Dumper->Dump([$data]);
  my $csum_data = link_files($data);
  undef $ifh;
}
#
sub link_files {
  my $idata = shift;
  my $odata;
  while (my ($csum, $files) = each $idata) {
    if (@$files == 1) {
      print "Nothing to do for ",$files->[0],"\n";
    } else {
      my $root = $files->[0];
      for my $idx (1 .. $#$files) {
        my $file = $files->[$idx];
        print "LINKING ",$file," to $root with checksum $csum\n";
        unlink $file and link $root, $file;
      }
    }
  }
  return $odata;
}
