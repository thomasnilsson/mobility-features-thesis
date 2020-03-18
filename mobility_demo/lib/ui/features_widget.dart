import 'package:flutter/material.dart';
import '../mobility.dart';

class FeaturesWidget extends StatelessWidget {
  FeaturesAggregate _features;
  List<String> _content;

  FeaturesWidget(this._features) {
    _content = [];
    if (_features != null) {
      _content.add('home stay: ${_features.homeStay}');
      _content.add('total dist: ${_features.totalDistance}');
      _content.add('clusters : ${_features.numberOfClusters}');
      _content.add('normalized entropy: ${_features.normalizedEntropy}');
      _content.add('routine index (today): ${_features.routineIndex}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _content.isEmpty
        ? Text('No features computed yet!')
        : ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _content.length,
      itemBuilder: (_, index) => Container(
        height: 50,
        child: Text(_content[index].toString()),
      ),
      separatorBuilder: (BuildContext context, int index) =>
      const Divider(),
    );
  }
}
