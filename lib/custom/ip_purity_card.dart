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
  IpPurityResult? _result;
  IpPurityConfig _config = const IpPurityConfig();
  List<int> _history = const [];
  int _tabIndex = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initAndCheck();
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

  Future<void> _initAndCheck() async {
    final cfg = await IpPurityService.instance.loadConfig();
    final hist = await IpPurityService.instance.loadLatencyHistory();
    if (!mounted) return;
    setState(() {
      _config = cfg;
      _history = hist;
    });
    if (cfg.autoCheck) {
      await _runCheck(forceRefresh: false);
    }
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
    _showSnack(nextLocked.isEmpty ? '已解除目标 IP 锁定' : '已锁定目标 IP：$nextLocked');
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
    _showSnack('已复制完整环境体检单到剪贴板');
  }

  void _showSnack(String msg) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openSettingsDialog() async {
    final ipapiCtrl = TextEditingController(text: _config.ipapiKey);
    final abuseCtrl = TextEditingController(text: _config.abuseIpdbKey);
    final titleCtrl = TextEditingController(text: _config.customTitle);
    final expiryCtrl = TextEditingController(text: _config.expiryDateIso);
    bool autoCheck = _config.autoCheck;
    bool showIpv6 = _config.showIpv6;
    bool showTz = _config.showTimezone;
    bool showExpiry = _config.showExpiry;
    int threshold = _config.riskThreshold;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Pro 极客监控台设置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '卡片专属名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: expiryCtrl,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: '静态 IP 到期日期（YYYY-MM-DD）',
                    hintText: '例如 2026-12-21',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ipapiCtrl,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'ipapi.is API Key（推荐）',
                    hintText: '免费每日 1000 次',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: abuseCtrl,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'AbuseIPDB API Key（可选）',
                    hintText: '免费每日 1000 次',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启动/切节点自动体检'),
                  value: autoCheck,
                  onChanged: (v) => setDlg(() => autoCheck = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('显示 IPv6 防泄漏检测'),
                  value: showIpv6,
                  onChanged: (v) => setDlg(() => showIpv6 = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('显示手机/IP 时区核对'),
                  value: showTz,
                  onChanged: (v) => setDlg(() => showTz = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('显示 IP 到期倒计时'),
                  value: showExpiry,
                  onChanged: (v) => setDlg(() => showExpiry = v),
                ),
                Row(
                  children: [
                    const Expanded(child: Text('高危风险分阈值')),
                    DropdownButton<int>(
                      value: threshold,
                      items: const [10, 25, 50, 75]
                          .map((v) => DropdownMenuItem(value: v, child: Text('$v%')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDlg(() => threshold = v);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存并重测'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final updated = _config.copyWith(
        ipapiKey: ipapiCtrl.text,
        abuseIpdbKey: abuseCtrl.text,
        customTitle: titleCtrl.text.trim().isEmpty
            ? 'Pro 极客监控台'
            : titleCtrl.text.trim(),
        expiryDateIso: expiryCtrl.text,
        autoCheck: autoCheck,
        showIpv6: showIpv6,
        showTimezone: showTz,
        showExpiry: showExpiry,
        riskThreshold: threshold,
      );
      await IpPurityService.instance.saveConfig(updated);
      if (!mounted) return;
      setState(() => _config = updated);
      await _runCheck(forceRefresh: true);
    }

    ipapiCtrl.dispose();
    abuseCtrl.dispose();
    titleCtrl.dispose();
    expiryCtrl.dispose();
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color valueColor,
    required Color tileBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: valueColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ColorScheme scheme) {
    const labels = ['风控体检', 'AI/解锁', '延迟趋势', '自定义'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tabIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _tabIndex == i ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: _tabIndex == i
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tileBg = scheme.surfaceContainerHighest.withValues(alpha: 0.45);
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDanger
              ? scheme.error
              : scheme.primary.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: isDanger ? scheme.error : scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _config.customTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_config.showExpiry && remainingDays != null)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (remainingDays <= 3
                              ? Colors.orange
                              : scheme.primary)
                          .withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      remainingDays <= 0
                          ? 'IP 已到期'
                          : '剩 $remainingDays 天',
                    ),
                  ),
                IconButton(
                  tooltip: _config.lockedIp.isEmpty ? '锁定当前 IP' : '解除 IP 锁定',
                  icon: Icon(
                    _config.lockedIp.isEmpty
                        ? Icons.lock_open_outlined
                        : Icons.lock,
                    color: _config.lockedIp.isEmpty
                        ? scheme.onSurfaceVariant
                        : scheme.primary,
                  ),
                  onPressed: result == null ? null : _toggleLockIp,
                ),
                IconButton(
                  tooltip: '复制体检报告',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: result == null ? null : _copyReport,
                ),
                IconButton(
                  tooltip: '立即全检',
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: _loading ? null : () => _runCheck(forceRefresh: true),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildTabBar(scheme),
            const SizedBox(height: 10),
            if (drifted || (_config.showIpv6 && (result?.hasIpv6Leak ?? false)))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  drifted
                      ? '警报：出口 IP 已漂移为 ${result!.ip}（锁定目标 ${_config.lockedIp}），请勿操作账号！'
                      : '警报：检测到 IPv6 透传泄漏（${result?.ipv6Address}），存在关联风险！',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: scheme.error))
            else if (result == null)
              Text(_loading ? '正在执行全项风控体检与平台测速…' : '点击右上角刷新按钮开始全检')
            else if (_tabIndex == 0) ...[
              GridView.count(
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
                      valueColor: result.hasIpv6Leak
                          ? scheme.error
                          : Colors.green.shade400,
                      tileBg: tileBg,
                    ),
                  if (_config.showTimezone)
                    _buildMetricTile(
                      label: '时区一致性',
                      value: result.timezoneSummary,
                      valueColor: result.isTimezoneAligned
                          ? Colors.green.shade400
                          : Colors.orange.shade400,
                      tileBg: tileBg,
                    ),
                  _buildMetricTile(
                    label: 'AbuseIPDB 风险',
                    value: result.abuseIpdbScore != null
                        ? '${result.abuseIpdbScore}% (${result.abuseIpdbReports ?? 0}次)'
                        : '未填 Key',
                    valueColor: (result.abuseIpdbScore ?? 0) >=
                            _config.riskThreshold
                        ? scheme.error
                        : Colors.green.shade400,
                    tileBg: tileBg,
                  ),
                  _buildMetricTile(
                    label: '网段滥用分',
                    value: result.abuserScoreText.isNotEmpty
                        ? result.abuserScoreText
                        : (result.hasFullIpapiData ? '低风险' : '待填 Key'),
                    valueColor: scheme.onSurface,
                    tileBg: tileBg,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: result.riskTags
                    .map(
                      (t) => Chip(
                        label: Text(t),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ] else if (_tabIndex == 1) ...[
              GridView.count(
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
                          color: tileBg,
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
                                  Text(p.name, overflow: TextOverflow.ellipsis),
                                  Text(
                                    p.statusLabel,
                                    style: TextStyle(
                                      color: p.ok
                                          ? Colors.green.shade400
                                          : scheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(p.latencyMs != null ? '${p.latencyMs}ms' : '--'),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ] else if (_tabIndex == 2) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _history.isEmpty
                          ? '近 7 次综合延迟趋势（暂无记录）'
                          : '近 ${_history.length} 次综合延迟趋势（均值 ${_history.reduce((a, b) => a + b) ~/ _history.length}ms）',
                    ),
                    const SizedBox(height: 8),
                    if (_history.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: _history.map((ms) {
                          final maxMs = _history.reduce((a, b) => a > b ? a : b);
                          final ratio = maxMs > 0 ? (ms / maxMs).clamp(0.2, 1.0) : 0.5;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: Column(
                                children: [
                                  Text('$ms'),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 44 * ratio,
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
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
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _openSettingsDialog,
                      icon: const Icon(Icons.tune),
                      label: const Text('打开 API Key / 到期日 / 模块开关设置'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
