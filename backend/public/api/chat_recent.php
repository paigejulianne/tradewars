<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Response;

$player = Auth::requirePlayer();
$scope = (string)($_GET['scope'] ?? 'galaxy');

if (!in_array($scope, ['galaxy', 'sector', 'corp'], true)) {
    Response::error('Invalid scope');
}

$db = DB::conn();
if ($scope === 'sector') {
    $stmt = $db->prepare('SELECT * FROM chat_messages WHERE scope = "sector" AND sector_id = :s ORDER BY id DESC LIMIT 50');
    $stmt->execute(['s' => $player['sector_id']]);
} elseif ($scope === 'corp') {
    if ($player['corporation_id'] === null) {
        Response::ok(['messages' => []]);
    }
    $stmt = $db->prepare('SELECT * FROM chat_messages WHERE scope = "corp" AND corporation_id = :c ORDER BY id DESC LIMIT 50');
    $stmt->execute(['c' => $player['corporation_id']]);
} else {
    $stmt = $db->query('SELECT * FROM chat_messages WHERE scope = "galaxy" ORDER BY id DESC LIMIT 50');
}

Response::ok(['messages' => array_reverse($stmt->fetchAll())]);
