part of app;

class InfoPage extends StatelessWidget {
  InfoPage();

  @override
  Widget build(BuildContext context) {
    print('*' * 50);
    print('Check');
    print('*' * 50);

    return Scaffold(
      appBar: AppBar(
        title: Text("Info Page"),
      ),
      body: Container(
          padding: EdgeInsets.all(20),
          child: infoText),
    );
  }
}
