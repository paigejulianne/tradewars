<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Response;

Auth::requirePlayer();

$sinceId = (int)($_GET['since_id'] ?? 0);
$db = DB::conn();

if ($sinceId > 0) {
    $stmt = $db->prepare('SELECT * FROM events_log WHERE id > :id ORDER BY id DESC LIMIT 100');
    $stmt->execute(['id' => $sinceId]);
} else {
    $stmt = $db->query('SELECT * FROM events_log ORDER BY id DESC LIMIT 50');
}

$rows = $stmt->fetchAll();
foreach ($rows as &$r) {
    $r['data'] = $r['data'] ? json_decode($r['data'], true) : null;
}

Response::ok(['events' => array_reverse($rows)]);
