import '../../repositories/access_control_repository.dart';

/// Use case for synchronizing access control data
class SyncDataUseCase {
  /// Repository containing access control logic
  final AccessControlRepository repository;

  /// Creates a use case with the given repository
  const SyncDataUseCase(this.repository);

  /// Synchronizes all data with remote server
  Future<bool> execute() async {
    // First sync any pending access logs
    await repository.syncAccessLogs();

    // Then sync credential data
    return repository.syncData();
  }

  /// Gets the current sync status stream
  Stream<bool> syncStatusStream() {
    return repository.syncStatusStream();
  }

  /// Rebuilds cache from scratch
  Future<void> rebuildCache() {
    return repository.rebuildCache();
  }
}
