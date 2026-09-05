import 'dart:convert';
import 'package:http/http.dart' as http;

/// Base URL for the REST API. Empty string means "same origin" (the
/// production deployment serves the Flutter web build and proxies /api
/// through the same Apache vhost). Override at build time with
/// `--dart-define=API_BASE=http://127.0.0.1:8099` for local development
/// against `php -S`.
const String _apiBase = String.fromEnvironment('API_BASE', defaultValue: '');

class ApiException implements Exception {
  final String message;
  final int status;
  final String? code;
  ApiException(this.message, this.status, [this.code]);
  @override
  String toString() => message;
}

class ApiClient {
  String? token;

  Uri _u(String path) => Uri.parse('$_apiBase/api$path');

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _handle(http.Response resp) async {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Unexpected server response (${resp.statusCode})', resp.statusCode);
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return body;
    }
    throw ApiException(
      body['error']?.toString() ?? 'Request failed',
      resp.statusCode,
      body['code']?.toString(),
    );
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) async {
    final uri = query == null ? _u(path) : _u(path).replace(queryParameters: query);
    final resp = await http.get(uri, headers: _headers(json: false));
    return _handle(resp);
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    final resp = await http.post(_u(path), headers: _headers(), body: jsonEncode(body ?? {}));
    return _handle(resp);
  }

  // --- Auth ---
  Future<Map<String, dynamic>> register(String email, String password, String handle) =>
      post('/auth/register.php', {'email': email, 'password': password, 'handle': handle});

  Future<Map<String, dynamic>> login(String email, String password) =>
      post('/auth/login.php', {'email': email, 'password': password});

  Future<void> logout() => post('/auth/logout.php');

  Future<Map<String, dynamic>> forgotPassword(String email) =>
      post('/auth/forgot.php', {'email': email});

  Future<Map<String, dynamic>> resetPassword(String token, String password) =>
      post('/auth/reset.php', {'token': token, 'password': password});

  // --- Game ---
  Future<Map<String, dynamic>> me() => get('/me.php');
  Future<Map<String, dynamic>> sector() => get('/sector.php');
  Future<Map<String, dynamic>> galaxyMap() => get('/galaxy_map.php');
  Future<Map<String, dynamic>> move(int toSector) => post('/move.php', {'to_sector': toSector});

  Future<Map<String, dynamic>> portTrade(String commodity, String action, int qty) =>
      post('/port_trade.php', {'commodity': commodity, 'action': action, 'qty': qty});

  Future<Map<String, dynamic>> shipUpgrade(String stat, int qty) =>
      post('/ship_upgrade.php', {'stat': stat, 'qty': qty});

  Future<Map<String, dynamic>> shipTypes() => get('/ship_types.php');

  Future<Map<String, dynamic>> shipBuy(int shipTypeId) =>
      post('/ship_buy.php', {'ship_type_id': shipTypeId});

  Future<Map<String, dynamic>> planet({int? id}) =>
      get('/planet.php', query: id == null ? null : {'id': '$id'});

  Future<Map<String, dynamic>> planetClaim(String name) =>
      post('/planet_claim.php', {'name': name});

  Future<Map<String, dynamic>> planetDeposit(String commodity, int qty) =>
      post('/planet_deposit.php', {'commodity': commodity, 'qty': qty});

  Future<Map<String, dynamic>> planetCollect(String commodity, int qty) =>
      post('/planet_collect.php', {'commodity': commodity, 'qty': qty});

  Future<Map<String, dynamic>> combatAttack(String targetType, int targetId) =>
      post('/combat_attack.php', {'target_type': targetType, 'target_id': targetId});

  Future<Map<String, dynamic>> minesDeploy(int qty) => post('/mines_deploy.php', {'qty': qty});

  Future<Map<String, dynamic>> corpCreate(String name, String tag) =>
      post('/corp_create.php', {'name': name, 'tag': tag});

  Future<Map<String, dynamic>> corpJoin(int corporationId) =>
      post('/corp_join.php', {'corporation_id': corporationId});

  Future<Map<String, dynamic>> corp({int? id}) =>
      get('/corp.php', query: id == null ? null : {'id': '$id'});

  Future<Map<String, dynamic>> leaderboard() => get('/leaderboard.php');

  Future<Map<String, dynamic>> eventsRecent({int sinceId = 0}) =>
      get('/events_recent.php', query: {'since_id': '$sinceId'});

  Future<Map<String, dynamic>> chatSend(String scope, String message) =>
      post('/chat_send.php', {'scope': scope, 'message': message});

  Future<Map<String, dynamic>> chatRecent(String scope) =>
      get('/chat_recent.php', query: {'scope': scope});
}
