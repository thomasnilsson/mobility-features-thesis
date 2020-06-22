part of app;

class AppProcessor {
  static const int BUFFER_SIZE = 100;
  FileManager util = FileManager();
  Geolocator _geoLocator = Geolocator();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  String uuid;
  MobilitySerializer<LocationSample> _sampleSerializer;
  List<LocationSample> _buffer = [];

  bool streamingLocation = false;
  StreamSubscription<Position> _subscription;
  int numberOfBuffers = 0;

  Future initialize() async {
    await _loadUUID();
    await _initLocation();
  }

  Future restart() async {
    print('Restarting...');
    if (_subscription != null) {
      _subscription.cancel();
    }

    await _initLocation();
  }

  Future _initNotificationService() async {
    await _firebaseMessaging.requestNotificationPermissions();
    _firebaseMessaging.configure(onMessage: _onMessage);
  }

  Future<dynamic> _onMessage(Map<String, dynamic> message) async {
    print(message);
    return message;
  }

  Future _initLocation() async {
    /// Set a minimum dist of such that we dont track every little move
    /// This is necessary if user is very stationary however, being in bed wont count!
    LocationOptions options = LocationOptions(distanceFilter: 0);
    await _geoLocator.isLocationServiceEnabled().then((response) {
      if (response) {
        streamingLocation = true;
        _subscription = _geoLocator.getPositionStream(options).listen(_onData);
      } else {
        print('Location service not enabled');
      }
    });
  }

  Future<void> _loadUUID() async {
    uuid = await FileManager().loadUUID();
  }

  void _onData(Position d) async {
    LocationSample sample =
        LocationSample(GeoPosition(d.latitude, d.longitude), d.timestamp);
    _buffer.add(sample);

    print('New location point: $sample');

    /// If buffer has reached max capacity, write to file and empty the buffer
    /// This is to avoid constantly reading and writing from file each time a new
    /// point comes in.
    if (_buffer.length >= BUFFER_SIZE) {
      /// Save buffer locally, empty it, and then upload the points file to firebase
      await _sampleSerializer.save(_buffer);
      _buffer = [];
      String urlPoints = await FileManager().uploadSamples(uuid);
      print(urlPoints);

      /// If enough data has been collected, evaluate features
      numberOfBuffers++;
      if (numberOfBuffers >= 5) {
        numberOfBuffers = 0;

        /// Off load to background, i.e. do not AWAIT
        saveAndUpload();
      }
    }
  }

  Future<void> saveAndUpload() async {
    /// Calculate features, then store stops, move and features
    MobilityContext mobilityContext = await _computeFeaturesAsync();

    await _saveOnDevice(mobilityContext);

    String urlFeatures = await FileManager().uploadFeatures(uuid);
    print(urlFeatures);

    String urlSamples = await FileManager().uploadSamples(uuid);
    print(urlSamples);

    String urlStops = await FileManager().uploadStops(uuid);
    print(urlStops);

    String urlMoves = await FileManager().uploadMoves(uuid);
    print(urlMoves);

    print('Saved features');
  }

  Future<void> _saveOnDevice(MobilityContext mc) async {

    await FileManager().saveFeatures(mc);

  }

  Future<MobilityContext> _computeFeaturesAsync() async {
    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(_asyncComputation, receivePort.sendPort);
    SendPort sendPort = await receivePort.first;

    MobilityContext mobilityContext = await _relay(sendPort);
    return mobilityContext;
  }

  Future _relay(SendPort sendPort) {
    ReceivePort receivePort = ReceivePort();
    sendPort.send([receivePort.sendPort]);
    return receivePort.first;
  }

  static void _asyncComputation(SendPort sendPort) async {
    ReceivePort receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);
    List args = await receivePort.first;
    SendPort replyPort = args[0];

    MobilityContext context =
        await ContextGenerator.generate(usePriorContexts: true);

    replyPort.send(context);
  }
}
