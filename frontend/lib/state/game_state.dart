import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import '../services/ws_client.dart';

enum AuthStatus { unknown, loggedOut, needsVerification, loggedIn }

class GameState extends ChangeNotifier {
  final ApiClient api = ApiClient();
  final SessionStore _store = SessionStore();
  WsClient? ws;

  AuthStatus authStatus = AuthStatus.unknown;
  String? authError;
  Map<String, dynamic>? user;
  Player? player;

  SectorInfo? sector;
  List<int> warpsOut = [];
  Port? port;
  List<OtherPlayer> playersHere = [];
  List<PlanetInfo> planetsHere = [];
  List<NpcShip> npcsHere = [];
  List<MineField> minesHere = [];
  List<ChatMessage> sectorChat = [];

  List<SectorInfo> galaxySectors = [];
  List<Warp> galaxyWarps = [];

  final List<GalaxyEvent> events = [];
  final _eventToast = StreamController<GalaxyEvent>.broadcast();
  Stream<GalaxyEvent> get eventToasts => _eventToast.stream;

  bool wsConnected = false;
  bool loadingSector = false;
  String? sectorError;

  Future<void> bootstrap() async {
    final token = await _store.loadToken();
    if (token == null) {
      authStatus = AuthStatus.loggedOut;
      notifyListeners();
      return;
    }
    api.token = token;
    try {
      final resp = await api.me();
      user = resp['user'] as Map<String, dynamic>;
      player = Player.fromJson(resp['player'] as Map<String, dynamic>);
      authStatus = AuthStatus.loggedIn;
      _connectWs();
      notifyListeners();
      await refreshSector();
      await refreshGalaxyMap();
    } catch (e) {
      await _store.clear();
      api.token = null;
      authStatus = AuthStatus.loggedOut;
      notifyListeners();
    }
  }

  Future<bool> register(String email, String password, String handle) async {
    authError = null;
    try {
      await api.register(email, password, handle);
      return true;
    } on ApiException catch (e) {
      authError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    authError = null;
    try {
      final resp = await api.login(email, password);
      api.token = resp['token'] as String;
      await _store.saveToken(api.token!);
      user = resp['user'] as Map<String, dynamic>;
      player = Player.fromJson(resp['player'] as Map<String, dynamic>);
      authStatus = AuthStatus.loggedIn;
      _connectWs();
      notifyListeners();
      unawaited(refreshSector());
      unawaited(refreshGalaxyMap());
      return true;
    } on ApiException catch (e) {
      if (e.code == 'unverified') {
        authStatus = AuthStatus.needsVerification;
      }
      authError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } catch (_) {}
    ws?.dispose();
    ws = null;
    await _store.clear();
    api.token = null;
    player = null;
    user = null;
    sector = null;
    authStatus = AuthStatus.loggedOut;
    notifyListeners();
  }

  void _connectWs() {
    ws?.dispose();
    ws = WsClient(tokenProvider: () => api.token ?? '');
    ws!.connectionStatus.listen((c) {
      wsConnected = c;
      notifyListeners();
    });
    ws!.messages.listen(_onWsMessage);
    ws!.connect();
  }

  void _onWsMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'chat':
        final chat = ChatMessage.fromJson(msg);
        if (chat.scope == 'sector' && sector != null) {
          sectorChat = [...sectorChat, chat].take(50).toList();
          notifyListeners();
        }
        break;
      case 'event':
        final ev = GalaxyEvent.fromJson(msg);
        events.insert(0, ev);
        if (events.length > 100) events.removeLast();
        _eventToast.add(ev);
        if (sector != null && (ev.sectorId == null || ev.sectorId == sector!.id)) {
          unawaited(refreshSector());
        }
        notifyListeners();
        break;
      case 'player_entered':
      case 'player_left':
        if (sector != null && msg['sector_id'] == sector!.id) {
          unawaited(refreshSector());
        }
        break;
    }
  }

  Future<void> refreshSector() async {
    loadingSector = true;
    sectorError = null;
    notifyListeners();
    try {
      final resp = await api.sector();
      sector = SectorInfo.fromJson(resp['sector'] as Map<String, dynamic>);
      warpsOut = (resp['warps'] as List).map((e) => e as int).toList();
      port = resp['port'] == null ? null : Port.fromJson(resp['port'] as Map<String, dynamic>);
      playersHere = (resp['players'] as List)
          .map((e) => OtherPlayer.fromJson(e as Map<String, dynamic>))
          .toList();
      planetsHere = (resp['planets'] as List)
          .map((e) => PlanetInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      npcsHere =
          (resp['npcs'] as List).map((e) => NpcShip.fromJson(e as Map<String, dynamic>)).toList();
      minesHere =
          (resp['mines'] as List).map((e) => MineField.fromJson(e as Map<String, dynamic>)).toList();
      sectorChat = (resp['chat'] as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      player = Player.fromJson(resp['me'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      sectorError = e.message;
    } finally {
      loadingSector = false;
      notifyListeners();
    }
  }

  Future<void> refreshGalaxyMap() async {
    try {
      final resp = await api.galaxyMap();
      galaxySectors = (resp['sectors'] as List)
          .map((e) => SectorInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      galaxyWarps =
          (resp['warps'] as List).map((e) => Warp.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<String?> moveTo(int toSector) async {
    try {
      await api.move(toSector);
      ws?.notifySectorChanged();
      await refreshSector();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> refreshMe() async {
    try {
      final resp = await api.me();
      player = Player.fromJson(resp['player'] as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {}
  }
}
