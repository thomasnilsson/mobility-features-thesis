part of mobility_features_lib;

const int HOURS_IN_A_DAY = 24;

/// Abstract class to enforce functions
/// to serialize and deserialize an object
abstract class Serializable {
  Map<String, dynamic> toJson();

  Serializable.fromJson(Map<String, dynamic> json);
}

/// A [Location] object contains a latitude and longitude
/// and represents a 2D spatial coordinates
class Location implements Serializable {
  double _latitude;
  double _longitude;

  Location(this._latitude, this._longitude);

  factory Location.fromJson(Map<String, dynamic> x) {
    num lat = x['latitude'] as double;
    num lon = x['longitude'] as double;
    return Location(lat, lon);
  }

  double get latitude => _latitude;

  double get longitude => _longitude;

  Map<String, dynamic> toJson() =>
      {"latitude": latitude, "longitude": longitude};

  @override
  String toString() {
    return 'Location: ($_latitude, $_longitude)';
  }
}

/// A [SingleLocationPoint] holds a 2D [Location] spatial data point
/// as well as a [DateTime] value s.t. it may be temporally ordered
class SingleLocationPoint implements Serializable {
  Location _location;
  DateTime _datetime;
  double speed = 0;

  SingleLocationPoint(this._location, this._datetime, {this.speed});

  Location get location => _location;

  DateTime get datetime => _datetime;

  Map<String, dynamic> toJson() => {
        "location": location.toJson(),
        "datetime": json.encode(datetime.millisecondsSinceEpoch)
      };

  /// Used for reading data from disk, not gonna be used in production
  factory SingleLocationPoint.fromMap(Map<String, dynamic> x) {
    /// Parse, i.e. perform type check
    double lat = double.parse(x['lat'].toString());
    double lon = double.parse(x['lon'].toString());
    int timeInMillis = int.parse(x['datetime'].toString());

    DateTime _datetime = DateTime.fromMillisecondsSinceEpoch(timeInMillis);
    return SingleLocationPoint(Location(lat, lon), _datetime);
  }

  factory SingleLocationPoint.fromJson(Map<String, dynamic> json) {
    /// Parse, i.e. perform type check
    Location loc = Location.fromJson(json['location']);
    int millis = int.parse(json['datetime']);
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return SingleLocationPoint(loc, dt);
  }

  @override
  String toString() {
    return '$_location [$_datetime]';
  }
}

class Cluster {
  List<Location> _locations;
  Location _centroid;

  Cluster(this._locations);

  factory Cluster.fromPoints(List<SingleLocationPoint> points) {
    List<Location> locs = points.map((p) => p.location).toList();
    return Cluster(locs);
  }

  Location get centroid {
    if (_centroid == null) {
      _centroid = _calculateCentroid();
    }
    return _centroid;
  }

  List<Location> get locations => _locations;

  Location _calculateCentroid() {
    double lat = Stats.fromData(locations.map((d) => (d.latitude)).toList())
        .median as double;
    double lon = Stats.fromData(locations.map((d) => (d.longitude)).toList())
        .median as double;
    return Location(lat, lon);
  }
}

/// A [Stop] represents a cluster of [SingleLocationPoint] which were 'close' to eachother
/// wrt. to Time and 2D space, in a period of little- to no movement.
/// A [Stop] has an assigned [placeId] which links it to a [Place].
/// At initialization a stop will be assigned to the 'Noise' place (with id -1),
/// and only after all places have been identified will a [Place] be assigned.
class Stop implements Serializable {
  Location _centroid;
  int placeId;
  DateTime _arrival, _departure;

  Stop(this._centroid, this._arrival, this._departure, {this.placeId = -1});

  /// Construct stop from point cloud
  factory Stop.fromPoints(List<SingleLocationPoint> points,
      {int placeId = -1}) {
    /// Calculate center
    Location center = Cluster.fromPoints(points).centroid;

    /// Find min/max time
    DateTime arr = DateTime.fromMillisecondsSinceEpoch(
        points.map((d) => d._datetime.millisecondsSinceEpoch).reduce(min));
    DateTime dep = DateTime.fromMillisecondsSinceEpoch(
        points.map((d) => d._datetime.millisecondsSinceEpoch).reduce(max));
    return Stop(center, arr, dep, placeId: placeId);
  }

  Location get centroid => _centroid;

  DateTime get departure => _departure;

  DateTime get arrival => _arrival;

