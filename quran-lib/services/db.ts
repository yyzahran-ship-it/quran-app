import * as SQLite from 'expo-sqlite';

let _db: SQLite.SQLiteDatabase | null = null;

export async function getDb(): Promise<SQLite.SQLiteDatabase> {
  if (_db) return _db;
  _db = await SQLite.openDatabaseAsync('quranlib.db');
  await runMigrations(_db);
  return _db;
}

// ── Schema migrations ──────────────────────────────────────────────────────────

const MIGRATIONS: Array<{ version: number; sql: string[] }> = [
  {
    version: 1,
    sql: [
      // Metadata / version tracking
      `CREATE TABLE IF NOT EXISTS metadata (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )`,

      // Surahs
      `CREATE TABLE IF NOT EXISTS surahs (
        id                    INTEGER PRIMARY KEY,
        name_arabic           TEXT    NOT NULL,
        name_english          TEXT    NOT NULL,
        name_transliteration  TEXT    NOT NULL,
        revelation_type       TEXT    NOT NULL CHECK(revelation_type IN ('Meccan','Medinan')),
        ayah_count            INTEGER NOT NULL,
        juz_start             INTEGER NOT NULL,
        page_start            INTEGER NOT NULL
      )`,

      // Ayahs
      `CREATE TABLE IF NOT EXISTS ayahs (
        id            INTEGER PRIMARY KEY,
        surah_id      INTEGER NOT NULL REFERENCES surahs(id),
        ayah_number   INTEGER NOT NULL,
        text_uthmani  TEXT    NOT NULL,
        text_clean    TEXT    NOT NULL,
        page          INTEGER NOT NULL DEFAULT 0,
        juz           INTEGER NOT NULL DEFAULT 1,
        hizb          INTEGER NOT NULL DEFAULT 1,
        sajdah        INTEGER NOT NULL DEFAULT 0,
        is_basmala    INTEGER NOT NULL DEFAULT 0
      )`,
      `CREATE INDEX IF NOT EXISTS idx_ayahs_surah    ON ayahs(surah_id)`,
      `CREATE INDEX IF NOT EXISTS idx_ayahs_juz      ON ayahs(juz)`,
      `CREATE INDEX IF NOT EXISTS idx_ayahs_page     ON ayahs(page)`,

      // Words (word-by-word)
      `CREATE TABLE IF NOT EXISTS words (
        id               INTEGER PRIMARY KEY,
        ayah_id          INTEGER NOT NULL REFERENCES ayahs(id),
        position         INTEGER NOT NULL,
        text_arabic      TEXT    NOT NULL,
        root             TEXT,
        lemma            TEXT,
        morphology_tag   TEXT,
        transliteration  TEXT
      )`,
      `CREATE INDEX IF NOT EXISTS idx_words_ayah ON words(ayah_id)`,

      // Translation editions registry
      `CREATE TABLE IF NOT EXISTS translation_editions (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        slug           TEXT    NOT NULL UNIQUE,
        language_code  TEXT    NOT NULL,
        name           TEXT    NOT NULL,
        translator     TEXT    NOT NULL DEFAULT '',
        direction      TEXT    NOT NULL DEFAULT 'ltr'
      )`,

      // Translations (actual text)
      `CREATE TABLE IF NOT EXISTS translations (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        ayah_id     INTEGER NOT NULL REFERENCES ayahs(id),
        edition_id  INTEGER NOT NULL REFERENCES translation_editions(id),
        text        TEXT    NOT NULL
      )`,
      `CREATE INDEX IF NOT EXISTS idx_translations_ayah    ON translations(ayah_id)`,
      `CREATE INDEX IF NOT EXISTS idx_translations_edition ON translations(edition_id)`,
      `CREATE UNIQUE INDEX IF NOT EXISTS idx_translations_unique ON translations(ayah_id, edition_id)`,

      // Tafsir sources registry
      `CREATE TABLE IF NOT EXISTS tafsir_sources (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        slug        TEXT    NOT NULL UNIQUE,
        name        TEXT    NOT NULL,
        author      TEXT    NOT NULL DEFAULT '',
        language    TEXT    NOT NULL,
        description TEXT    NOT NULL DEFAULT ''
      )`,

      // Tafsir texts
      `CREATE TABLE IF NOT EXISTS tafsirs (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        ayah_id    INTEGER NOT NULL REFERENCES ayahs(id),
        source_id  INTEGER NOT NULL REFERENCES tafsir_sources(id),
        text       TEXT    NOT NULL,
        language   TEXT    NOT NULL
      )`,
      `CREATE INDEX IF NOT EXISTS idx_tafsirs_ayah   ON tafsirs(ayah_id)`,
      `CREATE INDEX IF NOT EXISTS idx_tafsirs_source ON tafsirs(source_id)`,
      `CREATE UNIQUE INDEX IF NOT EXISTS idx_tafsirs_unique ON tafsirs(ayah_id, source_id)`,

      // Bookmarks
      `CREATE TABLE IF NOT EXISTS bookmarks (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        ayah_id          INTEGER NOT NULL REFERENCES ayahs(id),
        collection_name  TEXT    NOT NULL DEFAULT 'Favourites',
        note             TEXT,
        created_at       TEXT    NOT NULL DEFAULT (datetime('now'))
      )`,
      `CREATE INDEX IF NOT EXISTS idx_bookmarks_ayah       ON bookmarks(ayah_id)`,
      `CREATE INDEX IF NOT EXISTS idx_bookmarks_collection ON bookmarks(collection_name)`,

      // Last read positions (one per surah)
      `CREATE TABLE IF NOT EXISTS last_reads (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        surah_id  INTEGER NOT NULL REFERENCES surahs(id),
        ayah_id   INTEGER NOT NULL REFERENCES ayahs(id),
        timestamp TEXT    NOT NULL DEFAULT (datetime('now')),
        UNIQUE(surah_id)
      )`,

      // Reading plans
      `CREATE TABLE IF NOT EXISTS reading_plans (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        name            TEXT    NOT NULL,
        start_date      TEXT    NOT NULL,
        end_date        TEXT    NOT NULL,
        type            TEXT    NOT NULL DEFAULT 'juz',
        current_surah   INTEGER NOT NULL DEFAULT 1,
        current_ayah    INTEGER NOT NULL DEFAULT 1
      )`,

      // FTS5 virtual table for full-text search
      `CREATE VIRTUAL TABLE IF NOT EXISTS fts_ayahs USING fts5(
        ayah_id UNINDEXED,
        text_clean,
        content='ayahs',
        content_rowid='id'
      )`,
      `CREATE VIRTUAL TABLE IF NOT EXISTS fts_translations USING fts5(
        translation_id UNINDEXED,
        ayah_id UNINDEXED,
        edition_id UNINDEXED,
        text,
        content='translations',
        content_rowid='id'
      )`,
    ],
  },
];

