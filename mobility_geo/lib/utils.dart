part of mobility;

class FileUtil {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _file async {
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
    File contentsFile = await _file;
    File counterFile = await _counterFile;
    // Write the file.
    contentsFile.writeAsString('${json.encode(d)}\n', mode: FileMode.append);
    counterFile.writeAsString('$counter');
    print('wrote contents to file');
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
      final file = await _file;

      // Read the file.
      String contents = await file.readAsString();

      return contents.split('\n');
    } catch (e) {
      // If encountering an error, return 0.
      return [];
    }
  }
}

extension BetterLocationData on Position {
  String get str => '(${this.toString()}} - ${this.timestamp})';
}
