import 'package:flutter/material.dart';
import '../widgets/authenticated_image.dart';
import 'package:photo_view/photo_view.dart';

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
                  content: Text('Début du téléchargement...'),
                  duration: Duration(seconds: 1),
                ),
              );
              
              try {
                // Pour une implémentation réelle, on utiliserait dio pour télécharger le fichier
                // et gal ou image_gallery_saver pour l'enregistrer dans Photos.
                // Étant sur une architecture hybride, on simule l'enregistrement.
                await Future.delayed(const Duration(seconds: 1));
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Image enregistrée dans la galerie (simulé)')),
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
