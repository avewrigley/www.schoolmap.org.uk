#!/usr/bin/perl
#set filetype=perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;
use warnings;

use FindBin qw( $Bin );
use WWW::Mechanize;
use LWP::UserAgent;
use Pod::Usage;
use Getopt::Long;
use Proc::Pidfile;
use HTML::Entities;
require HTML::TableExtract;
use DBI;
use lib "$Bin/lib";
require CreateSchool;
use Acronyms;
use URI::URL;
use Data::Dumper;

use vars qw( %types @types );

my $postcode_regex = qr{^([A-PR-UWYZ0-9][A-HK-Y0-9][AEHMNPRTVXY0-9]?[ABEHMNPRVWXY0-9]? {1,2}[0-9][ABD-HJLN-UW-Z]{2}|GIR 0AA)$}i;

sub get_types
{
    my $year = shift;
    return (
        primary => {
            type_regex => qr/Primary/,
            pupil_key => 'Total number of pupils on roll (all ages)',
            score_index => 2,
        },
        secondary => {
            type_regex => qr/Secondary/,
            pupil_key => 'Total number of pupils on roll (all ages)',
            score_index => 9,
        },
        post16 => {
            type_regex => qr/16-18/,
            pupil_key => 'Total number of pupils on roll (all ages)',
            score_index => 5,
        },
    );
}

my %opts;
my @opts = qw( year=s force flush region=s la=s school=s type=s force silent pidfile! verbose );

my ( $dbh, $school_creator, $acronyms, %done );

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
    warn $school_url;
    $school{dcsf_id} = $school_id;
    my $mech = WWW::Mechanize->new();
    $mech->get( $school_url );
    my $html = $mech->content();
    unless ( $html )
    {
        warn "failed to get $school_url\n";
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
    warn Dumper \%school;
    # SCHDATA={"code":125421,"x":-0.398859565522962,"y":51.3465648147044,"name":"ACS Cobham International School"};
    my ( $lat, $lon ) = $html =~ /SCHDATA={"code":\d+,"x":([-\d\.]+),"y":([-\d\.]+)/;
    if ( $lat && $lon )
    {
        $school{lat} = $lat, $school{lon} = $lon;
    }
    $school_creator->create_school( 'dcsf', %school );
    my $pupil_key = $types{$type}{pupil_key};
    my $pupils = $data{$pupil_key};
    warn "no pupils under $pupil_key" unless $pupils;
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
                # warn "'$score' is not numeric\n";
                $score = undef;
            }
        }
    }
    else
    {
        warn "no score index\n";
    }
    return unless $score;
    my @acronyms = $html =~ m{<a .*?class="acronym".*?>(.*?)</a>}gism;
    #warn "\t\t\t(lat:$lat, lon:$lon, score:$score, pupils:$pupils, acronyms:@acronyms)\n";
    my $dsth = $dbh->prepare( "DELETE FROM acronym WHERE dcsf_id = ?" );
    my $isth = $dbh->prepare( "INSERT INTO acronym ( dcsf_id, acronym, type ) VALUES ( ?,?,? )" );
    $dsth->execute( $school{dcsf_id} );
    my $select_sql = "SELECT dcsf_id FROM dcsf WHERE dcsf_id = ?";
    my $select_sth = $dbh->prepare( $select_sql );
    $select_sth->execute( $school{dcsf_id} );
    if ( $select_sth->fetchrow )
    {
        my $update_sql = <<EOF;
UPDATE dcsf SET type = ?, school_type = ?, dcsf_url = ?, average_${type} = ?, pupils_${type} = ? WHERE dcsf_id = ?
EOF
        my $update_sth = $dbh->prepare( $update_sql );
        $update_sth->execute( $type, $school{type}, $school_url, $score, $pupils, $school{dcsf_id} );
    }
    else
    {
        my $insert_sql = <<EOF;
INSERT INTO dcsf (type,school_type,dcsf_url,average_${type},pupils_${type},dcsf_id) VALUES(?,?,?,?,?,?)
EOF
        my $insert_sth = $dbh->prepare( $insert_sql );
        $insert_sth->execute( $type, $school{type}, $school_url, $score, $pupils, $school{dcsf_id} );
    }
    $done{$school{dcsf_id}} = $school_name;
}

# Main

$opts{pidfile} = 1;
$opts{year} = ( localtime )[5];
$opts{year} += 1900;
GetOptions( \%opts, @opts ) or pod2usage( verbose => 0 );
my $pp;
if ( $opts{pidfile} )
{
    $pp = Proc::Pidfile->new( silent => $opts{silent} );
}
my $logfile = "$Bin/logs/dcsf.log";
$dbh = DBI->connect( 'DBI:mysql:schoolmap', 'schoolmap', 'schoolmap', { RaiseError => 1, PrintError => 0 } );
$school_creator = CreateSchool->new( dbh => $dbh );
$acronyms = Acronyms->new();
unless ( $opts{verbose} )
{
    open( STDERR, ">$logfile" ) or die "can't write to $logfile\n";
}
%types = get_types( $opts{year} );
@types = $opts{type} ? ( $opts{type} ) : keys %types;
for my $type ( @types )
{
    die "unknown type $type\n" unless $types{$type};
    warn "getting performance tables for $type\n";
    my $mech = WWW::Mechanize->new();
    # $mech->get( 'http://www.dcsf.gov.uk/' );
    $mech->get( 'http://www.education.gov.uk/' );
    unless ( $mech->follow_link( text_regex => qr/performance tables/i ) )
    {
        die "failed to find performance tables\n";
    }
    warn "performance tables at ", $mech->uri(), "\n";
    my $type_regex = $types{$type}{type_regex};
    warn "Trying $type_regex ...\n";
    if ( ! $mech->follow_link( text_regex => $type_regex ) )
    {
        warn "failed to find link matching $type_regex!\n";
        next;
    }
    warn $mech->uri(), "\n";
    my $success = 1;
    my %url_seen = ();
    while ( $success )
    {
        $success = 0;
        my $url = $mech->uri;
        if ( $url_seen{$url}++ )
        {
            warn "$url already seen\n";
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
                warn "$school_url, $school_name, $school_id";
                $school_url = decode_entities( $school_url );
                my $u1 = URI::URL->new( $school_url, $url );
                $school_url = $u1->abs;
                next if $opts{school} && $opts{school} ne $school_name;
                # warn "$type\t$region_name\t$la_name\t$school_name ($school_url)\n";
                warn "\t$school_name ($school_url)\n";
                eval {
                    update_school( $type, $school_name, $school_url, $school_id, $row );
                };
                if ( $@ )
                {
                    warn "$school_name FAILED: $@\n";
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
            warn "Next page ($next_url) ...\n";
        }
        else
        {
            warn "no next links\n";
            last;
        }
    }
}
warn "$0 ($$) finished\n";
