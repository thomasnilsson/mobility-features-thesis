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
  double _locationVariance, _normalizedEntropy, _homeStay, _distanceTravelled;

  /// The routine index is calculated from another class since it
  /// needs multiple MobilityContexts to be computed.
  /// This means the field is semi-public and will be set from this class.
  double _routineIndex = -1.0;

  /// Constructor
  MobilityContext(this._date, this._stops, this._allPlaces, this._moves);

  DateTime get date => _date.midnight;

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

  /// Normalized entropy today
  /// A scalar between 0 and 1
  /// High entropy: Time is spent evenly among all places
  /// Low  entropy: Time is mainly spent at a few of the places
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

  /// Routine index, calculation takes place in the
  /// MobilityContextAggregated-class.
  double get routineIndex => _routineIndex;

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

  /// Private normalized entropy calculation
  double _calculateNormalizedEntropy() {
    // If no places were visited return -1.0
    if (places.isEmpty) {
      return -1.0;
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

  /// Private distance travelled calculation
  double _calculateDistanceTravelled() {
    return _moves.map((m) => (m.distance)).fold(0.0, (a, b) => a + b);
  }
}

class MobilityContextAggregated {
  List<MobilityContext> _contexts;
  List<DateTime> _dates;

  /// Features
  int _numberOfPlacesTotal;
  double _locationVarianceAverage,
      _normalizedEntropyAverage,
      _homeStayAverage,
      _distanceTravelledAverage,
      _routineIndexAverage;

  MobilityContextAggregated(this._contexts);

  /// Unique dates
  List<DateTime> get dates {
    if (_dates == null) {
      _dates = _contexts.map((c) => c.date).toSet().toList();
    }
    return _dates;
  }

  /// Number of places among all context
  int get numberOfPlacesTotal {
    if (_numberOfPlacesTotal == null) {
      _numberOfPlacesTotal = _contexts.first._allPlaces.length;
    }
    return _numberOfPlacesTotal;
  }

  /// Average home stay. Filter out days with an undefined home stay,
  /// which is the case the value is -1.0
  double get homeStayAverage {
    if (_homeStayAverage == null) {
      _homeStayAverage =
          _contexts.map((c) => c.homeStay).where((x) => x >= 0.0).mean;
    }
    return _homeStayAverage;
  }

  /// Average entropy. Filter out days with undefined location variance,
  /// which is the case the value is 0.0
  double get locationVarianceAverage {
    if (_locationVarianceAverage == null) {
      _locationVarianceAverage =
          _contexts.map((c) => c.locationVariance).where((x) => x > 0.0).mean;
    }
    return _locationVarianceAverage;
  }

  /// Average entropy. Filter out days with undefined entropy,
  /// which is the case the value is -1.0
  double get normalizedEntropyAverage {
    if (_normalizedEntropyAverage == null) {
      _normalizedEntropyAverage = _contexts
          .map((c) => c._calculateNormalizedEntropy())
          .where((x) => x >= 0.0)
          .mean;
    }
    return _normalizedEntropyAverage;
  }

  /// Average distance travelled for all the days.
  double get distanceTravelledAverage {
    if (_distanceTravelledAverage == null) {
      _distanceTravelledAverage =
          _contexts.map((c) => c.distanceTravelled).mean;
    }
    return _distanceTravelledAverage;
  }

  /// Routine Index Average
  double get routineIndexAverage {
    if (_routineIndexAverage == null) {
      _routineIndexAverage = _computeRoutineOverlapAverage();
    }
    return _routineIndexAverage;
  }

  /// Routine index (overlap) calculation
  double _computeRoutineOverlapForContext(MobilityContext c) {
    // We require at least 2 days to compute the routine index
    if (_contexts.length <= 1) {
      return -1.0;
    }

    /// Hour matrix for each context
    List<HourMatrix> matrices = _contexts.map((c) => c.hourMatrix).toList();
    HourMatrix avgMatrix = HourMatrix.average(matrices);

    /// Compute the overlap
    return c.hourMatrix.computeOverlap(avgMatrix);
  }

  /// Routine index (overlap) calculation
  double _computeRoutineOverlapAverage() {
    double overlap = 0.0;

    for (MobilityContext c in _contexts) {
      /// Set the routine index
      c._routineIndex = _computeRoutineOverlapForContext(c);
      overlap += c._routineIndex;
    }

    return overlap / _contexts.length;
//    double overlap = 0.0;
//
//    // We require at least 2 days to compute the routine index
//    if (_contexts.length <= 1) {
//      return -1.0;
//    }
//
//    /// Hour matrix for each context
//    List<HourMatrix> matrices = _contexts.map((c) => c.hourMatrix).toList();
//    HourMatrix avgMatrix = HourMatrix.average(matrices);
//
//    /// For each context, compute the overlap of
//    /// its hour matrix and the average matrix
//    for (MobilityContext c in _contexts) {
//      overlap += c.hourMatrix.computeOverlap(avgMatrix);
//    }
//
//    /// Compute the average overlap
//    return overlap / _contexts.length;
  }
}
