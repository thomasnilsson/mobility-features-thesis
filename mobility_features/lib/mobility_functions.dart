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

  static bool isWithin(Location a, Location b, double d) {
    return fromLocation(a, b) <= d;
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
      Stats.fromData(data.map((d) => (d._latitude)).toList()).median as double;
  double medianLon =
      Stats.fromData(data.map((d) => (d._longitude)).toList()).median as double;

  return Location(medianLat, medianLon);
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

extension LocationList on List<SingleLocationPoint> {
  List<Location> get locations =>
      this.map((SingleLocationPoint d) => d.location).toList();
}

class Serializer<E> {
  /// Provide a file reference in order to serialize objects.
  File file;

  Serializer(this.file) {
    bool exists = file.existsSync();
    if (!exists) {
      write([]);
    }
  }

  /// Writes a list of [Serializable] to the file given in the constructor.
  Future<void> write(List<Serializable> elements) async {
    List jsonStops = elements.map((e) => e.toJson()).toList();
    String s = json.encode(jsonStops);
    file.writeAsString(s);
  }

  /// Reads contents of the file in the constructor,
  /// and maps it to a list of a specific [Serializable] type.
  Future<List<Serializable>> read() async {
    String stopsAsString = await file.readAsString();
    List decodedJsonList = json.decode(stopsAsString);

    switch (E) {
      case Move : return decodedJsonList.map((x) => Move.fromJson(x)).toList();
      case Stop : return decodedJsonList.map((x) => Stop.fromJson(x)).toList();
      default: return decodedJsonList.map((x) => SingleLocationPoint.fromJson(x)).toList();
    }
  }
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
