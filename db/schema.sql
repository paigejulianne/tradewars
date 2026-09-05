-- TradeWars: Galactic Frontier — database schema
-- MariaDB 11.x / InnoDB / utf8mb4

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- Accounts & auth
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS users (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email               VARCHAR(190) NOT NULL,
    password_hash       VARCHAR(255) NOT NULL,
    email_verified_at   DATETIME NULL,
    verification_token  CHAR(64) NULL,
    verification_sent_at DATETIME NULL,
    is_admin            TINYINT(1) NOT NULL DEFAULT 0,
    is_banned           TINYINT(1) NOT NULL DEFAULT 0,
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_at       DATETIME NULL,
    UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS password_resets (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id     INT UNSIGNED NOT NULL,
    token       CHAR(64) NOT NULL,
    expires_at  DATETIME NOT NULL,
    used_at     DATETIME NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_pwreset_token (token),
    KEY idx_pwreset_user (user_id),
    CONSTRAINT fk_pwreset_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS sessions (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id     INT UNSIGNED NOT NULL,
    token_hash  CHAR(64) NOT NULL,
    ip          VARCHAR(64) NULL,
    user_agent  VARCHAR(255) NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at  DATETIME NOT NULL,
    UNIQUE KEY uq_session_token (token_hash),
    KEY idx_session_user (user_id),
    CONSTRAINT fk_session_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Galaxy topology
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS sectors (
    id          INT UNSIGNED PRIMARY KEY,
    name        VARCHAR(64) NULL,
    x           INT NOT NULL DEFAULT 0,
    y           INT NOT NULL DEFAULT 0,
    region      VARCHAR(32) NOT NULL DEFAULT 'deep_space',
    is_federation TINYINT(1) NOT NULL DEFAULT 0,
    has_port    TINYINT(1) NOT NULL DEFAULT 0,
    hazard      TINYINT(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS warps (
    from_sector INT UNSIGNED NOT NULL,
    to_sector   INT UNSIGNED NOT NULL,
    PRIMARY KEY (from_sector, to_sector),
    KEY idx_warp_to (to_sector),
    CONSTRAINT fk_warp_from FOREIGN KEY (from_sector) REFERENCES sectors(id) ON DELETE CASCADE,
    CONSTRAINT fk_warp_to FOREIGN KEY (to_sector) REFERENCES sectors(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Ports (trading posts)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ports (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sector_id       INT UNSIGNED NOT NULL,
    name            VARCHAR(64) NOT NULL,
    class           TINYINT UNSIGNED NOT NULL,     -- 0=Stardock (special), 1-8 classic TW port classes
    fuel_ore_qty    INT NOT NULL DEFAULT 0,
    fuel_ore_price  DECIMAL(10,2) NOT NULL DEFAULT 0,
    fuel_ore_mode   ENUM('buy','sell') NOT NULL DEFAULT 'sell', -- port buys from / sells to player
    organics_qty    INT NOT NULL DEFAULT 0,
    organics_price  DECIMAL(10,2) NOT NULL DEFAULT 0,
    organics_mode   ENUM('buy','sell') NOT NULL DEFAULT 'sell',
    equipment_qty   INT NOT NULL DEFAULT 0,
    equipment_price DECIMAL(10,2) NOT NULL DEFAULT 0,
    equipment_mode  ENUM('buy','sell') NOT NULL DEFAULT 'sell',
    credits         BIGINT NOT NULL DEFAULT 1000000,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_port_sector (sector_id),
    CONSTRAINT fk_port_sector FOREIGN KEY (sector_id) REFERENCES sectors(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Ships & players
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ship_types (
    id              TINYINT UNSIGNED PRIMARY KEY,
    `key`           VARCHAR(32) NOT NULL,
    name            VARCHAR(64) NOT NULL,
    base_price      INT NOT NULL,
    max_fighters    INT NOT NULL,
    max_shields     INT NOT NULL,
    max_holds       INT NOT NULL,
    base_holds      INT NOT NULL,
    can_cloak       TINYINT(1) NOT NULL DEFAULT 0,
    turn_cost       TINYINT UNSIGNED NOT NULL DEFAULT 1,
    description     TEXT NULL,
    UNIQUE KEY uq_shiptype_key (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS corporations (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(64) NOT NULL,
    tag             VARCHAR(8) NOT NULL,
    founder_player_id INT UNSIGNED NULL,
    treasury        BIGINT NOT NULL DEFAULT 0,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_corp_name (name),
    UNIQUE KEY uq_corp_tag (tag)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS players (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id         INT UNSIGNED NOT NULL,
    handle          VARCHAR(32) NOT NULL,
    ship_type_id    TINYINT UNSIGNED NOT NULL DEFAULT 1,
    ship_name       VARCHAR(64) NOT NULL DEFAULT 'Merchant Cruiser',
    sector_id       INT UNSIGNED NOT NULL DEFAULT 1,
    credits         BIGINT NOT NULL DEFAULT 10000,
    turns_remaining INT NOT NULL DEFAULT 2000,
    turns_reset_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    experience      INT NOT NULL DEFAULT 0,
    alignment       INT NOT NULL DEFAULT 0,
    fighters        INT NOT NULL DEFAULT 20,
    shields         INT NOT NULL DEFAULT 100,
    holds_total     INT NOT NULL DEFAULT 20,
    fuel_ore        INT NOT NULL DEFAULT 0,
    organics        INT NOT NULL DEFAULT 0,
    equipment       INT NOT NULL DEFAULT 0,
    colonists       INT NOT NULL DEFAULT 0,
    cloak           TINYINT(1) NOT NULL DEFAULT 0,
    corporation_id  INT UNSIGNED NULL,
    is_alive        TINYINT(1) NOT NULL DEFAULT 1,
    last_action_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_player_user (user_id),
    UNIQUE KEY uq_player_handle (handle),
    KEY idx_player_sector (sector_id),
    KEY idx_player_corp (corporation_id),
    CONSTRAINT fk_player_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_player_shiptype FOREIGN KEY (ship_type_id) REFERENCES ship_types(id),
    CONSTRAINT fk_player_corp FOREIGN KEY (corporation_id) REFERENCES corporations(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE corporations
    ADD CONSTRAINT fk_corp_founder FOREIGN KEY (founder_player_id) REFERENCES players(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS corporation_members (
    corporation_id  INT UNSIGNED NOT NULL,
    player_id       INT UNSIGNED NOT NULL,
    role            ENUM('founder','officer','member') NOT NULL DEFAULT 'member',
    joined_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (corporation_id, player_id),
    CONSTRAINT fk_corpmem_corp FOREIGN KEY (corporation_id) REFERENCES corporations(id) ON DELETE CASCADE,
    CONSTRAINT fk_corpmem_player FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Planets
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS planets (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sector_id       INT UNSIGNED NOT NULL,
    name            VARCHAR(64) NOT NULL,
    type            ENUM('class_m','class_k','class_o','class_h','class_c') NOT NULL DEFAULT 'class_m',
    owner_player_id INT UNSIGNED NULL,
    colonists       INT NOT NULL DEFAULT 0,
    max_colonists   INT NOT NULL DEFAULT 5000000,
    fighters        INT NOT NULL DEFAULT 0,
    citadel_level   TINYINT UNSIGNED NOT NULL DEFAULT 0,
    fuel_ore_stock  INT NOT NULL DEFAULT 0,
    organics_stock  INT NOT NULL DEFAULT 0,
    equipment_stock INT NOT NULL DEFAULT 0,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_planet_sector (sector_id),
    KEY idx_planet_owner (owner_player_id),
    CONSTRAINT fk_planet_sector FOREIGN KEY (sector_id) REFERENCES sectors(id) ON DELETE CASCADE,
    CONSTRAINT fk_planet_owner FOREIGN KEY (owner_player_id) REFERENCES players(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Mines (deployed sector defenses)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS mines (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sector_id       INT UNSIGNED NOT NULL,
    owner_player_id INT UNSIGNED NULL,
    quantity        INT NOT NULL DEFAULT 0,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_mine_sector (sector_id),
    CONSTRAINT fk_mine_sector FOREIGN KEY (sector_id) REFERENCES sectors(id) ON DELETE CASCADE,
    CONSTRAINT fk_mine_owner FOREIGN KEY (owner_player_id) REFERENCES players(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- NPCs (Ferrengi raiders, space monsters, alien traders)
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS npc_ships (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    kind            ENUM('ferrengi_raider','space_monster','alien_trader') NOT NULL,
    name            VARCHAR(64) NOT NULL,
    sector_id       INT UNSIGNED NOT NULL,
    fighters        INT NOT NULL DEFAULT 50,
    shields         INT NOT NULL DEFAULT 50,
    bounty_credits  INT NOT NULL DEFAULT 500,
    aggressive      TINYINT(1) NOT NULL DEFAULT 1,
    spawned_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_npc_sector (sector_id),
    CONSTRAINT fk_npc_sector FOREIGN KEY (sector_id) REFERENCES sectors(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Combat & event logs
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS combat_log (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sector_id           INT UNSIGNED NOT NULL,
    attacker_player_id  INT UNSIGNED NULL,
    defender_player_id  INT UNSIGNED NULL,
    defender_npc_id     INT UNSIGNED NULL,
    outcome             VARCHAR(32) NOT NULL,
    fighters_lost_attacker INT NOT NULL DEFAULT 0,
    fighters_lost_defender INT NOT NULL DEFAULT 0,
    credits_looted      BIGINT NOT NULL DEFAULT 0,
    detail              JSON NULL,
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_combat_sector (sector_id),
    KEY idx_combat_attacker (attacker_player_id),
    KEY idx_combat_defender (defender_player_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS events_log (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_type  VARCHAR(32) NOT NULL,
    sector_id   INT UNSIGNED NULL,
    player_id   INT UNSIGNED NULL,
    title       VARCHAR(128) NOT NULL,
    message     TEXT NOT NULL,
    data        JSON NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_event_sector (sector_id),
    KEY idx_event_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS chat_messages (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    scope       ENUM('galaxy','sector','corp') NOT NULL DEFAULT 'galaxy',
    sector_id   INT UNSIGNED NULL,
    corporation_id INT UNSIGNED NULL,
    player_id   INT UNSIGNED NOT NULL,
    handle      VARCHAR(32) NOT NULL,
    message     VARCHAR(500) NOT NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_chat_scope (scope, sector_id, corporation_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;
