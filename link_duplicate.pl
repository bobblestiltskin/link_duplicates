#!/usr/bin/perl -w
# 
# takes a minimum size in bytes, an output filename and a list of directories to process
#
# creates a hash of file size vs list of files of that size and serialises to output file
#
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
my $help = 0;
my $man = 0;
my $keep = 0;
my $verbose = 0;
my $sha = 1;
my $shasize = 512;
my $getopt_result = GetOptions (
#  'regexp=s' => \$regexp,
  'size=i'    => \$MINSIZE,
  'shasize=i' => \$shasize,
  'verbose+'  => \$verbose,
  'keep!'     => \$keep,
  'sha!'      => \$sha,
  'help|?'    => \$help,
  'man'       => \$man,
);
die "Bad Parameter passed to $0" unless ($getopt_result);

pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

$MINSIZE = (10 ** shift) if (not defined $MINSIZE) and ($ARGV[0] =~ /^\d$/);
die "Need a minsize and some directories to process" unless (($MINSIZE =~ /\d+/) and @ARGV);

$| = 1;
my $data;
print "*** Finding location of files\n";
find(\&wanted, @ARGV);
if (defined $data) {
  print Data::Dumper->Dump([$data]) if $verbose > 1;

  my $find_fh = File::Temp->new(UNLINK => !$keep, SUFFIX => '.find.dat' );
  my $serializer = Data::Serializer->new;
  $serializer->store($data, $find_fh);
  $find_fh->seek(0, SEEK_SET);

  my $stat_fh = File::Temp->new(UNLINK => !$keep, SUFFIX => '.stat.dat' );
  print "*** Getting size of files\n";
  stat_files($find_fh, $stat_fh, $verbose);
  $stat_fh->seek(0, SEEK_SET);

  my $md5_fh = File::Temp->new(UNLINK => !$keep, SUFFIX => '.md5.dat' );
  print "*** Calculating md5sum of files\n";
  checksum_data(\&md5sum_data, $stat_fh, $md5_fh, $verbose);
  $md5_fh->seek(0, SEEK_SET);

  if ($sha) {
    my $sha_fh = File::Temp->new(UNLINK => !$keep, SUFFIX => '.sha.dat' );
    print "*** Calculating shasum of files\n";
    checksum_data(\&shasum_data, $md5_fh, $sha_fh, $verbose, $shasize);
    $sha_fh->seek(0, SEEK_SET);
    print "*** Linking files\n";
    link_all($sha_fh, $verbose);
  } else {
    print "Linking files\n";
    link_all($md5_fh, $verbose);
  }
}

