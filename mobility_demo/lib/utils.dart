part of mobility;

class FileUtil {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get locationDataFile async {
    final path = await _localPath;
    print('Local path: ${path}');
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

  Future<void> flush() async {
    File contentsFile = await locationDataFile;
    // Write the file.
    contentsFile.writeAsString('', mode: FileMode.write, flush: true);
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

  Future<File> writeSingleLocationPoint(SingleLocationPoint p) async {
    File contentsFile = await locationDataFile;
    // Write the file.
    String content = '${json.encode(p.toJson())}\n';
    print('Content: $content');
    contentsFile.writeAsString(content, mode: FileMode.append);
    return contentsFile;
  }

  Future<List<SingleLocationPoint>> readLocationData() async {
    List<SingleLocationPoint> points = [];
    final file = await locationDataFile;

    await file.readAsString().then((String contents) {
      List<String> tokens = contents.split('\n');
      tokens.removeLast(); // last element is the empty string
      print('Tokens length: ${tokens.length}');

      for (String t in tokens) {
//        var enc = json.encode(t);
//        var dec1 = json.decode(enc);
        var dec2 = json.decode(t);
        SingleLocationPoint p = SingleLocationPoint.fromJson(dec2);
        points.add(p);
      }
    });
    return points;
  }

  void printList(List l) {
    for (int i = 0; i < l.length; i++) {
      print('[$i] ${l[i]}');
    }

    print('-' * 50);
  }
}
