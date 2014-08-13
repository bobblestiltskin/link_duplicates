#!/usr/bin/perl -w
# 
# reads a serialised hash file - size, inode, [filenames]
# writes a serialised hash file - size, csum, [filenames]
#
use strict;
#
use Data::Dumper;
use Data::Serializer;
use Digest::MD5;
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
  my $data = $obj->retrieve($ifh);
  print Data::Dumper->Dump([$data]);
  my $csum_data = md5sum_data($data);
  print Data::Dumper->Dump([$csum_data]);
  my $ofh = IO::File->new($OUTFILE, "w");
  if (defined $ifh) {
    $obj->store($csum_data, $ofh);
    undef $ofh;
  }
  undef $ifh;
}
#
sub md5sum_data {
  my $idata = shift;
  my $odata;
  while (my ($k, $v) = each $idata) {
    while (my ($inode, $files) = each $v) {
      my $file = $files->[0];
      open (my $fh, '<', $file) or die "Can't open '$file': $!";
      binmode ($fh);
      my $checksum = Digest::MD5->new->addfile($fh)->hexdigest;
      print "CHECKSUM ", $checksum,"\n";
      close ($fh) or die "Can't close $file: $!";

      if (defined $odata->{$k}->{$checksum}) {
        push @{$odata->{$k}->{$checksum}}, $file;
      } else {
        $odata->{$k}->{$checksum} = [ $file ];
      }
    }
  }
  return $odata;
}
