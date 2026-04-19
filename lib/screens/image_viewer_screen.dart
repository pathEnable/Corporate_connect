import 'package:flutter/material.dart';
import '../widgets/authenticated_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../services/media_service.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withAlpha(150),
        elevation: 0,
        title: Text(title ?? 'Aperçu', style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Téléchargement en cours...'),
                  duration: Duration(seconds: 1),
                ),
              );
              
              try {
                final absoluteUrl = await MediaService().getDownloadUrl(imageUrl);
                if (kIsWeb) {
                  final uri = Uri.parse(absoluteUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  return;
                }

                // Check permissions
                if (!await Gal.hasAccess(toAlbum: true)) {
                  final granted = await Gal.requestAccess(toAlbum: true);
                  if (!granted) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission refusée pour accéder à la galerie.')));
                    }
                    return;
                  }
                }

                // URL is already fetched above
                

                // Temp save
                final dir = await getTemporaryDirectory();
                final ext = imageUrl.split('.').last.split('?').first;
                final validExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext.toLowerCase()) ? ext : 'jpg';
                final savePath = '${dir.path}/image_${DateTime.now().millisecondsSinceEpoch}.$validExt';
                
                await Dio().download(absoluteUrl, savePath);
                
                // Save to gallery
                await Gal.putImage(savePath, album: 'CorporateConnect');
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Image enregistrée dans la galerie avec succès !')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: PhotoView(
        imageProvider: AuthenticatedImageProvider(imageUrl),
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
        heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
