import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_icons.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../app/widgets/app_screen_background.dart';
import '../../../../app/widgets/app_surface.dart';
import '../../data/devices_service.dart';

class ActiveDevicesScreen extends StatefulWidget {
  const ActiveDevicesScreen({super.key});

  @override
  State<ActiveDevicesScreen> createState() => _ActiveDevicesScreenState();
}

class _ActiveDevicesScreenState extends State<ActiveDevicesScreen> {
  final DevicesService _devicesService = DevicesService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _devices = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await _devicesService.listDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить устройства';
        _loading = false;
      });
    }
  }

  Future<void> _revoke(int deviceId) async {
    await _devicesService.revokeDevice(deviceId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppScreenBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
                child: Row(
                  children: [
                    AppIconButtonSurface(
                      icon: AppIcons.back,
                      tooltip: 'Назад',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Активные устройства',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    if (_devices.isEmpty) {
      return const Center(
        child: Text(
          'Устройств пока нет',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final device = _devices[index];
        final id = int.tryParse(device['id'].toString());
        final platform = (device['platform'] ?? 'unknown').toString();
        final name = (device['device_name'] ?? 'Устройство').toString();
        final active = device['is_active'] == true;
        return AppSurface(
          radius: AppRadius.xl,
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          borderColor: active ? AppColors.strokeSoft : AppColors.error.withValues(alpha: 0.25),
          child: Row(
            children: [
              Icon(
                platform == 'ios' ? Icons.phone_iphone : Icons.android_rounded,
                color: active ? AppColors.accentBright : AppColors.textMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      active ? 'Активно · $platform' : 'Отключено · $platform',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (id != null && active)
                TextButton(
                  onPressed: () => _revoke(id),
                  child: const Text('Отключить'),
                ),
            ],
          ),
        );
      },
    );
  }
}
