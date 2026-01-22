<?php

// GET /api/health
if ($path === "$prefix/health") {
  json_response(['status' => 'ok', 'db' => 'up', 'timestamp' => date('c')]);
}

// GET /api/ping - Test endpoint
if ($path === "$prefix/ping" && $method === 'GET') {
  json_response(['status' => 'pong', 'timestamp' => date('c')]);
}
