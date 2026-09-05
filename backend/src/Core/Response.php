<?php
declare(strict_types=1);

namespace TradeWars\Core;

final class Response
{
    public static function json($data, int $status = 200): never
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($data, JSON_UNESCAPED_SLASHES);
        exit;
    }

    public static function error(string $message, int $status = 400, array $extra = []): never
    {
        self::json(['error' => $message] + $extra, $status);
    }

    public static function ok(array $data = []): never
    {
        self::json(['ok' => true] + $data, 200);
    }
}
