part of mobility_features_lib;

const int HOURS_IN_A_DAY = 24;

class Features {
  List<SingleLocationPoint> data, dataOnDate;
  List<Stop> stops, stopsOnDate;
  List<Place> places;
  List<int> placeIdsOnDate;
  List<Move> moves, movesOnDate;
  DateTime date;
  Set<DateTime> uniqueDates;

  Features(this.date, this.uniqueDates, this.data, this.stops, this.places,
      this.moves) {
    this.dataOnDate = data.where((d) => d.datetime.date == date).toList();
    this.stopsOnDate = stops.where((d) => d.arrival.date == date).toList();
    this.placeIdsOnDate = stopsOnDate.map((s) => s.placeId).toSet().toList();
    this.movesOnDate = moves.where((d) => d.stopFrom.arrival.date == date).toList();
  }

  /// Number of clusters found by DBSCAN, i.e. number of places
  int get numberOfClusters => places.length;

  /// Number of clusters on the specified date
  int get numberOfClustersDaily => placeIdsOnDate.length;

  /// Location variance
  double get locationVariance {
    double latStd = Stats.fromData(data.map((d) => (d.location.latitude)))
        .standardDeviation;
    double lonStd = Stats.fromData(data.map((d) => (d.location.longitude)))
        .standardDeviation;
    double locVar = log(latStd * latStd + lonStd * lonStd + 1);
    return data.length >= 2 ? locVar : 0.0;
  }

  /// Location variance
  double get locationVarianceDaily {

    print('Lats length ${dataOnDate.map((d) => (d.location.latitude)).length}');

    double latStd =
        Stats.fromData(dataOnDate.map((d) => (d.location.latitude)))
            .standardDeviation;
    double lonStd =
        Stats.fromData(dataOnDate.map((d) => (d.location.longitude)))
            .standardDeviation;
    double locVar = log(latStd * latStd + lonStd * lonStd + 1);
    return data.length >= 2 ? locVar : 0.0;
  }

  /// Entropy calculates how dispersed time is between places
  double get entropy {
    List<Duration> durations = places.map((p) => (p.duration)).toList();
    Duration sum = durations.fold(Duration(), (a, b) => (a + b));
    List<double> distribution = durations
        .map((d) =>
            (d.inMilliseconds.toDouble() / sum.inMilliseconds.toDouble()))
        .toList();
    return -distribution.map((p) => (p * log(p))).reduce((a, b) => (a + b));
  }

  /// Entropy for the specified date in the constructor
  double get entropyDaily {
    List<Duration> durations = places
        .map((p) => (p.durationForDate(date)))
        .where((dur) => dur.inMilliseconds > 0) // avoid log(0) error later
        .toList();

    Duration sum = durations.fold(Duration(), (a, b) => (a + b));
    List<double> distribution = durations
        .map((d) =>
            (d.inMilliseconds.toDouble() / sum.inMilliseconds.toDouble()))
        .toList();
    return -distribution.map((p) => (p * log(p))).fold(0.0, (a, b) => (a + b));
  }

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
      .where((m) => m.stopFrom.arrival.date == date)
      .map((m) => (m.distance))
      .fold(0, (a, b) => a + b);

  /// TIME SPENT AT PLACES EACH HOUR
  List<List<double>> calculateTimeSpentAtPlaceAtHour(DateTime chosenDate) {
    int m = HOURS_IN_A_DAY, n = numberOfClusters;

    List<Stop> stopsOnChosenDate =
        stops.where((d) => d.arrival.date == chosenDate).toList();

    /// Init 2d matrix with m rows and n cols
    List<List<double>> hourMatrix =
        new List.generate(m, (_) => new List<double>.filled(n, 0.0));

    for (int pId in range(0, n)) {
      List<Stop> stopsAtPlace =
          stopsOnChosenDate.where((s) => (s.placeId) == pId).toList();
      for (Stop s in stopsAtPlace) {
        StopHours sr = StopHours.fromStop(s);

        /// For each hour of the day, add the hours from the StopRow to the matrix
        for (int h in range(0, HOURS_IN_A_DAY)) {
          hourMatrix[h][pId] += sr.hourSlots[h];
        }
      }
    }

    /// Normalize rows, divide by sum
    for (int h in range(0, HOURS_IN_A_DAY)) {
      double sum = hourMatrix[h].reduce((a, b) => (a + b));

      /// Avoid division by 0 error
      sum = sum > 0.0 ? sum : 1.0;
      for (int pId in range(0, n)) {
        hourMatrix[h][pId] /= sum;
      }
    }

    return hourMatrix;
  }

