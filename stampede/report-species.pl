#!/usr/bin/env perl

use strict;
use warnings;
use autodie;
use feature 'say';
use Data::Dump 'dump';
use File::Basename qw'dirname basename';
use File::Spec::Functions 'catfile';
use File::Path 'make_path';
use Getopt::Long;
use Pod::Usage;
use Text::RecordParser::Tab;

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

    my $out_dir = $args{'out-dir'} || '';
    my $limit   = $args{'limit'}   || '';
    my $unify   = $args{'unify'}   ||  0;
    my $genus   = $args{'genus'}   ||  0;
    my $species = $args{'species'} ||  0;

    unless (-d $out_dir) {
        make_path($out_dir);
    }

    if ($limit eq '' || $limit < 0 || $limit > 1) {
        $limit = .99;
    }

    my $i = 0;
    for my $file (@ARGV) {
        (my $basename = basename($file)) =~ s/\.txt.*$//;
        printf "%3d: %s\n", ++$i, $basename;
        my $p = Text::RecordParser::Tab->new($file);
        my ($query, @samples) = $p->field_list;

        my %data;
        while (my $r = $p->fetchrow_hashref) {
            for my $sample (@samples) {
                my $dist = $r->{$sample};
                if ($dist <= $limit) {
                    my $key  = $unify ? 'all' : $sample;
                    my $val  = $r->{'query'};
                    my @bits = split(/_/, $val);
                    if ($species) {
                        $val = join '_', @bits[0..1];
                    }
                    elsif ($genus) {
                        $val = join '_', $bits[0];
                    }

                    if ($val) {
                        push @{ $data{ $key } }, [ $dist, $val ];
                    }
                }
            }
        }

        #say dump(\%data);

        for my $sample (sort keys %data) {
            my @hits = @{ $data{ $sample } || [] } or next;
            (my $out_file = $sample . '_' . $basename . '.txt') =~ s/[^\w.]/_/g;
            my $path = catfile($out_dir || dirname($file), $out_file);
            printf "\t%s (%s)\n", $path, scalar(@hits);
            open my $fh, '>', $path;

            say $fh join "\t", qw(dist species);
            my %seen;
            for my $hit (sort { $a->[0] <=> $b->[0] } @hits) {
                next if $seen{ $hit->[1] }++;
                say $fh join "\t", @$hit;
            }

            close $fh;
        }
    }

    say "Done.";
}

# --------------------------------------------------
sub get_args {
    my %args;
    GetOptions(
        \%args,
        'limit:s',
        'out-dir:s',
        'unify',
        'genus',
        'species',
        'help',
        'man',
    ) or pod2usage(2);

    return %args;
}

__END__

# --------------------------------------------------

=pod

=head1 NAME

report-species.pl - report species from distance matrix

=head1 SYNOPSIS

  report-species.pl -l .25 -o /path/to/dir archeae.txt [fungi.txt ...]

Required arguments:

  One or more distance files.

Options  (defaults in parentheses):

  -l|--limit    Upper limit of distance (.99)
  -o|--out-dir  Where to put reports
  --help        Show brief help and exit
  --man         Show full documentation

=head1 DESCRIPTION

Describe what the script does, what input it expects, what output it
creates, etc.

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
