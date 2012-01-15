# $Id: Module.pm,v 1.4 2007/04/27 08:45:44 gonter Exp $

use strict;

package DBF::Unknown1;

my $dbg= 0;
my $dbg_hexdump= 1;
my $dbg_dumper= 1;

sub new
{
  my $class= shift;

  my $obj= {};
  bless $obj, $class;

  $obj->set (@_);

  $obj;
}

sub set
{
  my $obj= shift;
  my %par= @_;

  my %res;
  foreach my $par (keys %par)
  {
    $res{$par}= $obj->{$par};
    $obj->{$par}= $par{$par};
  }

  (wantarray) ? %res : \%res;
}

sub get_array
{
  my $obj= shift;
  my @par= @_;

  my @res;
  foreach my $par (@par)
  {
    push (@res, $obj->{$par});
  }

  (wantarray) ? @res : \@res;
}

sub get_hash
{
  my $obj= shift;
  my @par= @_;

  my %res;
  foreach my $par (@par)
  {
    $res{$par}= $obj->{$par};
  }

  (wantarray) ? %res : \%res;
}

*get= *get_array;

sub parse
{
  my $obj= shift;
  my $fnm= shift;
  my $flatten= shift;

  my @st= stat ($fnm);
  unless (@st)
  {
    print "ATTN: cant find [$fnm]\n";
    return undef;
  }
 
# ZZZ

  my $size= $st[7];
  unless (open (F, $fnm))
  {
    print "ATTN: cant open [$fnm]\n";
    return undef;
  }

  my $buffer;
  my $r_size= sysread (F, $buffer, $size);
  close (F);
  if ($r_size != $size)
  {
    print "ATTN: filesize mismatch: expected $size, got $r_size [continuing]\n";
  }

  my $res= $obj->parse_binary_block ($buffer, $r_size);
  ## print "result: ", main::Dumper ($res);

  # debugging
  if ($dbg)
  {
  my $rec_count= @$res;
  foreach (my $rec_num= 0; $rec_num < $rec_count; $rec_num++)
  {
    my $rec= $res->[$rec_num];
    my $start= $rec->{'start'};
    my $c_subrecs= @{$rec->{'subrecs'}};

    my $end= ($rec_num+1 < $rec_count) ? $res->[$rec_num+1]->{'start'} : $size;
    print "RECORD [$rec_num/$rec_count] subrecs=$c_subrecs start=$start end=$end\n";

    if ($dbg_dumper)
    {
      print main::Dumper ($rec);
      if ($dbg_hexdump && $c_subrecs > 1)
      {
        main::hex_dump (substr ($buffer, $start, $end-$start));
        if ($rec_num+1 < $rec_count)
        {
          main::hex_dump (substr ($buffer, $end, 128));
        }
      }
      print '-'x72, "\n";
    }
  }
  }

  if ($flatten)
  {
    $res= _flatten ($res);
  }
  ## print "result: ", main::Dumper ($res);

  $obj->{'fnm'}= $fnm;
  $obj->{'records'}= $res;
  $obj->{'flatten'}= $flatten;

  $res;
}

sub _flatten
{
  my $res= shift;

  my @res2= ();
  foreach my $rec (@$res)
  {
    foreach my $subrec (@{$rec->{'subrecs'}})
    {
      push (@res2, $subrec);
    }
  }
  
  \@res2;
}

sub parse_binary_block
{
  my $obj= shift;
  my $b= shift;
  my $s= shift;

  my $p= 0; # block pointer
  my @b= split ('', $b);
  # print "b: ", main::Dumper (\@b);

  my @res= ();

  my %cnt= ();

  my $rec= undef;
  my $subrec= undef;
  my $fields= undef;
  my $field= undef;
  for (my $p= 0; $p < $s; $p++)
  {
    my $bp= $b[$p];
    my $c= unpack ('C', $bp);

    if ($c == 0xFF)
    {
      if (defined ($rec))
      {
        push (@$fields, $field) if ($field ne '');
        # print "last rec: ", main::Dumper ($rec);
      }

      $fields= [];
      $subrec= { 'fields' => $fields, 'start' => $p };
      $rec= { 'subrecs' => [ $subrec ], 'start' => $p };
      $field= '';
      push (@res, $rec);
      # print "REC\n"; main::hex_dump (substr ($b, $p, 256));

      $cnt{'rec'}++;
      $cnt{'subrec'}++;
      $cnt{'field'}++;
    }
    elsif ($c == 0x01) # let's assume, this is also a record delimiter, seems like a subdelimter
    { # close current field
      push (@$fields, $field) if ($field ne '');
      $field= '';

      # create new sub record
      $fields= [];
      $subrec= { 'fields' => $fields, 'start' => $p };
      push (@{$rec->{'subrecs'}}, $subrec );

      $cnt{'subrec'}++;
      $cnt{'field'}++;
    }
    elsif ($c == 0x00)
    {
      push (@$fields, $field) if ($field ne '');
      $field= '';

      $cnt{'field'}++;
    }
    elsif ($c == 0xDB || $c == 0x0D || $c == 0x0A)
    {
    }
    else
    {
      $field .= $bp;
    }
  }

  push (@$fields, $field) if ($field ne '');
  print "stats: ", main::Dumper (\%cnt);
  \@res; 
}

1;

__END__

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 REFERENCES

=head1 AUTHOR

