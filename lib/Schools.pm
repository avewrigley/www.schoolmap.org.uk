package Schools;

use strict;
use warnings;

use Carp;
use HTML::Entities qw( encode_entities );
use Template;
use Data::Dumper;
use JSON;

my @from = ( "edubase", "dcsf" );
my $from = join( ",", @from );

sub new
{
    my $class = shift;
    my $self = bless { @_ }, $class;
    require DBI;
    # $self->{debug} = 1;
    $self->{dbh} = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
    $self->{tt} = Template->new( { INCLUDE_PATH => "/var/www/www.schoolmap.org.uk/templates" } );
    return $self;
}

my %label = (
    secondary => "Secondary",
    post16 => "Sixteen Plus",
    primary => "Primary",
    independent => "Independent",
    nursery => "Nursery",
    sen => "Special School",
    pru => "Pupil Referral Unit",
);

sub process_template
{
    my $self = shift;
    my $template = shift;
    my $params = shift;
    $self->{tt}->process( $template, $params ) || croak $self->{tt}->error;
    return unless $self->{debug};
    $self->{tt}->process( $template, $params, \*STDERR );
}

sub json
{
    my $self = shift;
    my $schools = $self->get_schools();
    print to_json( $schools );
}

sub types
{
    my $self = shift;
    print to_json( $self->_get_types );
}

sub phases
{
    my $self = shift;
    print to_json( $self->_get_phases );
}

sub _get_types
{
    my $self = shift;
    my ( $where, @args ) = $self->geo_where();
    warn $where;
    my @types = ( { val => "all", str => "all" } );
    my $sql = "SELECT school_type, COUNT(*) AS c FROM $from $where AND school_type IS NOT NULL GROUP BY school_type ORDER BY c DESC";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute( @args );
    while ( my ( $type, $count ) = $sth->fetchrow )
    {
        # push( @types, { val => $type, str => "$type ($count)" } );
        push( @types, { val => $type, str => $type } );
    }
    return \@types;
}

sub _get_phases
{
    my $self = shift;
    my ( $where, @args ) = $self->geo_where();
    warn $where;
    my @phases = ( { val => "all", str => "all" } );
    my $sql = "SELECT PhaseOfEducation, COUNT(*) AS c FROM $from $where AND PhaseOfEducation IS NOT NULL GROUP BY PhaseOfEducation ORDER BY c DESC";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute( @args );
    while ( my ( $phase, $count ) = $sth->fetchrow )
    {
        # push( @phases, { val => $phase, str => "$phase ($count)" } );
        push( @phases, { val => $phase, str => $phase } );
    }
    return \@phases;
}

sub get_school_types
{
    my $self = shift;
    my @types = ( "all" );
    my $sql = "SELECT DISTINCT school_type FROM dcsf";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute();
    while ( my ( $type ) = $sth->fetchrow )
    {
        push( @types, $type );
    }
    return \@types;
}

sub get_school_phases
{
    my $self = shift;
    my @phases = ( "all" );
    my $sql = "SELECT DISTINCT PhaseOfEducation FROM edubase";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute();
    while ( my ( $phase ) = $sth->fetchrow )
    {
        push( @phases, $phase );
    }
    return \@phases;
}

sub get_order_bys
{
    my $self = shift;
    return [
        { val => "", str => "-" },
        { val => "distance", str => "Distance" },
        { val => "primary", str => "Key stage 2 results" },
        { val => "secondary", str => "GCSE results" },
        { val => "post16", str => "A Levels" },
    ];
}

sub xml
{
    my $self = shift;
    my $schools = $self->get_schools();
    $self->{format} ||= "xml";
    $self->process_template( "school.$self->{format}", $schools );
}

sub geo_where
{
    my $self = shift;
    my @args;
    my @where = ( 
        "edubase.URN = dcsf.URN", 
    );
    if ( $self->{minLon} && $self->{maxLon} && $self->{minLat} && $self->{maxLat} )
    {
        push( 
            @where,
            (
                "edubase.lon > ?",
                "edubase.lon < ?",
                "edubase.lat > ?",
                "edubase.lat < ?",
            )
        );
        push( @args, $self->{minLon}, $self->{maxLon}, $self->{minLat}, $self->{maxLat} );
    }
    my $where = @where ? "WHERE " . join( " AND ", @where ) : '';
    return ( $where, @args );
}

sub get_schools
{
    my $self = shift;
    my @what = ( "*" );
    my $what = join( ",", @what );

    my @args;
    my @where = ( 
        "edubase.URN = dcsf.URN", 
    );
    if ( $self->{minLon} && $self->{maxLon} && $self->{minLat} && $self->{maxLat} )
    {
        push( 
            @where,
            (
                "edubase.lon > ?",
                "edubase.lon < ?",
                "edubase.lat > ?",
                "edubase.lat < ?",
            )
        );
        push( @args, $self->{minLon}, $self->{maxLon}, $self->{minLat}, $self->{maxLat} );
    }
    if ( my $phase = $self->{phase} )
    {
        push( @where, "edubase.PhaseOfEducation = ?" );
        push( @args, $phase );
    }
    if ( my $type = $self->{type} )
    {
        push( @where, "dcsf.school_type = ?" );
        push( @args, $type );
    }
    if ( $self->{find_school} )
    {
        push( @where, 'school.name LIKE ?' );
        push( @args, "%" . $self->{find_school} ."%" );
    }
    if ( $self->{order_by} )
    {
        push( @where, "average_$self->{order_by} IS NOT NULL" );
    }
    my $where = @where ? "WHERE " . join( " AND ", @where ) : '';
    my $sql = <<EOF;
SELECT SQL_CALC_FOUND_ROWS $what FROM $from $where
EOF
    if ( $self->{order_by} )
    {
        $sql .= " ORDER BY average_$self->{order_by} DESC";
    }
    else
    {
        $sql .= " ORDER BY name";
    }
    unless ( $self->{limit} eq 'all' || $self->{nolimit} )
    {
        my $limit = 50;
        $limit = $self->{limit} if defined $self->{limit};
        $sql .= " LIMIT $limit";
    }
    warn "$sql\n";
    warn "ARGS: @args\n";
    my $sth = $self->{dbh}->prepare( $sql );
    $sth->execute( @args );
    my @schools;
    while ( my $school = $sth->fetchrow_hashref )
    {
        delete $school->{location};
        push( @schools, $school );
    }
    $sth = $self->{dbh}->prepare( "SELECT FOUND_ROWS();" );
    $sth->execute();
    my ( $nschools ) = $sth->fetchrow();
    warn "NROWS: $nschools\n";
    return { nschools => $nschools, schools => \@schools };
}

1;
