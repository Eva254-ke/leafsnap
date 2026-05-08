import 'package:flutter/material.dart';

enum PlantNetSupportLevel { direct, assisted, limited, unsupported }

enum CameraToolId {
  plantFinder,
  waterCalc,
  repotChecker,
  plantAdvisor,
  weedId,
  allergenId,
  toxicId,
  treeId,
  treeRingId,
  identify360,
  birdId,
  insectId,
}

class CameraToolDefinition {
  const CameraToolDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.supportLevel,
    required this.cameraTitle,
    required this.cameraHint,
    required this.helpText,
    required this.plantNetNote,
    required this.analysisSteps,
    this.isRunnable = true,
  });

  final CameraToolId id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final PlantNetSupportLevel supportLevel;
  final String cameraTitle;
  final String cameraHint;
  final String helpText;
  final String plantNetNote;
  final List<String> analysisSteps;
  final bool isRunnable;

  String get supportBadgeLabel {
    switch (supportLevel) {
      case PlantNetSupportLevel.direct:
        return 'Full support';
      case PlantNetSupportLevel.assisted:
        return 'Assisted';
      case PlantNetSupportLevel.limited:
        return 'Limited';
      case PlantNetSupportLevel.unsupported:
        return 'Unavailable';
    }
  }

  String get supportTitle {
    switch (supportLevel) {
      case PlantNetSupportLevel.direct:
        return 'This tool is fully supported.';
      case PlantNetSupportLevel.assisted:
        return 'This tool is assisted by reference data.';
      case PlantNetSupportLevel.limited:
        return 'This tool is partially supported.';
      case PlantNetSupportLevel.unsupported:
        return 'This tool is not supported yet.';
    }
  }

  Color get supportColor {
    switch (supportLevel) {
      case PlantNetSupportLevel.direct:
        return const Color(0xFF1E7A46);
      case PlantNetSupportLevel.assisted:
        return const Color(0xFF2E86C1);
      case PlantNetSupportLevel.limited:
        return const Color(0xFFF39C12);
      case PlantNetSupportLevel.unsupported:
        return const Color(0xFF8E44AD);
    }
  }

  Color get supportTint {
    switch (supportLevel) {
      case PlantNetSupportLevel.direct:
        return const Color(0xFFE7F6ED);
      case PlantNetSupportLevel.assisted:
        return const Color(0xFFE9F4FB);
      case PlantNetSupportLevel.limited:
        return const Color(0xFFFFF4E5);
      case PlantNetSupportLevel.unsupported:
        return const Color(0xFFF3EBFA);
    }
  }

  String get unavailableMessage {
    return 'This tool cannot run $title yet. Switch to Plant Finder or Tree ID for a live scan.';
  }
}

