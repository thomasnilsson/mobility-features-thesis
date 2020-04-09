library mobility;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';
import 'package:mobility_features/mobility_features_lib.dart';

import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:convert';
import 'constants.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'utils.dart';

void main() => runApp(MobilityStudy());

class MobilityStudy extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    /// Set device orientation, i.e. disable landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    return new MaterialApp(
        title: 'Mobility Study',
        debugShowCheckedModeBanner: false,
        home: MainPage(title: title));
  }
}

class MainPage extends StatefulWidget {
  MainPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  FeaturesAggregate _features;
  AppState _state = AppState.NO_FEATURES;
  Geolocator _geoLocator = Geolocator();
  List<SingleLocationPoint> _pointsBuffer = [];
  String _uuid = 'NOT_SET';
  Serializer<SingleLocationPoint> _pointSerializer;
  Serializer<Stop> _stopSerializer;
  Serializer<Move> _moveSerializer;
  static const int BUFFER_SIZE = 100;
  int _pointsCollected = 0, _pointsCollectedToday = 0;

  void initialize() async {
    _initLocation();
    _initSerializers();

    await _loadUUID();
  }

  /// Feature Calculation ASYNC
  Future<FeaturesAggregate> _getFeatures() async {
    // From isolate to main isolate.
    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(calcFeaturesAsync, receivePort.sendPort);
    SendPort sendPort = await receivePort.first;

    DateTime today = DateTime.now().midnight;

    /// Load points, stops and moves via package
    print('Reading points');

    /// Load points. If the first point is from a previous date,
    /// filter out all previous points.
    /// Update the points file afterwards such that old points are deleted.
    List<SingleLocationPoint> points = await _pointSerializer.load();
    if (points.first.datetime.midnight.isBefore(today)) {
      print('Old location data found, deleting it...');
      points = points.where((p) => p.datetime.midnight == today).toList();
      await _pointSerializer.flush();
      _pointSerializer.save(points);
    }

    print('Points total: ${points.length}');

    print('Reading stops');
    List<Stop> stopsOld = await _stopSerializer.load();

    print('Reading moves');
    List<Move> movesOld = await _moveSerializer.load();

    /// TODO: Remove
    /// Load asset-stops and moves
//    List<Stop> stopsOld = await FileUtil().loadStopsFromAssets();
//    List<Move> movesOld = await FileUtil().loadMovesFromAssets();

    /// TODO: Remove
    /// Merge
//    List<Stop> stops = stopsAssets + stopsOld;
//    List<Move> moves = movesAssets + movesOld;

    FeaturesAggregate _features =
        await relay(sendPort, points, stopsOld, movesOld);
    _features.printOverview();
    for (var stop in _features.stopsDaily) print(stop);
    print(_features.hourMatrixDaily);
    return _features;
  }

  Future relay(SendPort sp, List<SingleLocationPoint> points, List<Stop> stops,
      List<Move> moves) {
    ReceivePort receivePort = ReceivePort();
    sp.send([points, stops, moves, receivePort.sendPort]);
    return receivePort.first;
  }

