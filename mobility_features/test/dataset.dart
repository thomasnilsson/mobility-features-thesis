part of mobility_features_test_lib;

class Dataset {
  Future<List<LocationData>> _readJsonFromFile(String path) async {
    /// Read file contents, without assuming type
    Map<dynamic, dynamic> fileContents = await new File(path)
        .readAsString()
        .then((fileContents) => json.decode(fileContents));

    /// Cast as Map with String keys
    Map<String, dynamic> x = Map<String, dynamic>.from(fileContents);

    /// Convert to LocationData List
    return x.keys.map((k) => LocationData.fromJson(x[k])).toList();
  }

  Future<List<LocationData>> get multiDateData async =>
      await _readJsonFromFile('test/data/multi_date_data.json');

  Future<List<LocationData>> get singleDateData async =>
      await _readJsonFromFile('test/data/single_date_data.json');


}
