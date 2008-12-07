#! /usr/bin/perl -T
# Web wrapper for Nancy
# (c) 2002-2008 Reuben Thomas (rrt@sc3d.org, http://rrt.sc3d.org)
# Distributed under the GNU General Public License

$ENV{PATH} = '/usr/local/bin:/bin:/usr/bin';

use strict;
use warnings;

use CGI qw(:standard);
use CGI::Carp 'fatalsToBrowser';
use CGI::Util qw(unescape);

use vars qw($BaseUrl);

# Root of site relative to root of server
$BaseUrl = "/";
# Root of source files
$DocumentRoot = "/var/www";

# Untaint the given value
# FIXME: Use CGI::Untaint
sub untaint {
  my ($var) = @_;
  return if !defined($var);
  $var =~ /^(.*)$/ms;           # get untainted value in $1
  return $1;
}

my $page = unescape(url());
my $base = url(-base => 1);
$base = untaint($base);
$page =~ s|^$base$BaseUrl||;
$page =~ s|^/||;

# Perform the request
my $headers = {};
$headers->{-charset} = "utf-8";
open(IN, "-|", "weavefile.pl", $DocumentRoot, $page, "template.html");
my $out = do { local $/, <IN> };
close IN;
print header($headers) . $out;
