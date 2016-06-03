#!/usr/bin/env perl

use strict;
use autodie;
use feature 'say';
use File::Basename qw'dirname basename';
use File::Spec::Functions 'catfile';

@ARGV or die "No files.\n";

my $delim = "\t";

my $i = 0;
for my $file (@ARGV) {
    my $basename = basename($file);
    
    printf "%3d: %s\n", ++$i, $basename;

    open my $in,  '<', $file;
    open my $out, '>', catfile(dirname($file), $basename . '.fixed');

    my $i = 0;
    while (my $line = <$in>) {
        chomp($line);
        my @flds = split(/$delim/, $line);

        if (++$i == 1) {
            my $query = shift @flds;
            $query    =~ s/^#//;
            my @files = map { s/\..*//; basename($_) } @flds;
            @flds = ($query, @files);
        }
        else {
            (my $file = basename($flds[0])) =~ s/\.gz$//;
            $flds[0] = $file;
        }

        say $out join $delim, @flds;
    }

    close $in;
    close $out;
}

say "Done.";
