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
  Location location = Location();
  List<LocationData> _data = [];
  bool tracking = false;
  int writeEvery = 10;

  @override
  void initState() {
    super.initState();
    locationStuff();
  }

  void locationStuff() async {
    FileUtil().flush();
    await location.requestPermission().then((response) {
      if (response) {
        location.onLocationChanged().listen((LocationData d) async {
          tracking = true;
          print('-' * 50);
          print(d.str);
          _data.add(d);
          await FileUtil().write([d]);
        });
      } else {
        locationStuff();
      }
    });
  }

  void _pressed() async {
    String c = await FileUtil().read();
    setState(() {
      print('*'*20 + 'FILE CONTENTS' + '*'*20);
      print(c);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(tracking ? 'Mobility (Not tracking)' : 'Mobility (Tracking...)'),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.location_on),
              onPressed: _pressed,
            )
          ],
        ),
        body: _data.isEmpty
            ? Text('No data yet 😭')
            : ListView.builder(
                itemCount: _data.length,
                itemBuilder: (_, index) => ListTile(
                      title: Text(
                          "${_data[index].latitude}, ${_data[index].longitude}"),
                      trailing: Text('${_data[index].date.toString()}'),
                      subtitle: Text('${_data[index].accuracy}'),
                    )),
      ),
    );
  }
}
