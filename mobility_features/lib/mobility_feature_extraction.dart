part of mobility_features_lib;

const int HOURS_IN_A_DAY = 24;

class Features {
  List<SingleLocationPoint> _data, _dataOnDate;
  List<Stop> _stops, _stopsDaily;
  List<Place> _places, _placesDaily;
  List<Move> _moves, _movesDaily;
  DateTime _date;
  Set<DateTime> _uniqueDates;

  Features(this._date, this._uniqueDates, this._data, this._stops, this._places,
      this._moves) {
    this._dataOnDate = _data.where((d) => d.datetime.date == _date).toList();
    this._stopsDaily = _stops.where((d) => d.arrival.date == _date).toList();
    this._placesDaily = _places
        .where((p) => p.durationForDate(_date).inMilliseconds > 0)
        .toList();
    this._movesDaily =
        _moves.where((d) => d.stopFrom.arrival.date == _date).toList();
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
  double get locationVarianceDaily => calcLocationVariance(_dataOnDate);

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
  double get totalDistanceDaily => moves
      .where((m) => m.stopFrom.arrival.date == _date)
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
    // Load stops from disk
    // Filter out historical stops
    //
    return 1.0;
  }

  /// CALCULATIONS
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

  /// TIME SPENT AT PLACES EACH HOUR
  List<List<double>> hourMatrix(DateTime chosenDate) {
    int m = HOURS_IN_A_DAY, n = numberOfClusters;

    List<Stop> stopsOnChosenDate =
        stops.where((d) => d.arrival.date == chosenDate).toList();

    /// Init 2d matrix with m rows and n cols
    List<List<double>> hours2d =
        new List.generate(m, (_) => new List<double>.filled(n, 0.0));

    for (int pId in range(0, n)) {
      List<Stop> stopsAtPlace =
          stopsOnChosenDate.where((s) => (s.placeId) == pId).toList();
      for (Stop s in stopsAtPlace) {
        StopHours sr = StopHours.fromStop(s);

        /// For each hour of the day, add the hours from the StopRow to the matrix
        for (int h in range(0, HOURS_IN_A_DAY)) {
          hours2d[h][pId] += sr.hourSlots[h];
        }
      }
    }

    /// Normalize rows, divide by sum
    for (int h in range(0, HOURS_IN_A_DAY)) {
      double sum = hours2d[h].fold(0, (a, b) => (a + b));

      /// Avoid division by 0 error
      sum = sum > 0.0 ? sum : 1.0;
      for (int pId in range(0, n)) {
        hours2d[h][pId] /= sum;
      }
    }
    return hours2d;
  }

  /// Find the place ID of the HOME place
  Place get _homePlace {
    List<int> candidates = [];

    // Find the most popular place between 00:00 and 06:00 for each day
    for (DateTime d in _uniqueDates) {
      List<Stop> stopsOnDate = stops.where((s) => s.arrival.date == d).toList();
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

  List<Stop> _loadHistoricalStops() {}

  /// Mean timetable difference between the data of the current date,
  /// and the data of the historic dates
  double get routineIndexOld {
    if (_uniqueDates.length < 2) return -1.0;

    // Calculate the routine index differences between the current date and each
    // historical date
    List<double> diffs = _uniqueDates
        .where((d) => d.leq(_date))
        .map((d) => _routineIndexDifference(_date, d))
        .toList();

    // Calculate the mean difference
    return diffs.fold(0.0, (a, b) => a + b) / (diffs.length.toDouble());
  }

  double _routineIndexDifference(DateTime d1, DateTime d2) {
    List<List<double>> hours1 = hourMatrix(d1);
    List<List<double>> hours2 = hourMatrix(d2);

    int numPlaces = min(hours1.first.length, hours2.first.length);

    /// Calculate overlap
    List<double> timeslots = List<double>.filled(HOURS_IN_A_DAY, 0.0);

    for (int i in range(0, HOURS_IN_A_DAY)) {
      double r = 1.0;
      for (int j in range(0, numPlaces)) {
        /// Check that the two hours are the same
        r = hours1[i][j] == hours2[i][j] ? r : 0.0;
      }
      timeslots[i] = r;
    }
    /// TODO: Calculate properly, i.e. compare all m*n elements and divide by m*n
    return 1.0 - timeslots.fold(0.0, (a, b) => a + b) / 24.0;
  }
}
