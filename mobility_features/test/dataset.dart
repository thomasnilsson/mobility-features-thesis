part of mobility_features_test_lib;

class Dataset {
  Future<List<SingleLocationPoint>> _readJsonFromFile(String path) async {
    /// Read file contents, without assuming type
    Future<List<SingleLocationPoint>> xxx = await new File(path)
        .readAsString()
        .then((content) => content.split('\n').map((s) {
              var map = json.decode(s);
              return SingleLocationPoint.fromJson(map);
            }));

    /// Cast as Map with String keys
    Map<String, dynamic> jsonData = Map<String, dynamic>.from(fileContents);

    /// Convert to LocationData List
    return jsonData.keys
        .map((k) => SingleLocationPoint.fromJson(jsonData[k], hourOffset: -1))
        .toList();
  }

  Future<List<SingleLocationPoint>> get exampleData async =>
      await _readJsonFromFile('test/data/example-multi.json');
}
