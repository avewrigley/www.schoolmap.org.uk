package School;

use strict;
use warnings;

use Carp;
use CGI::Lite;
require DBI;
use Template;
use Data::Dumper;
use FindBin qw( $Bin );

my $ofsted_base_url = "http://www.ofsted.gov.uk/inspection-reports/find-inspection-report/provider/ELS/";

sub new
{
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;
    $self->{dbh} = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    $self->{dcsf_types} = {
        post16 => "A Level",
        secondary => "GCSE",
        primary => "Key stage 2",
    };
    warn Dumper $self;
    return $self;
}

sub DESTROY
{
    my $self = shift;
    $self->{dbh}->disconnect();
}

sub get_tabs
{
    my $self = shift;
    my $school = shift;
    my $wiki_name = $school->{name};
    $wiki_name =~ s/\s+/_/g;
    $wiki_name =~ s/[^A-Za-z0-9_]//g;
    warn Dumper $school;
    return [
        { 
            url => $school->{WebsiteAddress},
            description => "School Website" 
        },
        { 
            url => "http://en.wikipedia.org/wiki/$wiki_name", 
            description => "Wikipedia entry" 
        },
        { 
            url => "$ofsted_base_url/$school->{URN}",
            description => "Ofsted",
        },
        { 
            url => $school->{dcsf_url},
            description => "Department of Education",
            current => 1,
        },
    ];
}

sub html
{
    my $self = shift;

    my $school_sql = "SELECT * FROM edubase,dcsf WHERE edubase.URN = dcsf.URN AND edubase.URN = ?";
    warn "$school_sql\n";
    my $school_sth = $self->{dbh}->prepare( $school_sql );
    $school_sth->execute( $self->{id} );
    warn $self->{id};
    my $school = $school_sth->fetchrow_hashref;
    $school_sth->finish();
    warn Dumper $school;
    my $iframe_source = $school->{dcsf_url};
    warn "iframe_source: $iframe_source\n";
    my $tabs = $self->get_tabs( $school );
    my $tt = Template->new( { INCLUDE_PATH => "$Bin/../templates" } );
    warn "../$Bin/templates";
    $tt->process(
        "school.html", 
        { 
            school => $school,
            tabs => $tabs,
            iframe_source => $iframe_source,
        }
    ) || die $tt->error();
}

#------------------------------------------------------------------------------
#
# Start of POD
#
#------------------------------------------------------------------------------

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2004 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

#------------------------------------------------------------------------------
#
# End of POD
#
#------------------------------------------------------------------------------

