import 'mobility_features_test_lib.dart';
import 'package:mobility_features/mobility_features_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:io';

void main() async {
  String datasetPath = 'lib/data/example-multi.json';
  String testDataDir = 'test/data';

  List<DateTime> dates = [
    DateTime(2020, 02, 12),
    DateTime(2020, 02, 13),
    DateTime(2020, 02, 14),
    DateTime(2020, 02, 15),
    DateTime(2020, 02, 16),
    DateTime(2020, 02, 17),
  ];

  test('Datetime extension', () async {
    DateTime d1 = DateTime.parse('2020-02-12 09:30:00.000');
    DateTime d2 = DateTime.parse('2020-02-12 13:31:00.400');
    assert(d1.midnight == d2.midnight);
  });

  test('Run feature extraction', () async {
    List<SingleLocationPoint> data = await Dataset().loadDataset(datasetPath);
    List<Stop> stops = [];
    List<Move> moves = [];
    DataPreprocessor dp;

    for (DateTime date in dates) {
      dp = DataPreprocessor(date);
      List<Stop> stopsOnDate = dp.findStops(data);
      stops.addAll(stopsOnDate);
      moves.addAll(dp.findMoves(data, stopsOnDate));
    }

    List<Place> places = dp.findPlaces(stops);

    FeaturesAggregate f = FeaturesAggregate(dates.last, stops, places, moves);

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
    print('Entropy: ${f.entropy}');
    print('Normalized Entropy: ${f.normalizedEntropy}');
    print('Total Distance (meters): ${f.totalDistance}');
    print('Homestay (%): ${f.homeStay}');
    print('-' * 50);

    print('Daily Number of Clusters: ${f.numberOfClustersDaily}');
    print('Daily Entropy: ${f.entropyDaily}');
    print('Daily Normalized Entropy: ${f.normalizedEntropyDaily}');
    print('Daily Total Distance (meters): ${f.totalDistanceDaily}');
    print('Daily Homestay (%): ${f.homeStayDaily}');
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

    List<Move> decodedMoves =
        decodedMovesMaps.map((d) => Move.fromJson(d)).toList();
    printList(decodedMoves);
  });

  test('Incremental RI', () async {
    List<SingleLocationPoint> data = await Dataset().loadDataset(datasetPath);

    /// This is the equivalent of the stored stops and moves
    List<Stop> stops = [];
    List<Move> moves = [];

    for (DateTime date in dates) {
      DataPreprocessor dp = DataPreprocessor(date);

      List<SingleLocationPoint> dataOnDate =
          data.where((x) => (x.datetime.midnight == date)).toList();

      List<Stop> stopsOnDate = dp.findStops(dataOnDate);
      stops.addAll(stopsOnDate);

      List<Place> places = dp.findPlaces(stops);

      List<Move> movesOnDate = dp.findMoves(dataOnDate, stopsOnDate);
      moves.addAll(movesOnDate);

      FeaturesAggregate features =
          FeaturesAggregate(date, stops, places, moves);
      print('$date | RoutineIndex: ${features.routineIndexDaily}');
    }
  });

  test('write to file', () async {
    File f = new File('test/test_file.txt');
    await f.writeAsString('test 123 123 123');

    String res = await f.readAsString();

    print(res);
  });

  test('Serialization to file', () async {
    /// Single data points
    List<SingleLocationPoint> data = await Dataset().loadDataset(datasetPath);

    Serializer<SingleLocationPoint> dataSerializer =
        Serializer(new File('$testDataDir/points.json'));
    List<SingleLocationPoint> subset = data.sublist(0, 5);
    printList(subset);

    /// Serialize the subset of 5 points
    dataSerializer.save(subset);

    /// De-serialize the subset from file
    List<SingleLocationPoint> dataFromFile = await dataSerializer.load();
    printList(dataFromFile);

    List<Stop> stops = [
      Stop.fromPoints(data.sublist(0, 10), placeId: 1),
      Stop.fromPoints(data.sublist(10, 20), placeId: 2),
      Stop.fromPoints(data.sublist(20, 30), placeId: 3),
      Stop.fromPoints(data.sublist(30, 40), placeId: 4)
    ];

    printList(stops);

    /// Serialize stops
    Serializer<Stop> stopSerializer =
        Serializer(new File('$testDataDir/stops.json'));
    stopSerializer.save(stops);

    /// De-serialize stops
    List<Stop> stopsFromFile = await stopSerializer.load();
    print('Stops deserialized:');
    printList(stopsFromFile);

    List<Move> moves = [
      Move.fromPoints(stops[0], stops[1], data.sublist(0, 20)),
      Move.fromPoints(stops[1], stops[2], data.sublist(10, 30)),
      Move.fromPoints(stops[2], stops[3], data.sublist(20, 40))
    ];

    printList(moves);

    /// Serialize moves
    Serializer<Move> moveSerializer =
        Serializer(new File('$testDataDir/moves.json'));
    moveSerializer.save(moves);

    /// Deserialize moves
    List<Move> movesFromFile = await moveSerializer.load();
    print('Moves deserialized:');
    printList(movesFromFile);
  });

  test('Serialize all Data points', () async {
    /// Single data points
    List<SingleLocationPoint> data = await Dataset().loadDataset(datasetPath);

    Serializer dataSerializer =
        Serializer(new File('$testDataDir/all_points.json'));

    /// Serialize the dataset
    dataSerializer.save(data);
  });

  test('De-serialize all Data points', () async {
    /// Single data points
    List<SingleLocationPoint> data = await Dataset().loadDataset(datasetPath);

    Serializer<SingleLocationPoint> dataSerializer =
        Serializer(new File('$testDataDir/all_points.json'));

    /// Serialize the dataset
    List<SingleLocationPoint> dataFromFile = await dataSerializer.load();
    assert(dataFromFile.length == data.length);
  });

  test('Serialize Stops and Moves', () async {
    Serializer<Stop> stopSerializer =
        Serializer(new File('$testDataDir/all_stops.json'));
    Serializer<Move> moveSerializer =
        Serializer(new File('$testDataDir/all_moves.json'));

    stopSerializer.flush();
    moveSerializer.flush();

    /// Single data points
    List<SingleLocationPoint> data = await Dataset().loadDataset(datasetPath);

    for (DateTime date in dates) {
      List<SingleLocationPoint> dataOnDate =
          data.where((x) => x.datetime.midnight == date).toList();
      DataPreprocessor preprocessor = DataPreprocessor(date);
      List<Stop> newStops = preprocessor.findStops(dataOnDate);
      List<Move> newMoves = preprocessor.findMoves(dataOnDate, newStops);

      /// Save to file  by reading the content, appending it, and then writing
      List<Stop> stops = await stopSerializer.load();
      List<Move> moves = await moveSerializer.load();
      stops.addAll(newStops);
      moves.addAll(newMoves);

      List<Place> places = preprocessor.findPlaces(stops);

      ///  Do something with places

      /// Write new stops and moves
      stopSerializer.save(newStops);
      moveSerializer.save(newMoves);
    }

    List<Stop> stops = await stopSerializer.load();
    List<Move> moves = await moveSerializer.load();
    print("Number of stops: ${stops.length}");
    print("Number of moves: ${moves.length}");
  });

  test('Load stops and moves', () async {
    Serializer<Stop> stopSerializer =
        Serializer(new File('$testDataDir/all_stops.json'));
    Serializer<Move> moveSerializer =
        Serializer(new File('$testDataDir/all_moves.json'));

    List<Stop> stops = await stopSerializer.load();
    List<Move> moves = await moveSerializer.load();

    print("Number of stops: ${stops.length}");
    print("Number of moves: ${moves.length}");
  });

  test('Serialize empty Stops and Moves', () async {
    Serializer<SingleLocationPoint> dataSerializer =
        Serializer(new File('$testDataDir/empty_data.json'));
    Serializer<Stop> stopSerializer =
        Serializer(new File('$testDataDir/empty_stops.json'));
    Serializer<Move> moveSerializer =
        Serializer(new File('$testDataDir/empty_moves.json'));

    List<SingleLocationPoint> points = await dataSerializer.load();
    List<Stop> stops = await stopSerializer.load();
    List<Move> moves = await moveSerializer.load();

    print('Loaded ${points.length} points');
    print('Loaded ${stops.length} stops');
    print('Loaded ${moves.length} moves');
    print("Ran test without errors!");
  });

  test('Simulate everything', () async {
    Serializer<SingleLocationPoint> dataSerializer =
        Serializer(new File('$testDataDir/all_points.json'));
    Serializer<Stop> stopSerializer =
        Serializer(new File('$testDataDir/all_stops.json'));
    Serializer<Move> moveSerializer =
        Serializer(new File('$testDataDir/all_moves.json'));

    /// Reset file content
    dataSerializer.flush();
    stopSerializer.flush();
    moveSerializer.flush();

    /// Init data
    List<SingleLocationPoint> data = await Dataset().loadDataset(datasetPath);
    List<SingleLocationPoint> buffer = [];
    int bufferSize = 100;

    /// Simulate going through the dates
    for (DateTime today in dates) {
      List dataOnDate =
          data.where((d) => d.datetime.midnight == today.midnight).toList();

      /// Simulate data points coming in one at a time
      for (SingleLocationPoint x in dataOnDate) {
        buffer.add(x);

        /// Fill up buffer. When full: write data to file.
        if (buffer.length >= bufferSize) {
          await dataSerializer.save(buffer);
          buffer = [];
        }
      }

      /// Time passes, and we now need the data
      /// Remember to add the remaining buffer to the loaded data as well.
      List<SingleLocationPoint> loadedData = await dataSerializer.load();
      List<SingleLocationPoint> pointsAll = loadedData + buffer;

      /// Pre-process today's data
      DataPreprocessor preprocessor = DataPreprocessor(today);
      List<Stop> stopsToday = preprocessor.findStops(pointsAll);
      List<Move> movesToday = preprocessor.findMoves(pointsAll, stopsToday);

      /// Load old stops and moves
      List<Stop> stopsLoaded = await stopSerializer.load();
      List<Move> movesLoaded = await moveSerializer.load();

      DateTime fourWeeksAgo = today.subtract(Duration(days: 28));

      /// Filter out stops and moves which were computed today,
      /// which were just loaded as well as stops older than 28 days
      List<Stop> stopsOld = stopsLoaded
          .where((s) => s.arrival.midnight != today.midnight&&
          fourWeeksAgo.leq(s.arrival.midnight))
          .toList();

      List<Move> movesOld = movesLoaded
          .where((m) =>
              m.stopFrom.arrival.midnight != today.midnight &&
              fourWeeksAgo.leq(m.stopFrom.arrival.midnight))
          .toList();

      /// Concatenate old and and new
      List<Stop> stopsAll = stopsOld + stopsToday;
      List<Move> movesAll = movesOld + movesToday;

      /// Find all places, both historic and today
      List<Place> placesAll = preprocessor.findPlaces(stopsAll);

      /// Save today's stops and moves.
      /// Naive approach, is to just append - but this
      /// assumes this processing is done 23:59:59
      /// and that it hasn't been done previously on this day.
      /// By flushing the file and writing ALL stops and moves,
      /// the issue is avoided, albeit by using more compute power.
      stopSerializer.flush();
      moveSerializer.flush();
      stopSerializer.save(stopsAll);
      moveSerializer.save(movesAll);

      /// Calculate features
      FeaturesAggregate features =
          FeaturesAggregate(today, stopsAll, placesAll, movesAll);
      features.printOverview();
    }
  });

  test('Test single after the fact', () async {
    Serializer<Stop> stopSerializer =
    Serializer(new File('$testDataDir/all_stops.json'));
    Serializer<Move> moveSerializer =
    Serializer(new File('$testDataDir/all_moves.json'));

    List<Stop> stops = await stopSerializer.load();
    List<Move> moves = await moveSerializer.load();

    print('No. stops: ${stops.length}');
    print('No. moves: ${moves.length}');

    DateTime today = DateTime(2020, 02, 17);

    DataPreprocessor preprocessor = DataPreprocessor(today);
    List<Place> places = preprocessor.findPlaces(stops);

    FeaturesAggregate features = FeaturesAggregate(today, stops, places, moves);
    features.printOverview();
  });
}