sub wanted {
  return unless (-f $File::Find::name);
  my $size = (stat($File::Find::name))[7];
  if ($size >= $MINSIZE) {
    print "wanted: file - $File::Find::name, size - $size\n" if $verbose;
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
  my $verbose = shift;

  if (defined $ifh) {
    my $obj = Data::Serializer->new();
    my $idata = $obj->retrieve($ifh);
    print "stat_files: idata is ",Data::Dumper->Dump([$idata]) if $verbose > 1;
    my $odata = stat_data($idata, $verbose);
    if (defined $odata) {
      print "stat_files: odata is ",Data::Dumper->Dump([$odata]) if $verbose > 1;
      if (defined $ifh) {
        $obj->store($odata, $ofh);
      }
    }
  }
}
#  
sub stat_data {
  my $idata = shift;
  my $verbose = shift;

  my $odata;
  if (defined $idata) {
    while (my ($k, $v) = each $idata) {
      if (@$v > 1) {
        foreach my $file (@$v) {
          my $inode = (stat($file))[1];
          print "stat_data: file - ", $file, ", inode - $inode\n" if $verbose;
   
          if (defined $odata->{$k}->{$inode}) {
            push @{$odata->{$k}->{$inode}}, $file;
          } else {
            $odata->{$k}->{$inode} = [ $file ];
          }
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
  my $verbose = shift;
  my $shasize = shift;

  if (defined $ifh) {
    my $obj = Data::Serializer->new;
    my $idata = $obj->retrieve($ifh);
    print "checksum_data: idata is ",Data::Dumper->Dump([$idata]) if $verbose > 1;
    my $odata = $function->($idata, $verbose);
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
  my $verbose = shift;

  my $odata;
  if (defined $idata) {
    while (my ($k, $v) = each $idata) {
      if ((keys %$v) > 1) {
        while (my ($inode, $files) = each $v) {
          my $file = $files->[0]; # first file at inode
          open (my $fh, '<', $file) or die "Can't open '$file': $!";
          binmode ($fh);
          my $checksum = Digest::MD5->new->addfile($fh)->hexdigest;
          print "md5sum_data: file - ",$file,", checksum - ", $checksum,"\n" if $verbose;
          close ($fh) or die "Can't close $file: $!";
    
          if (defined $odata->{$checksum}) {
            push @{$odata->{$checksum}}, $file;
          } else {
            $odata->{$checksum} = [ $file ];
          }
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
  my $verbose = shift;
  my $shasize = shift;

  my $odata;
  if (defined $idata) {
    while (my ($md5sum, $files) = each $idata) {
      if (@$files > 1) {
        foreach my $file (@$files) {
          open (my $fh, '<', $file) or die "Can't open '$file': $!";
          binmode ($fh);
          my $checksum = Digest::SHA->new($shasize)->addfile($fh)->hexdigest;
          print "shasum_data: file - ",$file,", checksum - ", $checksum,"\n" if $verbose;
          close ($fh) or die "Can't close $file: $!";
  
          if (defined $odata->{$checksum}) {
            push @{$odata->{$checksum}}, $file;
          } else {
            $odata->{$checksum} = [ $file ];
          }
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
  my $verbose = shift;

  if (defined $ifh) {
    my $obj = Data::Serializer->new();
    my $idata = $obj->retrieve($ifh);
    print "link_all: idata is ",Data::Dumper->Dump([$idata]) if $verbose > 1;
    link_files($idata, $verbose);
  }
}
#
sub link_files {
# 
# reads a serialised hash file - size, csum, [filenames]
#
  my $idata = shift;
  my $verbose = shift;

  my $odata;
  if (defined $idata) {
    while (my ($checksum, $files) = each $idata) {
      if (@$files == 1) {
        print "link_files: Nothing to do for ",$files->[0],"\n" if $verbose;
      } else {
        my $root = $files->[0];
        for my $idx (1 .. $#$files) {
          my $file = $files->[$idx];
          print "link_files: linking ",$file," to $root with checksum $checksum\n" if $verbose;
          unlink $file and link $root, $file;
        }
      }
    }
  }
  return $odata;
}

__END__

=head1 NAME

link_duplicate.pl - reduce used disk space by determining duplicates and hard-linking

=head1 SYNOPSIS

link_duplicate.pl [options] [paths ...]

link_duplicate.pl --size 50 /path/to/dir1 /path/to/dir2

This form is used to specify any minimum file size within the given sub-trees.

link_duplicate.pl           [0-9] /path/to/files

This form will used 2**[0-9] as the minimum file size to consider in the path.

Options:
  --size      minimum file size to process
  --verbose   give once for some output, twice for more
  --keep      keep the intermediate files (suffix .dat in /tmp by default).
  --sha       use shasum after md5sum (belt and braces approach due to md5 collisions)
  --shasize   size of sha digest (defaults to 512).

=head1 OPTIONS

=over 8

=item B<--size>

Minimum file size to process. If missing the first parameter must be a single digit which is used as the power of 10.
i.e. 0 would give size of 1, 1 would give size of 10, 2 => 100, 3 => 1000...

=item B<--keep>

Keep the intermediate files (suffix .dat in $TMPDIR). Default value is 0.

e.g.

=over

=item /tmp/iFVZNes1_O.find.dat

=item /tmp/y86IoWxOrU.stat.dat

=item /tmp/NLQpPUg0Ad.md5.dat

=item /tmp/JL6Th_9d4T.sha.dat

=back

=item B<--verbose>

Level of verbosity; specify once for some output; twice for data dumps, too. Default value is 0.

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

B<link_duplicate.pl> will search through a file system for file above a minimum specified size. The associated inodes of each file of each size found are compared. 
Any duplicates are discarded (already these are hard links). Each file of that size has the md5sum computed. Any duplicates have their shasum computed
if the switch --sha is set. Any duplicates are then consolidated to one inode and hard links made to the previous names. 

File system integrity is preserved, but the total space is reduced. This is especially useful on back-up disks with multiple copies of large files.

=cut
