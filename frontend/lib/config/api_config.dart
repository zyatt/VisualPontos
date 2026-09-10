import 'package:flutter_dotenv/flutter_dotenv.dart';

/// URL base da API PHP, lida do arquivo `.env` (chave `API_BASE_URL`).
///
/// Assim dá pra trocar entre produção e ambiente local (Laragon) só
/// editando o `.env`, sem precisar mexer em código nem recompilar
/// lógica de serviço.
///
/// Exemplo de valores no `.env`:
///   API_BASE_URL=https://visualpremium.com.br/api
///   API_BASE_URL=http://localhost/backend-php/api
class ApiConfig {
  static String get baseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception(
        'API_BASE_URL não definida no .env. '
        'Adicione, por exemplo: API_BASE_URL=https://visualpremium.com.br/api',
      );
    }
    // Remove a barra final, se houver, para evitar "//" nas requisições.
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}