package Unique;

use warnings;

BEGIN {
  require Exporter;

  # set the version for version checking
  our $VERSION     = 1.00;

  # Functions and variables which are exported by default
  our @EXPORT      = qw(stat_data md5sum_data shasum_data link_files);
}

use strict;
#
use Data::Serializer;
use Digest::MD5;
use Digest::SHA;
use IO::File;
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
        print "CHECKSUM ", $checksum,"\n";
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

1;
