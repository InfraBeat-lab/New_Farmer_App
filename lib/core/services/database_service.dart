import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:postgres/postgres.dart';

class DatabaseService {
  static Connection? _connection;

  /// Retrieves or creates an active PostgreSQL connection.
  static Future<Connection> getConnection() async {
    if (_connection != null && _connection!.isOpen) {
      return _connection!;
    }

    final host = dotenv.env['DB_HOST'] ?? 'localhost';
    final port = int.tryParse(dotenv.env['DB_PORT'] ?? '5432') ?? 5432;
    final databaseName = dotenv.env['DB_NAME'] ?? 'infrabeat_poultryos';
    final username = dotenv.env['DB_USER'] ?? 'postgres';
    final password = dotenv.env['DB_PASSWORD'] ?? 'root#123';
    final sslMode = (dotenv.env['DB_SSL'] ?? 'false').toLowerCase() == 'true'
        ? SslMode.require
        : SslMode.disable;

    debugPrint(
        'Connecting to PostgreSQL database at $host:$port/$databaseName...');

    try {
      _connection = await Connection.open(
        Endpoint(
          host: host,
          database: databaseName,
          username: username,
          password: password,
          port: port,
        ),
        settings: ConnectionSettings(
          sslMode: sslMode,
          connectTimeout: const Duration(seconds: 5),
          queryTimeout: const Duration(seconds: 5),
        ),
      );

      debugPrint('PostgreSQL connection established successfully.');
      await _initializeDatabase(_connection!);
      return _connection!;
    } catch (e) {
      debugPrint('Failed to connect to PostgreSQL database: $e');
      _connection = null;
      rethrow;
    }
  }

  /// Creates the users table if it does not exist.
  static Future<void> _initializeDatabase(Connection conn) async {
    try {
      debugPrint('Initializing PostgreSQL tables...');
      await conn.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          email VARCHAR(255) UNIQUE NOT NULL,
          name VARCHAR(255),
          photo_url TEXT,
          role VARCHAR(50) DEFAULT 'Farmer',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          last_login TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
      ''');
      debugPrint('PostgreSQL users table is ready.');
    } catch (e) {
      debugPrint('Error creating users table in PostgreSQL: $e');
    }
  }

  /// Inserts a new user or updates their last login time on successful sign-in.
  static Future<void> insertOrUpdateUser({
    required String email,
    required String name,
    required String photoUrl,
    String role = 'Farmer',
  }) async {
    try {
      final conn = await getConnection();

      // Check if user already exists
      final checkResult = await conn.execute(
        Sql.named('SELECT id FROM users WHERE email = :email'),
        parameters: {'email': email},
      );

      if (checkResult.isEmpty) {
        // User not found, insert new user
        debugPrint('Inserting new user: $email into PostgreSQL');
        await conn.execute(
          Sql.named('''
            INSERT INTO users (email, name, photo_url, role, created_at, last_login)
            VALUES (:email, :name, :photoUrl, :role, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          '''),
          parameters: {
            'email': email,
            'name': name,
            'photoUrl': photoUrl,
            'role': role,
          },
        );
      } else {
        // User found, update last login and profile info
        debugPrint('User exists. Updating last login for: $email');
        await conn.execute(
          Sql.named('''
            UPDATE users
            SET last_login = CURRENT_TIMESTAMP, name = :name, photo_url = :photoUrl
            WHERE email = :email
          '''),
          parameters: {
            'email': email,
            'name': name,
            'photoUrl': photoUrl,
          },
        );
      }
    } catch (e) {
      debugPrint('Error inserting/updating user in PostgreSQL: $e');
      rethrow;
    }
  }

  /// Close connection.
  static Future<void> close() async {
    if (_connection != null && _connection!.isOpen) {
      await _connection!.close();
      _connection = null;
      debugPrint('PostgreSQL database connection closed.');
    }
  }
}
