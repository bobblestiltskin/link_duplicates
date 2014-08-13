#!/usr/bin/perl -w
# 
# reads a serialised hash file - size, md5sum, [filenames]
# writes a serialised hash file - size, shasum, [filenames]
#
use strict;
#
use Data::Dumper;
use Data::Serializer;
use Digest::SHA;
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
  my $csum_data = shasum_data($data);
  if (defined $csum_data) {
    print Data::Dumper->Dump([$csum_data]);
    my $ofh = IO::File->new($OUTFILE, "w");
    if (defined $ifh) {
      $obj->store($csum_data, $ofh);
      undef $ofh;
    }
  }
  undef $ifh;
}
#
sub shasum_data {
  my $idata = shift;
  my $odata;
  while (my ($md5sum, $files) = each $idata) {
    if (@$files > 1) {
      foreach my $file (@$files) {
        open (my $fh, '<', $file) or die "Can't open '$file': $!";
        binmode ($fh);
        my $checksum = Digest::SHA->new(512)->addfile($fh)->hexdigest;
        print "FILE : ",$file," : CHECKSUM : ", $checksum,"\n";
        close ($fh) or die "Can't close $file: $!";

        if (defined $odata->{$checksum}) {
          push @{$odata->{$checksum}}, $file;
        } else {
          $odata->{$checksum} = [ $file ];
        }
      }
    }
  }
  return $odata;
}
