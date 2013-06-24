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

sub create_school
{
    my $self = shift;
    my $type = shift;
    die "no type" unless $type;
    my %school = @_;

    die "no name" unless $school{name};
    die "no postcode" unless $school{postcode};
    my $postcode = $school{postcode};
    my $id_key = $type . "_id";
    die "no $id_key" unless $school{$id_key};
    $school{postcode} = uc( $school{postcode} );
    $school{postcode} =~ s/[^0-9A-Z]//g;
    # warn "lookup @school{qw(postcode name)} ...\n";
    my $ssth = $self->{dbh}->prepare( "SELECT * FROM school WHERE postcode = ? AND name = ?" );
    $ssth->execute( @school{qw(postcode name)} );
    my $school = $ssth->fetchrow_hashref();
    if ( $school )
    {
        # warn "UPDATE $school->{name}\n";
        my $usth = $self->{dbh}->prepare( "UPDATE school SET ${type}_id = ? WHERE postcode = ? AND name = ?" );
        $usth->execute( @school{$id_key, qw(postcode name)} );
        return;
    }
    warn "new school: $school{name}\n";
    if ( $school{lat} && $school{lon} )
    {
        $self->{geopostcode}->add( $school{postcode}, $school{lat}, $school{lon} );
    }
    else
    {
        ( $school{lon}, $school{lat} ) = $self->get_location( \%school, using => [ "google" ] );
    }
    my $isth = $self->{dbh}->prepare( <<SQL );
REPLACE INTO school ( $id_key, name, postcode, address ) VALUES ( ?,?,?,? )
SQL
    $isth->execute( @school{$id_key, qw( name postcode address )} );
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
