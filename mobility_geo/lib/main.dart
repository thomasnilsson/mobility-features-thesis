import 'dart:async';
import 'package:flutter/material.dart';
import 'mobility.dart';
import 'package:firebase_database/firebase_database.dart';


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
    print('Transfer idx read: $transferredIdx');
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

  void _pressed() async {
    String c = await FileUtil().read();
    _contents = c.split('\n');

    int before = transferredIdx + 0;

    for (var str in _contents.sublist(transferredIdx)) {
      print(str);
      if (str != '') {
        Map<String, String> x = Map<String, String>.from(json.decode(str));
        createRecord(x);
      }
      transferredIdx++;
    }

    print(
        'Created ${transferredIdx - before} transactitons. Now at $transferredIdx.');
    setState(() => print('Refreshed UI'));
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(
              tracking ? 'Mobility (Not tracking)' : 'Mobility (Tracking...)'),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _pressed,
            )
          ],
        ),
        body: _contents.isEmpty
            ? Text('No data yet 😭')
            : ListView.builder(
                itemCount: _contents.length,
                itemBuilder: (_, index) => ListTile(
                      title: Text("${_contents[index]}"),
                    )),
      ),
    );
  }
}
