import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitlore/services/architecture_codec.dart';

void main() {
  test('shared Worker fixture decodes and retains source relationships', () {
    final json = jsonDecode(
      File('backend/worker/test/fixtures/static-analysis.json')
          .readAsStringSync(),
    );
    final result = ArchitectureCodec.decode(json);
    expect(result.repository, 'team/orchard');
    expect(result.edges.single.from, 'src/index.js');
    expect(result.edges.single.to, 'src/service.js');
    expect(result.steps.length, result.nodes.length);
    expect(ArchitectureCodec.encode(result), json);
  });
}
