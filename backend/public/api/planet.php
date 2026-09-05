<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Response;

$player = Auth::requirePlayer();
$id = (int)($_GET['id'] ?? 0);

$db = DB::conn();
if ($id > 0) {
    $stmt = $db->prepare('SELECT * FROM planets WHERE id = :id');
    $stmt->execute(['id' => $id]);
    $planet = $stmt->fetch();
} else {
    $stmt = $db->prepare('SELECT * FROM planets WHERE sector_id = :s LIMIT 1');
    $stmt->execute(['s' => $player['sector_id']]);
    $planet = $stmt->fetch();
}

if (!$planet) {
    Response::error('No such planet', 404);
}

Response::ok(['planet' => $planet]);
