part of mobility_features_lib;

/// Daily mobility context.
/// All Stops and Moves should be on the same date.
/// Places are all places for which the duration
/// on the given data is greater than 0
class MobilityContext {
  List<Stop> _stops;
  List<Place> _allPlaces, _places;

  List<Stop> get stops => _stops;
  List<Move> _moves;
  DateTime _timestamp, date;
  _HourMatrix _hourMatrix;

  /// Features
  int _numberOfPlaces;
  double _locationVariance,
      _entropy,
      _normalizedEntropy,
      _homeStay,
      _distanceTravelled,
      _routineIndex;
  List<MobilityContext> contexts;

  /// Private constructor, cannot be instantiated from outside
  MobilityContext._(this._stops, this._allPlaces, this._moves,
      {this.contexts, this.date}) {
    _timestamp = DateTime.now();
    date = date ?? _timestamp.midnight;
  }

//  /// Public constructor, can be instantiated from outside
//  MobilityContext(this._stops, this._allPlaces, this._moves,
//      {this.contexts, this.date}) {
//    _timestamp = DateTime.now();
//    date = date ?? _timestamp.midnight;
//  }

  get timestamp => _timestamp;

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
  _HourMatrix get hourMatrix {
    if (_hourMatrix == null) {
      _hourMatrix = _HourMatrix.fromStops(_stops, _allPlaces.length);
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
    _HourMatrix hm = _HourMatrix.fromStops(_stops, numberOfPlaces);
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
    double latStd = Stats.fromData(_stops.map((s) => (s.location.latitude)))
        .standardDeviation;
    double lonStd = Stats.fromData(_stops.map((s) => (s.location.longitude)))
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
    } else if (contexts.length <= 1) {
      return -1.0;
    }

    /// Compute the HourMatrix for each context that is older
    List<_HourMatrix> matrices = contexts
        .where((c) => c.date.isBefore(this.date))
        .map((c) => c.hourMatrix)
        .toList();

    /// Compute the 'average day' from the matrices
    _HourMatrix avgMatrix = _HourMatrix.average(matrices);

    /// Compute the overlap between the 'average day' and today
    return this.hourMatrix.computeOverlap(avgMatrix);
  }

  List<Place> get allPlaces => _allPlaces;

  List<Move> get moves => _moves;

  Map<String, dynamic> toJson() => {
        "date": date.toIso8601String(),
        "timestamp": timestamp.toIso8601String(),
        "num_of_places": numberOfPlaces,
        "entropy": entropy,
        "normalized_entropy": normalizedEntropy,
        "home_stay": homeStay,
        "distance_travelled": distanceTravelled,
        "routine_index": routineIndex,
      };
}

class ContextGenerator {
  static const String POINTS = 'points', STOPS = 'stops', MOVES = 'moves';

  static Future<File> _file(String type) async {
    bool isMobile = Platform.isAndroid || Platform.isIOS;

    /// If on a mobile device, use the path_provider plugin to access the
    /// file system
    String path;
    if (isMobile) {
      path = (await getApplicationDocumentsDirectory()).path;
    } else {
      path = 'test/data';
    }
    return new File('$path/$type.json');
  }

  static Future<Serializer<SingleLocationPoint>> get pointSerializer async =>
      Serializer<SingleLocationPoint>(await _file(POINTS));

  static Future<MobilityContext> generate(
      {bool usePriorContexts: false, DateTime today}) async {
    /// Init serializers
    Serializer<SingleLocationPoint> slpSerializer = await pointSerializer;
    Serializer<Stop> stopSerializer = Serializer<Stop>(await _file(STOPS));
    Serializer<Move> moveSerializer = Serializer<Move>(await _file(MOVES));

    /// Load data from disk
    List<SingleLocationPoint> pointsToday = await slpSerializer.load();
    List<Stop> stopsAll = await stopSerializer.load();
    List<Move> movesAll = await moveSerializer.load();

    // Define today as the midnight time
    today = today ?? DateTime.now();
    today = today.midnight;

    // Filter out old points
    pointsToday = _filterPoints(pointsToday, today);

    // Filter out todays stops, and stops older than 28 days
    stopsAll = _stopsHistoric(stopsAll, today);
    movesAll = _movesHistoric(movesAll, today);

    /// Recompute stops and moves today and add them
    List<Stop> stopsToday = _findStops(pointsToday, today);
    List<Move> movesToday = _findMoves(pointsToday, stopsToday);
    stopsAll.addAll(stopsToday);
    movesAll.addAll(movesToday);

    /// Save Stops and Moves to disk
    stopSerializer.flush();
    moveSerializer.flush();
    stopSerializer.save(stopsAll);
    moveSerializer.save(movesAll);

    /// Find places for the period
    List<Place> placesAll = _findPlaces(stopsAll);

    /// Find prior contexts, if prior is not chosen just leave empty
    List<MobilityContext> priorContexts = [];

    /// If Prior is chosen, compute mobility contexts for each previous date.
    if (usePriorContexts) {
      Set<DateTime> dates = stopsAll.map((s) => s.arrival.midnight).toSet();
      for (DateTime date in dates) {
        List<Stop> stopsOnDate = _stopsForDate(stopsAll, date);
        List<Move> movesOnDate = _movesForDate(movesAll, date);
        MobilityContext mc =
            MobilityContext._(stopsOnDate, placesAll, movesOnDate, date: date);
        priorContexts.add(mc);
      }
    }

    return MobilityContext._(stopsToday, placesAll, movesToday,
        contexts: priorContexts, date: today);
  }

  static List<SingleLocationPoint> _filterPoints(
      List<SingleLocationPoint> X, DateTime date) {
    return X.where((x) => x.datetime.midnight == date).toList();
  }

  static List<Stop> _stopsForDate(List<Stop> stops, DateTime date) {
    return stops.where((x) => x.arrival.midnight == date).toList();
  }

  static List<Move> _movesForDate(List<Move> moves, DateTime date) {
    return moves.where((x) => x.stopFrom.arrival.midnight == date).toList();
  }

  static List<Stop> _stopsHistoric(List<Stop> stops, DateTime date) {
    DateTime fourWeeksPrior = date.subtract(Duration(days: 28));
    return stops
        .where((x) =>
            x.arrival.midnight.isBefore(date) &&
            x.arrival.midnight.isAfter(fourWeeksPrior))
        .toList();
  }

  static List<Move> _movesHistoric(List<Move> moves, DateTime date) {
    DateTime fourWeeksPrior = date.subtract(Duration(days: 28));
    return moves
        .where((x) =>
            x.stopFrom.arrival.midnight.isBefore(date) &&
            x.stopFrom.arrival.midnight.isAfter(fourWeeksPrior))
        .toList();
  }
}
