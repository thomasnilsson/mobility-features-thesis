part of mobility_features_lib;

/// Find the stops in a sequence of gps data points
List<Stop> _findStops(List<SingleLocationPoint> data, DateTime date,
    {double stopRadius = 25.0,
    Duration stopDuration = const Duration(minutes: 3)}) {
  if (data.isEmpty) return [];

  List<Stop> stops = [];
  int n = data.length;

  /// Go through all the data points, i.e from index [0...n-1]
  int start = 0;
  while (start < n) {
    int end = start + 1;
    List<SingleLocationPoint> subset = data.sublist(start, end);
    Location centroid = _Cluster.computeCentroid(subset);

    /// Expand cluster until either all data points have been considered,
    /// or the current data point lies outside the radius.
    while (
        end < n && Distance.fromGeospatial(centroid, data[end]) <= stopRadius) {
      end += 1;
      subset = data.sublist(start, end);
      centroid = _Cluster.computeCentroid(subset);
    }
    Stop s = Stop._fromPoints(subset);
    stops.add(s);

    /// Update the start index, such that we no longer look at
    /// the previously considered data points
    start = end;
  }

  /// Filter out stops which are shorter than the min. duration
  stops = stops.where((s) => (s.duration >= stopDuration)).toList();

  return stops;
}

/// Finds the places by clustering stops with the DBSCAN algorithm
List<Place> _findPlaces(List<Stop> stops, {double placeRadius = 50.0}) {
  List<Place> places = [];

  DBSCAN dbscan = DBSCAN(
      epsilon: placeRadius, minPoints: 1, distanceMeasure: Distance.fromList);

  /// Extract gps coordinates from stops
  List<List<double>> stopCoordinates =
      stops.map((s) => ([s.location.latitude, s.location.longitude])).toList();

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
    Place p = Place._(label, stopsForPlace);
    places.add(p);

    /// Set placeId field for the stops belonging to this place
    stopsForPlace.forEach((s) => s.placeId = p._id);
  }
  return places;
}

List<Move> _findMoves(List<SingleLocationPoint> data, List<Stop> stops,
    {Duration moveDuration = const Duration(minutes: 3)}) {
  if (stops.isEmpty) return [];
  List<Move> moves = [];

  /// Insert two placeholder stops, as the first and last data point gathered
  Stop first = Stop._fromPoints([data.first]);
  List<Stop> allStops = [first] + stops;

  if (data.first != data.last) {
    Stop last = Stop._fromPoints([data.last]);
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

    moves.add(Move._fromPath(cur, next, pointsInBetween));
  }

  /// Filter out moves based on the minimum duration
  return moves.where((m) => m.duration >= moveDuration).toList();
}
