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