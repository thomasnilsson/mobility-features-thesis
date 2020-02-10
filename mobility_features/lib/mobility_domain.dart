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

/// A [LocationData] holds a 2D [Location] spatial data point
/// as well as a [DateTime] value s.t. it may be temporally ordered
class LocationData {
  Location location;
  double speed = 0;
  DateTime datetime;

  LocationData(this.location, this.datetime, {this.speed});

  factory LocationData.fromJson(Map<String, dynamic> x) {
    num lat = x['latitude'] as double;
    num lon = x['longitude'] as double;
    int time = x['datetime'];
    DateTime _datetime = DateTime.fromMillisecondsSinceEpoch(time);
    _datetime = _datetime.subtract(Duration(hours: 1));
    return LocationData(Location(lat, lon), _datetime);
  }

  @override
  String toString() {
    return '$location [$datetime]';
  }
}

/// A [Stop] represents a cluster of [LocationData] which were 'close' to eachother
/// wrt. to Time and 2D space, in a period of little- to no movement.
/// A [Stop] has an assigned [placeId] which links it to a [Place].
/// At initialization a stop will be assigned to the 'Noise' place (with id -1),
/// and only after all places have been identified will a [Place] be assigned.
class Stop {
  List<LocationData> locationDataPoints;
  Location medianLocation;
  int placeId, samples;
  DateTime arrival, departure;

  Stop(this.locationDataPoints, {this.placeId = -1}) {
    medianLocation = calculateCentroid(locationDataPoints.locations);
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
    return 'Stop at place $placeId,  (${medianLocation.toString()}) [$arrival - $departure] ($duration) ';
  }
}

/// A [Place] is a cluster of [Stop]s found by the DBSCAN algorithm
/// https://www.aaai.org/Papers/KDD/1996/KDD96-037.pdf
class Place {
  int id;
  Location location;
  Duration duration;

  Place(this.id, this.location, this.duration);

  @override
  String toString() {
    return 'Place ID: $id, at ${location.toString()} ($duration)';
  }
}

/// A [Move] is a transfer from one [Stop] to another.
/// A set of features can be derived from this such as the haversine distance between
/// the stops, the duration of the move, and thereby also the average travel speed.
class Move {
  DateTime departure, arrival;
  Location locationFrom, locationTo;
  int placeFromId, placeToId;

  Move(this.locationFrom, this.locationTo, this.placeFromId, this.placeToId,
      this.departure, this.arrival);

  /// The haversine distance between the two places, in meters
  double get distance {
    return haversineDist([locationFrom.latitude, locationFrom.longitude],
        [locationTo.latitude, locationTo.longitude]);
  }

  /// The duration of the move in milliseconds
  Duration get duration => Duration(
      milliseconds:
          arrival.millisecondsSinceEpoch - departure.millisecondsSinceEpoch);

  /// The average speed when moving between the two places (m/s)
  double get meanSpeed => distance / duration.inSeconds.toDouble();

  @override
  String toString() {
    return 'Move: $locationFrom --> $locationTo, (Place ${placeFromId} --> ${placeToId}) ($duration)';
  }
}
