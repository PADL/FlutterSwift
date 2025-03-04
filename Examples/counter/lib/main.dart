import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  debugProfilePlatformChannels = true;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Counter'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const message = BasicMessageChannel<dynamic>('com.example.counter.basic', JSONMessageCodec());
  static const platform = MethodChannel('com.example.counter.toggle');
  static const stream = EventChannel('com.example.counter.events');

  bool counterEnabled = false;

  static Stream<int> get getCounterStream {
    return stream.receiveBroadcastStream().cast();
  }

  toggleCounter() async {
    final dynamic reply = await message.send('Hello, world');
    try {
      await platform.invokeMethod('toggle', reply);
    } on PlatformException catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          ElevatedButton(onPressed: toggleCounter, child: const Text('Start/Stop')),
          StreamBuilder<int>(
            stream: getCounterStream,
            builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
              counterEnabled = snapshot.hasData;
              if(snapshot.hasData) {
                return Text("Current counter: ${snapshot.data}");
              } else {
                return Text("Waiting for new random number...");
              }
            },
          ),
          if (counterEnabled) Text('') else CircularProgressIndicator()
        ],
      ),
    );
  }
}
