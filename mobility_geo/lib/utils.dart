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

  Future<File> write(Map<String, String> d) async {
    File contentsFile = await locationDataFile;
    // Write the file.
    contentsFile.writeAsString('${json.encode(d)}\n', mode: FileMode.append);
    return contentsFile;
  }

  Map<String, String> decode(String s) {
    try {
      Map<String, String> res = Map<String, String>.from(json.decode(s));
      return res;
    } catch (e) {
      return {};
    }
  }

  Future<List<Map<String, String>>> read() async {
    List<Map<String, String>> maps = [];
    final file = await locationDataFile;

    await file.readAsString().then((String contents) {
      List<String> tokens = contents.split('\n');
      print('Tokens length: ${tokens.length}');

      for (String x in tokens) {
        Map<String, String> m = decode(x);
        if (m.isNotEmpty) maps.add(m);
      }

      print('Maps length: ${maps.length}');
    });
    return maps;
  }
}
