#!/usr/bin/env perl

use strict;
use warnings;
use autodie;
use feature 'say';
use Data::Dump 'dump';
use File::Basename qw'dirname basename';
use File::Spec::Functions 'catfile';
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

    if ($limit eq '' || $limit < 0 || $limit > 1) {
        $limit = .99;
    }

    my $i = 0;
    for my $file (@ARGV) {
        (my $basename = basename($file)) =~ s/\..*//;
        printf "%3d: %s\n", ++$i, $basename;
        my $p = Text::RecordParser::Tab->new($file);
        my ($query, @samples) = $p->field_list;

        my %data;
        while (my $r = $p->fetchrow_hashref) {
            for my $sample (@samples) {
                my $dist = $r->{$sample};
                if ($dist <= $limit) {
                    push @{ $data{ $sample } }, [ $dist, $r->{'query'} ];
                }
            }
        }

        #say dump(\%data);

        for my $sample (@samples) {
            my @hits = @{ $data{ $sample } || [] } or next;
            (my $out_file = $sample . '_' . $basename . '.txt') =~ s/[^\w.]/_/g;
            my $path = catfile($out_dir || dirname($file), $out_file);
            printf "\t%s (%s)\n", $path, scalar(@hits);
            open my $fh, '>', $path;

            say $fh join "\t", qw(dist species);
            for my $hit (sort { $a->[0] <=> $b->[0] } @hits) {
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
