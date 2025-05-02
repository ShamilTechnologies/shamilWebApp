// lib/injection_container.dart
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart'; // Assuming Hive is used for local data sources
import 'package:http/http.dart' as http;

// Core (Example - uncomment/implement if needed)
// import 'package:shamil_web_app/core/network/network_info.dart';
// import 'package:internet_connection_checker/internet_connection_checker.dart';

// Data Sources (Import Interfaces & Implementations)
// Remote
import 'package:shamil_web_app/data/datasources/remote/firebase_auth_datasource.dart';
import 'package:shamil_web_app/data/datasources/remote/firestore_datasource.dart'; // Assuming FirestoreProviderDataSource lives here
import 'package:shamil_web_app/data/datasources/remote/cloudinary_datasource.dart';
// Local (Example Placeholders - Create these files)
// import 'package:shamil_web_app/data/datasources/local/hive_provider_profile_datasource.dart';
// import 'package:shamil_web_app/data/datasources/local/hive_access_log_datasource.dart';
// Hardware (Example Placeholder)
// import 'package:shamil_web_app/data/datasources/hardware/nfc_datasource.dart';

// Repositories (Import Interfaces & Implementations)
// Auth & Provider
import 'package:shamil_web_app/data/repositories/auth_repository_impl.dart';
import 'package:shamil_web_app/data/repositories/service_provider_repository_impl.dart';
import 'package:shamil_web_app/data/repositories/image_repository_impl.dart';
import 'package:shamil_web_app/domain/repositories/auth_repository.dart';
import 'package:shamil_web_app/domain/repositories/service_provider_repository.dart';
import 'package:shamil_web_app/domain/repositories/image_repository.dart';
// Other Features (Example Placeholders - Create these files)
// import 'package:shamil_web_app/data/repositories/dashboard_repository_impl.dart';
// import 'package:shamil_web_app/domain/repositories/dashboard_repository.dart';
// import 'package:shamil_web_app/data/repositories/access_log_repository_impl.dart';
// import 'package:shamil_web_app/domain/repositories/access_log_repository.dart';
// import 'package:shamil_web_app/data/repositories/nfc_repository_impl.dart';
// import 'package:shamil_web_app/domain/repositories/nfc_repository.dart';
// import 'package:shamil_web_app/data/repositories/reservation_repository_impl.dart';
// import 'package:shamil_web_app/domain/repositories/reservation_repository.dart';
// import 'package:shamil_web_app/data/repositories/subscription_repository_impl.dart';
// import 'package:shamil_web_app/domain/repositories/subscription_repository.dart';


// Use Cases (Import All)
// Auth
import 'package:shamil_web_app/domain/use_cases/auth/get_current_user.dart';
import 'package:shamil_web_app/domain/use_cases/auth/reload_user.dart';
import 'package:shamil_web_app/domain/use_cases/auth/sign_in.dart';
import 'package:shamil_web_app/domain/use_cases/auth/send_email_verification.dart';
// Provider
import 'package:shamil_web_app/domain/use_cases/provider/register_provider.dart';
import 'package:shamil_web_app/domain/use_cases/provider/get_service_provider_profile.dart';
import 'package:shamil_web_app/domain/use_cases/provider/save_service_provider_profile.dart';
// Assets
import 'package:shamil_web_app/domain/use_cases/assets/upload_asset.dart';
import 'package:shamil_web_app/domain/use_cases/assets/remove_asset.dart';
import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart';
// Other Features (Example Placeholders - Create these files)
// import 'package:shamil_web_app/domain/use_cases/dashboard/get_dashboard_data.dart';
// import 'package:shamil_web_app/domain/use_cases/access_control/validate_access.dart';
// import 'package:shamil_web_app/domain/use_cases/nfc/connect_nfc_reader.dart';
// import 'package:shamil_web_app/domain/use_cases/nfc/listen_nfc_tags.dart';
// import 'package:shamil_web_app/domain/use_cases/logs/get_access_logs.dart';


