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
// Revisionssichere Datenbankstruktur mit vollständiger Nachvollziehbarkeit
$pdo->exec("
-- Tabelle für Wurfdaten mit Revisionssicherheit
CREATE TABLE IF NOT EXISTS wurfe (
    id TEXT PRIMARY KEY,
    scheibe_id TEXT NOT NULL,
    player_id TEXT,
    entfernung REAL,
    geschwindigkeit REAL,
    rotation REAL,
    hoehe REAL,
    start_zeitpunkt TEXT,
    end_zeitpunkt TEXT,
    dauer_sekunden REAL,
    erstellt_am TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
    geaendert_am TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
    version INTEGER DEFAULT 1 NOT NULL,
    geloescht INTEGER DEFAULT 0 NOT NULL,
    geloescht_am TEXT,
    zusaetzliche_daten TEXT,
    FOREIGN KEY (scheibe_id) REFERENCES scheiben(id)
);

-- Tabelle für Sensormessungen mit vollständiger Zeitstempelung
CREATE TABLE IF NOT EXISTS messungen (
    id TEXT PRIMARY KEY,
    wurf_id TEXT NOT NULL,
    zeitpunkt TEXT NOT NULL,
    sequenz_nr INTEGER NOT NULL,
    beschleunigung_x REAL,
    beschleunigung_y REAL,
    beschleunigung_z REAL,
    gyroskop_x REAL,
    gyroskop_y REAL,
    gyroskop_z REAL,
    magnetometer_x REAL,
    magnetometer_y REAL,
    magnetometer_z REAL,
    temperatur REAL,
    luftdruck REAL,
    gps_breitengrad REAL,
    gps_laengengrad REAL,
    gps_hoehe REAL,
    erstellt_am TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
    FOREIGN KEY (wurf_id) REFERENCES wurfe(id),
    UNIQUE(wurf_id, sequenz_nr)
);

-- Tabelle für Audit-Log (Revision-Historie)
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

-- Tabelle für Scheiben/Messsysteme
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

-- Tabelle für Benutzer
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('player','trainer')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- Tabelle für Auth-Tokens
CREATE TABLE IF NOT EXISTS auth_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Indizes für bessere Performance
CREATE INDEX IF NOT EXISTS idx_wurfe_scheibe_id ON wurfe(scheibe_id);
CREATE INDEX IF NOT EXISTS idx_wurfe_erstellt_am ON wurfe(erstellt_am);
CREATE INDEX IF NOT EXISTS idx_wurfe_player_id ON wurfe(player_id);
CREATE INDEX IF NOT EXISTS idx_wurfe_geloescht ON wurfe(geloescht);
CREATE INDEX IF NOT EXISTS idx_messungen_wurf_id ON messungen(wurf_id);
CREATE INDEX IF NOT EXISTS idx_messungen_zeitpunkt ON messungen(zeitpunkt);
CREATE INDEX IF NOT EXISTS idx_messungen_sequenz ON messungen(wurf_id, sequenz_nr);
CREATE INDEX IF NOT EXISTS idx_audit_log_tabelle_id ON audit_log(tabelle, datensatz_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_zeitpunkt ON audit_log(zeitpunkt);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_auth_tokens_token ON auth_tokens(token);
CREATE INDEX IF NOT EXISTS idx_auth_tokens_user_id ON auth_tokens(user_id);

-- Trigger für automatisches Audit-Logging bei Änderungen
CREATE TRIGGER IF NOT EXISTS trigger_wurfe_update AFTER UPDATE ON wurfe
BEGIN
    INSERT INTO audit_log (tabelle, datensatz_id, operation, alte_daten, neue_daten, zeitpunkt)
    VALUES ('wurfe', NEW.id, 'UPDATE', 
        json_object('id', OLD.id, 'scheibe_id', OLD.scheibe_id, 'entfernung', OLD.entfernung, 
                   'geschwindigkeit', OLD.geschwindigkeit, 'version', OLD.version),
        json_object('id', NEW.id, 'scheibe_id', NEW.scheibe_id, 'entfernung', NEW.entfernung, 
                   'geschwindigkeit', NEW.geschwindigkeit, 'version', NEW.version),
        strftime('%Y-%m-%dT%H:%M:%fZ','now'));
END;

CREATE TRIGGER IF NOT EXISTS trigger_wurfe_insert AFTER INSERT ON wurfe
BEGIN
    INSERT INTO audit_log (tabelle, datensatz_id, operation, neue_daten, zeitpunkt)
    VALUES ('wurfe', NEW.id, 'INSERT', 
        json_object('id', NEW.id, 'scheibe_id', NEW.scheibe_id, 'entfernung', NEW.entfernung, 
                   'geschwindigkeit', NEW.geschwindigkeit, 'version', NEW.version),
        strftime('%Y-%m-%dT%H:%M:%fZ','now'));
END;

CREATE TRIGGER IF NOT EXISTS trigger_wurfe_delete AFTER UPDATE ON wurfe WHEN NEW.geloescht = 1 AND OLD.geloescht = 0
BEGIN
    UPDATE wurfe SET geloescht_am = strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = NEW.id;
    INSERT INTO audit_log (tabelle, datensatz_id, operation, alte_daten, neue_daten, zeitpunkt)
    VALUES ('wurfe', NEW.id, 'DELETE', 
        json_object('id', OLD.id, 'scheibe_id', OLD.scheibe_id, 'entfernung', OLD.entfernung),
        json_object('id', NEW.id, 'geloescht', NEW.geloescht, 'geloescht_am', NEW.geloescht_am),
        strftime('%Y-%m-%dT%H:%M:%fZ','now'));
END;");
