/**
 * INSOFT TESORERÍA DSI - GOOGLE SHEETS CONNECTOR (APPS SCRIPT)
 * 
 * INSTRUCCIONES DE INSTALACIÓN:
 * 1. Abre tu Google Spreadsheet en el navegador.
 * 2. Ve a Extensiones -> Apps Script.
 * 3. Borra el código por defecto y pega este código completo.
 * 4. Cambia el nombre del proyecto a "Insoft Tesoreria Sync".
 * 5. Haz clic en "Implementar" (Deploy) -> "Nueva implementación" (New deployment).
 * 6. Tipo: "Aplicación web" (Web app).
 * 7. Ejecutar como: "Tú" (ej. tu_correo@gmail.com).
 * 8. Quién tiene acceso: "Cualquier persona" (Anyone) <-- IMPORTANTE para que el servidor PHP pueda conectarse.
 * 9. Haz clic en "Implementar", autoriza los accesos de Google y COPIA el URL de la aplicación web que te dará.
 * 10. Pega ese URL en la variable GOOGLE_SHEET_WEBHOOK_URL de tu archivo `.env` en el servidor PHP.
 */

function doPost(e) {
  try {
    var responseData = { ok: false, error: "" };
    
    // Validar el payload de entrada
    if (!e || !e.postData || !e.postData.contents) {
      responseData.error = "No post body received";
      return ContentService.createTextOutput(JSON.stringify(responseData))
                           .setMimeType(ContentService.MimeType.JSON);
    }
    
    // Parsear JSON
    var request = JSON.parse(e.postData.contents);
    var action = request.action;
    var payload = request.payload;
    
    var ss = null;
    var debugLog = [];
    try {
      ss = SpreadsheetApp.getActiveSpreadsheet();
      if (ss) {
        debugLog.push("getActiveSpreadsheet: " + ss.getId());
      } else {
        debugLog.push("getActiveSpreadsheet: null");
      }
    } catch(err) {
      debugLog.push("getActiveSpreadsheet err: " + err.toString());
    }
    if (!ss) {
      try {
        ss = SpreadsheetApp.openByUrl("https://docs.google.com/spreadsheets/d/1elz_pid-14VDtJNLB1qhCnYnQBESgvT_nPIdqMXw9nc/edit");
        debugLog.push("openByUrl: ok");
      } catch(e2) {
        debugLog.push("openByUrl err: " + e2.toString());
        try {
          ss = SpreadsheetApp.openById("1elz_pid-14VDtJNLB1qhCnYnQBESgvT_nPIdqMXw9nc");
          debugLog.push("openById: ok");
        } catch(e3) {
          debugLog.push("openById err: " + e3.toString());
        }
      }
    }
    if (!ss) {
      throw new Error("No access. Debug logs: " + debugLog.join(" | "));
    }
    
    // Ejecutar lógica según la acción recibida
    switch (action) {
      case 'GET_CODE':
        responseData.ok = true;
        responseData.code = {
          sincronizarTodoSheets: typeof sincronizarTodoSheets !== 'undefined' ? sincronizarTodoSheets.toString() : 'undefined',
          sincronizarDetalleApertura: typeof sincronizarDetalleApertura !== 'undefined' ? sincronizarDetalleApertura.toString() : 'undefined',
          obtenerOInsertarHoja: typeof obtenerOInsertarHoja !== 'undefined' ? obtenerOInsertarHoja.toString() : 'undefined'
        };
        return ContentService.createTextOutput(JSON.stringify(responseData))
                             .setMimeType(ContentService.MimeType.JSON);
      case 'DIAGNOSTICO':
        var info = {};
        info.spreadsheetId = ss.getId();
        info.sheets = [];
        var sheets = ss.getSheets();
        for (var i = 0; i < sheets.length; i++) {
          info.sheets.push({
            name: sheets[i].getName(),
            rows: sheets[i].getLastRow(),
            cols: sheets[i].getLastColumn()
          });
        }
        responseData.ok = true;
        responseData.info = info;
        return ContentService.createTextOutput(JSON.stringify(responseData))
                             .setMimeType(ContentService.MimeType.JSON);
      case 'TEST_PAYLOAD':
        responseData.ok = true;
        responseData.payloadSample = {
          hasDeudores: !!(payload && payload.deudores),
          deudoresLength: payload && payload.deudores ? payload.deudores.length : 0,
          hasPagos: !!(payload && payload.pagos),
          pagosLength: payload && payload.pagos ? payload.pagos.length : 0,
          hasGastos: !!(payload && payload.gastos),
          gastosLength: payload && payload.gastos ? payload.gastos.length : 0,
          rawPayloadKeys: payload ? Object.keys(payload) : []
        };
        return ContentService.createTextOutput(JSON.stringify(responseData))
                             .setMimeType(ContentService.MimeType.JSON);
      case 'SINCRONIZAR_TODO':
        // Log payload sizes for diagnosis
        debugLog.push("payload keys: " + (payload ? Object.keys(payload).join(',') : 'NULL'));
        debugLog.push("fondo_base.length: " + (payload && payload.fondo_base ? payload.fondo_base.length : 'NULL'));
        debugLog.push("pagos.length: " + (payload && payload.pagos ? payload.pagos.length : 'NULL'));
        debugLog.push("gastos.length: " + (payload && payload.gastos ? payload.gastos.length : 'NULL'));
        debugLog.push("extras.length: " + (payload && payload.extras ? payload.extras.length : 'NULL'));
        debugLog.push("deudores.length: " + (payload && payload.deudores ? payload.deudores.length : 'NULL'));
        sincronizarTodoSheets(ss, payload, debugLog);
        // Verify row counts after sync
        var sheetNames = ['Detalle Apertura','Historial Pagos','Historial Gastos','Ingresos Extra','Estado Alumnos','Cuadro General Pagos','Resumen General'];
        for (var si = 0; si < sheetNames.length; si++) {
          var sh = ss.getSheetByName(sheetNames[si]);
          debugLog.push(sheetNames[si] + " rows after sync: " + (sh ? sh.getLastRow() : 'NOT FOUND'));
        }
        break;
      case 'TEST_SETVALUES':
        // Test: can doPost context write with setValues?
        var testSheet = ss.getSheetByName('TestSetValues') || ss.insertSheet('TestSetValues');
        testSheet.clear();
        SpreadsheetApp.flush();
        var testData = [["Col A","Col B"],["Row1A","Row1B"],["Row2A","Row2B"]];
        testSheet.getRange(1, 1, testData.length, 2).setValues(testData);
        SpreadsheetApp.flush();
        var readBack = testSheet.getRange(1, 1, 3, 2).getValues();
        responseData.ok = true;
        responseData.wrote = testData.length + " rows";
        responseData.readBack = readBack;
        responseData.lastRow = testSheet.getLastRow();
        return ContentService.createTextOutput(JSON.stringify(responseData))
                             .setMimeType(ContentService.MimeType.JSON);
      case 'APERTURA_CAJA':
        actualizarFondoBase(ss, payload);
        break;
      case 'PAGO_NUEVO':
        registrarPagoSheets(ss, payload);
        break;
      case 'PAGO_EDITADO':
        editarPagoSheets(ss, payload);
        break;
      case 'PAGO_ELIMINADO':
        eliminarPagoSheets(ss, payload);
        break;
      case 'GASTO_NUEVO':
        registrarGastoSheets(ss, payload);
        break;
      case 'GASTO_EDITADO':
        editarGastoSheets(ss, payload);
        break;
      case 'GASTO_ELIMINADO':
        eliminarGastoSheets(ss, payload);
        break;
      case 'INGRESO_EXTRA':
        registrarIngresoExtraSheets(ss, payload);
        break;
      case 'INGRESO_EXTRA_EDITADO':
        editarIngresoExtraSheets(ss, payload);
        break;
      case 'INGRESO_EXTRA_ELIMINADO':
        eliminarIngresoExtraSheets(ss, payload);
        break;
      case 'CAJA_RESET':
        limpiarCajaSheets(ss);
        break;
      default:
        responseData.error = "Acción '" + action + "' desconocida.";
        return ContentService.createTextOutput(JSON.stringify(responseData))
                             .setMimeType(ContentService.MimeType.JSON);
    }
    
    // Sincronizar la hoja de Resumen General si no es una sincronización total (ya que esta lo hace internamente)
    if (action !== 'SINCRONIZAR_TODO') {
      actualizarResumenCaja(ss, payload);
    }
    
    responseData.ok = true;
    responseData.debugLog = debugLog;
    return ContentService.createTextOutput(JSON.stringify(responseData))
                         .setMimeType(ContentService.MimeType.JSON);
                            
  } catch (err) {
    var userEmail = "desconocido";
    try {
      userEmail = Session.getEffectiveUser().getEmail();
    } catch(e) {}
    var errResponse = { ok: false, error: err.toString() + " | Stack: " + (err.stack || "no-stack") + " (Ejecutando como: " + userEmail + ")", debugLog: debugLog };
    return ContentService.createTextOutput(JSON.stringify(errResponse))
                         .setMimeType(ContentService.MimeType.JSON);
  }
}

