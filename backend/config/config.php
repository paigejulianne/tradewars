<?php
declare(strict_types=1);

return [
    'db' => [
        'host' => '127.0.0.1',
        'name' => 'tradewars',
        'user' => 'tradewars',
        'pass' => '7acjHbEeyQaU073kSoV8yWrzyoHdp8',
    ],
    'app' => [
        'url'        => 'https://tradewars.paigejulianne.com',
        'jwt_secret' => '28b2af03099d003d4ebb41a204d66a57db56fb89ca44e185048c56a151551daf',
        'mail_from'  => 'noreply@tradewars.paigejulianne.com',
        'mail_name'  => 'TradeWars: Galactic Frontier',
        'starting_credits' => 10000,
        'starting_turns'   => 2000,
        'daily_turn_reset' => 1000,
    ],
];
