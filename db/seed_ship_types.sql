INSERT INTO ship_types (id, `key`, name, base_price, max_fighters, max_shields, max_holds, base_holds, can_cloak, turn_cost, description) VALUES
(1, 'merchant_cruiser', 'Merchant Cruiser', 0,       500,  200, 60,  20, 0, 1, 'The starting vessel every trader begins with. Balanced and unremarkable.'),
(2, 'scout_marauder',   'Scout Marauder',  15000,   750,  150, 40,  20, 1, 1, 'Fast, cloak-capable, light cargo. Favored by smugglers and scouts.'),
(3, 'cargo_hauler',     'Cargo Hauler',    35000,   400,  250, 120, 60, 0, 1, 'Slow but enormous holds. The backbone of any trading empire.'),
(4, 'corporate_flagship', 'Corporate Flagship', 90000, 2000, 600, 80, 40, 0, 1, 'A heavily armed capital ship favored by corporation fleets.'),
(5, 'imperial_starship', 'Imperial Starship', 175000, 5000, 1200, 100, 50, 1, 1, 'The pinnacle of Federation shipbuilding. Expensive, deadly, cloak-capable.')
ON DUPLICATE KEY UPDATE name=VALUES(name);
