import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';
import '../utils/app_constants.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  int? _electionId;
  Map<String, Object?>? _election;
  List<Map<String, Object?>> _candidates = [];
  List<Map<String, Object?>> _ballots = [];
  final _name = TextEditingController();
  final _org = TextEditingController();
  final _total = TextEditingController(text: '0');
  final _select = TextEditingController(text: '0');
  final _exclude = TextEditingController(text: '0');

  @override void initState() { super.initState(); _bootstrap(); }
  Future<void> _bootstrap() async {
    final list = await AppDatabase.instance.elections();
    final id = list.isEmpty ? await AppDatabase.instance.createElection() : list.first['id'] as int;
    await _load(id);
  }

  Future<void> _load(int id) async {
    final list = await AppDatabase.instance.elections();
    final e = list.firstWhere((x) => x['id'] == id);
    final cs = await AppDatabase.instance.candidates(id);
    final bs = await AppDatabase.instance.ballots(id);
    setState(() {
      _electionId = id; _election = e; _candidates = cs; _ballots = bs;
      _name.text = e['name']?.toString() ?? ''; _org.text = e['organization']?.toString() ?? '';
      _total.text = '${e['total_ballots'] ?? 0}'; _select.text = '${e['select_count'] ?? 0}'; _exclude.text = '${e['exclude_count'] ?? 0}';
    });
  }

  Future<void> _saveSetup({bool goEntry = false}) async {
    if (_electionId == null) return;
    await AppDatabase.instance.updateElection(_electionId!, {
      'name': _name.text.trim(), 'organization': _org.text.trim(),
      'total_ballots': int.tryParse(_total.text) ?? 0,
      'select_count': int.tryParse(_select.text) ?? 0,
      'exclude_count': int.tryParse(_exclude.text) ?? 0,
    });
    await _load(_electionId!);
    if (goEntry) setState(() => _tab = 2);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu thông tin cuộc bầu cử')));
  }

  Future<void> _newElection() async {
    await _saveSetup();
    final id = await AppDatabase.instance.createElection();
    await _load(id); setState(() => _tab = 1);
  }

  Future<void> _chooseElection() async {
    final list = await AppDatabase.instance.elections();
    if (!mounted) return;
    final id = await showModalBottomSheet<int>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: ListView.builder(shrinkWrap: true, itemCount: list.length, itemBuilder: (_, i) {
      final e = list[i]; final name = (e['name']?.toString().trim().isNotEmpty ?? false) ? e['name'].toString() : 'Cuộc bầu cử chưa đặt tên';
      return ListTile(leading: const Icon(Icons.how_to_vote), title: Text(name), subtitle: Text('${e['organization'] ?? ''}\nCập nhật: ${_fmt(e['updated_at'])}'), isThreeLine: true, onTap: () => Navigator.pop(ctx, e['id'] as int));
    })));
    if (id != null) { await _saveSetup(); await _load(id); }
  }

  Future<void> _exportFile() async {
    if (_electionId == null) return;
    await _saveSetup();
    final data = await AppDatabase.instance.exportElection(_electionId!);
    final dir = await getTemporaryDirectory();
    final safe = (_name.text.trim().isEmpty ? 'cuoc_bau_cu' : _name.text.trim()).replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final file = File(p.join(dir.path, '${safe}_${DateTime.now().millisecondsSinceEpoch}.nsbau'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data), flush: true);
    await SharePlus.instance.share(ShareParams(text: 'Tệp cuộc bầu cử từ phần mềm NGUYEN SANG', files: [XFile(file.path)]));
  }

  Future<void> _importFile() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập tệp .nsbau'),
        content: const Text('Bản V2 hiện ưu tiên hoạt động độc lập và xuất sao lưu. Chức năng nhập tệp sẽ được bổ sung ở bản tiếp theo.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
      ),
    );
  }

  static String _fmt(Object? iso) { try { return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse('$iso')); } catch (_) { return '$iso'; } }
  void _error(String text) => showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Thông báo'), content: Text(text), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))]));

  @override Widget build(BuildContext context) {
    final title = (_election?['name']?.toString().trim().isNotEmpty ?? false) ? _election!['name'].toString() : 'Cuộc bầu cử chưa đặt tên';
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('KIỂM ĐẾM PHIẾU BẦU MOBILE PRO V2', style: TextStyle(fontWeight: FontWeight.bold)), Text(title, style: Theme.of(context).textTheme.bodySmall)]), actions: [PopupMenuButton<String>(tooltip: 'Quản lý cuộc bầu cử', onSelected: (v) { if (v == 'new') _newElection(); if (v == 'open') _importFile(); if (v == 'save') _exportFile(); if (v == 'saved') _chooseElection(); if (v == 'about') _about(); }, itemBuilder: (_) => const [
        PopupMenuItem(value: 'new', child: ListTile(leading: Icon(Icons.add_box), title: Text('Tạo cuộc bầu cử mới'))),
        PopupMenuItem(value: 'open', child: ListTile(leading: Icon(Icons.folder_open), title: Text('Mở tệp cuộc bầu cử'))),
        PopupMenuItem(value: 'save', child: ListTile(leading: Icon(Icons.save_alt), title: Text('Lưu cuộc bầu cử ra máy'))),
        PopupMenuItem(value: 'saved', child: ListTile(leading: Icon(Icons.history), title: Text('Cuộc bầu cử đã lưu'))),
        PopupMenuDivider(), PopupMenuItem(value: 'about', child: ListTile(leading: Icon(Icons.info_outline), title: Text('Thông tin phần mềm'))),
      ])]),
      body: _body(),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (v) => setState(() => _tab = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.folder_copy_outlined), selectedIcon: Icon(Icons.folder_copy), label: 'Quản lý'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Thiết lập'),
        NavigationDestination(icon: Icon(Icons.how_to_vote_outlined), selectedIcon: Icon(Icons.how_to_vote), label: 'Nhập phiếu'),
        NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Danh sách'),
        NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Thống kê'),
      ]),
    );
  }

  Widget _body() {
    if (_electionId == null) return const Center(child: CircularProgressIndicator());
    return switch (_tab) { 0 => _management(), 1 => _setup(), 2 => _entry(), 3 => _ballotList(), _ => _stats() };
  }

  Widget _management() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quản lý cuộc bầu cử', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('Đang mở: ${_election?['name']?.toString().trim().isNotEmpty == true ? _election!['name'] : 'Chưa đặt tên'}'),
                  Text('Số ứng cử viên: ${_candidates.length} • Số phiếu đã nhập: ${_ballots.length}/${_election?['total_ballots'] ?? 0}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _bigButton(Icons.add_box, 'Tạo cuộc bầu cử mới', 'Tự lưu cuộc đang làm rồi tạo cuộc mới', _newElection),
          _bigButton(Icons.history, 'Cuộc bầu cử đã lưu', 'Mở lại và tiếp tục chỉnh sửa thông tin, số phiếu và phiếu bầu', _chooseElection),
          _bigButton(Icons.folder_open, 'Mở tệp .nsbau', 'Nhập dữ liệu sẽ được bổ sung ở bản tiếp theo', _importFile),
          _bigButton(Icons.save_alt, 'Lưu/Chia sẻ cuộc bầu cử', 'Xuất đầy đủ dữ liệu và lịch sử sửa phiếu', _exportFile),
        ],
      );

  Widget _bigButton(IconData icon, String title, String sub, VoidCallback tap) => Card(child: ListTile(leading: Icon(icon, size: 34), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(sub), trailing: const Icon(Icons.chevron_right), onTap: tap));

  Widget _setup() => ListView(padding: const EdgeInsets.all(12), children: [
    Text('2. THIẾT LẬP', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 10),
    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tên cuộc bầu cử (có thể để trống)')), const SizedBox(height: 10),
    TextField(controller: _org, decoration: const InputDecoration(labelText: 'Cấp / đơn vị tổ chức')), const SizedBox(height: 10),
    Row(children: [Expanded(child: TextField(controller: _total, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tổng số phiếu'))), const SizedBox(width: 8), Expanded(child: TextField(controller: _select, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số được chọn'))), const SizedBox(width: 8), Expanded(child: TextField(controller: _exclude, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số bị bỏ')))]),
    const SizedBox(height: 12), Row(children: [Expanded(child: Text('DANH SÁCH NGƯỜI ĐƯỢC BẦU', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))), FilledButton.icon(onPressed: () => _saveSetup(goEntry: true), icon: const Icon(Icons.save), label: const Text('LƯU THÔNG TIN'))]),
    const SizedBox(height: 6), FilledButton.tonalIcon(onPressed: _candidateDialog, icon: const Icon(Icons.person_add), label: const Text('Thêm người ứng cử')),
    ..._candidates.map((c) => Card(child: ListTile(leading: CircleAvatar(child: Text('${c['seq']}')), title: Text('${c['name']}'), subtitle: Text('${c['note'] ?? ''}'), onTap: () => _candidateDialog(c), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await AppDatabase.instance.deleteCandidate(c['id'] as int); await _load(_electionId!); })))).toList(),
  ]);

  Future<void> _candidateDialog([Map<String, Object?>? c]) async {
    final n = TextEditingController(text: c?['name']?.toString() ?? ''); final note = TextEditingController(text: c?['note']?.toString() ?? '');
    await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: Text(c == null ? 'Thêm người ứng cử' : 'Chỉnh sửa người ứng cử'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, autofocus: true, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Họ và tên')), const SizedBox(height: 10), TextField(controller: note, decoration: const InputDecoration(labelText: 'Ghi chú'), onSubmitted: (_) => Navigator.pop(ctx, 'save'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Lưu'))])).then((v) async {
      if (v == 'save' && n.text.trim().isNotEmpty) { if (c == null) { await AppDatabase.instance.addCandidate(_electionId!, n.text, note.text); } else { await AppDatabase.instance.updateCandidate(c['id'] as int, n.text, note.text); } await _load(_electionId!); }
    });
  }

  Widget _entry() => BallotEntry(election: _election!, candidates: _candidates, ballotCount: _ballots.length, onSaved: () => _load(_electionId!));

  Widget _ballotList() => ListView(padding: const EdgeInsets.all(12), children: [
    Text('4. DANH SÁCH PHIẾU', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8),
    if (_ballots.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Chưa có phiếu nào')))),
    ..._ballots.reversed.map((b) { final excluded = (jsonDecode('${b['excluded_json']}') as List).join(', '); final edited = b['edited'] == 1; return Card(child: ListTile(leading: CircleAvatar(child: Text('${b['ballot_no']}')), title: Text(b['is_valid'] == 1 ? 'HỢP LỆ' : 'KHÔNG HỢP LỆ – ${b['invalid_reason']}', style: TextStyle(fontWeight: FontWeight.bold, color: b['is_valid'] == 1 ? Colors.green.shade800 : Colors.red.shade800)), subtitle: Text('Số bị bỏ: ${excluded.isEmpty ? 'Không có / phiếu trắng' : excluded}\n${edited ? 'ĐÃ SỬA' : 'CHƯA SỬA'} • ${_fmt(b['updated_at'])}'), isThreeLine: true, onTap: () => _ballotDetails(b), trailing: const Icon(Icons.chevron_right))); }).toList(),
  ]);

  Future<void> _ballotDetails(Map<String, Object?> b) async {
    final histories = await AppDatabase.instance.edits(b['id'] as int);
    if (!mounted) return;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => DraggableScrollableSheet(expand: false, initialChildSize: .78, maxChildSize: .95, builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.all(16), children: [
      Text('Chi tiết phiếu số ${b['ballot_no']}', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8), Text('Trạng thái: ${b['edited'] == 1 ? 'ĐÃ SỬA' : 'CHƯA SỬA'}', style: const TextStyle(fontWeight: FontWeight.bold)), Text('Cập nhật: ${_fmt(b['updated_at'])}'), const Divider(),
      FilledButton.icon(onPressed: () async { Navigator.pop(ctx); await _editBallotDialog(b); }, icon: const Icon(Icons.edit), label: const Text('Chỉnh sửa phiếu')),
      const SizedBox(height: 12), Text('Lịch sử sửa chữa', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      if (histories.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Text('Phiếu này chưa từng được sửa.')),
      ...histories.map((h) { final before = jsonDecode('${h['before_json']}') as Map; final after = jsonDecode('${h['after_json']}') as Map; return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_fmt(h['edited_at']), style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text('Trước: bị bỏ ${before['excluded_json']} • ${before['is_valid'] == 1 ? 'Hợp lệ' : 'Không hợp lệ: ${before['invalid_reason']}'}'), Text('Sau: bị bỏ ${after['excluded_json']} • ${after['is_valid'] == 1 ? 'Hợp lệ' : 'Không hợp lệ: ${after['invalid_reason']}'}')]))); }).toList(),
    ])));
  }

  Future<void> _editBallotDialog(Map<String, Object?> b) async {
    final initial = (jsonDecode('${b['excluded_json']}') as List).map((x) => x as int).toSet();
    final selected = <int>{...initial};
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(title: Text('Sửa phiếu số ${b['ballot_no']}'), content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: _candidates.map((c) { final seq = c['seq'] as int; return CheckboxListTile(value: selected.contains(seq), title: Text('$seq. ${c['name']}'), subtitle: const Text('Tích = người bị bỏ'), onChanged: (v) => setLocal(() { if (v == true) selected.add(seq); else selected.remove(seq); })); }).toList())), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu sửa chữa'))])));
    if (ok == true) { final result = _validateExcluded(selected.toList()); await AppDatabase.instance.editBallot(b, selected.toList()..sort(), result.$1, result.$2); await _load(_electionId!); }
  }

  (bool, String) _validateExcluded(List<int> excluded) {
    if (excluded.length == _candidates.length || (_candidates.isNotEmpty && excluded.isEmpty && (_election?['select_count'] as int? ?? 0) == 0)) return (false, 'PHIẾU TRẮNG');
    final required = _election?['exclude_count'] as int? ?? 0;
    return excluded.length == required ? (true, '') : (false, 'BỎ SAI SỐ LƯỢNG');
  }

  Widget _stats() {
    final valid = _ballots.where((b) => b['is_valid'] == 1).toList(); final invalid = _ballots.length - valid.length; final blank = _ballots.where((b) => '${b['invalid_reason']}' == 'PHIẾU TRẮNG').length;
    final counts = <int, int>{for (final c in _candidates) c['seq'] as int: 0};
    for (final b in valid) { final excluded = (jsonDecode('${b['excluded_json']}') as List).cast<int>().toSet(); for (final seq in counts.keys) { if (!excluded.contains(seq)) counts[seq] = counts[seq]! + 1; } }
    final ranking = _candidates.map((c) => (c: c, votes: counts[c['seq']] ?? 0)).toList()..sort((a,b) => b.votes.compareTo(a.votes));
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [Expanded(child: _metric('Đã nhập', '${_ballots.length}/${_election?['total_ballots'] ?? 0}', Icons.ballot)), Expanded(child: _metric('Hợp lệ', '$valid'.split('[').first == '[]' ? '0' : '${valid.length}', Icons.check_circle)), Expanded(child: _metric('Không hợp lệ', '$invalid', Icons.cancel))]),
      Row(children: [Expanded(child: _metric('Phiếu trắng', '$blank', Icons.description_outlined)), Expanded(child: _metric('Ứng cử viên', '${_candidates.length}', Icons.groups)), Expanded(child: _metric('Đã sửa', '${_ballots.where((b) => b['edited'] == 1).length}', Icons.edit_note))]),
      const SizedBox(height: 8), FilledButton.icon(onPressed: () => _exportPdf(ranking, valid.length, invalid, blank), icon: const Icon(Icons.picture_as_pdf), label: const Text('XUẤT / CHIA SẺ BÁO CÁO PDF')),
      const SizedBox(height: 10), Text('XẾP HẠNG KẾT QUẢ', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ...ranking.asMap().entries.map((entry) { final r = entry.value; final pct = valid.isEmpty ? 0.0 : r.votes * 100 / valid.length; return Card(child: ListTile(leading: CircleAvatar(child: Text('${entry.key + 1}')), title: Text('${r.c['name']}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: LinearProgressIndicator(value: pct / 100), trailing: Text('${r.votes}\n${pct.toStringAsFixed(1)}%', textAlign: TextAlign.right))); }).toList(),
    ]);
  }

  Widget _metric(String title, String value, IconData icon) => Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6), child: Column(children: [Icon(icon), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))])));

  Future<void> _exportPdf(List<({Map<String, Object?> c, int votes})> ranking, int valid, int invalid, int blank) async {
    final doc = pw.Document();
    String ascii(String s) { const a='àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ'; const b='aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD'; var out=s; for(var i=0;i<a.length;i++) { out=out.replaceAll(a[i], b[i]); } return out; }
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (_) => [pw.Text(ascii(_name.text.isEmpty ? 'BAO CAO KIEM DEM PHIEU BAU' : _name.text), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)), pw.Text(ascii('Don vi: ${_org.text}')), pw.SizedBox(height: 12), pw.TableHelper.fromTextArray(headers: ['Noi dung','So luong'], data: [['Tong phieu', _total.text], ['Da nhap', '${_ballots.length}'], ['Hop le', '$valid'], ['Khong hop le', '$invalid'], ['Phieu trang', '$blank']]), pw.SizedBox(height: 12), pw.Text('XEP HANG', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.TableHelper.fromTextArray(headers: ['Hang','Ho va ten','So phieu','Ty le'], data: ranking.asMap().entries.map((e) { final pct=valid==0?0:e.value.votes*100/valid; return ['${e.key+1}', ascii('${e.value.c['name']}'), '${e.value.votes}', '${pct.toStringAsFixed(1)}%']; }).toList())]));
    final bytes = await doc.save(); await Printing.sharePdf(bytes: bytes, filename: 'bao_cao_kiem_dem.pdf');
  }

  void _about() => showAboutDialog(context: context, applicationName: AppConstants.fullName, applicationVersion: '1.0.0', children: const [Text('Phát triển bởi: NGUYEN SANG'), Text('ZALO: 0976688173')]);
}