function ejecutarLayoutSeguro(fn) {
  try {
    fn();
    SpreadsheetApp.flush();
  } catch (err) {
    Logger.log("Advertencia de Layout en modo headless (omitido): " + err.toString());
  }
}

function eliminarHojaPorDefecto(ss) {
  var defaultSheet = ss.getSheetByName("Hoja 1") || ss.getSheetByName("Sheet1") || ss.getSheetByName("Sheet 1");
  if (defaultSheet && ss.getSheets().length > 1) {
    try {
      ss.deleteSheet(defaultSheet);
    } catch (e) {
      // Ignorar si falla
    }
  }
}

// ------------------------------------------------------------------------
// LÓGICA DE SINCRONIZACIÓN COMPLETA (BULK SYNC)
// ------------------------------------------------------------------------

function sincronizarTodoSheets(ss, payload, debugLog) {
  if (!debugLog) debugLog = [];
  debugLog.push("Iniciando sincronizarTodoSheets...");
  
  // 1. Detalle Apertura
  try {
    debugLog.push("1. Iniciando Detalle Apertura");
    sincronizarDetalleApertura(ss, payload.fondo_base);
    debugLog.push("1. Detalle Apertura completado");
  } catch(e) {
    debugLog.push("1. ERROR Detalle Apertura: " + e.toString() + " | Stack: " + e.stack);
  }
  SpreadsheetApp.flush();
  Utilities.sleep(200);
  
  // 2. Historial Pagos
  try {
    debugLog.push("2. Iniciando Historial Pagos");
    sincronizarHistorialPagos(ss, payload.pagos);
    debugLog.push("2. Historial Pagos completado");
  } catch(e) {
    debugLog.push("2. ERROR Historial Pagos: " + e.toString() + " | Stack: " + e.stack);
  }
  SpreadsheetApp.flush();
  Utilities.sleep(200);
  
  // 3. Historial Gastos
  try {
    debugLog.push("3. Iniciando Historial Gastos");
    sincronizarHistorialGastos(ss, payload.gastos);
    debugLog.push("3. Historial Gastos completado");
  } catch(e) {
    debugLog.push("3. ERROR Historial Gastos: " + e.toString() + " | Stack: " + e.stack);
  }
  SpreadsheetApp.flush();
  Utilities.sleep(200);
  
  // 4. Ingresos Extra
  try {
    debugLog.push("4. Iniciando Ingresos Extra");
    sincronizarIngresosExtra(ss, payload.extras);
    debugLog.push("4. Ingresos Extra completado");
  } catch(e) {
    debugLog.push("4. ERROR Ingresos Extra: " + e.toString() + " | Stack: " + e.stack);
  }
  SpreadsheetApp.flush();
  Utilities.sleep(200);
  
  // 5. Estado Alumnos
  try {
    debugLog.push("5. Iniciando Estado Alumnos");
    sincronizarEstadoAlumnos(ss, payload.deudores);
    debugLog.push("5. Estado Alumnos completado");
  } catch(e) {
    debugLog.push("5. ERROR Estado Alumnos: " + e.toString() + " | Stack: " + e.stack);
  }
  SpreadsheetApp.flush();
  Utilities.sleep(200);
  
  // 6. Cuadro General Pagos (Matriz por actividad)
  try {
    debugLog.push("6. Iniciando Cuadro General Pagos");
    sincronizarCuadroGeneralPagos(ss, payload.actividades, payload.deudores, payload.pagos);
    debugLog.push("6. Cuadro General Pagos completado");
  } catch(e) {
    debugLog.push("6. ERROR Cuadro General Pagos: " + e.toString() + " | Stack: " + e.stack);
  }
  SpreadsheetApp.flush();
  Utilities.sleep(200);
  
  // 7. Resumen General
  try {
    debugLog.push("7. Iniciando Resumen General");
    actualizarResumenCaja(ss, payload);
    debugLog.push("7. Resumen General completado");
  } catch(e) {
    debugLog.push("7. ERROR Resumen General: " + e.toString() + " | Stack: " + e.stack);
  }
  SpreadsheetApp.flush();
  
  // Eliminar la hoja por defecto si existe
  eliminarHojaPorDefecto(ss);
  debugLog.push("Sincronización total terminada.");
}

