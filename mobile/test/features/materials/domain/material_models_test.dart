import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_fixtures.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Material Models & Fixtures Tests (#284)', () {
    test('MaterialSummary serializa y deserializa JSON correctamente', () {
      final summary = MaterialFixtures.sampleSummary1;
      final json = summary.toJson();
      final fromJson = MaterialSummary.fromJson(json);

      expect(fromJson.id, summary.id);
      expect(fromJson.title, summary.title);
      expect(fromJson.authorName, summary.authorName);
      expect(fromJson.subjectName, summary.subjectName);
      expect(fromJson.downloadCount, 42);
      expect(fromJson.rating, 4.8);
    });

    test('MaterialDetail serializa y deserializa JSON correctamente', () {
      final detail = MaterialFixtures.sampleDetail1;
      final json = detail.toJson();
      final fromJson = MaterialDetail.fromJson(json);

      expect(fromJson.summary.id, detail.summary.id);
      expect(fromJson.downloadUrl, detail.downloadUrl);
      expect(fromJson.fileSizeBytes, detail.fileSizeBytes);
      expect(fromJson.tags, contains('Árboles'));
      expect(fromJson.viewCount, 156);
    });
  });
}
