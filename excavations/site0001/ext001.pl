#!/usr/local/bin/perl
# $Id: script.pl,v 1.6 2007/12/12 15:19:17 gonter Exp $

=pod

=head1 NAME

dummy script doing nothing

=cut

use strict;

use lib '.';
use Encode;
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

  my %cats;
  &read_cat (\%cats, 'pers', 'PERS.CAT');
  &read_cat (\%cats, 'werk', 'WERK.CAT');
  # print "cat: ", Dumper (\%cats); exit;

  my %all;
  # === Table PERS.DAT =========================
  my $db_pers= new DBF::Unknown1;
  $db_pers->parse ('PERS.DAT', 1);
  my $cnt= @{$db_pers->{'records'}};
  # print "db_pers: recs=[$cnt] ", Dumper ($db_pers);

  my $st_pers= &analyze_records ($db_pers, \%all, 'pers');
  my $cnt_pers= scalar keys %all;
  print __LINE__, " cnt_pers=[$cnt_pers]\n";
  # print "stats pers: ", Dumper ($st_pers);

  # === Table TIT.DAT =========================
  my $db_tit= new DBF::Unknown1;
  $db_tit->parse ('TIT.DAT', 1);
  my $cnt= @{$db_tit->{'records'}};
  # print "db_tit: recs=[$cnt] ", Dumper ($db_tit);

  my $st_tit= &analyze_records ($db_tit, \%all, 'title');
  my $cnt_tit= scalar keys %all;
  print __LINE__, " cnt_tit=[$cnt_tit]\n";

  # === Statistics ==========================
  # print "stats tit: ", Dumper ($st_tit);
  &combine_stats (\%cats, 'pers' => $st_pers, 'title' => $st_tit);

  open (DUMP, '>out.dump') or die;
  print "writing out.dump\n";
  print DUMP "cats: ", Dumper (\%cats);
  print DUMP "all: ", Dumper (\%all);
  close (DUMP);

  &show_db (\%cats, \%all);

}

