part of mobility_features_lib;

/// Preprocessing for the Feature Extraction.
/// Finds Stops, Places and Moves for a day of GPS data
class DataPreprocessor {
  /// Parameters for algorithms
  double stopRadius, placeRadius, moveDist = 50;
  Duration stopDuration, moveDuration;

  /// Data fields
  DateTime _date;

  DataPreprocessor(this._date,
      {this.stopRadius = 25,
      this.placeRadius = 50,
      this.moveDist = 50,
      this.stopDuration = const Duration(minutes: 3),
      this.moveDuration = const Duration(minutes: 3)});

  /// Getters
  DateTime get date => _date;

  /// Filter out data not on the specified date
  List<SingleLocationPoint> pointsToday(List<SingleLocationPoint> data) {
    List<SingleLocationPoint> filtered =
        data.where((x) => x.datetime.midnight == _date.midnight).toList();
    return filtered;
  }

  /// Find the stops in a sequence of gps data points
  List<Stop> findStops(List<SingleLocationPoint> data) {
    if (data.isEmpty) return [];

    List<Stop> stops = [];
    int n = data.length;

    /// Go through all the data points, i.e from index [0...n-1]
    int start = 0;
    while (start < n) {
      int end = start + 1;
      List<SingleLocationPoint> subset = data.sublist(start, end);
      Location centroid = Cluster.computeCentroid(subset);

      /// Expand cluster until either all data points have been considered,
      /// or the current data point lies outside the radius.
      while (end < n &&
          Distance.fromGeospatial(centroid, data[end]) <= stopRadius) {
        end += 1;
        subset = data.sublist(start, end);
        centroid = Cluster.computeCentroid(subset);
      }
      Stop s = Stop.fromPoints(subset);
      stops.add(s);

      /// Update the start index, such that we no longer look at
      /// the previously considered data points
      start = end;
    }

    /// Filter out stops which are shorter than the min. duration
    stops = stops.where((s) => (s.duration >= stopDuration)).toList();

    /// Add additional boundary stops, this is necessary to calculate moves.
//    Stop first = Stop.fromPoints([data.first]);
//    List<Stop> allStops = [first] + stops;
//
//    if (data.first != data.last) {
//      Stop last = Stop.fromPoints([data.last]);
//      allStops.add(last);
//    }

    return stops;
  }

  /// Finds the places by clustering stops with the DBSCAN algorithm
  List<Place> findPlaces(List<Stop> stops) {
    List<Place> places = [];

    DBSCAN dbscan = DBSCAN(
        epsilon: placeRadius,
        minPoints: 1,
        distanceMeasure: Distance.fromList);

    /// Extract gps coordinates from stops
    List<List<double>> stopCoordinates = stops
        .map((s) => ([s.location.latitude, s.location.longitude]))
        .toList();

    /// Run DBSCAN on data points
    dbscan.run(stopCoordinates);

    /// Extract labels for each stop, each label being a cluster
    /// Filter out stops labelled as noise (where label is -1)
    Set<int> clusterLabels = dbscan.label.where((l) => (l != -1)).toSet();

    for (int label in clusterLabels) {
      /// Get indices of all stops with the current cluster label
      List<int> indices =
          stops.asMap().keys.where((i) => (dbscan.label[i] == label)).toList();

      /// For each index, get the corresponding stop
      List<Stop> stopsForPlace = indices.map((i) => (stops[i])).toList();

      /// Add place to the list
      Place p = Place(label, stopsForPlace);
      places.add(p);

      /// Set placeId field for the stops belonging to this place
      stopsForPlace.forEach((s) => s.placeId = p._id);
    }
    return places;
  }

  List<Move> findMoves(List<SingleLocationPoint> data, List<Stop> stops) {
    if (stops.isEmpty) return [];
    List<Move> moves = [];
    /// Insert two placeholder stops, as the first and last data point gathered
    Stop first = Stop.fromPoints([data.first]);
    List<Stop> allStops = [first] + stops;

    if (data.first != data.last) {
      Stop last = Stop.fromPoints([data.last]);
      allStops.add(last);
    }

    /// Create moves from stops
    for (int i = 0; i < allStops.length - 1; i++) {
      Stop cur = allStops[i];
      Stop next = allStops[i + 1];

      /// Extract all points (including the 'loose' points) between the two stops
      List<SingleLocationPoint> pointsInBetween = data
          .where((d) =>
              cur.departure.leq(d.datetime) && d.datetime.leq(next.arrival))
          .toList();

      moves.add(Move.fromPath(cur, next, pointsInBetween));
    }

    /// Filter out moves based on the minimum duration
    return moves.where((m) => m.duration >= moveDuration).toList();
  }
}
