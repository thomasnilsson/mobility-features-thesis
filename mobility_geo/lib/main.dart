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
  List<String> _contents = [];

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
      print(d.str);
      await FileUtil().write(d);
    });
  }

  void _pressed() async {
    String c = await FileUtil().read();
    _contents = c.split('\n');

    setState(() => print('Refreshed UI'));
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