sub show_db
{
  my $cats= shift;
  my $db= shift;

  my $UID= &get_UID;
  my @sections= ();
  foreach my $id (sort { $a <=> $b } keys %$db)
  {
    my $epub_id= sprintf ("Author_%04d", $id);
    my $fnm_xhtml= sprintf ("Text/Author_%04d.xhtml", $id);
    my $fnm_out= 'out/OEBPS/' . $fnm_xhtml;
    open (FO, '>', $fnm_out) or die;

    my $section=
    {
      'id' => $epub_id,
      'file' => $fnm_xhtml,
    };

    push (@sections, $section);
    print "writing $fnm_xhtml [$fnm_out]\n";

    my $obj= $db->{$id};
    # print "obj($id}: ", Dumper ($obj);
    # note: $obj is a record for one person (with multiple versons) with his/her works

    my @p_recs= @{$obj->{'pers'}};

    # print "="x72, "\n";
    my ($author, $auth_rec)= &prepare_one_sub_record ($cats, $p_recs[$#p_recs]);
    if (defined ($author))
    {
      $section->{'title'}= $author;
    }

    my $tit= $obj->{'title'};
    # print "title: ", Dumper ($tit);
    my @books;
    foreach my $t (sort { $a <=> $b } keys %$tit)
    {
      my @t_recs= @{$tit->{$t}};
      # print FO "-"x72, "\n";
      my ($book_title, $book_rec)= &prepare_one_sub_record ($cats, $t_recs[$#t_recs]);
      push (@books, [ $book_title, $book_rec ]);
    }

print FO <<EOX;
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
  "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>$author</title>
</head>

<body>
<h1>$author</h1>
EOX

    &print_one_table (*FO, $auth_rec);
    foreach my $book (@books)
    {
      print FO "<h2>$book->[0]</h2>\n";
      &print_one_table (*FO, $book->[1]);
    }

print FO <<EOX;
</body>
</html>
EOX
    close (FO);
  }
  
  &write_content_opf ($UID, \@sections);
  &write_toc_ncx ($UID, \@sections);
}

sub print_one_table
{
  local *FO= shift;
  my $t= shift;

print FO <<EOX;
  <table border="1" cellpadding="1" cellspacing="1">
    <tbody>
EOX

  foreach my $row (@$t)
  {
print FO <<EOX;
<tr>
  <td>$row->[0]</td>
  <td>$row->[1]</td>
  <td>$row->[2]</td>
</tr>
EOX

  }

print FO <<EOX;
    </tbody>
  </table>

EOX

}

sub prepare_one_sub_record
{
  my $cats= shift;
  my $rec= shift;

  # print "rec: ", Dumper ($rec);

  my $t= undef;
  my @l= ();
  foreach my $key (sort { $a <=> $b } keys %$rec)
  {
    my $s= join ('/', keys %{$cats->{$key}->{_}});
    my $av= $rec->{$key}->[0];
    $t= $av if ($key == 100 || $key ==  212);
    push @l, [ sprintf ("%03d", $key), $s, $av ];
  }

  ( $t, \@l );
}

sub combine_stats
{
  my $cats= shift;
  my %v= @_;

  my @tables= sort keys %v;
  printf ("%03s %-16s:", 'key', 'label');
  foreach my $table (@tables) { printf ("%6s", $table); }
  print "\n";

  foreach my $key (sort { $a <=> $b } keys %$cats)
  {
    my $x= $cats->{$key};
    my $s= join ('/', keys %{$x->{_}}); # TODO: collect this into something more handy

    printf ("%03d %-16s:", $key, $s);
    foreach my $table (@tables)
    {
      my $c= $v{$table}->{$key};
      printf ("%6d", $c);
    }

    print "\n";
  }
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
      $field= encode ('utf-8', decode ('cp850', $field));
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

sub read_cat
{
  my $cat= shift;
  my $section= shift;
  my $fnm= shift;

  open (FI, $fnm) or die;
  my $found= 0;
  while (<FI>)
  {
    chop;
    s/\r//g;
    # print ">> [$_]\n";
    if (m/^\s*$/) { next; }
    elsif (m/#KATEGORIEN#/)
    {
      $found= 1;
    }
    elsif ($found)
    {
      # print ">>> [$_]\n";
      if (m#(\d{3}) \"\s*(.+)\"\!(.*)#)
      {
        my ($key, $str, $x)= ($1, $2, $3);
        my $ty= ($x =~ m#\s*([A-Z])#) ? $1 : '?';
        my $ty= ($x =~ m#\s*([A-Z])#) ? $1 : '?';
	$str= encode ('utf-8', decode ('cp850', $str));
	$cat->{$key}->{_}->{$str}++;
	$cat->{$key}->{$section}= [ $str, $ty ];
      }
    }

  }
  close (FI);
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

# EPUB generation ========================================

sub get_UID
{
  my $t= time ();
  my $UID1= "f48d29a4-44f4-4834-b5fb-f21c33f90332";
  my $UID2= sprintf ("f48d29a4-44f4-4834-b5fb-f2%08lx33", $t);
  print "uid1=[$UID1]\n";
  print "uid1=[$UID2]\n";
  $UID2;
}

sub write_content_opf
{
  my $uid= shift;
  my $sections= shift;

  open (FO, '>out/OEBPS/content.opf') or die;
  print "writing out/OEBPS/content.opf\n";
  print FO <<EOX;
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:identifier id="BookId" opf:scheme="UUID">urn:uuid:$uid</dc:identifier>
    <dc:title>bismas</dc:title>
    <dc:creator opf:role="aut">unknown</dc:creator>
    <dc:language>de</dc:language>
    <meta content="0.5.3" name="Sigil version" /><!-- change this! -->
  </metadata>
  <manifest>
    <item href="toc.ncx" id="ncx" media-type="application/x-dtbncx+xml" />
EOX

  foreach my $sec (@$sections)
  {
    print FO <<EOX;
    <item href="$sec->{'file'}" id="$sec->{'id'}" media-type="application/xhtml+xml" />
EOX
  }

  print FO <<EOX;
  </manifest>
  <spine toc="ncx">
EOX

  foreach my $sec (@$sections)
  {
    print FO <<EOX;
    <itemref idref="$sec->{'id'}" />
EOX
  }

  print FO <<EOX;
  </spine>
</package>
EOX
  close (FO);
}

sub write_toc_ncx
{
  my $uid= shift;
  my $sections= shift;

  open (FO, '>out/OEBPS/toc.ncx') or die;
  print "writing out/OEBPS/toc.ncx\n";
  print FO <<EOX;
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN"
   "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
<head>
   <meta name="dtb:uid" content="urn:uuid:$uid" />
   <meta name="dtb:depth" content="0" />
   <meta name="dtb:totalPageCount" content="0" />
   <meta name="dtb:maxPageNumber" content="0" />
</head>
<docTitle>
   <text>Unknown</text>
</docTitle>
<navMap>
EOX

  my $i= 0;
  foreach my $sec (@$sections)
  {
    $i++;
    my $navLabel_text= (exists ($sec->{'title'})) ? $sec->{'title'} : $sec->{'id'};

  print FO <<EOX;
<navPoint id="navPoint-$i" playOrder="$i">
  <navLabel>
    <text>$navLabel_text</text>
  </navLabel>
  <content src="$sec->{'file'}" />
</navPoint>
EOX
  }

  print FO <<EOX;
</navMap>
</ncx>
EOX
}

=cut

=head1 AUTHOR

Firstname Lastname <address@example.org>

=over

