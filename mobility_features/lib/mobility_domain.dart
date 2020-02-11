part of mobility_features_lib;

/// A [Location] object contains a latitude and longitude
/// and represents a 2D spatial coordinates
class Location {
  double longitude;
  double latitude;

  Location(this.latitude, this.longitude);

  factory Location.fromJson(Map<String, dynamic> x) {
    num lat = x['latitude'] as double;
    num lon = x['longitude'] as double;
    return Location(lat, lon);
  }

  @override
  String toString() {
    return 'Location: ($latitude, $longitude)';
  }
}

/// A [SingleLocationPoint] holds a 2D [Location] spatial data point
/// as well as a [DateTime] value s.t. it may be temporally ordered
class SingleLocationPoint {
  Location location;
  double speed = 0;
  DateTime datetime;

  SingleLocationPoint(this.location, this.datetime, {this.speed});

  factory SingleLocationPoint.fromJson(Map<String, dynamic> x) {
    num lat = x['latitude'] as double;
    num lon = x['longitude'] as double;
    int time = x['datetime'];
    DateTime _datetime = DateTime.fromMillisecondsSinceEpoch(time);
    _datetime = _datetime.subtract(Duration(hours: 1));
    return SingleLocationPoint(Location(lat, lon), _datetime);
  }

  @override
  String toString() {
    return '$location [$datetime]';
  }
}

/// A [Stop] represents a cluster of [SingleLocationPoint] which were 'close' to eachother
/// wrt. to Time and 2D space, in a period of little- to no movement.
/// A [Stop] has an assigned [placeId] which links it to a [Place].
/// At initialization a stop will be assigned to the 'Noise' place (with id -1),
/// and only after all places have been identified will a [Place] be assigned.
class Stop {
  List<SingleLocationPoint> locationDataPoints;
  Location location;
  int placeId, samples;
  DateTime arrival, departure;

  Stop(this.locationDataPoints, {this.placeId = -1}) {
    location = calculateCentroid(locationDataPoints.locations);
    samples = locationDataPoints.length;

    /// Find min/max time
    arrival = DateTime.fromMillisecondsSinceEpoch(locationDataPoints
        .map((d) => d.datetime.millisecondsSinceEpoch)
        .reduce(min));
    departure = DateTime.fromMillisecondsSinceEpoch(locationDataPoints
        .map((d) => d.datetime.millisecondsSinceEpoch)
        .reduce(max));
  }

  Duration get duration => Duration(
      milliseconds:
          departure.millisecondsSinceEpoch - arrival.millisecondsSinceEpoch);

  @override
  String toString() {
    return 'Stop at place $placeId,  (${location.toString()}) [$arrival - $departure] ($duration) ';
  }
}

/// A [Place] is a cluster of [Stop]s found by the DBSCAN algorithm
/// https://www.aaai.org/Papers/KDD/1996/KDD96-037.pdf
class Place {
  int id;
  List<Stop> stops;
  Location location;

  Place(this.id, this.stops) {
    location = calculateCentroid(stops.map((s) => s.location).toList());
  }

  Duration get duration => stops.map((s) => s.duration).reduce((a, b) => a + b);

  @override
  String toString() {
    return 'Place ID: $id, at ${location.toString()} ($duration)';
  }
}

/// A [Move] is a transfer from one [Stop] to another.
/// A set of features can be derived from this such as the haversine distance between
/// the stops, the duration of the move, and thereby also the average travel speed.
class Move {
  Stop fromStop, toStop;
  List<SingleLocationPoint> points;

  Move(this.fromStop, this.toStop, this.points);

  /// The haversine distance through all the points between the two stops
  double get distance {
    double d = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      d += Distance.fromLocation(points[i].location, points[i + 1].location);
    }
    return d;
  }

  /// The duration of the move in milliseconds
  Duration get duration => Duration(
      milliseconds: toStop.arrival.millisecondsSinceEpoch -
          fromStop.departure.millisecondsSinceEpoch);

  /// The average speed when moving between the two places (m/s)
  double get meanSpeed => distance / duration.inSeconds.toDouble();

  @override
  String toString() {
    return 'Move: ${fromStop.location} --> ${toStop.location}, (Place ${fromStop.placeId} --> ${toStop.placeId}) (Time: $duration) (Points: ${points.length})';
  }
}

/// A [Move] is a transfer from one [Stop] to another.
/// A set of features can be derived from this such as the haversine distance between
/// the stops, the duration of the move, and thereby also the average travel speed.
//class Move {
//  Stop fromStop, toStop;
//
//  Move(this.fromStop, this.toStop);
//
//  /// The haversine distance between the two places, in meters
//  double get distance {
//    return Distance.fromLocation(fromStop.location, toStop.location);
//  }
//
//  /// The duration of the move in milliseconds
//  Duration get duration => Duration(
//      milliseconds: toStop.arrival.millisecondsSinceEpoch -
//          fromStop.departure.millisecondsSinceEpoch);
//
//  /// The average speed when moving between the two places (m/s)
//  double get meanSpeed => distance / duration.inSeconds.toDouble();
//
//  @override
//  String toString() {
//    return 'Move: ${fromStop.location} --> ${toStop.location}, (Place ${fromStop.placeId} --> ${toStop.placeId}) ($duration)';
//  }
//}
