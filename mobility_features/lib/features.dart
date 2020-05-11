part of mobility_features_lib;

const int MILLISECONDS_IN_A_DAY = 24 * 60 * 60 * 1000;

class Features {
  List<Stop> _stopsForPeriod, _stopsDaily;
  List<Place> _placesForPeriod, _placesDaily;
  List<Move> _movesForPeriod, _movesDaily;
  DateTime _date;
  List<DateTime> _uniqueDates, _historicalDates;
  DateTime _timestamp = DateTime.now();

  Features(this._date, this._stopsForPeriod, this._placesForPeriod,
      this._movesForPeriod) {
    this._stopsDaily =
        _stopsForPeriod.where((d) => d.arrival.midnight == _date).toList();
    this._placesDaily = _placesForPeriod
        .where((p) => p.durationForDate(_date).inMilliseconds > 0)
        .toList();
    this._movesDaily = _movesForPeriod
        .where((d) => d.stopFrom.arrival.midnight == _date)
        .toList();
    this._uniqueDates =
        _stopsForPeriod.map((s) => s.arrival.midnight).toSet().toList();
    this._historicalDates =
        _uniqueDates.where((d) => d.isBefore(_date.midnight)).toList();
  }

  /// Preprocessing feature: All stops
  List<Stop> get stopsForPeriod => _stopsForPeriod;

  /// Preprocessing feature: Daily stops
  List<Stop> get stopsDaily => _stopsDaily;

  /// Preprocessing feature: All places
  List<Place> get placesForPeriod => _placesForPeriod;

  /// Preprocessing feature: Daily places
  List<Place> get placesDaily => _placesDaily;

  /// Preprocessing feature: All moves
  List<Move> get movesForPeriod => _movesForPeriod;

  /// Preprocessing feature: Daily moves
  List<Move> get movesDaily => _movesDaily;

  /// Number of clusters found by DBSCAN, i.e. number of places
  int get numberOfClustersAggregate => placesForPeriod.length;

  /// Number of clusters on the specified date
  int get numberOfClustersDaily => _placesDaily.length;

  /// Location variance for all stops
  double get locationVarianceAggregate =>
      _calcLocationVariance(_stopsForPeriod);

  /// Location variance today
  double get locationVarianceDaily => _calcLocationVariance(_stopsDaily);

  /// Total entropy
  double get entropyAggregate =>
      _calcEntropy(placesForPeriod.map((p) => p.duration).toList());

  /// Entropy today
  double get entropyDaily =>
      _calcEntropy(_placesDaily.map((p) => p.durationForDate(_date)).toList());

  /// Normalized Entropy, i.e. entropy relative to the number of places
  double get normalizedEntropyAggregate => numberOfClustersAggregate > 1
      ? entropyAggregate / log(numberOfClustersAggregate)
      : 0.0;

  /// Normalized Entropy for the date specified in the constructor
  double get normalizedEntropyDaily => numberOfClustersDaily > 1
      ? entropyDaily / log(numberOfClustersDaily)
      : 0.0;

  /// Total distance travelled in meters
  double get totalDistanceAggregate =>
      movesForPeriod.map((m) => (m.distance)).fold(0.0, (a, b) => a + b);

  /// Total distance travelled in meters for the specified date
  double get totalDistanceDaily =>
      _movesDaily.map((m) => (m.distance)).fold(0.0, (a, b) => a + b);

  /// Routine index (daily)
  double get routineIndexDaily =>
      _computeRoutineOverlap([_date.midnight], _historicalDates);

  /// Routine index (aggregate)
  double get routineIndexAggregate =>
      _computeRoutineOverlap(_uniqueDates, _historicalDates);

  Place _placeLookUp(int id) {
    return _placesForPeriod.where((p) => p.id == id).first;
  }

  /// Home Stay
  double get homeStayAggregate {
    int total = _uniqueDates.length * MILLISECONDS_IN_A_DAY;
    int homeId = _homePlaceIdForPeriod();
    if (homeId == -1) return -1.0;
    Place homePlace = _placeLookUp(homeId);
    int home = homePlace.duration.inMilliseconds;
    print('Home stay, home: $home');

    return _calcHomeStay(total, home);
  }

  /// Home Stay Daily
  double get homeStayDaily {
    /// Total time elapsed today since midnight
    int total = DateTime.now().millisecondsSinceEpoch -
        DateTime.now().midnight.millisecondsSinceEpoch;

    /// Find todays  home id
    HourMatrix hm =
        HourMatrix.fromStops(_stopsDaily, numberOfClustersAggregate);
    if (hm.homePlaceId == -1) return -1.0;
    Place homePlace = _placeLookUp(hm.homePlaceId);

    int home = homePlace.durationForDate(_date).inMilliseconds;
    print('Home stay daily, home: $home');

    return _calcHomeStay(total, home);
  }

