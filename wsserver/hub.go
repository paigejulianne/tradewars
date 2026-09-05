package main

import (
	"encoding/json"
	"log"
	"sync"

	"github.com/gorilla/websocket"
)

// OutMessage is any JSON payload sent down to clients.
type OutMessage map[string]any

type Client struct {
	conn     *websocket.Conn
	player   *Player
	sectorID int
	send     chan []byte
	closed   bool
	mu       sync.Mutex
}

func (c *Client) writeJSON(msg OutMessage) {
	b, err := json.Marshal(msg)
	if err != nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed {
		return
	}
	select {
	case c.send <- b:
	default:
		// slow consumer; drop
	}
}

type Hub struct {
	mu       sync.RWMutex
	clients  map[int]*Client         // playerID -> client
	bySector map[int]map[int]*Client // sectorID -> playerID -> client
}

func NewHub() *Hub {
	return &Hub{
		clients:  make(map[int]*Client),
		bySector: make(map[int]map[int]*Client),
	}
}

func (h *Hub) Register(c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.clients[c.player.ID] = c
	h.addToSectorLocked(c)
	log.Printf("player %d (%s) connected, sector %d, %d total online", c.player.ID, c.player.Handle, c.sectorID, len(h.clients))
}

func (h *Hub) Unregister(c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if existing, ok := h.clients[c.player.ID]; ok && existing == c {
		delete(h.clients, c.player.ID)
	}
	h.removeFromSectorLocked(c)
	log.Printf("player %d (%s) disconnected, %d total online", c.player.ID, c.player.Handle, len(h.clients))
}

func (h *Hub) addToSectorLocked(c *Client) {
	m, ok := h.bySector[c.sectorID]
	if !ok {
		m = make(map[int]*Client)
		h.bySector[c.sectorID] = m
	}
	m[c.player.ID] = c
}

func (h *Hub) removeFromSectorLocked(c *Client) {
	if m, ok := h.bySector[c.sectorID]; ok {
		delete(m, c.player.ID)
		if len(m) == 0 {
			delete(h.bySector, c.sectorID)
		}
	}
}

// MoveSector updates a client's tracked sector and notifies both the old and
// new sector's occupants.
func (h *Hub) MoveSector(c *Client, newSector int) {
	h.mu.Lock()
	old := c.sectorID
	h.removeFromSectorLocked(c)
	c.sectorID = newSector
	h.addToSectorLocked(c)
	h.mu.Unlock()

	if old != newSector {
		h.BroadcastSector(old, OutMessage{"type": "player_left", "player_id": c.player.ID, "handle": c.player.Handle, "sector_id": old})
		h.BroadcastSector(newSector, OutMessage{"type": "player_entered", "player_id": c.player.ID, "handle": c.player.Handle, "sector_id": newSector})
	}
}

func (h *Hub) BroadcastSector(sectorID int, msg OutMessage) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for _, c := range h.bySector[sectorID] {
		c.writeJSON(msg)
	}
}

func (h *Hub) BroadcastAll(msg OutMessage) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for _, c := range h.clients {
		c.writeJSON(msg)
	}
}

func (h *Hub) SendToPlayer(playerID int, msg OutMessage) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	c, ok := h.clients[playerID]
	if !ok {
		return false
	}
	c.writeJSON(msg)
	return true
}

func (h *Hub) OnlineCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

func (h *Hub) SectorRoster(sectorID int) []OutMessage {
	h.mu.RLock()
	defer h.mu.RUnlock()
	out := make([]OutMessage, 0, len(h.bySector[sectorID]))
	for _, c := range h.bySector[sectorID] {
		out = append(out, OutMessage{"player_id": c.player.ID, "handle": c.player.Handle})
	}
	return out
}
