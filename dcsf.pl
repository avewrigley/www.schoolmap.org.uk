#!/usr/bin/perl
#set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

=head1 NAME

dcfs.pl

=head1 DESCRIPTION

A script to crawl dcfs site for school info.

=head1 SYNOPSIS

    deliver.pl 
        [--verbose] 
        [--man] 
        [--help] 
        [--year <YYY-MM-DD>]
        [--force]
        [--flush]
        [--silent]
        [--pidfile </path/to/pidfile>]
        [--school <school name>]
        [--type <school type>]


=head1 OPTIONS

=over 4

=item --verbose

Output status messages to STDERR

=item --man

Output man page documentation

=item --help

Output help documentation

=back

=cut



use FindBin qw( $Bin );
use WWW::Mechanize;
use LWP::Simple;
use Pod::Usage;
use Getopt::Long;
use Proc::Pidfile;
use HTML::Entities;
require HTML::TableExtract;
use DBI;
use Log::Any qw( $log );
use Log::Dispatch::FileRotate;
use Log::Dispatch::Screen;
use Log::Any::Adapter;
use lib "$Bin/lib";
require CreateSchool;
use URI::URL;
use Data::Dumper;

use vars qw( %types @types );
my $ofsted_base_url = "http://www.ofsted.gov.uk/inspection-reports/find-inspection-report/provider/ELS/";

sub get_types
{
    return (
        primary => {
            type_regex => qr/Primary/,
            score_index => 2,
        },
        secondary => {
            type_regex => qr/Secondary/,
            score_index => 9,
        },
        post16 => {
            type_regex => qr/16-18/,
            score_index => 5,
        },
    );
}

my %opts;
my @opts = qw( year=s force flush school=s type=s force silent pidfile! verbose help man );

my ( $dbh, %done );

sub get_id
{
    my $url = shift;
    return unless $url =~ /performance\/school\/(\d+)\//;
    return $1;
}

