<?php
declare(strict_types=1);

namespace TradeWars\Game;

use TradeWars\Core\DB;

final class Galaxy
{
    public static function warpsFrom(int $sectorId): array
    {
        $stmt = DB::conn()->prepare('SELECT to_sector FROM warps WHERE from_sector = :s ORDER BY to_sector');
        $stmt->execute(['s' => $sectorId]);
        return array_map('intval', array_column($stmt->fetchAll(), 'to_sector'));
    }

    public static function isAdjacent(int $from, int $to): bool
    {
        $stmt = DB::conn()->prepare(
            'SELECT 1 FROM warps WHERE from_sector = :f AND to_sector = :t LIMIT 1'
        );
        $stmt->execute(['f' => $from, 't' => $to]);
        return (bool)$stmt->fetchColumn();
    }

    public static function sector(int $id): ?array
    {
        $stmt = DB::conn()->prepare('SELECT * FROM sectors WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $s = $stmt->fetch();
        return $s ?: null;
    }
}
