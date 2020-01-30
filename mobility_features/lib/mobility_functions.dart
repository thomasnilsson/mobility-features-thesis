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
double radiansFromDegrees(final double degrees) => degrees * (pi / 180.0);

extension on double {
  double get radiansFromDegrees => this * (pi / 180.0);
}

/// Haversine distance between two points
double haversineDist(List<double> point1, List<double> point2) {
  double lat1 = radiansFromDegrees(point1[0]);
  double lon1 = radiansFromDegrees(point1[1]);
  double lat2 = radiansFromDegrees(point2[0]);
  double lon2 = radiansFromDegrees(point2[1]);

  double earthRadius = 6378137.0; // WGS84 major axis
  double distance = 2 *
      earthRadius *
      asin(sqrt(pow(sin(lat2 - lat1) / 2, 2) +
          cos(lat1) * cos(lat2) * pow(sin(lon2 - lon1) / 2, 2)));

  return distance;
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

  DateTime get date {
    return DateTime(this.year, this.month, this.day);
  }
}


extension UniqueList on List {
  List get unique => this.toSet().toList();
}
