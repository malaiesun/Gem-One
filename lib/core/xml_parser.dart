import 'calculator.dart';
import 'medical_search_service.dart';
import 'scholar_tools.dart';

class ToolCall {
  final String tool;
  final Map<String, String> args;

  const ToolCall({
    required this.tool,
    required this.args,
  });

  String? get query => args['query'] ?? args['q'];
  String? get expr  => args['expr']  ?? args['expression'];

  @override
  String toString() => 'ToolCall($tool, $args)';
}

class ToolParser {
  static const String openTag  = '<gem_one_call>';
  static const String closeTag = '</gem_one_call>';

  // Holds back display of the last N chars so a partial <gem_one_call> prefix
  // never flashes to the user during streaming before we know it's a tool call.
  static int trailingPartialOpenLength(String text) {
    for (int n = openTag.length - 1; n > 0; n--) {
      if (text.length >= n &&
          text.substring(text.length - n) == openTag.substring(0, n)) {
        return n;
      }
    }
    return 0;
  }

  static int firstOpen(String text)  => text.indexOf(openTag);
  static int firstClose(String text) => text.indexOf(closeTag);

  static bool hasOpen(String text)         => firstOpen(text) >= 0;
  static bool hasCompleteCall(String text) {
    final o = firstOpen(text);
    final c = firstClose(text);
    return o >= 0 && c > o;
  }

  // Parse the FIRST complete <gem_one_call>...</gem_one_call> in [text].
  // Returns null if no complete call is present or it is malformed.
  static ToolCall? parse(String text) {
    final start = firstOpen(text);
    final end   = firstClose(text);
    if (start < 0 || end < 0 || end < start) return null;

    final inner = text.substring(start + openTag.length, end);

    final tool = _innerTag(inner, 'tool');
    if (tool == null || tool.isEmpty) return null;

    final args = <String, String>{};
    final re = RegExp(r'<(\w+)>([\s\S]*?)</\1>');
    for (final m in re.allMatches(inner)) {
      final tag = m.group(1)!;
      final val = m.group(2)!.trim();
      if (tag != 'tool') args[tag] = val;
    }

    return ToolCall(tool: tool.toLowerCase(), args: args);
  }

  static String? _innerTag(String src, String tag) {
    final re = RegExp('<$tag>([\\s\\S]*?)</$tag>');
    return re.firstMatch(src)?.group(1)?.trim();
  }

  // Strips complete tool-call blocks so they never reach the UI.
  // If the close tag is missing (streaming incomplete), drops from the open tag
  // to end-of-string rather than leaving a dangling prefix visible.
  static String stripCalls(String text) {
    var out = text;
    while (true) {
      final s = out.indexOf(openTag);
      if (s < 0) break;
      final e = out.indexOf(closeTag, s);
      if (e < 0) {
        out = out.substring(0, s);
        break;
      }
      out = out.substring(0, s) + out.substring(e + closeTag.length);
    }
    return out.trim();
  }

  // The trailing instruction prevents Gemma from entering an infinite agentic loop
  // by emitting a second tool call in response to the tool_response.
  static String formatResponse(String tool, String result) {
    final safe = result.replaceAll('</tool_response>', '');
    return '<tool_response>'
        '<tool>$tool</tool>'
        '<result>$safe</result>'
        '</tool_response>\n\n'
        'Using the tool_response above, give the final answer to the user. '
        'Do not emit another tool call.';
  }
}

class ToolDispatcher {
  static Future<String> execute(ToolCall call) async {
    switch (call.tool) {
      case 'medical_search':
        return _medicalSearch(call.query ?? '');
      case 'calculator':
      case 'calc':
        return _calculator(call.expr ?? '');
      case 'solve':
        return ScholarTools.solve(call.args['eq'] ?? call.args['equation'] ?? '');
      case 'factor':
        return ScholarTools.factor(call.args['n'] ?? call.args['input'] ?? '');
      case 'stats':
        return ScholarTools.stats(call.args['data'] ?? call.args['values'] ?? '');
      case 'convert':
        return ScholarTools.convert(call.args['expr'] ?? call.args['input'] ?? '');
      default:
        return 'Tool "${call.tool}" is not available on this device.';
    }
  }

  // Human-readable label shown in the chat bubble while the tool runs.
  static String label(String tool) {
    switch (tool.toLowerCase()) {
      case 'medical_search':
        return 'Searching medical knowledge';
      case 'calculator':
      case 'calc':
        return 'Calculating';
      case 'solve':
        return 'Solving equation';
      case 'factor':
        return 'Factoring';
      case 'stats':
        return 'Computing statistics';
      case 'convert':
        return 'Converting units';
      default:
        return 'Running tool: $tool';
    }
  }

  static String _medicalSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return 'No query provided.';
    final results = MedicalSearchService.instance.search(q);
    if (results.isEmpty) {
      return 'No matching entries found in the local medical knowledge base for "$q".';
    }
    return results.first;
  }

  static String _calculator(String expr) {
    final e = expr.trim();
    if (e.isEmpty) return 'No expression provided.';
    try {
      final v = Calculator.evaluate(e);
      // Display as integer when safe; above 1e15 doubles lose integer precision.
      if (v.isFinite &&
          v == v.truncateToDouble() &&
          v.abs() < 1e15) {
        return v.toInt().toString();
      }
      return v.toString();
    } on CalcException catch (e) {
      return 'Calculation error: $e';
    } catch (e) {
      return 'Calculation error: $e';
    }
  }
}
