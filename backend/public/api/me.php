<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\Response;
use TradeWars\Game\TurnManager;

$user = Auth::requireUser();
$player = Auth::requirePlayer();
$player = TurnManager::maybeReset($player);

Response::ok(['player' => $player, 'user' => [
    'id' => (int)$user['id'], 'email' => $user['email'], 'is_admin' => (bool)$user['is_admin'],
]]);
