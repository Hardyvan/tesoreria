import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../myPagesBack/modelo_usuario.dart';

class BaseDatosLocal {
  static Database? _database;

  // Singleton
  static final BaseDatosLocal instance = BaseDatosLocal._init();
  BaseDatosLocal._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tesoreria_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Tabla Usuarios (Copia local de DSI_salon_usuarios)
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY, -- ID remoto de MySQL
        nombre TEXT,
        celular TEXT,
        email TEXT,
        fotoUrl TEXT,
        rol TEXT,
        direccion TEXT,
        edad INTEGER,
        sexo TEXT,
        estado TEXT, -- Nuevo: 'activo' / 'inactivo'
        sincronizado INTEGER DEFAULT 1, -- 1: SÃ­, 0: No (Pendiente de subir)
        updated_at TEXT -- Fecha de ultima modificacion para resolucion de conflictos
      )
    ''');
    debugPrint("Tabla local 'usuarios' creada.");
  }

  // ---------------------------------------------------------------------------
  // CRUD USUARIOS
  // ---------------------------------------------------------------------------

  // A. Guardar/Actualizar Usuario (Desde la Nube o Local)
  Future<void> insertarUsuario(Usuario usuario, {bool sincronizado = true}) async {
    final db = await instance.database;
    
    // Usamos ConflictAlgorithm.replace para hacer "Upsert" (Insertar o Actualizar)
    await db.insert(
      'usuarios',
      {
        'id': usuario.id,
        'nombre': usuario.nombre,
        'celular': usuario.celular,
        'email': usuario.email,
        'fotoUrl': usuario.fotoUrl,
        'rol': usuario.rol,
        'direccion': usuario.direccion,
        'edad': usuario.edad,
        'sexo': usuario.sexo,
        'estado': usuario.estado,
        'sincronizado': sincronizado ? 1 : 0,
        'updated_at': usuario.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // B. Obtener Todos (Para listar offline)
  Future<List<Usuario>> obtenerUsuarios() async {
    final db = await instance.database;
    final result = await db.query('usuarios', orderBy: 'nombre ASC');

    return result.map((json) => Usuario.desdeMapa({
      'id': json['id'],
      'nombre': json['nombre'],
      'celular': json['celular'],
      'email': json['email'],
      'foto_url': json['fotoUrl'], // Mapeo manual por diferencia de nombres
      'rol': json['rol'],
      'direccion': json['direccion'],
      'edad': json['edad'],
      'sexo': json['sexo'],
      'estado': json['estado'],
    })).toList();
  }

  // C. Obtener Pendientes de SincronizaciÃ³n
  Future<List<Usuario>> obtenerNoSincronizados() async {
    final db = await instance.database;
    final result = await db.query('usuarios', where: 'sincronizado = ?', whereArgs: [0]);

    return result.map((json) => Usuario.desdeMapa({
      'id': json['id'],
      'nombre': json['nombre'],
      'celular': json['celular'],
      'email': json['email'],
      'foto_url': json['fotoUrl'],
      'rol': json['rol'],
      'direccion': json['direccion'],
      'edad': json['edad'],
      'sexo': json['sexo'],
      'estado': json['estado'],
      'updated_at': json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    })).toList();
  }

  // D. Marcar como Sincronizado
  Future<void> marcarSincronizado(int id) async {
    final db = await instance.database;
    await db.update(
      'usuarios',
      {'sincronizado': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
