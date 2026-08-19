import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool mandatory;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.mandatory,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json, String currentVersion) {
    return UpdateInfo(
      currentVersion: currentVersion,
      latestVersion: json['latestVersion'] ?? '',
      downloadUrl: json['downloadUrl'] ?? '',
      releaseNotes: json['releaseNotes'] ?? '',
      mandatory: json['mandatory'] ?? false,
    );
  }
}

class UpdateService {
  static const String _updateCheckUrl = 'UPDATE_CHECK_URL';

  static void _log(String msg) {
    debugPrint('[UpdateService] $msg');
  }

  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      _log('Iniciando verificação de atualização...');

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      _log('Versão atual: $currentVersion');

      final apiUrl = dotenv.env[_updateCheckUrl];
      if (apiUrl == null || apiUrl.isEmpty) {
        _log('ERRO: UPDATE_CHECK_URL não definida no .env');
        return null;
      }
      _log('URL de verificação: $apiUrl');

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      _log('Status HTTP: ${response.statusCode}');

      if (response.statusCode != 200) {
        _log('ERRO: Status não-200 recebido');
        return null;
      }

      final data = json.decode(response.body);
      Map<String, dynamic> updateData;

      if (data.containsKey('tag_name')) {
        _log('Formato detectado: GitHub Releases API');
        final latestVersion =
            (data['tag_name'] as String).replaceFirst(RegExp(r'^v'), '');

        final assets = data['assets'] as List?;
        if (assets == null || assets.isEmpty) {
          _log('ERRO: Nenhum asset encontrado no release');
          return null;
        }

        final wantedExtension = Platform.isAndroid ? '.apk' : '.exe';

        final asset = assets.firstWhere(
          (a) => (a['name'] as String).toLowerCase().endsWith(wantedExtension),
          orElse: () => null,
        );

        if (asset == null) {
          _log('ERRO: Nenhum arquivo $wantedExtension encontrado nos assets');
          return null;
        }

        updateData = {
          'latestVersion': latestVersion,
          'downloadUrl': asset['browser_download_url'],
          'releaseNotes': data['body'] ?? '',
          'mandatory': false,
        };
      } else if (data.containsKey('latestVersion')) {
        _log('Formato detectado: JSON customizado');
        updateData = data;
      } else {
        _log('ERRO: Formato desconhecido. Chaves: ${data.keys.toList()}');
        return null;
      }

      final latestVersion = updateData['latestVersion'] as String;

