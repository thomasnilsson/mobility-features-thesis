part of app;

String formatDate(DateTime date) => new DateFormat("MMMM dd yyyy").format(date);

enum AppState { NO_FEATURES, CALCULATING_FEATURES, FEATURES_READY }

class FileManager {
  Future<File> _file(String type) async {
    String path = (await getApplicationDocumentsDirectory()).path;
    return new File('$path/$type.json');
  }

  Future<File> get samplesFile async => await _file('locations');

  Future<File> get stopsFile async => await _file('stops');

  Future<File> get movesFile async => await _file('moves');

  Future<File> get answersFile async => await _file('answers');

  Future<File> get featuresFile async => await _file('features');

  Future<void> saveFeatures(MobilityContext mc) async {
    File file = await featuresFile;
    String jsonString = json.encode(mc.toJson()) + '\n';
    await file.writeAsString(jsonString, mode: FileMode.writeOnlyAppend);
  }

  Future<void> saveAnswers(Map<String, String> answers) async {
    File file = await answersFile;
    String jsonString = json.encode(answers) + '\n';
    await file.writeAsString(jsonString, mode: FileMode.writeOnlyAppend);
  }

  Future<String> loadUUID() async {
    String uuid;
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
    return uuid;
  }


  Future<String> uploadMoves(String uuid) async {
    return await _upload(await movesFile, uuid, 'moves');
  }

  Future<String> uploadStops(String uuid) async {
    return await _upload(await stopsFile, uuid, 'stops');
  }

  Future<String> uploadSamples(String uuid) async {
    /// Save to firebase. Date is added to the points file name in firebase
    File pointsFile = await FileManager().samplesFile;
    String dateString =
        '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    String urlPoints = await _upload(pointsFile, uuid, 'points-$dateString');
    return urlPoints;
  }

  Future<String> uploadAnswers(String uuid) async {
    return await _upload(await answersFile, uuid, 'answers');
  }

  Future<String> uploadFeatures(String uuid) async {
    return await _upload(await featuresFile, uuid, 'features');
  }

  Future<String> _upload(File f, String uuid, String prefix) async {
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

  Future<Iterable<Map<String, dynamic>>> _loadFromAssets(String path) async {
    String delimiter = '\n';
    String content = await rootBundle.loadString(path);
    print(content);

    /// Split content into lines by delimiting them
    List<String> lines = content.split(delimiter);

    print('lines length ${lines.length}');
    Iterable<Map<String, dynamic>> maps = lines
        .sublist(0, lines.length - 1)
        .map((e) => json.decode(e))
        .map((e) => Map<String, dynamic>.from(e));

    return maps;
  }

  void printList(List l) {
    for (int i = 0; i < l.length; i++) {
      print('[$i] ${l[i]}');
    }
    print('-' * 50);
  }
}