function obtenerOInsertarHoja(ss, nombre) {
  var sheet = ss.getSheetByName(nombre);
  if (!sheet) {
    sheet = ss.insertSheet(nombre);
  }
  sheet.clear();
  sheet.clearFormats();
  SpreadsheetApp.flush(); // Commit clear before writing new data
  return sheet;
}

function sincronizarDetalleApertura(ss, fondoBase) {
  var sheet = obtenerOInsertarHoja(ss, "Detalle Apertura");
  var headers = ["Monto Base (S/)", "Motivo / Notas", "Fecha Apertura"];
  var rows = [headers];
  
  var totalFondo = 0;
  if (fondoBase && fondoBase.length > 0) {
    for (var i = 0; i < fondoBase.length; i++) {
      var row = fondoBase[i];
      var monto = parseFloat(row.monto || 0);
      totalFondo += monto;
      rows.push([
        monto,
        row.motivo || "",
        row.fecha_apertura || ""
      ]);
    }
  }
  
  // Fila de Total
  rows.push([
    totalFondo,
    "TOTAL BASE DE APERTURA",
    ""
  ]);
  
  sheet.getRange(1, 1, rows.length, 3).setValues(rows);
  SpreadsheetApp.flush(); // Commit data before styling
  aplicarEstilosPestaña(sheet, ["right", "left", "center"], ["S/ #,##0.00", "", ""], true, rows.length, 3);
}

function sincronizarHistorialPagos(ss, pagos) {
  var sheet = obtenerOInsertarHoja(ss, "Historial Pagos");
  var headers = ["ID Pago", "Alumno", "Actividad o Concepto", "Método", "Monto (S/)", "Mora (S/)", "Cajero", "Fecha de Pago"];
  var rows = [headers];
  
  var totalMonto = 0;
  var totalMora = 0;
  
  if (pagos && pagos.length > 0) {
    // Ordenar cronológicamente por ID de pago
    pagos.sort(function(a, b) {
      return parseInt(a.id || 0) - parseInt(b.id || 0);
    });
    
    for (var i = 0; i < pagos.length; i++) {
      var p = pagos[i];
      var monto = parseFloat(p.monto || 0);
      var mora = parseFloat(p.monto_multa || 0);
      totalMonto += monto;
      totalMora += mora;
      
      var cajero = p.recaudador || "Sistema";
      if (!isNaN(cajero) && String(cajero).trim().length > 0) {
        cajero = "Admin ID: " + cajero;
      }
      
      rows.push([
        parseInt(p.id || 0),
        p.alumno || "",
        p.actividad || "",
        p.metodo_pago || "Efectivo",
        monto,
        mora,
        cajero,
        p.fecha_pago || ""
      ]);
    }
  }
  
  rows.push([
    "",
    "TOTAL RECAUDADO",
    "",
    "",
    totalMonto,
    totalMora,
    "",
    ""
  ]);
  
  sheet.getRange(1, 1, rows.length, 8).setValues(rows);
  SpreadsheetApp.flush(); // Commit data before styling
  aplicarEstilosPestaña(
    sheet, 
    ["center", "left", "left", "center", "right", "right", "left", "center"], 
    ["", "", "", "", "S/ #,##0.00", "S/ #,##0.00", "", ""], 
    true,
    rows.length,
    8
  );
}

