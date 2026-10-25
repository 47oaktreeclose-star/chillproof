import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models.dart';
import 'temperature.dart';
import 'widgets/common.dart';

enum SendOutcome { opened, sharedInstead, failed }

/// Builds the temperature log (PDF + plain text) and opens the email app
/// addressed to the registered business email.
class LogExporter {
  final BusinessProfile profile;
  final TempScale scale;
  final DateTime from;
  final DateTime to; // exclusive
  final List<CheckSession> sessions; // newest first, as loaded

  LogExporter({
    required this.profile,
    required this.scale,
    required this.from,
    required this.to,
    required this.sessions,
  });

  List<CheckSession> get _chrono => [...sessions]..sort((a, b) => a.takenAt.compareTo(b.takenAt));

  String get periodLabel {
    final last = to.subtract(const Duration(days: 1));
    return startOfDay(from) == startOfDay(last) ? fmtDate(from) : '${fmtDate(from)} – ${fmtDate(last)}';
  }

  String get subject => 'Temperature log – ${profile.businessName} – $periodLabel';

  /// Columns: one per unit that appears in the period (by id, latest name).
  List<({int id, String name, UnitType type})> get _columns {
    final map = <int, ({int id, String name, UnitType type})>{};
    for (final s in _chrono) {
      for (final r in s.readings) {
        map[r.unitId] = (id: r.unitId, name: r.unitName, type: r.unitType);
      }
    }
    final list = map.values.toList()
      ..sort((a, b) {
        if (a.type != b.type) return a.type == UnitType.fridge ? -1 : 1;
        return a.id.compareTo(b.id);
      });
    return list;
  }

  String plainText() {
    final b = StringBuffer()
      ..writeln('FRIDGE & FREEZER TEMPERATURE LOG')
      ..writeln()
      ..writeln('Business: ${profile.businessName}');
    if (profile.companyNumber.isNotEmpty) b.writeln('Company no: ${profile.companyNumber}');
    b
      ..writeln('Period: $periodLabel')
      ..writeln('Limits: fridges 8.0°C or below (aim for 5.0°C or below); freezers -18.0°C or colder')
      ..writeln();
    if (sessions.isEmpty) {
      b.writeln('No temperature checks were recorded in this period.');
    }
    for (final s in _chrono) {
      b.writeln('${fmtDateShort(s.takenAt)}  ${fmtTime(s.takenAt)}'
          '${s.checkedBy.isEmpty ? '' : '  (checked by ${s.checkedBy})'}');
      for (final r in s.readings) {
        final mark = switch (r.status) {
          TempStatus.ok => 'OK',
          TempStatus.warning => 'CHECK',
          TempStatus.critical => 'OUT OF RANGE',
        };
        b.writeln('   ${r.unitName}: ${formatTemp(r.tempC, scale)}  [$mark]'
            '${r.action.isEmpty ? '' : '  – Action: ${r.action}'}');
      }
      b.writeln();
    }
    b
      ..writeln('A PDF copy of this log is attached.')
      ..writeln()
      ..writeln('Sent from ChillProof – fridge & freezer temperature logs.');
    return b.toString();
  }

  Future<File> buildPdf() async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter_400Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter_700Bold.ttf'));
    final heading = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans_800ExtraBold.ttf'));
    final logo = pw.MemoryImage((await rootBundle.load('assets/images/logo.png')).buffer.asUint8List());

    const navy = PdfColor.fromInt(0xFF0B3D6E);
    const red = PdfColor.fromInt(0xFFDC2626);
    const amber = PdfColor.fromInt(0xFFB45309);
    const lightRed = PdfColor.fromInt(0xFFFDEBEB);
    const lightAmber = PdfColor.fromInt(0xFFFFF4DF);
    const line = PdfColor.fromInt(0xFFD5DEE8);

    final doc = pw.Document(
      title: subject,
      author: profile.businessName,
      creator: 'ChillProof',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    final cols = _columns;
    // Split wide logs into several tables so columns stay readable.
    const perTable = 8;
    final chunks = <List<({int id, String name, UnitType type})>>[];
    for (var i = 0; i < cols.length; i += perTable) {
      chunks.add(cols.sublist(i, i + perTable > cols.length ? cols.length : i + perTable));
    }
    if (chunks.isEmpty) chunks.add([]);

    pw.Widget cell(String text, {bool head = false, PdfColor? color, PdfColor? bg, bool alignLeft = false}) =>
        pw.Container(
          color: bg,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.center,
          child: pw.Text(text,
              textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: head ? 8.5 : 9,
                font: head ? bold : regular,
                color: head ? PdfColors.white : (color ?? PdfColors.black),
              )),
        );

