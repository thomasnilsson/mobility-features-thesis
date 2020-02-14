part of mobility_features_test_lib;

class Dataset {
  Future<List<SingleLocationPoint>> _readJsonFromFile(String path) async {
    /// Read file contents, without assuming type
    Map<dynamic, dynamic> fileContents = await new File(path)
        .readAsString()
        .then((fileContents) => json.decode(fileContents));

    /// Cast as Map with String keys
    Map<String, dynamic> jsonData = Map<String, dynamic>.from(fileContents);

    /// Convert to LocationData List
    return jsonData.keys.map((k) => SingleLocationPoint.fromJson(jsonData[k], hourOffset: -1)).toList();
  }

  Future<List<SingleLocationPoint>> get multiDateData async =>
      await _readJsonFromFile('test/data/multi_date_data.json');

  Future<List<SingleLocationPoint>> get singleDateData async =>
      await _readJsonFromFile('test/data/single_date_data.json');

}
