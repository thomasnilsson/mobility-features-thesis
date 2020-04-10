part of app;

class AppProcessor {
  FileUtil util = FileUtil();
  Geolocator _geoLocator = Geolocator();

  String uuid;
  Serializer<SingleLocationPoint> _pointSerializer;
  Serializer<Stop> _stopSerializer;
  Serializer<Move> _moveSerializer;
  List<SingleLocationPoint> _pointsBuffer = [];
  static const int BUFFER_SIZE = 100;
  int pointsCollectedToday = 0;
  Isolate isolate;

  Future initialize() async {
    await _loadUUID();
    await _initSerializers();
    await _initLocation();
  }

  Future _initSerializers() async {
    File pointsFile = await FileUtil().pointsFile;
    File stopsFile = await FileUtil().stopsFile;
    File movesFile = await FileUtil().movesFile;

    _pointSerializer = Serializer<SingleLocationPoint>(pointsFile, debug: true);
    _stopSerializer = Serializer<Stop>(stopsFile, debug: true);
    _moveSerializer = Serializer<Move>(movesFile, debug: true);
  }

  Future _initLocation() async {
    /// Set a minimum dist of such that we dont track every little move
    LocationOptions options = LocationOptions(distanceFilter: 5);
    await _geoLocator.isLocationServiceEnabled().then((response) {
      if (response) {
        _geoLocator.getPositionStream(options).listen(_onData);
      } else {
        print('Location service not enabled');
      }
    });
  }

