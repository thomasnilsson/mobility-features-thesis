part of mobility_features_lib;

/// Daily mobility context.
/// All Stops and Moves should be on the same date.
/// Places are all places for which the duration
/// on the given data is greater than 0
class MobilityContext {
  List<Stop> _stops;
  List<Place> _allPlaces, _places;
  List<Move> _moves;
  DateTime _date;
  HourMatrix _hourMatrix;

  /// Features
  int _numberOfPlaces;
  double _locationVariance,
      _entropy,
      _normalizedEntropy,
      _homeStay,
      _distanceTravelled,
      _routineIndex;
  List<MobilityContext> contexts;

  /// The routine index is calculated from another class since it
  /// needs multiple MobilityContexts to be computed.
  /// This means the field is semi-public and will be set from this class.
  /// Constructor
  MobilityContext(this._date, this._stops, this._allPlaces, this._moves,
      {this.contexts});

  DateTime get date => _date.midnight;

  double get routineIndex {
    if (_routineIndex == null) {
      _routineIndex = _calculateRoutineIndex();
    }
    return _routineIndex;
  }

  /// Get places today
  List<Place> get places {
    if (_places == null) {
      _places = _allPlaces
          .where((p) => p.durationForDate(date).inMilliseconds > 0)
          .toList();
    }
    return _places;
  }

  /// Hour matrix for the day
  /// Uses the number of allPlaces since matrices have to match other days
  HourMatrix get hourMatrix {
    if (_hourMatrix == null) {
      _hourMatrix = HourMatrix.fromStops(_stops, _allPlaces.length);
    }
    return _hourMatrix;
  }

  /// Number of Places today
  int get numberOfPlaces {
    if (_numberOfPlaces == null) {
      _numberOfPlaces = _calculateNumberOfPlaces();
    }
    return _numberOfPlaces;
  }

  /// Home Stay Percentage today
  /// A scalar between 0 and 1, i.e. from 0% to 100%
  double get homeStay {
    if (_homeStay == null) {
      _homeStay = _calculateHomeStay();
    }
    return _homeStay;
  }

  /// Location Variance today
  double get locationVariance {
    if (_locationVariance == null) {
      _locationVariance = _calculateLocationVariance();
    }
    return _locationVariance;
  }

  /// Entropy
  /// High entropy: Time is spent evenly among all places
  /// Low  entropy: Time is mainly spent at a few of the places
  double get entropy {
    if (_entropy == null) {
      _entropy = _calculateEntropy();
    }
    return _entropy;
  }
  /// Normalized entropy,
  /// a scalar between 0 and 1
  double get normalizedEntropy {
    if (_normalizedEntropy == null) {
      _normalizedEntropy = _calculateNormalizedEntropy();
    }
    return _normalizedEntropy;
  }

  /// Distance travelled today, in meters
  double get distanceTravelled {
    if (_distanceTravelled == null) {
      _distanceTravelled = _calculateDistanceTravelled();
    }
    return _distanceTravelled;
  }

  /// Private number of places calculation
  int _calculateNumberOfPlaces() {
    return places.length;
  }

  /// Private home stay calculation
  double _calculateHomeStay() {
    // Latest known sample time
    DateTime latestTime = _stops.last.departure;

    // Total time elapsed from midnight until the last stop
    int totalTime = latestTime.millisecondsSinceEpoch -
        latestTime.midnight.millisecondsSinceEpoch;

    // Find todays home id, if no home exists today return -1.0
    HourMatrix hm = HourMatrix.fromStops(_stops, numberOfPlaces);
    if (hm.homePlaceId == -1) {
      return -1.0;
    }

    Place homePlace = places.where((p) => p.id == hm.homePlaceId).first;

    int homeTime = homePlace.durationForDate(date).inMilliseconds;

    return homeTime.toDouble() / totalTime.toDouble();
  }

  /// Private location variance calculation
  double _calculateLocationVariance() {
    /// Require at least 2 observations
    if (_stops.length < 2) {
      return 0.0;
    }
    double latStd = Stats.fromData(_stops.map((s) => (s.centroid.latitude)))
        .standardDeviation;
    double lonStd = Stats.fromData(_stops.map((s) => (s.centroid.longitude)))
        .standardDeviation;
    return log(latStd * latStd + lonStd * lonStd + 1);
  }

  double _calculateEntropy() {
    // If no places were visited return -1.0
    if (places.isEmpty) {
      return -1.0;
    }
    // The Entropy is zero when one outcome is certain to occur.
    else if (places.length < 2) {
      return 0.0;
    }
    // Calculate time spent at different places
    List<Duration> durations =
    places.map((p) => p.durationForDate(date)).toList();

    Duration totalTimeSpent = durations.fold(Duration(), (a, b) => a + b);

    List<double> distribution = durations
        .map((d) => (d.inMilliseconds.toDouble() /
        totalTimeSpent.inMilliseconds.toDouble()))
        .toList();

    return -distribution.map((p) => p * log(p)).reduce((a, b) => (a + b));
  }

  /// Private normalized entropy calculation
  double _calculateNormalizedEntropy() {
    if (numberOfPlaces < 2) {
      return 0.0;
    }
    return entropy / log(numberOfPlaces);
  }

  /// Private distance travelled calculation
  double _calculateDistanceTravelled() {
    return _moves.map((m) => (m.distance)).fold(0.0, (a, b) => a + b);
  }

  /// Routine index (overlap) calculation
  double _calculateRoutineIndex() {
    // We require at least 2 days to compute the routine index
    if (contexts == null) {
      return -1.0;
    } else if (contexts.isEmpty) {
      return -1.0;
    }

    /// Compute the HourMatrix for each context that is older
    List<HourMatrix> matrices = contexts
        .where((c) => c.date.isBefore(this.date))
        .map((c) => c.hourMatrix)
        .toList();

    if (matrices.isEmpty) {
      return -1.0;
    }
    /// Compute the 'average day' from the matrices
    HourMatrix avgMatrix = HourMatrix.average(matrices);

    /// Compute the overlap between the 'average day' and today
    return this.hourMatrix.computeOverlap(avgMatrix);
  }
}