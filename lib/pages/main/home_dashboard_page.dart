import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/base_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../providers/statistics_providers.dart';
import '../../widgets/biz/ledger_picker_sheet.dart';
import '../../widgets/biz/bee_icon.dart';
import '../account/accounts_page.dart';
import '../calendar/calendar_page.dart';
import '../tag/tag_manage_page.dart';
import '../transaction/transaction_editor_page.dart';
import 'ledgers_page_new.dart';

/// 新版首页仪表盘：
/// - 顶部本月概览（小眼睛 + 切换账本 + 黄色记一笔）
/// - 常用功能四模块：账本管理 / 资产 / 标签管理 / 收支日历
class HomeDashboardPage extends ConsumerStatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  ConsumerState<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends ConsumerState<HomeDashboardPage> {
  bool _hideAmount = false;
  String _period = 'month'; // week | month | year
  Future<(double income, double expense)>? _summaryFuture;
  int? _summaryLedgerId;
  String? _summaryPeriod;
  int? _summaryTick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ledgersAsync = ref.watch(localLedgersProvider);
    final currentLedgerId = ref.watch(currentLedgerIdProvider);
    final repo = ref.watch(repositoryProvider);
    final tick = ref.watch(statsRefreshProvider);

    var ledgerName = '主账本';
    final ledgers = ledgersAsync.value;
    if (ledgers != null) {
      for (final ledger in ledgers) {
        if (ledger.id == currentLedgerId) {
          ledgerName = ledger.name;
          break;
        }
      }
    }
    if (_summaryFuture == null ||
        _summaryLedgerId != currentLedgerId ||
        _summaryPeriod != _period ||
        _summaryTick != tick) {
      _summaryLedgerId = currentLedgerId;
      _summaryPeriod = _period;
      _summaryTick = tick;
      _summaryFuture = _loadSummary(repo, currentLedgerId);
    }

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
          children: [
            _buildPageHeader(ledgerName),
            const SizedBox(height: 12),
            FutureBuilder<(double income, double expense)>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                final totals = snapshot.data;
                final income = totals?.$1 ?? 0.0;
                final expense = totals?.$2 ?? 0.0;
                final balance = income - expense;
                return _buildTopSummaryCard(
                  ledgerName: ledgerName,
                  balanceText: _hideAmount ? '****' : '¥${balance.toStringAsFixed(2)}',
                  incomeText: _hideAmount ? '****' : '¥${income.toStringAsFixed(2)}',
                  expenseText: _hideAmount ? '****' : '¥${expense.toStringAsFixed(2)}',
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              '常用功能',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2329),
              ),
            ),
            const SizedBox(height: 12),
            _buildModuleGrid(),
            const SizedBox(height: 18),
            _ReservedModule(),
          ],
        ),
      ),
    );
  }

  Future<(double income, double expense)> _loadSummary(
    BaseRepository repo,
    int ledgerId,
  ) async {
    final now = DateTime.now();
    switch (_period) {
      case 'week':
        final today = DateTime(now.year, now.month, now.day);
        final start = today.subtract(Duration(days: now.weekday - 1));
        return repo.totalsInRange(
          ledgerId: ledgerId,
          start: start,
          end: start.add(const Duration(days: 7)),
        );
      case 'year':
        return repo.yearlyTotals(ledgerId: ledgerId, year: now.year);
      case 'month':
      default:
        return repo.monthlyTotals(
          ledgerId: ledgerId,
          month: DateTime(now.year, now.month, 1),
        );
    }
  }

  String _periodLabel() {
    switch (_period) {
      case 'week':
        return '本周账单';
      case 'year':
        return '本年账单';
      case 'month':
      default:
        return '本月账单';
    }
  }

  Future<void> _showPeriodPicker() async {
    final options = <(String, String)>[
      ('week', '本周'),
      ('month', '本月'),
      ('year', '本年'),
    ];
    var index = options.indexWhere((e) => e.$1 == _period);
    if (index < 0) index = 1;
    var temp = options[index].$1;
    var confirmed = false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SizedBox(
        height: 250,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E3E7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 44,
                scrollController: FixedExtentScrollController(initialItem: index),
                onSelectedItemChanged: (i) => temp = options[i].$1,
                children: [
                  for (final option in options)
                    Center(
                      child: Text(
                        option.$2,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          confirmed = true;
                          Navigator.pop(ctx);
                        },
                        child: const Text('确定'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed && temp != _period) {
      setState(() => _period = temp);
    }
  }

  Widget _buildTopSummaryCard({
    required String ledgerName,
    required String balanceText,
    required String incomeText,
    required String expenseText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEF0F3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PopupMenuButton<String>(
                  initialValue: _period,
                  onSelected: (value) => setState(() => _period = value),
                  offset: const Offset(0, 28),
                  padding: EdgeInsets.zero,
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  itemBuilder: (context) => [
                    for (final option in const [
                      ('week', '本周'),
                      ('month', '本月'),
                      ('year', '本年'),
                    ])
                      PopupMenuItem<String>(
                        value: option.$1,
                        height: 36,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              child: _period == option.$1
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: Color(0xFFF5B301),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              option.$2,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_periodLabel()} · $ledgerName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5B6169),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Color(0xFF9AA0A8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _hideAmount = !_hideAmount),
                child: Icon(
                  _hideAmount ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: const Color(0xFF9AA0A8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  balanceText,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2329),
                  ),
                ),
              ),
              _YellowRecordButton(),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniAmount(label: '收入', text: incomeText),
              const SizedBox(width: 12),
              _MiniAmount(label: '支出', text: expenseText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader(String ledgerName) {
    return Row(
      children: [
        const BeeIcon(color: Color(0xFFF5B301), size: 28),
        const SizedBox(width: 8),
        const Text(
          '蜜蜂记账',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2329),
          ),
        ),
        const SizedBox(width: 12),
        _SwitchLedgerChip(label: ledgerName),
      ],
    );
  }

  Widget _buildModuleGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _ModuleCard(
          title: '账本管理',
          subtitle: '创建 / 编辑账本',
          icon: Icons.menu_book_rounded,
          color: const Color(0xFF4C7DF0),
          onTap: () => _push(context, const LedgersPageNew()),
        ),
        _ModuleCard(
          title: '资产',
          subtitle: '账户与资产概况',
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFF12B886),
          onTap: () => _push(context, const AccountsPage()),
        ),
        _ModuleCard(
          title: '标签管理',
          subtitle: '整理交易标签',
          icon: Icons.sell_rounded,
          color: const Color(0xFFF05A76),
          onTap: () => _push(context, const TagManagePage()),
        ),
        _ModuleCard(
          title: '收支日历',
          subtitle: '按日期回看收支',
          icon: Icons.calendar_month_rounded,
          color: const Color(0xFFF5A623),
          onTap: () => _push(context, const CalendarPage()),
        ),
      ],
    );
  }
}

class _SwitchLedgerChip extends ConsumerWidget {
  final String label;

  const _SwitchLedgerChip({required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => showLedgerPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3A3F45),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Color(0xFF3A3F45),
            ),
          ],
        ),
      ),
    );
  }
}

class _YellowRecordButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TransactionEditorPage(
              initialKind: 'expense',
              quickAdd: true,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5B301),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF5B301).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 18, color: Colors.black87),
            SizedBox(width: 2),
            Text(
              '记一笔',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAmount extends StatelessWidget {
  final String label;
  final String text;

  const _MiniAmount({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9A8A4F)),
            ),
            const SizedBox(height: 2),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2329),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEF0F3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2329),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9AA0A8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservedModule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE9ECEF),
          style: BorderStyle.solid,
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_rounded, size: 16, color: Color(0xFFB8BFC7)),
          SizedBox(width: 6),
          Text(
            '更多功能 · 预留位',
            style: TextStyle(fontSize: 12, color: Color(0xFFB8BFC7)),
          ),
        ],
      ),
    );
  }
}

void _push(BuildContext context, Widget page) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}
