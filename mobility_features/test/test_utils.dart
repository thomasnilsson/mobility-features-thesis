part of mobility_features_test_lib;

void printList(List l) {
  for (var x in l) print(x);
  print('-' * 50);
}

void printMatrix(List<List> m) {
  for (List row in m) {
    String s = '';
    for (var e in row) {
      s += '$e ';
    }
    print(s);
  }
}

double abs(double x) => x >= 0 ? x : -x;

bool vectorsEqual(List<double> a, List<double> b) {
  double sum = 0.0;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    sum += abs(a[i] - b[i]);
  }
  return sum < 0.001;
}