import 'package:flutter/material.dart';
import '../mobility.dart';

class DataWidget extends StatelessWidget {
  List<SingleLocationPoint> _content, _subset = [];

  DataWidget(this._content) {
    if (_content.isNotEmpty) {
      _subset = _content.reversed.toList().sublist(0, 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _subset.isEmpty
        ? Text('No data yet...')
        : ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: _subset.length,
            itemBuilder: (_, index) => Container(
              height: 50,
              child: Text(_subset[index].toString()),
            ),
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(),
          );
  }
}

class _DataWidgetState extends State<StateFulDataWidget> {
  List<SingleLocationPoint> _content, _subset;

  _DataWidgetState(this._content) {
    if (_content.isNotEmpty) {
      _subset = _content.reversed.toList().sublist(0, 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _subset.isEmpty
        ? Text('No data yet...')
        : ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: _subset.length,
            itemBuilder: (_, index) => Container(
              height: 50,
              child: Text(_subset[index].toString()),
            ),
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(),
          );
  }
}

class StateFulDataWidget extends StatefulWidget {
  List<SingleLocationPoint> content;

  StateFulDataWidget({Key key, this.content}) : super(key: key);

  @override
  _DataWidgetState createState() => _DataWidgetState(content);
}
