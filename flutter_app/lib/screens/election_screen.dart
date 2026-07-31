import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/election.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';

class ElectionScreen extends StatefulWidget {
  const ElectionScreen({super.key, required this.apiBaseUrl, required this.code, this.ownerKey});
  final String apiBaseUrl;
  final String code;
  final String? ownerKey;
  @override State<ElectionScreen> createState() => _ElectionScreenState();
}

class _ElectionScreenState extends State<ElectionScreen> {
  Election? election;
  final selected = <String>{};
  final candidateName = TextEditingController();
  io.Socket? socket;
  bool busy = false;
  bool get owner => widget.ownerKey != null && widget.ownerKey!.isNotEmpty;
  ApiService get api => ApiService(widget.apiBaseUrl);

  @override void initState() { super.initState(); _load(); _connect(); }
  @override void dispose() { socket?.dispose(); candidateName.dispose(); super.dispose(); }

  void _connect() {
    socket = io.io(widget.apiBaseUrl, io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build());
    socket!.connect();
    socket!.onConnect((_) => socket!.emit('join-election', widget.code));
    socket!.on('election-updated', (_) => _load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => busy = true);
    try { final e = await api.getElection(widget.code, ownerKey: widget.ownerKey); if (mounted) setState(() => election = e); }
    catch (e) { if (mounted) _msg(e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _addCandidate() async {
    if (!owner || candidateName.text.trim().isEmpty) return;
    try { final e = await api.addCandidate(widget.code, widget.ownerKey!, candidateName.text.trim()); candidateName.clear(); setState(() => election = e); }
    catch (e) { _msg(e.toString()); }
  }

  Future<void> _submit() async {
    final e = election; if (e == null) return;
    if (selected.isEmpty) return _msg('Hãy chọn ít nhất một người.');
    if (selected.length > e.maxChoices) return _msg('Chỉ được chọn tối đa ${e.maxChoices} người.');
    try { final updated = await api.submitBallot(widget.code, selected.toList()); setState(() { election = updated; selected.clear(); }); _msg('Đã lưu phiếu số ${updated.totalBallots}.'); }
    catch (e) { _msg(e.toString()); }
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override Widget build(BuildContext context) {
    final e = election;
    return Scaffold(
      appBar: AppBar(title: Text(e?.name ?? widget.code), actions: [
        IconButton(onPressed: e == null ? null : () => PdfService.share(e), icon: const Icon(Icons.picture_as_pdf), tooltip: 'Xuất PDF'),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      body: busy && e == null ? const Center(child: CircularProgressIndicator()) : e == null ? const Center(child: Text('Không tải được dữ liệu')) : LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final input = _ballotPanel(e);
        final stats = _statsPanel(e);
        return wide ? Row(children: [Expanded(child: input), const VerticalDivider(width: 1), Expanded(child: stats)]) : ListView(children: [input, const Divider(), stats]);
      }),
    );
  }

  Widget _ballotPanel(Election e) => Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Mã tham gia: ${e.code}', style: Theme.of(context).textTheme.titleLarge), Text(owner ? 'Chế độ: CHỦ CUỘC BẦU CỬ' : 'Chế độ: NGƯỜI NHẬP PHIẾU')]),
      QrImageView(data: e.code, size: 100),
    ]),
    if (owner) ...[
      const SizedBox(height: 12),
      Row(children: [Expanded(child: TextField(controller: candidateName, onSubmitted: (_) => _addCandidate(), decoration: const InputDecoration(labelText: 'Tên người được bầu', border: OutlineInputBorder()))), const SizedBox(width: 8), IconButton.filled(onPressed: _addCandidate, icon: const Icon(Icons.add))]),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Khóa nhập phiếu'), value: e.locked, onChanged: (v) async { try { setState(() => busy = true); election = await api.setLocked(e.code, widget.ownerKey!, v); setState(() {}); } catch (x) { _msg(x.toString()); } finally { setState(() => busy = false); } }),
    ],
    const SizedBox(height: 8),
    Text('Chọn tối đa ${e.maxChoices} người', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    ...e.candidates.map((c) => Card(child: CheckboxListTile(
      value: selected.contains(c.id),
      title: Text('${c.sortOrder}. ${c.name}'),
      onChanged: e.locked ? null : (v) => setState(() { if (v == true) { if (selected.length < e.maxChoices) selected.add(c.id); else _msg('Đã đủ ${e.maxChoices} lựa chọn.'); } else { selected.remove(c.id); } }),
      secondary: owner ? IconButton(onPressed: () async { try { election = await api.deleteCandidate(e.code, widget.ownerKey!, c.id); setState(() {}); } catch (x) { _msg(x.toString()); } }, icon: const Icon(Icons.delete_outline)) : null,
    ))),
    const SizedBox(height: 10),
    FilledButton.icon(onPressed: e.locked || e.candidates.isEmpty ? null : _submit, icon: const Icon(Icons.save), label: const Text('LƯU PHIẾU')),
  ]));

  Widget _statsPanel(Election e) {
    final rows = [...e.candidates]..sort((a, b) => b.votes.compareTo(a.votes));
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('KẾT QUẢ TRỰC TIẾP', style: Theme.of(context).textTheme.headlineSmall),
      Text('Tổng phiếu: ${e.totalBallots}'),
      const SizedBox(height: 12),
      ...List.generate(rows.length, (i) {
        final c = rows[i]; final pct = e.totalBallots == 0 ? 0.0 : c.votes / e.totalBallots;
        return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i + 1}. ${c.name}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6), LinearProgressIndicator(value: pct), const SizedBox(height: 6),
          Text('${c.votes} phiếu • ${(pct * 100).toStringAsFixed(2)}% • Không chọn: ${e.totalBallots - c.votes}'),
        ])));
      }),
    ]));
  }
}
