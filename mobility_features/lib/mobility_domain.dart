part of mobility_features_lib;

/// A [Location] object contains a latitude and longitude
/// and represents a 2D spatial coordinates
class Location {
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
class SingleLocationPoint {
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
  factory SingleLocationPoint.fromMap(Map<String, dynamic> x,
      {int hourOffset = 0}) {
    /// Parse, i.e. perform type check
    double lat = double.parse(x['lat'].toString());
    double lon = double.parse(x['lon'].toString());
    int timeInMillis = int.parse(x['datetime'].toString());

    DateTime _datetime = DateTime.fromMillisecondsSinceEpoch(timeInMillis)
        .add(Duration(hours: hourOffset));
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

/// A [Stop] represents a cluster of [SingleLocationPoint] which were 'close' to eachother
/// wrt. to Time and 2D space, in a period of little- to no movement.
/// A [Stop] has an assigned [placeId] which links it to a [Place].
/// At initialization a stop will be assigned to the 'Noise' place (with id -1),
/// and only after all places have been identified will a [Place] be assigned.
class Stop {
  List<SingleLocationPoint> points;
  Location _centroid;
  int placeId;
  DateTime arrival, departure;

  Stop(this.points, {this.placeId = -1}) {
    _centroid = calculateCentroid(points.locations);

    /// Find min/max time
    arrival = DateTime.fromMillisecondsSinceEpoch(
        points.map((d) => d._datetime.millisecondsSinceEpoch).reduce(min));
    departure = DateTime.fromMillisecondsSinceEpoch(
        points.map((d) => d._datetime.millisecondsSinceEpoch).reduce(max));
  }

  Location get centroid => _centroid;

  Duration get duration => Duration(
      milliseconds:
          departure.millisecondsSinceEpoch - arrival.millisecondsSinceEpoch);

  Map<String, dynamic> toJson() =>
      {"points": points.map((p) => p.toJson()).toList(), "placeId": placeId};

  factory Stop.fromJson(Map<String, dynamic> json) {
    List<SingleLocationPoint> decodedPoints = (json['points'] as List)
        .map((m) => SingleLocationPoint.fromJson(m))
        .toList();
    return Stop(decodedPoints, placeId: json['placeId']);
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

  Place(this._id, this._stops) {
    _centroid = calculateCentroid(_stops.map((s) => s._centroid).toList());
  }

  Duration get duration =>
      _stops.map((s) => s.duration).reduce((a, b) => a + b);

  Duration durationForDate(DateTime d) => _stops
      .where((s) => s.arrival.zeroTime == d)
      .map((s) => s.duration)
      .fold(Duration(), (a, b) => a + b);

  // Init accumulator to zero (empty duration),
  // otherwise reduce/fold will fail if
  // a place has not been visited on the specified date

  Location get centroid => _centroid;

  int get id => _id;

  @override
  String toString() {
    return 'Place ID: $_id, at ${_centroid.toString()} ($duration)';
  }
}

/// A [Move] is a transfer from one [Stop] to another.
/// A set of features can be derived from this such as the haversine distance between
/// the stops, the duration of the move, and thereby also the average travel speed.
class Move {
  Stop _stopFrom, _stopTo;
  List<SingleLocationPoint> _pointChain;

  Move(this._stopFrom, this._stopTo, this._pointChain);

  /// The haversine distance through all the points between the two stops
  double get distance {
    double d = 0.0;
    for (int i = 0; i < _pointChain.length - 1; i++) {
      d += Distance.fromLocation(
          _pointChain[i]._location, _pointChain[i + 1]._location);
    }
    return d;
  }

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

  @override
  String toString() {
    return 'Move: ${_stopFrom._centroid} --> ${_stopTo._centroid}, (Place ${_stopFrom.placeId} --> ${_stopTo.placeId}) (Time: $duration) (Points: ${_pointChain.length})';
  }
}

/// TODO: Make a getter in stop, easier
class StopHours {
  int placeId;
  List<double> hourSlots;

  StopHours(this.placeId, this.hourSlots);

  factory StopHours.fromStop(Stop s) {
    /// Start and end should be on the same date!
    int start = s.arrival.hour;
    int end = s.departure.hour;

    if (s.departure.zeroTime != s.arrival.zeroTime) {
      throw Exception(
          'Arrival and Departure should be on the same date, but was not! $s');
    }

    List<double> hours = List<double>.filled(HOURS_IN_A_DAY, 0.0);

    /// Set the corresponding hour slots to 1
    for (int i = start; i <= end; i++) {
      hours[i] = 1.0;
    }

    return StopHours(s.placeId, hours);
  }
}

class HourMatrix {
  static const int HOURS_IN_A_DAY = 24;

  List<Stop> _stops;
  int _numberOfPlaces;
  List<List<double>> _matrix;

  HourMatrix(this._stops, this._numberOfPlaces) {
    /// Init 2d matrix with 24 rows and cols equal to number of places
    _matrix = new List.generate(
        HOURS_IN_A_DAY, (_) => new List<double>.filled(_numberOfPlaces, 0.0));

    for (int j = 0; j < _numberOfPlaces; j++) {
      List<Stop> stopsAtPlace = _stops.where((s) => (s.placeId) == j).toList();

      for (Stop s in stopsAtPlace) {
        StopHours sr = StopHours.fromStop(s);

        /// For each hour of the day, add the hours from the StopRow to the matrix
        for (int i = 0; i < HOURS_IN_A_DAY; i++) {
          _matrix[i][j] += sr.hourSlots[i];
        }
      }
    }
  }

  List<List<double>> get matrix => _matrix;

  /// Features
  int get homePlaceId {
    List<List<double>> nightHours = _matrix.sublist(0, 6);
    List<double> nightHoursAtPlaces =
        nightHours.map((h) => h.reduce((a, b) => a + b)).toList();
    return argmaxDouble(nightHoursAtPlaces);
  }

  /// Calculates the error between two matrices
  double computeError(HourMatrix other) {
    /// Check that dimensions match
    assert(other.matrix.length == HOURS_IN_A_DAY &&
        other.matrix.first.length == _numberOfPlaces);

    /// Count errors
    double error = 0.0;
    for (int i = 0; i < HOURS_IN_A_DAY; i++) {
      for (int j = 0; j < _numberOfPlaces; j++) {
        error += (this.matrix[i][j] - other.matrix[i][j]).abs();
      }
    }
    /// Compute average
    return error / (HOURS_IN_A_DAY * _numberOfPlaces);
  }

}
