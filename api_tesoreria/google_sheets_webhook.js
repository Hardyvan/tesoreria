/**
 * INSOFT TESORERÍA DSI - GOOGLE SHEETS CONNECTOR (APPS SCRIPT)
 * 
 * INSTRUCCIONES DE INSTALACIÓN:
 * 1. Abre tu Google Spreadsheet en el navegador.
 * 2. Ve a Extenciones -> Apps Script.
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
    
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    
    // Ejecutar lógica según la acción recibida
    switch (action) {
      case 'APERTURA_CAJA':
        actualizarFondoBase(ss, payload);
        break;
      case 'PAGO_NUEVO':
        registrarPagoSheets(ss, payload);
        break;
      case 'GASTO_NUEVO':
        registrarGastoSheets(ss, payload);
        break;
      case 'INGRESO_EXTRA':
        registrarIngresoExtraSheets(ss, payload);
        break;
      case 'CAJA_RESET':
        limpiarCajaSheets(ss);
        break;
      default:
        responseData.error = "Acción '" + action + "' desconocida.";
        return ContentService.createTextOutput(JSON.stringify(responseData))
                             .setMimeType(ContentService.MimeType.JSON);
    }
    
    // Sincronizar la hoja de Resumen General
    actualizarResumenCaja(ss, payload);
    
    responseData.ok = true;
    return ContentService.createTextOutput(JSON.stringify(responseData))
                         .setMimeType(ContentService.MimeType.JSON);
                         
  } catch (err) {
    var errResponse = { ok: false, error: err.toString() };
    return ContentService.createTextOutput(JSON.stringify(errResponse))
                         .setMimeType(ContentService.MimeType.JSON);
  }
}

// ------------------------------------------------------------------------
// MÉTODOS DE INTEGRACIÓN Y ESTILIZACIÓN DE Hojas
// ------------------------------------------------------------------------

function registrarPagoSheets(ss, payload) {
  var sheet = ss.getSheetByName("Historial Pagos") || ss.insertSheet("Historial Pagos");
  
  // Si la hoja está vacía, crear cabeceras con estilo corporativo
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(["ID Pago", "Alumno", "Actividad o Concepto", "Método", "Monto (S/)", "Mora (S/)", "Cajero", "Fecha de Pago"]);
    estilizarCabecera(sheet);
  }
  
  // Agregar datos
  sheet.appendRow([
    payload.id || "",
    payload.alumno || "",
    payload.actividad || "",
    payload.metodo_pago || "Efectivo",
    parseFloat(payload.monto || 0),
    parseFloat(payload.monto_multa || 0),
    payload.recaudador || "Sistema",
    payload.fecha_pago || Utilities.formatDate(new Date(), "GMT-5", "yyyy-MM-dd HH:mm:ss")
  ]);
  
  // Aplicar formato a la última fila insertada
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
  
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(["ID Gasto", "Descripción", "Actividad Imputada", "Responsable", "Monto Gastado (S/)", "Comprobante?", "Fecha de Gasto"]);
    estilizarCabecera(sheet);
  }
  
  var tieneComprobante = (payload.comprobante_url && payload.comprobante_url.trim().length > 0) ? "Sí" : "No";
  
  sheet.appendRow([
    payload.id || "",
    payload.descripcion || "",
    payload.actividad || "Gasto General",
    payload.responsable || "Sistema",
    parseFloat(payload.monto || 0),
    tieneComprobante,
    payload.fecha_gasto || Utilities.formatDate(new Date(), "GMT-5", "yyyy-MM-dd HH:mm:ss")
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
  
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(["ID Registro", "Descripción o Motivo", "Monto Ingreso (S/)", "Responsable", "Fecha Registro"]);
    estilizarCabecera(sheet);
  }
  
  sheet.appendRow([
    payload.id || "",
    payload.descripcion || "",
    parseFloat(payload.monto || 0),
    payload.responsable || "Sistema",
    payload.fecha_ingreso || Utilities.formatDate(new Date(), "GMT-5", "yyyy-MM-dd HH:mm:ss")
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
  // Limpia los datos de las hojas para reiniciar caja
  var hojas = ["Detalle Apertura", "Historial Pagos", "Historial Gastos", "Ingresos Extra", "Resumen General"];
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
  
  sheet.appendRow([]); // Espaciador
  sheet.appendRow(["Concepto de Control de Caja", "Monto (S/)"]);
  
  // Cabecera de la tabla
  var headRow = 4;
  sheet.getRange("A" + headRow + ":B" + headRow).setFontWeight("bold").setFontColor("#FFFFFF").setBackground("#457B9D").setBorder(true, true, true, true, true, true, "#CCCCCC", SpreadsheetApp.BorderStyle.SOLID);
  
  // Fórmulas dinámicas basadas en los historiales de las otras pestañas
  // Así el total en la nube se calcula de forma real y transparente, auditado por fórmulas
  sheet.appendRow(["(+) Fondo de Apertura (Caja Fuerte)", "=IFERROR(SUM('Detalle Apertura'!A2:A), 0)"]);
  sheet.appendRow(["(+) Ingresos por Cobros (Pagos)", "=IFERROR(SUM('Historial Pagos'!E2:E) + SUM('Historial Pagos'!F2:F), 0)"]);
  sheet.appendRow(["(+) Ingresos Extra y Donaciones", "=IFERROR(SUM('Ingresos Extra'!C2:C), 0)"]);
  sheet.appendRow(["(-) Gastos Totales (Egresos)", "=IFERROR(SUM('Historial Gastos'!E2:E), 0)"]);
  sheet.appendRow(["(=) SALDO NETO ACTUAL EN CAJA", "=B5+B6+B7-B8"]);
  
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
  
  sheet.setColumnWidth(1, 280);
  sheet.setColumnWidth(2, 150);
}

// ------------------------------------------------------------------------
// MÉTODOS DE APOYO DE ESTILOS PREMIUM
// ------------------------------------------------------------------------

function estilizarCabecera(sheet) {
  var lastCol = sheet.getLastColumn();
  var range = sheet.getRange(1, 1, 1, lastCol);
  
  range.setFontWeight("bold")
       .setFontColor("#FFFFFF")
       .setBackground("#1D3557") // Azul profundo
       .setFontSize(10)
       .setFontFamily("Inter")
       .setHorizontalAlignment("center");
       
  sheet.setRowHeight(1, 26);
  sheet.setFrozenRows(1);
}

function estilizarUltimaFila(sheet, formatos) {
  var row = sheet.getLastRow();
  var cols = sheet.getLastColumn();
  
  sheet.setRowHeight(row, 20);
  
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
  
  // Autoajustar anchos
  for (var col = 1; col <= cols; col++) {
    sheet.autoResizeColumn(col);
    var currentWidth = sheet.getColumnWidth(col);
    sheet.setColumnWidth(col, Math.max(currentWidth + 15, 90)); // Un padding cómodo
  }
}

function formatsMapping(formatInput) {
  if (!formatInput) return { isNumberFormat: false, val: "left" };
  
  if (typeof formatInput === "string" && formatInput.indexOf("S/") !== -1) {
    return { isNumberFormat: true, val: formatInput };
  }
  
  // Mapear alineaciones
  var valString = "left";
  if (formatInput === "center") {
    valString = "center";
  } else if (formatInput === "right") {
    valString = "right";
  }
  
  return { isNumberFormat: false, val: valString };
}
