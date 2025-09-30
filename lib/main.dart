import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/language_service.dart';
import 'services/voice_search_service.dart';
import 'services/proxy_service.dart';
import 'services/consolidated_ad_service.dart';
import 'screens/home/index.dart';
import 'screens/splash/splash_screen.dart';
import 'components/earth_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize();
  await NotificationService.requestPermission();
  await LanguageService.initialize();
  await VoiceSearchService.initialize();
  await ProxyService().initialize(); // ALWAYS INITIALIZE PROXY ON APP START
  await ConsolidatedAdService.initialize(); // INITIALIZE CONSOLIDATED AD SERVICE
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: LanguageService.translate('app_name'),
      locale: Locale(LanguageService.currentLanguage),
      home: FutureBuilder(
        future: _initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }
          
          if (snapshot.connectionState == ConnectionState.done) {
            return const SplashScreen();
          }
          
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2196F3),
                    Color(0xFF1976D2),
                  ],
                ),
              ),
              child: const Center(
                child: EarthLoader(
                  size: 120,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Future<void> _initializeApp() async {
    try {
      await dotenv.load(fileName: ".env");
      // Add any other initialization here
      await Future.delayed(const Duration(seconds: 2)); // Minimum display time for loader
    } catch (e) {
      // Continue without .env file
    }
  }
}
