part of mobility_features_lib;

/// Preprocessing for the Feature Extraction.
/// Finds Stops, Places and Moves for a day of GPS data
class Preprocessor {
  double _minStopDist = 25,
      _minPlaceDist = 25,
      _mergeDist = 5,
      _minMoveDist = 50;
  Duration _minStopDuration = Duration(minutes: 15),
      _minMoveDuration = Duration(minutes: 5),
      _minMergeDuration = Duration(minutes: 5);
  bool _merge = false;

  Preprocessor(data);

  /// Calculate centroid of a gps point cloud
  Location _findCentroid(List<Location> data) {
    List<double> lats = data.map((d) => (d.latitude)).toList();
    List<double> lons = data.map((d) => (d.longitude)).toList();

    double medianLat = Stats.fromData(lats).median as double;
    double medianLon = Stats.fromData(lons).median as double;

    return Location(medianLat, medianLon);
  }

  /// Checks if two points are within the minimum distance
  bool _isWithinMinStopDist(Location a, Location b) {
    double d =
        haversineDist([a.latitude, a.longitude], [b.latitude, b.longitude]);
    return d <= _minStopDist;
  }

  /// Find the stops in a sequence of gps data points
  List<Stop> findStops(List<LocationData> data) {
    List<Stop> stops = [];
    int i = 0;
    int j;
    int N = data.length;
    List<LocationData> dataSubset;
    Location centroid;

    /// Go through all the data points
    /// Each iteration looking at a subset of the data set
    while (i < N) {
      j = i + 1;
      dataSubset = data.sublist(i, j);
      centroid = _findCentroid(dataSubset.map((d) => (d.location)).toList());

      /// Include a new data point until no longer within radius
      /// to be considered at stop
      /// or when all points have been taken
      while (j < N && _isWithinMinStopDist(data[j].location, centroid)) {
        j += 1;
        dataSubset = data.sublist(i, j);
        centroid = _findCentroid(dataSubset.map((d) => (d.location)).toList());
      }

      /// The centroid of the biggest subset is the location of the found stop
      Stop s = Stop(centroid, dataSubset.first.timestamp,
          dataSubset.last.timestamp, dataSubset.length);
      stops.add(s);

      /// Update i, such that we no longer look at
      /// the previously considered data points
      i = j;
    }

    /// Filter out stops which are shorter than the min. duration
    print(stops.length);
    stops = stops.where((s) => (s.duration >= _minStopDuration)).toList();

    /// If merge parameter set to true, then merge noisy stops
    /// Otherwise leave them in
    return _merge ? _mergeStops(stops) : stops;
  }

