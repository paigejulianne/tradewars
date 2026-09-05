<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Request;
use TradeWars\Core\Response;
use TradeWars\Game\Galaxy;

const COSTS = ['fighters' => 50, 'shields' => 30, 'holds' => 2000];

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Response::error('POST required', 405);
}

$player = Auth::requirePlayer();
$stat = (string)Request::input('stat', '');
$qty = (int)Request::input('qty', 0);

if (!array_key_exists($stat, COSTS)) {
    Response::error('stat must be one of: fighters, shields, holds');
}
if ($qty <= 0) {
    Response::error('qty must be positive');
}

$sector = Galaxy::sector((int)$player['sector_id']);
if (!$sector || !$sector['is_federation']) {
    Response::error('Ship upgrades are only available at Stardock (Sector 1)', 400, ['code' => 'not_at_stardock']);
}

$db = DB::conn();
$stmt = $db->prepare('SELECT * FROM ship_types WHERE id = :id');
$stmt->execute(['id' => $player['ship_type_id']]);
$shipType = $stmt->fetch();

$column = $stat === 'holds' ? 'holds_total' : $stat;
$max = $stat === 'holds' ? (int)$shipType['max_holds'] : (int)$shipType["max_{$stat}"];
$current = (int)$player[$column];

if ($current + $qty > $max) {
    $qty = $max - $current;
}
if ($qty <= 0) {
    Response::error('Already at maximum for your ship class', 400, ['code' => 'at_max']);
}

$cost = $qty * COSTS[$stat];
if ($cost > (int)$player['credits']) {
    Response::error('Not enough credits');
}

$db->prepare("UPDATE players SET {$column} = {$column} + :qty, credits = credits - :cost WHERE id = :id")
    ->execute(['qty' => $qty, 'cost' => $cost, 'id' => $player['id']]);

Response::ok([
    'stat' => $stat,
    'new_value' => $current + $qty,
    'credits_spent' => $cost,
]);