function sincronizarHistorialGastos(ss, gastos) {
  var sheet = obtenerOInsertarHoja(ss, "Historial Gastos");
  var headers = ["ID Gasto", "Descripción", "Actividad Imputada", "Responsable", "Monto Gastado (S/)", "Comprobante?", "Fecha de Gasto"];
  var rows = [headers];
  
  var totalMonto = 0;
  if (gastos && gastos.length > 0) {
    gastos.sort(function(a, b) {
      return parseInt(a.id || 0) - parseInt(b.id || 0);
    });
    
    for (var i = 0; i < gastos.length; i++) {
      var g = gastos[i];
      var monto = parseFloat(g.monto || 0);
      totalMonto += monto;
      
      var responsable = g.responsable || "Sistema";
      if (!isNaN(responsable) && String(responsable).trim().length > 0) {
        responsable = "Admin ID: " + responsable;
      }
      
      var tieneComprobante = (g.comprobante_url && String(g.comprobante_url).trim().length > 0) ? "Sí" : "No";
      
      rows.push([
        parseInt(g.id || 0),
        g.descripcion || "",
        g.actividad || "Gasto General",
        responsable,
        monto,
        tieneComprobante,
        g.fecha_gasto || ""
      ]);
    }
  }
  
  rows.push([
    "",
    "TOTAL GASTOS",
    "",
    "",
    totalMonto,
    "",
    ""
  ]);
  
  sheet.getRange(1, 1, rows.length, 7).setValues(rows);
  SpreadsheetApp.flush(); // Commit data before styling
  aplicarEstilosPestaña(
    sheet, 
    ["center", "left", "left", "left", "right", "center", "center"], 
    ["", "", "", "", "S/ #,##0.00", "", ""], 
    true,
    rows.length,
    7
  );
}

function sincronizarIngresosExtra(ss, extras) {
  var sheet = obtenerOInsertarHoja(ss, "Ingresos Extra");
  var headers = ["ID Registro", "Descripción o Motivo", "Monto Ingreso (S/)", "Responsable", "Fecha Registro"];
  var rows = [headers];
  
  var totalMonto = 0;
  if (extras && extras.length > 0) {
    extras.sort(function(a, b) {
      return parseInt(a.id || 0) - parseInt(b.id || 0);
    });
    
    for (var i = 0; i < extras.length; i++) {
      var ex = extras[i];
      var monto = parseFloat(ex.monto || 0);
      totalMonto += monto;
      
      var responsable = ex.responsable || "Sistema";
      if (!isNaN(responsable) && String(responsable).trim().length > 0) {
        responsable = "Admin ID: " + responsable;
      }
      
      rows.push([
        parseInt(ex.id || 0),
        ex.descripcion || "",
        monto,
        responsable,
        ex.fecha_ingreso || ""
      ]);
    }
  }
  
  rows.push([
    "",
    "TOTAL INGRESOS EXTRA",
    totalMonto,
    "",
    ""
  ]);
  
  sheet.getRange(1, 1, rows.length, 5).setValues(rows);
  SpreadsheetApp.flush(); // Commit data before styling
  aplicarEstilosPestaña(
    sheet, 
    ["center", "left", "right", "left", "center"], 
    ["", "", "S/ #,##0.00", "", ""], 
    true,
    rows.length,
    5
  );
}

function sincronizarEstadoAlumnos(ss, deudores) {
  var sheet = obtenerOInsertarHoja(ss, "Estado Alumnos");
  var headers = ["ID Alumno", "Nombre", "Rol", "Celular", "Total Pagado (S/)", "Deuda Total (S/)", "Estado"];
  var rows = [headers];
  
  var totalPagado = 0;
  var totalDeuda = 0;
  
  if (deudores && deudores.length > 0) {
    deudores.sort(function(a, b) {
      return String(a.nombre || "").localeCompare(String(b.nombre || ""));
    });
    
    for (var i = 0; i < deudores.length; i++) {
      var d = deudores[i];
      var tPagar = parseFloat(d.total_a_pagar || 0);
      var tPagado = parseFloat(d.total_pagado || 0);
      var deuda = tPagar - tPagado;
      
      totalPagado += tPagado;
      totalDeuda += deuda;
      
      rows.push([
        parseInt(d.id || 0),
        d.nombre || "",
        d.rol || "Alumno",
        d.celular || "",
        tPagado,
        deuda,
        deuda > 0 ? "Deudor" : "Al día"
      ]);
    }
  }
  
  rows.push([
    "",
    "TOTAL GENERAL",
    "",
    "",
    totalPagado,
    totalDeuda,
    ""
  ]);
  
  sheet.getRange(1, 1, rows.length, 7).setValues(rows);
  SpreadsheetApp.flush(); // Commit data before styling
  aplicarEstilosPestaña(
    sheet, 
    ["center", "left", "center", "center", "right", "right", "center"], 
    ["", "", "", "", "S/ #,##0.00", "S/ #,##0.00", ""], 
    true,
    rows.length,
    7
  );
}