// Blocs (Import All)
import 'package:shamil_web_app/features/auth/presentation/bloc/service_provider_bloc.dart';
import 'package:shamil_web_app/features/dashboard/bloc/access_control_bloc/access_control_bloc.dart';
import 'package:shamil_web_app/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:shamil_web_app/features/access_control/presentation/bloc/access_point_bloc.dart';
import 'package:shamil_web_app/features/dashboard/presentation/bloc/access_control_bloc/access_control_bloc.dart'; // For log viewing

// Services (If needed directly or for DataSources)
import 'package:shamil_web_app/features/access_control/service/nfc_reader_service.dart';
// import 'package:shamil_web_app/features/access_control/service/access_control_sync_service.dart'; // Might be wrapped by repos/datasources now


final sl = GetIt.instance; // Service Locator instance

/// Initializes the dependency injection container.
/// Call this function in main.dart before runApp().
Future<void> init() async {

  //---------------------------------------
  // Features
  //---------------------------------------

  //! Feature: ServiceProvider / Auth
  // Bloc (Factory - new instance each time it's requested)
  sl.registerFactory(() => ServiceProviderBloc(
        getCurrentUserUseCase: sl(),
        reloadUserUseCase: sl(),
        signInUseCase: sl(),
        registerProviderUseCase: sl(),
        sendEmailVerificationUseCase: sl(),
        getServiceProviderProfileUseCase: sl(),
        saveServiceProviderProfileUseCase: sl(),
        uploadAssetUseCase: sl(),
        removeAssetUseCase: sl(),
      ));

  // Use Cases (Lazy Singleton - created once when first requested)
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => ReloadUserUseCase(sl()));
  sl.registerLazySingleton(() => SignInUseCase(sl()));
  sl.registerLazySingleton(() => RegisterProviderUseCase(sl(), sl()));
  sl.registerLazySingleton(() => SendEmailVerificationUseCase(sl()));
  sl.registerLazySingleton(() => GetServiceProviderProfileUseCase(sl()));
  sl.registerLazySingleton(() => SaveServiceProviderProfileUseCase(sl()));
  sl.registerLazySingleton(() => UploadAssetUseCase(sl()));
  sl.registerLazySingleton(() => RemoveAssetUseCase(sl()));

  // Repositories (Lazy Singleton) - Registering the Implementation for the Interface
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ServiceProviderRepository>(
    () => ServiceProviderRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ImageRepository>(
    () => ImageRepositoryImpl(remoteDataSource: sl()),
  );

  // Data Sources (Lazy Singleton)
  sl.registerLazySingleton<FirebaseAuthDataSource>(
    () => FirebaseAuthDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<FirestoreProviderDataSource>( // Use specific interface name
    () => FirestoreProviderDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<CloudinaryDataSource>(
    () => CloudinaryDataSourceImpl(/* pass http client if needed: sl() */),
  );


  //! Feature: Dashboard
  // Bloc
  sl.registerFactory(() => DashboardBloc(
      // Inject necessary use cases, e.g.:
      // getDashboardDataUseCase: sl(),
      // Placeholder: Using Repos directly for now until use cases are defined
      authRepository: sl(),
      serviceProviderRepository: sl(),
      // reservationRepository: sl(), // Add Reservation repo
      // subscriptionRepository: sl(), // Add Subscription repo
      // accessLogRepository: sl(), // Add AccessLog repo
    ));

  // Use Cases (Define these)
  // sl.registerLazySingleton(() => GetDashboardDataUseCase(sl(), sl(), sl(), sl()));

  // Repositories (Define these)
  // sl.registerLazySingleton<DashboardRepository>(() => DashboardRepositoryImpl(remoteDataSource: sl()));
  // sl.registerLazySingleton<ReservationRepository>(() => ReservationRepositoryImpl(remoteDataSource: sl()));
  // sl.registerLazySingleton<SubscriptionRepository>(() => SubscriptionRepositoryImpl(remoteDataSource: sl()));
  // sl.registerLazySingleton<AccessLogRepository>(() => AccessLogRepositoryImpl(remoteDataSource: sl(), localDataSource: sl()));

  // Data Sources (Define these)
  // sl.registerLazySingleton<FirestoreDashboardDataSource>(() => FirestoreDashboardDataSourceImpl(sl()));
  // sl.registerLazySingleton<HiveAccessLogDataSource>(() => HiveAccessLogDataSourceImpl(sl()));


  //! Feature: Access Control Point
  // Bloc
  sl.registerFactory(() => AccessPointBloc(
        // Inject necessary use cases, e.g.:
        // connectNfcReaderUseCase: sl(),
        // listNfcPortsUseCase: sl(),
        // listenNfcTagsUseCase: sl(),
        // validateAccessUseCase: sl(),
        // disconnectNfcReaderUseCase: sl(),
        // Placeholder: Using Repos/Services directly for now
        dashboardBloc: sl(), // Needs DashboardBloc for provider context
        nfcReaderService: sl(), // Inject service or wrap in Repo/DataSource
        accessControlSyncService: sl(), // Inject service or wrap in Repo/DataSource
      ));

  // Use Cases (Define these)
  // sl.registerLazySingleton(() => ConnectNfcReaderUseCase(sl()));
  // sl.registerLazySingleton(() => DisconnectNfcReaderUseCase(sl()));
  // sl.registerLazySingleton(() => ListNfcPortsUseCase(sl()));
  // sl.registerLazySingleton(() => ListenNfcTagsUseCase(sl()));
  // sl.registerLazySingleton(() => ValidateAccessUseCase(sl(), sl(), sl())); // Needs Cache/User/Sub/Res Repos

  // Repositories (Define these)
  // sl.registerLazySingleton<NfcRepository>(() => NfcRepositoryImpl(dataSource: sl()));
  // sl.registerLazySingleton<UserRepository>(() => UserRepositoryImpl(localDataSource: sl())); // Example for cached user repo

  // Data Sources (Define these)
  // sl.registerLazySingleton<NfcDataSource>(() => NfcDataSourceImpl(sl())); // Wraps NfcReaderService
  // sl.registerLazySingleton<HiveUserDataSource>(() => HiveUserDataSourceImpl(sl()));


  //! Feature: Access Control Log Viewer
   // Bloc
   sl.registerFactory(() => AccessControlBloc(
      // Inject necessary use cases, e.g.:
      // getAccessLogsUseCase: sl(),
      // Placeholder: Using Repos directly for now
      // accessLogRepository: sl(),
      firebaseAuth: sl(), // Direct dependency for now
      firestore: sl(),   // Direct dependency for now
   ));

   // Use Cases (Define these)
   // sl.registerLazySingleton(() => GetAccessLogsUseCase(sl()));

   // Repositories (AccessLogRepository defined above with Dashboard)

   // Data Sources (Hive/Firestore AccessLog DataSources defined above)


  //---------------------------------------
  // Core
  //---------------------------------------
  // sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  //---------------------------------------
  // External Dependencies
  //---------------------------------------
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);
  sl.registerLazySingleton(() => http.Client());
  // sl.registerLazySingleton(() => InternetConnectionChecker());
  // Register Hive Box instances if needed by DataSources? Or open within DataSource init.
  // sl.registerLazySingletonAsync<Box<CachedUser>>(() => Hive.openBox<CachedUser>('cachedUsersBox'));

  // Register Services if they aren't wrapped by Repositories/DataSources yet
  // Only register singletons if they manage their own state appropriately
  sl.registerLazySingleton(() => NfcReaderService());
  sl.registerLazySingleton(() => AccessControlSyncService()); // Be cautious if this depends on Hive boxes registered async

  // Ensure all async singletons are ready if needed immediately
  // await sl.allReady(); // Uncomment if using registerLazySingletonAsync

  print("Dependency registration complete.");
}