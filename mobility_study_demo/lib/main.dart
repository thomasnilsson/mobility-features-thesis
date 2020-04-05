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
import 'constants.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foreground_service/foreground_service.dart';

import 'dart:io' show Platform;

part 'utils.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        title: 'Mobility Study',
        debugShowCheckedModeBanner: false,
        home: MyHomePage(title: title));
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FeaturesAggregate _features;

  Geolocator _geoLocator = Geolocator();
  List<SingleLocationPoint> _pointsBuffer = [];
  List<Stop> _stops = [];
  List<Move> _moves = [];
  String _uuid = 'NOT_SET';
  Serializer<SingleLocationPoint> _singleLocationPointSerializer;
  Serializer<Stop> _stopSerializer;
  Serializer<Move> _moveSerializer;

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
//    List<SingleLocationPoint> localData = await FileUtil().readLocationData();
    List<SingleLocationPoint> localData =
        await _singleLocationPointSerializer.read();
    _pointsBuffer.addAll(localData);
  }

  /// Feature Calculation ASYNC
  Future<FeaturesAggregate> _getFeatures() async {
    // From isolate to main isolate.
    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(calcFeaturesAsync, receivePort.sendPort);
    SendPort sendPort = await receivePort.first;
    List<SingleLocationPoint> todaysPoints =
        await _singleLocationPointSerializer.read();
    FeaturesAggregate _features =
        await relay(sendPort, todaysPoints, _stops, _moves);
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

  Future<void> _loadUUID() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _uuid = prefs.getString('uuid');
    if (_uuid == null) {
      _uuid = Uuid().v4();
      print('UUID generated> $_uuid');
      prefs.setString('uuid', _uuid);
    } else {
      print('Loaded UUID succesfully: $_uuid');
      prefs.setString('uuid', _uuid);
    }
  }

  void _initLocation() async {
    await _geoLocator.isLocationServiceEnabled().then((response) {
      if (response) {
        _geoLocator.getPositionStream().listen(onData);
      } else {
        print('Location service not enabled');
      }
    });
  }

  void onData(Position d) async {
    print('-' * 50);
    SingleLocationPoint p =
        SingleLocationPoint(Location(d.latitude, d.longitude), d.timestamp);
    _pointsBuffer.add(p);

    print('New location point: $p');

    /// If buffer has reached max capacity, write to file and empty the buffer
    /// This is to avoid constantly reading and writing from file each time a new
    /// point comes in.
    if (_pointsBuffer.length >= 5) {
      _singleLocationPointSerializer.write(_pointsBuffer);
      _pointsBuffer = [];
    }
  }

  //use an async method so we can await
  void startForegroundServiceAndroid() async {
    if (!(await ForegroundService.foregroundServiceIsStarted())) {
      await ForegroundService.setServiceIntervalSeconds(5);

      //necessity of editMode is dubious (see function comments)
      await ForegroundService.notification.startEditMode();

      await ForegroundService.notification
          .setTitle("Example Title: ${DateTime.now()}");
      await ForegroundService.notification
          .setText("Example Text: ${DateTime.now()}");

      await ForegroundService.notification.finishEditMode();

      try {
        await ForegroundService.startForegroundService(
            foregroundServiceFunction);
        await ForegroundService.getWakeLock();
      } catch (error) {
        print(error);
      }
    }
  }

  void foregroundServiceFunction() {
    debugPrint("The current time is: ${DateTime.now()}");
    ForegroundService.notification.setText("The time was: ${DateTime.now()}");
  }

  @override
  void initState() {
    super.initState();
    start();
  }

  void start() async {
    _initLocation();
    _initSerializers();

    /// Start foreground service in order to track location in background
    /// (only required on Android, iOS allows background location by default)
    if (Platform.isAndroid) {
      startForegroundServiceAndroid();
    }

    await _loadUUID();
    await _loadStopsFromAssets();
    await _loadMovesFromAssets();
    await _loadDataFromDevice();

    print('Dataset loaded, length = ${_pointsBuffer.length} points');
  }

  void _initSerializers() async {
    final dir = await getApplicationDocumentsDirectory();
    _singleLocationPointSerializer =
        Serializer<SingleLocationPoint>(new File('${dir.path}/locations.json'));
    _stopSerializer = Serializer<Stop>(new File('${dir.path}/stops.json'));
    _moveSerializer = Serializer<Move>(new File('${dir.path}/moves.json'));
  }

  void _buttonPressed() async {
    print('Loading features...');
    var f = await _getFeatures();
    setState(() {
      _features = f;
    });
  }

  Widget featuresOverview() {
    return ListView(
      children: <Widget>[
        entry("Dates today is compared to",
            "${_features.historicalDates.length}", Icons.date_range),
        entry(
            "Routine index",
            "${(_features.routineIndexDaily * 100).toStringAsFixed(1)}%",
            Icons.repeat),
        entry(
            "Home stay",
            "${(_features.homeStayDaily * 100).toStringAsFixed(1)}%",
            Icons.home),
        entry(
            "Distance travelled",
            "${(_features.totalDistanceDaily / 1000).toStringAsFixed(2)} km",
            Icons.directions_walk),
        entry("Significant places", "${_features.numberOfClustersDaily}",
            Icons.place),
        entry(
            "Normalized entropy",
            "${_features.normalizedEntropyDaily.toStringAsFixed(2)}",
            Icons.equalizer),
        entry(
            "Location variance",
            "${(111.133 * _features.locationVarianceDaily).toStringAsFixed(5)} km",
            Icons.crop_rotate),
      ],
    );
  }

  Widget entry(String key, String value, IconData icon) {
    return Container(
        padding: const EdgeInsets.all(2),
        margin: EdgeInsets.all(3),
        child: ListTile(
          leading: Icon(icon),
          title: Text(key),
          trailing: Text(value),
        ));
  }

  List<Widget> getContent() => <Widget>[
        Container(
            margin: EdgeInsets.all(25),
            child: Column(children: [
              Text(
                'Statistics for',
                style: TextStyle(fontSize: 20),
              ),
              Text(
                '${formatDate(_features.date)}',
                style: TextStyle(fontSize: 20, color: Colors.blue),
              ),
            ])),
        Expanded(child: featuresOverview())
      ];

  void goToPatientPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InfoPage(_uuid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> noContent = [
      Text('No features yet, click the refresh button to generate features')
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            onPressed: goToPatientPage,
            icon: Icon(
              Icons.info,
              color: Colors.white,
            ),
          )
        ],
      ),
      body: Column(
        children: _features == null ? noContent : getContent(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _buttonPressed,
        tooltip: 'Calculate features',
        child: Icon(Icons.refresh),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class InfoPage extends StatelessWidget {
  String uuid;

  InfoPage(this.uuid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Info Page"),
      ),
      body: Center(
          child: Container(
        margin: EdgeInsets.all(10),
        child: Column(
          children: <Widget>[
            Text(
              "Your participant ID:",
              style: TextStyle(fontSize: 20),
            ),
            Text(
              uuid,
              style: TextStyle(fontSize: 12),
            ),
            Container(
              margin: EdgeInsets.only(top: 20),
              child: Text(
                  'This is some information regarding the features and what we do with your data.'),
            )
          ],
        ),
      )),
    );
  }
}
