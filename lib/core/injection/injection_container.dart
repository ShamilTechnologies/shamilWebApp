import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/datasources/access_control_local_datasource.dart';
import '../../data/datasources/access_control_remote_datasource.dart';
import '../../data/models/access_control/access_credential_model.dart'
    as credential_model;
import '../../data/models/access_control/access_log_model.dart' as log_model;
import '../../data/models/access_control/cached_user_model.dart' as user_model;
import '../../data/models/access_control/hive_adapters.dart';
import '../../data/repositories/access_control_repository_impl.dart';
import '../../domain/models/access_control/access_result.dart';
import '../../domain/models/access_control/access_type.dart';
import '../../domain/repositories/access_control_repository.dart';
import '../../domain/usecases/access_control/sync_data_usecase.dart';
import '../../domain/usecases/access_control/validate_access_usecase.dart';
import '../../presentation/bloc/access_control/access_control_bloc.dart';
import '../network/network_info.dart';
import '../services/device_management_service.dart';

/// Global service locator
final GetIt sl = GetIt.instance;

/// Initialize all dependencies
Future<void> init() async {
  try {
    print("DI: Starting dependency registration");

    // Register external services first
    _registerExternalServices();

    // Register core services
    _registerCoreServices();

    // Initialize Hive and register adapters
    await _initializeHive();

    // Register data sources
    _registerDataSources();

    // Register repositories
    _registerRepositories();

    // Register use cases
    _registerUseCases();

    // Register BLoCs
    _registerBlocs();

    print("DI: Registration completed successfully");
  } catch (e, s) {
    print("DI: Error during initialization: $e");
    print("DI: Stack trace: $s");
    rethrow;
  }
}

/// Register external services like Firebase
void _registerExternalServices() {
  print("DI: Registering external services");

  try {
    // First, ensure Connectivity is registered
    if (!sl.isRegistered<Connectivity>()) {
      final connectivity = Connectivity();
      sl.registerSingleton<Connectivity>(connectivity);
      print("DI: Connectivity registered successfully");
    } else {
      print("DI: Connectivity was already registered");
    }
  } catch (e) {
    print("DI: Error registering Connectivity: $e");
    // Create and register anyway even if there was an error
    sl.registerSingleton<Connectivity>(Connectivity());
  }

  // Register Firebase services
  sl.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);
  sl.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);

  print("DI: External services registered");
}

/// Register core services
void _registerCoreServices() {
  print("DI: Registering core services");

  try {
    // Make sure Connectivity is registered first
    if (!sl.isRegistered<Connectivity>()) {
      print("DI: Connectivity not registered yet, registering again");
      sl.registerSingleton<Connectivity>(Connectivity());
    }

    // Now register NetworkInfo
    sl.registerSingleton<NetworkInfo>(NetworkInfoImpl(sl<Connectivity>()));
    print("DI: NetworkInfo registered");

    // Register DeviceManagementService
    sl.registerSingleton<DeviceManagementService>(DeviceManagementService());
    print("DI: DeviceManagementService registered");
  } catch (e) {
    print("DI: Error registering NetworkInfo: $e");
    rethrow;
  }
}

/// Initialize Hive and register adapters
Future<void> _initializeHive() async {
  print("DI: Initializing Hive");
  try {
    final appDocDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocDir.path);

    // Register Hive adapters
    if (!Hive.isAdapterRegistered(user_model.cachedUserTypeId)) {
      Hive.registerAdapter(user_model.CachedUserModelAdapter());
    }

    if (!Hive.isAdapterRegistered(credential_model.accessCredentialTypeId)) {
      Hive.registerAdapter(credential_model.AccessCredentialModelAdapter());
    }

    if (!Hive.isAdapterRegistered(log_model.accessLogTypeId)) {
      Hive.registerAdapter(log_model.AccessLogModelAdapter());
    }

    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(AccessTypeAdapter());
    }

    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(AccessResultAdapter());
    }

    print("DI: Hive initialization completed");
  } catch (e) {
    print("DI: Error during Hive initialization: $e");
    rethrow;
  }
}

/// Register data sources
void _registerDataSources() {
  print("DI: Registering data sources");

  // Create and initialize the AccessControlLocalDataSource
  final localDataSource = AccessControlLocalDataSourceImpl();
  // Initialize immediately to prevent "not initialized" errors
  localDataSource
      .initialize()
      .then((_) {
        print("DI: AccessControlLocalDataSource initialized successfully");
      })
      .catchError((e) {
        print("DI: Error initializing AccessControlLocalDataSource: $e");
      });

  sl.registerLazySingleton<AccessControlLocalDataSource>(() => localDataSource);

  sl.registerLazySingleton<AccessControlRemoteDataSource>(
    () => AccessControlRemoteDataSource(),
  );
}

/// Register repositories
void _registerRepositories() {
  print("DI: Registering repositories");
  sl.registerLazySingleton<AccessControlRepository>(
    () => AccessControlRepositoryImpl(
      localDataSource: sl<AccessControlLocalDataSource>(),
      remoteDataSource: sl<AccessControlRemoteDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );
}

/// Register use cases
void _registerUseCases() {
  print("DI: Registering use cases");
  sl.registerFactory(
    () => ValidateAccessUseCase(sl<AccessControlRepository>()),
  );
  sl.registerFactory(() => SyncDataUseCase(sl<AccessControlRepository>()));
}

/// Register BLoCs
void _registerBlocs() {
  print("DI: Registering BLoCs");
  sl.registerFactory(
    () => AccessControlBloc(
      validateAccessUseCase: sl<ValidateAccessUseCase>(),
      syncDataUseCase: sl<SyncDataUseCase>(),
    ),
  );
}
