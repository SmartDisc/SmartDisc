<?php
// Audit Helper Functions

function get_client_ip() {
  return $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['HTTP_X_REAL_IP'] ?? $_SERVER['REMOTE_ADDR'] ?? 'unknown';
}

function log_audit($tabelle, $datensatz_id, $operation, $alte_daten = null, $neue_daten = null) {
  global $pdo;
  $stmt = $pdo->prepare("
    INSERT INTO audit_log (tabelle, datensatz_id, operation, alte_daten, neue_daten, ip_adresse, user_agent, zeitpunkt)
    VALUES (:tabelle, :datensatz_id, :operation, :alte_daten, :neue_daten, :ip, :ua, strftime('%Y-%m-%dT%H:%M:%fZ','now'))
  ");
  $stmt->execute([
    ':tabelle' => $tabelle,
    ':datensatz_id' => $datensatz_id,
    ':operation' => $operation,
    ':alte_daten' => $alte_daten ? json_encode($alte_daten) : null,
    ':neue_daten' => $neue_daten ? json_encode($neue_daten) : null,
    ':ip' => get_client_ip(),
    ':ua' => $_SERVER['HTTP_USER_AGENT'] ?? null
  ]);
}