  static void calcFeaturesAsync(SendPort sendPort) async {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    final msg = await receivePort.first;

    List<SingleLocationPoint> points = msg[0];
    List<Stop> stopsLoaded = msg[1];
    List<Move> movesLoaded = msg[2];
    final replyPort = msg[3];
    DateTime today = DateTime.now().midnight;

    DataPreprocessor preprocessor = DataPreprocessor(today);

    DateTime fourWeeksAgo = today.subtract(Duration(days: 28));

    print('Filering out old places...');

    /// Filter out stops and moves which were computed today,
    /// which were just loaded as well as stops older than 28 days
    List<Stop> stopsOld = stopsLoaded.isEmpty
        ? stopsLoaded
        : stopsLoaded
            .where((s) =>
                s.arrival.midnight != today.midnight &&
                fourWeeksAgo.leq(s.arrival.midnight))
            .toList();

    List<Move> movesOld = movesLoaded.isEmpty
        ? movesLoaded
        : movesLoaded
            .where((m) =>
                m.stopFrom.arrival.midnight != today.midnight &&
                fourWeeksAgo.leq(m.stopFrom.arrival.midnight))
            .toList();

    print('Calculating new stops...');
    List<Stop> stopsToday = preprocessor.findStops(points, filter: false);

    print('Calculating new moves...');
    List<Move> movesToday = preprocessor.findMoves(points, stopsToday, filter: false);

    /// Get all stop, moves, and places
    List<Stop> stopsAll = stopsOld + stopsToday;
    List<Move> movesAll = movesOld + movesToday;

//    List<Stop> stopsAll = stopsOld;
//    List<Move> movesAll = movesOld;
    print('No. stops: ${stopsAll.length}');
    print('No. moves: ${movesAll.length}');

    print('Calculating new places...');

    List<Place> placesAll = preprocessor.findPlaces(stopsAll);

    /// Extract features
    FeaturesAggregate features =
        FeaturesAggregate(today, stopsAll, placesAll, movesAll);

    /// Send back response
    replyPort.send(features);
  }

  Future<String> _uploadDataToFirebase(File f, String prefix) async {
    /// Create a folder using the UUID,
    /// if not created, and write to a  file inside it
    String fireBaseFileName = '${_uuid}/${prefix}_$_uuid.json';
    StorageReference firebaseStorageRef =
        FirebaseStorage.instance.ref().child(fireBaseFileName);
    StorageUploadTask uploadTask = firebaseStorageRef.putFile(f);
    StorageTaskSnapshot downloadUrl = await uploadTask.onComplete;
    String url = await downloadUrl.ref.getDownloadURL();
    return url;
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
    if (_pointsBuffer.length >= BUFFER_SIZE) {
      _saveBuffer();
    }
  }

  void _saveBuffer() async {
    String dateString =
        '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';

    await _pointSerializer.save(_pointsBuffer);
    File pointsFile = await FileUtil().pointsFile;

    /// Date is added to the points file
    String urlPoints =
        await _uploadDataToFirebase(pointsFile, 'points-$dateString');
    print(urlPoints);
    _pointsBuffer = [];
  }

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<File> _file(String type) async {
    String path = (await getApplicationDocumentsDirectory()).path;
    return new File('$path/$type.json');
  }

  void _initSerializers() async {
    File pointsFile = await FileUtil().pointsFile;
    File stopsFile = await FileUtil().stopsFile;
    File movesFile = await FileUtil().movesFile;

    _pointSerializer = Serializer<SingleLocationPoint>(pointsFile, debug: true);
    _stopSerializer = Serializer<Stop>(stopsFile, debug: true);
    _moveSerializer = Serializer<Move>(movesFile, debug: true);
  }

  void _updateFeatures() async {
    setState(() {
      _state = AppState.CALCULATING_FEATURES;
    });

    /// Write the newest data points to the file before calculation
    await _saveBuffer();

    print('Calculating features...');
    FeaturesAggregate f = await _getFeatures();

    setState(() {
      _features = f;
      _state = AppState.FEATURES_READY;
    });

    /// When features are computed, save stops and moves to Firebase
    _saveStopsAndMovesToFirebase(f);
  }

  Future<void> _saveStopsAndMovesToFirebase(FeaturesAggregate features) async {
    /// Clean up files
    await _stopSerializer.flush();
    await _moveSerializer.flush();

    /// Write updates values
    await _stopSerializer.save(features.stops);
    await _moveSerializer.save(features.moves);

    File stopsFile = await FileUtil().stopsFile;
    File movesFile = await FileUtil().movesFile;

    String urlStops = await _uploadDataToFirebase(stopsFile, 'stops');
    print(urlStops);

    String urlMoves = await _uploadDataToFirebase(movesFile, 'moves');
    print(urlMoves);
  }

