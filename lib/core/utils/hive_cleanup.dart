import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';

/// Utility to handle Hive database cleanup for schema changes
class HiveCleanup {
  /// Delete all Hive boxes in case of schema changes
  static Future<void> deleteAllBoxes() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final hivePath = '${appDocDir.path}/hive';

      // Check if the directory exists
      if (await Directory(hivePath).exists()) {
        print('HiveCleanup: Deleting all Hive boxes from $hivePath');
        await Directory(hivePath).delete(recursive: true);
        print('HiveCleanup: Successfully deleted Hive directory');
      } else {
        print('HiveCleanup: No Hive directory found at $hivePath');
      }

      // Also check for any boxes in the app documents directory
      final files = await appDocDir.list().toList();
      for (final file in files) {
        if (file.path.endsWith('.hive') || file.path.endsWith('.lock')) {
          print('HiveCleanup: Deleting file: ${file.path}');
          await file.delete();
        }
      }
    } catch (e) {
      print('HiveCleanup: Error deleting Hive boxes: $e');
    }
  }

  /// Delete specific boxes that might have schema issues
  static Future<void> deleteProblematicBoxes() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final problematicBoxes = [
        'localAccessLogs',
        'access_logs',
        'cached_users',
        'access_credentials',
      ];

      // Try to close any open box first
      for (final boxName in problematicBoxes) {
        try {
          if (Hive.isBoxOpen(boxName)) {
            await Hive.box(boxName).close();
            print('HiveCleanup: Closed $boxName box');
          }
        } catch (e) {
          print('HiveCleanup: Failed to close $boxName box: $e');
          // Continue with deletion anyway
        }
      }

      for (final boxName in problematicBoxes) {
        // Try all possible paths
        final paths = [
          '${appDocDir.path}/$boxName.hive',
          '${appDocDir.path}/hive/$boxName.hive',
          '${appDocDir.path}/$boxName',
          '${appDocDir.path}/hive/$boxName',
        ];

        for (final path in paths) {
          final boxFile = File(path);
          if (await boxFile.exists()) {
            print('HiveCleanup: Deleting problematic box: $boxName at $path');
            await boxFile.delete();
            print('HiveCleanup: Successfully deleted box: $boxName from $path');

            // Also delete lock files if they exist
            final lockPath = '$path.lock';
            final lockFile = File(lockPath);
            if (await lockFile.exists()) {
              await lockFile.delete();
              print('HiveCleanup: Deleted lock file for $boxName from $path');
            }
          }
        }
      }

      print('HiveCleanup: Problematic boxes deletion completed');
    } catch (e) {
      print('HiveCleanup: Error deleting problematic boxes: $e');
    }
  }

  /// Fix the access logs box that has DateTime/String type mismatch issues
  static Future<void> fixAccessLogsBox() async {
    try {
      print(
        'HiveCleanup: Specifically fixing access logs box to resolve DateTime/String type mismatch',
      );

      // First, close any open box
      if (Hive.isBoxOpen('localAccessLogs')) {
        await Hive.box('localAccessLogs').close();
      }
      if (Hive.isBoxOpen('access_logs')) {
        await Hive.box('access_logs').close();
      }

      final appDocDir = await getApplicationDocumentsDirectory();

      // Delete all possible versions of the access logs box
      final boxPaths = [
        '${appDocDir.path}/localAccessLogs.hive',
        '${appDocDir.path}/hive/localAccessLogs.hive',
        '${appDocDir.path}/access_logs.hive',
        '${appDocDir.path}/hive/access_logs.hive',
      ];

      for (final path in boxPaths) {
        final boxFile = File(path);
        if (await boxFile.exists()) {
          print('HiveCleanup: Deleting access logs box at $path');
          await boxFile.delete();

          // Delete the lock file too
          final lockFile = File('$path.lock');
          if (await lockFile.exists()) {
            await lockFile.delete();
          }
        }
      }

      print('HiveCleanup: Access logs box cleanup completed');
    } catch (e) {
      print('HiveCleanup: Error fixing access logs box: $e');
    }
  }

  /// Perform a complete database reset and rebuild
  static Future<void> resetDatabase() async {
    try {
      // First, make sure all boxes are closed
      await Hive.close();
      print('HiveCleanup: Closed all open Hive boxes');

      // Specifically fix the access logs box issue
      await fixAccessLogsBox();

      // Delete problematic boxes
      await deleteProblematicBoxes();

      // Delete all boxes
      await deleteAllBoxes();

      // Force the OS to release file handles
      await Future.delayed(const Duration(milliseconds: 500));

      print('HiveCleanup: Database reset complete');
    } catch (e) {
      print('HiveCleanup: Error during database reset: $e');
    }
  }
}
