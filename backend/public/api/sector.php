<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Response;
use TradeWars\Game\Economy;
use TradeWars\Game\Galaxy;
use TradeWars\Game\TurnManager;

$player = Auth::requirePlayer();
$player = TurnManager::maybeReset($player);

$sectorId = (int)$player['sector_id'];
$sector = Galaxy::sector($sectorId);
if (!$sector) {
    Response::error('Current sector not found', 500);
}

$db = DB::conn();

$warps = Galaxy::warpsFrom($sectorId);

$stmt = $db->prepare('SELECT * FROM ports WHERE sector_id = :s');
$stmt->execute(['s' => $sectorId]);
$port = $stmt->fetch();
if ($port) {
    $port = Economy::regen($port);
}

$stmt = $db->prepare(
    'SELECT id, handle, ship_name, ship_type_id, fighters, shields, corporation_id
     FROM players WHERE sector_id = :s AND id != :me AND is_alive = 1'
);
$stmt->execute(['s' => $sectorId, 'me' => $player['id']]);
$otherPlayers = $stmt->fetchAll();

$stmt = $db->prepare('SELECT * FROM planets WHERE sector_id = :s');
$stmt->execute(['s' => $sectorId]);
$planets = $stmt->fetchAll();

$stmt = $db->prepare('SELECT * FROM npc_ships WHERE sector_id = :s');
$stmt->execute(['s' => $sectorId]);
$npcs = $stmt->fetchAll();

$stmt = $db->prepare(
    'SELECT owner_player_id, SUM(quantity) AS total FROM mines WHERE sector_id = :s GROUP BY owner_player_id'
);
$stmt->execute(['s' => $sectorId]);
$mines = $stmt->fetchAll();

$stmt = $db->prepare(
    'SELECT handle, message, created_at FROM chat_messages
     WHERE scope = "sector" AND sector_id = :s ORDER BY id DESC LIMIT 30'
);
$stmt->execute(['s' => $sectorId]);
$chat = array_reverse($stmt->fetchAll());

Response::ok([
    'sector' => $sector,
    'warps' => $warps,
    'port' => $port ?: null,
    'players' => $otherPlayers,
    'planets' => $planets,
    'npcs' => $npcs,
    'mines' => $mines,
    'chat' => $chat,
    'me' => $player,
]);
