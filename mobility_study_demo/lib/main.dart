library mobility;

import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';
import 'package:mobility_features/mobility_features_lib.dart';

import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:convert';

part 'utils.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: MyHomePage(title: 'Mobility Study', number: 10),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title, this.number}) : super(key: key);

  final String title;
  final int number;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FeaturesAggregate _features = null;

  Geolocator geo = Geolocator();
  List<SingleLocationPoint> _points = [];
  List<Stop> _stops = [];
  List<Move> _moves = [];

  Future _loadStopsFromAssets() async {
    String contents = await rootBundle.loadString('data/all_stops.json');
    List decoded = json.decode(contents);
    _stops = decoded.map((x) => Stop.fromJson(x)).toList();
  }

  Future _loadMovesFromAssets() async {
    String contents = await rootBundle.loadString('data/all_moves.json');
    List decoded = json.decode(contents);
    _moves = decoded.map((x) => Move.fromJson(x)).toList();
  }

  Future _loadDataFromDevice() async {
    List<SingleLocationPoint> localData = await FileUtil().readLocationData();
    _points.addAll(localData);
  }

  /// Feature Calculation ASYNC
  Future<FeaturesAggregate> _getFeatures() async {
    // From isolate to main isolate.
    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(calcFeaturesAsync, receivePort.sendPort);
    SendPort sendPort = await receivePort.first;
    FeaturesAggregate _features =
        await relay(sendPort, _points, _stops, _moves);
    return _features;
  }

  Future relay(SendPort sp, List<SingleLocationPoint> points, List<Stop> stops,
      List<Move> moves) {
    ReceivePort receivePort = ReceivePort();
    sp.send([points, stops, moves, receivePort.sendPort]);
    return receivePort.first;
  }

  static calcFeaturesAsync(SendPort sendPort) async {
    ReceivePort receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    var msg = await receivePort.first;

    List<SingleLocationPoint> points = msg[0];
    List<Stop> stops = msg[1];
    List<Move> moves = msg[2];
    SendPort replyPort = msg[3];

    /// Find today's stops and moves
//    DateTime today = DateTime.now().midnight;
    DateTime today = DateTime(2020, 02, 17).midnight;
    DataPreprocessor p = DataPreprocessor(today);
    List<Stop> stopsToday = p.findStops(points);
    List<Move> movesToday = p.findMoves(points, stopsToday);

    /// Add historic stops and moves
    stops.addAll(stopsToday);
    moves.addAll(movesToday);

    /// Find all places
    List<Place> places = p.findPlaces(stops);

    /// Extract features
    FeaturesAggregate f = FeaturesAggregate(today, stops, places, moves);

    /// Send back response
    replyPort.send(f);
  }

  void _initLocation() async {
    await geo.isLocationServiceEnabled().then((response) {
      if (response) {
        geo.getPositionStream().listen((Position d) async {
          print('-' * 50);
          SingleLocationPoint p = SingleLocationPoint(
              Location(d.latitude, d.longitude), d.timestamp);
          print(p);
          FileUtil().writeSingleLocationPoint(p);
        });
      } else {
        print('Location service not enabled');
      }
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    start();
  }

  void start() async {
    _initLocation();
    await _loadStopsFromAssets();
    await _loadMovesFromAssets();

    await _loadDataFromDevice();
    print('Dataset loaded, length = ${_points.length} points');
  }

  void _buttonPressed() async {
    print('Loading features...');
    var f = await _getFeatures();
    setState(() {
      _features = f;
    });
  }

  List<Widget> getContent() => [
        Text(
          'Statistics for today (thus far), ${formatDate(_features.date)} based on ${_features.historicalDates.length} previous dates.',
          style: Theme.of(context).textTheme.body2,
        ),
        Text(
          "You've have stuck ${_features.routineIndexDaily * 100} % to your routine.",
        ),
        Text(
          "You've stayed home ${_features.homeStayDaily * 100} % of the time.",
        ),
        Text(
          "You've travelled ${_features.totalDistanceDaily / 1000} km.",
        ),
        Text(
          "You've visited ${_features.numberOfClustersDaily} significant places.",
        ),
        Text(
          'Entropy for time spent at significant places is ${_features.normalizedEntropyDaily}',
        ),
        Text(
          'Total location variance is ${_features.locationVarianceDaily}',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    List<Widget> noContent = [Text('No features yet...')];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _features == null ? noContent : getContent()),
      floatingActionButton: FloatingActionButton(
        onPressed: _buttonPressed,
        tooltip: 'Calculate features',
        child: Icon(Icons.refresh),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
