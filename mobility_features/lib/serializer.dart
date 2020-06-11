part of mobility_features_lib;

class Serializer<E> {
  /// Provide a file reference in order to serialize objects.
  File file;
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
  Future<void> flush() async =>
      await file.writeAsString('', mode: FileMode.write);

  /// Writes a list of [_Serializable] to the file given in the constructor.
  Future<void> save(List<_Serializable> elements) async {
    _debugPrint('Saving to file...');
    String jsonString = "";
    for (_Serializable e in elements) {
      jsonString += json.encode(e._toJson()) + delimiter;
    }
    await file.writeAsString(jsonString, mode: FileMode.writeOnlyAppend);
  }

  /// Reads contents of the file in the constructor,
  /// and maps it to a list of a specific [_Serializable] type.
  Future<List<_Serializable>> load() async {
    /// Read file content as one big string
    String content = await file.readAsString();

    /// Split content into lines by delimiting them
    List<String> lines = content.split(delimiter);

    /// Remove last entry since it is always empty
    /// Then convert each line to JSON, and then to Dart Map<T> objects
    Iterable<Map<String, dynamic>> jsonObjs = lines
        .sublist(0, lines.length - 1)
        .map((e) => json.decode(e))
        .map((e) => Map<String, dynamic>.from(e));

    switch (E) {
      case Move:

        /// Filter out moves which are not recent
        return jsonObjs.map((x) => Move._fromJson(x)).toList();
      case Stop:

        /// Filter out stops which are not recent
        return jsonObjs.map((x) => Stop._fromJson(x)).toList();
      default:

        /// Filter out data points not from today
        return jsonObjs.map((x) => SingleLocationPoint._fromJson(x)).toList();
    }
  }

  void _debugPrint(String s) {
    if (debug) print('Serializer<$E> debug: $s');
  }
}