  /// Home Stay
  double get homeStay {
    List<List<double>> hours = calculateTimeSpentAtPlaceAtHour(date);

    /// Find the home place id
    List<List<double>> nightHours = hours.sublist(0, 6);
    List<double> nightHoursAtPlaces =
        nightHours.map((h) => h.reduce((a, b) => a + b)).toList();
    int homeIndex = nightHoursAtPlaces.argmax;

    /// Calculate distribution for time spent at places
    double timeSpentTotal = places
        .map((p) => p.duration.inMilliseconds)
        .fold(0, (a, b) => a + b)
        .toDouble();
    double timeSpentAtHome = places
        .where((p) => p._id == homeIndex)
        .first
        .duration
        .inMilliseconds
        .toDouble();

    return timeSpentAtHome / timeSpentTotal;
  }

  /// Home Stay
  double get homeStayDaily {
    List<List<double>> hours = calculateTimeSpentAtPlaceAtHour(date);

    /// Find the home place id
    List<List<double>> nightHours = hours.sublist(0, 6);
    List<double> nightHoursAtPlaces =
        nightHours.map((h) => h.reduce((a, b) => a + b)).toList();
    int homeIndex = nightHoursAtPlaces.argmax;

    /// Calculate distribution for time spent at different places
    double timeSpentTotal = stopsOnDate
        .map((s) => s.duration.inMilliseconds)
        .fold(0, (a, b) => a + b)
        .toDouble();

    double timeSpentAtHome = stopsOnDate
        .where((s) => s.placeId == homeIndex)
        .map((s) => s.duration.inMilliseconds)
        .fold(0, (a, b) => a + b)
        .toDouble();

    // Avoid div by zero error
    timeSpentTotal = timeSpentTotal > 0 ? timeSpentTotal : 1;

    return timeSpentAtHome / timeSpentTotal;
  }

  /// Mean timetable difference between the data of the current date,
  /// and the data of the historic dates
  double get routineIndex {
    if (uniqueDates.length < 2) return -1.0;

    // Calculate the routine index differences between the current date and each
    // historical date
    List<double> diffs = uniqueDates
        .where((d) => d.leq(date))
        .map((d) => _routineIndexDifference(date, d))
        .toList();

    // Calculate the mean difference
    return diffs.fold(0.0, (a, b) => a + b) / (diffs.length.toDouble());
  }

  double _routineIndexDifference(DateTime d1, DateTime d2) {
    List<List<double>> hours1 = calculateTimeSpentAtPlaceAtHour(d1);
    List<List<double>> hours2 = calculateTimeSpentAtPlaceAtHour(d2);

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

    return 1.0 - timeslots.fold(0.0, (a, b) => a + b) / 24.0;
  }
}

class StopHours {
  int placeId;
  List<double> hourSlots;

  StopHours(this.placeId, this.hourSlots);

  factory StopHours.fromStop(Stop s) {
    /// Start and end should be on the same date!
    int start = s.arrival.hour;
    int end = s.departure.hour;

    if (s.departure.date != s.arrival.date) {
      throw Exception(
          'Arrival and Departure should be on the same date, but was not! $s');
    }

    List<double> hours = List<double>.filled(HOURS_IN_A_DAY, 0.0);

    /// Set the corresponding hour slots to 1
    for (int i = start; i <= end; i++) {
      hours[i] = 1.0;
    }

    return StopHours(s.placeId, hours);
  }
}
