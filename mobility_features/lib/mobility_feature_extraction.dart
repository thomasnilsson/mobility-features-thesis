part of mobility_features_lib;

const int HOURS_IN_A_DAY = 24;

class Features {
  List<SingleLocationPoint> data;
  List<Stop> stops;
  List<Place> places;
  List<Move> moves;
  DateTime date;

  Features(this.date, this.data, this.stops, this.places, this.moves);

  /// Number of clusters found by DBSCAN, i.e. number of places
  int get numberOfClusters => places.length;

  /// Location variance
  double get locationVariance {
    double latStd = Stats.fromData(data.map((d) => (d.location.latitude)))
        .standardDeviation;
    double lonStd = Stats.fromData(data.map((d) => (d.location.longitude)))
        .standardDeviation;
    double locVar = log(latStd * latStd + lonStd * lonStd + 1);
    return data.length >= 2 ? locVar : 0.0;
  }

  /// Entropy calculates how dispersed time is between places
  double get entropy {
    List<Duration> durations = places.map((p) => (p.duration)).toList();
    Duration sum = durations.reduce((a, b) => (a + b));
    List<double> distribution = durations
        .map((d) =>
            (d.inMilliseconds.toDouble() / sum.inMilliseconds.toDouble()))
        .toList();
    return -distribution.map((p) => (p * log(p))).reduce((a, b) => (a + b));
  }

  /// Normalized Entropy, i.e. entropy relative to the number of places
  double get normalizedEntropy => entropy / log(numberOfClusters);

  /// Total distance travelled in meters
  double get totalDistance =>
      moves.map((m) => (m.distance)).reduce((a, b) => a + b);

  /// TIME SPENT AT PLACES EACH HOUR
  List<List<double>> calculateTimeSpentAtPlaceAtHour(DateTime chosenDateTime) {
    /// All stops on the current date
    List<Stop> stopsOnDay = stops
        .where((s) => (s.arrival.date == chosenDateTime.date &&
            s.departure.date == chosenDateTime.date))
        .toList();

    Set<int> placeLabels = stopsOnDay.map((s) => (s.placeId)).toSet();
    int m = 24, n = placeLabels.length;

    /// Init 2d matrix with m rows and n cols
    List<List<double>> hourMatrix =
        new List.generate(m, (_) => new List<double>.filled(n, 0.0));

    for (int pId in placeLabels) {
      List<Stop> stopsAtPlace =
          stopsOnDay.where((s) => (s.placeId) == pId).toList();
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
      for (int pId in placeLabels) {
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
        .reduce((a, b) => a + b)
        .toDouble();
    double timeSpentAtHome = places
        .where((p) => p.id == homeIndex)
        .first
        .duration
        .inMilliseconds
        .toDouble();

    return timeSpentAtHome / timeSpentTotal;
  }

  double calculateRoutineIndex(DateTime chosenDateTime) {
    /// All stops on the current date
    List<Stop> current =
        stops.where((s) => (s.arrival.date == chosenDateTime.date)).toList();

    /// All stops before the current date
    List<Stop> history =
        stops.where((s) => (s.departure.date != chosenDateTime.date)).toList();

    /// If unable to calculate index, return 0
    if (current.isEmpty || history.isEmpty) return 0.0;
  }

  double routineIndexDifference(DateTime d1, DateTime d2) {
    List<List<double>> hours1 = calculateTimeSpentAtPlaceAtHour(d1);
    List<List<double>> hours2 = calculateTimeSpentAtPlaceAtHour(d2);

    int numPlaces = min(hours1.first.length, hours2.first.length);

    /// calculate overlap
    List<double> timeslots = List<double>.filled(HOURS_IN_A_DAY, 0.0);

    for (int i in range(0, HOURS_IN_A_DAY)) {
      double r = 1.0;
      for (int j in range(0, numPlaces)) {
        /// Check that the two hours are the same
        r = hours1[i][j] == hours2[i][j] ? r : 0.0;
      }
      timeslots[i] = r;
    }
    return 1.0 - timeslots.reduce((a, b) => a + b) / 24.0;
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
