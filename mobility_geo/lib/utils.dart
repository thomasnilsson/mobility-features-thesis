part of mobility;

class FileUtil {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _file async {
    final path = await _localPath;
    String time = DateTime.now().toString();
    String fileName = '$path/location_data.txt';
    return File(fileName);
  }

  Future<File> flush() async {
    File file = await _file;
    return file.writeAsString('', mode: FileMode.write);
  }

  Future<File> write(Position d) async {
    File file = await _file;
    // Write the file.
    file.writeAsString('${d.str}\n', mode: FileMode.append);
    print('wrote contents to file');
    return file;
  }

  Future<String> read() async {
    try {
      final file = await _file;

      // Read the file.
      String contents = await file.readAsString();

      return contents;
    } catch (e) {
      // If encountering an error, return 0.
      return '<empty>';
    }
  }
}

extension BetterLocationData on Position {
  String get str => '(${this.toString()}} - ${this.timestamp})';
}