sub update_school
{
    my $type = shift;
    my $school_name = shift;
    my $school_url = shift;
    my $school_id = shift;
    my $row = shift;

    my %school = ( name => $school_name );
    $log->info( $school_url );
    $school{dcsf_id} = $school_id;
    my $mech = WWW::Mechanize->new();
    $mech->get( $school_url );
    my $html = $mech->content();
    unless ( $html )
    {
        $log->warning( "failed to get $school_url" );
        return;
    }
    my $te = HTML::TableExtract->new();
    $te->parse( $html );
    my @tables = $te->tables;
    my %data;
    foreach my $ts ( $te->tables ) 
    {
        foreach my $r ( $ts->rows ) 
        {
            $r->[1] =~ s/^\s*//;
            $r->[1] =~ s/\s*$//;
            $data{$r->[0]} = $r->[1];
        }
    }
    $school{address} = join( ",", @data{qw( Street Town Postcode )} );
    $school{postcode} = $data{Postcode};
    $school{type} = $data{"School type"};
    $school{URN} = $data{"Unique Reference Number"};
    my $ofsted_url = "$ofsted_base_url/$school{URN}";
    my $content = get( $ofsted_url );
    if ( $content )
    {
        $log->info( $ofsted_url );
        if ( $content =~ m{<span class="ins-judgement[^"]*">(.*?)</span>} )
        {
            $school{OfstedStatus} = $1;
            $log->info( "OfstedStatus: $school{OfstedStatus}" );
        }
    }
    $log->debug( Dumper \%school );
    # SCHDATA={"code":125421,"x":-0.398859565522962,"y":51.3465648147044,"name":"ACS Cobham International School"};
    my ( $lat, $lon ) = $html =~ /SCHDATA={"code":\d+,"x":([-\d\.]+),"y":([-\d\.]+)/;
    if ( $lat && $lon )
    {
        $school{lat} = $lat, $school{lon} = $lon;
    }
    my $score;
    if ( my $i = $types{$type}{score_index} )
    {
        $score = $row->[$i];
        if ( $score )
        {
            $score =~ s/\s*$//; $score =~ s/^\s*//;
            if ( $score =~ /^([\d\.]+)%?$/ )
            {
                $score = $1;
            }
            else
            {
                $log->warning( "'$score' is not numeric" );
                $score = undef;
            }
        }
    }
    else
    {
        $log->warning( "no score index" );
    }
    return unless $score;
    my $select_sql = "SELECT dcsf_id FROM dcsf WHERE dcsf_id = ?";
    my $select_sth = $dbh->prepare( $select_sql );
    $select_sth->execute( $school{dcsf_id} );
    if ( $select_sth->fetchrow )
    {
        my $update_sql = <<EOF;
UPDATE dcsf SET URN = ?, type = ?, school_type = ?, dcsf_url = ?, average_${type} = ?, ofstedstatus = ? WHERE dcsf_id = ?
EOF
        my $update_sth = $dbh->prepare( $update_sql );
        $update_sth->execute( $school{URN}, $type, $school{type}, $school_url, $score, $school{OfstedStatus}, $school{dcsf_id} );
    }
    else
    {
        my $insert_sql = <<EOF;
INSERT INTO dcsf (URN,type,school_type,dcsf_url,average_${type},ofstedstatus,dcsf_id) VALUES(?,?,?,?,?,?)
EOF
        my $insert_sth = $dbh->prepare( $insert_sql );
        $insert_sth->execute( $school{URN}, $type, $school{type}, $school_url, $score, $school{OfstedStatus}, $school{dcsf_id} );
    }
    $done{$school{dcsf_id}} = $school_name;
}

# Main

$opts{pidfile} = 1;
$opts{year} = ( localtime )[5];
$opts{year} += 1900;
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );
$opts{help} && pod2usage( verbose => 1 );
$opts{man} && pod2usage( verbose => 2 );

my $logfile = "/var/log/schoolmap/dcsf.log";

my $dispatcher = Log::Dispatch->new(
    callbacks  => sub {
        my %args = @_;
        my $message = $args{message};
        return uc( $args{level} ) . ": " . scalar( localtime ) . ": $message";
    }
);

Log::Any::Adapter->set( 'Dispatch', dispatcher => $dispatcher );

if( $opts{verbose} )
{
    $dispatcher->add(
        Log::Dispatch::Screen->new(
            name        => 'screen',
            newline     => 1,
            min_level   => 'info',
        )
    );
    $log->info( "logging to $logfile" );
}
else
{
    $dispatcher->add(
        Log::Dispatch::Screen->new(
            name        => 'screen',
            newline     => 1,
            min_level   => 'error',
        )
    );
}

$dispatcher->add(
    my $file = Log::Dispatch::FileRotate->new( 
        name            => 'logfile',
        min_level       => 'info',
        filename        => $logfile,
        mode            => 'append' ,
        DatePattern     => 'yyyy-MM-dd',
        max             => 7,
        newline         => 1,
    ),
);

my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}
$dbh = DBI->connect( 'DBI:mysql:schoolmap', 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
%types = get_types();
@types = $opts{type} ? ( $opts{type} ) : keys %types;
for my $type ( @types )
{
    $log->critical( "unknown type $type" ) and die unless $types{$type};
    $log->info( "getting performance tables for $type" );
    my $mech = WWW::Mechanize->new();
    # $mech->get( 'http://www.dcsf.gov.uk/' );
    $mech->get( 'http://www.education.gov.uk/' );
    unless ( $mech->follow_link( text_regex => qr/performance tables/i ) )
    {
        $log->critical( "failed to find performance tables" ) and die;
    }
    $log->info( "performance tables at " . $mech->uri() );
    my $type_regex = $types{$type}{type_regex};
    $log->info( "Trying $type_regex ..." );
    if ( ! $mech->follow_link( text_regex => $type_regex ) )
    {
        $log->warning( "failed to find link matching $type_regex" );
        next;
    }
    $log->info( $mech->uri() );
    my $success = 1;
    my %url_seen = ();
    while ( $success )
    {
        $success = 0;
        my $url = $mech->uri;
        if ( $url_seen{$url}++ )
        {
            $log->info( "$url already seen" );
            last;
        }
        my $html = $mech->content();
        my $te = HTML::TableExtract->new( keep_html => 1 );
        $te->parse( $html );
        my @tables = $te->tables;
        foreach my $ts ( $te->tables ) 
        {
            foreach my $row ( $ts->rows ) 
            {
                my $school_html = $row->[0];
                next unless $school_html;
                my ( $school_url, $school_name ) = $school_html =~ m{<a .*?href="(.*?)".*?>(.*?)</a>}sim;
                next unless $school_name && $school_url;
                next unless $school_name && $school_name =~ /\S/;
                my $school_id = get_id( $school_url );
                next unless $school_id;
                $log->info( "$school_url, $school_name, $school_id" );
                $school_url = decode_entities( $school_url );
                my $u1 = URI::URL->new( $school_url, $url );
                $school_url = $u1->abs;
                next if $opts{school} && $opts{school} ne $school_name;
                $log->info( "\t$school_name ($school_url)" );
                eval {
                    update_school( $type, $school_name, $school_url, $school_id, $row );
                };
                if ( $@ )
                {
                    $log->error( "$school_name FAILED: $@" );
                }
                else
                {
                    $success = 1;
                }
            }
        }
        if ( $mech->follow_link( text_regex => qr/Next/ ) )
        {
            my $next_url = $mech->uri;
            $log->info( "Next page ($next_url) ..." );
        }
        else
        {
            $log->warning( "no next links" );
            last;
        }
    }
}
$log->info( "$0 ($$) finished" );
