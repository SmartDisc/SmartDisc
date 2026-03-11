<?php

// SQLite database - no server needed
$dbPath = __DIR__ . '/data/smartdisc.db';
$dbDir = dirname($dbPath);
if (!is_dir($dbDir)) {
    mkdir($dbDir, 0755, true);
}

try {
    $pdo = new PDO(
        "sqlite:$dbPath",
        null,
        null,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );
} catch (Exception $e) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'error' => [
            'code' => 'DB_CONNECT_ERROR',
            'message' => $e->getMessage()
        ]
    ]);
    exit;
}

$pdo->exec("
CREATE TABLE IF NOT EXISTS scheiben (
    id TEXT PRIMARY KEY,
    name TEXT,
    modell TEXT,
    seriennummer TEXT,
    firmware_version TEXT,
    kalibrierungsdatum TEXT,
    aktiv INTEGER NOT NULL DEFAULT 1,
    erstellt_am TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    geaendert_am TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('player', 'trainer')),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS trainer_requests (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    decided_at TEXT,
    approval_token TEXT NOT NULL UNIQUE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS auth_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS disc_assignments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    disc_id TEXT NOT NULL,
    player_id TEXT NOT NULL,
    assigned_by TEXT,
    assigned_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (disc_id, player_id),
    FOREIGN KEY (disc_id) REFERENCES scheiben(id) ON DELETE CASCADE,
    FOREIGN KEY (player_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_by) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS wurfe (
    id TEXT PRIMARY KEY,
    scheibe_id TEXT NOT NULL,
    player_id TEXT,
    rotation REAL,
    hoehe REAL,
    acceleration_x REAL,
    acceleration_y REAL,
    acceleration_z REAL,
    acceleration_max REAL,
    erstellt_am TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    geaendert_am TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version INTEGER NOT NULL DEFAULT 1,
    geloescht INTEGER NOT NULL DEFAULT 0,
    geloescht_am TEXT,
    FOREIGN KEY (scheibe_id) REFERENCES scheiben(id),
    FOREIGN KEY (player_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tabelle TEXT NOT NULL,
    datensatz_id TEXT NOT NULL,
    operation TEXT NOT NULL,
    alte_daten TEXT,
    neue_daten TEXT,
    benutzer TEXT,
    zeitpunkt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_adresse TEXT,
    user_agent TEXT
);

CREATE TABLE IF NOT EXISTS highscores (
    user_id TEXT PRIMARY KEY,
    best_rotation REAL,
    best_hoehe REAL,
    best_acceleration_max REAL,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

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

CREATE INDEX IF NOT EXISTS idx_disc_assignments_player_id ON disc_assignments(player_id);
CREATE INDEX IF NOT EXISTS idx_disc_assignments_disc_id ON disc_assignments(disc_id);

CREATE INDEX IF NOT EXISTS idx_highscores_user_id ON highscores(user_id);
");
