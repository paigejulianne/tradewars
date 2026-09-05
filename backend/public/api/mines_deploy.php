<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Request;
use TradeWars\Core\Response;
use TradeWars\Game\TurnManager;

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Response::error('POST required', 405);
}

$player = Auth::requirePlayer();
$player = TurnManager::maybeReset($player);
$qty = (int)Request::input('qty', 0);

if ($qty <= 0) {
    Response::error('qty must be positive');
}
if ((int)$player['equipment'] < $qty) {
    Response::error('Mines are built from Equipment cargo — you do not have enough aboard');
}
if (!TurnManager::spend($player, 1)) {
    Response::error('Not enough turns remaining', 402, ['code' => 'no_turns']);
}

$db = DB::conn();
$db->beginTransaction();
try {
    $db->prepare('UPDATE players SET equipment = equipment - :q WHERE id = :id')
        ->execute(['q' => $qty, 'id' => $player['id']]);

    $stmt = $db->prepare('SELECT id, quantity FROM mines WHERE sector_id = :s AND owner_player_id = :p');
    $stmt->execute(['s' => $player['sector_id'], 'p' => $player['id']]);
    $existing = $stmt->fetch();
    if ($existing) {
        $db->prepare('UPDATE mines SET quantity = quantity + :q WHERE id = :id')
            ->execute(['q' => $qty, 'id' => $existing['id']]);
    } else {
        $db->prepare('INSERT INTO mines (sector_id, owner_player_id, quantity) VALUES (:s, :p, :q)')
            ->execute(['s' => $player['sector_id'], 'p' => $player['id'], 'q' => $qty]);
    }
    $db->commit();
} catch (\Throwable $e) {
    $db->rollBack();
    throw $e;
}

Response::ok(['message' => "Deployed {$qty} mines in sector {$player['sector_id']}."]);
