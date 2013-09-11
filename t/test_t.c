#include "test_t.h"

#include <stdio.h>
#include <string.h>

#define OUTFILE "theoutput.dat"
#define RECLIMIT 200000

int main() {
  FILE *outfile = fopen(OUTFILE, "wb");

  test_t play;
  int x = 0;

  printf("Sizeof test_t is '%ld'\n", sizeof(test_t));

  for (x = 0; x < RECLIMIT; x += 1) {
    memset(&play, 0, sizeof(test_t));
    play.one = x + 1;
    sprintf(play.two, "XXX: '%d'", x);
    play.three = x * play.one;
    play.four = x;

    fwrite(&play, sizeof(test_t), 1, outfile);
  }
  fflush(outfile);

  fclose(outfile);

  return 0;
}
