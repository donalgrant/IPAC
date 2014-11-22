package IPAC::AsciiTable;

use feature 'switch';

=pod

IPAC::AsciiTable - read, parse, manipulate, and write data in IPAC Ascii Table format.

=cut

use Data::Dumper;

sub identical_arrays {
  my $a1=shift;
  my $a2=shift;
  return 0 unless scalar(@$a1)==scalar(@$a2);
  for (my $i=0; $i<scalar(@$a1); $i++) { return 0 unless $a1->[$i]==$a2->[$i] }
  return 1;
}
  
sub trim_white { local $_=shift; s/^\s*//; s/\s*$//; return $_ }

sub max { my $m=shift; for (@_) { $m=($_>$m) ? $_ : $m } return $m }

sub marker_capture {
  local $_=shift;
  my $m=shift() || '|';  # optionally change column marker character
  my @o;
  for (my $i=0; $i<length($_); $i++) { push @o,$i if substr($_,$i,1) eq $m }
  return @o;
}

sub column_capture {
  my $s=shift; # string from which to extract columns
  my @m=@_;    # column marker index numbers
  my @r;       # results to be returned
  for (my $i=0; $i<scalar(@m)-1; $i++) { push @r, substr($s,$m[$i]+1,$m[$i+1]-$m[$i]-1) }
  return @r;
}


=pod

  S Original source
  C comments 
  K key/value pairs
  H headings for each column
  D Data (by labeled columns)
  T type for each column
  U units for each column
  N null values for each column
  M Marker positions for columns

=cut

sub new_empty {
  my $class=shift;
  my %T;
  @T{qw( S C K H D T U N M )}=();
  return bless \%T, $class;
}

# modify this to do "open_file" and "read_line" calls
# so that we don't have to read in the entire file at
# once if it's too large to do so?

sub new_from_file {
  my $class=shift;
  my $file=shift;
  my $T=new_empty($class,$file);
  # read file here
  my $fh;
  open($fh,'<',$file) or die "Couldn't open $file for read:  $!";
  my @m=qw( M H T U N );  # keep track of order of column info
  my %c;  for (@m) { $c{$_}=0 }
  while (<$fh>) {
    chomp;
    push @{$T->{S}}, $_;
    # need validation on the file contents -- correct file formats are assumed below
    given ($_) {
      when (/^[\\]?\s*$/) { next }  # ignore blank lines
      when (/^\\\s(.*)$/) { push @{$T->{C}}, $1 }
      when (/^\\(\S+)\s*[=]\s*(.*)$/) { $T->{K}{$1}=$2 }
      when (/^[|]/) { 
	my @cm=marker_capture($_,'|');
	if ($c{M}) { 
	  unless (identical_arrays(\@cm,\@{$T->{M}})) {
	    print Dumper($T),"\n";
	    die "inconsistent column markers; line is:\n$_\n";
	  }
	} else { $T->{M}=\@cm; $c{M}=1 }
	my @c=map { trim_white($_) } column_capture($_,@{$T->{M}});
	for my $m (@m) {
	  next if $c{$m};  # already have this column info
	  $T->{$m}=\@c;    # capture new column info
	  $c{$m}=1;        # mark that we have this column info
	  last;            # only one kind of info per row
	}
      }
      default {  # assume a data line, and sort into columns
	unless ($c{H} && $c{T}) {
	  print Dumper($T),"\n";
	  die "Apparent data line prior to defining mandatory headers:\n$_\n" 
	}
	my @c=map { trim_white($_) } column_capture($_,@{$T->{M}});
	for my $h (@{$T->{H}}) { push @{$T->{D}{$h}}, shift(@c) }
      }
    }
  }
  return $T;
}

sub new {
my $class=shift;
my $filename=shift;
return new_from_file($class,$filename) if defined $filename;
return new_empty($class);
}

sub n_cols { my $self=shift; return scalar(@{$self->{H}}) }
sub col_name { my $self=shift; return $self->{H}[shift()] }
sub n_data_rows { my $self=shift; return scalar(@{$self->{D}{$self->col_name(0)}}) }

sub row { # get full data row (specified by number)
  my $self=shift;
  my $r=shift;
  my @col_names=scalar(@_) ? @_ : @{$self->{H}};
  my @o;
  for (@col_names) { push @o, $self->{D}{$_}[$r] }
  return @o;
}

sub col {  # get full data column (specified by name)
  my $self=shift;
  my $c=shift;
  return @{$self->{D}{$c}};
}

sub extract {  # get data sub-table:  all rows for a specified list of column names
  my $self=shift;
  my %t;
  for (@_) { push @{$t{$_}}, $self->col($_) }
  return \%t;
}

sub add_col { # add a new column of data
  my $self=shift;
  my ($h,$t,$u,$n,$d)=@_;
  $self->{D}{$h}=();
  for (@$d) { push @{$self->{D}{$h}}, $_ }
  push @{$self->{H}},$h;
  push @{$self->{T}},$t;
  push @{$self->{U}},$u if defined $u;
  push @{$self->{N}},$n if defined $n;
  # get new column width from data values
  my $max_col_length=max( map { 1+length($_) } (@$d,$h,$t,(defined $u ? $u : ''),(defined $n ? $n : '')) );
  push @{$self->{M}},$max_col_length+$self->{M}[-1];
}

sub write_row {
  my $self=shift;
  my $fh=shift; # file handle
  my $A=shift;  # data array
  my $d=shift;  # delimeter
  # need to verify that number of markers and number of 
  # columns line up here...
  for my $i (0..scalar(@$A)-1) {
    my $fw=$self->{M}[$i+1]-$self->{M}[$i]-1;
    print $fh sprintf("$d%${fw}s",$A->[$i]);
  }
  print $d,"\n";
}

sub write {  # write out an ascii table
  my $self=shift;
  my $fh=shift;
  for (sort { $a cmp $b } keys %{$self->{K}}) {
    print $fh '\\',$_,' = ',$self->{K}{$_},"\n";
  }
  $self->write_row($fh,$self->{H},'|');
  $self->write_row($fh,$self->{T},'|');
  $self->write_row($fh,$self->{U},'|') if defined $self->{U};
  $self->write_row($fh,$self->{N},'|') if defined $self->{N};
  for (0..$self->n_data_rows()-1) {
    $self->write_row($fh,[ $self->row($_) ],' ');
  }
}

return 1;
