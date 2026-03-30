import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../data/services/profile_service.dart';
import '../../../../core/network/api_client.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isUploading = false;
  String? _error;

  Map<String, dynamic>? _me;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final me = await _profileService.getMe();

      if (!mounted) return;

      setState(() {
        _me = me;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      String message = 'Не удалось загрузить профиль';

      if (e is DioException) {
        final data = e.response?.data;

        if (data is Map<String, dynamic>) {
          message =
              data['detail']?.toString() ?? data['message']?.toString() ?? message;
        } else if (data is String && data.isNotEmpty) {
          message = data;
        } else if (e.message != null && e.message!.isNotEmpty) {
          message = e.message!;
        }
      }

      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  String _username() {
    return (_me?['username'] ?? 'Пользователь').toString();
  }

  String _email() {
    return (_me?['email'] ?? '').toString();
  }

  String? _avatarUrl() {
    final raw = (_me?['avatar_url'] ?? '').toString().trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final base = _dioBaseForImages();
    return '$base$raw';
  }

  String _dioBaseForImages() {
   
      return ApiClient.baseUrl;
  }

  String _initials(String value) {
    final parts =
        value.split(' ').where((e) => e.trim().isNotEmpty).take(2).toList();

    if (parts.isEmpty) return 'Ч';

    if (parts.length == 1) {
      final word = parts.first.trim();
      return word.isNotEmpty ? word[0].toUpperCase() : 'Ч';
    }

    final first = parts[0].trim();
    final second = parts[1].trim();

    final firstChar = first.isNotEmpty ? first[0].toUpperCase() : '';
    final secondChar = second.isNotEmpty ? second[0].toUpperCase() : '';

    final result = '$firstChar$secondChar'.trim();
    return result.isEmpty ? 'Ч' : result;
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploading) return;

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (picked == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final updated = await _profileService.uploadMyAvatar(File(picked.path));

      if (!mounted) return;

      setState(() {
        _me = updated;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Аватар обновлен'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String message = 'Не удалось загрузить аватар';

      if (e is DioException) {
        final data = e.response?.data;

        if (data is Map<String, dynamic>) {
          message =
              data['detail']?.toString() ?? data['message']?.toString() ?? message;
        } else if (data is String && data.isNotEmpty) {
          message = data;
        } else if (e.message != null && e.message!.isNotEmpty) {
          message = e.message!;
        }
      }

      setState(() {
        _isUploading = false;
        _error = message;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    }
  }

  Widget _buildAvatar() {
    final avatarUrl = _avatarUrl();
    final initials = _initials(_username());

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Image.network(
          avatarUrl,
          width: 112,
          height: 112,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _buildAvatarFallback(initials);
          },
        ),
      );
    }

    return _buildAvatarFallback(initials);
  }

  Widget _buildAvatarFallback(String initials) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(32),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 32,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.accentBorder.withAlpha(110),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: Colors.black,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
        ),
      );
    }

    if (_error != null && _me == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Stack(
            children: [
              _buildAvatar(),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _isUploading ? null : _pickAndUploadAvatar,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: _isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(
                            Icons.edit,
                            color: Colors.black,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _username(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _email(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoCard(
            label: 'Username',
            value: _username(),
            icon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            label: 'Email',
            value: _email(),
            icon: Icons.mail_outline_rounded,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Профиль',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B0B0D),
              Color(0xFF09090B),
              Color(0xFF140A02),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: _buildBody(),
        ),
      ),
    );
  }
}