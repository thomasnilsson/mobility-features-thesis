part of app;

class QuestionPage extends StatefulWidget {
  final String uuid;

  QuestionPage(this.uuid);

  State<StatefulWidget> createState() => new _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage> {
  final _formKey = GlobalKey<FormState>();
  String _defaultAnswer = 'No Answer';

  Map<String, String> _answers = {
    'datetime': null,
    'places': null,
    'home': null,
    'routine': null,
  };

  bool _submitted = false;
  bool _allAnswersCompleted = false;

  String _routineAnswer() {
    String val = _answers['routine'];
    if (val != null) {
      return val == '0' ? 'No' : 'Yes';
    }
    return _defaultAnswer;
  }

  String _placesAnswer() {
    String val = _answers['places'];
    if (val != null) {
      return '$val places';
    }
    return _defaultAnswer;
  }

  String _homeAnswer() {
    String val = _answers['home'];
    if (val != null) {
      return '$val hours';
    }
    return _defaultAnswer;
  }

  void checkAllAnswers() {
    setState(() {
      _allAnswersCompleted = _answers['places'] != null &&
          _answers['home'] != null &&
          _answers['routine'] != null;
    });
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
          NumberPickerColumn(begin: 0, end: 10),
        ]),
        hideHeader: true,
        title: new Text("Select an answer"),
        onConfirm: (Picker picker, List value) {
          setState(() {
            _answers['places'] = value.first.toString();
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
      Text('How many unique places did you visit today?', style: mediumText),
      Text(_placesAnswer(), style: bigText),
      FlatButton(
        color: Colors.green,
        child: Text('Pick an answer'),
        textColor: Colors.white,
        onPressed: () => placePicker(context),
      )
    ]));
  }

  Widget questionHomeStay(BuildContext context) {
    return paddedContainer(Column(
      children: <Widget>[
        Text('How many hours did you spend away from home today?',
            style: mediumText),
        Text(
          _homeAnswer(),
          style: bigText,
        ),
        FlatButton(
          color: Colors.green,
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
        Text("Did you spend time at places you normally don't visit?",
            style: mediumText),
        Text(_routineAnswer(), style: bigText),
        FlatButton(
          color: Colors.green,
          child: Text('Pick an answer'),
          textColor: Colors.white,
          onPressed: () => routinePicker(context),
        ),
      ],
    ));
  }

  Widget submitButton() {
    return Container(
        width: 200,
        height: 60,
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
    await FileUtil().saveAnswers(_answers);
    print('Uploading answers to firebase...');
    await FileUtil().uploadAnswers(widget.uuid);
    print('Done');
    setState(() {
      _submitted = true;
    });
  }

  Widget getForm(BuildContext context) {
    return Form(
        key: _formKey,
        child: Center(
            child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
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
              submitButton()
            ],
          ),
        )));
  }

  Widget thankYou() {
    return paddedContainer(
      Text(
          'Thank you for reporting today! 🎉\n\nPlease go back to the main screen and keep the app running in the background.',
          style: mediumText),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: new Text('Daily Report'),
        ),
        body: _submitted ? thankYou() : getForm(context));
  }
}
