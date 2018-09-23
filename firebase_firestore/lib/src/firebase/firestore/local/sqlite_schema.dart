// File created by
// Lung Razvan <long1eu>
// on 21/09/2018

import 'dart:async';

import 'package:firebase_firestore/src/firebase/firestore/local/persistence.dart';
import 'package:sqflite/sqflite.dart';

/// Migrates schemas from version 0 (empty) to whatever the current version is.
///
/// * Migrations are numbered for the version of the database they apply to. The
/// [VERSION] constant in this class should be one more than the highest
/// numbered migration.
///
/// * NOTE: Once we ship code with a migration in it the code for that migration
/// should never be changed again. Further changes can be made to the schema by
/// adding a new migration method, bumping the VERSION, and adding a call to the
/// migration method from [runMigrations].
class SQLiteSchema {
  /// The version of the schema. Increase this by one for each migration added
  /// to [runMigrations] below.
  static final int VERSION = (Persistence.INDEXING_SUPPORT_ENABLED) ? 6 : 5;

  final Database db;

  SQLiteSchema(this.db);

  /// Runs the migration methods defined in this class, starting at the given
  /// version.
  void runMigrations([int fromVersion, int toVersion]) async {
    fromVersion ??= 0;
    toVersion ??= VERSION;
    // Each case in this switch statement intentionally falls through to the one
    // below it, making it possible to start at the version that's installed and
    // then run through any that haven't been applied yet.

    if (fromVersion < 1 && toVersion >= 5) {
      _createMutationQueue();
      _createQueryCache();
      _createRemoteDocumentCache();
    }

    if (fromVersion < 6 && toVersion >= 6) {
      if (Persistence.INDEXING_SUPPORT_ENABLED) {
        _createLocalDocumentsCollectionIndex();
      }
    }
  }

  Future<void> _createMutationQueue() async {
    // A table naming all the mutation queues in the system.
    await db.rawQuery(
        // @formatter:off
        '''CREATE TABLE mutation_queues (
              uid                        TEXT PRIMARY KEY,
              last_acknowledged_batch_id INTEGER,
              last_stream_token          BLOB
            )'''
        // @formatter:on
        );

    // All the mutation batches in the system, partitioned by user.
    await db.rawQuery(
        // @formatter:off
        '''CREATE TABLE mutations (
            uid       TEXT,
            batch_id  INTEGER,
            mutations BLOB,
            PRIMARY KEY (uid, batch_id)
           )'''
        // @formatter:on
        );

    // A manually maintained index of all the mutation batches that affect a
    // given document key. The rows in this table are references based on the
    // contents of mutations.mutations.
    await db.rawQuery(
        // @formatter:off
        '''CREATE TABLE document_mutations (
            uid      TEXT, 
            path     TEXT, 
            batch_id INTEGER, 
            PRIMARY KEY (uid, path, batch_id)
           )'''
        // @formatter:on
        );
  }

  Future<void> _createQueryCache() async {
    // A cache of targets and associated metadata
    await db.rawQuery(
        // @formatter:off
        '''CREATE TABLE targets (
            target_id                   INTEGER PRIMARY KEY, 
            canonical_id                TEXT, 
            snapshot_version_seconds    INTEGER, 
            snapshot_version_nanos      INTEGER, 
            resume_token                BLOB, 
            last_listen_sequence_number INTEGER, 
            target_proto                BLOB
           )'''
        // @formatter:on
        );

    await db.rawQuery(
        '''CREATE INDEX query_targets ON targets (canonical_id, target_id)''');

    // Global state tracked across all queries, tracked separately
    await db.rawQuery(
        'CREATE TABLE target_globals (highest_target_id INTEGER, highest_listen_sequence_number INTEGER, last_remote_snapshot_version_seconds INTEGER, last_remote_snapshot_version_nanos INTEGER, target_count INTEGER)');

    await db.rawQuery(
        'INSERT INTO target_globals (highest_target_id, highest_listen_sequence_number, last_remote_snapshot_version_seconds, last_remote_snapshot_version_nanos, target_count) VALUES (?, ?, ?, ?, ?)',
        ['0', '0', '0', '0', '0']);

    // A Mapping table between targets, document paths and sequence number
    await db.rawQuery(
        'CREATE TABLE target_documents (target_id INTEGER, path TEXT, sequence_number INTEGER, PRIMARY KEY (target_id, path))');

    // The document_targets reverse mapping table is just an index on
    // target_documents.
    await db.rawQuery(
        'CREATE INDEX document_targets ON target_documents (path, target_id)');
  }

  Future<void> _createRemoteDocumentCache() async {
    // A cache of documents obtained from the server.
    await db.rawQuery(
        'CREATE TABLE remote_documents (path TEXT PRIMARY KEY, contents BLOB)');
  }

  // field_value_type determines type of field_value fields.
  // field_value_2 is first component
  // field_value_2 is the second component; required for timestamps, GeoPoints
  Future<void> _createLocalDocumentsCollectionIndex() async {
    // A per-user, per-collection index for cached documents indexed by a single
    // field's name and value.
    await db.rawQuery(
        'CREATE TABLE collection_index (uid TEXT, collection_path TEXT, field_path TEXT, field_value_type INTEGER, field_value_1, field_value_2, document_id TEXT, PRIMARY KEY (uid, collection_path, field_path, field_value_type, field_value_1, field_value_2, document_id))');
  }
}

class DatabaseUtils {
  static Future<int> queryNumEntries(Database db, String table,
      [String selection = '', List<String> selectionArgs]) async {
    selection = selection.isNotEmpty ? ' where ' + selection : '';
    final Map<String, dynamic> result = (await db.rawQuery(
            'select count(*) from $table $selection ', selectionArgs))
        .first;
    return result['count(*)'];
  }
}
