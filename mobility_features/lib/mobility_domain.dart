part of mobility_features_lib;

class LocationData {
  Location location;
  int time;
  double speed = 0;

  LocationData(this.location, this.time, {this.speed});

  factory LocationData.fromJson(Map<String, dynamic> x) {
    num lat = x['latitude'] as double;
    num lon = x['longitude'] as double;
    int time = x['datetime'];
    return LocationData(Location(lat, lon), time);
  }
}

/// A location contains a latitude and longitude (no time component)
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

class Stop {
  Location location;
  int arrival, departure, placeId, samples;

  Stop(this.location, this.arrival, this.departure, this.samples,
      {this.placeId});

  DateTime get arrivalDateTime => DateTime.fromMillisecondsSinceEpoch(arrival);

  DateTime get departureDateTime =>
      DateTime.fromMillisecondsSinceEpoch(departure);

  Duration get duration => Duration(milliseconds: departure - arrival);

  @override
  String toString() {
    String placeString = placeId != null ? placeId.toString() : '<NO PLACE_ID>';
    return 'Stop: ${location.toString()} [$arrivalDateTime - $departureDateTime] ($duration) (samples: $samples) (PlaceId: $placeString)';
  }
}

class Place {
  int id;
  Location location;
  Duration duration;

  Place(this.id, this.location, this.duration);

  @override
  String toString() {
    return 'Place {$id}:  ${location.toString()} ($duration)';
  }
}

class Move {
  int departure, arrival;
  Location locationFrom, locationTo;
  int placeFromId, placeToId;

  Move(this.locationFrom, this.locationTo, this.placeFromId, this.placeToId,
      this.departure, this.arrival);

  /// The haversine distance between the two places
  double get distance {
    return haversineDist([locationFrom.latitude, locationFrom.longitude],
        [locationTo.latitude, locationTo.longitude]);
  }

  /// The duration of the move in milliseconds
  Duration get duration => Duration(milliseconds: arrival - departure);

  /// The average speed when moving between the two places
  double get meanSpeed => distance / duration.inSeconds.toDouble();

  @override
  String toString() {
    return 'Move: $locationFrom --> $locationTo, (Place ${placeFromId} --> ${placeToId}) ($duration)';
  }
}