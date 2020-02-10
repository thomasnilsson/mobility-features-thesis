import 'mobility_features_test_lib.dart';
import 'package:mobility_features/mobility_features_lib.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  List<LocationData> data = await Dataset().multiDateData;
  printList(data.sublist(0, 10));

  test('Datetime extension', () async {
    DateTime d1 = DateTime.parse('2019-11-11 09:30:00.000');
    DateTime d2 = DateTime.parse('2019-11-11 13:31:00.400');
    assert(d1.date == d2.date);
  });

  test('Get unique dates', () async {
    final p = Preprocessor(data, moveDuration: Duration(minutes: 3));
    print('Unique Dates:');
    print('*' * 50);
    printList(p.uniqueDates.toList());
  });

  test('Group data by date', () async {
    final p = Preprocessor(data, moveDuration: Duration(minutes: 3));
    print('Data Grouped by dates:');
    print('*' * 50);
    printList(p.dataGroupedByDates);
  });

//  test('Create stop row', () {
//    List<double> target = List<double>.filled(HOURS_IN_A_DAY, 0.0);
//    for (int i = 1; i <= 9; i++) target[i] = 1.0;
//
//    DateTime arrival = DateTime.parse('2019-11-11 01:00:00.000');
//    DateTime departure = DateTime.parse('2019-11-11 09:30:00.000');
//    Location loc = Location(55.6863790613, 12.5571557078);
//    int nSamples = 1000;
//
//    print('Stop and stop row:');
//    print('*' * 50);
//    Stop s = Stop(loc, arrival, departure, nSamples);
//    print(s);
//
//    StopHours sr = StopHours.fromStop(s);
//    print(sr.hourSlots);
//    assert(vectorsEqual(sr.hourSlots, target));
//  });

  test('Run feature extraction', () async {
    DateTime date = DateTime(2019, 11, 11);
    Preprocessor p = Preprocessor(data, moveDuration: Duration(minutes: 3));
    Features f = p.featuresByDate(date);

    print('Stops found:');
    print('*' * 50);
    printList(f.stops);

    print('Places found:');
    print('*' * 50);
    printList(f.places);

    print('Moves found:');
    print('*' * 50);
    printList(f.moves);

    print('Features:');
    print('*' * 50);

    print('Number of Clusters: ${f.numberOfClusters}');
    print('Location Variance: ${f.locationVariance}');
    print('Entropy: ${f.entropy}');
    print('Normalized Entropy: ${f.normalizedEntropy}');
    print('Total Distance (meters): ${f.totalDistance}');
    print('Homestay (%): ${f.homeStay}');
    print('Routine index (%): ${f.routineIndexDifference(DateTime(2019, 11, 11), DateTime(2019, 11, 12))}');

    print('2019-11-11');
    var m = f.calculateTimeSpentAtPlaceAtHour(DateTime.parse('2019-11-11'));
    printMatrix(m);

    print('2019-11-12');
    var m2 = f.calculateTimeSpentAtPlaceAtHour(DateTime.parse('2019-11-12'));
    printMatrix(m2);

  });
}
