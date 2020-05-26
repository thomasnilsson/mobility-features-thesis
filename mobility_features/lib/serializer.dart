part of mobility_features_lib;

class Serializer<E> {
  /// Provide a file reference in order to serialize objects.
  File file;
  int dayWindow;
  String delimiter = '\n';
  bool debug;

  Serializer(this.file, {this.debug = false}) {
    _debugPrint('Initializing Serializer for ${file.path}');
    bool exists = file.existsSync();
    if (!exists) {
      flush();
    }
  }

  /// Deletes the content of the file
  Future<void> flush() async {
    await file.writeAsString('', mode: FileMode.write);
    _debugPrint('Flushed file!');
  }

  /// Writes a list of [Serializable] to the file given in the constructor.
  Future<void> save(List<Serializable> elements) async {
    _debugPrint('Saving to file...');
    String jsonString = "";
    for (Serializable e in elements) {
      jsonString += json.encode(e.toJson()) + delimiter;
    }
    await file.writeAsString(jsonString, mode: FileMode.writeOnlyAppend);
  }

  /// Reads contents of the file in the constructor,
  /// and maps it to a list of a specific [Serializable] type.
  Future<List<Serializable>> load() async {
    /// Read file content as one big string
    String content = await file.readAsString();

    /// Split content into lines by delimiting them
    List<String> lines = content.split(delimiter);

    /// Remove last entry since it is always empty
    /// Then convert each line to JSON, and then to Dart Map<T> objects
    Iterable<Map<String, dynamic>> maps = lines
        .sublist(0, lines.length - 1)
        .map((e) => json.decode(e))
        .map((e) => Map<String, dynamic>.from(e));

    switch (E) {
      case Move:

      /// Filter out moves which are not recent
        return maps
            .map((x) => Move.fromJson(x))
            .toList();
      case Stop:

      /// Filter out stops which are not recent
        return maps
            .map((x) => Stop.fromJson(x))
            .toList();
      default:

      /// Filter out data points not from today
        return maps
            .map((x) => SingleLocationPoint.fromJson(x))
            .toList();
    }
  }

  void _debugPrint(String s) {
    if (debug) print('Serializer<$E> debug: $s');
  }

}