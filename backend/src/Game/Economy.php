<?php
declare(strict_types=1);

namespace TradeWars\Game;

use TradeWars\Core\DB;

/**
 * Port trading economy. Each commodity a port trades has a stock, a unit
 * price, and a mode: 'sell' means the port sells that commodity to players
 * (players buy), 'buy' means the port buys it from players (players sell).
 * Stock slowly regenerates toward a class-dependent ceiling over time, and
 * prices drift with each trade to simulate supply and demand.
 */
final class Economy
{
    public const COMMODITIES = ['fuel_ore', 'organics', 'equipment'];
    public const MAX_STOCK = 20000;
    public const REGEN_PCT_PER_HOUR = 0.02;

    public static function regen(array $port): array
    {
        $updatedAt = new \DateTimeImmutable($port['updated_at'], new \DateTimeZone('UTC'));
        $now = new \DateTimeImmutable('now', new \DateTimeZone('UTC'));
        $hours = ($now->getTimestamp() - $updatedAt->getTimestamp()) / 3600;
        if ($hours < 0.05) {
            return $port;
        }
        $changed = false;
        foreach (self::COMMODITIES as $c) {
            $qtyKey = "{$c}_qty";
            $cap = self::MAX_STOCK;
            $regen = (int)round($cap * self::REGEN_PCT_PER_HOUR * $hours);
            if ($regen > 0 && $port[$qtyKey] < $cap) {
                $port[$qtyKey] = min($cap, $port[$qtyKey] + $regen);
                $changed = true;
            }
        }
        if ($changed) {
            $stmt = DB::conn()->prepare(
                'UPDATE ports SET fuel_ore_qty=:f, organics_qty=:o, equipment_qty=:e, updated_at = NOW() WHERE id = :id'
            );
            $stmt->execute([
                'f' => $port['fuel_ore_qty'], 'o' => $port['organics_qty'], 'e' => $port['equipment_qty'],
                'id' => $port['id'],
            ]);
        }
        return $port;
    }

    /**
     * @return array{ok:bool, error?:string, port?:array, player?:array, total?:int}
     */
    public static function trade(array $port, array $player, string $commodity, string $action, int $qty): array
    {
        if (!in_array($commodity, self::COMMODITIES, true)) {
            return ['ok' => false, 'error' => 'Unknown commodity'];
        }
        if ($qty <= 0) {
            return ['ok' => false, 'error' => 'Quantity must be positive'];
        }
        $mode = $port["{$commodity}_mode"];
        // action='buy' (player buys from port) requires port mode 'sell'; vice versa.
        if (($action === 'buy' && $mode !== 'sell') || ($action === 'sell' && $mode !== 'buy')) {
            return ['ok' => false, 'error' => 'This port does not trade that commodity that way'];
        }

        $price = (float)$port["{$commodity}_price"];
        $stock = (int)$port["{$commodity}_qty"];
        $total = (int)round($price * $qty);

        if ($action === 'buy') {
            if ($qty > $stock) {
                return ['ok' => false, 'error' => 'Port does not have that much stock'];
            }
            if ($total > (int)$player['credits']) {
                return ['ok' => false, 'error' => 'Not enough credits'];
            }
            $holdsUsed = (int)$player['fuel_ore'] + (int)$player['organics'] + (int)$player['equipment'] + (int)$player['colonists'];
            if ($holdsUsed + $qty > (int)$player['holds_total']) {
                return ['ok' => false, 'error' => 'Not enough cargo hold space'];
            }
            $newStock = $stock - $qty;
            $newPlayerQty = (int)$player[$commodity] + $qty;
            $newCredits = (int)$player['credits'] - $total;
            $priceDelta = 1 + min(0.15, ($qty / max(1, self::MAX_STOCK)) * 2);
        } else {
            if ($qty > (int)$player[$commodity]) {
                return ['ok' => false, 'error' => 'You do not have that much cargo to sell'];
            }
            if ($total > (int)$port['credits']) {
                return ['ok' => false, 'error' => 'Port cannot afford that much'];
            }
            $newStock = $stock + $qty;
            $newPlayerQty = (int)$player[$commodity] - $qty;
            $newCredits = (int)$player['credits'] + $total;
            $priceDelta = 1 - min(0.15, ($qty / max(1, self::MAX_STOCK)) * 2);
        }

        $newPrice = round($price * $priceDelta, 2);
        $newPortCredits = $action === 'buy' ? (int)$port['credits'] + $total : (int)$port['credits'] - $total;

        $db = DB::conn();
        $db->beginTransaction();
        try {
            $db->prepare(
                "UPDATE ports SET {$commodity}_qty = :qty, {$commodity}_price = :price, credits = :pc, updated_at = NOW() WHERE id = :id"
            )->execute(['qty' => $newStock, 'price' => $newPrice, 'pc' => $newPortCredits, 'id' => $port['id']]);

            $db->prepare(
                "UPDATE players SET {$commodity} = :cq, credits = :cr WHERE id = :id"
            )->execute(['cq' => $newPlayerQty, 'cr' => $newCredits, 'id' => $player['id']]);

            $db->commit();
        } catch (\Throwable $e) {
            $db->rollBack();
            throw $e;
        }

        $port["{$commodity}_qty"] = $newStock;
        $port["{$commodity}_price"] = $newPrice;
        $port['credits'] = $newPortCredits;
        $player[$commodity] = $newPlayerQty;
        $player['credits'] = $newCredits;

        return ['ok' => true, 'port' => $port, 'player' => $player, 'total' => $total];
    }
}
