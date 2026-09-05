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

$name = trim((string)Request::input('name', ''));
$tag = strtoupper(trim((string)Request::input('tag', '')));

if (!preg_match('/^[A-Za-z0-9 \-\'\.]{3,64}$/', $name)) {
    Response::error('Name must be 3-64 characters');
}
if (!preg_match('/^[A-Z0-9]{2,8}$/', $tag)) {
    Response::error('Tag must be 2-8 letters/numbers');
}

$db = DB::conn();
$db->beginTransaction();
try {
    $db->prepare('INSERT INTO corporations (name, tag, founder_player_id) VALUES (:n, :t, :f)')
        ->execute(['n' => $name, 't' => $tag, 'f' => $player['id']]);
    $corpId = (int)$db->lastInsertId();

    $db->prepare('UPDATE players SET corporation_id = :c WHERE id = :id')
        ->execute(['c' => $corpId, 'id' => $player['id']]);

    $db->prepare('INSERT INTO corporation_members (corporation_id, player_id, role) VALUES (:c, :p, "founder")')
        ->execute(['c' => $corpId, 'p' => $player['id']]);

    $db->commit();
} catch (\Throwable $e) {
    $db->rollBack();
    if ($e->getCode() === '23000') {
        Response::error('That corporation name or tag is already taken', 409);
    }
    throw $e;
}

Response::ok(['corporation_id' => $corpId]);
