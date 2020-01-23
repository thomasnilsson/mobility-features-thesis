library mobility_features;

import 'package:simple_cluster/src/dbscan.dart';
import 'dart:math';
import 'dataset.dart';
import 'package:stats/stats.dart';

/// Convert from degrees to radians
double radiansFromDegrees(final double degrees) => degrees * (pi / 180.0);

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

class Stop {
  Location location;
  int arrival, departure;

  Stop(this.location, this.arrival, this.departure);

  DateTime get arrivalDateTime => DateTime.fromMillisecondsSinceEpoch(arrival);
  DateTime get departureDateTime => DateTime.fromMillisecondsSinceEpoch(departure);



  @override
  String toString() {
    return 'Stop: ${location.toString()} [$arrivalDateTime - $departureDateTime]';
  }
}

class Place {
  int id;
  Location location;
  double duration;

  Place(this.id, this.location, this.duration);
}

class Move {
  int departure, arrival;
  Place placeFrom, placeTo;

  Move(this.placeFrom, this.placeTo, this.departure, this.arrival);

  /// The haversine distance between the two places
  double get distance {
    return haversineDist(
        [placeFrom.location.latitude, placeFrom.location.longitude],
        [placeTo.location.latitude, placeTo.location.longitude]);
  }

  /// The duration of the move in milliseconds
  int get duration => arrival - departure;

  /// The average speed when moving between the two places
  double get meanSpeed => distance / duration.toDouble();
}

class Preprocessor {
  double minDist = 50;
  int minDuration = 10 * 60 * 1000; // 10 minutes

  DBSCAN dbscan =
      DBSCAN(epsilon: 50, minPoints: 1, distanceMeasure: haversineDist);

  Function distf = haversineDist;

  /// Calculate centroid of a gps point cloud
  Location findCentroid(List<LocationData> data) {
    List<double> lats = data.map((d) => (d.location.latitude)).toList();
    List<double> lons = data.map((d) => (d.location.longitude)).toList();

    double medianLat = Stats.fromData(lats).median as double;
    double medianLon = Stats.fromData(lons).median as double;

    return Location(medianLat, medianLon);
  }

  bool isWithinRadius(Location a, Location b, radius) {
    double d = distf([a.latitude, a.longitude], [b.latitude, b.longitude]);
    return d <= radius;
  }

  /// Find the stops in a sequence of gps data points
  List<Stop> findStops(
      List<LocationData> data) {
    List<Stop> stops = [];

    int i = 0;
    int j;
    int N = data.length;

    while (i < N) {
      j = i + 1;
      List<LocationData> g = data.sublist(i, j);
      Location c = findCentroid(g);

      while (j < N && isWithinRadius(data[j].location, c, minDist)) {
        j++;
        g = data.sublist(i, j);
        c = findCentroid(g);
      }

      /// Check that the stop lasted for the minimum duration
      int duration = g.last.time - g.first.time;
      if (duration >= minDuration) {
        stops.add(Stop(c, g.first.time, g.last.time));
      }
      i = j;
    }

    return stops;
  }
}
