part of mobility;

String formatDate(DateTime date) => new DateFormat("MMMM dd yyyy").format(date);

class FileUtil {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get locationDataFile async {
    final path = await _localPath;
    print('Local path: ${path}');
    String fileName = '$path/location_data.json';
    return File(fileName);
  }

  Future<File> writeSingleLocationPoint(SingleLocationPoint p) async {
    File contentsFile = await locationDataFile;
    String content = '${json.encode(p.toJson())}\n';
    contentsFile.writeAsString(content, mode: FileMode.append);
    return contentsFile;
  }

  Future<List<SingleLocationPoint>> readLocationData() async {
    List<SingleLocationPoint> points = [];
    final file = await locationDataFile;

    await file.readAsString().then((String contents) {
      List<String> tokens = contents.split('\n');
      tokens.removeLast(); // last element is the empty string, so we remove it

      for (String t in tokens) {
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
