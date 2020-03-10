import 'mobility_features_test_lib.dart';
import 'package:mobility_features/mobility_features_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

void main() async {
  print('Loading data (before tests)... ');
  List<SingleLocationPoint> data = await Dataset().exampleData;
  printList(data.sublist(0, 10));

  test('Datetime extension', () async {
    DateTime d1 = DateTime.parse('2020-02-12 09:30:00.000');
    DateTime d2 = DateTime.parse('2020-02-12 13:31:00.400');
    assert(d1.zeroTime == d2.zeroTime);
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
    printList(p.dataGroupedByDates.map((arr) => arr.length).toList());
  });

  test('Run feature extraction', () async {
    /// TODO: MOCK DATE
    DateTime date = DateTime(2020, 02, 17);
    Preprocessor p = Preprocessor(data, moveDuration: Duration(minutes: 3));

    Features f = p.getFeatures(date: date);

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
    print('-' * 50);


    print('Daily Number of Clusters: ${f.numberOfClustersDaily}');
    print('Daily Location Variance: ${f.locationVarianceDaily}');
    print('Daily Entropy: ${f.entropyDaily}');
    print('Daily Normalized Entropy: ${f.normalizedEntropyDaily}');
    print('Daily Total Distance (meters): ${f.totalDistanceDaily}');
    print('Daily Homestay (%): ${f.homeStayDaily}');

    print('Routine index (%): ${f.routineIndex}');
  });

  test('Serialization', () async {
    /// Create a [SingleLocationPoint] manually
    SingleLocationPoint p =
    SingleLocationPoint(Location(12.345, 98.765), DateTime.now());

    /// Serialize it
    var toJson = p.toJson();
    print(toJson);

    /// Deserialize it
    SingleLocationPoint fromJson = SingleLocationPoint.fromJson(toJson);
    print(fromJson);

    /// Create a [Stop] manually
    Stop s = Stop([p, p, p], placeId: 2);

    /// Serialize it
    var jsonStop = s.toJson();

    /// Deserialize it
    Stop stopFromJson = Stop.fromJson(jsonStop);

    /// Make a [List] of stops
    List jsonStops = [stopFromJson, stopFromJson, stopFromJson]
        .map((s) => s.toJson())
        .toList();

    /// Serialize it
    String jsonStringStops = json.encode(jsonStops);

    /// Deserialize it
    List decoded = json.decode(jsonStringStops);
    List<Stop> stopsDecoded = decoded.map((d) => Stop.fromJson(d)).toList();
    printList(decoded);
    printList(stopsDecoded);
  });

  test('Incremental RI', () async {
    DateTime date = DateTime(2020, 02, 17);
    Preprocessor p = Preprocessor(data, moveDuration: Duration(minutes: 3));
    Features f = p.getFeatures(date: date);
    var stops = f.stops;
  });
}
