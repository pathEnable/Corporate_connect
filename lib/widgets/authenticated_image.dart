import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/api_config.dart';

/// Un widget réutilisable pour afficher des images depuis une URL sécurisée (nécessite le token JWT).
/// Il utilise le token mis en cache dans AuthService pour plus de performances, 
/// ou le récupère de manière asynchrone si le cache est vide.
class AuthenticatedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final Widget Function(BuildContext, String)? placeholder;
  final Color? color;
  final Widget Function(BuildContext, ImageProvider<Object>)? imageBuilder;

  const AuthenticatedNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
    this.placeholder,
    this.color,
    this.imageBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // Si le token est en cache, on l'utilise directement de façon synchrone
    if (AuthService.cachedToken != null) {
      return _buildImage(AuthService.cachedToken!);
    }

    // Sinon, on le récupère (sécurité/fallback)
    return FutureBuilder<String?>(
      future: AuthService().getToken(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _buildImage(snapshot.data!);
      },
    );
  }

  Widget _buildImage(String token) {
    // Si l'URL est externe (ex: Cloudinary), on n'envoie PAS le header JWT
    final bool isInternal = ApiConfig.isInternalUrl(imageUrl);
    
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      color: color,
      imageBuilder: imageBuilder,
      httpHeaders: isInternal ? {'Authorization': 'Bearer $token'} : null,
      errorWidget: errorWidget ?? (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
      placeholder: placeholder,
    );
  }
}

/// Un ImageProvider sécurisé, utile pour BoxDecoration.image (BoxDecoration) ou CircleAvatar(backgroundImage).
/// Attention : Ce provider ne peut utiliser que le token en cache (synchrone).
/// Assurez-vous que l'AuthService est initialisé avant utilisation.
class AuthenticatedImageProvider extends CachedNetworkImageProvider {
  AuthenticatedImageProvider(super.url) : super(
    headers: ApiConfig.isInternalUrl(url) 
      ? {'Authorization': 'Bearer ${AuthService.cachedToken ?? ''}'}
      : null,
  );
}
