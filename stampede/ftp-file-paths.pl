#!/usr/bin/env perl

use strict;
use warnings;
use feature 'say';
use autodie;
use Data::Dump 'dump';
use File::Path 'make_path';
use File::Basename qw'dirname basename';
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

    my @assembly_files = @ARGV or pod2usage('No names file');
    my $out_dir        = $args{'out-dir'}    || '';
    my $incomplete     = $args{'incomplete'} || 0;

    for my $assembly_info (@assembly_files) {
        my $dir = $out_dir || dirname($assembly_info);

        unless (-d $dir) {
            make_path($dir);
        }

        printf STDERR "Processing %s => $dir\n", basename($assembly_info), $dir;

        my $p = Text::RecordParser->new(
            filename        => $assembly_info,
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

        my %seen;
        my $i = 0;
        while (my $rec = $p->fetchrow_hashref) {
            next unless $rec->{'version_status'} eq 'latest';
            next unless $incomplete || $rec->{'assembly_level'} eq 'Complete Genome';

            my $path        = $rec->{'ftp_path'} or next;
            my @bits        = split /\//, $path;
            my $asm         = $bits[5];
            my $remote_file = join('/', $path, $asm . '_genomic.fna.gz');
            my $local_file  = $rec->{'organism_name'}; 
            my $strain      = '';

            if ($rec->{'infraspecific_name'} =~ /^strain=(.+)/) {
                $strain = $1;
            }

            if ($seen{ $local_file }++) {
                $local_file .= ' ' . $strain;
            }

            $local_file     =~ s/\W+/_/g;
            $local_file     =~ s/_$//;
            my $local_path  = catfile($dir, $local_file . '.gz');

            unless (-e $local_path) {
                printf "ncftpget -c %s > %s\n", $remote_file, $local_path;
            }
        }
    }

    say STDERR "Done.";
}

# --------------------------------------------------
sub get_args {
    my %args;
    GetOptions(
        \%args,
        'out-dir|o:s',
        'incomplete|i',
        'help',
        'man',
    ) or pod2usage(2);

    return %args;
}

__END__

# --------------------------------------------------

=pod

=head1 NAME

ftp-file-paths.pl - extract FTP file path from "assembly_summary.txt"

=head1 SYNOPSIS

  ftp-file-paths.pl assembly_summary.txt 

Required arguments:

  Assembly summary from NCBI

Options (defaults in parentheses):

  -o|--out-dir     Download path (same as location of assembly info)
  -i|--incomplete  Download incomplete genomes 
  --help           Show brief help and exit
  --man            Show full documentation

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
