#!/usr/bin/env perl
#set filetype=perl

use strict;
use warnings;

require CGI::Lite;
use FindBin qw( $Bin );
use lib "$Bin/lib";
require Schools;
require Template;
# require Geo::Coder::Google;
require Google::GeoCoder::Smart;
use Data::Dumper;
use YAML qw( LoadFile );
use Log::Any qw( $log );
use Log::Dispatch::FileRotate;
use Log::Dispatch::Screen;
use Log::Any::Adapter;

my $logfile = "/var/log/schoolmap/index.log";

my $dispatcher = Log::Dispatch->new(
    callbacks  => sub {
        my %args = @_;
        my $message = $args{message};
        return uc( $args{level} ) . ": " . scalar( localtime ) . ": $message";
    }
);

Log::Any::Adapter->set( 'Dispatch', dispatcher => $dispatcher );

$dispatcher->add(
    my $file = Log::Dispatch::FileRotate->new(
        name            => 'logfile',
        min_level       => 'debug',
        filename        => $logfile,
        mode            => 'append' ,
        DatePattern     => 'yyyy-MM-dd',
        max             => 7,
        newline         => 1,
    ),
);

$log->debug( "start" );
my $config = LoadFile( "$Bin/google.yaml" );
$log->debug( "config: " . Dumper $config );
my %formdata = CGI::Lite->new->parse_form_data();
$log->debug( "form data: " . Dumper \%formdata );
print "Content-Type: text/html\n\n";
my $schools = eval { Schools->new( %formdata ) };
$log->critical( $@ ) if $@;
$formdata{types} = $schools->get_school_types;
$formdata{phases} = $schools->get_school_phases;
$formdata{order_bys} = $schools->get_order_bys;
my $template_file = 'index.tt';
$formdata{$_} = $config->{$_} for keys %$config;
$formdata{title} = "UK Schools Map";
if ( $formdata{address} )
{
    my $geo = eval { Google::GeoCoder::Smart->new() };
    $log->critical( $@ ) if $@;
    $log->info( "lookup $formdata{address}" );
    my ( $resultnum, $error, @results, $returncontent ) = $geo->geocode( "address" => $formdata{address} );
    $log->info( "$resultnum results" );
    if ( $resultnum )
    {
        $formdata{title} = "UK Schools Map - $results[0]->{formatted_address}";
        my $location = $results[0]->{geometry}{location};
        $log->debug( Dumper( $results[0] ) );
        $formdata{location} = $location;
    }
}
$log->info( $formdata{address} );
my $template = Template->new( INCLUDE_PATH => "$Bin/templates" );
$template->process( $template_file, \%formdata ) || $log->critical( $template->error() )
;
