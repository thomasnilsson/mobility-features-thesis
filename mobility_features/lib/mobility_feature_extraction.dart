part of mobility_features_lib;

class FeaturesAggregate {

  List<Stop> _stops, _stopsDaily;
  List<Place> _places, _placesDaily;
  List<Move> _moves, _movesDaily;
  DateTime _date;
  Set<DateTime> _uniqueDates;

  FeaturesAggregate(this._date, this._stops, this._places, this._moves) {

    // TODO: Load stops from disk
    this._stopsDaily =
        _stops.where((d) => d.arrival.midnight == _date).toList();
    this._placesDaily = _places
        .where((p) => p.durationForDate(_date).inMilliseconds > 0)
        .toList();
    this._movesDaily =
        _moves.where((d) => d.stopFrom.arrival.midnight == _date).toList();
    this._uniqueDates = _stops.map((s) => s.arrival.midnight).toSet();
  }

  /// FEATURES
  List<Stop> get stops => _stops;

  List<Place> get places => _places;

  List<Move> get moves => _moves;

  /// Number of clusters found by DBSCAN, i.e. number of places
  int get numberOfClusters => places.length;

  /// Number of clusters on the specified date
  int get numberOfClustersDaily => _placesDaily.length;

  /// Location variance today
//  double get locationVarianceDaily => calcLocationVariance(_dataDaily);

  double get entropy => calcEntropy(places.map((p) => p.duration).toList());

  double get entropyDaily =>
      calcEntropy(_placesDaily.map((p) => p.durationForDate(_date)).toList());

  /// Normalized Entropy, i.e. entropy relative to the number of places
  double get normalizedEntropy => entropy / log(numberOfClusters);

  /// Normalized Entropy for the date specified in the constructor
  double get normalizedEntropyDaily =>
      entropyDaily / log(numberOfClustersDaily);

  /// Total distance travelled in meters
  double get totalDistance =>
      moves.map((m) => (m.distance)).fold(0.0, (a, b) => a + b);

  /// Total distance travelled in meters for the specified date
  double get totalDistanceDaily => _movesDaily
      .map((m) => (m.distance))
      .fold(0, (a, b) => a + b);

  /// Routine index
  double get routineIndex => _calcRoutineIndex();

  /// Home Stay
  double get homeStay {
    int total =
    _places.map((p) => p.duration.inMilliseconds).fold(0, (a, b) => a + b);

    int home = _homePlace.duration.inMilliseconds;

    return calcHomeStay(total, home);
  }

  /// Home Stay Daily
  double get homeStayDaily {
    int total = _placesDaily
        .map((p) => p.durationForDate(_date).inMilliseconds)
        .fold(0, (a, b) => a + b);

    int home = _homePlace.durationForDate(_date).inMilliseconds;

    return calcHomeStay(total, home);
  }

  /// Auxiliary calculations for feature extraction
  /// Location variance calculation
  double calcLocationVariance(List<SingleLocationPoint> points) {
    /// Require at least 2 observations
    if (points.length < 2) {
      return 0.0;
    }
    double latStd = Stats.fromData(points.map((d) => (d.location.latitude)))
        .standardDeviation;
    double lonStd = Stats.fromData(points.map((d) => (d.location.longitude)))
        .standardDeviation;
    return log(latStd * latStd + lonStd * lonStd + 1);
  }

  double _calcRoutineIndex() {
    HourMatrix hourMatrixToday = HourMatrix(_stopsDaily, numberOfClusters);
    double totalError = 0.0;

    /// Extract past dates
    List<DateTime> datesHist = _uniqueDates.where((d) => d.isBefore(_date.midnight)).toList();

    if (datesHist.isEmpty) {
      return -1.0;
    }

    /// TODO: Only calculate error between a start and end time
    for (DateTime d in datesHist) {
      List<Stop> histStops = stops.where((s) => s.arrival.midnight == d.midnight).toList();
      HourMatrix x = HourMatrix(histStops, numberOfClusters);
      totalError += hourMatrixToday.computeError(x);
    }
    // Average error
    totalError = totalError / datesHist.length;

    return 1 - totalError;
  }

  /// Entropy calculates how dispersed time is between places
  double calcEntropy(List<Duration> durations) {
    Duration sum = durations.fold(Duration(), (a, b) => a + b);

    List<double> distribution = durations
        .map((d) =>
    (d.inMilliseconds.toDouble() / sum.inMilliseconds.toDouble()))
        .toList();
    return -distribution.map((p) => p * log(p)).reduce((a, b) => (a + b));
  }

  /// Find the place ID of the HOME place
  Place get _homePlace {
    List<int> candidates = [];

    // Find the most popular place between 00:00 and 06:00 for each day
    for (DateTime d in _uniqueDates) {
      List<Stop> stopsOnDate =
      stops.where((s) => s.arrival.midnight == d).toList();
      HourMatrix hours = HourMatrix(stopsOnDate, numberOfClusters);
      candidates.add(hours.homePlaceId);
    }

    /// Reduce to unique candidates
    List<int> unique = candidates.toSet().toList();

    /// Count the frequency of each candidate
    List<int> counts =
    unique.map((x) => candidates.where((y) => y == x).length).toList();

    /// Return the candidate with the highest frequency
    int homeId = unique[argmaxInt(counts)];
    return _places.where((p) => p.id == homeId).first;
  }

  /// Home Stay calculation
  double calcHomeStay(int timeSpentTotal, int timeSpentAtHome) {
    // Avoid div by zero error
    timeSpentTotal = timeSpentTotal > 0 ? timeSpentTotal : 1;

    return timeSpentAtHome.toDouble() / timeSpentTotal.toDouble();
  }

}

