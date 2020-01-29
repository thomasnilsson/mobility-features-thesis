part of mobility_features_lib;

final int HOURS_IN_A_DAY = 24;

class Features {
  List<LocationData> data;
  List<Stop> stops;
  List<Place> places;
  List<Move> moves;

  Features(this.data, this.stops, this.places, this.moves);

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
  List<List<double>> calculateTimeSpentAtPlaceAtHour(DateTime date) {
    /// All stops on the current date
    List<Stop> stopsOnDay = stops
        .where((s) => (sameDate(s.arrival, date) &&
            sameDate(s.departure, date)))
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
        range(0, HOURS_IN_A_DAY)
            .forEach((h) => (hourMatrix[h][pId] += sr.hourSlots[h]));
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
  /// TODO

  double calculateRoutineIndex(DateTime date) {
    /// All stops on the current date
    List<Stop> current =
        stops.where((s) => (sameDate(s.arrival, date))).toList();

    /// All stops before the current date
    List<Stop> history =
        stops.where((s) => (!sameDate(s.departure, date))).toList();

    /// If unable to calculate index, return 0
    if (current.isEmpty || history.isEmpty) return 0.0;
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

    if (!sameDate(s.departure, s.arrival)) {
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
