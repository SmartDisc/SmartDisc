<?php
// Migration Script für Datenbankschema
$DB_FILE = __DIR__ . '/data/smartdisc.sqlite';
if (!file_exists($DB_FILE)) {
    echo "Datenbank existiert nicht. Wird beim ersten API-Aufruf erstellt.\n";
    exit(0);
}

try {
    $pdo = new PDO('sqlite:' . $DB_FILE, null, null, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    
    echo "Migriere Datenbankschema...\n";
    
    // Prüfe welche Spalten bereits existieren
    $wurfeColumns = $pdo->query("PRAGMA table_info(wurfe)")->fetchAll(PDO::FETCH_COLUMN, 1);
    $messungenColumns = $pdo->query("PRAGMA table_info(messungen)")->fetchAll(PDO::FETCH_COLUMN, 1);
    
    // Migriere wurfe Tabelle
    $alterStatements = [];
    if (!in_array('player_id', $wurfeColumns)) {
        $alterStatements[] = "ALTER TABLE wurfe ADD COLUMN player_id TEXT";
    }
    if (!in_array('rotation', $wurfeColumns)) {
        $alterStatements[] = "ALTER TABLE wurfe ADD COLUMN rotation REAL";
    }
    if (!in_array('hoehe', $wurfeColumns)) {
        $alterStatements[] = "ALTER TABLE wurfe ADD COLUMN hoehe REAL";
    }
    if (!in_array('start_zeitpunkt', $wurfeColumns)) {
        $alterStatements[] = "ALTER TABLE wurfe ADD COLUMN start_zeitpunkt TEXT";
    }
    if (!in_array('end_zeitpunkt', $wurfeColumns)) {
        $alterStatements[] = "ALTER TABLE wurfe ADD COLUMN end_zeitpunkt TEXT";
    }
    if (!in_array('dauer_sekunden', $wurfeColumns)) {
        $alterStatements[] = "ALTER TABLE wurfe ADD COLUMN dauer_sekunden REAL";
    }
    if (!in_array('geaendert_am', $wurfeColumns)) {
        $alterStatements[] = "ALTER TABLE wurfe ADD COLUMN geaendert_am TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))";
    }
    if (!in_array('version', $wurfeColumns)) {
        $alterStatements[] = "ALTER TABLE wurfe ADD COLUMN version INTEGER DEFAULT 1";
    }
    if (!in_array('geloescht', $wurfeColumns)) {
        $alterStatements[] = "ALTER TABLE wurfe ADD COLUMN geloescht INTEGER DEFAULT 0";
    }
    if (!in_array('geloescht_am', $wurfeColumns)) {
        $alterStatements[] = "ALTER TABLE wurfe ADD COLUMN geloescht_am TEXT";
    }
    if (!in_array('zusaetzliche_daten', $wurfeColumns)) {
        $alterStatements[] = "ALTER TABLE wurfe ADD COLUMN zusaetzliche_daten TEXT";
    }
    
    foreach ($alterStatements as $stmt) {
        try {
            $pdo->exec($stmt);
            echo "✓ $stmt\n";
        } catch (Exception $e) {
            echo "⚠ Warnung: $stmt - " . $e->getMessage() . "\n";
        }
    }
    
    // Migriere messungen Tabelle
    $alterStatements = [];
    if (!in_array('sequenz_nr', $messungenColumns)) {
        // Zuerst temporäre Spalte hinzufügen
        try {
            $pdo->exec("ALTER TABLE messungen ADD COLUMN sequenz_nr INTEGER");
            // Bestehende Messungen mit sequenz_nr versehen
            $pdo->exec("UPDATE messungen SET sequenz_nr = (SELECT COUNT(*) FROM messungen m2 WHERE m2.wurf_id = messungen.wurf_id AND m2.rowid <= messungen.rowid) - 1 WHERE sequenz_nr IS NULL");
        } catch (Exception $e) {
            echo "⚠ Warnung beim Hinzufügen von sequenz_nr: " . $e->getMessage() . "\n";
        }
    }
    
    $newColumns = [
        'gyroskop_x' => 'REAL',
        'gyroskop_y' => 'REAL',
        'gyroskop_z' => 'REAL',
        'magnetometer_x' => 'REAL',
        'magnetometer_y' => 'REAL',
        'magnetometer_z' => 'REAL',
        'luftdruck' => 'REAL',
        'gps_breitengrad' => 'REAL',
        'gps_laengengrad' => 'REAL',
        'gps_hoehe' => 'REAL',
        'erstellt_am' => "TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))"
    ];
    
    foreach ($newColumns as $col => $type) {
        if (!in_array($col, $messungenColumns)) {
            try {
                $pdo->exec("ALTER TABLE messungen ADD COLUMN $col $type");
                echo "✓ ALTER TABLE messungen ADD COLUMN $col\n";
            } catch (Exception $e) {
                echo "⚠ Warnung: $col - " . $e->getMessage() . "\n";
            }
        }
    }
    
    // Erstelle neue Tabellen falls nicht vorhanden
    $pdo->exec("
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
    ");
    echo "✓ Neue Tabellen erstellt\n";
    
    // Indizes erstellen
    $indexes = [
        "CREATE INDEX IF NOT EXISTS idx_wurfe_scheibe_id ON wurfe(scheibe_id)",
        "CREATE INDEX IF NOT EXISTS idx_wurfe_erstellt_am ON wurfe(erstellt_am)",
        "CREATE INDEX IF NOT EXISTS idx_wurfe_player_id ON wurfe(player_id)",
        "CREATE INDEX IF NOT EXISTS idx_wurfe_geloescht ON wurfe(geloescht)",
        "CREATE INDEX IF NOT EXISTS idx_messungen_wurf_id ON messungen(wurf_id)",
        "CREATE INDEX IF NOT EXISTS idx_messungen_zeitpunkt ON messungen(zeitpunkt)",
        "CREATE INDEX IF NOT EXISTS idx_messungen_sequenz ON messungen(wurf_id, sequenz_nr)",
        "CREATE INDEX IF NOT EXISTS idx_audit_log_tabelle_id ON audit_log(tabelle, datensatz_id)",
        "CREATE INDEX IF NOT EXISTS idx_audit_log_zeitpunkt ON audit_log(zeitpunkt)"
    ];
    
    foreach ($indexes as $idx) {
        try {
            $pdo->exec($idx);
        } catch (Exception $e) {
            echo "⚠ Warnung bei Index: " . $e->getMessage() . "\n";
        }
    }
    echo "✓ Indizes erstellt\n";
    
    // Trigger nur erstellen wenn sie nicht existieren
    // (SQLite unterstützt kein IF NOT EXISTS für Trigger)
    try {
        $existingTriggers = $pdo->query("SELECT name FROM sqlite_master WHERE type='trigger'")->fetchAll(PDO::FETCH_COLUMN);
        
        if (!in_array('trigger_wurfe_update', $existingTriggers)) {
            $pdo->exec("
            CREATE TRIGGER trigger_wurfe_update AFTER UPDATE ON wurfe
            BEGIN
                INSERT INTO audit_log (tabelle, datensatz_id, operation, alte_daten, neue_daten, zeitpunkt)
                VALUES ('wurfe', NEW.id, 'UPDATE', 
                    json_object('id', OLD.id, 'scheibe_id', OLD.scheibe_id, 'entfernung', OLD.entfernung, 
                               'geschwindigkeit', OLD.geschwindigkeit, 'version', OLD.version),
                    json_object('id', NEW.id, 'scheibe_id', NEW.scheibe_id, 'entfernung', NEW.entfernung, 
                               'geschwindigkeit', NEW.geschwindigkeit, 'version', NEW.version),
                    strftime('%Y-%m-%dT%H:%M:%fZ','now'));
            END;
            ");
            echo "✓ Trigger erstellt\n";
        }
    } catch (Exception $e) {
        echo "⚠ Warnung bei Trigger: " . $e->getMessage() . "\n";
    }
    
    echo "\nMigration abgeschlossen!\n";
    
} catch (Exception $e) {
    echo "Fehler: " . $e->getMessage() . "\n";
    exit(1);
}

