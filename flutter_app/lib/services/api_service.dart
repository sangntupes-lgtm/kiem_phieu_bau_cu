import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/election.dart';

class ApiService {
  ApiService(this.baseUrl);
  final String baseUrl;

  Uri _u(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');

  Future<Map<String, dynamic>> _json(http.Response r) async {
    final body = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception(body['error'] ?? 'Lỗi máy chủ ${r.statusCode}');
    }
    return body;
  }

  Future<Election> createElection({required String name, required String unit, required int maxChoices}) async {
    final r = await http.post(_u('/api/elections'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({
      'name': name,
      'unit': unit,
      'maxChoices': maxChoices,
    }));
    return Election.fromJson(await _json(r));
  }

  Future<Election> getElection(String code, {String? ownerKey}) async {
    final r = await http.get(_u('/api/elections/${code.toUpperCase()}'), headers: ownerKey == null ? {} : {'x-owner-key': ownerKey});
    return Election.fromJson(await _json(r));
  }

  Future<Election> addCandidate(String code, String ownerKey, String name) async {
    final r = await http.post(_u('/api/elections/$code/candidates'), headers: {'Content-Type': 'application/json', 'x-owner-key': ownerKey}, body: jsonEncode({'name': name}));
    return Election.fromJson(await _json(r));
  }

  Future<Election> deleteCandidate(String code, String ownerKey, String candidateId) async {
    final r = await http.delete(_u('/api/elections/$code/candidates/$candidateId'), headers: {'x-owner-key': ownerKey});
    return Election.fromJson(await _json(r));
  }

  Future<Election> submitBallot(String code, List<String> selected) async {
    final r = await http.post(_u('/api/elections/$code/ballots'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'selected': selected}));
    return Election.fromJson(await _json(r));
  }

  Future<Election> setLocked(String code, String ownerKey, bool locked) async {
    final r = await http.patch(_u('/api/elections/$code'), headers: {'Content-Type': 'application/json', 'x-owner-key': ownerKey}, body: jsonEncode({'locked': locked}));
    return Election.fromJson(await _json(r));
  }

  Future<void> deleteElection(String code, String ownerKey) async {
    final r = await http.delete(_u('/api/elections/$code'), headers: {'x-owner-key': ownerKey});
    await _json(r);
  }
}
