int _i(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

double _d(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

bool _b(dynamic v) => v == true || v == 1 || v == '1';

String _s(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;

class ShipTypeInfo {
  final int id;
  final String key;
  final String name;
  final int basePrice;
  final int maxFighters;
  final int maxShields;
  final int maxHolds;
  final int baseHolds;
  final bool canCloak;
  final String description;

  ShipTypeInfo.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        key = _s(j['key']),
        name = _s(j['name']),
        basePrice = _i(j['base_price']),
        maxFighters = _i(j['max_fighters']),
        maxShields = _i(j['max_shields']),
        maxHolds = _i(j['max_holds']),
        baseHolds = _i(j['base_holds']),
        canCloak = _b(j['can_cloak']),
        description = _s(j['description']);
}

class Player {
  final int id;
  final int userId;
  final String handle;
  final int shipTypeId;
  final String shipName;
  final int sectorId;
  final int credits;
  final int turnsRemaining;
  final int experience;
  final int alignment;
  final int fighters;
  final int shields;
  final int holdsTotal;
  final int fuelOre;
  final int organics;
  final int equipment;
  final int colonists;
  final bool cloak;
  final int? corporationId;
  final bool isAlive;

  Player.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        userId = _i(j['user_id']),
        handle = _s(j['handle']),
        shipTypeId = _i(j['ship_type_id']),
        shipName = _s(j['ship_name']),
        sectorId = _i(j['sector_id']),
        credits = _i(j['credits']),
        turnsRemaining = _i(j['turns_remaining']),
        experience = _i(j['experience']),
        alignment = _i(j['alignment']),
        fighters = _i(j['fighters']),
        shields = _i(j['shields']),
        holdsTotal = _i(j['holds_total']),
        fuelOre = _i(j['fuel_ore']),
        organics = _i(j['organics']),
        equipment = _i(j['equipment']),
        colonists = _i(j['colonists']),
        cloak = _b(j['cloak']),
        corporationId = j['corporation_id'] == null ? null : _i(j['corporation_id']),
        isAlive = _b(j['is_alive']);

  int get holdsUsed => fuelOre + organics + equipment + colonists;
  int get holdsFree => holdsTotal - holdsUsed;
}

class SectorInfo {
  final int id;
  final String? name;
  final int x, y;
  final String region;
  final bool isFederation;
  final bool hasPort;
  final bool hazard;

  SectorInfo.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = j['name'] as String?,
        x = _i(j['x']),
        y = _i(j['y']),
        region = _s(j['region']),
        isFederation = _b(j['is_federation']),
        hasPort = _b(j['has_port']),
        hazard = _b(j['hazard']);
}

class Warp {
  final int from, to;
  Warp(this.from, this.to);
  Warp.fromJson(Map<String, dynamic> j) : from = _i(j['from']), to = _i(j['to']);
}

class Port {
  final int id;
  final int sectorId;
  final String name;
  final int cls;
  final int fuelOreQty;
  final double fuelOrePrice;
  final String fuelOreMode;
  final int organicsQty;
  final double organicsPrice;
  final String organicsMode;
  final int equipmentQty;
  final double equipmentPrice;
  final String equipmentMode;
  final int credits;

  Port.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        sectorId = _i(j['sector_id']),
        name = _s(j['name']),
        cls = _i(j['class']),
        fuelOreQty = _i(j['fuel_ore_qty']),
        fuelOrePrice = _d(j['fuel_ore_price']),
        fuelOreMode = _s(j['fuel_ore_mode']),
        organicsQty = _i(j['organics_qty']),
        organicsPrice = _d(j['organics_price']),
        organicsMode = _s(j['organics_mode']),
        equipmentQty = _i(j['equipment_qty']),
        equipmentPrice = _d(j['equipment_price']),
        equipmentMode = _s(j['equipment_mode']),
        credits = _i(j['credits']);
}

class PlanetInfo {
  final int id;
  final int sectorId;
  final String name;
  final String type;
  final int? ownerPlayerId;
  final int colonists;
  final int maxColonists;
  final int fighters;
  final int citadelLevel;
  final int fuelOreStock;
  final int organicsStock;
  final int equipmentStock;

  PlanetInfo.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        sectorId = _i(j['sector_id']),
        name = _s(j['name']),
        type = _s(j['type']),
        ownerPlayerId = j['owner_player_id'] == null ? null : _i(j['owner_player_id']),
        colonists = _i(j['colonists']),
        maxColonists = _i(j['max_colonists']),
        fighters = _i(j['fighters']),
        citadelLevel = _i(j['citadel_level']),
        fuelOreStock = _i(j['fuel_ore_stock']),
        organicsStock = _i(j['organics_stock']),
        equipmentStock = _i(j['equipment_stock']);
}

class NpcShip {
  final int id;
  final String kind;
  final String name;
  final int sectorId;
  final int fighters;
  final int shields;
  final int bountyCredits;
  final bool aggressive;

  NpcShip.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        kind = _s(j['kind']),
        name = _s(j['name']),
        sectorId = _i(j['sector_id']),
        fighters = _i(j['fighters']),
        shields = _i(j['shields']),
        bountyCredits = _i(j['bounty_credits']),
        aggressive = _b(j['aggressive']);
}

class OtherPlayer {
  final int id;
  final String handle;
  final String shipName;
  final int shipTypeId;
  final int fighters;
  final int shields;
  final int? corporationId;

  OtherPlayer.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        handle = _s(j['handle']),
        shipName = _s(j['ship_name']),
        shipTypeId = _i(j['ship_type_id']),
        fighters = _i(j['fighters']),
        shields = _i(j['shields']),
        corporationId = j['corporation_id'] == null ? null : _i(j['corporation_id']);
}

class ChatMessage {
  final int id;
  final String scope;
  final String handle;
  final String message;
  final DateTime createdAt;

  ChatMessage.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        scope = _s(j['scope']),
        handle = _s(j['handle']),
        message = _s(j['message']),
        createdAt = DateTime.tryParse(_s(j['created_at'])) ?? DateTime.now();
}

class GalaxyEvent {
  final int id;
  final String eventType;
  final int? sectorId;
  final String title;
  final String message;
  final DateTime createdAt;

  GalaxyEvent.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        eventType = _s(j['event_type']),
        sectorId = j['sector_id'] == null ? null : _i(j['sector_id']),
        title = _s(j['title']),
        message = _s(j['message']),
        createdAt = DateTime.tryParse(_s(j['created_at'])) ?? DateTime.now();
}

class MineField {
  final int? ownerPlayerId;
  final int total;
  MineField.fromJson(Map<String, dynamic> j)
      : ownerPlayerId = j['owner_player_id'] == null ? null : _i(j['owner_player_id']),
        total = _i(j['total']);
}

class CorpSummary {
  final int id;
  final String name;
  final String tag;
  final int treasury;
  final int memberCount;
  CorpSummary.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = _s(j['name']),
        tag = _s(j['tag']),
        treasury = _i(j['treasury']),
        memberCount = _i(j['member_count']);
}

class LeaderboardEntry {
  final String handle;
  final int credits;
  final int experience;
  final int alignment;
  final String shipName;
  final String? corpTag;
  LeaderboardEntry.fromJson(Map<String, dynamic> j)
      : handle = _s(j['handle']),
        credits = _i(j['credits']),
        experience = _i(j['experience']),
        alignment = _i(j['alignment']),
        shipName = _s(j['ship_name']),
        corpTag = j['corp_tag'] as String?;
}
