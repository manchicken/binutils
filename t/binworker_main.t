#!/usr/bin/env perl
use strict;
use warnings;

use Test::More tests => 3;

use FindBin qw{$Bin};
use Readonly;
use Data::Dumper;

Readonly our $TEST_T_SIZE => 76;

use lib "$Bin/../lib";

sub BEGIN {
  use_ok('BinWorker');
}

sub test_get_struct_metadata {
  my $inst = BinWorker->new(
    include=>"$Bin",
    header=>"$Bin/test_t.h",
  );

  ok(my $meta = $inst->get_struct_metadata('test_t'), "Get the metadata...");
  is($meta->{size}, $TEST_T_SIZE, "Make sure the size matches what we expected...");
  print Dumper($meta);
}

&test_get_struct_metadata;

# $c->tag($struct_name.'.two', Format => 'String');
# my $sizeof = $c->sizeof($struct_name);
# print "Sizeof($struct_name) is: $sizeof\n";

# my %struct_data = map { $c->offsetof($struct_name, $_).': '.$_ => $c->typeof(join('',$struct_name,$_)) } ($c->member($struct_name));
# print Dumper(\%struct_data);

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