    final legendStatus = 'Fridges: 8.0°C or below by law (England, Wales & NI); aim for 5.0°C or below. '
        'Freezers: -18.0°C or colder. ! = needs checking, !! = out of range. Temperatures in ${scale.symbol}.';

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
      header: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Image(logo, width: 34, height: 34),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(profile.businessName, style: pw.TextStyle(font: heading, fontSize: 16, color: navy)),
              pw.Text('Fridge & freezer temperature log  ·  $periodLabel',
                  style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            if (profile.companyNumber.isNotEmpty)
              pw.Text('Company no. ${profile.companyNumber}', style: const pw.TextStyle(fontSize: 8.5)),
            pw.Text(profile.phone, style: const pw.TextStyle(fontSize: 8.5)),
            pw.Text(profile.email, style: const pw.TextStyle(fontSize: 8.5)),
          ]),
        ]),
      ),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Generated by ChillProof on ${fmtDateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
      ]),
      build: (ctx) {
        final out = <pw.Widget>[
          pw.Text(legendStatus, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
        ];
        if (sessions.isEmpty) {
          out.add(pw.Padding(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Text('No temperature checks were recorded in this period.')));
          return out;
        }
        for (final chunk in chunks) {
          final header = <pw.Widget>[
            cell('Date', head: true),
            cell('Time', head: true),
            for (final c in chunk) cell('${c.name}\n(${c.type.label})', head: true),
            cell('Checked by', head: true),
          ];
          final rows = <pw.TableRow>[
            pw.TableRow(decoration: const pw.BoxDecoration(color: navy), children: header),
          ];
          for (final s in _chrono) {
            final byUnit = {for (final r in s.readings) r.unitId: r};
            rows.add(pw.TableRow(children: [
              cell(fmtDateShort(s.takenAt)),
              cell(fmtTime(s.takenAt)),
              for (final c in chunk)
                () {
                  final r = byUnit[c.id];
                  if (r == null) return cell('–', color: PdfColors.grey500);
                  final txt = formatTemp(r.tempC, scale, withSymbol: false);
                  return switch (r.status) {
                    TempStatus.ok => cell(txt),
                    TempStatus.warning => cell('$txt !', color: amber, bg: lightAmber),
                    TempStatus.critical => cell('$txt !!', color: red, bg: lightRed),
                  };
                }(),
              cell(s.checkedBy.isEmpty ? '' : s.checkedBy),
            ]));
          }
          out.add(pw.Table(
            border: pw.TableBorder.all(color: line, width: 0.6),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            columnWidths: {
              0: const pw.FixedColumnWidth(62),
              1: const pw.FixedColumnWidth(40),
              chunk.length + 2: const pw.FixedColumnWidth(70),
            },
            children: rows,
          ));
          out.add(pw.SizedBox(height: 14));
        }

        // Corrective actions table.
        final actions = <(CheckSession, Reading)>[
          for (final s in _chrono)
            for (final r in s.readings)
              if (r.status != TempStatus.ok) (s, r),
        ];
        if (actions.isNotEmpty) {
          out.add(pw.Text('Out-of-range readings and corrective actions',
              style: pw.TextStyle(font: heading, fontSize: 12, color: navy)));
          out.add(pw.SizedBox(height: 6));
          out.add(pw.Table(
            border: pw.TableBorder.all(color: line, width: 0.6),
            columnWidths: {
              0: const pw.FixedColumnWidth(92),
              1: const pw.FixedColumnWidth(120),
              2: const pw.FixedColumnWidth(60),
              3: const pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(color: navy), children: [
                cell('Date / time', head: true),
                cell('Unit', head: true),
                cell('Reading', head: true),
                cell('Action taken', head: true),
              ]),
              for (final (s, r) in actions)
                pw.TableRow(children: [
                  cell('${fmtDateShort(s.takenAt)} ${fmtTime(s.takenAt)}'),
                  cell(r.unitName, alignLeft: true),
                  cell(formatTemp(r.tempC, scale),
                      color: r.status == TempStatus.critical ? red : amber),
                  cell(r.action.isEmpty ? 'Not recorded' : r.action, alignLeft: true),
                ]),
            ],
          ));
        }
        return out;
      },
    ));

    final dir = await getTemporaryDirectory();
    final safeName = profile.businessName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final file = File('${dir.path}/ChillProof_${safeName}_${fmtDateShort(from).replaceAll('/', '-')}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  /// Opens the email app with the log addressed to the registered email.
  /// Falls back to the Android share sheet if no email app is set up.
  Future<SendOutcome> send() async {
    final pdf = await buildPdf();
    final body = plainText();
    try {
      await FlutterEmailSender.send(Email(
        subject: subject,
        recipients: [profile.email],
        body: body,
        attachmentPaths: [pdf.path],
      ));
      return SendOutcome.opened;
    } catch (_) {
      try {
        final ok = await Printing.sharePdf(
          bytes: await pdf.readAsBytes(),
          filename: pdf.uri.pathSegments.last,
          subject: subject,
          body: body,
          emails: [profile.email],
        );
        return ok ? SendOutcome.sharedInstead : SendOutcome.failed;
      } catch (_) {
        return SendOutcome.failed;
      }
    }
  }

  Future<void> preview() async {
    final pdf = await buildPdf();
    final bytes = await pdf.readAsBytes();
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: subject);
  }
}
