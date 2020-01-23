library mobility_features;

import 'package:simple_cluster/src/dbscan.dart';
import 'dart:math';
import 'dataset.dart';
import 'package:stats/stats.dart';

void printList(List l) {
  for (var x in l) print(x);
  print('-' * 50);
}

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
  Place place;

  Stop(this.location, this.arrival, this.departure, {this.place});

  DateTime get arrivalDateTime => DateTime.fromMillisecondsSinceEpoch(arrival);

  DateTime get departureDateTime =>
      DateTime.fromMillisecondsSinceEpoch(departure);

  Duration get duration => Duration(milliseconds: departure - arrival);

  @override
  String toString() {
    String placeString = place != null ? place.toString() : '<NO PLACE>';
    return 'Stop: ${location.toString()} [$arrivalDateTime - $departureDateTime] ($duration) ($placeString)';
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
  Place placeFrom, placeTo;

  Move(this.locationFrom, this.locationTo, this.placeFrom, this.placeTo,
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
    return 'Move: $locationFrom --> $locationTo, (Place ${placeFrom.id} --> ${placeTo.id}) ($duration)';
  }
}

/// Preprocessing for the Feature Extraction.
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
      List<LocationData> g = data.sublist(i, j);
      Location c = findCentroid(g.map((d) => (d.location)).toList());

      while (j < N && isWithinMinDist(data[j].location, c)) {
        j += 1;
        g = data.sublist(i, j);
        c = findCentroid(g.map((d) => (d.location)).toList());
      }

      /// Check that the stop lasted for the minimum duration
      Stop s = Stop(c, g.first.time, g.last.time);
      if (s.duration >= minStopDuration) {
        stops.add(Stop(c, g.first.time, g.last.time));
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
    List<List<double>> gpsCoords = stops
        .map((s) => ([s.location.latitude, s.location.longitude]))
        .toList();

    /// Run DBSCAN on data points
    dbscan.run(gpsCoords);

    /// Extract labels for each stop, each label being a cluster
    /// Filter out stops labelled as noise (where label is -1)
    Set<int> clusterLabels = dbscan.label.where((l) => (l != -1)).toSet();

    for (int label in clusterLabels) {
      /// Get indices of all stops with the current cluster label
      List<int> indices =
          stops.asMap().keys.where((i) => (dbscan.label[i] == label)).toList();

      /// For each index, get the corresponding stop
      List<Stop> stopsForPlace = indices.map((i) => (stops[i])).toList();

      /// Given all stops belonging to a place,
      /// calculate the centroid of the place
      List<Location> stopsLocations =
          stopsForPlace.map((x) => (x.location)).toList();
      Location centroid = findCentroid(stopsLocations);

      /// Calculate the sum of the durations spent at the stops,
      /// belonging to the place
      Duration duration =
          stopsForPlace.map((s) => (s.duration)).reduce((a, b) => a + b);

      /// Add place to the list
      Place p = Place(label, centroid, duration);
      places.add(p);

      /// Set place field for the current stops
      stopsForPlace.forEach((s) => s.place = p);
    }
    return places;
  }

  List<Move> findMoves(List<LocationData> data, List<Stop> stops) {
    List<Move> moves = [];
    int departure = data.map((d) => (d.time)).reduce(min);
    Place prevPlace;

    for (Stop stop in stops) {
      List<LocationData> g = data
          .where((d) => (d.time >= departure && d.time <= stop.arrival))
          .toList();
      if (g.isNotEmpty) {
        Move m = Move(g.first.location, g.last.location, prevPlace, stop.place,
            departure, stop.arrival);

        /// If move lasted long enough, add it to the moves list
        if (m.duration >= minMoveDuration) {
          moves.add(m);
        }

        departure = stop.departure;
        prevPlace = stop.place;
      } else {
        g = data.where((d) => (d.time >= departure)).toList();
        if (g.isNotEmpty) {
          int arrival = g.map((d) => (d.time)).reduce(max);
          Move m = Move(g.first.location, g.last.location, prevPlace, stop.place,
              departure, arrival);

          /// If move lasted long enough, add it to the moves list
          if (m.duration >= minMoveDuration) {
            moves.add(m);
          }
        }
      }
    }

    return moves;

//    '''
//    moves = []
//    if 'date'in stops.columns:
//        stops = stops[stops.date==df.date.values[0]]
//    departure = df.datetime.min()
//    prev_place = np.nan
//    for index, stop in stops.iterrows():
//        g = df[(df.datetime >= departure) & (df.datetime <= stop.arrival)]
//        if not g.empty:
//            moves.append([g.lat.values[0], g.lon.values[0],
//                          g.lat.values[-1], g.lon.values[-1],
//                          departure, stop.arrival, prev_place, stop.place,
//                          _move_length(g, distf)])
//        departure = stop.departure
//        prev_place = stop.place
//    else:
//        g = df[(df.datetime >= departure)]
//        #g = g.sort_values('datetime')
//        if not g.empty:
//            moves.append([g.lat.values[0], g.lon.values[0],
//                          g.lat.values[-1], g.lon.values[-1],
//                          departure, g.datetime.max(), prev_place, np.nan,
//                          _move_length(g, distf)])
//    moves = pd.DataFrame(moves, columns=['from_lat', 'from_lon',
//                         'to_lat', 'to_lon', 'departure', 'arrival',
//                         'from_place', 'to_place', 'distance'])
//    moves.insert(0, 'user_id', df.user_id.values[0])
//    moves['duration'] = (moves.arrival - moves.departure).dt.total_seconds()/60
//    moves['mean_speed'] = moves.distance / (moves.duration * 60)
//    moves = moves[moves.duration >= min_duration].reset_index()
//    return moves
//    '''
  }
}
