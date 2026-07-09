import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import 'kassa_controller.dart';
import '../shared/client_form.dart';

/// Kassa ichidagi «Клиент» tab: qidiruv, ro'yxat, biriktirish, yangi mijoz.
class ClientTab extends StatefulWidget {
  final KassaController ctrl;
  final VoidCallback onAttached;
  const ClientTab({super.key, required this.ctrl, required this.onAttached});
  @override
  State<ClientTab> createState() => _ClientTabState();
}

class _ClientTabState extends State<ClientTab> {
  String _q = '';

  int _discountOf(Client c) {
    final g = widget.ctrl.app.clientGroups.where((g) => g.name == c.group).toList();
    return g.isEmpty ? 0 : g.first.percent;
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.ctrl.app;
    final qd = _q.replaceAll(RegExp(r'[^0-9]'), '');
    final list = app.clients.where((c) => _q.isEmpty || c.name.toLowerCase().contains(_q.toLowerCase()) || (qd.isNotEmpty && c.phone.replaceAll(RegExp(r'[^0-9]'), '').contains(qd))).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Row(children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                style: AppTheme.sans(size: 15),
                decoration: InputDecoration(
                  hintText: 'Имя или телефон…',
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
                  isDense: true, filled: true, fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  hintStyle: AppTheme.sans(size: 15, color: AppColors.textTertiary),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _newClient,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
              child: Text('＋ Новый', style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ]),
      ),
      Expanded(
        child: list.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('👤', style: TextStyle(fontSize: 34)),
                  const SizedBox(height: 10),
                  Text('Клиент не найден', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Проверьте имя или добавьте нового', textAlign: TextAlign.center, style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
                ]),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                children: [
                  Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      for (int i = 0; i < list.length; i++) _clientRow(list[i], i == 0),
                    ]),
                  ),
                ],
              ),
      ),
    ]);
  }

  Widget _clientRow(Client c, bool first) {
    final attached = widget.ctrl.active.client?.id == c.id;
    final disc = _discountOf(c);
    return GestureDetector(
      onTap: () => _attach(c),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: attached ? AppColors.accentSoft : null,
          border: first ? null : const Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: const BoxDecoration(color: AppColors.bgSecondary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(c.initials, style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
            Text('${c.phone} · ${c.group}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
            if (c.bonus > 0) Text('💎 ${groupNum(c.bonus)} бон.', style: AppTheme.sans(size: 11.5, weight: FontWeight.w600, color: AppColors.warning)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(999)),
            child: Text('−$disc%', style: AppTheme.sans(size: 11.5, weight: FontWeight.w700, color: AppColors.success)),
          ),
          if (attached) ...[const SizedBox(width: 8), Text('✓', style: AppTheme.sans(size: 15, weight: FontWeight.w700, color: AppColors.success))],
        ]),
      ),
    );
  }

  void _attach(Client c) {
    if (widget.ctrl.active.client?.id == c.id) {
      widget.ctrl.detachClient();
      showToast(context, 'Клиент откреплён', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.person_off_outlined);
      return;
    }
    final disc = _discountOf(c);
    widget.ctrl.attachClient(c);
    showToast(context, disc > 0 ? '${c.name} — скидка $disc%' : '${c.name} прикреплён');
    widget.onAttached();
  }

  void _newClient() {
    showClientForm(context, widget.ctrl.app, onSaved: (c) {
      widget.ctrl.attachClient(c);
      widget.onAttached();
    });
  }
}