class Features {
  Preprocessor _preprocessor;
  List<SingleLocationPoint> _data, _dataDaily;
  List<Stop> _stops, _stopsDaily;
  List<Place> _places, _placesDaily;
  List<Move> _moves, _movesDaily;
  DateTime _date;
  Set<DateTime> _uniqueDates;

  Features(this._date, this._preprocessor) {

    _stops = _preprocessor.stops;
    _places = _preprocessor.places;
    _moves = _preprocessor.moves;
    _uniqueDates = _preprocessor.uniqueDates;
    _data = _preprocessor.data;

    // TODO: Load stops from disk
    this._dataDaily =
        _data.where((d) => d.datetime.midnight == _date).toList();
    this._stopsDaily =
        _stops.where((d) => d.arrival.midnight == _date).toList();
    this._placesDaily = _places
        .where((p) => p.durationForDate(_date).inMilliseconds > 0)
        .toList();
    this._movesDaily =
        _moves.where((d) => d.stopFrom.arrival.midnight == _date).toList();
  }

  /// FEATURES
  List<Stop> get stops => _stops;

  List<Place> get places => _places;

  List<Move> get moves => _moves;

  /// Number of clusters found by DBSCAN, i.e. number of places
  int get numberOfClusters => places.length;

  /// Number of clusters on the specified date
  int get numberOfClustersDaily => _placesDaily.length;

  /// Location variance
  double get locationVariance => calcLocationVariance(_data);

  /// Location variance today
  double get locationVarianceDaily => calcLocationVariance(_dataDaily);

  double get entropy => calcEntropy(places.map((p) => p.duration).toList());

  double get entropyDaily =>
      calcEntropy(_placesDaily.map((p) => p.durationForDate(_date)).toList());

  /// Normalized Entropy, i.e. entropy relative to the number of places
  double get normalizedEntropy => entropy / log(numberOfClusters);

  /// Normalized Entropy for the date specified in the constructor
  double get normalizedEntropyDaily =>
      entropyDaily / log(numberOfClustersDaily);

  /// Total distance travelled in meters
  double get totalDistance =>
      moves.map((m) => (m.distance)).fold(0.0, (a, b) => a + b);

  /// Total distance travelled in meters for the specified date
  double get totalDistanceDaily => _movesDaily
      .map((m) => (m.distance))
      .fold(0, (a, b) => a + b);

  /// Home Stay
  double get homeStay {
    int total =
        _places.map((p) => p.duration.inMilliseconds).fold(0, (a, b) => a + b);

    int home = _homePlace.duration.inMilliseconds;

    return calcHomeStay(total, home);
  }

  /// Home Stay Daily
  double get homeStayDaily {
    int total = _placesDaily
        .map((p) => p.durationForDate(_date).inMilliseconds)
        .fold(0, (a, b) => a + b);

    int home = _homePlace.durationForDate(_date).inMilliseconds;

    return calcHomeStay(total, home);
  }

  /// Routine index
  double get routineIndex {
    HourMatrix hourMatrixToday = HourMatrix(_stopsDaily, numberOfClusters);
    double totalError = 0.0;

    /// Extract past dates
    List<DateTime> datesHist = _uniqueDates.where((d) => d.isBefore(_date.midnight)).toList();

    /// TODO: Only calculate error between a start and end time
    for (DateTime d in datesHist) {
      List<Stop> histStops = stops.where((s) => s.arrival.midnight == d.midnight).toList();
      HourMatrix x = HourMatrix(histStops, numberOfClusters);
      totalError += hourMatrixToday.computeError(x);
    }
    // Average error
    totalError = totalError / datesHist.length;

    return 1 - totalError;

  }

  /// Auxiliary calculations for feature extraction
  /// Location variance calculation
  double calcLocationVariance(List<SingleLocationPoint> points) {
    /// Require at least 2 observations
    if (points.length < 2) {
      return 0.0;
    }
    double latStd = Stats.fromData(points.map((d) => (d.location.latitude)))
        .standardDeviation;
    double lonStd = Stats.fromData(points.map((d) => (d.location.longitude)))
        .standardDeviation;
    return log(latStd * latStd + lonStd * lonStd + 1);
  }

  /// Entropy calculates how dispersed time is between places
  double calcEntropy(List<Duration> durations) {
    Duration sum = durations.fold(Duration(), (a, b) => a + b);

    List<double> distribution = durations
        .map((d) =>
            (d.inMilliseconds.toDouble() / sum.inMilliseconds.toDouble()))
        .toList();
    return -distribution.map((p) => p * log(p)).reduce((a, b) => (a + b));
  }

  /// Find the place ID of the HOME place
  Place get _homePlace {
    List<int> candidates = [];

    // Find the most popular place between 00:00 and 06:00 for each day
    for (DateTime d in _uniqueDates) {
      List<Stop> stopsOnDate =
          stops.where((s) => s.arrival.midnight == d).toList();
      HourMatrix hours = HourMatrix(stopsOnDate, numberOfClusters);
      candidates.add(hours.homePlaceId);
    }

    /// Reduce to unique candidates
    List<int> unique = candidates.toSet().toList();

    /// Count the frequency of each candidate
    List<int> counts =
        unique.map((x) => candidates.where((y) => y == x).length).toList();

    /// Return the candidate with the highest frequency
    int homeId = unique[argmaxInt(counts)];
    return _places.where((p) => p.id == homeId).first;
  }

  /// Home Stay calculation
  double calcHomeStay(int timeSpentTotal, int timeSpentAtHome) {
    // Avoid div by zero error
    timeSpentTotal = timeSpentTotal > 0 ? timeSpentTotal : 1;

    return timeSpentAtHome.toDouble() / timeSpentTotal.toDouble();
  }

}
