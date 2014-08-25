#!/usr/bin/perl -w

=pod

=head1 NAME

link_duplicate.pl - reduce used disk space by determining duplicates and hard-linking

=head1 SYNOPSIS

link_duplicate.pl [options] [paths ...]

link_duplicate.pl --minsize 50 /path/to/dir1 /path/to/dir2

This form is used to specify any minimum file size within the given sub-trees.

link_duplicate.pl [options] [0-9] [paths ...]

This form will used 10**[0-9] as the minimum file size to consider in the path.

Options:
  --minsize      minimum file size to process
  --maxsize   maximum file size to process
  --verbose   give once for some output, twice for more
  --keep      keep the intermediate files (suffix .dat in /tmp by default).
  --file      a pre-computed file of serialised size, inode, [files]
  --link      link duplicates
  --sha       use shasum after md5sum (belt and braces approach due to md5 collisions)
  --shasize   size of sha digest (defaults to 512).

=cut

use strict;
use warnings;

use Data::Dumper;
use Data::Serializer;
use Digest::MD5;
use Digest::SHA;
use File::Find;
use File::Temp qw/ :seekable /;
use Getopt::Long;
use IO::File;
use Pod::Usage;

my $MINSIZE; # capitalise since we use it in the File::Find wanted sub
my $MAXSIZE; # capitalise since we use it in the File::Find wanted sub
my $help = 0;
my $man = 0;
my $keep = 0;
my $file;
my $link = 1;
my $verbose = 0;
my $debug = 0;
my $sha = 1;
my $shasize = 512;
my $getopt_result = GetOptions (
  'minsize=i' => \$MINSIZE,
  'maxsize=i' => \$MAXSIZE,
  'shasize=i' => \$shasize,
  'verbose+'  => \$verbose,
  'debug+'    => \$debug,
  'keep!'     => \$keep,
  'file=s'    => \$file,
  'link!'     => \$link,
  'sha!'      => \$sha,
  'help|?'    => \$help,
  'man'       => \$man,
);
die "Bad Parameter passed to $0" unless ($getopt_result);

pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

$| = 1;
my $DATA;
my $find_fh;
if (defined $file) {
  $find_fh = IO::File->new($file,"r") or die "Can't open $file, $!";
  $DATA = Data::Serializer->new->retrieve($find_fh);
} else {
  die "Need some directories to process" unless @ARGV;
  $MINSIZE = (10 ** shift) if (not defined $MINSIZE) and ($ARGV[0] =~ /^\d$/);
  die "Need a minimum file size" unless defined $MINSIZE;
  die "Need a minimum file size and some directories to process" unless (($MINSIZE =~ /\d+/) and @ARGV);

  print "*** Finding location of files\n";
  print "*** MINSIZE is $MINSIZE\n";
  print "*** MAXSIZE is $MAXSIZE\n" if (defined $MAXSIZE);
  find({wanted => \&process_files, follow => 0}, @ARGV);
  if (($keep or not $link) and defined $DATA) {
    $find_fh = File::Temp->new(UNLINK => !$keep, SUFFIX => '.find.dat' );
    Data::Serializer->new->store($DATA, $find_fh);
    $find_fh->seek(0, SEEK_SET);
  }
}

