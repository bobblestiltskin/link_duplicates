#!/usr/bin/perl -w
# 
# takes a minimum size in bytes, an output filename and a list of directories to process
#
# creates a hash of file size vs list of files of that size and serialises to output file
#
use strict;
#
use Data::Serializer;
use File::Find;
use IO::File;
#  
my $MINSIZE = shift;
my $OUTFILE = shift;
die "Need a minsize, an output file name and some directories to process" unless (($MINSIZE =~ /\d+/) and @ARGV);
#
$| = 1;
my $data;
find(\&wanted, @ARGV);
#
my $obj = Data::Serializer->new();
my $ofh = IO::File->new($OUTFILE, "w");
if (defined $ofh) {
  $obj->store($data, $ofh);
  undef $ofh;
}
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
