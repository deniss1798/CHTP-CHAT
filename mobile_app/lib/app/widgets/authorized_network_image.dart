import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../core/network/url_helper.dart';
import '../../core/storage/secure_storage_service.dart';

const _kAvatarFetchHeaders = <String, String>{
  'User-Agent': 'CHTP-Chat/1.0 (Flutter; avatar)',
  'Accept': 'image/*,*/*;q=0.8',
};

/// [Image.network] for API-backed media: Bearer только если URL с того же хоста, что [ApiClient].
/// Публичные S3/MinIO (другой домен) — без Authorization, иначе часто 403 и падает в [errorBuilder].
class AuthorizedNetworkImage extends StatefulWidget {
  const AuthorizedNetworkImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<AuthorizedNetworkImage> createState() => _AuthorizedNetworkImageState();
}

class _AuthorizedNetworkImageState extends State<AuthorizedNetworkImage> {
  late final Future<String?> _tokenFuture = SecureStorageService.getAccessToken();

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (widget.width * dpr).round();
    final cacheH = (widget.height * dpr).round();

    if (!UrlHelper.isSameServerAsApi(widget.url)) {
      return Image.network(
        widget.url,
        key: ValueKey<String>(widget.url),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        headers: _kAvatarFetchHeaders,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        errorBuilder: widget.errorBuilder,
      );
    }

    return FutureBuilder<String?>(
      future: _tokenFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ColoredBox(
            color: AppColors.chatListCard,
            child: SizedBox(width: widget.width, height: widget.height),
          );
        }
        final token = snapshot.data;
        final h = Map<String, String>.from(_kAvatarFetchHeaders);
        if (token != null && token.isNotEmpty) {
          h['Authorization'] = 'Bearer $token';
        }

        return Image.network(
          widget.url,
          key: ValueKey<String>(widget.url),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          headers: h,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          cacheWidth: cacheW,
          cacheHeight: cacheH,
          errorBuilder: widget.errorBuilder,
        );
      },
    );
  }
}