function sincronizarCuadroGeneralPagos(ss, actividades, deudores, pagos) {
  var sheet = obtenerOInsertarHoja(ss, "Cuadro General Pagos");
  
  if (!actividades) actividades = [];
  if (!deudores) deudores = [];
  if (!pagos) pagos = [];
  
  // Ordenar actividades por ID para que las columnas tengan sentido
  actividades.sort(function(a, b) {
    return parseInt(a.id || 0) - parseInt(b.id || 0);
  });
  
  // Ordenar deudores por nombre
  deudores.sort(function(a, b) {
    return String(a.nombre || "").localeCompare(String(b.nombre || ""));
  });
  
  // Crear cabecera
  var headers = ["N°", "NOMBRES Y APELLIDOS"];
  var formats = ["", ""];
  var alignments = ["center", "left"];
  
  for (var i = 0; i < actividades.length; i++) {
    headers.push(actividades[i].titulo || "");
    formats.push("S/ #,##0.00");
    alignments.push("right");
  }
  headers.push("Total General (S/)");
  formats.push("S/ #,##0.00");
  alignments.push("right");
  
  var rows = [headers];
  
  // Mapear pagos por alumno y actividad
  var mapaPagos = {};
  for (var k = 0; k < pagos.length; k++) {
    var p = pagos[k];
    var key = (p.alumno || "") + "_" + (p.actividad || "");
    mapaPagos[key] = (mapaPagos[key] || 0) + parseFloat(p.monto || 0);
  }
  
  var totalesColumnas = Array(actividades.length).fill(0);
  var totalGeneralMatriz = 0;
  
  for (var u = 0; u < deudores.length; u++) {
    var user = deudores[u];
    var nombreAlumno = user.nombre || "";
    
    var rowCells = [
      u + 1,
      nombreAlumno
    ];
    
    var totalAlumno = 0;
    
    for (var a = 0; a < actividades.length; a++) {
      var act = actividades[a];
      var key = nombreAlumno + "_" + (act.titulo || "");
      var monto = mapaPagos[key] || 0;
      
      totalAlumno += monto;
      totalesColumnas[a] += monto;
      
      rowCells.push(monto > 0 ? monto : "");
    }
    
    totalGeneralMatriz += totalAlumno;
    rowCells.push(totalAlumno);
    rows.push(rowCells);
  }
  
  // Fila de Total
  var footerRow = [
    "",
    "Total"
  ];
  for (var a = 0; a < totalesColumnas.length; a++) {
    footerRow.push(totalesColumnas[a]);
  }
  footerRow.push(totalGeneralMatriz);
  rows.push(footerRow);
  
  sheet.getRange(1, 1, rows.length, headers.length).setValues(rows);
  SpreadsheetApp.flush(); // Commit data before styling
  aplicarEstilosPestaña(sheet, alignments, formats, true, rows.length, headers.length);
}

// Helper para aplicar estilos premium a las pestañas
function aplicarEstilosPestaña(sheet, alignments, formats, hasFooter, lastRow, lastCol) {
  if (!lastRow) lastRow = sheet.getLastRow();
  if (!lastCol) lastCol = sheet.getLastColumn();
  if (lastRow === 0 || lastCol === 0) return;
  
  try {
    // 1. Cabecera (Fila 1) — azul navy, texto blanco
    sheet.getRange(1, 1, 1, lastCol)
         .setBackground("#1D3557")
         .setFontColor("#FFFFFF")
         .setFontWeight("bold")
         .setFontSize(10)
         .setHorizontalAlignment("center")
         .setVerticalAlignment("middle");
    SpreadsheetApp.flush();
  } catch(e) { Logger.log("Header style error: " + e); }
  
  var numDataRows = hasFooter ? (lastRow - 2) : (lastRow - 1);
  
  try {
    // 2. Filas de datos
    if (numDataRows > 0) {
      sheet.getRange(2, 1, numDataRows, lastCol)
           .setFontSize(9)
           .setVerticalAlignment("middle");
      
      // Alineación y formato por columna
      for (var col = 1; col <= lastCol; col++) {
        var colRange = sheet.getRange(2, col, numDataRows, 1);
        var align = alignments[col - 1] || "left";
        var fmt = formats[col - 1] || "";
        colRange.setHorizontalAlignment(align);
        if (fmt) colRange.setNumberFormat(fmt);
      }
      SpreadsheetApp.flush();
    }
  } catch(e) { Logger.log("Data style error: " + e); }
  
  try {
    // 3. Footer — gris claro, negrita
    if (hasFooter && lastRow >= 2) {
      sheet.getRange(lastRow, 1, 1, lastCol)
           .setBackground("#ECEFF1")
           .setFontWeight("bold")
           .setFontSize(9)
           .setVerticalAlignment("middle");
      
      for (var col = 1; col <= lastCol; col++) {
        var align = alignments[col - 1] || "left";
        var fmt = formats[col - 1] || "";
        var cell = sheet.getRange(lastRow, col);
        cell.setHorizontalAlignment(align);
        if (fmt) cell.setNumberFormat(fmt);
      }
      SpreadsheetApp.flush();
    }
  } catch(e) { Logger.log("Footer style error: " + e); }
  
  // 4. Layout (ancho columnas, alto filas, congelar) — tolerante a fallos
  ejecutarLayoutSeguro(function() { sheet.setFrozenRows(1); });
  ejecutarLayoutSeguro(function() { sheet.setRowHeight(1, 28); });
  if (hasFooter && lastRow >= 2) {
    ejecutarLayoutSeguro(function() { sheet.setRowHeight(lastRow, 22); });
  }
  ejecutarLayoutSeguro(function() {
    for (var col = 1; col <= lastCol; col++) {
      var w = (col === 1) ? 70 : (col === 2 || col === 3) ? 190 : (col === lastCol) ? 140 : 110;
      sheet.setColumnWidth(col, w);
    }
  });
}

// ------------------------------------------------------------------------
// MÉTODOS DE INTEGRACIÓN EN TIEMPO REAL (HISTORIAL TRADICIONAL)
// ------------------------------------------------------------------------

function registrarPagoSheets(ss, payload) {
  var sheet = ss.getSheetByName("Historial Pagos") || ss.insertSheet("Historial Pagos");
  eliminarHojaPorDefecto(ss);
  
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(["ID Pago", "Alumno", "Actividad o Concepto", "Método", "Monto (S/)", "Mora (S/)", "Cajero", "Fecha de Pago"]);
    estilizarCabecera(sheet);
  }
  
  var id = payload.id || payload.pago_id || "";
  var alumno = payload.alumno || payload.alumno_nombre || "";
  var actividad = payload.actividad || payload.actividad_titulo || "";
  var metodo = payload.metodo_pago || "Efectivo";
  var monto = parseFloat(payload.monto || 0);
  var mora = parseFloat(payload.monto_multa || 0);
  var cajero = payload.recaudador || payload.registrado_por_nombre || payload.registrado_por || "Sistema";
  var fecha = payload.fecha_pago || Utilities.formatDate(new Date(), "GMT-5", "yyyy-MM-dd HH:mm:ss");

  if (!isNaN(cajero) && String(cajero).trim().length > 0) {
    cajero = "Admin ID: " + cajero;
  }

  sheet.appendRow([
    id,
    alumno,
    actividad,
    metodo,
    monto,
    mora,
    cajero,
    fecha
  ]);
  
  estilizarUltimaFila(sheet, [
    "center",
    "left",
    "left",
    "center",
    "S/ #,##0.00",
    "S/ #,##0.00",
    "left",
    "center"
  ]);
}

