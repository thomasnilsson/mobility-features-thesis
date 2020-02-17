part of mobility_features_test_lib;

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
    List<Map<String, String>> maps = [];
    final file = await await new File(path);

    await file.readAsString().then((String contents) {
      List<String> tokens = contents.split('\n');
      print('Tokens length: ${tokens.length}');

      for (String x in tokens) {
        Map<String, String> m = decode(x);
        if (m.isNotEmpty) {
          maps.add(m);
          data.add(SingleLocationPoint.fromJson(m));
        }
      }

      print('Maps length: ${maps.length}');
    });
    return data;
  }

  Future<List<SingleLocationPoint>> get exampleData async =>
      await _readJsonFromFile('test/data/example-multi.json');
}
