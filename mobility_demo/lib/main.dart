import 'dart:async';
import 'package:flutter/material.dart';
import 'mobility.dart';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'ui/data_widget.dart';
import 'ui/features_widget.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Geolocator geo = Geolocator();
  List<SingleLocationPoint> _points = [];
  List<Stop> _stops = [];
  List<Move> _moves = [];

  final databaseReference = FirebaseDatabase.instance.reference();
  int _currentIndex = 0;
  List<Widget> _children = [DataWidget([]), FeaturesWidget(null)];

  @override
  void initState() {
    super.initState();

    init();
    _initLocation();
  }

  void init() async {
    //    await _loadPointsFromAssets();
    await _loadStopsFromAssets();
    await _loadMovesFromAssets();

    await _loadDataFromDevice();
    print('Dataset length: ${_points.length}');
    await _loadFeaturesAsync();
  }

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
    _children[0] = DataWidget(_points);
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

  void _pressedFileUpload() async {
    DateTime now = DateTime.now();
    String date = '${now.year}-${now.month}-${now.day}';
    await FileUtil().locationDataFile.then((File f) async {
      final StorageReference firebaseStorageRef =
          FirebaseStorage.instance.ref().child('data-$date.json');
      final StorageUploadTask uploadTask = firebaseStorageRef.putFile(f);
      final StorageTaskSnapshot downloadUrl = await uploadTask.onComplete;
      final String url = await downloadUrl.ref.getDownloadURL();
      print('URL Is $url');
    });
  }

  void onTabTapped(int index) {
    _loadDataFromDevice();
    setState(() {
      _currentIndex = index;
    });
  }

  /// Feature Calculation ASYNC
  Future _loadFeaturesAsync() async {
    // From isolate to main isolate.
    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(calcFeaturesAsync, receivePort.sendPort);

    // Send port for the prime number isolate. We will send parameter n
    // using this port.
    SendPort sendPort = await receivePort.first;

    FeaturesAggregate f = await relay(sendPort, _points, _stops, _moves);
    _children[1] = FeaturesWidget(f);
  }

  Future relay(SendPort sp, List<SingleLocationPoint> points,
      List<Stop> stops, List<Move> moves) {
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

    print('Moves: ${moves.length}');
    print('Stops: ${stops.length}');

    /// Find all places
    List<Place> places = p.findPlaces(stops);

    /// Extract features
    FeaturesAggregate f = FeaturesAggregate(today, stops, places, moves);

    /// Send back response
    replyPort.send(f);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(
        title: Text('Mobility Demo'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.cloud_upload),
            onPressed: _pressedFileUpload,
          ),
          IconButton(
            icon: Icon(Icons.update),
            onPressed: _loadFeaturesAsync,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: onTabTapped,
        currentIndex: _currentIndex,
        // this will be set when a new tab is tapped
        items: [
          BottomNavigationBarItem(
            icon: new Icon(Icons.location_on),
            title: new Text('Data'),
          ),
          BottomNavigationBarItem(
            icon: new Icon(Icons.person),
            title: new Text('Features'),
          ),
        ],
      ),
      body: _children[_currentIndex], // new
    ));
  }
}
