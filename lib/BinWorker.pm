# /*
use strict;
use warnings;

package BinWorker;

use Convert::Binary::C;
use IO::File;
use Readonly;

sub new {
  my ($pkg, %opts) = @_;

  my $self = {%opts};

  return bless($self, $pkg);
}

Readonly our $STRUCT_BYTE_ALIGNMENT => 4;
Readonly our $ENDIANNESS => 'LittleEndian';

sub get_include_directories {
  my ($self) = @_;

  my @to_return = ();

  if (exists($ENV{CPATH})) {
    push(@to_return, $ENV{CPATH});
  }
  if (exists($self->{include})) {
    push(@to_return, $self->{include});
  }

  return @to_return;
}

sub get_c_type_data {
  my ($self) = @_;

  if (exists($self->{header})) {
    return {header => $self->{header}};
  } elsif (exists($self->{code})) {
    return {code => $self->{code}};
  }

  die "No C data defined. Please use key 'header' or 'code' to define C type data.";
}

sub _my_data {
  my ($self) = @_;

  my $c = Convert::Binary::C->new(
    Include => [$self->get_include_directories()], 
    ByteOrder => $ENDIANNESS, 
    Alignment=>$STRUCT_BYTE_ALIGNMENT, 
    OrderMembers=>1
  );

  # Get the data to work with...
  my $c_type_data = $self->get_c_type_data();
  if (exists($c_type_data->{header})) {
    $c = $c->parse_file($c_type_data->{header});
  } elsif (exists($c_type_data->{code})) {
    $c = $c->parse($c_type_data->{code});
  }

  return $c;
}

sub get_struct_metadata {
  my ($self, $struct_name) = @_;

  my $c = $self->_my_data();

  my %to_return = ();

  $to_return{size} = $c->sizeof($struct_name);

  return \%to_return;
}

# $c->tag($struct_name.'.two', Format => 'String');
# my $sizeof = $c->sizeof($struct_name);
# print "Sizeof($struct_name) is: $sizeof\n";

# my $infile = IO::File->new("$Bin/theoutput.dat", O_RDONLY) || die "Can't open file: $!";
# $infile->binmode();
# my $bindata = "";
# while ($infile->sysread($bindata, $sizeof, 0)) {
#   my $structval = $c->unpack($struct_name, $bindata);
#   print "Two: ".$structval->{two}."\n";

#   # eval { print hexdump($bindata); };
#   # if ($@) { print $@; }
#   print Dumper($structval);
# }


1;
# */