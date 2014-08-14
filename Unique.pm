package Unique;

use warnings;

BEGIN {
  require Exporter;

  # set the version for version checking
  our $VERSION     = 1.00;

  # Functions and variables which are exported by default
  our @EXPORT_OK   = qw(stat_files checksum_files md5sum_data shasum_data link_files);
}

use strict;
#
use Data::Dumper;
use Data::Serializer;
use Digest::MD5;
use Digest::SHA;
use IO::File;
#
sub stat_files {
  my $infile = shift;
  my $outfile = shift;

  my $ifh = IO::File->new($infile, "r");
  if (defined $ifh) {
    my $obj = Data::Serializer->new();
    my $idata = $obj->retrieve($ifh);
    print Data::Dumper->Dump([$idata]);
    my $odata = stat_data($idata);
    if (defined $odata) {
      print Data::Dumper->Dump([$odata]);
      my $ofh = IO::File->new($outfile, "w");
      if (defined $ifh) {
        $obj->store($odata, $ofh);
        undef $ofh;
      }
    }
    undef $ifh;
  }
}
#  
sub stat_data {
  my $idata = shift;

  my $odata;
  while (my ($k, $v) = each $idata) {
    if (@$v > 1) {
      print "processing ",$k, "\n";
      foreach my $file (@$v) {
        my $inode = (stat($file))[1];
        print "FILE is ", $file, "INODE - $inode\n";
 
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
#
sub checksum_files {
  my $function = shift;
  my $infile = shift;
  my $outfile = shift;

  my $ifh = IO::File->new($infile, "r");
  if (defined $ifh) {
    my $obj = Data::Serializer->new;
    my $idata = $obj->retrieve($ifh);
    print Data::Dumper->Dump([$idata]);
    my $odata = $function->($idata);
    if (defined $odata) {
      print Data::Dumper->Dump([$odata]);
      my $ofh = IO::File->new($outfile, "w");
      if (defined $ifh) {
        $obj->store($odata, $ofh);
        undef $ofh;
      }
    }
    undef $ifh;
  }
}
#
sub md5sum_data {
  my $idata = shift;

  my $odata;
  while (my ($k, $v) = each $idata) {
    if ((keys %$v) > 1) {
      while (my ($inode, $files) = each $v) {
        my $file = $files->[0];
        open (my $fh, '<', $file) or die "Can't open '$file': $!";
        binmode ($fh);
        my $checksum = Digest::MD5->new->addfile($fh)->hexdigest;
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
#
sub link_all {
# 
# reads a serialised hash file - size, csum, [filenames]
#
  my $infile = shift;

  my $ifh = IO::File->new($infile, "r");
  if (defined $ifh) {
    my $obj = Data::Serializer->new();
    my $idata = $obj->retrieve($ifh);
    print Data::Dumper->Dump([$idata]);
    link_files($idata);
    undef $ifh;
  }
}
#
sub link_files {
  my $idata = shift;

  my $odata;
  while (my ($checksum, $files) = each $idata) {
    if (@$files == 1) {
      print "Nothing to do for ",$files->[0],"\n";
    } else {
      my $root = $files->[0];
      for my $idx (1 .. $#$files) {
        my $file = $files->[$idx];
        print "LINKING ",$file," to $root with checksum $checksum\n";
        unlink $file and link $root, $file;
      }
    }
  }
  return $odata;
}

1;
