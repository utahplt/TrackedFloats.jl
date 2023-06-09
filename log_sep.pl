#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

=pod
USAGE

  perl log_sep.pl log_file.txt separated_basename

produces e.g. separated_basename_nan.txt and separated_basename_inf.txt
=cut

my $inname   = shift;
my $basename = shift;

print "Separating $inname to $basename *\n";

my %fhs = ();                   # log_token -> fh

open my $in_fh, '<', $inname;

my $last_cat;
while (<$in_fh>) {
  chomp;
  if (/^\[(\w+)\]/../^$/) {
    if (defined $1) {
      $last_cat = $1;           # Can't just use $1 because matching /^$/ resets it
    }
    print { get_fh($last_cat) } "$_\n";
  }
}

sub get_fh {
  my $name = shift;

  open $fhs{$name}, '>', "${basename}_$name.txt"
    or die "Can't open ${basename}_$name.txt: $!"
    unless defined $fhs{$name};

  return $fhs{$name};
}
