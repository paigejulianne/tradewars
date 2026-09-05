<?php
declare(strict_types=1);

namespace TradeWars\Core;

final class Config
{
    private static ?array $data = null;

    public static function get(string $key)
    {
        if (self::$data === null) {
            self::$data = require __DIR__ . '/../../config/config.php';
        }
        return self::$data[$key] ?? null;
    }
}
