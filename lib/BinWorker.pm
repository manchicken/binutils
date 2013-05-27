# /*
use strict;
use warnings;

package BinWorker;

use Inline;

sub new {
  my ($pkg, %opts) = @_;

  my $self = {%opts};

  return bless($self, $pkg);
}

sub strip_matching_entries_from_file {
  my ($self) = @_;

  my $header  = $self->{header}  || die "No header defined in BinWorker";
  my $struct  = $self->{struct}  || die "No struct defined in BinWorker";
  my $field   = $self->{field}   || die "No field defined in BinWorker";
  my $filnam  = $self->{filnam}  || die "No subject file defined in BinWorker";
  my $value   = $self->{value}   || die "No value defined in BinWorker";
  my $compare = $self->{compare} || die "No compare type defined in BinWorker";
  my $outfil = "${filnam}.output";

  my $switch = 'N';
  if ($compare eq "number") {
    $switch = 'N';
  } elsif ($compare eq "string") {
    $switch = 'S';
  } else {
    die "Unknown compare type '$compare'";
  }

  my $c = qq{
    /* */
    #include <stdlib.h>
    #include <string.h>
    #include <stdio.h>
    #include <$header>

    int _c_run_bin() {
      $struct one;

      FILE *infile = fopen("$filnam", "rb");
      if (!infile) {
        perror("Failed to open file '$filname' for reading");
        exit(-1);
      }

      FILE *outfile = fopen("$outfil", "wb");
      if (!outfile) {
        perror("Failed to open file '$outfil' for writing");
        exit(-1);
      }

      int status = 0;
      char comptype = '$switch';
      int skip = 0;
      while (!feof(infile)) {
        skip = 0;
        status = fread(&one, sizeof($struct), 1, infile);

        switch (comptype) {
          case 'N':
            if (one.${field} == $value) {
              skip = 1;
            }
            break;
          case 'S':
            if (strcasecmp(one.${field}, "$value") == 0) {
              skip = 1;
            }
            break;
          default:
            fprintf(stderr, "NO COMPARE TYPE DEFINED!\n");
            fclose(outfile);
            fclose(infile);
            return 0;
        };

        if (!skip) {
          fwrite(&one, sizeof($struct), 1, outfile);
        }
      }
      fflush(outfile);

      fclose(infile);
      fclose(outfile);

      return 1;
    }
  //};
  # /*

  Inline->bind(C=>$c);
  if (!_c_run_bin()) {
    print "Failed to run, cleaning up.\n";
    unlink($outfil);
    return 0;
  }

  print "Output file is '$outfil'\n";

  return 1;
}

1;
# */