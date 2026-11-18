class ManagedTypeMeta {
  const ManagedTypeMeta({
    required this.typeUri,
    required this.params,
  });

  final Uri typeUri;
  final List<ParameterMeta> params;

  String get className => typeUri.fragment;
}

class ParameterMeta {
  const ParameterMeta({
    required this.typeUri,
    required this.name,
    required this.managed,
    required this.required,
    required this.position,
    required this.positioned,
    required this.named,
    required this.optional,
  });

  final Uri typeUri;
  final String name;
  final bool managed;
  final bool required;
  final int position;
  final bool positioned;
  final bool named;
  final bool optional;

  String get className => typeUri.fragment;
}
