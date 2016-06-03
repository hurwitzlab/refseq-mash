#!/usr/bin/env perl

use strict;
use autodie;
use feature 'say';
use Bio::SeqIO;
use File::Basename qw'dirname basename';
use File::Spec::Functions 'catfile';

my $not_fasta = shift or die 'No file';
open my $not, '<', $not_fasta;

while (my $filename = <$not>) {
    chomp($filename);

    if ($filename =~ /\.gz$/) {
        if (-e $filename) {
            `gunzip $filename`;
        }
        $filename =~ s/\.gz$//;
    }

    my $in = Bio::SeqIO->new(
        -file   => $filename,
        -format => 'Genbank'
    );

    my $outname = catfile(dirname($filename), basename($filename) . '.fa');

    say $outname;
    my $out = Bio::SeqIO->new(
        -file   => ">$outname",
        -format => 'Fasta'
    );
 
    while (my $seq = $in->next_seq()) {
        $out->write_seq($seq);
    }

    `mv $outname $filename`;
    `gzip $filename`;
}
say "Done.";
