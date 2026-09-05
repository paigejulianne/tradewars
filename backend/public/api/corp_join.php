<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Request;
use TradeWars\Core\Response;

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Response::error('POST required', 405);
}

$player = Auth::requirePlayer();
if ($player['corporation_id'] !== null) {
    Response::error('You already belong to a corporation', 409);
}

$corpId = (int)Request::input('corporation_id', 0);
$db = DB::conn();
$stmt = $db->prepare('SELECT id FROM corporations WHERE id = :id');
$stmt->execute(['id' => $corpId]);
if (!$stmt->fetch()) {
    Response::error('No such corporation', 404);
}

$db->beginTransaction();
try {
    $db->prepare('UPDATE players SET corporation_id = :c WHERE id = :id')
        ->execute(['c' => $corpId, 'id' => $player['id']]);
    $db->prepare('INSERT INTO corporation_members (corporation_id, player_id, role) VALUES (:c, :p, "member")')
        ->execute(['c' => $corpId, 'p' => $player['id']]);
    $db->commit();
} catch (\Throwable $e) {
    $db->rollBack();
    throw $e;
}

Response::ok();
