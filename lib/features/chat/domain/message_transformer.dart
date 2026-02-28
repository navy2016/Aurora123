import 'ui_message.dart';

class MessageTransformContext {
  final String language;
  final String? model;
  final String providerName;

  const MessageTransformContext({
    required this.language,
    required this.model,
    required this.providerName,
  });
}

abstract class InputMessageTransformer {
  const InputMessageTransformer();

  Future<List<UiMessage>> transform(
      List<UiMessage> messages, MessageTransformContext context);
}

abstract class OutputMessageTransformer {
  const OutputMessageTransformer();

  UiMessage visualTransform(UiMessage message, MessageTransformContext context) {
    return message;
  }

  UiMessage onGenerationFinish(
      UiMessage message, MessageTransformContext context) {
    return message;
  }
}

class MessageTransformerPipeline {
  final List<InputMessageTransformer> input;
  final List<OutputMessageTransformer> output;

  const MessageTransformerPipeline({
    this.input = const [],
    this.output = const [],
  });

  Future<List<UiMessage>> transformInput(
    List<UiMessage> messages,
    MessageTransformContext context,
  ) async {
    var current = messages;
    for (final transformer in input) {
      current = await transformer.transform(current, context);
    }
    return current;
  }

  UiMessage visualTransform(
    UiMessage message,
    MessageTransformContext context,
  ) {
    var current = message;
    for (final transformer in output) {
      current = transformer.visualTransform(current, context);
    }
    return current;
  }

  UiMessage onGenerationFinish(
    UiMessage message,
    MessageTransformContext context,
  ) {
    var current = message;
    for (final transformer in output) {
      current = transformer.onGenerationFinish(current, context);
    }
    return current;
  }
}
