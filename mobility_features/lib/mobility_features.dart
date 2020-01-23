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

  DateTime get departureDateTime =>
      DateTime.fromMillisecondsSinceEpoch(departure);

  Duration get duration => Duration(milliseconds: departure - arrival);

  @override
  String toString() {
    return 'Stop: ${location.toString()} [$arrivalDateTime - $departureDateTime] ($duration)';
  }
}

class Place {
  int id;
  Location location;
  Duration duration;

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

/// Preprocessing for the Feature Extraction
/// Finds Stops, Places and Moves for a day of GPS data
class Preprocessor {
  double minStopDist = 50, minPlaceDist = 50;
  Duration minStopDuration = Duration(minutes: 10),
      minMoveDuration = Duration(minutes: 5);

  Function distf = haversineDist;

  /// Calculate centroid of a gps point cloud
  Location findCentroid(List<Location> data) {
    List<double> lats = data.map((d) => (d.latitude)).toList();
    List<double> lons = data.map((d) => (d.longitude)).toList();

    double medianLat = Stats.fromData(lats).median as double;
    double medianLon = Stats.fromData(lons).median as double;

    return Location(medianLat, medianLon);
  }

  /// Checks if two points are within the minimum distance
  bool isWithinMinDist(Location a, Location b) {
    double d = distf([a.latitude, a.longitude], [b.latitude, b.longitude]);
    return d <= minStopDist;
  }

  /// Find the stops in a sequence of gps data points
  List<Stop> findStops(List<LocationData> data) {
    List<Stop> stops = [];

    int i = 0;
    int j;
    int N = data.length;

    while (i < N) {
      j = i + 1;
      List<LocationData> pointCloud = data.sublist(i, j);
      Location centroid = findCentroid(pointCloud.map((d) => (d.location)));

      while (j < N && isWithinMinDist(data[j].location, centroid)) {
        j++;
        pointCloud = data.sublist(i, j);
        centroid = findCentroid(pointCloud.map((d) => (d.location)));
      }

      /// Check that the stop lasted for the minimum duration
      Stop s = Stop(centroid, pointCloud.first.time, pointCloud.last.time);
      if (s.duration >= minStopDuration) {
        stops.add(Stop(centroid, pointCloud.first.time, pointCloud.last.time));
      }
      i = j;
    }

    return stops;
  }

  /// Finds the places by clustering stops with the DBSCAN algorithm
  List<Place> findPlaces(List<Stop> stops) {

    List<Place> places = [];

    DBSCAN dbscan = DBSCAN(
        epsilon: minPlaceDist, minPoints: 1, distanceMeasure: haversineDist);

    /// Extract gps coordinates from stops
    List<List<double>> gpsCoords =
        stops.map((s) => ([s.location.latitude, s.location.longitude]));

    /// Run DBSCAN on data points
    dbscan.run(gpsCoords);

    /// Extract labels for each stop, each label being a cluster
    /// Filter out stops labelled as noise (where label is -1)
    Set<int> clusterLabels = dbscan.label.where((l) => (l != -1)).toSet();

    for (int label in clusterLabels) {
      /// Get indices of all stops with the current cluster label
      List<int> indices =
          stops.asMap().keys.where((i) => (dbscan.label[i] == label));

      /// For each index, get the corresponding stop
      List<Stop> stopsForPlace = indices.map((i) => (stops[i]));

      /// Given all stops belonging to a place,
      /// calculate the centroid of the place
      Location centroid = findCentroid(stopsForPlace.map((x) => (x.location)));

      /// Calculate the sum of the durations spent at the stops,
      /// belonging to the place
      Duration duration =
          stopsForPlace.map((s) => (s.duration)).reduce((a, b) => a + b);

      /// Add place to the list
      places.add(Place(label, centroid, duration));
    }

    return places;
  }
}
