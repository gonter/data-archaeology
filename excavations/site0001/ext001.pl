#!/usr/local/bin/perl
# $Id: script.pl,v 1.6 2007/12/12 15:19:17 gonter Exp $

=pod

=head1 NAME

dummy script doing nothing

=cut

use strict;

use lib '.';
use Data::Dumper;
$Data::Dumper::Indent= 1;

use DBF::Unknown1;

my $x_flag= 0;

my @JOBS;
my $arg;
while (defined ($arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
       if ($arg eq '-h') { &usage; exit (0); }
    elsif ($arg eq '-x') { $x_flag= 1; }
    elsif ($arg eq '--') { push (@JOBS, @ARGV); @ARGV= (); }
    else { &usage; }
    next;
  }

  push (@JOBS, $arg);
}

while (defined ($arg= shift (@JOBS)))
{
  &main_function ($arg);
}

exit (0);

sub usage
{
  print <<EOX;
usage: $0 [-opts] pars

options:
-h  ... help
-x  ... set x flag
--  ... remaining args are parameters
EOX
}

# ----------------------------------------------------------------------------
sub main_function
{
  my $fnm= shift;
  print "main_function: $fnm\n";

  my $db= new DBF::Unknown1;
  $db->parse ($fnm, 1);
  my $cnt= @{$db->{'records'}};
  print "db: recs=[$cnt] ", Dumper ($db);
}

# ----------------------------------------------------------------------------
sub hex_dump
{
  my $data= shift;
  local *FX= shift || *STDOUT;

  my $off= 0;
  my ($i, $c, $v);

  while ($data)
  {
    my $char= '';
    my $hex= '';
    my $offx= sprintf ('%08X', $off);
    $off += 0x10;

    for ($i= 0; $i < 16; $i++)
    {
      $c= substr ($data, 0, 1);

      if ($c ne '')
      {
        $data= substr ($data, 1);
        $v= unpack ('C', $c);
        $c= '.' if ($v < 0x20 || $v >= 0x7F);

        $char .= $c;
        $hex .= sprintf (' %02X', $v);
      }
      else
      {
        $char .= ' ';
        $hex  .= '   ';
      }
    }

    print FX "$offx $hex |$char|\n";
  }
}

=cut

=head1 AUTHOR

Firstname Lastname <address@example.org>

=over

