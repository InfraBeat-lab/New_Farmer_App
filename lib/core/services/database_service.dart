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
        CREATE SCHEMA IF NOT EXISTS auth;
        ''');

      await conn.execute('''
        CREATE TABLE IF NOT EXISTS auth.users (
            id SERIAL PRIMARY KEY,
            user_code VARCHAR(20) NOT NULL UNIQUE DEFAULT ('USR' || nextval('auth.users_id_seq')),
            user_name VARCHAR(100) NOT NULL,
            farmer_id INTEGER,
            mobile_number VARCHAR(20) UNIQUE,
            email_address VARCHAR(100) UNIQUE,
            password_hash VARCHAR(255),
            role_id INTEGER DEFAULT 1,
            device_id VARCHAR(100),
            fcm_token VARCHAR(255),
            otp_code VARCHAR(10),
            otp_expires_at TIMESTAMP,
            last_login_at TIMESTAMP,
            login_attempts INTEGER NOT NULL DEFAULT 0,
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            google_uid VARCHAR(100),
            photo_url TEXT,
            auth_provider VARCHAR(20) DEFAULT 'LOCAL',

            CONSTRAINT fk_users_farmer
                FOREIGN KEY (farmer_id)
                REFERENCES auth.farmers(id)
                ON UPDATE CASCADE
                ON DELETE RESTRICT,

            CONSTRAINT fk_users_role
                FOREIGN KEY (role_id)
                REFERENCES auth.roles(id)
                ON UPDATE CASCADE
                ON DELETE RESTRICT
        );
        ''');

      debugPrint('auth.users table is ready.');
    } catch (e) {
      debugPrint('Error creating auth.users table: $e');
    }
  }

  /// Inserts a new user or updates their last login time on successful sign-in.
  static Future<void> insertOrUpdateUser({
    required String name,
    String? email,
    int? farmerId,
    String? mobileNumber,
    String? passwordHash,
    int roleId = 1,
    String? deviceId,
    String? fcmToken,
    String? googleUid,
    String? photoUrl,
    String authProvider = 'LOCAL',
  }) async {
    try {
      final conn = await getConnection();

      final check = await conn.execute(
        Sql.named('''
        SELECT id
FROM auth.users
WHERE email_address = :email
   OR google_uid = :googleUid
      '''),
        parameters: {
          'email': email,
        },
      );

      if (check.isEmpty) {
        await conn.execute(
          Sql.named('''
          INSERT INTO auth.users (
            user_code,
            user_name,
            farmer_id,
            mobile_number,
            email_address,
            password_hash,
            role_id,
            device_id,
            fcm_token,
            created_at,
            updated_at,
            last_login_at
          )
          VALUES (
            :userCode,
            :userName,
            :farmerId,
            :mobileNumber,
            :email,
            :passwordHash,
            :roleId,
            :deviceId,
            :fcmToken,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
          )
        '''),
          parameters: {
            'userName': name,
            'farmerId': farmerId,
            'mobileNumber': mobileNumber,
            'email': email,
            'passwordHash': passwordHash,
            'roleId': roleId,
            'deviceId': deviceId,
            'fcmToken': fcmToken,
            'googleUid': googleUid,
            'photoUrl': photoUrl,
            'authProvider': authProvider,
          },
        );
      } else {
        await conn.execute(
          Sql.named('''
          UPDATE auth.users
SET
    user_name = :userName,
    farmer_id = :farmerId,
    mobile_number = :mobileNumber,
    device_id = :deviceId,
    fcm_token = :fcmToken,
    google_uid = :googleUid,
    photo_url = :photoUrl,
    auth_provider = :authProvider,
    last_login_at = CURRENT_TIMESTAMP,
    updated_at = CURRENT_TIMESTAMP
WHERE email_address = :email
        '''),
          parameters: {
            'userName': name,
            'deviceId': deviceId,
            'fcmToken': fcmToken,
            'email': email,
          },
        );
      }
    } catch (e) {
      debugPrint('Error inserting/updating user: $e');
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
