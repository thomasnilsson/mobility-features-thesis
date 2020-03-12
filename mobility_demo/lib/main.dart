import 'dart:async';
import 'package:flutter/material.dart';
import 'mobility.dart';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'ui/data_widget.dart';
import 'ui/features_widget.dart';

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
  List<SingleLocationPoint> dataset = [];
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
    SingleLocationPoint p =
        SingleLocationPoint(Location(12.345, 98.765), DateTime.now());
    Stop s = Stop([p, p, p], placeId: 2);
    List<Stop> stops = [s, s, s];

    List jsonStops = stops.map((s) => s.toJson()).toList();

    FileManager fm = FileManager('stops.json');
    await fm.writeStops(stops);
    List<Stop> stopsFromFile = await fm.readStops();
    FileUtil().printList(stopsFromFile);

    await _loadDataset();
    await _loadFeatures();
  }

  Future _loadDataset() async {
    dataset = await FileUtil().readLocationData();

    _children[0] = DataWidget(dataset);
  }

  Future _loadFeatures() async {
    // From isolate to main isolate.
    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(calcFeaturesAsync, receivePort.sendPort);

    // Send port for the prime number isolate. We will send parameter n
    // using this port.
    SendPort sendPort = await receivePort.first;

    Features f = await sendReceive(sendPort, dataset);
    _children[1] = FeaturesWidget(f);
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

  static calcFeaturesAsync(SendPort sendPort) async {
    // Port for receiving message from main isolate.
    // We will receive the value of n using this port.
    ReceivePort receivePort = ReceivePort();
    // Sending the send Port of isolate to receive port of main isolate.
    sendPort.send(receivePort.sendPort);
    var msg = await receivePort.first;

    List<SingleLocationPoint> dataset = msg[0];
    SendPort replyPort = msg[1];

    Preprocessor p = Preprocessor(dataset);
    DateTime date = DateTime.now().date;
    Features f = p.featuresByDate(date);

    replyPort.send(f);
  }

  Future sendReceive(SendPort send, message) {
    ReceivePort receivePort = ReceivePort();
    send.send([message, receivePort.sendPort]);
    return receivePort.first;
  }

  void onTabTapped(int index) {
    _loadDataset();
    setState(() {
      _currentIndex = index;
    });
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
            onPressed: _loadFeatures,
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
