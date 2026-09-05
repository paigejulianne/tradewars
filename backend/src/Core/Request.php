<?php
declare(strict_types=1);

namespace TradeWars\Core;

final class Request
{
    private static ?array $body = null;

    public static function body(): array
    {
        if (self::$body === null) {
            $raw = file_get_contents('php://input') ?: '';
            $decoded = json_decode($raw, true);
            self::$body = is_array($decoded) ? $decoded : [];
        }
        return self::$body;
    }

    public static function input(string $key, $default = null)
    {
        $body = self::body();
        if (array_key_exists($key, $body)) {
            return $body[$key];
        }
        return $_REQUEST[$key] ?? $default;
    }

    public static function bearerToken(): ?string
    {
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        if ($header === '' && function_exists('apache_request_headers')) {
            foreach (apache_request_headers() as $k => $v) {
                if (strtolower($k) === 'authorization') {
                    $header = $v;
                    break;
                }
            }
        }
        if (preg_match('/Bearer\s+(\S+)/i', $header, $m)) {
            return $m[1];
        }
        return null;
    }
}
