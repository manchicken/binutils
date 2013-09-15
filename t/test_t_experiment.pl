#!/usr/bin/env perl
use strict;use warnings;

use Convert::Binary::C;
use FindBin qw{$Bin};
use Data::Dumper;
use IO::File;
use Readonly;

Readonly our $STRUCT_BYTE_ALIGNMENT => 4;
Readonly our $ENDIANNESS => 'LittleEndian';

my $c = Convert::Binary::C->new(
  Include => [$Bin], 
  ByteOrder => $ENDIANNESS, 
  Alignment=>$STRUCT_BYTE_ALIGNMENT, 
  OrderMembers=>1)->parse_file(shift(@ARGV));

my $struct_name = shift(@ARGV);

$c->tag($struct_name.'.two', Format => 'String');
my $sizeof = $c->sizeof($struct_name);
print "Sizeof($struct_name) is: $sizeof\n";

my %struct_data = map { $_ => $c->typeof(join('',$struct_name,$_)).': '. $c->offsetof($struct_name, $_) } ($c->member($struct_name));
print Dumper(\%struct_data);

my $infile = IO::File->new("$Bin/theoutput.dat", O_RDONLY) || die "Can't open file: $!";
$infile->binmode();
my $bindata = "";
while ($infile->sysread($bindata, $sizeof, 0)) {
  my $structval = $c->unpack($struct_name, $bindata);
  print "Two: ".$structval->{two}."\n";

  if ($@) { print $@; }
  print Dumper($structval);
}