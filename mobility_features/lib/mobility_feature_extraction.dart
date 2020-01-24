part of mobility_features_lib;

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
  double get totalDistance => moves.map((m) => (m.distance)).reduce((a,b) => a+b);

  /// Home Stay
  /// TODO
}
