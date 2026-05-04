import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Pantilla Analítica: InSOFT Analytics
class InsoftAnalyticsDemo extends StatefulWidget {
  const InsoftAnalyticsDemo({Key? key}) : super(key: key);

  @override
  State<InsoftAnalyticsDemo> createState() => _InsoftAnalyticsDemoState();
}

class _InsoftAnalyticsDemoState extends State<InsoftAnalyticsDemo> {
  // Variables de los filtros
  String _anioSeleccionado = '2026';
  String _enfermedadSeleccionada = 'DENGUE';
  String _departamentoSeleccionado = 'NACIONAL';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Tendencias, Tablas, Mapas
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1D3557), // Azul oscuro estilo corporativo
          title: const Text(
            'InSOFT Analytics - Sala Situacional',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: Text(
                  'Motor: DSI',
                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                ),
              ),
            ),
          ],
        ),
        body: Row(
          children: [
            // 1. BARRA LATERAL DE FILTROS (Izquierda)
            _buildBarraLateral(),

            // 2. ÁREA PRINCIPAL DE DATOS (Derecha)
            Expanded(
              child: Column(
                children: [
                  // Pestañas (Tabs)
                  Container(
                    color: Colors.white,
                    child: const TabBar(
                      labelColor: Color(0xFF1D3557),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.teal,
                      tabs: [
                        Tab(text: 'Tendencias (Gráficos)'),
                        Tab(text: 'Tablas de Datos'),
                        Tab(text: 'Mapas'),
                      ],
                    ),
                  ),
                  
                  // Contenido de las pestañas
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF1F5F9), // Fondo gris claro
                      padding: const EdgeInsets.all(16),
                      child: TabBarView(
                        children: [
                          _buildGraficoTendencias(),
                          _buildTablaDatos(),
                          _buildMapaPlaceholder(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: BARRA LATERAL DE FILTROS ---
  Widget _buildBarraLateral() {
    return Container(
      width: 250,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtrar información',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          const SizedBox(height: 16),
          
          _crearDropdown('Año de análisis', ['2024', '2025', '2026'], _anioSeleccionado, (val) {
            setState(() => _anioSeleccionado = val!);
          }),
          
          _crearDropdown('Enfermedad', ['DENGUE', 'MALARIA', 'ZIKA'], _enfermedadSeleccionada, (val) {
            setState(() => _enfermedadSeleccionada = val!);
          }),
          
          _crearDropdown('Departamento', ['NACIONAL', 'LIMA', 'PIURA', 'LORETO'], _departamentoSeleccionado, (val) {
            setState(() => _departamentoSeleccionado = val!);
          }),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                // Aquí iría la lógica para procesar el CSV cargado en memoria
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Procesando datos en memoria...')),
                );
              },
              icon: const Icon(Icons.analytics),
              label: const Text('Procesar Datos'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _crearDropdown(String titulo, List<String> opciones, String valorActual, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: valorActual,
                items: opciones.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: GRÁFICO DE TENDENCIAS (fl_chart) ---
  Widget _buildGraficoTendencias() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Curva Epidémica de $_enfermedadSeleccionada - $_anioSeleccionado',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1D3557)),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (val, meta) => Text('Sem ${val.toInt()}')),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: const [
                        FlSpot(1, 1500), FlSpot(2, 2100), FlSpot(3, 4000), 
                        FlSpot(4, 8500), FlSpot(5, 6000), FlSpot(6, 3200),
                      ],
                      isCurved: true,
                      color: Colors.redAccent,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true, 
                        color: Colors.redAccent.withOpacity(0.1)
                      ),
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: TABLA DE DATOS ---
  Widget _buildTablaDatos() {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tabla de indicadores epidemiológicos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () {},
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Descargar CSV'),
                )
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFF1D3557)),
                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                columns: const [
                  DataColumn(label: Text('Indicador')),
                  DataColumn(label: Text('Casos')),
                  DataColumn(label: Text('Tasa Incidencia')),
                  DataColumn(label: Text('Defunciones')),
                  DataColumn(label: Text('Letalidad (%)')),
                ],
                rows: const [
                  DataRow(cells: [DataCell(Text('Casos Totales')), DataCell(Text('16,178')), DataCell(Text('46.7')), DataCell(Text('17')), DataCell(Text('0.11'))]),
                  DataRow(cells: [DataCell(Text('Casos Confirmados')), DataCell(Text('9,403')), DataCell(Text('27.1')), DataCell(Text('16')), DataCell(Text('0.17'))]),
                  DataRow(cells: [DataCell(Text('Casos Probables')), DataCell(Text('6,775')), DataCell(Text('19.6')), DataCell(Text('1')), DataCell(Text('0.01'))]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: MAPA (Placeholder) ---
  Widget _buildMapaPlaceholder() {
    return const Card(
      elevation: 2,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Mapa Interactivo de Calor (Requiere flutter_map)', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
