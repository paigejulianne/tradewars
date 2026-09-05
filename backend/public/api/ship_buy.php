<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Request;
use TradeWars\Core\Response;
use TradeWars\Game\Galaxy;

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Response::error('POST required', 405);
}

$player = Auth::requirePlayer();
$shipTypeId = (int)Request::input('ship_type_id', 0);

$sector = Galaxy::sector((int)$player['sector_id']);
if (!$sector || !$sector['is_federation']) {
    Response::error('Ships are only sold at Stardock (Sector 1)', 400, ['code' => 'not_at_stardock']);
}

$db = DB::conn();
$stmt = $db->prepare('SELECT * FROM ship_types WHERE id = :id');
$stmt->execute(['id' => $shipTypeId]);
$shipType = $stmt->fetch();
if (!$shipType) {
    Response::error('Unknown ship class', 404);
}
if ((int)$shipType['id'] === (int)$player['ship_type_id']) {
    Response::error('You already own that ship class');
}
if ((int)$shipType['base_price'] > (int)$player['credits']) {
    Response::error('Not enough credits');
}

$db->prepare(
    'UPDATE players SET ship_type_id = :t, ship_name = :n, credits = credits - :cost,
     fighters = :f, shields = :sh, holds_total = :h,
     fuel_ore = 0, organics = 0, equipment = 0, colonists = 0
     WHERE id = :id'
)->execute([
    't' => $shipType['id'],
    'n' => $shipType['name'],
    'cost' => $shipType['base_price'],
    'f' => min(50, (int)$shipType['max_fighters']),
    'sh' => min(50, (int)$shipType['max_shields']),
    'h' => $shipType['base_holds'],
    'id' => $player['id'],
]);

Response::ok([
    'message' => "Welcome to your new {$shipType['name']}. Your old cargo was left behind at the yard.",
    'ship_type' => $shipType,
]);