  /// Hour Matrix for today
  HourMatrix get hourMatrixDaily =>
      HourMatrix.fromStops(_stopsDaily, numberOfClustersAggregate);

  /// Hour Matrix for period, averaged
  HourMatrix get hourMatrixAggregate => null;

  /// Auxiliary calculations for feature extraction
  /// Location variance calculation
  double _calcLocationVariance(List<Stop> stopsList) {
    /// Require at least 2 observations
    if (stopsList.length < 2) {
      return 0.0;
    }
    double latStd = Stats.fromData(stopsList.map((s) => (s.centroid.latitude)))
        .standardDeviation;
    double lonStd = Stats.fromData(stopsList.map((s) => (s.centroid.longitude)))
        .standardDeviation;
    return log(latStd * latStd + lonStd * lonStd + 1);
  }

  /// Entropy calculates how dispersed time is between places
  double _calcEntropy(List<Duration> durations) {
    if (durations.isEmpty) return -1.0;
    Duration sum = durations.fold(Duration(), (a, b) => a + b);

    List<double> distribution = durations
        .map((d) =>
            (d.inMilliseconds.toDouble() / sum.inMilliseconds.toDouble()))
        .toList();
    return -distribution.map((p) => p * log(p)).reduce((a, b) => (a + b));
  }

  /// Find the place ID of the HOME place for a longer period
  int _homePlaceIdForPeriod() {
    List<int> candidates = [];

    // Find the most popular place between 00:00 and 06:00 for each day
    for (DateTime d in _uniqueDates) {
      List<Stop> stopsOnDate =
          stopsForPeriod.where((s) => s.arrival.midnight == d).toList();
      HourMatrix hours =
          HourMatrix.fromStops(stopsOnDate, numberOfClustersAggregate);
      int id = hours.homePlaceId;
      if (id == -1) {
        print('No time spent at night for this date.');
      } else {
        candidates.add(id);
      }
    }

    if (candidates.isEmpty) return -1;

    /// Reduce to unique candidates
    List<int> unique = candidates.toSet().toList();

    /// Count the frequency of each candidate
    List<int> counts =
        unique.map((x) => candidates.where((y) => y == x).length).toList();

    /// Return the candidate with the highest frequency
    return unique[argmaxInt(counts)];
  }

  /// Home Stay calculation
  double _calcHomeStay(int timeSpentTotal, int timeSpentAtHome) {
    return timeSpentAtHome.toDouble() / timeSpentTotal.toDouble();
  }

  /// Routine index (overlap) calculation
  double _computeRoutineOverlap(
      List<DateTime> days, List<DateTime> historical) {
    double avgOverlap = 0.0;

    if (historical.isEmpty) return -1.0;

    /// Make historical Hour Matrices
    List<HourMatrix> matrices = historical
        .map((d) => HourMatrix.fromStops(
            _stopsForPeriod
                .where((s) => s.arrival.midnight == d.midnight)
                .toList(),
            numberOfClustersAggregate))
        .toList();

    /// Compute average matrix for the historical dates
    HourMatrix avgMatrix = HourMatrix.average(matrices);

    /// For each date in current dates:
    /// Compute the error between the HourMatrix of this date,
    /// and the average historical matrix
    for (DateTime d in days) {
      HourMatrix matrixToday = HourMatrix.fromStops(
          _stopsForPeriod.where((s) => s.arrival.midnight == d).toList(),
          numberOfClustersAggregate);
      avgOverlap += matrixToday.computeOverlap(avgMatrix) / days.length;
    }
    return avgOverlap;
  }

  /// Serialization
  Map<String, dynamic> toJson() {
    return {
      'date': _date.toIso8601String(),
      'timestamp': _timestamp.toIso8601String(),
      'number_of_places_aggregate': numberOfClustersAggregate,
      'number_of_places_today': numberOfClustersDaily,
      'home_stay_aggregate': homeStayAggregate,
      'home_stay_today': homeStayDaily,
      'entropy_aggregate': entropyAggregate,
      'entropy_today': entropyDaily,
      'normalized_entropy_aggregate': normalizedEntropyAggregate,
      'normalized_entropy_today': normalizedEntropyDaily,
      'total_distance_aggregate': totalDistanceAggregate,
      'total_distance_today': totalDistanceDaily,
      'routine_index_aggregate': routineIndexAggregate,
      'routine_index_today': routineIndexDaily,
    };
  }
}
