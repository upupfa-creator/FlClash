import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ip_purity_service.dart';

class IpPurityCard extends StatefulWidget {
  const IpPurityCard({
    super.key,
    this.currentIp,
    this.localProxyPort,
  });

  final String? currentIp;
  final int? localProxyPort;

  @override
  State<IpPurityCard> createState() => _IpPurityCardState();
}

class _IpPurityCardState extends State<IpPurityCard> {
  static const _cardBg = Color(0xFF161821);
  static const _tileBg = Color(0xFF1F2330);
  static const _trackBg = Color(0xFF0E1017);
  static const _accentBlue = Color(0xFF3B82F6);
  static const _okGreen = Color(0xFF34D399);
  static const _warnAmber = Color(0xFFFBBF24);
  static const _dangerRed = Color(0xFFF87171);
  static const _textPrimary = Color(0xFFF1F5F9);
  static const _textMuted = Color(0xFF94A3B8);

  IpPurityResult? _result;
  IpPurityConfig _config = const IpPurityConfig();
  List<int> _history = const [];
  int _tabIndex = 0;
  bool _loading = false;
  String? _error;
  String? _notice;

  final _titleCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _ipapiCtrl = TextEditingController();
  final _abuseCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAndCheck();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _expiryCtrl.dispose();
    _ipapiCtrl.dispose();
    _abuseCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant IpPurityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIp != null &&
        widget.currentIp != oldWidget.currentIp &&
        _config.autoCheck) {
      _runCheck(forceRefresh: false);
    }
  }

  void _syncControllers(IpPurityConfig cfg) {
    _titleCtrl.text = cfg.customTitle;
    _expiryCtrl.text = cfg.expiryDateIso;
    _ipapiCtrl.text = cfg.ipapiKey;
    _abuseCtrl.text = cfg.abuseIpdbKey;
  }

  Future<void> _initAndCheck() async {
    final cfg = await IpPurityService.instance.loadConfig();
    final hist = await IpPurityService.instance.loadLatencyHistory();
    if (!mounted) return;
    _syncControllers(cfg);
    setState(() {
      _config = cfg;
      _history = hist;
    });
    if (cfg.autoCheck) {
      await _runCheck(forceRefresh: false);
    }
  }

  void _showNotice(String msg) {
    setState(() => _notice = msg);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _notice == msg) {
        setState(() => _notice = null);
      }
    });
  }

  Future<void> _runCheck({required bool forceRefresh}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await IpPurityService.instance.checkAll(
        knownIp: widget.currentIp,
        localProxyPort: widget.localProxyPort,
        forceRefresh: forceRefresh,
      );
      final hist = await IpPurityService.instance.loadLatencyHistory();
      if (!mounted) return;
      setState(() {
        _result = res;
        _history = hist;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '检测失败：$e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleLockIp() async {
    final currentIp = _result?.ip ?? '';
    final nextLocked = _config.lockedIp.isNotEmpty ? '' : currentIp;
    final nextCfg = _config.copyWith(lockedIp: nextLocked);
    await IpPurityService.instance.saveConfig(nextCfg);
    if (!mounted) return;
    setState(() => _config = nextCfg);
    _showNotice(nextLocked.isEmpty ? '已解除目标 IP 锁定' : '已锁定目标 IP：$nextLocked');
  }

  Future<void> _copyReport() async {
    final res = _result;
    if (res == null) return;
    await Clipboard.setData(
      ClipboardData(
        text: res.buildCopyableReport(appTitle: _config.customTitle),
      ),
    );
    if (!mounted) return;
    _showNotice('已复制完整环境体检单到剪贴板');
  }

  Future<void> _saveInlineConfig() async {
    final updated = _config.copyWith(
      customTitle: _titleCtrl.text.trim().isEmpty
          ? 'Pro 极客监控台'
          : _titleCtrl.text.trim(),
      expiryDateIso: _expiryCtrl.text.trim(),
      ipapiKey: _ipapiCtrl.text.trim(),
      abuseIpdbKey: _abuseCtrl.text.trim(),
    );
    await IpPurityService.instance.saveConfig(updated);
    if (!mounted) return;
    setState(() {
      _config = updated;
      _tabIndex = 0;
    });
    _showNotice('设置已保存，正在重测...');
    await _runCheck(forceRefresh: true);
  }

  Widget _buildPillAction({
    required String label,
    required VoidCallback? onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _accentBlue.withValues(alpha: 0.22) : _tileBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF93C5FD) : _textPrimary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _tileBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _textMuted, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: valueColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    const labels = ['风控体检', 'AI/解锁', '延迟趋势', '自定义'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _trackBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tabIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: _tabIndex == i ? _accentBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: _tabIndex == i ? Colors.white : _textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _trackBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2B3040)),
          ),
          child: TextField(
            controller: controller,
            autocorrect: false,
            style: const TextStyle(color: _textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: _textPrimary, fontSize: 12)),
            Container(
              width: 38,
              height: 22,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? _accentBlue : const Color(0xFF334155),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineSettings() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _tileBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputField(
              controller: _titleCtrl,
              label: '卡片专属名称',
              hint: '例如 Pro 极客监控台',
            ),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _expiryCtrl,
              label: '静态 IP 到期日期（YYYY-MM-DD）',
              hint: '例如 2026-12-21',
            ),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _ipapiCtrl,
              label: 'ipapi.is API Key（推荐，每日 1000 次免费）',
              hint: '粘贴你的 ipapi.is Key',
            ),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _abuseCtrl,
              label: 'AbuseIPDB API Key（可选，每日 1000 次免费）',
              hint: '粘贴你的 AbuseIPDB Key',
            ),
            const SizedBox(height: 10),
            _buildToggleRow(
              label: '启动 / 切节点自动体检',
              value: _config.autoCheck,
              onChanged: (v) =>
                  setState(() => _config = _config.copyWith(autoCheck: v)),
            ),
            _buildToggleRow(
              label: '显示 IPv6 防泄漏检测',
              value: _config.showIpv6,
              onChanged: (v) =>
                  setState(() => _config = _config.copyWith(showIpv6: v)),
            ),
            _buildToggleRow(
              label: '显示手机 / IP 时区核对',
              value: _config.showTimezone,
              onChanged: (v) =>
                  setState(() => _config = _config.copyWith(showTimezone: v)),
            ),
            _buildToggleRow(
              label: '显示 IP 到期倒计时',
              value: _config.showExpiry,
              onChanged: (v) =>
                  setState(() => _config = _config.copyWith(showExpiry: v)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  '高危阈值',
                  style: TextStyle(color: _textMuted, fontSize: 11),
                ),
                const SizedBox(width: 8),
                for (final v in const [10, 25, 50, 75])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(
                        () => _config = _config.copyWith(riskThreshold: v),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _config.riskThreshold == v
                              ? _accentBlue
                              : _trackBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$v%',
                          style: TextStyle(
                            color: _config.riskThreshold == v
                                ? Colors.white
                                : _textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _saveInlineConfig,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _accentBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '保存设置并立即重测',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final drifted = result != null &&
        _config.lockedIp.isNotEmpty &&
        result.ip != _config.lockedIp;
    final level = result?.evaluateLevel(
      riskThreshold: _config.riskThreshold,
      lockedIp: _config.lockedIp,
      checkIpv6: _config.showIpv6,
    );
    final isDanger = level == IpPurityLevel.highRisk;
    final remainingDays = _config.remainingDays;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDanger
              ? _dangerRed.withValues(alpha: 0.85)
              : _accentBlue.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isDanger ? _dangerRed : _okGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _config.customTitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              if (_config.showExpiry && remainingDays != null)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (remainingDays <= 3 ? _warnAmber : _accentBlue)
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    remainingDays <= 0 ? '已到期' : '剩$remainingDays天',
                    style: TextStyle(
                      color: remainingDays <= 3
                          ? _warnAmber
                          : const Color(0xFF93C5FD),
                      fontSize: 11,
                    ),
                  ),
                ),
              _buildPillAction(
                label: _config.lockedIp.isEmpty ? '锁IP' : '已锁',
                active: _config.lockedIp.isNotEmpty,
                onTap: result == null ? null : _toggleLockIp,
              ),
              const SizedBox(width: 6),
              _buildPillAction(
                label: '复制',
                onTap: result == null ? null : _copyReport,
              ),
              const SizedBox(width: 6),
              _buildPillAction(
                label: _loading ? '测速中' : '刷新',
                active: _loading,
                onTap: _loading ? null : () => _runCheck(forceRefresh: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTabBar(),
          const SizedBox(height: 12),
          if (_notice != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _accentBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _notice!,
                style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11),
              ),
            ),
          if (drifted || (_config.showIpv6 && (result?.hasIpv6Leak ?? false)))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _dangerRed.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _dangerRed.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                drifted
                    ? '警报：出口 IP 已漂移为 ${result!.ip}（锁定目标 ${_config.lockedIp}），请勿操作账号！'
                    : '警报：检测到 IPv6 透传泄漏（${result?.ipv6Address}），存在关联风险！',
                style: const TextStyle(color: _dangerRed, fontSize: 12),
              ),
            ),
          if (_tabIndex == 3)
            _buildInlineSettings()
          else if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: _dangerRed, fontSize: 12),
            )
          else if (result == null)
            Text(
              _loading ? '正在执行全项风控体检与平台测速…' : '点击右上角“刷新”开始全面体检',
              style: const TextStyle(color: _textMuted, fontSize: 12),
            )
          else if (_tabIndex == 0) ...[
            GridView.count(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.35,
              children: [
                if (_config.showIpv6)
                  _buildMetricTile(
                    label: 'IPv6 防泄漏',
                    value: result.hasIpv6Leak ? '检测到泄漏' : '已完全隔离',
                    valueColor: result.hasIpv6Leak ? _dangerRed : _okGreen,
                  ),
                if (_config.showTimezone)
                  _buildMetricTile(
                    label: '时区一致性',
                    value: result.timezoneSummary,
                    valueColor:
                        result.isTimezoneAligned ? _okGreen : _warnAmber,
                  ),
                _buildMetricTile(
                  label: 'AbuseIPDB 风险',
                  value: result.abuseIpdbScore != null
                      ? '${result.abuseIpdbScore}% (${result.abuseIpdbReports ?? 0}次)'
                      : '未填 Key',
                  valueColor: (result.abuseIpdbScore ?? 0) >=
                          _config.riskThreshold
                      ? _dangerRed
                      : _okGreen,
                ),
                _buildMetricTile(
                  label: '网段滥用分',
                  value: result.abuserScoreText.isNotEmpty
                      ? result.abuserScoreText
                      : (result.hasFullIpapiData ? '低风险' : '待填 Key'),
                  valueColor: _textPrimary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result.riskTags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _tileBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          color: _textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ] else if (_tabIndex == 1) ...[
            GridView.count(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.6,
              children: result.platforms
                  .map(
                    (p) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _tileBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  p.statusLabel,
                                  style: TextStyle(
                                    color: p.ok ? _okGreen : _dangerRed,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            p.latencyMs != null ? '${p.latencyMs}ms' : '--',
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _tileBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _history.isEmpty
                        ? '近 7 次综合延迟趋势（暂无记录）'
                        : '近 ${_history.length} 次综合延迟趋势（均值 ${_history.reduce((a, b) => a + b) ~/ _history.length}ms）',
                    style: const TextStyle(color: _textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  if (_history.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: _history.map((ms) {
                        final maxMs =
                            _history.reduce((a, b) => a > b ? a : b);
                        final ratio =
                            maxMs > 0 ? (ms / maxMs).clamp(0.2, 1.0) : 0.5;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              children: [
                                Text(
                                  '$ms',
                                  style: const TextStyle(
                                    color: _textPrimary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 44 * ratio,
                                  decoration: BoxDecoration(
                                    color: _accentBlue,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
