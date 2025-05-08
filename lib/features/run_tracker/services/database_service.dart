// lib/features/run_tracker/services/database_service.dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'dart:convert';

import '../models/activity.dart';
import '../models/sensor_reading.dart';

class DatabaseService {
  // Private constructor for singleton pattern
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static Database? _database;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String dbKey = 'volt_db_encryption_key';

  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDatabase() async {
    final dbPath = await _getDatabasePath();
    // Get encryption key but don't use it yet (for future implementation)
    await _getOrCreateEncryptionKey();

    // Removed the onConfigure callback to avoid WAL mode error on Android
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _createDb,
    );
  }

  // Get path for database file
  Future<String> _getDatabasePath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, 'volt_running_tracker.db');
  }

  // Get or create a new encryption key for the database
  Future<String> _getOrCreateEncryptionKey() async {
    String? key = await _secureStorage.read(key: dbKey);

    if (key == null) {
      // Generate a random key - in a real app, use a more secure method
      final random = DateTime.now().millisecondsSinceEpoch.toString();
      key = base64Encode(utf8.encode(random));
      await _secureStorage.write(key: dbKey, value: key);
    }

    return key;
  }

  // Create database tables
  Future<void> _createDb(Database db, int version) async {
    // Activities table
    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        startTime INTEGER NOT NULL,
        endTime INTEGER,
        durationSeconds INTEGER NOT NULL,
        distanceMeters REAL NOT NULL,
        elevationGainMeters REAL NOT NULL,
        elevationLossMeters REAL NOT NULL,
        averageHeartRate INTEGER,
        maxHeartRate INTEGER,
        averagePower INTEGER,
        maxPower INTEGER,
        averagePaceSecondsPerKm INTEGER,
        averageCadence INTEGER,
        maxCadence INTEGER,
        routePointsJson TEXT,
        status TEXT NOT NULL,
        notes TEXT
      )
    ''');

    // Sensor readings table
    await db.execute('''
      CREATE TABLE sensor_readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activityId TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        latitude REAL,
        longitude REAL,
        elevationMeters REAL,
        heartRate INTEGER,
        power INTEGER,
        cadence INTEGER,
        distanceMeters REAL,
        paceSecondsPerKm INTEGER,
        source TEXT,
        FOREIGN KEY (activityId) REFERENCES activities (id) ON DELETE CASCADE
      )
    ''');

    // Create indices for faster queries
    await db.execute(
        'CREATE INDEX idx_sensor_readings_activityId ON sensor_readings (activityId)');
    await db.execute(
        'CREATE INDEX idx_sensor_readings_timestamp ON sensor_readings (timestamp)');
  }

  // ACTIVITY METHODS

  /// Insert a new activity
  Future<String> insertActivity(Activity activity) async {
    final db = await database;
    await db.insert(
      'activities',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return activity.id;
  }

  /// Update an existing activity
  Future<int> updateActivity(Activity activity) async {
    final db = await database;
    return await db.update(
      'activities',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
    );
  }

  /// Get an activity by ID
  Future<Activity?> getActivity(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    return Activity.fromMap(maps.first);
  }

  /// Get all activities, ordered by start time (most recent first)
  Future<List<Activity>> getAllActivities() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'activities',
      orderBy: 'startTime DESC',
    );

    return List.generate(maps.length, (index) {
      return Activity.fromMap(maps[index]);
    });
  }

  /// Delete an activity and all its sensor readings
  Future<int> deleteActivity(String id) async {
    final db = await database;

    // Delete sensor readings first (should cascade, but belt and suspenders)
    await db.delete(
      'sensor_readings',
      where: 'activityId = ?',
      whereArgs: [id],
    );

    // Then delete the activity
    return await db.delete(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // SENSOR READING METHODS

  /// Insert a new sensor reading
  Future<int> insertSensorReading(SensorReading reading) async {
    final db = await database;
    return await db.insert(
      'sensor_readings',
      reading.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple sensor readings in a batch operation
  Future<void> insertSensorReadingsBatch(List<SensorReading> readings) async {
    final db = await database;
    final batch = db.batch();

    for (final reading in readings) {
      batch.insert(
        'sensor_readings',
        reading.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get all sensor readings for an activity
  Future<List<SensorReading>> getActivitySensorReadings(
      String activityId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sensor_readings',
      where: 'activityId = ?',
      whereArgs: [activityId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (index) {
      return SensorReading.fromMap(maps[index]);
    });
  }

  /// Get route points for an activity (GPS locations only)
  Future<List<SensorReading>> getActivityRoutePoints(String activityId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sensor_readings',
      where:
          'activityId = ? AND latitude IS NOT NULL AND longitude IS NOT NULL',
      whereArgs: [activityId],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (index) {
      return SensorReading.fromMap(maps[index]);
    });
  }

  /// Delete all sensor readings for an activity
  Future<int> deleteSensorReadings(String activityId) async {
    final db = await database;
    return await db.delete(
      'sensor_readings',
      where: 'activityId = ?',
      whereArgs: [activityId],
    );
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
