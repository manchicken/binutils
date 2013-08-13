use strict;
use warnings;

package BinWorker;

use Convert::Binary::C;
use IO::File;
use Readonly;

sub new {
  my ($pkg, %opts) = @_;

  my $self = {%opts};
  $self->{_fh} ||= undef;
  $self->{_fname} ||= undef;

  return bless($self, $pkg);
}

sub DESTROY {
  my ($self) = @_;

  if ($self->is_data_file_open()) {
    $self->close_data_file();
  }
}

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

  my $conf = BinWorker::Config->instance();

  my $c = Convert::Binary::C->new(
    Include => [$self->get_include_directories()], 
    ByteOrder => $conf->('endian'), 
    Alignment => $conf->('struct_alignment'), 
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

sub array_index_sorter {
  my ($a, $b) = @_;

  my $a_idx = undef;
  my $b_idx = undef;

  $a_idx = $1 if ($a =~ m/\[(\d+)\]/);
  $b_idx = $1 if ($b =~ m/\[(\d+)\]/);

  warn "value 'a' ($a) doesn't appear to have an index (e.g. not in format foo[123])" unless (defined $a_idx);
  warn "value 'b' ($b) doesn't appear to have an index (e.g. not in format foo[123])" unless (defined $b_idx);

  return ($a_idx <=> $b_idx);
}

sub array_is_string {
  my ($pkg, $array) = @_;

  if (scalar(@$array) <= 1) {
    return 0;
  }

  for my $element (@$array) {
    my ($name) = keys($element);
    my $info = $element->{$name};
    return 0 if ($info->{type} ne 'char');
  }

  return 1;
}

sub get_struct_metadata {
  my ($self, $struct_name) = @_;

  my $c = $self->_my_data();
  $self->{_converter} = $c;

  my %to_return = ();

  $to_return{size} = $c->sizeof($struct_name);

  my %members = ();

  for my $member ($c->member($struct_name)) {
    my $type = $c->typeof("$struct_name$member");
    my @path = split(m/\./, "$struct_name".$member);
    my $main_name = join('.', @path);
    my $is_array = ($main_name =~ m/\[(\d+)\]$/);
    my $idx = $1;

    $idx = 0 if (!defined($idx) || $idx !~ m/^\d+$/s);

    $main_name =~ s/\[\d+\]//g;

    $members{$main_name} ||= {min_index => 0, max_index => 0};

    my $ptr = $members{$main_name};

    $ptr->{is_array} = $is_array || 0;
    $ptr->{elements} ||= [];

    $ptr->{max_index} = $idx if ($idx > $ptr->{max_index});
    $ptr->{min_index} = $idx if ($idx < $ptr->{min_index});
    $ptr->{type} = $type;

    if ($ptr->{is_array}) {
      # Sort the elements by index
      @{$ptr->{elements}} = sort { array_index_sorter((keys(%$a))[0], (keys(%$b))[0]) }
        @{$ptr->{elements}}, {$path[-1] => {type=>$type}};

      # Determine whether or not the array is a string (char array).
      $ptr->{is_string} = $self->array_is_string($ptr->{elements});
    }
  }

  $to_return{members} = \%members;

  return \%to_return;
}

sub is_data_file_open {
  my ($self) = @_;

  return (exists($self->{_fh}) && ref($self->{_fh}));
}

sub open_data_file {
  my ($self, $file) = @_;

  if ($self->is_data_file_open() && $file eq $self->{_fname}) {
    return 1;
  } elsif ($self->is_data_file_open()) {
    warn "Another file is already open!";
    return 0;
  }

  my $infile = IO::File->new($file, O_RDONLY) ||
    die "Failed to open file '$file' for reading: $!";

  $infile->binmode();

  $self->{_fh} = $infile;
  $self->{_fname} = $file;

  return 1;
}

sub close_data_file {
  my ($self) = @_;

  $self->{_fh}->close() if ($self->is_data_file_open());
  $self->{_fh} = undef;

  return;
}

sub validate_data_file {
  my ($self, $file, $struct_name) = @_;

  my $byte_count = 0;
  my $meta = $self->get_struct_metadata($struct_name);

  if ($self->open_data_file($file)) {
    # Read all the bytes, then divide by the record lenght to see if it is valid.
    my $fh = $self->{_fh};

    my $orig_pos = $fh->tell();

    $fh->seek(0, SEEK_SET);

    my $buff = undef;
    my $bytes = 0;
    while (!$fh->eof()) {
      $bytes = $fh->read($buff, 1024);
      if (!defined($bytes)) {
        die "Failed to read the file: $!";
      }
      $byte_count += $bytes;
    }

    $fh->seek($orig_pos, SEEK_SET);

    return (($byte_count % $meta->{size}) == 0);
  }

  return 0;
}

sub get_next_record {
  my ($self, $struct_name) = @_;

  my $buff = undef;
  my $bytes = 0;
  my $meta = $self->get_struct_metadata($struct_name);

  if ($self->is_data_file_open()) {
    # Read all the bytes, then divide by the record lenght to see if it is valid.
    my $fh = $self->{_fh};
    if ($fh->eof()) {
      return undef;
    }

    $bytes = $fh->read($buff, $meta->{size});
    if (!defined($bytes)) {
      die "Failed to read the file: $!";
    }

    my $c = $self->{_converter} || die "Failed to get converter!";

    # Tag some types...
    for my $field_key (keys $meta->{members}) {
      my $field = $meta->{members}->{$field_key};
      if ($field->{is_string}) {
        # print "Tagging $field_key as string...\n";
        $c->tag($field_key, Format=>'String');
      }
    }

    my $to_return = $c->unpack($struct_name, $buff);

    return $to_return if ($to_return);

    die "Failed to unpack '$struct_name'.";
  } else {
    die "No data file open.";
  }

  return undef;
}
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

# Config handling...
{
  package BinWorker::Config;
  use FindBin qw{$Bin};
  use IO::File;
  use JSON;

  our $_config = undef;

  sub instance {
    my ($pkg, $config_file) = @_;

    $config_file ||= "$Bin/../config/config.json";

    if (defined($_config)) {
      return $_config;
    }

    local $/ = undef;
    my $inconf = IO::File->new($config_file, O_RDONLY) ||
      die "Failed to open log file '$config_file' for reading: $!";
    my $json_text = <$inconf>;
    $inconf->close();

    my $json_data = decode_json($json_text);
    $json_text = undef;

    $_config = sub {
      my ($key, $default) = @_;

      if (!exists($json_data->{$key})) {
        return $default;
      }

      return $json_data->{$key};
    };

    return $_config;
  }
};

1;
