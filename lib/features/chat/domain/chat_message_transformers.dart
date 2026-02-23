import 'message_transformer.dart';
import 'transformers/protocol_tag_transformer.dart';

const MessageTransformerPipeline chatMessageTransformers =
    MessageTransformerPipeline(output: [ProtocolTagTransformer()]);
