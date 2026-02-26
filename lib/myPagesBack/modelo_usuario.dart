class Usuario {
  final int id;
  final String uid;       // Nuevo: ID de Firebase/Google
  final String nombre;
  final String celular; // Usado para login manual
  final String email;   // Usado para login Google
  final String fotoUrl;
  final String rol;       // 'Admin' o 'Alumno'
  final String direccion; // Nuevo: Registro Híbrido
  final int edad;         // Nuevo: Registro Híbrido
  final String sexo;      // Nuevo: Registro Híbrido
  final String estado;    // Nuevo: Bloqueo de usuarios
  final DateTime? updatedAt; // Nuevo: Control de sincronización offline

  Usuario({
    required this.id,
    this.uid = '',        // Por defecto vacío
    required this.nombre,
    required this.celular,
    required this.email,
    required this.fotoUrl,
    required this.rol,
    this.direccion = '',
    this.edad = 0,
    this.sexo = '',
    this.estado = 'activo', // Por defecto
    this.updatedAt,
  });
  
  Usuario copyWith({
    int? id, String? uid, String? nombre, String? celular, String? email, 
    String? fotoUrl, String? rol, String? direccion, int? edad, String? sexo,
    String? estado, DateTime? updatedAt
  }) {
    return Usuario(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      nombre: nombre ?? this.nombre,
      celular: celular ?? this.celular,
      email: email ?? this.email,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      rol: rol ?? this.rol,
      direccion: direccion ?? this.direccion,
      edad: edad ?? this.edad,
      sexo: sexo ?? this.sexo,
      estado: estado ?? this.estado,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Factory para crear desde BD
  factory Usuario.desdeMapa(Map<String, dynamic> mapa) {
    return Usuario(
      id: mapa['id'] ?? 0,
      uid: mapa['uid'] ?? '',
      nombre: mapa['nombre'] ?? '',
      celular: mapa['celular'] ?? '',
      email: mapa['email'] ?? '',
      fotoUrl: mapa['foto_url'] ?? '',
      rol: mapa['rol'] ?? 'Alumno',
      direccion: mapa['direccion'] ?? '',
      edad: mapa['edad'] ?? 0,
      sexo: mapa['sexo'] ?? '',
      estado: mapa['estado'] ?? 'activo',
    );
  }

  // Convertir a Mapa
  Map<String, dynamic> aMapa() {
    return {
      'id': id,
      'uid': uid,
      'nombre': nombre,
      'celular': celular,
      'email': email,
      'foto_url': fotoUrl,
      'rol': rol,
      'direccion': direccion,
      'edad': edad,
      'sexo': sexo,
      'estado': estado,
    };
  }
}
