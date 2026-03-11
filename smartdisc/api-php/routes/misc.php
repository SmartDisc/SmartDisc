<?php

// GET /api/health - Simple health check (BLE/backend alignment: return only status)
if ($path === "$prefix/health") {
  json_response(['status' => 'ok']);
}

// GET /api/ping - Test endpoint
if ($path === "$prefix/ping" && $method === 'GET') {
  json_response(['status' => 'pong', 'timestamp' => date('c')]);
}
