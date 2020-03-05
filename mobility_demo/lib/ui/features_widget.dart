import 'package:flutter/material.dart';
import '../mobility.dart';

class FeaturesWidget extends StatelessWidget {
  Features _f;
  List<String> _content;

  FeaturesWidget(this._f) {
    _content = [];
    if (_f != null) {
      _content.add('homeStayDaily: ${_f.homeStayDaily}');
      _content.add('locationVarianceDaily: ${_f.locationVarianceDaily}');
      _content.add('totalDistanceDaily: ${_f.totalDistanceDaily}');
      _content.add('numberOfClustersDaily: ${_f.numberOfClustersDaily}');
      _content.add('normalizedEntropyDaily: ${_f.normalizedEntropyDaily}');
      _content.add('routineIndex: ${_f.routineIndex}');
      _content.add('-' * 50);

      for (var x in _f.stopsOnDate) {
        _content.add(x.toString());
      }
      for (var x in _f.places) {
        _content.add(x.toString());
      }
      for (var x in _f.movesOnDate) {
        _content.add(x.toString());
      }
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

class _FeatureWidgetState extends State<StateFulFeatureWidget> {
  Features _f;
  List<String> _content;

  _FeatureWidgetState(this._f) {
    _content = [];
    if (_f != null) {
      _content.add('homeStayDaily: ${_f.homeStayDaily}');
      _content.add('locationVarianceDaily: ${_f.locationVarianceDaily}');
      _content.add('totalDistanceDaily: ${_f.totalDistanceDaily}');
      _content.add('numberOfClustersDaily: ${_f.numberOfClustersDaily}');
      _content.add('normalizedEntropyDaily: ${_f.normalizedEntropyDaily}');
      _content.add('routineIndex: ${_f.routineIndexOld}');
      _content.add('-' * 50);

      for (var x in _f.stopsOnDate) {
        _content.add(x.toString());
      }
      for (var x in _f.places) {
        _content.add(x.toString());
      }
      for (var x in _f.movesOnDate) {
        _content.add(x.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _content.isEmpty
        ? Text('No features computed yet. Press the update button to calculate features.')
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

class StateFulFeatureWidget extends StatefulWidget {
  Features f;

  StateFulFeatureWidget({Key key, this.f}) : super(key: key);

  @override
  _FeatureWidgetState createState() => _FeatureWidgetState(f);
}
