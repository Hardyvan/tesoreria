import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../myPagesBack/modelo_usuario.dart';
import '../myPagesBack/modelo_pago.dart';

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
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _crearTablasNuevas(db);
    }
  }

  Future<void> _crearTablasNuevas(Database db) async {
    await db.execute('''
      CREATE TABLE actividades (
        id INTEGER PRIMARY KEY,
        titulo TEXT,
        descripcion TEXT,
        costo REAL,
        fecha_creacion TEXT,
        fecha_limite TEXT,
        multa_por_dia REAL,
        estado TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE pagos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER,
        actividad_id INTEGER,
        monto_pagado REAL,
        fecha_pago TEXT,
        metodo_pago TEXT,
        confirmado INTEGER,
        sincronizado INTEGER DEFAULT 0,
        temp_id_remoto INTEGER
      )
    ''');
    debugPrint("Tablas locales 'actividades' y 'pagos' creadas.");
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
    await _crearTablasNuevas(db);
  }

  // ---------------------------------------------------------------------------
  // CRUD PAGOS (OFFLINE)
  // ---------------------------------------------------------------------------

  Future<void> insertarPagoLocal(Pago pago) async {
    final db = await instance.database;
    await db.insert(
      'pagos',
      {
        'usuario_id': pago.usuarioId,
        'actividad_id': pago.actividadId,
        'monto_pagado': pago.montoPagado,
        'fecha_pago': pago.fechaPago.toIso8601String(),
        'metodo_pago': pago.metodoPago,
        'confirmado': pago.confirmado ? 1 : 0,
        'sincronizado': 0, // Pendiente de subir
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Pago>> obtenerPagosNoSincronizados() async {
    final db = await instance.database;
    final result = await db.query('pagos', where: 'sincronizado = ?', whereArgs: [0]);

    return result.map((json) => Pago(
      id: json['id'] as int,
      usuarioId: json['usuario_id'] as int,
      actividadId: json['actividad_id'] as int,
      montoPagado: json['monto_pagado'] as double,
      fechaPago: DateTime.parse(json['fecha_pago'] as String),
      metodoPago: json['metodo_pago'] as String,
      confirmado: (json['confirmado'] as int) == 1,
    )).toList();
  }

  Future<void> marcarPagoSincronizado(int localId, int remotoId) async {
    final db = await instance.database;
    await db.update(
      'pagos',
      {'sincronizado': 1, 'temp_id_remoto': remotoId},
      where: 'id = ?',
      whereArgs: [localId],
    );
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