if ($link and defined $DATA) {
  print Data::Dumper->Dump([$DATA]) if $debug;
  print "*** Calculating md5sum of files\n";
  checksum_and_link($DATA, $verbose, $sha, $shasize);
}
#
sub process_files {
  return if (-l $File::Find::name);
  return unless (-f $File::Find::name);
  my @stat_data = stat($File::Find::name);
  my $size = $stat_data[7];
  if ($size >= $MINSIZE) {
    if ((not defined $MAXSIZE) or ($size < $MAXSIZE)) {
      my $inode = $stat_data[1];
      print "wanted: file - $File::Find::name, size - $size, inode - $inode\n" if $verbose;
      if (defined $DATA->{$size}->{$inode}) {
        push @{$DATA->{$size}->{$inode}}, $File::Find::name;
      } else {
        $DATA->{$size}->{$inode} = [ $File::Find::name ];
      }
    }
  }
}
#
sub checksum_file {
  my ($file, $label, $algorithm, $verbose) = @_;

  print "$label: file - ",$file if $verbose;
  open (my $fh, '<', $file) or die "Can't open '$file': $!";
  binmode ($fh);
  my $checksum = $algorithm->addfile($fh)->hexdigest;
  print ", checksum - ", $checksum,"\n" if $verbose;
  close ($fh) or die "Can't close $file: $!";

  return $checksum;
}
#
sub md5sum_data {
  my $inode_files = shift;
  my $md5_data = shift;
  my $size = shift;
  my $verbose = shift;

  while (my ($inode, $files) = each $inode_files) {
    my $file = $files->[0]; # first file at inode
    my $md5sum = checksum_file($file, "md5sum_data", Digest::MD5->new, $verbose);
    $md5_data->{$size}->{$md5sum}->{$inode} = $file;
  }
  return $md5_data;
}
#
sub shasum_data {
  my $md5_data = shift;
  my $sha_data = shift;
  my $size = shift;
  my $verbose = shift;
  my $shasize = shift;

  while (my ($md5sum, $w) = each $md5_data->{$size}) {
    if ((keys %$w) > 1) {
      while (my ($inode, $file) = each $w) {
        my $shasum = checksum_file($file, "shasum_data", Digest::SHA->new($shasize), $verbose);
        $sha_data->{$size}->{$shasum}->{$inode} = $file;
      }
    }
  }
  return $sha_data;
}
#
sub link_files {
  my $checksum_data = shift;
  my $stat_data = shift;
  my $size = shift;
  my $verbose = shift;

  if (defined $checksum_data and defined $checksum_data->{$size}) {
    while (my ($checksum, $inode_files) = each $checksum_data->{$size}) {
      my @files;
      if ((keys %$inode_files) > 1) {
        foreach my $inode (keys %$inode_files) {
          push @files, @{$stat_data->{$size}->{$inode}};
        }
      }
      if (@files > 1) {
        my $root = $files[0];
        for my $idx (1 .. $#files) {
          my $file = $files[$idx];
          print "link_files: linking ",$file," to $root with checksum $checksum\n" if $verbose;
          unlink $file and link $root, $file;
        }
      }
    }
  }
}
#
sub checksum_and_link {
# 
# reads a serialised hash file  - size, inode,  [filenames]
#
  my $stat_data = shift;
  my $verbose = shift;
  my $sha = shift;
  my $shasize = shift;

  my $md5_data;
  my $sha_data;
  if (defined $stat_data) {
    while (my ($size, $inode_files) = each $stat_data) {
      if ((keys %$inode_files) > 1) { # more than one inode for this file size
        $md5_data = md5sum_data($inode_files, $md5_data, $size, $verbose);
        my $checksum_data = $md5_data;
        if ($sha) {
          $sha_data = shasum_data($md5_data, $sha_data, $size, $verbose, $shasize);
          $checksum_data = $sha_data;
        }
        link_files($checksum_data, $stat_data, $size, $verbose);
      }
    }
  }
}

__END__

=head1 OPTIONS

=over 8

=item B<--minsize>

Minimum file size to process. If missing the first parameter must be a single digit which is used as the power of 10.
i.e. 0 would give size of 1, 1 would give size of 10, 2 => 100, 3 => 1000...

=item B<--maxsize>

Maximum file size to process. Default value is 0 - not used when value is 0.

=item B<--keep>

Keep the intermediate files (suffix .dat in $TMPDIR). Default value is 0.

e.g.

=over

=item /tmp/iFVZNes1_O.find.dat

=back

=item B<--file>

Use a pre-computed file of serialised size, inode, [files]

=item B<--link>

Checksum files and link duplicates. Default value is 1.

=item B<--verbose>

Level of verbosity; specify for some output. Default value is 0.

=item B<--debug>

Level of verbosity; specify for data dumps. Default value is 0.

=item B<--sha>

Use shasum after md5sum. This is a "belt and braces approach" due to (admittedly slim possibility) of md5 collisions. Default value is 1.

=item B<--sha>

Size of shasum. Default value is 512.

=item B<--help>

Prints brief help and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<link_duplicate.pl> will search through a file system for file above a minimum specified size.
The set of all inodes of each file of each size found is computed. 
If there is more than one inode for each size then each inode of that size has the md5sum computed. 
Any inodes with duplicate md5sums have their shasum computed if the switch --sha is set. 
Any inodes with duplicate checksums are then consolidated to one inode and hard links made to the previous names. 

File system integrity is preserved, but the total space is reduced.
This is especially useful on back-up disks with multiple copies of large files.

=cut

