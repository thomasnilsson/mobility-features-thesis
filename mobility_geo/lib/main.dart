import 'dart:async';
import 'package:flutter/material.dart';
import 'mobility.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  bool tracking = false;
  List<String> _contents = [];
  int transferredIdx = 0; // keep track of which data to send to database
  final databaseReference = FirebaseDatabase.instance.reference();

  @override
  void initState() {
    super.initState();
    initLocation();
    initCounter();
  }

  void initCounter() async {
    transferredIdx = await FileUtil().readCounter();
    transferredIdx = transferredIdx >= 0 ? transferredIdx : 0;
    print('Transfer index read: $transferredIdx');
  }

  void initLocation() async {
    await geo.isLocationServiceEnabled().then((response) {
      if (response) {
        startStreaming();
      } else {
        print('Location service not enabled');
      }
    });
  }

  void startStreaming() {
    geo.getPositionStream().listen((Position d) async {
      tracking = true;
      print('-' * 50);
      Map<String, String> x = {
        'lat': d.latitude.toString(),
        'lon': d.longitude.toString(),
        'datetime': d.timestamp.millisecondsSinceEpoch.toString()
      };
      print(x);
      await FileUtil().write(x, transferredIdx);
    });
  }

  void _pressedSend() async {
    _contents = await FileUtil().read();

    int before = transferredIdx + 0;

    for (var str in _contents.sublist(transferredIdx)) {
      if (str != '') {
        Map<String, String> x = Map<String, String>.from(json.decode(str));
        createRecord(x);
      }
      transferredIdx++;
    }

    print("${'-' * 15} FIREBASE WRITE ${'-' * 15}");
    print(
        'Created ${transferredIdx - before} transactitons. Now at $transferredIdx.');
  }

  void getData() {
    databaseReference.once().then((DataSnapshot snapshot) {
      print('Data : ${snapshot.value}');
    });
  }

  void createRecord(Map<String, String> obj) {
    databaseReference.child(obj['datetime']).set({
      'lat': obj['lat'],
      'lon': obj['lon'],
    });
  }

  void _pressedPrint() async {
    _contents = await FileUtil().read();
    for (var str in _contents) {
      print(str);
    }
    setState(() => print('Refreshed UI'));
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

  Map<String, String> decode(String s) =>
      Map<String, String>.from(json.decode(s));

  String parseRow(int index) {
    String s = _contents.reversed.toList()[index];
    String txt = '<Parsing Error>';
    if (s != '') {
      Map<String, String> m = decode(s);
      String time =
          DateTime.fromMillisecondsSinceEpoch(int.parse(m['datetime']))
              .toIso8601String();
      txt = "$time: ${m['lat']}, ${m['lon']}";
    }
    return txt;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      appBar: AppBar(
        title: Text('GeoTracker'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.send),
            onPressed: _pressedSend,
          ),
          IconButton(
            icon: Icon(Icons.print),
            onPressed: _pressedPrint,
          ),
          IconButton(
            icon: Icon(Icons.cloud_upload),
            onPressed: _pressedFileUpload,
          )
        ],
      ),
      body: _contents.isEmpty
          ? Text('No data yet 😭')
          : ListView.builder(
              itemCount: _contents.length,
              itemBuilder: (_, index) => ListTile(
                title: Text(parseRow(index)),
              ),
            ),
    ));
  }
}
