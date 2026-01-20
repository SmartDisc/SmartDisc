<?php
// tools/seed_discs.php
// Seed-Script für feste Disc-Liste DISC-01 bis DISC-10 mit vollständigen Daten.
// - Fügt fehlende Discs ein
// - Aktualisiert bestehende Einträge mit vollständigen Daten
// Aufruf von Projektroot (api-php):
//   php tools/seed_discs.php

require_once __DIR__ . '/../db.php';

// Hilfsfunktion: Disc anlegen oder aktualisieren
function ensure_disc_exists(
  PDO $pdo, 
  string $id, 
  string $name, 
  ?string $modell = null,
  ?string $seriennummer = null,
  ?string $firmware_version = null,
  ?string $kalibrierungsdatum = null
): void {
  $check = $pdo->prepare('SELECT id FROM scheiben WHERE id = :id LIMIT 1');
  $check->execute([':id' => $id]);
  $exists = $check->fetchColumn();

  if ($exists) {
    // Aktualisiere bestehenden Eintrag
    $stmt = $pdo->prepare("
      UPDATE scheiben SET
        name = :name,
        modell = :modell,
        seriennummer = :seriennummer,
        firmware_version = :firmware_version,
        kalibrierungsdatum = :kalibrierungsdatum,
        geaendert_am = strftime('%Y-%m-%dT%H:%M:%fZ','now')
      WHERE id = :id
    ");
    $stmt->execute([
      ':id' => $id,
      ':name' => $name,
      ':modell' => $modell,
      ':seriennummer' => $seriennummer,
      ':firmware_version' => $firmware_version,
      ':kalibrierungsdatum' => $kalibrierungsdatum,
    ]);
  } else {
    // Neuen Eintrag anlegen
    $stmt = $pdo->prepare("
      INSERT INTO scheiben (
        id, name, modell, seriennummer, firmware_version, kalibrierungsdatum, 
        aktiv, erstellt_am, geaendert_am
      )
      VALUES (
        :id, :name, :modell, :seriennummer, :firmware_version, :kalibrierungsdatum,
        1, strftime('%Y-%m-%dT%H:%M:%fZ','now'), strftime('%Y-%m-%dT%H:%M:%fZ','now')
      )
    ");
    $stmt->execute([
      ':id' => $id,
      ':name' => $name,
      ':modell' => $modell,
      ':seriennummer' => $seriennummer,
      ':firmware_version' => $firmware_version,
      ':kalibrierungsdatum' => $kalibrierungsdatum,
    ]);
  }
}

// Disc-Daten: 10 Discs mit individuellen Daten
$discs = [
  [
    'id' => 'DISC-01',
    'name' => 'DISC-01',
    'modell' => 'SmartDisc Pro',
    'seriennummer' => 'SN-2024-001',
    'firmware_version' => 'v2.1.0',
    'kalibrierungsdatum' => '2024-01-15T10:30:00Z',
  ],
  [
    'id' => 'DISC-02',
    'name' => 'DISC-02',
    'modell' => 'SmartDisc Pro',
    'seriennummer' => 'SN-2024-002',
    'firmware_version' => 'v2.1.0',
    'kalibrierungsdatum' => '2024-01-20T14:15:00Z',
  ],
  [
    'id' => 'DISC-03',
    'name' => 'DISC-03',
    'modell' => 'SmartDisc Lite',
    'seriennummer' => 'SN-2024-003',
    'firmware_version' => 'v2.0.5',
    'kalibrierungsdatum' => '2024-02-01T09:00:00Z',
  ],
  [
    'id' => 'DISC-04',
    'name' => 'DISC-04',
    'modell' => 'SmartDisc Pro',
    'seriennummer' => 'SN-2024-004',
    'firmware_version' => 'v2.1.2',
    'kalibrierungsdatum' => '2024-02-10T11:45:00Z',
  ],
  [
    'id' => 'DISC-05',
    'name' => 'DISC-05',
    'modell' => 'SmartDisc Standard',
    'seriennummer' => 'SN-2024-005',
    'firmware_version' => 'v2.0.8',
    'kalibrierungsdatum' => '2024-02-18T16:20:00Z',
  ],
  [
    'id' => 'DISC-06',
    'name' => 'DISC-06',
    'modell' => 'SmartDisc Pro',
    'seriennummer' => 'SN-2024-006',
    'firmware_version' => 'v2.1.0',
    'kalibrierungsdatum' => '2024-03-05T08:30:00Z',
  ],
  [
    'id' => 'DISC-07',
    'name' => 'DISC-07',
    'modell' => 'SmartDisc Lite',
    'seriennummer' => 'SN-2024-007',
    'firmware_version' => 'v2.0.5',
    'kalibrierungsdatum' => '2024-03-12T13:10:00Z',
  ],
  [
    'id' => 'DISC-08',
    'name' => 'DISC-08',
    'modell' => 'SmartDisc Standard',
    'seriennummer' => 'SN-2024-008',
    'firmware_version' => 'v2.0.8',
    'kalibrierungsdatum' => '2024-03-20T15:00:00Z',
  ],
  [
    'id' => 'DISC-09',
    'name' => 'DISC-09',
    'modell' => 'SmartDisc Pro',
    'seriennummer' => 'SN-2024-009',
    'firmware_version' => 'v2.1.2',
    'kalibrierungsdatum' => '2024-04-01T10:00:00Z',
  ],
  [
    'id' => 'DISC-10',
    'name' => 'DISC-10',
    'modell' => 'SmartDisc Standard',
    'seriennummer' => 'SN-2024-010',
    'firmware_version' => 'v2.0.8',
    'kalibrierungsdatum' => '2024-04-10T12:30:00Z',
  ],
];

// Alle Discs anlegen
foreach ($discs as $disc) {
  ensure_disc_exists(
    $pdo,
    $disc['id'],
    $disc['name'],
    $disc['modell'],
    $disc['seriennummer'],
    $disc['firmware_version'],
    $disc['kalibrierungsdatum']
  );
}

echo "Seed completed: DISC-01 .. DISC-10 mit vollständigen Daten sichergestellt.\n";



