<?php
declare(strict_types=1);

namespace TradeWars\Game;

use TradeWars\Core\DB;
use TradeWars\Core\Config;

final class TurnManager
{
    /** Lazily resets a player's turns if their last reset was on a previous UTC day. Returns fresh player row. */
    public static function maybeReset(array $player): array
    {
        $resetAt = new \DateTimeImmutable($player['turns_reset_at'], new \DateTimeZone('UTC'));
        $now = new \DateTimeImmutable('now', new \DateTimeZone('UTC'));
        if ($resetAt->format('Y-m-d') === $now->format('Y-m-d')) {
            return $player;
        }
        $app = Config::get('app');
        $stmt = DB::conn()->prepare(
            'UPDATE players SET turns_remaining = :turns, turns_reset_at = NOW() WHERE id = :id'
        );
        $stmt->execute(['turns' => $app['daily_turn_reset'], 'id' => $player['id']]);
        $player['turns_remaining'] = $app['daily_turn_reset'];
        return $player;
    }

    public static function spend(array $player, int $amount): bool
    {
        if ((int)$player['turns_remaining'] < $amount) {
            return false;
        }
        $stmt = DB::conn()->prepare('UPDATE players SET turns_remaining = turns_remaining - :a WHERE id = :id');
        $stmt->execute(['a' => $amount, 'id' => $player['id']]);
        return true;
    }
}
