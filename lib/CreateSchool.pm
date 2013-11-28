package CreateSchool;

use strict;
use warnings;

require Geo::Postcode;
use Data::Dumper;

my $google_api_key = "ABQIAAAAzvdwQCWLlw5TXpo7sNhCSRTpDCCGWHns9m2oc9sQQ_LCUHXVlhS7v4YbLZCNgHXnaepLqcd-J0BBDw";
my $yahoo_api_key = "8iy5OSrV34EfmQoZVXSrpkinxPQT7jYcNPs8AbkK8ngkpqNt8.HJg4N.8dzzrcp6wdg-";

sub get_location
{
    my $self = shift;
    my $school = shift;
    my %opts = @_;

    my @coords = $self->{geopostcode}->coords( $school->{postcode} );
    return @coords if @coords == 2 && $coords[0] && $coords[1];
    die "no using parameter\n" unless $opts{using};
    for my $field ( qw( address postcode ) )
    {
        my $value = $school->{$field};
        for my $using ( @{$opts{using}} )
        {
            warn "looking up $field ($value) using $using ...\n";
            if ( $using eq 'google' )
            {
                unless ( $self->{geogoogle} )
                {
                    require Geo::Coder::Google;
                    $self->{geogoogle} = Geo::Coder::Google->new(
                        apikey => $google_api_key,
                        host => "maps.google.co.uk",
                    );
                }
                my $response = $self->{geogoogle}->geocode( location => $value );
                if ( $response->{Status}{code} == 620 )
                {
                    warn "Too many geocoding queries\n";
                }
                if ( $response->{Status}{code} != 200 )
                {
                    warn "geocoding query failed: $response->{Status}{code}\n";
                }
                else
                {
                    my $location = $response->{Placemark}[0];
                    if ( $location )
                    {
                        @coords = @{ $location->{Point}{coordinates} };
                        return @coords if @coords == 2 && $coords[0] && $coords[1];
                    }
                    else
                    {
                        warn "failed to get location from $using for $field ($value)\n";
                    }
                }
            }
            elsif ( $using eq 'yahoo' )
            {
                unless ( $self->{geoyahoo} )
                {
                    require Geo::Coder::Yahoo;
                    $self->{geoyahoo} = Geo::Coder::Yahoo->new( appid => $yahoo_api_key );
                }
                my $response = $self->{geoyahoo}->geocode( location => $value );
                my $location = $response->[0];
                if ( $location )
                {
                    warn "found $location->{longitude}, $location->{latitude}\n";
                    @coords = ( $location->{longitude}, $location->{latitude} );
                    return @coords if @coords == 2 && $coords[0] && $coords[1];
                }
            }
            else
            {
                die "don't know how to lookup using $using\n";
            }
        }
    }
    die "no lat / lon\n";
}

sub new
{
    my $class = shift;
    my %args = @_;
    my $self = bless \%args, $class;
    die "no dbh\n" unless $self->{dbh};
    $self->{geopostcode} = Geo::Postcode->new( );
    return $self;
}

1;