  List<double> get hourSlots {
    /// Start and end should be on the same date!
    int startHour = arrival.hour;
    int endHour = departure.hour;

    if (departure.midnight != arrival.midnight) {
      throw Exception(
          'Arrival and Departure should be on the same date, but was not! $this');
    }

    List<double> hours = List<double>.filled(HOURS_IN_A_DAY, 0.0);

    /// If arrived and departed within same hour
    if (startHour == endHour) {
      hours[startHour] = (departure.minute - arrival.minute) / 60.0;
    }

    /// Otherwise if the stop has overlap in hours
    else {
      /// Start
      hours[startHour] = 1.0 - arrival.minute / 60.0;

      /// In between
      for (int hour = startHour + 1; hour < endHour; hour++) {
        hours[hour] = 1.0;
      }

      /// Departure
      hours[endHour] = departure.minute / 60.0;
    }
    return hours;
  }

  Duration get duration => Duration(
      milliseconds:
          departure.millisecondsSinceEpoch - arrival.millisecondsSinceEpoch);

  Map<String, dynamic> toJson() => {
        "centroid": centroid.toJson(),
        "place_id": placeId,
        "arrival": arrival.millisecondsSinceEpoch,
        "departure": departure.millisecondsSinceEpoch
      };

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
        Location.fromJson(json['centroid']),
        DateTime.fromMillisecondsSinceEpoch(json['arrival']),
        DateTime.fromMillisecondsSinceEpoch(json['departure']),
        placeId: json['place_id']);
  }

  @override
  String toString() {
    return 'Stop at place $placeId,  (${_centroid.toString()}) [$arrival - $departure] ($duration) ';
  }
}

/// A [Place] is a cluster of [Stop]s found by the DBSCAN algorithm
/// https://www.aaai.org/Papers/KDD/1996/KDD96-037.pdf
class Place {
  int _id;
  List<Stop> _stops;
  Location _centroid;

  Place(this._id, this._stops);

  Duration get duration =>
      _stops.map((s) => s.duration).reduce((a, b) => a + b);

  Duration durationForDate(DateTime d) => _stops
      .where((s) => s.arrival.midnight == d)
      .map((s) => s.duration)
      .fold(Duration(), (a, b) => a + b);

  Location get centroid {
    if (_centroid == null) {
      List<Location> centroids = _stops.map((s) => s.centroid).toList();
      _centroid = Cluster(centroids).centroid;
    }
    return _centroid;
  }

  int get id => _id;

  @override
  String toString() {
    return 'Place ID: $_id, at ${_centroid.toString()} ($duration)';
  }
}

/// A [Move] is a transfer from one [Stop] to another.
/// A set of features can be derived from this such as the haversine distance between
/// the stops, the duration of the move, and thereby also the average travel speed.
class Move implements Serializable {
  Stop _stopFrom, _stopTo;
  double _distance;

  Move(this._stopFrom, this._stopTo, this._distance);

  factory Move.fromPoints(Stop from, Stop to, List<SingleLocationPoint> p) {
    double d = 0.0;
    for (int i = 0; i < p.length - 1; i++) {
      d += Distance.fromLocation(p[i]._location, p[i + 1]._location);
    }

    return Move(from, to, d);
  }

  /// The haversine distance through all the points between the two stops
  double get distance => _distance;

  /// The duration of the move in milliseconds
  Duration get duration => Duration(
      milliseconds: _stopTo.arrival.millisecondsSinceEpoch -
          _stopFrom.departure.millisecondsSinceEpoch);

  /// The average speed when moving between the two places (m/s)
  double get meanSpeed => distance / duration.inSeconds.toDouble();

  int get placeFrom => _stopFrom.placeId;

  int get placeTo => _stopTo.placeId;

  Stop get stopFrom => _stopFrom;

  Stop get stopTo => _stopTo;

  Map<String, dynamic> toJson() => {
        "stop_from": _stopFrom.toJson(),
        "stop_to": _stopTo.toJson(),
        "distance": _distance
      };

  factory Move.fromJson(Map<String, dynamic> _json) {
    return Move(Stop.fromJson(_json["stop_from"]),
        Stop.fromJson(_json["stop_to"]), _json["distance"]);
  }

  @override
  String toString() {
    return '''Move:
    FROM: $_stopFrom
    TO:   $_stopTo
    Duration: $duration
    Distance: $distance
    ''';
  }
}

class HourMatrix {
  List<List<double>> _matrix;
  int _numberOfPlaces;

  HourMatrix(this._matrix) {
    _numberOfPlaces = _matrix.first.length;
  }

