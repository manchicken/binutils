
#define SOMEINTVALUE(X) int X
#define SOMESTRING(X,SZ) char X[SZ]

struct foo {
  SOMESTRING(five_dot_one, 40);
  SOMEINTVALUE(five_dot_two);
  int test1;
};

typedef struct {
  SOMEINTVALUE(one);
  SOMESTRING(two,16);
  int three;
  char four;
  struct foo five;
} test_t;