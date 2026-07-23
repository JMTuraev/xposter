import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../state/app_state.dart';
import '../../models.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import '../../services/printer_service.dart';
import '../../services/printer_ui.dart';
import 'kassa_controller.dart';
import 'pin_screen.dart';
import 'payment_screen.dart';
import 'orders_screen.dart';
import 'functions_sheet.dart';
import 'client_tab.dart';

class KassaScreen extends StatefulWidget {
  const KassaScreen({super.key});
  @override
  State<KassaScreen> createState() => _KassaScreenState();
}

class _KassaScreenState extends State<KassaScreen> {
  KassaController? _ctrl;
  int _tab = 0; // 0 Чек, 1 Клиент
  int? _categoryId; // null = kategoriyalar ko'rinishi
  String _search = '';
  bool _searchOpen = false;
  bool _panelOpen = false;
  bool _dropOpen = false;
  bool _showHall = true; // kassa ochilganda avval zal xaritasi
  int _hallId = 0; // tanlangan zal (0 → birinchisi)

  @override
  void dispose() {
    // MUHIM: ctrl AppState'ga listener qo'shadi va debounce-timer ushlab turadi.
    // Dispose qilinmasa eski ctrl logout'dan keyin ham yangi kafening
    // openChecks'iga eski cheklarni yozib yuborishi mumkin edi.
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    _ctrl ??= KassaController(app);
    final ctrl = _ctrl!;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        if (ctrl.user == null) return PinScreen(ctrl: ctrl);
        if (_showHall) return _hallView(context, ctrl, app);
        return Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: Column(
              children: [
                _topBar(ctrl),
                Expanded(
                  child: Stack(children: [
                    Column(children: [
                      Expanded(
                        child: _tab == 0
                            ? _checkTab(ctrl)
                            : ClientTab(ctrl: ctrl, onAttached: () => setState(() => _tab = 0)),
                      ),
                      _cartPanel(ctrl),
                    ]),
                    if (_dropOpen)
                      Positioned.fill(child: GestureDetector(onTap: () => setState(() => _dropOpen = false), child: const SizedBox())),
                    if (_dropOpen) _dropdownOverlay(ctrl),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Qora yuqori panel ──
  Widget _topBar(KassaController ctrl) {
    return Container(
      color: AppColors.posDark,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        children: [
          Row(children: [
            GestureDetector(
              onTap: () => setState(() { _dropOpen = false; _showHall = true; }),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 6, 8, 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('‹', style: TextStyle(fontSize: 18, color: Colors.white, height: 1)),
                  const SizedBox(width: 2),
                  Text('Залы', style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: Colors.white)),
                ]),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _dropOpen = !_dropOpen),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(9)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Чек №${ctrl.active.number}', style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(width: 6),
                  const Text('▼', style: TextStyle(fontSize: 8.5, color: Colors.white70)),
                ]),
              ),
            ),
            const Spacer(),
            _darkBtn('🗃', onTap: () {
              setState(() => _dropOpen = false);
              Navigator.push(context, MaterialPageRoute(builder: (_) => OrdersScreen(ctrl: ctrl, initialTab: 1)));
            }),
            const SizedBox(width: 2),
            _darkBtn('☰', onTap: () { setState(() => _dropOpen = false); showFunctionsSheet(context, ctrl); }),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: () { context.read<AppState>().lock(); },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text((ctrl.user?.name ?? 'Кассир').split(' ').first, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(width: 5),
                  const Text('🔒', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF8FBC66), shape: BoxShape.circle)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: const Color(0x47000000), borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(3),
            child: Row(children: [
              Expanded(child: _segTab('Чек', 0, ctrl)),
              const SizedBox(width: 3),
              Expanded(child: _segTab('Клиент', 1, ctrl)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _darkBtn(String glyph, {VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(width: 32, height: 32, alignment: Alignment.center, child: Text(glyph, style: const TextStyle(fontSize: 15, color: Colors.white))),
      );

  Widget _segTab(String label, int i, KassaController ctrl) {
    final active = _tab == i;
    final showMark = i == 1 && ctrl.active.client != null;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFAF9F5) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: active ? AppColors.text : const Color(0xFFB9B6AB))),
          if (showMark) ...[const SizedBox(width: 5), Text('✓', style: AppTheme.sans(size: 13, weight: FontWeight.w700, color: AppColors.success))],
        ]),
      ),
    );
  }

  Widget _dropdownOverlay(KassaController ctrl) {
    return Positioned(
      top: 4,
      left: 0, right: 0,
      child: Center(
        child: Container(
          width: 250,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(color: Color(0x38141413), blurRadius: 34, offset: Offset(0, 14))]),
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ...List.generate(ctrl.checks.length, (i) {
              final c = ctrl.checks[i];
              final activeRow = i == ctrl.activeIndex;
              return GestureDetector(
                onTap: () { ctrl.switchCheck(i); setState(() => _dropOpen = false); },
                child: Container(
                  color: activeRow ? AppColors.accentSoft : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Чек №${c.number}', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600)),
                      Text('${c.lines.length} поз. · ${sum(c.dueFor(ctrl.app))}', style: AppTheme.sans(size: 11.5, color: AppColors.textTertiary)),
                    ])),
                    if (activeRow) Text('✓', style: AppTheme.sans(size: 14, weight: FontWeight.w700, color: AppColors.success)),
                  ]),
                ),
              );
            }),
            GestureDetector(
              onTap: () { ctrl.newCheck(); setState(() => _dropOpen = false); showToast(context, 'Создан чек №${ctrl.active.number}'); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('＋', style: AppTheme.sans(size: 16, weight: FontWeight.w600, color: AppColors.accentHover)),
                  const SizedBox(width: 7),
                  Text('Создать новый чек', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600, color: AppColors.accentHover)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Чек tab: katalog ──
  Widget _checkTab(KassaController ctrl) => _catalog(ctrl);

  Widget _catalog(KassaController ctrl) {
    final app = ctrl.app;
    final cat = _categoryId == null ? null : app.categoryById(_categoryId!);
    final q = _search.trim().toLowerCase();
    // Kategoriya yo'q (yoki barcha tovar kategoriyasiz) bo'lsa — tovarlarni
    // to'g'ridan-to'g'ri ko'rsatamiz, «Меню пусто» deb yolg'on gapirmaymiz.
    final visibleCats = app.categories.where((c) => !c.hidden).toList();
    final noCats = visibleCats.isEmpty && app.products.isNotEmpty;
    final showItems = _categoryId != null || q.isNotEmpty || noCats;
    List<Product> products;
    if (q.isNotEmpty) {
      products = app.products.where((p) => p.name.toLowerCase().contains(q)).toList();
    } else if (_categoryId == -1) {
      // «Прочее» — kategoriyasi o'chirilgan/mavjud bo'lmagan tovarlar
      final ids = app.categories.map((c) => c.id).toSet();
      products = app.products.where((p) => !ids.contains(p.categoryId)).toList();
    } else if (_categoryId != null) {
      products = app.products.where((p) => p.categoryId == _categoryId).toList();
    } else if (noCats) {
      products = app.products.toList();
    } else {
      products = [];
    }

    return Column(
      children: [
        // Header: breadcrumb / search
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: _searchOpen
              ? Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setState(() => _search = v),
                        style: AppTheme.sans(size: 15),
                        decoration: InputDecoration(
                          hintText: 'Поиск по меню…',
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
                          isDense: true,
                          filled: true, fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          hintStyle: AppTheme.sans(size: 15, color: AppColors.textTertiary),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.borderStrong)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() { _searchOpen = false; _search = ''; }),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), child: Text('Отмена', style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: AppColors.textSecondary))),
                  ),
                ])
              : Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { _categoryId = null; }),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Все товары', style: AppTheme.sans(size: 13.5, weight: FontWeight.w600, color: _categoryId == null ? AppColors.text : AppColors.accentHover)),
                        if (cat != null) ...[
                          Text('  ›  ', style: AppTheme.sans(size: 13.5, color: AppColors.textTertiary)),
                          Flexible(child: Text(cat.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 13.5, weight: FontWeight.w600))),
                        ],
                      ]),
                    ),
                  ),
                  _sqIcon(const Icon(Icons.qr_code_scanner, size: 18, color: AppColors.textSecondary), () => showToast(context, 'Сканер штрих-кодов не подключён', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.info_outline)),
                  const SizedBox(width: 7),
                  _sqIcon(const Icon(Icons.search, size: 18, color: AppColors.textSecondary), () => setState(() => _searchOpen = true)),
                  const SizedBox(width: 7),
                  GestureDetector(
                    onTap: () {
                      final promos = ctrl.app.promotionsList.where((p) => p['active'] == true).toList();
                      showToast(
                        context,
                        promos.isEmpty
                            ? 'Активных акций нет — создайте в «Ещё → Маркетинг»'
                            : 'Акция «${promos.first['name']}» применяется автоматически',
                        color: AppColors.accentHover, bg: AppColors.accentSoft, icon: Icons.local_offer_outlined,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(10)),
                      child: Text('Акции', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.accentHover)),
                    ),
                  ),
                ]),
        ),
        Expanded(
          child: !showItems ? _categoryGrid(ctrl) : _productGrid(ctrl, products),
        ),
      ],
    );
  }

  Widget _sqIcon(Widget child, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)), child: child),
      );

  Widget _categoryGrid(KassaController ctrl) {
    final cats = ctrl.app.categories.where((c) => !c.hidden).toList();
    if (cats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🍽️', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text('Меню пусто', style: AppTheme.sans(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text('Добавьте категории и блюда во вкладке «Меню» внизу экрана', textAlign: TextAlign.center, style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary, height: 1.4)),
        ]),
      );
    }
    // Kategoriyasi yo'q tovarlar bo'lsa — «Прочее» plitkasi (ular ham sotilsin).
    final ids = ctrl.app.categories.map((c) => c.id).toSet();
    final hasOrphans = ctrl.app.products.any((p) => !ids.contains(p.categoryId));
    return GridView.extent(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
      maxCrossAxisExtent: 170, // planshetda ustunlar soni avtomatik oshadi
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.9,
      children: [
        ...cats.map((c) {
          return GestureDetector(
            onTap: () => setState(() => _categoryId = c.id),
            child: Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_catEmoji(c.name), style: const TextStyle(fontSize: 27)),
                const SizedBox(height: 7),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(c.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 11.5, weight: FontWeight.w600, height: 1.25))),
              ]),
            ),
          );
        }),
        if (hasOrphans)
          GestureDetector(
            onTap: () => setState(() => _categoryId = -1),
            child: Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('🗂️', style: TextStyle(fontSize: 27)),
                const SizedBox(height: 7),
                Text('Прочее', style: AppTheme.sans(size: 11.5, weight: FontWeight.w600, height: 1.25)),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _productGrid(KassaController ctrl, List<Product> products) {
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🔍', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 10),
          Text('Ничего не найдено', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Попробуйте изменить запрос', style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
        ]),
      );
    }
    return GridView.extent(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
      maxCrossAxisExtent: 150, // planshetda ustunlar soni avtomatik oshadi
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.76,
      children: products.map((p) {
        final inCheck = ctrl.active.lines.where((l) => l.product.id == p.id).fold<double>(0, (s, l) => s + l.qty);
        return GestureDetector(
          onTap: () => _addProduct(ctrl, p),
          // StackFit.expand: kartochka katakni to'liq egallaydi. Aks holda Stack
          // bolasiga loose constraint beradi va qisqa nomli tovar («Choy») torayib,
          // «×N» nishoni kartochkadan uzoqda — katak chetida osilib qoladi.
          child: Stack(fit: StackFit.expand, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                ProductThumb(imagePath: p.imagePath, emoji: p.photo, size: 46, radius: 12),
                const SizedBox(height: 5),
                Text(p.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 11, weight: FontWeight.w600, height: 1.25)),
                const SizedBox(height: 4),
                Text(groupNum(p.price), style: AppTheme.sans(size: 11.5, weight: FontWeight.w700, color: AppColors.textSecondary)),
              ]),
            ),
            if (inCheck > 0)
              Positioned(
                top: 5, right: 5,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20), height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(999)),
                  child: Text('×${qty(inCheck)}', style: AppTheme.sans(size: 10.5, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
          ]),
        );
      }).toList(),
    );
  }

  void _addProduct(KassaController ctrl, Product p) {
    if (p.modifications != null && p.modifications!.isNotEmpty) {
      _modSheet(ctrl, p);
    } else {
      ctrl.addProduct(p);
    }
  }

  void _modSheet(KassaController ctrl, Product p) {
    _sheet(
      titleWidget: Text('${p.photo} ${p.name}', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
      children: (ctx) => [
        Padding(padding: const EdgeInsets.only(top: 4), child: Text('Выберите вариант', style: AppTheme.sans(size: 13, color: AppColors.textSecondary))),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (int i = 0; i < p.modifications!.length; i++)
              GestureDetector(
                onTap: () { ctrl.addProduct(p, modification: p.modifications![i].name); Navigator.pop(ctx); },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.border))),
                  child: Row(children: [
                    Expanded(child: Text(p.modifications![i].name, style: AppTheme.sans(size: 14.5, weight: FontWeight.w600))),
                    Text(groupNum(p.price), style: AppTheme.sans(size: 13.5, weight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.textTertiary),
                  ]),
                ),
              ),
          ]),
        ),
      ],
    );
  }

  // ── Savat paneli (yig'iladigan pastki panel) ──
  Widget _cartPanel(KassaController ctrl) {
    final doc = ctrl.active;
    final due = doc.dueFor(ctrl.app);
    final count = doc.lines.fold<double>(0, (s, l) => s + l.qty);
    final where = doc.tableId != null
        ? '🍽 ${_tableName(ctrl.app, doc.tableId!)}${doc.guests > 0 ? ' · ${doc.guests} гост.' : ''}'
        : (doc.orderType == 'Навынос' ? '🥡 Навынос' : '');
    final subParts = <String>[
      if (where.isNotEmpty) where,
      if (doc.lines.isNotEmpty) '${qty(count)} поз.',
      if (doc.client != null) doc.client!.name,
    ];
    final sub = subParts.isEmpty ? 'Чек пуст' : subParts.join(' · ');
    return Container(
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => setState(() => _panelOpen = !_panelOpen),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 9, 16, 2),
                child: Row(children: [
                  Text('Чек №${doc.number}', style: AppTheme.sans(size: 13, weight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(sub, style: AppTheme.sans(size: 12, color: AppColors.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text(_panelOpen ? 'свернуть ⌄' : 'развернуть ⌃', style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
                ]),
              ),
            ),
            if (_panelOpen) _panelBody(ctrl),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(children: [
                _panelSqBtn(const Text('⋯', style: TextStyle(fontSize: 19, color: AppColors.textSecondary)), () => _checkMenu(ctrl)),
                const SizedBox(width: 8),
                _panelSqBtn(const Text('🖨', style: TextStyle(fontSize: 16)), () {
                  // Pречек: joriy chekni real Wi-Fi printerga chiqaradi (printer yo'q bo'lsa — ro'yxat ochiladi).
                  if (doc.lines.isEmpty) {
                    showToast(context, 'Чек пуст', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.info_outline);
                    return;
                  }
                  final now = DateTime.now();
                  String two(int n) => n.toString().padLeft(2, '0');
                  final rc = ReceiptData(
                    venue: ctrl.app.company['name'] as String,
                    address: ctrl.app.company['address'] as String?,
                    checkNo: '№${doc.number} (пречек)',
                    cashier: ctrl.user?.name ?? 'Кассир',
                    dateTime: '${two(now.day)}.${two(now.month)}.${now.year} ${two(now.hour)}:${two(now.minute)}',
                    items: doc.lines
                        .map((l) => ReceiptLine(name: l.product.name + (l.modification != null ? ' (${l.modification})' : ''), qty: l.qty, price: l.product.price))
                        .toList(),
                    subtotal: doc.subtotal,
                    discountLabel: doc.discountPctFor(ctrl.app) > 0 ? 'Скидка ${doc.discountPctFor(ctrl.app)}%' : null,
                    discountAmount: doc.discountAmountFor(ctrl.app),
                    serviceLabel: doc.serviceFeePctFor(ctrl.app) > 0 ? 'Обслуживание ${doc.serviceFeePctFor(ctrl.app)}%' : null,
                    serviceAmount: doc.serviceAmountFor(ctrl.app),
                    total: due,
                    paymentLabel: 'Предчек (к оплате)',
                    footer: 'Предчек — не фискальный документ',
                  );
                  ensurePrinterAndPrint(context, rc);
                }),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: doc.lines.isEmpty ? null : () {
                      setState(() => _dropOpen = false);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(ctrl: ctrl)));
                    },
                    child: Opacity(
                      opacity: due > 0 ? 1 : 0.5,
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(AppRadius.btn)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Оплатить', style: AppTheme.sans(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(width: 10),
                          Text(sum(due), style: AppTheme.serif(size: 15.5, weight: FontWeight.w700, color: Colors.white)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelSqBtn(Widget child, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.btn), border: Border.all(color: AppColors.borderStrong)), child: child),
      );

  Widget _panelBody(KassaController ctrl) {
    final doc = ctrl.active;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 262),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(child: Text('НАИМЕНОВАНИЕ', style: AppTheme.sans(size: 10.5, weight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.4))),
              SizedBox(width: 40, child: Text('КОЛ-ВО', textAlign: TextAlign.center, style: AppTheme.sans(size: 10.5, weight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.4))),
              SizedBox(width: 62, child: Text('ЦЕНА', textAlign: TextAlign.right, style: AppTheme.sans(size: 10.5, weight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.4))),
              SizedBox(width: 66, child: Text('ИТОГО', textAlign: TextAlign.right, style: AppTheme.sans(size: 10.5, weight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.4))),
            ]),
          ),
          if (doc.lines.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 22, 10, 18),
              child: Center(child: Column(children: [
                const Text('🧾', style: TextStyle(fontSize: 26)),
                const SizedBox(height: 6),
                Text('Чек пуст', style: AppTheme.sans(size: 13, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Добавьте блюда из каталога выше', style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
              ])),
            )
          else
            ...doc.lines.map((l) {
              final mod = l.modification ?? '';
              final com = l.comment != null ? '💬 ${l.comment}' : '';
              final modLine = mod + (mod.isNotEmpty && com.isNotEmpty ? ' · ' : '') + com;
              return GestureDetector(
                onTap: () => _lineSheet(ctrl, l),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.product.name, style: AppTheme.sans(size: 13, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (modLine.isNotEmpty) Text(modLine, style: AppTheme.sans(size: 11, color: AppColors.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                    SizedBox(width: 40, child: Text(qty(l.qty), textAlign: TextAlign.center, style: AppTheme.sans(size: 13, weight: FontWeight.w600))),
                    SizedBox(width: 62, child: Text(groupNum(l.product.price), textAlign: TextAlign.right, style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary))),
                    SizedBox(width: 66, child: Text(groupNum(l.total), textAlign: TextAlign.right, style: AppTheme.sans(size: 13, weight: FontWeight.w600))),
                  ]),
                ),
              );
            }),
          if (doc.client != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(11, 6, 6, 6),
                  decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('👤 ${doc.client!.name} · −${ctrl.discountPct}%', style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: AppColors.accentHover)),
                    const SizedBox(width: 7),
                    GestureDetector(
                      onTap: () { ctrl.detachClient(); showToast(context, 'Клиент откреплён', color: AppColors.textSecondary, bg: AppColors.bgSecondary, icon: Icons.person_off_outlined); },
                      child: Container(width: 20, height: 20, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0x24C96442), shape: BoxShape.circle), child: const Text('✕', style: TextStyle(fontSize: 10, color: AppColors.accentHover))),
                    ),
                  ]),
                ),
              ]),
            ),
          if (doc.comment != null)
            Padding(padding: const EdgeInsets.only(top: 7, bottom: 2), child: Text('💬 ${doc.comment}', style: AppTheme.sans(size: 12, color: AppColors.textSecondary))),
          if (ctrl.discountAmount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(children: [
                Text('Скидка клиента ${ctrl.discountPct}%', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.success)),
                const Spacer(),
                Text('−${sum(ctrl.discountAmount)}', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.success)),
              ]),
            ),
          if (doc.serviceFeePctFor(ctrl.app) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Row(children: [
                Text('Обслуживание ${doc.serviceFeePctFor(ctrl.app)}%', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.textSecondary)),
                const Spacer(),
                Text('+${sum(doc.serviceAmountFor(ctrl.app))}', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.textSecondary)),
              ]),
            ),
        ]),
      ),
    );
  }

  // ── Pozitsiya sheet ──
  void _lineSheet(KassaController ctrl, OrderLine l) {
    final commentCtrl = TextEditingController(text: l.comment ?? '');
    _sheet(
      titleWidget: Text('${l.product.photo} ${l.product.name}', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
      children: (ctx) => [
        Padding(padding: const EdgeInsets.only(top: 3), child: Text(l.modification ?? sum(l.product.price), style: AppTheme.sans(size: 13, color: AppColors.textSecondary))),
        const SizedBox(height: 16),
        Text('КОЛИЧЕСТВО', style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        StatefulBuilder(builder: (ctx2, setSheet) {
          void upd(double d) {
            final nq = (l.qty + d);
            if (nq <= 0) { ctrl.removeLine(l); Navigator.pop(ctx); return; }
            setSheet(() => l.qty = double.parse(nq.toStringAsFixed(2)));
            ctrl.refresh();
          }
          return Row(children: [
            _qtyBtn('−1', () => upd(-1)),
            const SizedBox(width: 6),
            _qtyBtn('−0,5', () => upd(-0.5)),
            const SizedBox(width: 6),
            Expanded(child: Container(height: 46, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: AppColors.borderStrong, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text(qty(l.qty), style: AppTheme.serif(size: 19, weight: FontWeight.w700)))),
            const SizedBox(width: 6),
            _qtyBtn('+0,5', () => upd(0.5)),
            const SizedBox(width: 6),
            _qtyBtn('+1', () => upd(1)),
          ]);
        }),
        const SizedBox(height: 14),
        Text('КОММЕНТАРИЙ К ПОЗИЦИИ', style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        _sheetInput(commentCtrl, 'Например: без лука, поострее…'),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () { ctrl.removeLine(l); Navigator.pop(ctx); },
            child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text('Удалить', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600, color: AppColors.danger))),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: GestureDetector(
            onTap: () { ctrl.setLineComment(l, commentCtrl.text); Navigator.pop(ctx); },
            child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text('Готово', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600, color: Colors.white))),
          )),
        ]),
      ],
    );
  }

  Widget _qtyBtn(String label, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text(label, style: AppTheme.sans(size: 14.5, weight: FontWeight.w700))),
        ),
      );

  // ── Chek amallari menyusi (⋯) ──
  void _checkMenu(KassaController ctrl) {
    _sheet(
      titleWidget: Text('Чек №${ctrl.active.number}', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
      children: (ctx) => [
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            _menuRow('💬', 'Комментарий к чеку', AppColors.text, false, () { Navigator.pop(ctx); _checkComment(ctrl); }),
            _menuRow('🚫', 'Закрыть без оплаты', AppColors.text, true, () { Navigator.pop(ctx); _closeNoPay(ctrl); }),
            _menuRow('🧹', 'Очистить заказ', AppColors.danger, true, () { Navigator.pop(ctx); _clearConfirm(ctrl); }, iconBg: AppColors.dangerSoft),
          ]),
        ),
      ],
    );
  }

  Widget _menuRow(String emoji, String label, Color color, bool top, VoidCallback onTap, {Color iconBg = AppColors.bgSecondary}) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(border: top ? const Border(top: BorderSide(color: AppColors.border)) : null),
          child: Row(children: [
            Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)), child: Text(emoji, style: const TextStyle(fontSize: 16))),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTheme.sans(size: 14.5, weight: FontWeight.w500, color: color))),
            const Icon(Icons.chevron_right, size: 17, color: AppColors.textTertiary),
          ]),
        ),
      );

  void _checkComment(KassaController ctrl) {
    final noteCtrl = TextEditingController(text: ctrl.active.comment ?? '');
    _sheet(
      titleWidget: Text('Комментарий к чеку', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
      children: (ctx) => [
        Padding(padding: const EdgeInsets.only(top: 4), child: Text('Виден кассиру и печатается на кухонном бегунке', style: AppTheme.sans(size: 13, color: AppColors.textSecondary))),
        const SizedBox(height: 14),
        _sheetInput(noteCtrl, 'Например: подать всё вместе, стол у окна…'),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () { ctrl.active.comment = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(); ctrl.refresh(); Navigator.pop(ctx); showToast(context, 'Комментарий сохранён'); },
          child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text('Сохранить', style: AppTheme.sans(size: 14.5, weight: FontWeight.w600, color: Colors.white))),
        ),
      ],
    );
  }

  void _clearConfirm(KassaController ctrl) {
    _confirmSheet(
      emoji: '🧹',
      title: 'Очистить заказ?',
      body: 'Все позиции, клиент и комментарий будут удалены из текущего чека.',
      confirmLabel: 'Очистить',
      onConfirm: () { ctrl.clearActive(); showToast(context, 'Заказ очищен', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.cleaning_services_outlined); },
    );
  }

  void _closeNoPay(KassaController ctrl) {
    final n = ctrl.active.number;
    _confirmSheet(
      emoji: '🚫',
      title: 'Закрыть без оплаты?',
      body: 'Чек №$n будет закрыт, позиции не будут оплачены. Действие необратимо.',
      confirmLabel: 'Закрыть без оплаты',
      onConfirm: () { ctrl.closeWithoutPay(); showToast(context, 'Чек №$n закрыт без оплаты', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.block); },
    );
  }

  // ── Umumiy sheet yordamchilari ──
  void _sheet({required Widget titleWidget, required List<Widget> Function(BuildContext) children}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 34 + MediaQuery.of(ctx).viewPadding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(999)), margin: const EdgeInsets.only(bottom: 16))),
            titleWidget,
            ...children(ctx),
          ]),
        ),
      ),
    );
  }

  void _confirmSheet({required String emoji, required String title, required String body, required String confirmLabel, required VoidCallback onConfirm}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
        top: false,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 5, decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(999)), margin: const EdgeInsets.only(bottom: 16)),
          Text(emoji, style: const TextStyle(fontSize: 38)),
          const SizedBox(height: 6),
          Text(title, style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: AppTheme.sans(size: 13.5, height: 1.5, color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () { Navigator.pop(ctx); onConfirm(); },
            child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text(confirmLabel, style: AppTheme.sans(size: 15, weight: FontWeight.w600, color: AppColors.danger))),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.btn), border: Border.all(color: AppColors.borderStrong)), child: Text('Отмена', style: AppTheme.sans(size: 15, weight: FontWeight.w600))),
          ),
        ]),
      ),
      ),
      ),
    );
  }

  Widget _sheetInput(TextEditingController ctrl, String hint) => TextField(
        controller: ctrl,
        style: AppTheme.sans(size: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true, fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          hintStyle: AppTheme.sans(size: 13.5, color: AppColors.textTertiary),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: const BorderSide(color: AppColors.borderStrong)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: const BorderSide(color: AppColors.borderStrong)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.btn), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        ),
      );

  String _catEmoji(String name) {
    switch (name) {
      case 'Основные блюда': return '🍛';
      case 'Шашлыки': return '🍢';
      case 'Салаты': return '🥗';
      case 'Выпечка': return '🫓';
      case 'Горячие напитки': return '🫖';
      case 'Холодные напитки': return '🥤';
      default: return '🍽️';
    }
  }

  // ══════════════ ZAL XARITASI (карта зала) ══════════════
  String _tableName(AppState app, int id) {
    final t = app.tables.where((t) => t.id == id).toList();
    return t.isEmpty ? 'Стол' : t.first.name;
  }

  Widget _hallView(BuildContext context, KassaController ctrl, AppState app) {
    if (_hallId == 0 || !app.halls.any((h) => h.id == _hallId)) {
      _hallId = app.halls.isEmpty ? 0 : app.halls.first.id;
    }
    final tables = _hallId == 0 ? <RestTable>[] : app.tablesIn(_hallId);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          // Qora yuqori panel
          Container(
            color: AppColors.posDark,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(children: [
              Text('Залы', style: AppTheme.serif(size: 19, weight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              GestureDetector(
                onTap: () => _serviceSheet(context, app),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(9)),
                  child: Text(app.serviceFeePct > 0 ? 'Обсл. ${app.serviceFeePct}%' : 'Обсл. —', style: AppTheme.sans(size: 12, weight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.read<AppState>().lock(),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text((ctrl.user?.name ?? '').split(' ').first, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(width: 5),
                  const Text('🔒', style: TextStyle(fontSize: 12)),
                ]),
              ),
            ]),
          ),
          // Zal chiplari
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final h in app.halls)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _hallId = h.id),
                      onLongPress: () => _editHall(context, app, h),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: h.id == _hallId ? AppColors.accent : AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: h.id == _hallId ? AppColors.accent : AppColors.border),
                        ),
                        child: Text(h.name, style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: h.id == _hallId ? Colors.white : AppColors.textSecondary)),
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: () => _addHall(context, app),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.border)),
                    child: Text('＋ зал', style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
          // Stollar
          Expanded(
            child: app.halls.isEmpty
                ? _hallEmpty(context, app)
                : GridView.extent(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    maxCrossAxisExtent: 190, // planshetda ustunlar ko'payadi
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.92,
                    children: [
                      for (final t in tables) _tableCard(context, ctrl, app, t),
                      _addTableCard(context, app),
                    ],
                  ),
          ),
          // Навынос
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: GestureDetector(
              onTap: () { ctrl.startTakeaway(); setState(() => _showHall = false); },
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.btn), border: Border.all(color: AppColors.borderStrong)),
                child: Text('🥡 Навынос (без стола)', style: AppTheme.sans(size: 14, weight: FontWeight.w600)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tableCard(BuildContext context, KassaController ctrl, AppState app, RestTable t) {
    final occupied = ctrl.isTableOccupied(t.id);
    final due = ctrl.tableDue(t.id);
    return GestureDetector(
      onTap: () {
        if (occupied) {
          final ex = ctrl.checks.firstWhere((c) => c.tableId == t.id);
          ctrl.openTable(hallId: t.hallId, tableId: t.id, guests: ex.guests);
          setState(() => _showHall = false);
        } else {
          _askGuests(context, ctrl, t);
        }
      },
      onLongPress: () => _editTable(context, app, t),
      child: Container(
        decoration: BoxDecoration(
          color: occupied ? AppColors.accentSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: occupied ? AppColors.accent : AppColors.border, width: occupied ? 1.5 : 1),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('🍽', style: TextStyle(fontSize: 22, color: occupied ? AppColors.accentHover : AppColors.textTertiary)),
          const SizedBox(height: 4),
          Text(t.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(size: 13, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('${t.seats} мест', style: AppTheme.sans(size: 10.5, color: AppColors.textTertiary)),
          const SizedBox(height: 3),
          occupied
              ? Text(sum(due), style: AppTheme.sans(size: 11, weight: FontWeight.w700, color: AppColors.accentHover))
              : Text('свободен', style: AppTheme.sans(size: 10, weight: FontWeight.w600, color: AppColors.success)),
        ]),
      ),
    );
  }

  Widget _addTableCard(BuildContext context, AppState app) {
    return GestureDetector(
      onTap: () => _addTable(context, app),
      child: Container(
        decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        alignment: Alignment.center,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('＋', style: TextStyle(fontSize: 22, color: AppColors.textTertiary)),
          const SizedBox(height: 2),
          Text('стол', style: AppTheme.sans(size: 11, color: AppColors.textTertiary)),
        ]),
      ),
    );
  }

  Widget _hallEmpty(BuildContext context, AppState app) {
    return Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🏛', style: TextStyle(fontSize: 40)),
      const SizedBox(height: 10),
      Text('Залов пока нет', style: AppTheme.sans(size: 15, weight: FontWeight.w700)),
      const SizedBox(height: 5),
      Text('Создайте зал, затем добавьте столы', textAlign: TextAlign.center, style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
      const SizedBox(height: 14),
      PrimaryButton('＋ Создать зал', expand: false, onPressed: () => _addHall(context, app)),
    ])));
  }

  void _askGuests(BuildContext context, KassaController ctrl, RestTable t) {
    int guests = t.seats;
    _sheet(
      titleWidget: Text('${t.name} · открыть заказ', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
      children: (ctx) => [
        const SizedBox(height: 8),
        Text('Количество гостей за столом', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        StatefulBuilder(builder: (ctx2, setS) => Row(children: [
          _qtyBtn('−1', () { if (guests > 1) setS(() => guests--); }),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 46, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: AppColors.borderStrong, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text('$guests', style: AppTheme.serif(size: 19, weight: FontWeight.w700)))),
          const SizedBox(width: 8),
          _qtyBtn('+1', () => setS(() => guests++)),
        ])),
        const SizedBox(height: 16),
        PrimaryButton('Открыть стол', onPressed: () {
          ctrl.openTable(hallId: t.hallId, tableId: t.id, guests: guests);
          Navigator.pop(ctx);
          setState(() => _showHall = false);
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  void _serviceSheet(BuildContext context, AppState app) {
    final custom = TextEditingController(text: app.serviceFeePct.toString());
    _sheet(
      titleWidget: Text('Процент за обслуживание', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
      children: (ctx) => [
        const SizedBox(height: 6),
        Text('Добавляется к счёту заказов в зале (со столом).', style: AppTheme.sans(size: 12.5, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        StatefulBuilder(builder: (ctx2, setS) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [0, 5, 10, 15].map((p) {
            final active = app.serviceFeePct == p;
            return GestureDetector(
              onTap: () { app.setServiceFeePct(p); custom.text = p.toString(); setS(() {}); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(color: active ? AppColors.accent : AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? AppColors.accent : AppColors.border)),
                child: Text(p == 0 ? 'Не использовать' : '$p%', style: AppTheme.sans(size: 13, weight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
              ),
            );
          }).toList()),
          const SizedBox(height: 14),
          Text('Своё значение, %', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _sheetInput(custom, 'Например: 7')),
            const SizedBox(width: 8),
            PrimaryButton('OK', expand: false, onPressed: () {
              final v = (int.tryParse(custom.text.trim()) ?? 0).clamp(0, 100).toInt();
              app.setServiceFeePct(v);
              setS(() {});
            }),
          ]),
        ])),
        const SizedBox(height: 12),
        PrimaryButton('Готово', onPressed: () => Navigator.pop(ctx)),
        const SizedBox(height: 8),
      ],
    );
  }

  void _addHall(BuildContext context, AppState app) {
    final name = TextEditingController();
    _sheet(
      titleWidget: Text('Новый зал', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
      children: (ctx) => [
        const SizedBox(height: 10),
        _sheetInput(name, 'Название зала — например: Терраса'),
        const SizedBox(height: 14),
        PrimaryButton('Создать', onPressed: () {
          if (name.text.trim().isEmpty) { showToast(context, 'Введите название', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
          app.addHall(name.text.trim());
          _hallId = app.halls.last.id;
          Navigator.pop(ctx);
          setState(() {});
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  void _editHall(BuildContext context, AppState app, Hall h) {
    final name = TextEditingController(text: h.name);
    _sheet(
      titleWidget: Text('Зал «${h.name}»', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
      children: (ctx) => [
        const SizedBox(height: 10),
        _sheetInput(name, 'Название зала'),
        const SizedBox(height: 14),
        PrimaryButton('Сохранить', onPressed: () {
          if (name.text.trim().isNotEmpty) app.renameHall(h, name.text.trim());
          Navigator.pop(ctx);
          setState(() {});
        }),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            app.removeHall(h.id);
            Navigator.pop(ctx);
            setState(() => _hallId = app.halls.isEmpty ? 0 : app.halls.first.id);
          },
          child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text('Удалить зал и его столы', style: AppTheme.sans(size: 14, weight: FontWeight.w600, color: AppColors.danger))),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _addTable(BuildContext context, AppState app) {
    if (app.halls.isEmpty) { showToast(context, 'Сначала создайте зал', color: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.info_outline); return; }
    final name = TextEditingController(text: 'Стол ${app.tablesIn(_hallId).length + 1}');
    int seats = 4;
    _sheet(
      titleWidget: Text('Новый стол', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
      children: (ctx) => [
        const SizedBox(height: 10),
        _sheetInput(name, 'Название/номер стола'),
        const SizedBox(height: 12),
        Text('Количество мест', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        StatefulBuilder(builder: (ctx2, setS) => Row(children: [
          _qtyBtn('−1', () { if (seats > 1) setS(() => seats--); }),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 46, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: AppColors.borderStrong, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text('$seats мест', style: AppTheme.serif(size: 17, weight: FontWeight.w700)))),
          const SizedBox(width: 8),
          _qtyBtn('+1', () => setS(() => seats++)),
        ])),
        const SizedBox(height: 16),
        PrimaryButton('Добавить стол', onPressed: () {
          if (name.text.trim().isEmpty) { showToast(context, 'Введите название', color: AppColors.danger, bg: AppColors.dangerSoft, icon: Icons.error_outline); return; }
          app.addTable(_hallId, name.text.trim(), seats);
          Navigator.pop(ctx);
          setState(() {});
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  void _editTable(BuildContext context, AppState app, RestTable t) {
    final name = TextEditingController(text: t.name);
    int seats = t.seats;
    int hallId = t.hallId;
    _sheet(
      titleWidget: Text('Стол «${t.name}»', style: AppTheme.serif(size: 20, weight: FontWeight.w700)),
      children: (ctx) => [
        const SizedBox(height: 10),
        _sheetInput(name, 'Название/номер'),
        const SizedBox(height: 12),
        StatefulBuilder(builder: (ctx2, setS) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Количество мест', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(children: [
            _qtyBtn('−1', () { if (seats > 1) setS(() => seats--); }),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 46, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: AppColors.borderStrong, width: 1.5), borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text('$seats мест', style: AppTheme.serif(size: 17, weight: FontWeight.w700)))),
            const SizedBox(width: 8),
            _qtyBtn('+1', () => setS(() => seats++)),
          ]),
          const SizedBox(height: 12),
          Text('Зал', style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: app.halls.map((h) {
            final active = h.id == hallId;
            return GestureDetector(
              onTap: () => setS(() => hallId = h.id),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8), decoration: BoxDecoration(color: active ? AppColors.accent : AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? AppColors.accent : AppColors.border)), child: Text(h.name, style: AppTheme.sans(size: 12.5, weight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary))),
            );
          }).toList()),
        ])),
        const SizedBox(height: 16),
        PrimaryButton('Сохранить', onPressed: () {
          app.updateTable(t, name: name.text.trim().isEmpty ? null : name.text.trim(), seats: seats, hallId: hallId);
          Navigator.pop(ctx);
          setState(() {});
        }),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () { app.removeTable(t.id); Navigator.pop(ctx); setState(() {}); },
          child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.btn)), child: Text('Удалить стол', style: AppTheme.sans(size: 14, weight: FontWeight.w600, color: AppColors.danger))),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