  factory HourMatrix.fromStops(List<Stop> stops, int numberOfPlaces) {
    /// Init 2d matrix with 24 rows and cols equal to number of places
    List<List<double>> matrix = new List.generate(
        HOURS_IN_A_DAY, (_) => new List<double>.filled(numberOfPlaces, 0.0));

    for (int j = 0; j < numberOfPlaces; j++) {
      List<Stop> stopsAtPlace = stops.where((s) => (s.placeId) == j).toList();

      for (Stop s in stopsAtPlace) {
        /// For each hour of the day, add the hours from the StopRow to the matrix
        for (int i = 0; i < HOURS_IN_A_DAY; i++) {
          matrix[i][j] += s.hourSlots[i];
        }
      }
    }
    return HourMatrix(matrix);
  }

  factory HourMatrix.average(List<HourMatrix> matrices) {
    int nDays = matrices.length;
    int nPlaces = matrices.first.matrix.first.length;
    List<List<double>> avg = zeroMatrix(HOURS_IN_A_DAY, nPlaces);

    for (HourMatrix m in matrices) {
      for (int i = 0; i < HOURS_IN_A_DAY; i++) {
        for (int j = 0; j < nPlaces; j++) {
          avg[i][j] += m.matrix[i][j] / nDays;
        }
      }
    }
    return HourMatrix(avg);
  }

  List<List<double>> get matrix => _matrix;

  /// Features
  int get homePlaceId {
    int startHour = 0, endHour = 6;

    List<double> hourSpentAtPlace = List.filled(_numberOfPlaces, 0.0);

    for (int placeId = 0; placeId < _numberOfPlaces; placeId++) {
      for (int hour = startHour; hour < endHour; hour++) {
        hourSpentAtPlace[placeId] += _matrix[hour][placeId];
      }
    }
    double timeSpentAtNight = hourSpentAtPlace.fold(0.0, (a, b) => a + b);
    if (timeSpentAtNight > 0) {
      return argmaxDouble(hourSpentAtPlace);
    }
    return -1;
  }

  double get sum {
    double s = 0.0;
    for (int i = 0; i < HOURS_IN_A_DAY; i++) {
      for (int j = 0; j < _numberOfPlaces; j++) {
        s += this.matrix[i][j];
      }
    }
    return s;
  }

  /// Calculates the error between two matrices
  double computeError(HourMatrix other) {
    /// Check that dimensions match
    assert(other.matrix.length == HOURS_IN_A_DAY &&
        other.matrix.first.length == _matrix.first.length);

    /// Cumulative error between the two matrices
    double error = 0.0;
    //
    for (int i = 0; i < HOURS_IN_A_DAY; i++) {
      for (int j = 0; j < _numberOfPlaces; j++) {
        error += (this.matrix[i][j] - other.matrix[i][j]).abs();
      }
    }

    /// Compute average error by dividing by the number of total entries
    return error / (HOURS_IN_A_DAY * _numberOfPlaces);
  }

  /// Calculates the error between two matrices
  double computeOverlap(HourMatrix other) {
    /// Check that dimensions match
    assert(other.matrix.length == HOURS_IN_A_DAY &&
        other.matrix.first.length == _matrix.first.length);

    double maxOverlap = min(this.sum, other.sum);

    if (maxOverlap == 0.0) return -1.0;

    /// Cumulative error between the two matrices
    double overlap = 0.0;
    //
    for (int i = 0; i < HOURS_IN_A_DAY; i++) {
      for (int j = 0; j < _numberOfPlaces; j++) {
        /// If overlap in time-place matrix,
        /// add the overlap to the total overlap.
        /// The overlap is equal to the minimum of the two quantities
        if (this.matrix[i][j] > 0.0 && other.matrix[i][j] > 0.0) {
          overlap += min(this.matrix[i][j], other.matrix[i][j]);
        }
      }
    }

    /// Compute average error by dividing by the number of total entries
    return overlap / maxOverlap;
  }

  @override
  String toString() {
    String s = '\n';
    s += 'Home place ID: $homePlaceId\n';
    s += 'Matrix\t\t';
    for (int p = 0; p < _numberOfPlaces; p++) {
      s += 'Place $p\t\t';
    }
    s += '\n';
    for (int hour = 0; hour < HOURS_IN_A_DAY; hour++) {
      s += 'Hour ${hour.toString().padLeft(2, '0')}\t\t';

      for (double e in _matrix[hour]) {
        s += '${e.toStringAsFixed(3)}\t\t';
      }
      s += '\n';
    }
    return s;
  }
}
