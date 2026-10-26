import 'dart:convert';
import 'dart:io';
import '../config/api_config.dart';
import '../models/line_item.dart';
import 'ocr_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Gemini Service
///
/// Uses Google's Gemini Flash Multimodal API to accurately recognize and
/// parse handwritten and printed procurement documents in English, Sinhala,
/// and Tamil.
/// ─────────────────────────────────────────────────────────────────────────────
class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  /// Recognises and extracts structured line items from a single [imageFile]
  Future<OcrResult> recognise(File imageFile) async {
    return recogniseAll([imageFile]);
  }

  /// Recognises and extracts structured line items across multiple [imageFiles] (consecutive pages)
  Future<OcrResult> recogniseAll(List<File> imageFiles) async {
    if (ApiConfig.geminiApiKey.isEmpty) {
      throw Exception(
        'Gemini API key is missing. Please run with: '
        '--dart-define=GEMINI_API_KEY=your_api_key',
      );
    }

    if (imageFiles.isEmpty) {
      throw ArgumentError('At least one image file is required for recognition.');
    }

    final base64Images = <String>[];
    for (final imageFile in imageFiles) {
      final imageBytes = await imageFile.readAsBytes();
      base64Images.add(base64Encode(imageBytes));
    }

    final models = [
      ApiConfig.geminiModel,
      'gemini-3.6-flash',
      ApiConfig.fallbackModel,
      'gemini-3.5-flash',
    ];

    Object? lastError;
    for (final model in models) {
      try {
        return await _callGeminiApi(base64Images, model);
      } catch (e) {
        lastError = e;
        final err = e.toString().toLowerCase();
        if (err.contains('503') ||
            err.contains('unavailable') ||
            err.contains('429') ||
            err.contains('404') ||
            err.contains('not found')) {
          continue;
        }
        rethrow;
      }
    }
    throw lastError ??
        Exception('All Gemini models are temporarily busy. Please try again.');
  }

  Future<OcrResult> _callGeminiApi(List<String> base64Images, String model) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 25);

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=${ApiConfig.geminiApiKey}',
    );

    final parts = <Map<String, dynamic>>[
      {
        'text': '''
You are an expert procurement and receipt document scanner.
Your task is to transcribe and extract line items, prices, VAT details, and totals from bills, handwritten invoices, and receipts written in English, Sinhala, or Tamil.

Instructions:
1. If multiple images are provided, they represent consecutive pages (Page 1, Page 2, etc.) of the same document or multi-page invoice. Transcribe all line items across all pages in chronological order.
2. Support various document formats, table layouts, column orders, and templates. Identify values by column headers and document context rather than assuming fixed positions.
3. Distinguish Unit Price (cost per individual item) from Item Total / Amount (line total for quantity × price).
4. Accurately transcribe line items (support Sinhala, Tamil, and English handwriting and print).
5. For each line item:
   - "description": name of the item or service (preserve Sinhala / Tamil / English characters).
   - "quantity": quantity (e.g. "1", "2.5"). If none written, use "1".
   - "unit_price": unit price as written in the document (e.g. "150.00").
   - "unit_price_excl_vat": unit price excluding VAT if explicitly indicated by columns/notes, or null.
   - "unit_price_incl_vat": unit price including VAT if explicitly indicated by columns/notes, or null.
   - "vat_rate": VAT rate explicitly stated for this item or document (e.g. "18%", "0%"), or null.
   - "vat_amount": VAT amount for this line item if written, or null.
   - "price_vat_status": "inclusive", "exclusive", or "unspecified" based on headings (e.g. "Inc. VAT", "Excl. VAT").
   - "amount": line total amount as written on the receipt (e.g. "300.00").
   - "confidence": confidence score from 0.0 to 1.0 (e.g. 0.95). If handwriting or meaning is ambiguous, lower the confidence (< 0.8) and add a note to warnings.
6. Document-level context:
   - "written_subtotal": subtotal amount before VAT if present, or null.
   - "written_vat_total": total VAT amount printed on document, or null.
   - "written_total": the grand total or final amount written on the document, or null if not present.
   - "document_vat_rate": global VAT rate mentioned on document (e.g. "18%"), or null.
   - "document_price_status": "inclusive", "exclusive", or "unspecified" for the overall document.
   - "raw_text": full text transcription of all text detected across all document pages.
   - "warnings": list of notes if any handwriting is unreadable, ambiguous, or if VAT inclusion is unclear.

Respond ONLY with valid JSON in this exact structure without markdown code fences:
{
  "items": [
    {
      "description": "Item description",
      "quantity": "2",
      "unit_price": "150.00",
      "unit_price_excl_vat": null,
      "unit_price_incl_vat": null,
      "vat_rate": "18%",
      "vat_amount": null,
      "price_vat_status": "unspecified",
      "amount": "300.00",
      "confidence": 0.95
    }
  ],
  "written_subtotal": null,
  "written_vat_total": null,
  "written_total": "300.00",
  "document_vat_rate": "18%",
  "document_price_status": "unspecified",
  "raw_text": "transcription",
  "warnings": []
}
''',
      },
      ...base64Images.map(
        (b64) => {
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': b64,
          },
        },
      ),
    ];

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': parts,
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'responseMimeType': 'application/json',
      },
    });

    try {
      final request = await client.postUrl(url);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('x-goog-api-key', ApiConfig.geminiApiKey);
      request.add(utf8.encode(requestBody));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        final errorMsg = _extractErrorMessage(responseBody, response.statusCode);
        throw Exception(errorMsg);
      }

      final jsonResponse = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = jsonResponse['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Gemini returned an empty response.');
      }

      final candidate = candidates.first as Map<String, dynamic>;
      final content = candidate['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw Exception('No content parts found in Gemini response.');
      }

      final text = parts.first['text'] as String? ?? '';
      return _parseGeminiResult(text);
    } finally {
      client.close();
    }
  }

  OcrResult _parseGeminiResult(String rawJson) {
    // Clean up potential markdown formatting (```json ... ```)
    var cleaned = rawJson.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    Map<String, dynamic> data;
    try {
      data = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      // In case Gemini returned raw text
      return OcrResult(
        rawText: rawJson,
        lineItems: [],
        warnings: ['Could not parse structured items from document.'],
        writtenTotal: null,
      );
    }

    final rawItems = data['items'] as List<dynamic>? ?? [];
    final items = <LineItem>[];

    for (final rawItem in rawItems) {
      if (rawItem is Map<String, dynamic>) {
        final desc = rawItem['description']?.toString() ?? 'Item';
        final qty = rawItem['quantity']?.toString() ?? '1';
        final unitPrice = rawItem['unit_price']?.toString() ?? '0.00';
        final amount = rawItem['amount']?.toString() ?? '0.00';
        final conf = (rawItem['confidence'] as num?)?.toDouble() ?? 0.95;

        PriceVatStatus itemPriceStatus = PriceVatStatus.unspecified;
        final pStatusStr = rawItem['price_vat_status']?.toString().toLowerCase();
        if (pStatusStr == 'inclusive') {
          itemPriceStatus = PriceVatStatus.inclusive;
        } else if (pStatusStr == 'exclusive') {
          itemPriceStatus = PriceVatStatus.exclusive;
        }

        items.add(LineItem(
          description: desc,
          rawQuantity: qty,
          rawUnitPrice: unitPrice,
          rawAmount: amount,
          rawUnitPriceExclVat: rawItem['unit_price_excl_vat']?.toString(),
          rawUnitPriceInclVat: rawItem['unit_price_incl_vat']?.toString(),
          rawVatRate: rawItem['vat_rate']?.toString(),
          rawVatAmount: rawItem['vat_amount']?.toString(),
          priceVatStatus: itemPriceStatus,
          confidence: conf,
        ));
      }
    }

    final warningsList = <String>[];
    if (data['warnings'] is List) {
      for (final w in data['warnings'] as List) {
        if (w != null) warningsList.add(w.toString());
      }
    }

    final fullText = data['raw_text']?.toString() ?? '';
    final writtenTotal = data['written_total']?.toString();
    final writtenSubtotal = data['written_subtotal']?.toString();
    final writtenVatTotal = data['written_vat_total']?.toString();
    final documentVatRate = data['document_vat_rate']?.toString();

    final docStatusStr = data['document_price_status']?.toString().toLowerCase();
    PriceVatStatus docPriceStatus = PriceVatStatus.unspecified;
    if (docStatusStr == 'inclusive') {
      docPriceStatus = PriceVatStatus.inclusive;
    } else if (docStatusStr == 'exclusive') {
      docPriceStatus = PriceVatStatus.exclusive;
    }

    return OcrResult(
      rawText: fullText,
      lineItems: items,
      warnings: warningsList,
      writtenTotal: writtenTotal,
      writtenSubtotal: writtenSubtotal,
      writtenVatTotal: writtenVatTotal,
      documentVatRate: documentVatRate,
      documentPriceStatus: docPriceStatus,
    );
  }

  String _extractErrorMessage(String body, int statusCode) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      if (error != null) {
        final msg = error['message']?.toString() ?? '';
        final status = error['status']?.toString() ?? '';
        if (statusCode == 401 || status == 'UNAUTHENTICATED') {
          return 'Gemini API authentication failed (401). Please verify your API key in lib/config/api_config.dart. Details: $msg';
        }
        return 'Gemini API error ($statusCode $status): $msg';
      }
    } catch (_) {}
    return 'Gemini API request failed with status $statusCode: $body';
  }
}
