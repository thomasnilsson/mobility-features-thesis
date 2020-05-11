part of mobility_features_lib;

/// Returns an [Iterable] of [List]s where the nth element in the returned
/// iterable contains the nth element from every Iterable in [iterables]. The
/// returned Iterable is as long as the shortest Iterable in the argument. If
/// [iterables] is empty, it returns an empty list.
Iterable<List<T>> zip<T>(Iterable<Iterable<T>> iterables) sync* {
  if (iterables.isEmpty) return;
  final iterators = iterables.map((e) => e.iterator).toList(growable: false);
  while (iterators.every((e) => e.moveNext())) {
    yield iterators.map((e) => e.current).toList(growable: false);
  }
}

/// Convert from degrees to radians
extension on double {
  double get radiansFromDegrees => this * (pi / 180.0);
}

class Distance {
  static double fromLocation(Location a, Location b) {
    return fromDouble([a._latitude, a._longitude], [b._latitude, b._longitude]);
  }

  static double fromDouble(List<double> p1, List<double> p2) {
    double lat1 = p1[0].radiansFromDegrees;
    double lon1 = p1[1].radiansFromDegrees;
    double lat2 = p2[0].radiansFromDegrees;
    double lon2 = p2[1].radiansFromDegrees;

    double earthRadius = 6378137.0; // WGS84 major axis
    double distance = 2 *
        earthRadius *
        asin(sqrt(pow(sin(lat2 - lat1) / 2, 2) +
            cos(lat1) * cos(lat2) * pow(sin(lon2 - lon1) / 2, 2)));

    return distance;
  }
}

Iterable<int> range(int low, int high) sync* {
  for (int i = low; i < high; ++i) {
    yield i;
  }
}
extension CompareDates on DateTime {
  bool geq(DateTime other) {
    return this.isAfter(other) || this.isAtSameMomentAs(other);
  }

  bool leq(DateTime other) {
    return this.isBefore(other) || this.isAtSameMomentAs(other);
  }

  DateTime get midnight {
    return DateTime(this.year, this.month, this.day);
  }
}

extension AverageIterable on Iterable {
  double get mean {
    return this.fold(0, (a, b) => a + b) / this.length.toDouble();
  }
}

int argmaxDouble(List<double> list) {
  double maxVal = -double.infinity;
  int i = 0;

  for (int j = 0; j < list.length; j++) {
    if (list[j] > maxVal) {
      maxVal = list[j];
      i = j;
    }
  }
  return i;
}

int argmaxInt(List<int> list) {
  int maxVal = -2147483648;
  int i = 0;

  for (int j = 0; j < list.length; j++) {
    if (list[j] > maxVal) {
      maxVal = list[j];
      i = j;
    }
  }
  return i;
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

List<List<double>> zeroMatrix(int rows, int cols) {
  return new List.generate(rows, (_) => new List<double>.filled(cols, 0.0));
}
