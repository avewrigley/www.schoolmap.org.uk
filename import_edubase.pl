#!/usr/bin/perl
#set filetype=perl

use strict;
use warnings;

use Text::CSV;
use Data::Dumper;
use Geo::Coordinates::OSGB qw(grid_to_ll);
use WWW::Mechanize;
use Getopt::Long;
use Pod::Usage;
use Proc::Pidfile;
use FindBin qw( $Bin );
use DBI;

my $logfile = ">/var/log/schoolmap/edubase.log";
my $ofsted_base_url = "http://www.ofsted.gov.uk/oxcare_providers/urn_search?type=2&urn=";

my @keys = qw(
    TypeOfEstablishment
    URN
    EstablishmentName
    PhaseOfEducation
    HeadTitle
    NumberOfPupils
    Postcode
    HeadLastName
    WebsiteAddress
    TelephoneNum
    Easting
    Northing
    Street
    Gender
    Town
    lat
    lon
    address
    name
);

my %opts;
my @opts = qw( pidfile! silent verbose );
$opts{pidfile} = 1;
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );

unless ( $opts{verbose} )
{
    open( STDERR, ">$logfile" ) or die "can't write to $logfile\n";
}
my $cvsfile = shift or die "usage: $0 <csvfile>\n";

my $mech = WWW::Mechanize->new();
my $dbh = DBI->connect( "DBI:mysql:schoolmap", 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
my @fields = join ',', @keys;
my @placeholders = join ',', map "?", @keys;
my $school_sql = "REPLACE INTO edubase ( @fields ) VALUES ( @placeholders )";
my $school_sth = $dbh->prepare( $school_sql );
my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();
open my $fh, "<:encoding(utf8)", $cvsfile or die "$cvsfile: $!";
my $header = $csv->getline( $fh );
while ( my $row = $csv->getline( $fh ) )
{
    my %row;
    @row{@$header} = @$row;
    warn "$row{EstablishmentName}\n";
    add_school( \%row );
}

sub add_school
{
    my $edubase = shift;
    for my $k1 ( keys %$edubase )
    {
        my $k2 = $k1;
        $k2 =~ s/ \(name\)//;
        $edubase->{$k2} = delete $edubase->{$k1};
    }
    $edubase->{Postcode} =~ s/\s//g;
    my $easting = $edubase->{Easting};
    my $northing = $edubase->{Northing};
    ( $edubase->{lat}, $edubase->{lon} ) = grid_to_ll( $easting, $northing );
    $edubase->{name} = $edubase->{EstablishmentName};
    $edubase->{address} = join ", ", $edubase->{Street}, $edubase->{Town};
    warn "$edubase->{name} ($edubase->{URN}) $edubase->{address} $edubase->{Postcode} ($edubase->{lat}, $edubase->{lon})\n";
    for ( @keys )
    {
        warn "No $_\n" and return unless $edubase->{$_};
    }
    my %edubase = %{$edubase};
    my @values = @edubase{@keys};
    $school_sth->execute( @values );
}
