package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"time"

	"github.com/gorilla/websocket"
)

const (
	writeWait  = 10 * time.Second
	pongWait   = 60 * time.Second
	pingPeriod = (pongWait * 9) / 10
	maxMsgSize = 4096
)

type inMessage struct {
	Type     string `json:"type"`
	Scope    string `json:"scope,omitempty"`
	Message  string `json:"message,omitempty"`
	SectorID int    `json:"sector_id,omitempty"`
}

func serveClient(db *sql.DB, hub *Hub, conn *websocket.Conn, player *Player) {
	c := &Client{
		conn:     conn,
		player:   player,
		sectorID: player.SectorID,
		send:     make(chan []byte, 32),
	}
	hub.Register(c)
	defer hub.Unregister(c)

	go writePump(c)
	readPump(db, hub, c)
}

func readPump(db *sql.DB, hub *Hub, c *Client) {
	defer func() {
		c.mu.Lock()
		c.closed = true
		close(c.send)
		c.mu.Unlock()
		c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMsgSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, raw, err := c.conn.ReadMessage()
		if err != nil {
			return
		}
		var msg inMessage
		if err := json.Unmarshal(raw, &msg); err != nil {
			continue
		}
		handleInbound(db, hub, c, msg)
	}
}

func handleInbound(db *sql.DB, hub *Hub, c *Client, msg inMessage) {
	switch msg.Type {
	case "sync_sector":
		// Client tells us it moved (after a successful REST /api/move.php call).
		actual, err := refreshPlayerSector(db, c.player.ID)
		if err != nil {
			return
		}
		hub.MoveSector(c, actual)
		c.writeJSON(OutMessage{"type": "sector_synced", "sector_id": actual, "roster": hub.SectorRoster(actual)})

	case "chat":
		if msg.Message == "" || len(msg.Message) > 500 {
			return
		}
		scope := msg.Scope
		if scope != "galaxy" && scope != "sector" && scope != "corp" {
			scope = "galaxy"
		}
		var sectorID any
		var corpID any
		if scope == "sector" {
			sectorID = c.sectorID
		}
		if scope == "corp" {
			if !c.player.CorpID.Valid {
				return
			}
			corpID = c.player.CorpID.Int64
		}
		_, err := db.Exec(
			`INSERT INTO chat_messages (scope, sector_id, corporation_id, player_id, handle, message) VALUES (?,?,?,?,?,?)`,
			scope, sectorID, corpID, c.player.ID, c.player.Handle, msg.Message,
		)
		if err != nil {
			log.Printf("chat insert: %v", err)
		}
		// Broadcast happens via the chat poller so REST-originated and
		// WS-originated messages are handled identically.

	case "ping":
		c.writeJSON(OutMessage{"type": "pong"})
	}
}

func writePump(c *Client) {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()
	for {
		select {
		case msg, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, msg); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
