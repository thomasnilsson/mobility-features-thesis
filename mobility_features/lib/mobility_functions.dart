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

class HaversineDist {
  static double fromLocation(Location a, Location b) {
    return fromDouble([a.latitude, a.longitude], [b.latitude, b.longitude]);
  }

  static double fromDouble(List<double> point1, List<double> point2) {
    double lat1 = point1[0].radiansFromDegrees;
    double lon1 = point1[1].radiansFromDegrees;
    double lat2 = point2[0].radiansFromDegrees;
    double lon2 = point2[1].radiansFromDegrees;

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

/// Calculate centroid of a gps point cloud
Location calculateCentroid(List<Location> data) {
  double medianLat =
      Stats.fromData(data.map((d) => (d.latitude)).toList()).median as double;
  double medianLon =
      Stats.fromData(data.map((d) => (d.longitude)).toList()).median as double;

  return Location(medianLat, medianLon);
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

extension NumList<num> on List<num> {
  int get argmax {
    double maxVal = -double.infinity;
    int i = 0;

    for (int j = 0; j < this.length; j++) {
      if (this[j] as double > maxVal) {
        maxVal = this[j] as double;
        i = j;
      }
    }
    return i;
  }
}

extension LocationList on List<LocationData> {
  List<Location> get locations =>
      this.map((LocationData d) => d.location).toList();
}