  Future<void> _loadUUID() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    uuid = prefs.getString('uuid');
    if (uuid == null) {
      uuid = Uuid().v4();
      print('UUID generated> $uuid');
      prefs.setString('uuid', uuid);
    } else {
      print('Loaded UUID succesfully: $uuid');
      prefs.setString('uuid', uuid);
    }
  }

  /// Loads local data points and filters older points out if needed
  Future<List<SingleLocationPoint>> _loadLocalPoints() async {
    DateTime today = DateTime.now().midnight;
    print('Loading local data points...');
    List<SingleLocationPoint> points = await _pointSerializer.load();
    if (points.first.datetime.midnight.isBefore(today)) {
      print('Old location data found, deleting it...');
      points = points.where((p) => p.datetime.midnight == today).toList();
      await _pointSerializer.flush();
      await _pointSerializer.save(points);
    }
    return points;
  }

  void _onData(Position d) async {
    SingleLocationPoint p =
        SingleLocationPoint(Location(d.latitude, d.longitude), d.timestamp);
    _pointsBuffer.add(p);

    print('New location point: $p');

    /// If buffer has reached max capacity, write to file and empty the buffer
    /// This is to avoid constantly reading and writing from file each time a new
    /// point comes in.
    if (_pointsBuffer.length >= BUFFER_SIZE) {
//      /// Downsample to save space and make algorithms easier to run
//      List<SingleLocationPoint> downSampled = _downSample(_pointsBuffer);
      /// Save buffer locally, empty it, and then upload the points file to firebase
      await _pointSerializer.save(_pointsBuffer);
      _pointsBuffer = [];
      String urlPoints = await _uploadPoints();
      print(urlPoints);
    }
  }

  List<SingleLocationPoint> _downSample(List<SingleLocationPoint> data,
      {int factor = 10}) {
    List<SingleLocationPoint> downSampled = [];
    for (int i = 0; i < data.length; i = i + factor) {
      downSampled.add(data[i]);
    }
    return downSampled;
  }

  void start() async {
    ReceivePort receivePort =
        ReceivePort(); //port for this main isolate to receive messages.
    isolate = await Isolate.spawn(runTimer, receivePort.sendPort);
    receivePort.listen((data) {
      stdout.write('RECEIVE: ' + data + ', ');
    });
  }

  void runTimer(SendPort sendPort) {
    int counter = 0;
    Timer.periodic(new Duration(seconds: 1), (Timer t) {
      counter++;
      String msg = 'notification ' + counter.toString();
      stdout.write('SEND: ' + msg + ' - ');
      sendPort.send(msg);
    });
  }

  void stop() {
    if (isolate != null) {
      stdout.writeln('killing isolate');
      isolate.kill(priority: Isolate.immediate);
      isolate = null;
    }
  }

  Future<String> _uploadPoints() async {
    /// Save to firebase. Date is added to the points file name on firebase
    File pointsFile = await FileUtil().pointsFile;
    String dateString =
        '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    String urlPoints = await upload(pointsFile, 'points-$dateString');
    return urlPoints;
  }

  Future<FeaturesAggregate> computeFeaturesAsync() async {
    /// Load points, stops and moves via package
    print('Reading points');
    List<SingleLocationPoint> points = await _loadLocalPoints();
    pointsCollectedToday = points.length;

    print('Reading stops');
    List<Stop> stops = await _stopSerializer.load();

    print('Reading moves');
    List<Move> moves = await _moveSerializer.load();

    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(_asyncComputation, receivePort.sendPort);
    SendPort sendPort = await receivePort.first;

    FeaturesAggregate features = await relay(sendPort, points, stops, moves);
    return features;
  }

  Future relay(SendPort sp, List<SingleLocationPoint> points, List<Stop> stops,
      List<Move> moves) {
//    Map args = {
//      'sendPort': sendPort,
//      'points': points,
//      'stops': stops,
//      'moves': moves,
//    };
    ReceivePort receivePort = ReceivePort();
    sp.send([points, stops, moves, receivePort.sendPort]);
    return receivePort.first;
  }

  static void _asyncComputation(SendPort sendPort) async {
    print('Check...!');
    ReceivePort receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    List args = await receivePort.first;
//    SendPort replyPort = args['sendPort'];
//    List<SingleLocationPoint> points = args['points'];
//    List<Stop> stops = args['stops'];
//    List<Move> moves = args['moves'];

    List<SingleLocationPoint> points = args[0];
    List<Stop> stops = args[1];
    List<Move> moves = args[2];
    SendPort replyPort = args[3];

    DateTime today = DateTime.now().midnight;
    DataPreprocessor preprocessor = DataPreprocessor(today);
    DateTime fourWeeksAgo = today.subtract(Duration(days: 28));
    print('Filering out old stops/moves...');

    /// Filter out stops and moves which were computed today,
    /// which were just loaded as well as stops older than 28 days
    List<Stop> stopsOld = stops.isEmpty
        ? stops
        : stops
            .where((s) =>
                s.arrival.midnight != today.midnight &&
                fourWeeksAgo.leq(s.arrival.midnight))
            .toList();

    List<Move> movesOld = moves.isEmpty
        ? moves
        : moves
            .where((m) =>
                m.stopFrom.arrival.midnight != today.midnight &&
                fourWeeksAgo.leq(m.stopFrom.arrival.midnight))
            .toList();

    print('Calculating new stops...');
    List<Stop> stopsToday = preprocessor.findStops(points, filter: false);

    print('Calculating new moves...');
    List<Move> movesToday =
        preprocessor.findMoves(points, stopsToday, filter: false);

    /// Get all stop, moves, and places
    List<Stop> stopsAll = stopsOld + stopsToday;
    List<Move> movesAll = movesOld + movesToday;

    print('Calculating new places...');

    List<Place> placesAll = preprocessor.findPlaces(stopsAll);

    print('No. stops: ${stopsAll.length}');
    for (final x in stopsAll) print(x);
    print('No. moves: ${movesAll.length}');
    for (final x in movesAll) print(x);
    print('No. places: ${placesAll.length}');
    for (final x in placesAll) print(x);

    /// Extract features
    FeaturesAggregate features =
        FeaturesAggregate(today, stopsAll, placesAll, movesAll);

    /// TODO: Can probably remove this
    features.printOverview();
    print(features.hourMatrixDaily);
    replyPort.send(features);
  }

  /// Feature Calculation
  Future<FeaturesAggregate> calculateFeatures() async {
    /// Load points, stops and moves via package
    print('Reading points');

    print('Reading pointts');
    List<SingleLocationPoint> points = await _loadLocalPoints();

    /// Downsample to make things easier...
//    points = _downSample(points);
    print('Points going into algorithms: ${points.length}');
    pointsCollectedToday = points.length;

    print('Reading stops');
    List<Stop> stopsLoaded = await _stopSerializer.load();

    print('Reading moves');
    List<Move> movesLoaded = await _moveSerializer.load();

    DateTime today = DateTime.now().midnight;
    DataPreprocessor preprocessor = DataPreprocessor(today);
    DateTime fourWeeksAgo = today.subtract(Duration(days: 28));
    print('Filering out old stops/moves...');

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
    List<Move> movesToday =
        preprocessor.findMoves(points, stopsToday, filter: false);

    /// Get all stop, moves, and places
    List<Stop> stopsAll = stopsOld + stopsToday;
    List<Move> movesAll = movesOld + movesToday;

    print('No. stops: ${stopsAll.length}');
    print('No. moves: ${movesAll.length}');

    print('Calculating new places...');

    List<Place> placesAll = preprocessor.findPlaces(stopsAll);

    /// Extract features
    FeaturesAggregate features =
        FeaturesAggregate(today, stopsAll, placesAll, movesAll);

    /// TODO: Can probably remove this
    features.printOverview();
    print(features.hourMatrixDaily);
    return features;
  }

  Future<void> saveStopsAndMoves(List<Stop> stops, List<Move> moves) async {
    /// Clean up files
    await _stopSerializer.flush();
    await _moveSerializer.flush();

    /// Write updates values
    await _stopSerializer.save(stops);
    await _moveSerializer.save(moves);

    File stopsFile = await util.stopsFile;
    File movesFile = await util.movesFile;

    String urlPoints = await _uploadPoints();
    print(urlPoints);

    String urlStops = await upload(stopsFile, 'stops');
    print(urlStops);

    String urlMoves = await upload(movesFile, 'moves');
    print(urlMoves);
  }

  Future<String> upload(File f, String prefix) async {
    /// Create a folder using the UUID,
    /// if not created, and write to a  file inside it
    String fireBaseFileName = '${uuid}/${prefix}_$uuid.json';
    StorageReference firebaseStorageRef =
        FirebaseStorage.instance.ref().child(fireBaseFileName);
    StorageUploadTask uploadTask = firebaseStorageRef.putFile(f);
    StorageTaskSnapshot downloadUrl = await uploadTask.onComplete;
    String url = await downloadUrl.ref.getDownloadURL();
    return url;
  }
}
