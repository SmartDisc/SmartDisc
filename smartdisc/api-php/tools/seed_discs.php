<?php
// tools/seed_discs.php
// Seed-Script für feste Disc-Liste DISC-01 bis DISC-10.
// - Fügt fehlende Discs ein
// - Ändert existierende Einträge NICHT
// Aufruf von Projektroot (api-php):
//   php tools/seed_discs.php

require_once __DIR__ . '/../db.php';

// Hilfsfunktion: Disc anlegen, falls sie fehlt
function ensure_disc_exists(PDO $pdo, string $id, string $name): void {
  $check = $pdo->prepare('SELECT id FROM scheiben WHERE id = :id LIMIT 1');
  $check->execute([':id' => $id]);
  $exists = $check->fetchColumn();

  if ($exists) {
    // Nichts ändern, bestehender Datensatz bleibt wie er ist
    return;
  }

  $stmt = $pdo->prepare("
    INSERT INTO scheiben (id, name, aktiv, erstellt_am, geaendert_am)
    VALUES (:id, :name, 1, strftime('%Y-%m-%dT%H:%M:%fZ','now'), strftime('%Y-%m-%dT%H:%M:%fZ','now'))
  ");
  $stmt->execute([
    ':id' => $id,
    ':name' => $name,
  ]);
}

// Feste Liste DISC-01 .. DISC-10 anlegen
for ($i = 1; $i <= 10; $i++) {
  $id = sprintf('DISC-%02d', $i);
  $name = sprintf('Disc %d', $i);
  ensure_disc_exists($pdo, $id, $name);
}

echo "Seed completed: DISC-01 .. DISC-10 sichergestellt.\n";