const List<CameraToolDefinition> quickToolDefinitions = <CameraToolDefinition>[
  CameraToolDefinition(
    id: CameraToolId.plantFinder,
    icon: Icons.eco_rounded,
    title: 'Plant Finder',
    subtitle: 'Identify any plant',
    accentColor: Color(0xFF1E7A46),
    supportLevel: PlantNetSupportLevel.direct,
    cameraTitle: 'Scan the plant',
    cameraHint: 'Center the clearest leaf, flower, fruit, or bark detail.',
    helpText:
        'This works best when the plant fills the frame and the photo is sharp.',
    plantNetNote: 'Species identification plus reference care data.',
    analysisSteps: <String>[
      'Detecting plant features',
      'Matching species',
      'Preparing results',
    ],
  ),
  CameraToolDefinition(
    id: CameraToolId.waterCalc,
    icon: Icons.opacity_rounded,
    title: 'Water Calc',
    subtitle: 'Perfect watering',
    accentColor: Color(0xFF2E86C1),
    supportLevel: PlantNetSupportLevel.assisted,
    cameraTitle: 'Scan for watering guidance',
    cameraHint: 'We first identify the plant, then pull its watering notes.',
    helpText:
        'We identify the plant first, then pull its watering notes from the care dataset.',
    plantNetNote:
        'We identify the species, then use watering guidance from our care dataset.',
    analysisSteps: <String>[
      'Identifying the plant',
      'Loading watering notes',
      'Preparing results',
    ],
  ),
  CameraToolDefinition(
    id: CameraToolId.repotChecker,
    icon: Icons.build_rounded,
    title: 'Repot Checker',
    subtitle: 'When to repot',
    accentColor: Color(0xFFF39C12),
    supportLevel: PlantNetSupportLevel.limited,
    cameraTitle: 'Scan before repot advice',
    cameraHint:
        'We can identify the plant now, but a real repot check needs pot and root context too.',
    helpText:
        'Repot timing also depends on root crowding, pot size, season, and growth rate.',
    plantNetNote:
        'Species ID is part of the flow, but repot advice needs additional context.',
    analysisSteps: <String>[
      'Identifying the plant',
      'Loading care context',
      'Preparing results',
    ],
  ),
  CameraToolDefinition(
    id: CameraToolId.plantAdvisor,
    icon: Icons.quiz_rounded,
    title: 'Plant Advisor',
    subtitle: 'Care tips',
    accentColor: Color(0xFF8E44AD),
    supportLevel: PlantNetSupportLevel.assisted,
    cameraTitle: 'Scan for care advice',
    cameraHint:
        'We identify the plant first, then surface the best care notes we have.',
    helpText: 'Care suggestions come from our reference care dataset.',
    plantNetNote:
        'We identify the species, then surface sunlight and watering guidance.',
    analysisSteps: <String>[
      'Identifying the plant',
      'Loading care notes',
      'Preparing results',
    ],
  ),
];

