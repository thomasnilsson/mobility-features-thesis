import 'mobility_features_test_lib.dart';
import 'package:mobility_features/mobility_features_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

void main() async {

  test('Datetime extension', () async {
    DateTime d1 = DateTime.parse('2020-02-12 09:30:00.000');
    DateTime d2 = DateTime.parse('2020-02-12 13:31:00.400');
    assert(d1.zeroTime == d2.zeroTime);
  });

  test('Get unique dates', () async {
    List<SingleLocationPoint> data = await Dataset().exampleData;
    final p = Preprocessor(data, moveDuration: Duration(minutes: 3));
    print('Unique Dates:');
    print('*' * 50);
    printList(p.uniqueDates.toList());
  });

  test('Run feature extraction', () async {
    List<SingleLocationPoint> data = await Dataset().exampleData;
    /// TODO: MOCK DATE
    DateTime date = DateTime(2020, 02, 17);
    Preprocessor p = Preprocessor(data, moveDuration: Duration(minutes: 3));

    Features f = Features(date, p);

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

  test('Serialization of stops and moves', () async {
    /// Create a [SingleLocationPoint] manually
    SingleLocationPoint p1 =
        SingleLocationPoint(Location(12.345, 98.765), DateTime(2020, 02, 16));

    /// Serialize it
    var toJson = p1.toJson();
    print(toJson);

    /// Deserialize it
    SingleLocationPoint fromJson = SingleLocationPoint.fromJson(toJson);
    print(fromJson);

    /// Create a [Stop] manually
    Stop s1 = Stop.fromPoints([p1, p1, p1], placeId: 2);
    print(s1);

    /// Serialize it
    var jsonStop = s1.toJson();

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

    /// Move serialization
    SingleLocationPoint p2 =
    SingleLocationPoint(Location(13.345, 95.765), DateTime(2020, 02, 17));
    Stop s2 = Stop.fromPoints([p2, p2, p2], placeId: 1);

    Move m = Move.fromPoints(s1, s2, [p1, p2]);
    print(m);

    var jsonMove = m.toJson();
    print(jsonMove);

    Move moveFromJson = Move.fromJson(jsonMove);

    print(moveFromJson);

    /// Make a [List] of stops
    List jsonMoves = [moveFromJson, moveFromJson, moveFromJson]
        .map((m) => m.toJson())
        .toList();

    /// Serialize it
    String jsonStringMoves = json.encode(jsonMoves);

    /// Deserialize it
    List decodedMovesMaps = json.decode(jsonStringMoves);
    printList(decodedMovesMaps);

    List<Move> decodedMoves = decodedMovesMaps.map((d) => Move.fromJson(d)).toList();
    printList(decodedMoves);

  });

  test('Incremental RI', () async {
    List<SingleLocationPoint> data = await Dataset().exampleData;
    List<DateTime> dates = [
      DateTime(2020, 02, 12),
      DateTime(2020, 02, 13),
      DateTime(2020, 02, 14),
      DateTime(2020, 02, 15),
      DateTime(2020, 02, 16),
      DateTime(2020, 02, 17),
    ];


    /// This is the equivalent of the stored stops and moves
    List<Stop> stops = [];
    List<Move> moves = [];

    for (DateTime _date in dates) {
      List<SingleLocationPoint> d =
          data.where((d) => (d.datetime.zeroTime == _date)).toList();
      Preprocessor p = Preprocessor(d, moveDuration: Duration(minutes: 3));
      Features f = Features(_date, p);
      stops.addAll(f.stops);

    }
  });
}
