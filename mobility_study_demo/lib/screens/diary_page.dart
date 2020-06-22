part of app;

enum SubmitState { NOT_SUBMITTED, UPLOADING, SUBMITTED }

class DiaryPage extends StatefulWidget {
  final String uuid;

  DiaryPage(this.uuid);

  State<StatefulWidget> createState() => new _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  String _defaultAnswer = 'No Answer';
  SubmitState _state = SubmitState.NOT_SUBMITTED;

  Map<String, String> _answers = {
    'datetime': null,
    'places': null,
    'home': null,
    'routine': null,
    'routine_scale': null,
  };

  bool _allAnswersCompleted = false;

  String _routineAnswer() {
    String val = _answers['routine'];
    if (val != null) {
      return val == '0' ? 'No' : 'Yes';
    }
    return _defaultAnswer;
  }

  String _routineScaleAnswer() {
    String val = _answers['routine_scale'];
    if (val != null) {
      return '$val/5';
    }
    return _defaultAnswer;
  }

  String _placesAnswer() {
    String val = _answers['places'];
    if (val != null) {
      return val == '1'  ? '$val place' : '$val places';
    }
    return _defaultAnswer;
  }

  String _homeAnswer() {
    String val = _answers['home'];
    if (val != null) {
      return val == '1'  ? '$val hour' : '$val hours';
    }
    return _defaultAnswer;
  }

  void checkAllAnswers() {
    setState(() {
      _allAnswersCompleted = _answers['places'] != null &&
          _answers['home'] != null &&
          _answers['routine'] != null &&
          _answers['routine_scale'] != null;
    });
  }

  void routineScalePicker(BuildContext context) {
    new Picker(
        adapter: NumberPickerAdapter(data: [
          NumberPickerColumn(begin: 0, end: 5),
        ]),
        hideHeader: true,
        title: new Text("Select an answer"),
        onConfirm: (Picker picker, List value) {
          setState(() {
            _answers['routine_scale'] = value.first.toString();
            checkAllAnswers();
          });
        }).showDialog(context);
  }

  void routinePicker(BuildContext context) {
    new Picker(
        adapter: PickerDataAdapter(data: [
          PickerItem(text: Text('No')),
          PickerItem(text: Text('Yes'))
        ]),
        hideHeader: true,
        title: new Text("Select an answer"),
        onConfirm: (Picker picker, List value) {
          setState(() {
            _answers['routine'] = value.first.toString();
            checkAllAnswers();
          });
        }).showDialog(context);
  }

  void placePicker(BuildContext context) {
    new Picker(
        adapter: NumberPickerAdapter(data: [
          NumberPickerColumn(begin: 1, end: 30),
        ]),
        hideHeader: true,
        title: new Text("Select an answer"),
        onConfirm: (Picker picker, List value) {
          setState(() {
            _answers['places'] = (value.first + 1).toString();
            checkAllAnswers();
          });
        }).showDialog(context);
  }

  void homeStayPicker(BuildContext context) {
    new Picker(
        adapter: NumberPickerAdapter(data: [
          NumberPickerColumn(begin: 0, end: 24),
        ]),
        hideHeader: true,
        title: new Text("Select an answer"),
        onConfirm: (Picker picker, List value) {
          setState(() {
            _answers['home'] = value.first.toString();
            checkAllAnswers();
          });
        }).showDialog(context);
  }

  Widget paddedContainer(Widget child) {
    return Container(padding: EdgeInsets.all(20), child: child);
  }

  Widget questionPlaces() {
    return paddedContainer(Column(children: <Widget>[
      Text('How many unique places (including home) did you stay at today?', style: mediumText),
      Text(_placesAnswer(), style: bigText),
      FlatButton(
        color: Colors.blue,
        child: Text('Pick an answer'),
        textColor: Colors.white,
        onPressed: () => placePicker(context),
      )
    ]));
  }

  Widget questionHomeStay(BuildContext context) {
    return paddedContainer(Column(
      children: <Widget>[
        Text('How many hours did you spend away from home today? (Rounded-up)',
            style: mediumText),
        Text(
          _homeAnswer(),
          style: bigText,
        ),
        FlatButton(
          color: Colors.blue,
          child: Text('Pick an answer'),
          textColor: Colors.white,
          onPressed: () => homeStayPicker(context),
        )
      ],
    ));
  }

  Widget questionRoutine(BuildContext context) {
    return paddedContainer(Column(
      children: <Widget>[
        Text(
            "Did you spend time at places today that you don't normally visit?",
            style: mediumText),
        Text(_routineAnswer(), style: bigText),
        FlatButton(
          color: Colors.blue,
          child: Text('Pick an answer'),
          textColor: Colors.white,
          onPressed: () => routinePicker(context),
        ),
      ],
    ));
  }

  Widget questionRoutineScale(BuildContext context) {
    return paddedContainer(Column(
      children: <Widget>[
        Text(
            "On a scale of 0-5, how much did today look like the previous, recent days? (Where 0 means 'not at all' little and 5 means 'Exactly the same')",
            style: mediumText),
        Text(_routineScaleAnswer(), style: bigText),
        FlatButton(
          color: Colors.blue,
          child: Text('Pick an answer'),
          textColor: Colors.white,
          onPressed: () => routineScalePicker(context),
        ),
      ],
    ));
  }

  Widget submitButton() {
    return Container(
        width: 200,
        height: 60,
        margin: EdgeInsets.all(20),
        child: RaisedButton(
          onPressed: _allAnswersCompleted ? _saveAnswers : null,
          child: Text(
            'Submit',
            style: mediumText,
          ),
        ));
  }

  Future<void> _saveAnswers() async {
    _answers['datetime'] = DateTime.now().toIso8601String();
    print('*' * 50);
    print(_answers);
    print('*' * 50);
    print('Saving answers on device...');

    setState(() {
      _state = SubmitState.UPLOADING;
    });

    await FileManager().saveAnswers(_answers);
    print('Uploading answers to firebase...');
    await FileManager().uploadAnswers(widget.uuid);
    print('Done');
    setState(() {
      _state = SubmitState.SUBMITTED;
    });
  }

  Widget _questionsView(BuildContext context) {
    return ListView(
      children: [
        questionPlaces(),
        Divider(
          height: 20,
          thickness: 1,
        ),
        questionHomeStay(context),
        Divider(
          height: 20,
          thickness: 1,
        ),
        questionRoutine(context),
        Divider(
          height: 20,
          thickness: 1,
        ),
        questionRoutineScale(context),
        Divider(
          height: 20,
          thickness: 1,
        ),
        submitButton()
      ],
    );
  }

  Widget _submittedView() {
    return paddedContainer(
      Text(
          'Thank you for reporting today! 🎉\n\nPlease go back to the main screen and keep the app running in the background.',
          style: mediumText),
    );
  }

  Widget _uploadingView() {
    return Container(
        margin: EdgeInsets.all(25),
        child: Column(children: [
          Text(
            'Uploading answers...',
            style: TextStyle(fontSize: 20),
          ),
          Container(
              margin: EdgeInsets.only(top: 50),
              child: Center(child: CircularProgressIndicator(strokeWidth: 10)))
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text('Diary'),
        ),

        /// Check state and render a view accordingly
        body: _state == SubmitState.SUBMITTED
            ? _submittedView()
            : _state == SubmitState.UPLOADING
                ? _uploadingView()
                : _questionsView(context));
  }
}