function registrarGastoSheets(ss, payload) {
  var sheet = ss.getSheetByName("Historial Gastos") || ss.insertSheet("Historial Gastos");
  eliminarHojaPorDefecto(ss);
  
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(["ID Gasto", "Descripción", "Actividad Imputada", "Responsable", "Monto Gastado (S/)", "Comprobante?", "Fecha de Gasto"]);
    estilizarCabecera(sheet);
  }
  
  var tieneComprobante = (payload.comprobante_url && payload.comprobante_url.trim().length > 0) ? "Sí" : "No";
  
  var id = payload.id || payload.gasto_id || "";
  var descripcion = payload.descripcion || "";
  var actividad = payload.actividad || payload.actividad_titulo || "Gasto General";
  var responsable = payload.responsable || payload.registrado_por_nombre || payload.registrado_por || "Sistema";
  var monto = parseFloat(payload.monto || 0);
  var fecha = payload.fecha_gasto || Utilities.formatDate(new Date(), "GMT-5", "yyyy-MM-dd HH:mm:ss");

  if (!isNaN(responsable) && String(responsable).trim().length > 0) {
    responsable = "Admin ID: " + responsable;
  }

  sheet.appendRow([
    id,
    descripcion,
    actividad,
    responsable,
    monto,
    tieneComprobante,
    fecha
  ]);
  
  estilizarUltimaFila(sheet, [
    "center",
    "left",
    "left",
    "left",
    "S/ #,##0.00",
    "center",
    "center"
  ]);
}

function registrarIngresoExtraSheets(ss, payload) {
  var sheet = ss.getSheetByName("Ingresos Extra") || ss.insertSheet("Ingresos Extra");
  eliminarHojaPorDefecto(ss);
  
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(["ID Registro", "Descripción o Motivo", "Monto Ingreso (S/)", "Responsable", "Fecha Registro"]);
    estilizarCabecera(sheet);
  }
  
  var id = payload.id || payload.ingreso_id || "";
  var descripcion = payload.descripcion || "";
  var monto = parseFloat(payload.monto || 0);
  var responsable = payload.responsable || payload.registrado_por_nombre || payload.registrado_por || "Sistema";
  var fecha = payload.fecha_ingreso || Utilities.formatDate(new Date(), "GMT-5", "yyyy-MM-dd HH:mm:ss");

  if (!isNaN(responsable) && String(responsable).trim().length > 0) {
    responsable = "Admin ID: " + responsable;
  }

  sheet.appendRow([
    id,
    descripcion,
    monto,
    responsable,
    fecha
  ]);
  
  estilizarUltimaFila(sheet, [
    "center",
    "left",
    "S/ #,##0.00",
    "left",
    "center"
  ]);
}

function actualizarFondoBase(ss, payload) {
  var sheet = ss.getSheetByName("Detalle Apertura") || ss.insertSheet("Detalle Apertura");
  eliminarHojaPorDefecto(ss);
  
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(["Monto Base (S/)", "Motivo / Notas", "Fecha Apertura"]);
    estilizarCabecera(sheet);
  }
  
  sheet.appendRow([
    parseFloat(payload.monto || 0),
    payload.motivo || "Apertura de Caja",
    payload.fecha_apertura || Utilities.formatDate(new Date(), "GMT-5", "yyyy-MM-dd HH:mm:ss")
  ]);
  
  estilizarUltimaFila(sheet, [
    "S/ #,##0.00",
    "left",
    "center"
  ]);
}

function limpiarCajaSheets(ss) {
  var hojas = ["Detalle Apertura", "Historial Pagos", "Historial Gastos", "Ingresos Extra", "Resumen General", "Estado Alumnos", "Cuadro General Pagos"];
  for (var i = 0; i < hojas.length; i++) {
    var sheet = ss.getSheetByName(hojas[i]);
    if (sheet) {
      sheet.clearContents();
      sheet.clearFormats();
    }
  }
}

// ------------------------------------------------------------------------
// HOJA DE RESUMEN GENERAL E INTERFAZ ESTÉTICA DE GOOGLE SHEETS
// ------------------------------------------------------------------------

