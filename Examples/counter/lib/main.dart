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
  static const initChannel = MethodChannel('com.example.counter.init');

  bool counterEnabled = false;
  bool nativeInitialized = false;
  int currentCounter = 0;

  @override
  void initState() {
    super.initState();
    _setupInitializationHandler();
  }

  void _setupInitializationHandler() {
    print('Setting up initialization handler for com.example.counter.init');
    initChannel.setMethodCallHandler((call) async {
      print('Received method call: ${call.method} with arguments: ${call.arguments}');
      if (call.method == 'nativeInitialized') {
        print('Native side initialized, updating state');
        setState(() {
          nativeInitialized = true;
        });
        // Native side is ready, StreamBuilder can now safely subscribe
      }
    });
  }

  Stream<int> get getCounterStream {
    if (!nativeInitialized) {
      return Stream.empty();
    }
    return stream.receiveBroadcastStream().cast<int>();
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
          Text('Native initialized: $nativeInitialized'),
          ElevatedButton(onPressed: toggleCounter, child: const Text('Start/Stop')),
          if (nativeInitialized)
            StreamBuilder<int>(
              stream: getCounterStream,
              builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                if(snapshot.hasData) {
                  counterEnabled = snapshot.hasData;
                  currentCounter = snapshot.data!;
                  return Text("Current counter: ${snapshot.data}");
                } else if (snapshot.hasError) {
                  return Text("Stream error: ${snapshot.error}");
                } else {
                  return Text("Press button to start counter");
                }
              },
            )
          else
            Text("Waiting for native initialization..."),
          if (counterEnabled) Text('Counter active') else CircularProgressIndicator()
        ],
      ),
    );
  }
}
