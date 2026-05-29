import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:learning_app/screens/splash_screen.dart';

import 'services/auth_services.dart';
import 'services/local_storage_service.dart';
import 'services/tflite_model_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LocalStorageService.initialize();
  await AuthService.initialize();
  
  // Initialize TFLite models in background (non-blocking)
  TfliteModelService.initialize().then((success) {
    if (success) {
      debugPrint('✅ AI Models initialized successfully');
    } else {
      debugPrint('ℹ️ AI Models not available, using local NLP fallback');
    }
  });
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of  application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Learning App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Dyslexia-friendly, calm, professional color scheme
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF4A6FA5), // Calm blue
          secondary: const Color(0xFF4CAF50), // Calm green
          surface: const Color(0xFFFFFBF5), // Warm white
          background: const Color(0xFFF5F5F0), // Soft cream
          error: const Color(0xFFE74C3C), // Soft red
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: const Color(0xFF2D3748), // Dark text
          onBackground: const Color(0xFF2D3748),
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F0), // Calm background
        fontFamily: 'Lexend', // Default font for all text
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
            letterSpacing: 1.0,
          ),
          displayMedium: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
            letterSpacing: 1.0,
          ),
          displaySmall: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
            letterSpacing: 1.0,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
            letterSpacing: 1.0,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
            letterSpacing: 1.0,
          ),
          headlineSmall: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
            letterSpacing: 1.0,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
            letterSpacing: 1.0,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
            letterSpacing: 0.5,
          ),
          titleSmall: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
            letterSpacing: 0.5,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 20,
            color: Color(0xFF2D3748),
            letterSpacing: 0.5,
            height: 1.6,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 18,
            color: Color(0xFF2D3748),
            letterSpacing: 0.5,
            height: 1.6,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 16,
            color: Color(0xFF2D3748),
            letterSpacing: 0.5,
            height: 1.5,
          ),
          labelLarge: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
            letterSpacing: 1.0,
          ),
          labelMedium: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
            letterSpacing: 0.5,
          ),
          labelSmall: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
            letterSpacing: 0.5,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F5F0),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF2D3748)),
          titleTextStyle: TextStyle(
            fontFamily: 'Lexend',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
            letterSpacing: 1.0,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontFamily: 'Lexend',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4A6FA5),
            textStyle: const TextStyle(
              fontFamily: 'Lexend',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 3),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF81C784), width: 2),
          ),
          labelStyle: const TextStyle(
            fontFamily: 'Lexend',
            fontSize: 18,
            color: Color(0xFF2D3748),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: SplashScreen(),
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
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
