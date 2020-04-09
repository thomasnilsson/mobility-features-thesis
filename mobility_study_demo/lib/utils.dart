part of mobility;

String formatDate(DateTime date) => new DateFormat("MMMM dd yyyy").format(date);

enum AppState {
  NO_FEATURES, CALCULATING_FEATURES, FEATURES_READY
}

class FileUtil {
  Future<File> _file(String type) async {
    String path = (await getApplicationDocumentsDirectory()).path;
    return new File('$path/$type.json');
  }

  Future<File> get pointsFile async => await _file('locations');

  Future<File> get stopsFile async => await _file('stops');

  Future<File> get movesFile async => await _file('moves');

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

  Future<List<Stop>> loadStopsFromAssets() async {
    final maps = await _loadFromAssets('data/all_stops.json');
    return maps.map((x) => Stop.fromJson(x)).toList();
  }

  Future<List<Move>> loadMovesFromAssets() async {
    final maps = await _loadFromAssets('data/all_moves.json');
    return maps.map((x) => Move.fromJson(x)).toList();
  }

  void printList(List l) {
    for (int i = 0; i < l.length; i++) {
      print('[$i] ${l[i]}');
    }
    print('-' * 50);
  }
}
