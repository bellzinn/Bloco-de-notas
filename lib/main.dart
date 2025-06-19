import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  runApp(const MyApp());
}

class Nota {
  final int? id;
  final String titulo;
  final String conteudo;

  Nota({this.id, required this.titulo, required this.conteudo});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'conteudo': conteudo,
    };
  }

  static Nota fromMap(Map<String, dynamic> map) {
    return Nota(
      id: map['id'],
      titulo: map['titulo'],
      conteudo: map['conteudo'],
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('notas.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT NOT NULL,
        conteudo TEXT NOT NULL
      )
    ''');
  }

  Future<List<Nota>> getNotas() async {
    final db = await instance.database;
    final result = await db.query('notas');
    return result.map((json) => Nota.fromMap(json)).toList();
  }

  Future<int> addNota(Nota nota) async {
    final db = await instance.database;
    return await db.insert('notas', nota.toMap());
  }

  Future<int> updateNota(Nota nota) async {
    final db = await instance.database;
    return await db.update(
      'notas',
      nota.toMap(),
      where: 'id = ?',
      whereArgs: [nota.id],
    );
  }

  Future<int> deleteNota(int id) async {
    final db = await instance.database;
    return await db.delete('notas', where: 'id = ?', whereArgs: [id]);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bloco de Notas',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const NotaListPage(),
    );
  }
}

class NotaListPage extends StatefulWidget {
  const NotaListPage({super.key});

  @override
  State<NotaListPage> createState() => _NotaListPageState();
}

class _NotaListPageState extends State<NotaListPage> {
  late Future<List<Nota>> notas;

  @override
  void initState() {
    super.initState();
    notas = DatabaseHelper.instance.getNotas();
  }

  Future<void> _refreshNotas() async {
    setState(() {
      notas = DatabaseHelper.instance.getNotas();
    });
  }

  void _abrirNota(BuildContext context, [Nota? nota]) async {
    final resultado = await Navigator.of(context).push<Nota>(
      MaterialPageRoute(
        builder: (context) => NotaDetailPage(nota: nota),
      ),
    );
    if (resultado != null) {
      await _refreshNotas();
    }
  }

  void _deletarNota(int id) async {
    await DatabaseHelper.instance.deleteNota(id);
    await _refreshNotas();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nota deletada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bloco de Notas'),
      ),
      body: FutureBuilder<List<Nota>>(
        future: notas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final listaNotas = snapshot.data!;
            if (listaNotas.isEmpty) {
              return const Center(child: Text('Nenhuma nota encontrada.'));
            }
            return ListView.builder(
              itemCount: listaNotas.length,
              itemBuilder: (context, index) {
                final nota = listaNotas[index];
                return ListTile(
                  title: Text(nota.titulo),
                  subtitle: Text(
                    nota.conteudo.length > 50
                        ? '${nota.conteudo.substring(0, 50)}...'
                        : nota.conteudo,
                  ),
                  onTap: () => _abrirNota(context, nota),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletarNota(nota.id!),
                  ),
                );
              },
            );
          }
          return const Center(child: Text('Nenhuma nota disponível.'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirNota(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class NotaDetailPage extends StatefulWidget {
  final Nota? nota;

  const NotaDetailPage({super.key, this.nota});

  @override
  State<NotaDetailPage> createState() => _NotaDetailPageState();
}

class _NotaDetailPageState extends State<NotaDetailPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tituloController;
  late TextEditingController _conteudoController;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.nota?.titulo ?? '');
    _conteudoController = TextEditingController(text: widget.nota?.conteudo ?? '');
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _conteudoController.dispose();
    super.dispose();
  }

  void _salvarNota() async {
    if (_formKey.currentState!.validate()) {
      final titulo = _tituloController.text.trim();
      final conteudo = _conteudoController.text.trim();

      final nota = Nota(
        id: widget.nota?.id,
        titulo: titulo,
        conteudo: conteudo,
      );

      if (widget.nota == null) {
        await DatabaseHelper.instance.addNota(nota);
      } else {
        await DatabaseHelper.instance.updateNota(nota);
      }

      if (mounted) {
        Navigator.of(context).pop(nota);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nota == null ? 'Nova Nota' : 'Editar Nota'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _salvarNota,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, insira um título';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextFormField(
                  controller: _conteudoController,
                  decoration: const InputDecoration(labelText: 'Conteúdo'),
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, insira o conteúdo';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
