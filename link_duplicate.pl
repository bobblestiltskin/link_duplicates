#!/usr/bin/perl -w
# 
# takes a minimum size in bytes, an output filename and a list of directories to process
#
# creates a hash of file size vs list of files of that size and serialises to output file
#
use strict;
use warnings;
#
use Data::Dumper;
use Data::Serializer;
use Digest::MD5;
use Digest::SHA;
use File::Find;
use File::Temp qw/ :seekable /;
use Getopt::Long;
use IO::File;
#  
my ($MINSIZE, $verbose);
my $getopt_result = GetOptions (
  'size=i' => \$MINSIZE,
#  'track_regexp=s' => \$track_regexp,
  'verbose' => \$verbose,
);
die "Bad Parameter passed to $0" unless ($getopt_result);
#
my $find_fh = File::Temp->new(UNLINK => 0, SUFFIX => '.find.dat' );
###my $fn = "/tmp/find.dat";
###my $find_fh = IO::File->new($fn, "w+");
#print "Find Filename is ",$find_fh->filename,"\n";
die "Need a minsize and some directories to process" unless (($MINSIZE =~ /\d+/) and @ARGV);
#
$| = 1;
my $data;
find(\&wanted, @ARGV);
print Data::Dumper->Dump([$data]);
#
my $serializer = Data::Serializer->new;
$serializer->store($data, $find_fh);
###close $find_fh;
###$find_fh = IO::File->new($fn, "r");
$find_fh->seek(0, SEEK_SET);
print "can see ",Data::Dumper->Dump([$serializer->retrieve($find_fh)]);
$find_fh->seek(0, SEEK_SET);
#print "Find Filename is ",$find_fh->filename,"\n";
#
my $stat_fh = File::Temp->new(UNLINK => 0, SUFFIX => '.stat.dat' );
print "Stat Filename is ",$stat_fh->filename,"\n";
#$data = stat_files($find_fh, $stat_fh);
stat_files($find_fh, $stat_fh);
$stat_fh->seek(0, SEEK_SET);
#
my $md5_fh = File::Temp->new(UNLINK => 0, SUFFIX => '.md5.dat' );
checksum_data(\&md5sum_data, $stat_fh, $md5_fh);
$md5_fh->seek(0, SEEK_SET);
##
my $sha_fh = File::Temp->new(UNLINK => 0, SUFFIX => '.sha.dat' );
checksum_data(\&shasum_data, $md5_fh, $sha_fh);
$sha_fh->seek(0, SEEK_SET);
##
link_all($sha_fh);
#
sub wanted {
  return unless (-f $File::Find::name);
  my $size = (stat($File::Find::name))[7];
  if ($size >= $MINSIZE) {
    print "--FILE is $File::Find::name and SIZE is $size\n";
    if (defined $data->{$size}) {
      push @{$data->{$size}}, $File::Find::name;
    } else {
      $data->{$size} = [ $File::Find::name ];
    }
  }
}
#
sub stat_files {
# 
# reads a serialised hash file  - size,        [filenames]
# writes a serialised hash file - size, inode, [filenames]
#
  my $ifh = shift;
  my $ofh = shift;

  my $odata;
  if (defined $ifh) {
    my $obj = Data::Serializer->new();
    my $idata = $obj->retrieve($ifh);
    print "stat files data is ",Data::Dumper->Dump([$idata]);
    my $odata = stat_data($idata);
#    $odata = stat_data($idata);
    if (defined $odata) {
      print Data::Dumper->Dump([$odata]);
      if (defined $ifh) {
        $obj->store($odata, $ofh);
      }
    }
  }
#  return $odata;
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
sub checksum_data {
  my $function = shift;
  my $ifh = shift;
  my $ofh = shift;

  if (defined $ifh) {
    my $obj = Data::Serializer->new;
    my $idata = $obj->retrieve($ifh);
    print Data::Dumper->Dump([$idata]);
    my $odata = $function->($idata);
    if ((defined $ofh) and (defined $odata)) {
      $obj->store($odata, $ofh);
    }
  }
}
#
sub md5sum_data {
# 
# reads a serialised hash file  - size, inode,  [filenames]
# writes a serialised hash file - size, md5sum, [filenames]
#
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
# 
# reads a serialised hash file  - size, md5sum, [filenames]
# writes a serialised hash file - size, shasum, [filenames]
#
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
  my $ifh = shift;

  if (defined $ifh) {
    my $obj = Data::Serializer->new();
    my $idata = $obj->retrieve($ifh);
    print Data::Dumper->Dump([$idata]);
    link_files($idata);
  }
}
#
sub link_files {
# 
# reads a serialised hash file - size, csum, [filenames]
#
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
