import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shamil_web_app/feature/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/feature/auth/views/page/registration_flow.dart';
import 'package:shamil_web_app/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Provide the ServiceProviderBloc globally.
        BlocProvider<ServiceProviderBloc>(
          create: (_) => ServiceProviderBloc(),
        ),
        // Add other global blocs here if needed.
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Service Provider Registration',
        theme: ThemeData(
          primaryColor: Colors.blue, // Replace with your theme settings.
        ),
        home: const RegistrationStoryFlow(),
      ),
    );
  }
}
