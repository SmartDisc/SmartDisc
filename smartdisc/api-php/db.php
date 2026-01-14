<?php
$DB_FILE = __DIR__ . '/data/smartdisc.sqlite';
if (!is_dir(__DIR__ . '/data')) { mkdir(__DIR__ . '/data', 0777, true); }
try {
  $pdo = new PDO('sqlite:' . $DB_FILE, null, null, [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
  ]);
  // Foreign Key Constraints aktivieren
  $pdo->exec('PRAGMA foreign_keys = ON');
} catch (Exception $e) {
  http_response_code(500);
  header('Content-Type: application/json');
  echo json_encode(['error' => ['code'=>'DB_CONNECT_ERROR','message'=>$e->getMessage()]]);
  exit;
}

$pdo->exec("
CREATE TABLE IF NOT EXISTS wurfe (
    id TEXT PRIMARY KEY,
    scheibe_id TEXT NOT NULL,
    player_id TEXT,
    rotation REAL,
    hoehe REAL,
    acceleration_max REAL,
    erstellt_am TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
    geaendert_am TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
    version INTEGER DEFAULT 1 NOT NULL,
    geloescht INTEGER DEFAULT 0 NOT NULL,
    geloescht_am TEXT,
    FOREIGN KEY (scheibe_id) REFERENCES scheiben(id)
);

-- Table for audit log
CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tabelle TEXT NOT NULL,
    datensatz_id TEXT NOT NULL,
    operation TEXT NOT NULL,
    alte_daten TEXT,
    neue_daten TEXT,
    benutzer TEXT,
    zeitpunkt TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
    ip_adresse TEXT,
    user_agent TEXT
);

-- Table for discs/measurement systems
CREATE TABLE IF NOT EXISTS scheiben (
    id TEXT PRIMARY KEY,
    name TEXT,
    modell TEXT,
    seriennummer TEXT,
    firmware_version TEXT,
    kalibrierungsdatum TEXT,
    aktiv INTEGER DEFAULT 1 NOT NULL,
    erstellt_am TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
    geaendert_am TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL
);

-- Table for users
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('player','trainer')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- Table for auth tokens
CREATE TABLE IF NOT EXISTS auth_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_wurfe_scheibe_id ON wurfe(scheibe_id);
CREATE INDEX IF NOT EXISTS idx_wurfe_erstellt_am ON wurfe(erstellt_am);
CREATE INDEX IF NOT EXISTS idx_wurfe_player_id ON wurfe(player_id);
CREATE INDEX IF NOT EXISTS idx_wurfe_geloescht ON wurfe(geloescht);
CREATE INDEX IF NOT EXISTS idx_audit_log_tabelle_id ON audit_log(tabelle, datensatz_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_zeitpunkt ON audit_log(zeitpunkt);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_auth_tokens_token ON auth_tokens(token);
CREATE INDEX IF NOT EXISTS idx_auth_tokens_user_id ON auth_tokens(user_id);

-- Table for highscores (best values per user)
CREATE TABLE IF NOT EXISTS highscores (
    user_id TEXT PRIMARY KEY,
    best_rotation REAL,
    best_hoehe REAL,
    best_acceleration_max REAL,
    updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_highscores_user_id ON highscores(user_id);

-- Triggers for automatic audit logging
CREATE TRIGGER IF NOT EXISTS trigger_wurfe_update AFTER UPDATE ON wurfe
BEGIN
    INSERT INTO audit_log (tabelle, datensatz_id, operation, alte_daten, neue_daten, zeitpunkt)
    VALUES ('wurfe', NEW.id, 'UPDATE', 
        json_object('id', OLD.id, 'scheibe_id', OLD.scheibe_id, 'version', OLD.version),
        json_object('id', NEW.id, 'scheibe_id', NEW.scheibe_id, 'version', NEW.version),
        strftime('%Y-%m-%dT%H:%M:%fZ','now'));
END;

CREATE TRIGGER IF NOT EXISTS trigger_wurfe_insert AFTER INSERT ON wurfe
BEGIN
    INSERT INTO audit_log (tabelle, datensatz_id, operation, neue_daten, zeitpunkt)
    VALUES ('wurfe', NEW.id, 'INSERT', 
        json_object('id', NEW.id, 'scheibe_id', NEW.scheibe_id, 'version', NEW.version),
        strftime('%Y-%m-%dT%H:%M:%fZ','now'));
END;

CREATE TRIGGER IF NOT EXISTS trigger_wurfe_delete AFTER UPDATE ON wurfe WHEN NEW.geloescht = 1 AND OLD.geloescht = 0
BEGIN
    UPDATE wurfe SET geloescht_am = strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = NEW.id;
    INSERT INTO audit_log (tabelle, datensatz_id, operation, alte_daten, neue_daten, zeitpunkt)
    VALUES ('wurfe', NEW.id, 'DELETE', 
        json_object('id', OLD.id, 'scheibe_id', OLD.scheibe_id),
        json_object('id', NEW.id, 'geloescht', NEW.geloescht, 'geloescht_am', NEW.geloescht_am),
        strftime('%Y-%m-%dT%H:%M:%fZ','now'));
END;");