async function runMigrations(db: SQLite.SQLiteDatabase): Promise<void> {
  // Enable WAL mode and foreign keys
  await db.execAsync('PRAGMA journal_mode=WAL');
  await db.execAsync('PRAGMA foreign_keys=ON');

  // Get current schema version
  let currentVersion = 0;
  try {
    const row = await db.getFirstAsync<{ value: string }>(
      `SELECT value FROM metadata WHERE key='schema_version'`
    );
    if (row) currentVersion = parseInt(row.value, 10);
  } catch {
    // metadata table doesn't exist yet — version 0
  }

  for (const migration of MIGRATIONS) {
    if (migration.version <= currentVersion) continue;

    await db.withTransactionAsync(async () => {
      for (const sql of migration.sql) {
        await db.execAsync(sql);
      }
      await db.runAsync(
        `INSERT OR REPLACE INTO metadata(key, value) VALUES('schema_version', ?)`,
        [String(migration.version)]
      );
    });
  }
}

// ── Convenience helpers ────────────────────────────────────────────────────────

export async function batchInsert(
  db: SQLite.SQLiteDatabase,
  table: string,
  columns: string[],
  rows: unknown[][],
  batchSize = 200
): Promise<void> {
  for (let i = 0; i < rows.length; i += batchSize) {
    const chunk = rows.slice(i, i + batchSize);
    await db.withTransactionAsync(async () => {
      for (const row of chunk) {
        const placeholders = columns.map(() => '?').join(', ');
        await db.runAsync(
          `INSERT OR IGNORE INTO ${table} (${columns.join(', ')}) VALUES (${placeholders})`,
          row as SQLite.SQLiteBindValue[]
        );
      }
    });
  }
}

export async function upsert(
  db: SQLite.SQLiteDatabase,
  table: string,
  columns: string[],
  values: unknown[]
): Promise<void> {
  const placeholders = columns.map(() => '?').join(', ');
  await db.runAsync(
    `INSERT OR REPLACE INTO ${table} (${columns.join(', ')}) VALUES (${placeholders})`,
    values as SQLite.SQLiteBindValue[]
  );
}