class BallotEntry extends StatefulWidget {
  const BallotEntry({super.key, required this.election, required this.candidates, required this.ballotCount, required this.onSaved});
  final Map<String, Object?> election; final List<Map<String, Object?>> candidates; final int ballotCount; final Future<void> Function() onSaved;
  @override State<BallotEntry> createState() => _BallotEntryState();
}

class _BallotEntryState extends State<BallotEntry> {
  bool numberMode = true; final input = TextEditingController(); final excluded = <int>{};
  (bool, String, List<int>) parse() {
    List<int> values;
    if (numberMode) { values = input.text.trim().isEmpty ? <int>[] : input.text.split(RegExp(r'[,;\s]+')).where((x) => x.isNotEmpty).map((x) => int.tryParse(x)).whereType<int>().toSet().toList(); } else { values = excluded.toList(); }
    values.sort();
    final max = widget.candidates.length;
    if (values.any((x) => x < 1 || x > max)) return (false, 'CÓ SỐ NGOÀI DANH SÁCH', values);
    if (values.length == max || (values.isEmpty && (widget.election['select_count'] as int? ?? 0) == 0)) return (false, 'PHIẾU TRẮNG', values);
    final required = widget.election['exclude_count'] as int? ?? 0;
    if (values.length != required) return (false, 'BỎ SAI SỐ LƯỢNG', values);
    return (true, '', values);
  }
  Future<void> save({bool blank = false}) async {
    final total = widget.election['total_ballots'] as int? ?? 0;
    if (total > 0 && widget.ballotCount >= total) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã nhập đủ tổng số phiếu. Hãy sửa tổng số phiếu trong Thiết lập.'))); return; }
    final result = blank ? (false, 'PHIẾU TRẮNG', List<int>.generate(widget.candidates.length, (i) => i + 1)) : parse();
    await AppDatabase.instance.addBallot(widget.election['id'] as int, result.$3, result.$1, result.$2);
    input.clear(); excluded.clear(); setState(() {}); await widget.onSaved();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.$1 ? 'Đã ghi phiếu hợp lệ' : 'Đã ghi phiếu không hợp lệ: ${result.$2}')));
  }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: [
    Row(children: [Expanded(child: Text('3. NHẬP PHIẾU', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))), SegmentedButton<bool>(segments: const [ButtonSegment(value: true, label: Text('Nhập số')), ButtonSegment(value: false, label: Text('Tích chọn'))], selected: {numberMode}, onSelectionChanged: (s) => setState(() => numberMode = s.first))]),
    const SizedBox(height: 10), Card(child: Padding(padding: const EdgeInsets.all(14), child: Text('Phiếu tiếp theo: ${widget.ballotCount + 1} • Số cần bỏ: ${widget.election['exclude_count']} • Tích/nhập số của người BỊ BỎ', style: const TextStyle(fontWeight: FontWeight.bold)))),
    if (numberMode) ...[TextField(controller: input, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(labelText: 'Nhập các số bị bỏ', hintText: 'Ví dụ: 2, 5, 7'), onSubmitted: (_) => save()), const SizedBox(height: 6), const Text('Các số cách nhau bằng dấu phẩy, dấu chấm phẩy hoặc khoảng trắng. Nhấn Enter để lưu phiếu.')]
    else ...widget.candidates.map((c) { final seq = c['seq'] as int; return CheckboxListTile(value: excluded.contains(seq), title: Text('$seq. ${c['name']}'), subtitle: Text('${c['note'] ?? ''}'), onChanged: (v) => setState(() { if (v == true) excluded.add(seq); else excluded.remove(seq); })); }),
    const SizedBox(height: 12), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => save(blank: true), icon: const Icon(Icons.description_outlined), label: const Text('GHI PHIẾU TRẮNG'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save), label: const Text('GHI PHIẾU')))]),
  ]);
}
