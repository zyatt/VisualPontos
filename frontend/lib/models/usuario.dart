class Usuario {
  final int id;
  final String nome;
  final String usuario;
  final String role;

  Usuario({
    required this.id,
    required this.nome,
    required this.usuario,
    required this.role,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      usuario: json['usuario'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'usuario': usuario,
        'role': role,
      };

  Usuario copyWith({String? nome, String? usuario, String? role}) {
    return Usuario(
      id: id,
      nome: nome ?? this.nome,
      usuario: usuario ?? this.usuario,
      role: role ?? this.role,
    );
  }
}