  Widget featuresOverview() {
    return ListView(
      children: <Widget>[
        entry(
            "Routine index",
            _features.routineIndexDaily < 0
                ? "?"
                : "${(_features.routineIndexDaily * 100).toStringAsFixed(1)}%",
            Icons.repeat),
        entry(
            "Home stay",
            _features.homeStayDaily < 0
                ? "?"
                : "${(_features.homeStayDaily * 100).toStringAsFixed(1)}%",
            Icons.home),
        entry(
            "Distance travelled",
            "${(_features.totalDistanceDaily / 1000).toStringAsFixed(2)} km",
            Icons.directions_walk),
        entry("Significant places", "${_features.numberOfClustersDaily}",
            Icons.place),
        entry(
            "Time-place distribution",
            "${_features.normalizedEntropyDaily.toStringAsFixed(2)}",
            Icons.equalizer),
        entry(
            "Location variance",
            "${(111.133 * _features.locationVarianceDaily).toStringAsFixed(5)} km",
            Icons.crop_rotate),
        entry("No. days tracked", "${_features.uniqueDates.length}",
            Icons.date_range),
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

  void goToPatientPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InfoPage(_uuid)),
    );
  }

  List<Widget> _contentNoFeatures() {
    return [
      Container(
          margin: EdgeInsets.all(25),
          child: Text(
            'Click on the refresh button to generate features',
            style: TextStyle(fontSize: 20),
          ))
    ];
  }

  List<Widget> _contentFeaturesReady() {
    return [
      Container(
          margin: EdgeInsets.all(25),
          child: Column(children: [
            Text(
              'Statistics for today,',
              style: TextStyle(fontSize: 20),
            ),
            Text(
              '${formatDate(_features.date)}',
              style: TextStyle(fontSize: 20, color: Colors.blue),
            ),
          ])),
      Expanded(child: featuresOverview())
    ];
  }

  List<Widget> _contentCalculatingFeatures() {
    return [
      Container(
          margin: EdgeInsets.all(25),
          child: Column(children: [
            Text(
              'Calculating features...',
              style: TextStyle(fontSize: 20),
            ),
            Container(
                margin: EdgeInsets.only(top: 50),
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 10)))
          ]))
    ];
  }

  List<Widget> _showContent() {
    if (_state == AppState.FEATURES_READY)
      return _contentFeaturesReady();
    else if (_state == AppState.CALCULATING_FEATURES)
      return _contentCalculatingFeatures();
    else
      return _contentNoFeatures();
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(children: _showContent()),
      floatingActionButton: FloatingActionButton(
        onPressed: _updateFeatures,
        tooltip: 'Calculate features',
        child: Icon(Icons.refresh),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class InfoPage extends StatelessWidget {
  String uuid;

  InfoPage(this.uuid);

  Widget textBox(String t, [TextStyle style]) {
    return Container(
      padding: EdgeInsets.only(top: 15),
      child: Text(t, style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('*'*50);
    print('Check');
    print('*'*50);

    return Scaffold(
      appBar: AppBar(
        title: Text("Info Page"),
      ),
      body: Center(
          child: Container(
        margin: EdgeInsets.all(10),
        child: Column(
          children: [
            textBox('This app is a part of a Master\'s Thesis study.'),
            textBox(
                'Your location data will be collected anonymously during 2-4 weeks, then analyzed and lastly deleted permanently.'),
            textBox(
                'If you have any questions regarding the study, shoot me an email at tnni@dtu.dk.'),
            textBox('Thank you for your contribution!'),
            textBox("Your participant ID is:",
                TextStyle(fontSize: 25, color: Colors.blue)),
            textBox(uuid, TextStyle(fontSize: 14, color: Colors.black38)),
          ],
        ),
      )),
    );
  }
}
