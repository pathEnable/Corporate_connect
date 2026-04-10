import 'package:flutter/material.dart';
import '../widgets/authenticated_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

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
              try {
                final hasAccess = await Gal.hasAccess();
                if (!hasAccess) {
                  await Gal.requestAccess();
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Téléchargement en cours...'), duration: Duration(seconds: 1)),
                  );
                }

                final tempDir = await getTemporaryDirectory();
                final path = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
                
                await Dio().download(imageUrl, path);
                await Gal.putImage(path);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Image enregistrée dans la galerie !')),
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
