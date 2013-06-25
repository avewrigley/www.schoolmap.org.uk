#!/usr/bin/env perl
#set filetype=perl

use strict;
use warnings;

require CGI::Lite;
use FindBin qw( $Bin );
use lib "$Bin/lib";
require Schools;
require Template;
require Geo::Coder::Google;
use Data::Dumper;
use YAML qw( LoadFile );

my $config = LoadFile( "$Bin/google.yaml" );
open( STDERR, ">>$Bin/logs/index.log" );
warn "$$ at ", scalar( localtime ), "\n";
my %formdata = CGI::Lite->new->parse_form_data();
warn Dumper \%formdata;
print "Content-Type: text/html\n\n";
my $schools = Schools->new( %formdata );
$formdata{types} = $schools->get_school_types;
$formdata{phases} = $schools->get_school_phases;
$formdata{order_bys} = $schools->get_order_bys;
my $template_file = 'index.tt';
$formdata{apikey} = $config->{apikey};
if ( $formdata{address} )
{
    my $geocoder = Geo::Coder::Google->new(
        apikey => $config->{apikey},
        host => "maps.google.co.uk",
    );
    warn "lookup $formdata{address}\n";
    my $location = $geocoder->geocode( location => $formdata{address} );
    warn Dumper $location;
    $formdata{location} = $location;
}
my $template = Template->new( INCLUDE_PATH => "$Bin/templates" );
$template->process( $template_file, \%formdata )
    || die $template->error()
;
