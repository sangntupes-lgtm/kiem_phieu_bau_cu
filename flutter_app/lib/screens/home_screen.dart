import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'election_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.apiBaseUrl});
  final String apiBaseUrl;
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _name = TextEditingController();
  final _unit = TextEditingController();
  final _code = TextEditingController();
  final _maxChoices = TextEditingController(text: '1');
  bool _busy = false;

  Future<void> _open(String code, {String? ownerKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastCode', code);
    if (ownerKey != null) await prefs.setString('owner_$code', ownerKey);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ElectionScreen(apiBaseUrl: widget.apiBaseUrl, code: code, ownerKey: ownerKey)));
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return _msg('Vui lòng nhập tên cuộc bầu cử.');
    setState(() => _busy = true);
    try {
      final e = await ApiService(widget.apiBaseUrl).createElection(
        name: _name.text.trim(), unit: _unit.text.trim(), maxChoices: int.tryParse(_maxChoices.text) ?? 1);
      await _open(e.code, ownerKey: e.ownerKey);
    } catch (e) { _msg(e.toString()); } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length != 6) return _msg('Mã cuộc bầu cử gồm 6 ký tự.');
    final prefs = await SharedPreferences.getInstance();
    await _open(code, ownerKey: prefs.getString('owner_$code'));
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KIỂM ĐẾM PHIẾU BẦU PRO')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700), child: ListView(padding: const EdgeInsets.all(18), children: [
        const Icon(Icons.how_to_vote, size: 76),
        const SizedBox(height: 12),
        Text('Tạo cuộc bầu cử mới', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tên cuộc bầu cử', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Cấp/đơn vị', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _maxChoices, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số người tối đa được chọn trên một phiếu', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _busy ? null : _create, icon: const Icon(Icons.add), label: const Text('TẠO CUỘC BẦU CỬ')),
        const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider()),
        Text('Tham gia bằng mã', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        TextField(controller: _code, textCapitalization: TextCapitalization.characters, maxLength: 6, decoration: const InputDecoration(labelText: 'Mã 6 ký tự', border: OutlineInputBorder())),
        FilledButton.tonalIcon(onPressed: _join, icon: const Icon(Icons.login), label: const Text('MỞ CUỘC BẦU CỬ')),
        const SizedBox(height: 18),
        Text('Máy chủ: ${widget.apiBaseUrl}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ]))),
    );
  }
}
