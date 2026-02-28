sealed class UiMessagePart {
  const UiMessagePart();
}

class UiTextPart extends UiMessagePart {
  final String text;

  const UiTextPart(this.text);

  UiTextPart copyWith({String? text}) => UiTextPart(text ?? this.text);
}

class UiReasoningPart extends UiMessagePart {
  final String text;

  const UiReasoningPart(this.text);

  UiReasoningPart copyWith({String? text}) => UiReasoningPart(text ?? this.text);
}

class UiImagePart extends UiMessagePart {
  final String url;
  final Map<String, dynamic> metadata;

  const UiImagePart({required this.url, this.metadata = const {}});

  UiImagePart copyWith({String? url, Map<String, dynamic>? metadata}) {
    return UiImagePart(
      url: url ?? this.url,
      metadata: metadata ?? this.metadata,
    );
  }
}

class UiAttachmentPart extends UiMessagePart {
  final String path;
  final String? mimeType;

  const UiAttachmentPart({required this.path, this.mimeType});

  UiAttachmentPart copyWith({String? path, Object? mimeType = _sentinel}) {
    return UiAttachmentPart(
      path: path ?? this.path,
      mimeType: mimeType == _sentinel ? this.mimeType : mimeType as String?,
    );
  }
}

class UiSearchRequestPart extends UiMessagePart {
  final String query;

  const UiSearchRequestPart(this.query);
}

class UiSkillRequestPart extends UiMessagePart {
  final String skillName;
  final String query;

  const UiSkillRequestPart({required this.skillName, required this.query});
}

const Object _sentinel = Object();
