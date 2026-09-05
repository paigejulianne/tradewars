<?php
declare(strict_types=1);

namespace TradeWars\Game;

use TradeWars\Core\DB;

final class PlayerOps
{
    /** Destroys a player's ship: reset to starting Merchant Cruiser at Stardock, cargo lost. */
    public static function pod(int $playerId): void
    {
        DB::conn()->prepare(
            'UPDATE players SET ship_type_id = 1, ship_name = "Merchant Cruiser", sector_id = 1,
             fighters = 20, shields = 100, holds_total = 20,
             fuel_ore = 0, organics = 0, equipment = 0, colonists = 0, cloak = 0
             WHERE id = :id'
        )->execute(['id' => $playerId]);
    }
}
