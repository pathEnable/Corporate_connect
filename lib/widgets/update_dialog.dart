import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final String apkUrl;
  final String versionName;

  const UpdateDialog({
    super.key,
    required this.apkUrl,
    required this.versionName,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double _progress = 0;
  String _status = "Une nouvelle version est disponible.";
  bool _isDownloading = false;

  void _startDownload() {
    setState(() {
      _isDownloading = true;
      _status = "Téléchargement en cours...";
    });

    UpdateService().startUpdate(widget.apkUrl).listen(
      (OtaEvent event) {
        setState(() {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              _progress = double.tryParse(event.value ?? "0") ?? 0;
              break;
            case OtaStatus.INSTALLING:
              _status = "Préparation de l'installation...";
              _progress = 100;
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              _status = "Mise à jour déjà en cours.";
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              _status = "Permission refusée.";
              _isDownloading = false;
              break;
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.INTERNAL_ERROR:
              _status = "Erreur lors du téléchargement.";
              _isDownloading = false;
              break;
            default:
              break;
          }
        });
      },
      onError: (e) {
        setState(() {
          _status = "Erreur: $e";
          _isDownloading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Empêche le retour arrière
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Mise à jour obligatoire"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.system_update_alt, size: 60, color: Colors.blueAccent),
            const SizedBox(height: 20),
            Text(
              "La version ${widget.versionName} est disponible. Cette mise à jour est nécessaire pour continuer à utiliser l'application.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _progress / 100,
                backgroundColor: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text("${_progress.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 8),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _status.contains("Erreur") ? Colors.red : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isDownloading)
            ElevatedButton(
              onPressed: _startDownload,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Mettre à jour maintenant"),
            ),
        ],
      ),
    );
  }
}
