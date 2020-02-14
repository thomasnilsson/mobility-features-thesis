part of mobility_features_lib;

/// Preprocessing for the Feature Extraction.
/// Finds Stops, Places and Moves for a day of GPS data
class Preprocessor {
  double stopRadius, placeRadius, moveRadius = 50;
  Duration stopDuration, moveDuration;
  List<SingleLocationPoint> data;

  Preprocessor(this.data,
      {this.stopRadius = 25,
      this.placeRadius = 25,
      this.moveRadius = 50,
      this.stopDuration = const Duration(minutes: 15),
      this.moveDuration = const Duration(minutes: 5)});

  /// Extracts unique dates in the dataset.
  Set<DateTime> get uniqueDates {
    Set<DateTime> uniqueDates = data.map((d) => (d._datetime.date)).toSet();
    return uniqueDates;
  }

  Features featuresByDate(DateTime date) {
    List<Stop> stops = [];

    for (List<SingleLocationPoint> d in dataGroupedByDates) {
      List<Stop> s = _findStops(d);
      stops.addAll(s);
    }

    List<Place> places = _findPlaces(stops);
    List<Move> moves = _findMoves(data, stops);

    return Features(date, uniqueDates, data, stops, places, moves);
  }

  /// Groups the dataset by dates.
  /// This is necessary since data is processed on a daily basis.
  List<List<SingleLocationPoint>> get dataGroupedByDates {
    List<List<SingleLocationPoint>> grouped = [];

    for (DateTime _date in uniqueDates) {
      grouped.add(data.where((d) => (d._datetime.date == _date)).toList());
    }
    return grouped;
  }

  /// Find the stops in a sequence of gps data points
  List<Stop> _findStops(List<SingleLocationPoint> data) {
    List<Stop> stops = [];
    int n = data.length;

    /// Go through all the data points
    /// Each iteration looking at a subset of the data set
    for (int i = 0; i < n; i++) {
      int j = i + 1;
      List<SingleLocationPoint> cluster = data.sublist(i, j);
      Location centroid = calculateCentroid(cluster.locations);

      /// Expand cluster until either all data points have been considered,
      /// or the current data point lies outside the radius.
      while (
          j < n && Distance.isWithin(data[j]._location, centroid, stopRadius)) {
        j += 1;
        cluster = data.sublist(i, j);
        centroid = calculateCentroid(cluster.locations);
      }
      stops.add(Stop(cluster));

      /// Update i, such that we no longer look at
      /// the previously considered data points
      i = j;
    }

    /// Filter out stops which are shorter than the min. duration
    stops = stops.where((s) => (s.duration >= stopDuration)).toList();

    return stops;
  }

  /// Finds the places by clustering stops with the DBSCAN algorithm
  List<Place> _findPlaces(List<Stop> stops) {
    List<Place> places = [];

    DBSCAN dbscan = DBSCAN(
        epsilon: placeRadius,
        minPoints: 1,
        distanceMeasure: Distance.fromDouble);

    /// Extract gps coordinates from stops
    List<List<double>> stopCoordinates = stops
        .map((s) => ([s._centroid._latitude, s._centroid._longitude]))
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


  List<Move> _findMoves(List<SingleLocationPoint> data, List<Stop> stops) {
    List<Move> moves = [];

    /// Create moves from stops
    for (int i = 0; i < stops.length - 1; i++) {
      Stop cur = stops[i];
      Stop next = stops[i + 1];

      /// Extract all points (including the 'loose' points) between the two stops
      List<SingleLocationPoint> pointsInBetween = data.where(
          (d) => cur.departure.leq(d._datetime) && d._datetime.leq(next.arrival)).toList();

      moves.add(Move(cur, next, pointsInBetween));
    }

    /// Filter out moves based on the minimum duration
    return moves.where((m) => m.duration >= moveDuration).toList();
  }
}
