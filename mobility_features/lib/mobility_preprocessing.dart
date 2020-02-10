part of mobility_features_lib;

/// Preprocessing for the Feature Extraction.
/// Finds Stops, Places and Moves for a day of GPS data
class Preprocessor {
  double minStopDist = 25, minPlaceDist = 25, mergeDist = 5, minMoveDist = 50;
  Duration minStopDuration = Duration(minutes: 15),
      minMoveDuration = Duration(minutes: 5),
      minMergeDuration = Duration(minutes: 5);
  bool enableMerging = false;
  List<LocationData> data;

  Preprocessor(this.data,
      {this.minStopDist = 25,
      this.minPlaceDist = 25,
      this.minMoveDist = 50,
      this.mergeDist = 5,
      this.minStopDuration = const Duration(minutes: 15),
      this.minMoveDuration = const Duration(minutes: 5),
      this.minMergeDuration = const Duration(minutes: 5),
      this.enableMerging = false});

  /// Extracts unique dates in the dataset.
  Set<DateTime> get uniqueDates {
    Set<DateTime> uniqueDates = data.map((d) => (d.datetime.date)).toSet();
    return uniqueDates;
  }

  Features featuresByDate(DateTime date) {
    List<Stop> stops = [];

    for (List<LocationData> d in dataGroupedByDates) {
      List<Stop> s = _findStops(d);
      stops.addAll(s);
    }

    List<Place> places = _findPlaces(stops);
    List<Move> moves = _findMoves(data, stops);

    return Features(date, data, stops, places, moves);
  }

  /// Groups the dataset by dates.
  /// This is necessary since data is processed on a daily basis.
  List<List<LocationData>> get dataGroupedByDates {
    List<List<LocationData>> grouped = [];

    for (DateTime _date in uniqueDates) {
      grouped.add(data.where((d) => (d.datetime.date == _date)).toList());
    }
    return grouped;
  }

  /// Checks if two points are within the minimum distance
  bool _isWithinMinStopDist(Location a, Location b) {
    double d = HaversineDist.fromLocation(a, b);
    return d <= minStopDist;
  }

  /// Find the stops in a sequence of gps data points
  List<Stop> _findStops(List<LocationData> data) {
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
      centroid = calculateCentroid(dataSubset.locations);

      /// Include a new data point until no longer within radius
      /// to be considered at stop
      /// or when all points have been taken
      while (j < N && _isWithinMinStopDist(data[j].location, centroid)) {
        j += 1;
        dataSubset = data.sublist(i, j);
        centroid = calculateCentroid(dataSubset.locations);
      }

      Stop s = Stop(dataSubset);
      stops.add(s);

      /// Update i, such that we no longer look at
      /// the previously considered data points
      i = j;
    }

    /// Filter out stops which are shorter than the min. duration
    stops = stops.where((s) => (s.duration >= minStopDuration)).toList();

    return stops;
  }

  /// Finds the places by clustering stops with the DBSCAN algorithm
  List<Place> _findPlaces(List<Stop> stops) {
    List<Place> places = [];

    DBSCAN dbscan = DBSCAN(
        epsilon: minPlaceDist,
        minPoints: 1,
        distanceMeasure: HaversineDist.fromDouble);

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

//      /// Given all stops belonging to a place,
//      /// calculate the centroid of the place
//      List<Location> stopsLocations =
//          stopsForPlace.map((x) => (x.location)).toList();
//      Location centroid = calculateCentroid(stopsLocations);
//
//      /// Calculate the sum of the durations spent at the stops,
//      /// belonging to the place
//      Duration duration =
//          stopsForPlace.map((s) => (s.duration)).reduce((a, b) => a + b);

      /// Add place to the list
      Place p = Place(label, stopsForPlace);
      places.add(p);

      /// Set placeId field for the stops belonging to this place
      stopsForPlace.forEach((s) => s.placeId = p.id);
    }
    return places;
  }

  List<Move> _findMoves(List<LocationData> data, List<Stop> stops) {
    List<Move> moves = [];
    List<Stop> fromStops =
        stops.sublist(0, stops.length - 1); // All except last
    List<Stop> toStops = stops.sublist(1); // All except first

    /// Zip the stops and creates moves
    for (int i = 0; i < fromStops.length; i++) {
      Move m = Move(fromStops[i], toStops[i]);
      moves.add(m);
    }

    /// Filter out moves based on the minimum duration
    return moves.where((m) => m.duration >= minMoveDuration).toList();
  }
}
