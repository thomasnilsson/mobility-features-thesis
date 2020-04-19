part of app;

class MainPage extends StatefulWidget {
  MainPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  FeaturesAggregate _features;
  AppState _state = AppState.NO_FEATURES;
  AppProcessor processor = AppProcessor();
  bool streamingLocation = false;

  void initialize() async {
    await processor.initialize();
    setState(() {
      streamingLocation = processor.streamingLocation;
    });
  }

  void restart() async {
    await processor.restart();
    setState(() {
      streamingLocation = processor.streamingLocation;
    });
  }

  @override
  void initState() {
    super.initState();
    initialize();
  }

  void _updateFeatures() async {
    if (_state == AppState.CALCULATING_FEATURES) {
      print('Already calculating features!');
      return;
    }

    setState(() {
      _state = AppState.CALCULATING_FEATURES;
    });

    print('Calculating features...');
    FeaturesAggregate f = await processor.computeFeaturesAsync();

    setState(() {
      _features = f;
      _state = AppState.FEATURES_READY;
    });

    /// When features are computed, save stops and moves to Firebase
    processor.saveStopsAndMoves(f.stops, f.moves);
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
        entry("Points today", "${processor.pointsCollectedToday}",
            Icons.my_location),
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

  void goToPatientPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InfoPage(processor.uuid)),
    );
  }

  void goToQuestionPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QuestionPage(processor.uuid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            onPressed: goToPatientPage,
            icon: Icon(
              Icons.info,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: goToQuestionPage,
            icon: Icon(
              Icons.question_answer,
              color: Colors.white,
            ),
          )
        ],
      ),
      body: streamingLocation
          ? Text('Location is being tracked 👍')
          : Text(
              'Location is not tracking 🤨. Go into your Settings App > Privacy > Location Services, find the Runner App, and choose Always allow. Then click the restart button below 👍'),
//      body: Column(children: _showContent()),
      floatingActionButton: FloatingActionButton(
        onPressed: restart,
        tooltip: 'Restart',
        child: Icon(Icons.refresh),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