  /// Finds the places by clustering stops with the DBSCAN algorithm
  List<Place> findPlaces(List<Stop> stops) {
    List<Place> places = [];

    DBSCAN dbscan = DBSCAN(
        epsilon: _minPlaceDist, minPoints: 1, distanceMeasure: haversineDist);

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
      Location centroid = _findCentroid(stopsLocations);

      /// Calculate the sum of the durations spent at the stops,
      /// belonging to the place
      Duration duration =
          stopsForPlace.map((s) => (s.duration)).reduce((a, b) => a + b);

      /// Add place to the list
      Place p = Place(label, centroid, duration);
      places.add(p);

      /// Set placeId field for the stops belonging to this place
      stopsForPlace.forEach((s) => s.placeId = p.id);
    }
    return places;
  }

  List<Move> findMoves(List<LocationData> data, List<Stop> stops) {
    List<Move> moves = [];
    DateTime departure = DateTime.fromMillisecondsSinceEpoch(
        data.map((d) => (d.timestamp.millisecondsSinceEpoch)).reduce(min));
    DateTime arrival;

    /// Non-existent starting stop
    int prevPlaceId = -1;

    for (Stop stop in stops) {
      /// Check for moves between this and the next stop
      List<LocationData> locationPoints = data
          .where((d) =>
              (geq(d.timestamp, departure) && leq(d.timestamp, stop.arrival)))
          .toList();

      /// We have moves between stop[i] and stop[i+1]
      if (locationPoints.isNotEmpty) {
        arrival = stop.arrival;

        moves.add(Move(
            locationPoints.first.location,
            locationPoints.last.location,
            prevPlaceId,
            stop.placeId,
            departure,
            stop.arrival));

        departure = stop.departure;
        prevPlaceId = stop.placeId;
      }

      /// Otherwise, if there is a 'dead end' i.e.
      /// no moves between stop[i] and stop[i+1]
      else {
        /// Check for moves after the current stop
        locationPoints =
            data.where((d) => (geq(d.timestamp, departure))).toList();

        /// We have moves after stop[i]
        if (locationPoints.isNotEmpty) {
          int arrivalMs = locationPoints
              .map((d) => (d.timestamp.millisecondsSinceEpoch))
              .reduce((a, b) => (a + b));
          arrival = DateTime.fromMillisecondsSinceEpoch(arrivalMs);

          /// Set -1 as the place_id for the move, since it
          /// has a 'dead end' i.e. the stop would be considered noise by DBSCAN
          moves.add(Move(
              locationPoints.first.location,
              locationPoints.last.location,
              prevPlaceId,
              -1,
              departure,
              arrival));
        }
      }
    }

    /// Filter out moves that are too short according to the criterion
    return moves
        .where((m) =>
            (m.duration >= _minMoveDuration && m.distance >= _minMoveDist))
        .toList();
  }

  /// Criteria for merging a stop with another
  bool _mergeCriteria(double deltaDist, Duration deltaTime) {
    return deltaDist <= _mergeDist && deltaTime <= _minMergeDuration;
  }

  /// Merging noisy stops, not working as intended right now
  List<Stop> _mergeStops(List<Stop> stops) {
    /// Check if merge applicable
    if (stops.length < 2) {
      return stops;
    }

    List<Stop> merged = [];
    List<int> idx = stops.asMap().keys.toList();

    /// Compute deltas
    int nStops = stops.length;
    List<double> lats = stops.map((s) => (s.location.latitude)).toList();
    List<double> lons = stops.map((s) => (s.location.longitude)).toList();

    /// Shift, and backwards-fill
    List<double> latsShifted = [lats[0]] + lats.sublist(0, nStops - 1);
    List<double> lonsShifted = [lons[0]] + lons.sublist(0, nStops - 1);

    List<double> deltaMeters = idx
        .map((i) => (haversineDist(
            [lats[i], lons[i]], [latsShifted[i], lonsShifted[i]])))
        .toList();

    List<DateTime> arrivals = stops.map((s) => (s.arrival)).toList();
    List<DateTime> departures = stops.map((s) => (s.departure)).toList();

    /// The first entry should be 0 after subtracing the arrival from the
    /// departure, this is why the first entry of the shifted departures is
    /// set to the first element of the arrivals
    List<DateTime> departuresShifted =
        [arrivals[0]] + departures.sublist(0, nStops - 1);
    List<Duration> deltaTime = zip([arrivals, departuresShifted])
        .map((t) => (Duration(
            milliseconds:
                t[0].millisecondsSinceEpoch - t[1].millisecondsSinceEpoch)))
        .toList();

    /// List of indices from 0 to N.
    /// Filter out indices for which the stop does not satisfy the criteria
    /// Bad indices are marked with -1, good indices are left alone
    List<int> mergeIdx = idx
        .map((i) => (_mergeCriteria(deltaMeters[i], deltaTime[i]) ? -1 : i))
        .toList();

    /// Forward fill indices, make sure first index is not -1 (set it manually)
    mergeIdx[0] = 0;
    mergeIdx = idx
        .map((i) => (mergeIdx[i] >= 0 ? mergeIdx[i] : mergeIdx[i - 1]))
        .toList();

    Set<int> stopIndices = mergeIdx.toSet();

    /// Merge stops based on their indices
    for (int index in stopIndices) {
      List<int> stopsToMergeIdx =
          idx.where((i) => (mergeIdx[i] == index)).toList();
      List<Stop> stopsToMerge = stopsToMergeIdx.map((i) => (stops[i])).toList();

      /// Calculate mean location of the stops to merge
      List<double> lats =
          stopsToMerge.map((s) => (s.location.latitude)).toList();
      List<double> lons =
          stopsToMerge.map((s) => (s.location.longitude)).toList();

      Location meanLocation =
          Location(Stats.fromData(lats).mean, Stats.fromData(lons).mean);

      /// Sum up gps samples used to create the stop
      int samplesSum =
          stopsToMerge.map((s) => (s.samples)).reduce((a, b) => a + b);

      /// Find arrival and departure with min and max
      int arrivalMs = stopsToMerge
          .map((s) => (s.arrival.millisecondsSinceEpoch))
          .reduce(min);
      int departureMs = stopsToMerge
          .map((s) => (s.departure.millisecondsSinceEpoch))
          .reduce(max);
      DateTime arrival = DateTime.fromMillisecondsSinceEpoch(arrivalMs);
      DateTime departure = DateTime.fromMillisecondsSinceEpoch(departureMs);
      merged.add(Stop(meanLocation, arrival, departure, samplesSum));
    }

    return merged;
  }
}