function actualizarResumenCaja(ss, payload) {
  var sheet = ss.getSheetByName("Resumen General") || ss.insertSheet("Resumen General");
  eliminarHojaPorDefecto(ss);
  sheet.clear(); // Limpiamos para redibujar el resumen actualizado
  
  // Título principal de alta gama
  sheet.getRange("A1").setValue("INSOFT TESORERÍA - AUDITORÍA EN TIEMPO REAL");
  sheet.getRange("A1:B1").merge();
  sheet.getRange("A1").setFontWeight("bold").setFontSize(14).setFontColor("#FFFFFF").setBackground("#1D3557").setHorizontalAlignment("center");
  
  // Subtítulo con fecha
  var fechaActual = Utilities.formatDate(new Date(), "GMT-5", "dd/MM/yyyy HH:mm");
  sheet.getRange("A2").setValue("Última actualización: " + fechaActual + " (GMT-5)");
  sheet.getRange("A2:B2").merge();
  sheet.getRange("A2").setFontStyle("italic").setFontSize(9).setFontColor("#555555").setHorizontalAlignment("center");
  
  sheet.appendRow(["", ""]); // Espaciador
  sheet.appendRow(["Concepto de Control de Caja", "Monto (S/)"]);
  
  // Cabecera de la tabla
  var headRow = 4;
  sheet.getRange("A" + headRow + ":B" + headRow).setFontWeight("bold").setFontColor("#FFFFFF").setBackground("#457B9D").setBorder(true, true, true, true, true, true, "#CCCCCC", SpreadsheetApp.BorderStyle.SOLID);
  
  // Fórmulas dinámicas basadas en los historiales de las otras pestañas
  sheet.appendRow(["(+) Fondo de Apertura (Caja Fuerte)", ""]);
  sheet.getRange("B5").setFormula("=IFERROR(SUM('Detalle Apertura'!A2:A), 0)");
  
  sheet.appendRow(["(+) Ingresos por Cobros (Pagos)", ""]);
  sheet.getRange("B6").setFormula("=IFERROR(SUM('Historial Pagos'!E2:E) + SUM('Historial Pagos'!F2:F), 0)");
  
  sheet.appendRow(["(+) Ingresos Extra y Donaciones", ""]);
  sheet.getRange("B7").setFormula("=IFERROR(SUM('Ingresos Extra'!C2:C), 0)");
  
  sheet.appendRow(["(-) Gastos Totales (Egresos)", ""]);
  sheet.getRange("B8").setFormula("=IFERROR(SUM('Historial Gastos'!E2:E), 0)");
  
  sheet.appendRow(["(=) SALDO NETO ACTUAL EN CAJA", ""]);
  sheet.getRange("B9").setFormula("=B5+B6+B7-B8");
  
  sheet.appendRow(["", ""]); // Espaciador
  sheet.appendRow(["(*) Deuda Pendiente (Por cobrar)", ""]);
  sheet.getRange("B11").setFormula("=IFERROR(SUM('Estado Alumnos'!F2:F), 0)");
  
  // Formatear filas de datos
  var startRow = 5;
  var endRow = 9;
  for (var r = startRow; r <= endRow; r++) {
    var range = sheet.getRange("A" + r + ":B" + r);
    range.setBorder(true, true, true, true, true, true, "#E0E0E0", SpreadsheetApp.BorderStyle.SOLID);
    
    // Celda de Monto
    var cellMonto = sheet.getRange("B" + r);
    cellMonto.setNumberFormat("S/ #,##0.00").setHorizontalAlignment("right");
    
    // Distinción de la fila del Saldo Final
    if (r === endRow) {
      range.setFontWeight("bold").setBackground("#ECEFF1");
      range.setBorder(true, true, true, true, true, true, "#1D3557", SpreadsheetApp.BorderStyle.DOUBLE); // Doble línea contable
    }
  }
  
  // Formatear fila de deuda pendiente (Fila 11)
  var rangeDeuda = sheet.getRange("A11:B11");
  rangeDeuda.setBorder(true, true, true, true, true, true, "#E0E0E0", SpreadsheetApp.BorderStyle.SOLID)
             .setFontStyle("italic");
  sheet.getRange("B11").setNumberFormat("S/ #,##0.00").setHorizontalAlignment("right");
  
  // Aplicar tipo de fuente Inter
  sheet.getRange("A1:B11").setFontFamily("Inter");
  
  ejecutarLayoutSeguro(function() {
    sheet.setColumnWidth(1, 280);
    sheet.setColumnWidth(2, 150);
  });
}

// ------------------------------------------------------------------------
// MÉTODOS DE APOYO DE ESTILOS PREMIUM INDIVIDUALES
// ------------------------------------------------------------------------

function estilizarCabecera(sheet) {
  var lastCol = sheet.getLastColumn();
  var range = sheet.getRange(1, 1, 1, lastCol);
  
  range.setFontWeight("bold")
       .setFontColor("#FFFFFF")
       .setBackground("#1D3557")
       .setFontSize(10)
       .setFontFamily("Inter")
       .setHorizontalAlignment("center");
       
  ejecutarLayoutSeguro(function() {
    sheet.setRowHeight(1, 26);
  });
  ejecutarLayoutSeguro(function() {
    sheet.setFrozenRows(1);
  });
}

function estilizarUltimaFila(sheet, formatos) {
  var row = sheet.getLastRow();
  var cols = sheet.getLastColumn();
  
  // Formatear bordes y celdas
  for (var c = 1; c <= cols; c++) {
    var cell = sheet.getRange(row, c);
    cell.setFontFamily("Inter").setFontSize(9).setBorder(true, true, true, true, true, true, "#E0E0E0", SpreadsheetApp.BorderStyle.SOLID);
    
    var formato = formatsMapping(formatos[c - 1]);
    if (formato.isNumberFormat) {
      cell.setNumberFormat(formato.val).setHorizontalAlignment("right");
    } else {
      cell.setHorizontalAlignment(formato.val);
    }
  }
  
  // Establecer anchos de columna y altos de fila de forma segura
  ejecutarLayoutSeguro(function() {
    sheet.setRowHeight(row, 20);
  });
  ejecutarLayoutSeguro(function() {
    for (var col = 1; col <= cols; col++) {
      var width = 110;
      if (col === 2 || col === 3) {
        width = 190;
      } else if (col === 1) {
        width = 70;
      } else if (col === cols) {
        width = 140;
      }
      sheet.setColumnWidth(col, width);
    }
  });
}

function formatsMapping(formatInput) {
  if (!formatInput) return { isNumberFormat: false, val: "left" };
  
  if (typeof formatInput === "string" && formatInput.indexOf("S/") !== -1) {
    return { isNumberFormat: true, val: formatInput };
  }
  
  var valString = "left";
  if (formatInput === "center") {
    valString = "center";
  } else if (formatInput === "right") {
    valString = "right";
  }
  
  return { isNumberFormat: false, val: valString };
}

