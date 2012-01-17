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

  &main_function ($arg);

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

  my %all= ();

  my $db_pers= new DBF::Unknown1;
  $db_pers->parse ('PERS.DAT', 1);
  my $cnt= @{$db_pers->{'records'}};
  # print "db_pers: recs=[$cnt] ", Dumper ($db_pers);
  my $st_pers= &analyze_records ($db_pers, \%all, 'pers');

  print "stats pers: ", Dumper ($st_pers);

  my $cnt_pers= scalar keys %all;
  print __LINE__, " cnt=[$cnt_pers]\n";

  my $db_tit= new DBF::Unknown1;
  $db_tit->parse ('TIT.DAT', 1);
  my $cnt= @{$db_tit->{'records'}};
  # print "db_tit: recs=[$cnt] ", Dumper ($db_tit);
  my $st_tit= &analyze_records ($db_tit, \%all, 'title');

  print "stats tit: ", Dumper ($st_tit);

  my $cnt_pers= scalar keys %all;
  print __LINE__, " cnt=[$cnt_pers]\n";

  print "all: ", Dumper (\%all);
}

# transform records into a more structured format
sub analyze_records
{
  my $db= shift;
  my $out= shift; # collection of all records, ordered by Ident.Nr.
  my $part= shift;

  my %stats= ();
  foreach my $rec (@{$db->{'records'}})
  {
    # print "rec: ", Dumper ($rec);
    my %out_record= ();
    my $ident_nr= undef;

    foreach my $field (@{$rec->{'fields'}})
    {
      # correct two broken fields
         if ($field =~ m#^28  (.+)#) { $field= '280 ' . $1 }
      elsif ($field =~ m#^2457(.+)#) { $field= '245 ' . $1 }

      if ($field =~ m#^(\d\d\d) (.+)#)
      {
        my ($key, $val)= ($1, $2);
	push (@{$out_record{$key}}, $val);
	$val=~ s# *$##;
	$stats{$key}++;

	if ($key == "000")
	{
          # ident_nr field looks like this '000 555.001'
	  $val =~ s# ##g; # apparently, there are entries with blanks in it...

	  if ($val =~ /^(\d+)$/ && $part eq 'pers')
	  {
	    $ident_nr= $1+0;
	    # print "ident_nr: #1 [$val] => [$ident_nr]\n";
            push (@{$out->{$ident_nr}->{'pers'}}, \%out_record);
	  }
	  elsif ($val =~ /^(\d+)\.(\d+)$/ && $part eq 'title')
	  {
	    my ($k1, $k2)= ($1, $2);
	    $k1 += 0;
	    $k2 += 0;
	    $ident_nr= $k1+0;

	    # print "ident_nr: #2 [$val] => [$k1], [$k2] => [$ident_nr]\n";
            push (@{$out->{$ident_nr}->{'title'}->{$k2}}, \%out_record);
	  }
	  else
	  {
            print "ATTN: unknown ident_nr format! [$field]\n";
            print "rec: ", Dumper ($rec);
	  }
	}
      }
      else
      {
        print "ATTN: unknown field format! [$field]\n";
        print "rec: ", Dumper ($rec);
      }
    }

    unless (defined ($ident_nr))
    {
      print "ATTN: no ident nr found in record: ", Dumper ($rec);
      next;
    }

  }

  \%stats;
}

sub analyze_pers
{
  my $db_pers= shift;

  # order persons by Ident.Nr.
  foreach my $rec (@{$db_pers->{'records'}})
  {
  }

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

