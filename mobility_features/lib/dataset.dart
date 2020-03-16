part of mobility_features_lib;

class Dataset {
  Map<String, String> decode(String s) {
    try {
      Map<String, String> res = Map<String, String>.from(json.decode(s));
      return res;
    } catch (e) {
      return {};
    }
  }

  Future<List<SingleLocationPoint>> _readJsonFromFile(String path) async {
    List<SingleLocationPoint> data = [];
    final file = new File(path);

    await file.readAsString().then((String contents) {
      List<String> tokens = contents.split('\n');
      for (String x in tokens) {
        Map<String, String> m = decode(x);
        if (m.isNotEmpty) {
          data.add(SingleLocationPoint.fromMap(m));
        }
      }
    });
    return data;
  }

  List<SingleLocationPoint> parseJson(String contents) {
    List<SingleLocationPoint> data = [];
    List<String> tokens = contents.split('\n');
    for (String x in tokens) {
      Map<String, String> m = decode(x);
      if (m.isNotEmpty) {
        data.add(SingleLocationPoint.fromMap(m));
      }
    }
    return data;
  }

  Future<List<SingleLocationPoint>> loadDataset(String path) async =>
      await _readJsonFromFile(path);
}