// ------------------------------------------------------------------------
// FUNCIONES DE EDICIÓN Y ELIMINACIÓN INDIVIDUAL
// ------------------------------------------------------------------------

function editarGastoSheets(ss, payload) {
  var sheet = ss.getSheetByName("Historial Gastos");
  if (!sheet) return;
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return;
  var data = sheet.getRange(2, 1, lastRow - 1, 7).getValues();
  var idBuscar = String(payload.id || payload.gasto_id);
  for (var i = 0; i < data.length; i++) {
    if (String(data[i][0]) === idBuscar) {
      var row = i + 2;
      var descripcion = payload.descripcion || "";
      var actividad = payload.actividad || payload.actividad_titulo || "Gasto General";
      var monto = parseFloat(payload.monto || 0);
      var tieneComprobante = (payload.comprobante_url && payload.comprobante_url.trim().length > 0) ? "Sí" : "No";
      
      sheet.getRange(row, 2).setValue(descripcion);
      sheet.getRange(row, 3).setValue(actividad);
      sheet.getRange(row, 5).setValue(monto);
      sheet.getRange(row, 6).setValue(tieneComprobante);
      break;
    }
  }
}

function eliminarGastoSheets(ss, payload) {
  var sheet = ss.getSheetByName("Historial Gastos");
  if (!sheet) return;
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return;
  var data = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
  var idBuscar = String(payload.id || payload.gasto_id);
  for (var i = 0; i < data.length; i++) {
    if (String(data[i][0]) === idBuscar) {
      sheet.deleteRow(i + 2);
      break;
    }
  }
}

function editarPagoSheets(ss, payload) {
  var sheet = ss.getSheetByName("Historial Pagos");
  if (!sheet) return;
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return;
  var data = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
  var idBuscar = String(payload.id || payload.pago_id);
  for (var i = 0; i < data.length; i++) {
    if (String(data[i][0]) === idBuscar) {
      var row = i + 2;
      var monto = parseFloat(payload.monto || 0);
      sheet.getRange(row, 5).setValue(monto);
      break;
    }
  }
}

function eliminarPagoSheets(ss, payload) {
  var sheet = ss.getSheetByName("Historial Pagos");
  if (!sheet) return;
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return;
  var data = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
  var idBuscar = String(payload.id || payload.pago_id);
  for (var i = 0; i < data.length; i++) {
    if (String(data[i][0]) === idBuscar) {
      sheet.deleteRow(i + 2);
      break;
    }
  }
}

function editarIngresoExtraSheets(ss, payload) {
  var sheet = ss.getSheetByName("Ingresos Extra");
  if (!sheet) return;
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return;
  var data = sheet.getRange(2, 1, lastRow - 1, 3).getValues();
  var idBuscar = String(payload.id || payload.ingreso_id);
  for (var i = 0; i < data.length; i++) {
    if (String(data[i][0]) === idBuscar) {
      var row = i + 2;
      var descripcion = payload.descripcion || "";
      var monto = parseFloat(payload.monto || 0);
      sheet.getRange(row, 2).setValue(descripcion);
      sheet.getRange(row, 3).setValue(monto);
      break;
    }
  }
}

function eliminarIngresoExtraSheets(ss, payload) {
  var sheet = ss.getSheetByName("Ingresos Extra");
  if (!sheet) return;
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return;
  var data = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
  var idBuscar = String(payload.id || payload.ingreso_id);
  for (var i = 0; i < data.length; i++) {
    if (String(data[i][0]) === idBuscar) {
      sheet.deleteRow(i + 2);
      break;
    }
  }
}

function testConexion() {
  try {
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    Logger.log("Paso 1: getActiveSpreadsheet ok. ID: " + ss.getId());
    
    Logger.log("Paso 2: Creando hoja 'Detalle Apertura'...");
    var sheet = obtenerOInsertarHoja(ss, "Detalle Apertura");
    SpreadsheetApp.flush();
    Logger.log("Paso 2 ok: hoja creada y flusheada.");
    
    Logger.log("Paso 3: Escribiendo valores...");
    var rows = [
      ["Monto Base (S/)", "Motivo / Notas", "Fecha Apertura"],
      [100.0, "Prueba Apertura", "2026-06-10 00:00:00"],
      [100.0, "TOTAL BASE DE APERTURA", ""]
    ];
    sheet.getRange(1, 1, rows.length, 3).setValues(rows);
    SpreadsheetApp.flush();
    Logger.log("Paso 3 ok: valores escritos.");
    
    Logger.log("Paso 4: Aplicando estilos...");
    aplicarEstilosPestaña(sheet, ["right", "left", "center"], ["S/ #,##0.00", "", ""], true, rows.length, 3);
    SpreadsheetApp.flush();
    Logger.log("Paso 4 ok: estilos aplicados.");
    
    Logger.log("--- ¡PRUEBA COMPLETA CON ÉXITO! ---");
  } catch(e) {
    Logger.log("FALLO EN PASO: " + e.toString() + " | Stack: " + e.stack);
  }
}

function logSheetInfo() {
  try {
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var sheets = ss.getSheets();
    for (var i = 0; i < sheets.length; i++) {
      var sheet = sheets[i];
      Logger.log("HOJA: '" + sheet.getName() + "' | Última Fila: " + sheet.getLastRow() + " | Última Columna: " + sheet.getLastColumn());
      if (sheet.getLastRow() > 0) {
        var numCols = Math.min(sheet.getLastColumn(), 5);
        var numRows = Math.min(sheet.getLastRow(), 3);
        var data = sheet.getRange(1, 1, numRows, numCols).getValues();
        Logger.log("Muestra de datos: " + JSON.stringify(data));
      }
    }
  } catch(e) {
    Logger.log("ERROR EN DIAGNÓSTICO: " + e.toString());
  }
}

