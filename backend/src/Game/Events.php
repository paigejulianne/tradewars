<?php
declare(strict_types=1);

namespace TradeWars\Game;

use TradeWars\Core\DB;

/**
 * Writes to events_log. The Go WebSocket server polls this table for new
 * rows and fans them out to connected clients in real time; it is also
 * readable directly via /api/events_recent.php for offline/poll clients.
 */
final class Events
{
    public static function log(string $type, ?int $sectorId, ?int $playerId, string $title, string $message, array $data = []): void
    {
        $stmt = DB::conn()->prepare(
            'INSERT INTO events_log (event_type, sector_id, player_id, title, message, data)
             VALUES (:t, :s, :p, :ti, :m, :d)'
        );
        $stmt->execute([
            't' => $type, 's' => $sectorId, 'p' => $playerId,
            'ti' => $title, 'm' => $message,
            'd' => json_encode($data, JSON_UNESCAPED_SLASHES),
        ]);
    }
}
