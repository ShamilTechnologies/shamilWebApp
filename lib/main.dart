import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shamil_web_app/controllers/registration_controller.dart';
import 'package:shamil_web_app/features/auth/views/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/auth/views/page/registration_flow.dart';
import 'package:shamil_web_app/firebase_options.dart';

Future<void> main() async {
  // Load environment variables from the .env file.
  await dotenv.load(fileName: "assets/env/.env");
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<RegistrationController>(
          create: (_) => RegistrationController(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ServiceProviderBloc>(
            create: (_) => ServiceProviderBloc(),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Service Provider Registration',
          theme: ThemeData(primaryColor: Colors.blue),
          home: const RegistrationFlow(),
        ),
      ),
    );
  }
}
