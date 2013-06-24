package School;

use strict;
use warnings;

use Carp;
use CGI::Lite;
require DBI;
use Template;
use Data::Dumper;

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
            url => "http://en.wikipedia.org/wiki/$wiki_name", 
            description => "Wikipedia entry" 
        },
        { 
            url => $school->{ofsted_url},
            description => "Ofsted",
            current => $self->{table} eq 'ofsted' ? 1 : 0,
        },
        { 
            url => $school->{dcsf_url},
            description => "Department of Education",
            current => $self->{table} eq 'dcsf' ? 1 : 0,
        },
    ];
}

sub html
{
    my $self = shift;

    my $school_sql = "SELECT * FROM school LEFT JOIN dcsf USING ( dcsf_id ) LEFT JOIN ofsted USING( ofsted_id ) WHERE school.$self->{table}_id = ?";
    warn "$school_sql\n";
    my $school_sth = $self->{dbh}->prepare( $school_sql );
    $school_sth->execute( $self->{id} );
    warn $self->{id};
    my $school = $school_sth->fetchrow_hashref;
    $school_sth->finish();
    warn Dumper $school;
    $self->{current} = 
    my $key = "$self->{table}_url";
    warn "key: $key\n";
    my $iframe_source = $school->{$key};
    warn "iframe_source: $key $iframe_source\n";
    my $tabs = $self->get_tabs( $school );
    warn Dumper $tabs;
    my $tt = Template->new( { INCLUDE_PATH => "/var/www/www.schoolmap.org.uk/templates" } );
    $tt->process(
        "school.html", 
        { 
            school => $school,
            tabs => $tabs,
            iframe_source => $iframe_source,
        }
    );
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