      if (_shouldUpdate(currentVersion, latestVersion)) {
        _log('Atualização necessária: $currentVersion → $latestVersion');
        return UpdateInfo.fromJson(updateData, currentVersion);
      } else {
        _log('App já na versão mais recente ($currentVersion)');
        return null;
      }
    } catch (e, stack) {
      _log('EXCEÇÃO em checkForUpdates: $e');
      _log('Stack: $stack');
      return null;
    }
  }

  static bool _shouldUpdate(String current, String latest) {
    try {
      final c = current.split('.').map(int.parse).toList();
      final l = latest.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final cv = i < c.length ? c[i] : 0;
        final lv = i < l.length ? l[i] : 0;
        if (lv > cv) return true;
        if (lv < cv) return false;
      }
    } catch (e) {
      _log('ERRO ao comparar versões: $e');
    }
    return false;
  }

  static Future<String?> downloadAndInstallUpdate(
    String downloadUrl,
    Function(double) onProgress,
  ) async {
    if (Platform.isAndroid) {
      return _downloadAndInstallAndroid(downloadUrl, onProgress);
    }
    return _downloadAndInstallWindows(downloadUrl, onProgress);
  }

  /// Baixa o arquivo remoto para [destPath], reportando progresso via
  /// [onProgress]. Retorna uma mensagem de erro em caso de falha, ou
  /// null se o download foi concluído com sucesso.
  static Future<String?> _downloadFile(
    String downloadUrl,
    String destPath,
    Function(double) onProgress,
  ) async {
    final request = http.Request('GET', Uri.parse(downloadUrl));
    final streamedResponse = await request.send();

    if (streamedResponse.statusCode != 200) {
      return 'Servidor retornou status ${streamedResponse.statusCode} ao baixar o instalador.';
    }

    final totalBytes = streamedResponse.contentLength ?? 0;
    int downloadedBytes = 0;
    final List<int> bytes = [];

    await for (final chunk in streamedResponse.stream) {
      bytes.addAll(chunk);
      downloadedBytes += chunk.length;
      if (totalBytes > 0) {
        onProgress(downloadedBytes / totalBytes);
      }
    }

    if (downloadedBytes == 0) {
      return 'Download falhou: nenhum byte recebido.';
    }

    final file = File(destPath);
    await file.writeAsBytes(bytes, flush: true);
    onProgress(1.0);

    final fileSize = await file.length();
    if (fileSize == 0) {
      return 'Arquivo gravado está vazio (0 bytes). Verifique a URL de download.';
    }

    if (!await file.exists()) {
      return 'Arquivo não encontrado após gravação:\n$destPath';
    }

    return null;
  }

  static Future<String?> _downloadAndInstallWindows(
    String downloadUrl,
    Function(double) onProgress,
  ) async {
    try {
      _log('Iniciando download (Windows): $downloadUrl');

      final tempDir = await getTemporaryDirectory();
      final installerPath = '${tempDir.path}\\VisualPremiumSetup.exe';

      final erroDownload = await _downloadFile(downloadUrl, installerPath, onProgress);
      if (erroDownload != null) return erroDownload;

      await Future.delayed(const Duration(milliseconds: 800));

      final process = await Process.start(
        installerPath,
        ['/SILENT', '/CLOSEAPPLICATIONS', '/RESTARTAPPLICATIONS'],
        mode: ProcessStartMode.detached,
      );
      _log('Processo iniciado. PID: ${process.pid}');

      await Future.delayed(const Duration(milliseconds: 500));
      exit(0);
    } catch (e, stack) {
      _log('EXCEÇÃO em _downloadAndInstallWindows: $e');
      _log('Stack: $stack');
      return 'Erro inesperado:\n$e';
    }
  }

  static Future<String?> _downloadAndInstallAndroid(
    String downloadUrl,
    Function(double) onProgress,
  ) async {
    try {
      _log('Iniciando download (Android): $downloadUrl');

      // Usa o diretório de documentos do app (acessível sem permissões
      // especiais de armazenamento) para salvar o .apk antes de instalar.
      final dir = await getApplicationDocumentsDirectory();
      final apkPath = '${dir.path}/VisualPremiumUpdate.apk';

      // Remove uma cópia anterior, se existir, para evitar instalar um
      // arquivo desatualizado caso o download atual falhe no meio.
      final existente = File(apkPath);
      if (await existente.exists()) {
        await existente.delete();
      }

      final erroDownload = await _downloadFile(downloadUrl, apkPath, onProgress);
      if (erroDownload != null) return erroDownload;

      _log('Download concluído, abrindo instalador do sistema...');

      final result = await OpenFilex.open(apkPath);

      _log('OpenFilex resultado: ${result.type} - ${result.message}');

      if (result.type != ResultType.done) {
        // done = o Android abriu a tela de instalação com sucesso.
        // Qualquer outro resultado indica falha (ex: permissão
        // "instalar apps desconhecidos" não concedida).
        return 'Não foi possível abrir o instalador:\n${result.message}\n\n'
            'Verifique se a permissão "Instalar apps desconhecidos" está '
            'habilitada para este app nas configurações do Android.';
      }

      // A instalação prossegue na tela nativa do Android; o app continua
      // rodando em segundo plano até o usuário confirmar a instalação.
      return null;
    } catch (e, stack) {
      _log('EXCEÇÃO em _downloadAndInstallAndroid: $e');
      _log('Stack: $stack');
      return 'Erro inesperado:\n$e';
    }
  }
}