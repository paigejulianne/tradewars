<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Request;
use TradeWars\Core\Response;

const ALLOWED = ['fuel_ore', 'organics', 'equipment', 'colonists'];

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Response::error('POST required', 405);
}

$player = Auth::requirePlayer();
$commodity = (string)Request::input('commodity', '');
$qty = (int)Request::input('qty', 0);

if (!in_array($commodity, ALLOWED, true) || $qty <= 0) {
    Response::error('Invalid commodity or quantity');
}

$db = DB::conn();
$stmt = $db->prepare('SELECT * FROM planets WHERE sector_id = :s LIMIT 1');
$stmt->execute(['s' => $player['sector_id']]);
$planet = $stmt->fetch();

if (!$planet) {
    Response::error('There is no planet in this sector', 404);
}
if ((int)$planet['owner_player_id'] !== (int)$player['id']) {
    Response::error('You do not own this planet', 403);
}
if ((int)$player[$commodity] < $qty) {
    Response::error('You do not have that much aboard');
}

$planetColumn = $commodity === 'colonists' ? 'colonists' : "{$commodity}_stock";
$cap = $commodity === 'colonists' ? (int)$planet['max_colonists'] : PHP_INT_MAX;
$newPlanetQty = min($cap, (int)$planet[$planetColumn] + $qty);
$actuallyMoved = $newPlanetQty - (int)$planet[$planetColumn];

$db->beginTransaction();
try {
    $db->prepare("UPDATE planets SET {$planetColumn} = :v WHERE id = :id")
        ->execute(['v' => $newPlanetQty, 'id' => $planet['id']]);
    $db->prepare("UPDATE players SET {$commodity} = {$commodity} - :q WHERE id = :id")
        ->execute(['q' => $actuallyMoved, 'id' => $player['id']]);
    $db->commit();
} catch (\Throwable $e) {
    $db->rollBack();
    throw $e;
}

Response::ok(['deposited' => $actuallyMoved, 'planet_total' => $newPlanetQty]);
