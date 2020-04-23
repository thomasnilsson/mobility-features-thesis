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
  List<Stop> findStops(List<SingleLocationPoint> data, {bool filter: true}) {
    if (data.isEmpty) return [];
    /// Filter out data not on the specified date
    if (filter) {
      data = pointsToday(data);
    }

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
          j < n && Distance.isWithin(data[j].location, centroid, stopRadius)) {
        j += 1;
        cluster = data.sublist(i, j);
        centroid = calculateCentroid(cluster.locations);
      }
      Stop s = Stop.fromPoints(cluster);
      stops.add(s);

      /// Update i, such that we no longer look at
      /// the previously considered data points
      i = j;
    }

    /// Filter out stops which are shorter than the min. duration
    stops = stops.where((s) => (s.duration >= stopDuration)).toList();

    return stops;
  }

  /// Finds the places by clustering stops with the DBSCAN algorithm
  List<Place> findPlaces(List<Stop> stops) {
    List<Place> places = [];

    DBSCAN dbscan = DBSCAN(
        epsilon: placeRadius,
        minPoints: 1,
        distanceMeasure: Distance.fromDouble);

    /// Extract gps coordinates from stops
    List<List<double>> stopCoordinates = stops
        .map((s) => ([s.centroid.latitude, s.centroid.longitude]))
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

  List<Move> findMoves(List<SingleLocationPoint> data, List<Stop> stops,
      {bool filter: true}) {

    if (stops.isEmpty) return [];
    /// Filter out data not on the specified date
    if (filter) {
      data = pointsToday(data);
    }
    List<Move> moves = [];

    List<SingleLocationPoint> pointsBeforeFirstPlace =
        data.where((d) => d.datetime.leq(stops.first.arrival)).toList();

    Stop firstStop = Stop.fromPoints([data.first]);

    Move firstMove = Move.fromPoints(firstStop, stops.first, pointsBeforeFirstPlace);

    moves.add(firstMove);

    /// Create moves from stops
    for (int i = 0; i < stops.length - 1; i++) {
      Stop cur = stops[i];
      Stop next = stops[i + 1];

      /// Extract all points (including the 'loose' points) between the two stops
      List<SingleLocationPoint> pointsInBetween = data
          .where((d) =>
              cur.departure.leq(d.datetime) && d.datetime.leq(next.arrival))
          .toList();

      moves.add(Move.fromPoints(cur, next, pointsInBetween));
    }

    /// Filter out moves based on the minimum duration
    return moves.where((m) => m.duration >= moveDuration).toList();
  }

// Merging noisy stops, not working as intended right now
//  List<Stop> _mergeStops(List<Stop> stops) {
//    /// Check if merge applicable
//    if (stops.length < 2) {
//      return stops;
//    }
//
//    List<Stop> merged = [];
//    List<int> idx = stops.asMap().keys.toList();
//
//    /// Compute deltas
//    int nStops = stops.length;
//    List<double> lats = stops.map((s) => (s.location.latitude)).toList();
//    List<double> lons = stops.map((s) => (s.location.longitude)).toList();
//
//    /// Shift, and backwards-fill
//    List<double> latsShifted = [lats[0]] + lats.sublist(0, nStops - 1);
//    List<double> lonsShifted = [lons[0]] + lons.sublist(0, nStops - 1);
//
//    List<double> deltaMeters = idx
//        .map((i) => (haversineDist(
//        [lats[i], lons[i]], [latsShifted[i], lonsShifted[i]])))
//        .toList();
//
//    List<int> arrivals = stops.map((s) => (s.arrival)).toList();
//    List<int> departures = stops.map((s) => (s.departure)).toList();
//
//    /// The first entry should be 0 after subtracing the arrival from the
//    /// departure, this is why the first entry of the shifted departures is
//    /// set to the first element of the arrivals
//    List<int> departuresShifted =
//        [arrivals[0]] + departures.sublist(0, nStops - 1);
//    List<Duration> deltaTime = zip([arrivals, departuresShifted])
//        .map((t) => (Duration(milliseconds: t[0] - t[1])))
//        .toList();
//
//    /// List of indices from 0 to N.
//    /// Filter out indices for which the stop does not satisfy the criteria
//    /// Bad indices are marked with -1, good indices are left alone
//    List<int> mergeIdx = idx
//        .map((i) => (_mergeCriteria(deltaMeters[i], deltaTime[i]) ? -1 : i))
//        .toList();
//
//    /// Forward fill indices, make sure first index is not -1 (set it manually)
//    mergeIdx[0] = 0;
//    mergeIdx = idx
//        .map((i) => (mergeIdx[i] >= 0 ? mergeIdx[i] : mergeIdx[i - 1]))
//        .toList();
//
//    Set<int> stopIndices = mergeIdx.toSet();
//
//    /// Merge stops based on their indices
//    for (int index in stopIndices) {
//      List<int> stopsToMergeIdx =
//      idx.where((i) => (mergeIdx[i] == index)).toList();
//      List<Stop> stopsToMerge = stopsToMergeIdx.map((i) => (stops[i])).toList();
//
//      /// Calculate mean location of the stops to merge
//      List<double> lats =
//      stopsToMerge.map((s) => (s.location.latitude)).toList();
//      List<double> lons =
//      stopsToMerge.map((s) => (s.location.longitude)).toList();
//
//      Location meanLocation =
//      Location(Stats.fromData(lats).mean, Stats.fromData(lons).mean);
//
//      /// Sum up gps samples used to create the stop
//      int samplesSum =
//      stopsToMerge.map((s) => (s.samples)).reduce((a, b) => a + b);
//
//      /// Find arrival and departure with min and max
//      int arrival = stopsToMerge.map((s) => (s.arrival)).reduce(min);
//      int departure = stopsToMerge.map((s) => (s.departure)).reduce(max);
//      merged.add(Stop(meanLocation, arrival, departure, samplesSum));
//    }
//
//    return merged;
//  }
}
