import 'dart:async';
import 'package:flutter/material.dart';
import 'mobility.dart';

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
  List<Map<String, String>> _dataPointsJson = [];
  List<String> content = [];
  final databaseReference = FirebaseDatabase.instance.reference();
  bool showGpsData = true;


  @override
  void initState() {
    super.initState();
    initLocation();
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
      FileUtil().write(x);
    });
  }

  void _pressedPrint() async {
    await FileUtil().read().then((List<Map<String, String>> c) {
      showGpsData = true;
      print(c);
      _dataPointsJson = c;
      content = [];
      for (Map<String, String> m in _dataPointsJson) {
        print(m);
        content.add(m.toString());
      }
      setState(() => print('Refreshed UI'));
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

  void _pressedCalculate() {
    showGpsData = false;
    List<SingleLocationPoint> dataset = [];
    for (Map<String, String> m in _dataPointsJson) {
      SingleLocationPoint d = SingleLocationPoint.fromJson(m);
      dataset.add(d);
    }

    Preprocessor p = Preprocessor(dataset);
    DateTime date = DateTime.now(); //DateTime(2020, 02, 12);
    Features f = p.featuresByDate(date);

    content = [];
    content.add('homeStayDaily: ${f.homeStayDaily}');
//    content.add('locationVarianceDaily: ${f.locationVarianceDaily}');
    content.add('totalDistanceDaily: ${f.totalDistanceDaily}');
    content.add('numberOfClustersDaily: ${f.numberOfClustersDaily}');
    content.add('normalizedEntropyDaily: ${f.normalizedEntropyDaily}');
    content.add('routineIndex: ${f.routineIndex}');
    content.add('-'*50);
    content.add('homeStay: ${f.homeStay}');
    content.add('locationVariance: ${f.locationVariance}');
    content.add('totalDistance: ${f.totalDistance}');
    content.add('numberOfClusters: ${f.numberOfClusters}');
    content.add('normalizedEntropy: ${f.normalizedEntropy}');
    content.add('-'*50);

    for (var x in f.stops) {
      content.add(x.toString());
    }
    for (var x in f.places) {
      content.add(x.toString());
    }
    for (var x in f.moves) {
      content.add(x.toString());
    }


    for (var x in content) print(x);
    setState(() => print('Refreshed UI'));

  }

  String parseRow(int index) {
    String txt = content[index];
    if (showGpsData) {
      Map<String, String> m = _dataPointsJson.reversed.toList()[index];
      if (m.isNotEmpty) {
        String time =
        DateTime.fromMillisecondsSinceEpoch(int.parse(m['datetime']))
            .toIso8601String();
        txt = "$time: ${m['lat']}, ${m['lon']}";
      }
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
            icon: Icon(Icons.print),
            onPressed: _pressedPrint,
          ),
          IconButton(
            icon: Icon(Icons.cloud_upload),
            onPressed: _pressedFileUpload,
          ),
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: _pressedCalculate,
          )
        ],
      ),
      body: content.isEmpty
          ? Text('No data yet 😭')
          : ListView.builder(
              itemCount: content.length,
              itemBuilder: (_, index) => ListTile(
                title: Text(parseRow(index)),
              ),
            ),
    ));
  }
}
