import 'mobility_features_test_lib.dart';
import 'package:mobility_features/mobility_features_lib.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Datetime extension', () async {
    DateTime d1 = DateTime.parse('2019-11-11 09:30:00.000');
    DateTime d2 = DateTime.parse('2019-11-11 13:31:00.400');
    print(d1.date);
    print(d2.date);
    print(d1.date == d2.date);
    print(d1.sameDate(d2));
  });

  test('Print data', () async {
    List<LocationData> data = await Dataset().multiDateData;
    printList(data.sublist(0, 10));
  });

  test('Get unique dates', () async {
    List<LocationData> data = await Dataset().multiDateData;
    final p = Preprocessor(data, minMoveDuration: Duration(minutes: 3));
    print(p.uniqueDates);
  });

  test('run db scan', () async {
    List<LocationData> data = await Dataset().multiDateData;
    final p = Preprocessor(data, minMoveDuration: Duration(minutes: 3));

    /// Find stops, stops will have an empty [place] field
    List<Stop> stops = p.findStops(data);

    /// Find places, now stops should have their [place] field set
    List<Place> places = p.findPlaces(stops);

    /// Find moves
    List<Move> moves = p.findMoves(data, stops);

    printList(stops);
    printList(places);
    printList(moves);

    Features f = Features(data, stops, places, moves);

    print('Number of Clusters: ${f.numberOfClusters}');
    print('Location Variance: ${f.locationVariance}');
    print('Entropy: ${f.entropy}');
    print('Normalized Entropy: ${f.normalizedEntropy}');
    print('Total Distance (meters): ${f.totalDistance}');

    var m = f.calculateTimeSpentAtPlaceAtHour(DateTime.parse('2019-11-11'));
    printMatrix(m);
  });

  test('Create stop row', () {
    List<double> target = List<double>.filled(HOURS_IN_A_DAY, 0.0);
    for (int i = 1; i <= 9; i++) target[i] = 1.0;

    DateTime arrival = DateTime.parse('2019-11-11 01:00:00.000');
    DateTime departure = DateTime.parse('2019-11-11 09:30:00.000');
    Location loc = Location(55.6863790613, 12.5571557078);
    int nSamples = 1000;
    Stop s = Stop(loc, arrival, departure, nSamples);
    print(s);

    StopHours sr = StopHours.fromStop(s);
    print(sr.hourSlots);
    assert(vectorsEqual(sr.hourSlots, target));
  });
}
