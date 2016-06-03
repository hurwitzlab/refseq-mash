#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';
use autodie;
use Data::Dump 'dump';
use File::Basename 'basename';
use File::Spec::Functions 'catfile';
use Getopt::Long;
use Pod::Usage;
use Readonly;
use Text::RecordParser;

main();

# --------------------------------------------------
sub main {
    my %args = get_args();

    if ($args{'help'} || $args{'man_page'}) {
        pod2usage({
            -exitval => 0,
            -verbose => $args{'man_page'} ? 2 : 1
        });
    }; 

    my $names = $args{'names'} or pod2usage('No names file');
    my $dir   = $args{'dir'}   or pod2usage('No dir');

    unless (-s $names) {
        pod2usage("Names ($names) is not a file");
    }

    unless (-d $dir) {
        pod2usage("Dir ($dir) is not a directory");
    }

    my $p = Text::RecordParser->new(
        filename        => $names,
        field_separator => "\t",
        comment         => qr/^#/,
    );

    $p->bind_fields(qw[
        assembly_accession bioproject biosample wgs_master
        refseq_category taxid species_taxid organism_name
        infraspecific_name isolate version_status assembly_level
        release_type genome_rep seq_rel_date asm_name
        submitter gbrs_paired_asm paired_asm_comp ftp_path
        excluded_from_refseq
    ]);

    my $i = 0;
    while (my $rec = $p->fetchrow_hashref) {
        #say dump($rec);    

        my $file = catfile($dir, 
            basename($rec->{'ftp_path'}) . '_genomic.gbff.gz'
        );

        # we only downloaded complete genomes
        next unless -s $file;

        (my $new_name = $rec->{'organism_name'}) =~ s/\W/_/g;

        printf "%4d: %s => %s\n", ++$i, basename($file), $new_name;

        my $cmd = join ' ', 'mv', $file, catfile($dir, $new_name);
        `$cmd`;
    }

    say "Done, changed $i.";
}

# --------------------------------------------------
sub get_args {
    my %args;
    GetOptions(
        \%args,
        'names=s',
        'dir=s',
        'help',
        'man',
    ) or pod2usage(2);

    return %args;
}

__END__

# --------------------------------------------------

=pod

=head1 NAME

change-names.pl - change the file names from accessions to species

=head1 SYNOPSIS

  change-names.pl -n assembly_summary.txt -d bacteria

Required arguments:

  -n|--names  Assembly summary from NCBI
  -d|--dir    The place where you downloaded the genomes

Options  (defaults in parentheses):

  --help    Show brief help and exit
  --man     Show full documentation

=head1 DESCRIPTION

Changes the names from "GCF_000005825.2_ASM582v2_genomic.gbff.gz" to 
"Bacillus pseudofirmus OF4."

=head1 SEE ALSO

perl.

=head1 AUTHOR

Ken Youens-Clark E<lt>kyclark@email.arizona.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2016 Ken Youens-Clark

This module is free software; you can redistribute it and/or
modify it under the terms of the GPL (either version 1, or at
your option, any later version) or the Artistic License 2.0.
Refer to LICENSE for the full license text and to DISCLAIMER for
additional warranty disclaimers.

=cut
