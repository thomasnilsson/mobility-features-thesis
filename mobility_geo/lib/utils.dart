part of mobility;

class FileUtil {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get locationDataFile async {
    final path = await _localPath;
    String time = DateTime.now().toString();
    String fileName = '$path/location_data.json';
    return File(fileName);
  }

  Future<File> get _counterFile async {
    final path = await _localPath;
    String transferredFile = '$path/counter_file.txt';
    return File(transferredFile);
  }

  Future<File> write(Map<String, String> d, int counter) async {
    File contentsFile = await locationDataFile;
    File counterFile = await _counterFile;
    // Write the file.
    contentsFile.writeAsString('${json.encode(d)}\n', mode: FileMode.append);
    counterFile.writeAsString('$counter');
    return contentsFile;
  }

  Future<int> readCounter() async {
    try {
      final file = await _counterFile;

      // Read the file.
      String contents = await file.readAsString();
      int counter = int.parse(contents);
      return counter;

    } catch (e) {
      // If encountering an error, return 0.
      return 0;
    }
  }


  Future<List<String>> read() async {
    try {
      final file = await locationDataFile;

      // Read the file.
      String contents = await file.readAsString();
      List<String> tokens = contents.split('\n');
      return tokens.sublist(0, tokens.length - 1);
    } catch (e) {
      // If encountering an error, return 0.
      return [];
    }
  }
}

extension BetterLocationData on Position {
  String get str => '(${this.toString()}} - ${this.timestamp})';
}