const List<CameraToolDefinition>
smartIdToolDefinitions = <CameraToolDefinition>[
  CameraToolDefinition(
    id: CameraToolId.weedId,
    icon: Icons.grass_rounded,
    title: 'Weed ID',
    subtitle: 'Control & prevent',
    accentColor: Color(0xFF22A45D),
    supportLevel: PlantNetSupportLevel.limited,
    cameraTitle: 'Scan the weed',
    cameraHint:
        'Get the likely plant species first, then decide if it is unwanted in your region.',
    helpText:
        'We can identify the plant, but whether it counts as a weed depends on local context.',
    plantNetNote:
        'We identify the species, but weed status and control guidance need further context.',
    analysisSteps: <String>[
      'Detecting plant features',
      'Matching species',
      'Preparing results',
    ],
  ),
  CameraToolDefinition(
    id: CameraToolId.allergenId,
    icon: Icons.spa_rounded,
    title: 'Allergen ID',
    subtitle: 'Identify & watch out',
    accentColor: Color(0xFFF4B400),
    supportLevel: PlantNetSupportLevel.limited,
    cameraTitle: 'Scan the plant',
    cameraHint:
        'We can identify the species, but allergen risk needs another dataset.',
    helpText:
        'Allergen risk requires a separate dataset beyond the plant species.',
    plantNetNote:
        'Plant species is identified, but allergen screening is separate.',
    analysisSteps: <String>[
      'Detecting plant features',
      'Matching species',
      'Preparing results',
    ],
  ),
  CameraToolDefinition(
    id: CameraToolId.toxicId,
    icon: Icons.warning_amber_rounded,
    title: 'Toxic ID',
    subtitle: 'Spot & stay safe',
    accentColor: Color(0xFFF06292),
    supportLevel: PlantNetSupportLevel.limited,
    cameraTitle: 'Scan the plant',
    cameraHint:
        'We can identify the species, but toxicity checks need safety metadata.',
    helpText:
        'Toxicity guidance requires a separate safety dataset and careful review.',
    plantNetNote:
        'The species is identified, but toxicity classification requires additional safety metadata.',
    analysisSteps: <String>[
      'Detecting plant features',
      'Matching species',
      'Preparing results',
    ],
  ),
  CameraToolDefinition(
    id: CameraToolId.treeId,
    icon: Icons.park_rounded,
    title: 'Tree ID',
    subtitle: 'Recognize & explore',
    accentColor: Color(0xFF22A45D),
    supportLevel: PlantNetSupportLevel.direct,
    cameraTitle: 'Scan the tree',
    cameraHint: 'Leaves are ideal, but bark and fruit can help too.',
    helpText:
        'Bark, leaf, flower, and fruit photos all help with tree identification.',
    plantNetNote: 'Tree scans work best when the subject fills the frame.',
    analysisSteps: <String>[
      'Detecting plant features',
      'Matching species',
      'Preparing results',
    ],
  ),
  CameraToolDefinition(
    id: CameraToolId.treeRingId,
    icon: Icons.album_rounded,
    title: 'Tree-ring ID',
    subtitle: 'Analyze growth',
    accentColor: Color(0xFFB08968),
    supportLevel: PlantNetSupportLevel.unsupported,
    cameraTitle: 'Tree-ring analysis is not available',
    cameraHint:
        'Trunk cross-sections and growth-ring analysis are not supported here.',
    helpText:
        'Tree-ring analysis is a different computer-vision problem from plant identification.',
    plantNetNote: 'Tree-ring analysis is outside the current tool scope.',
    analysisSteps: <String>[
      'Reviewing tool support',
      'Checking available scan modes',
      'Preparing guidance',
    ],
    isRunnable: false,
  ),
  CameraToolDefinition(
    id: CameraToolId.identify360,
    icon: Icons.threesixty_rounded,
    title: '360 ID',
    subtitle: 'Full-circle identify',
    accentColor: Color(0xFF26A69A),
    supportLevel: PlantNetSupportLevel.limited,
    cameraTitle: 'Start a multi-angle scan',
    cameraHint:
        'Multi-angle matching is useful, but this camera flow captures one photo at a time.',
    helpText:
        'This screen is wired for the tool now, but the capture UX is still single-photo.',
    plantNetNote:
        'Multi-image matching is not fully supported in the current capture flow.',
    analysisSteps: <String>[
      'Reviewing the photo',
      'Matching species',
      'Preparing results',
    ],
  ),
  CameraToolDefinition(
    id: CameraToolId.birdId,
    icon: Icons.filter_vintage_rounded,
    title: 'Bird ID',
    subtitle: 'Observe & learn',
    accentColor: Color(0xFFFF8A65),
    supportLevel: PlantNetSupportLevel.unsupported,
    cameraTitle: 'Bird ID is not available',
    cameraHint:
        'This app is focused on plant and plant-health identification rather than birds.',
    helpText:
        'Bird identification is outside the scope of this plant-focused workflow.',
    plantNetNote:
        'Bird classification is not supported by this plant-focused workflow.',
    analysisSteps: <String>[
      'Reviewing tool support',
      'Checking available scan modes',
      'Preparing guidance',
    ],
    isRunnable: false,
  ),
  CameraToolDefinition(
    id: CameraToolId.insectId,
    icon: Icons.bug_report_rounded,
    title: 'Insect ID',
    subtitle: 'Discover & classify',
    accentColor: Color(0xFF5C6BC0),
    supportLevel: PlantNetSupportLevel.limited,
    cameraTitle: 'Scan the pest or damage',
    cameraHint:
        'This works best for pests on a plant or visible plant damage, not general insect taxonomy.',
    helpText:
        'The model can suggest plant damage or pests when visible, but insect ID is not general taxonomy.',
    plantNetNote: 'This flow can suggest plant damage or pests from the photo.',
    analysisSteps: <String>[
      'Identifying the host plant',
      'Checking pest clues',
      'Preparing results',
    ],
  ),
];

const List<CameraToolDefinition> allCameraToolDefinitions =
    <CameraToolDefinition>[...quickToolDefinitions, ...smartIdToolDefinitions];

CameraToolDefinition cameraToolById(CameraToolId? id) {
  if (id == null) {
    return quickToolDefinitions.first;
  }

  for (final tool in allCameraToolDefinitions) {
    if (tool.id == id) {
      return tool;
    }
  }

  return quickToolDefinitions.first;
}
