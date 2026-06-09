import 'package:flutter/material.dart';

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
    required this.cameraTitle,
    required this.cameraHint,
    required this.helpText,
    required this.plantNetNote,
    required this.analysisSteps,
    this.isRunnable = true,
    this.requiresPremium = false,
  });

  final CameraToolId id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String cameraTitle;
  final String cameraHint;
  final String helpText;
  final String plantNetNote;
  final List<String> analysisSteps;
  final bool isRunnable;
  final bool requiresPremium;

  String get accessBadgeLabel {
    return requiresPremium ? 'Premium' : 'Free';
  }

  Color get accessColor {
    return requiresPremium ? const Color(0xFF8E44AD) : const Color(0xFF1E7A46);
  }

  Color get accessTint {
    return requiresPremium ? const Color(0xFFF3EBFA) : const Color(0xFFE7F6ED);
  }

  String get unavailableMessage {
    return 'This tool cannot run $title yet. Switch to Plant Finder or Tree ID for a live scan.';
  }
}

const List<CameraToolDefinition> quickToolDefinitions = <CameraToolDefinition>[
  CameraToolDefinition(
    id: CameraToolId.plantFinder,
    icon: Icons.center_focus_strong_rounded,
    title: 'Plant Finder',
    subtitle: 'Identify any plant',
    accentColor: Color(0xFF1E7A46),
    cameraTitle: 'Scan the plant',
    cameraHint: 'Center the clearest leaf, flower, fruit, or bark detail.',
    helpText:
        'This works best when the plant fills the frame and the photo is sharp.',
    plantNetNote: 'We analyze the photo and prepare your results.',
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
    cameraTitle: 'Scan for watering guidance',
    cameraHint: 'We analyze the photo and surface watering guidance.',
    helpText: 'We analyze the photo and surface watering guidance.',
    plantNetNote: 'Watering guidance is based on the photo analysis.',
    analysisSteps: <String>[
      'Identifying the plant',
      'Loading watering notes',
      'Preparing results',
    ],
  ),
  CameraToolDefinition(
    id: CameraToolId.repotChecker,
    icon: Icons.build_rounded,
    title: 'Report Checker',
    subtitle: 'Premium report review',
    accentColor: Color(0xFFF39C12),
    cameraTitle: 'Scan before report review',
    cameraHint:
      'Premium review uses a full plant scan plus care context.',
    helpText:
        'Premium report review helps interpret the scan with extra care context.',
    plantNetNote: 'Report review uses the strongest details available from the scan.',
    analysisSteps: <String>[
      'Identifying the plant',
      'Loading care context',
      'Preparing results',
    ],
    requiresPremium: true,
  ),
  CameraToolDefinition(
    id: CameraToolId.plantAdvisor,
    icon: Icons.quiz_rounded,
    title: 'Plant Advisor',
    subtitle: 'Care tips',
    accentColor: Color(0xFF8E44AD),
    cameraTitle: 'Scan for care advice',
    cameraHint: 'We analyze the photo and surface care tips.',
    helpText: 'Care tips are generated from the photo analysis.',
    plantNetNote: 'Care tips are based on what we see in the photo.',
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
    cameraTitle: 'Scan the weed',
    cameraHint: 'Check the photo, then decide if it is unwanted in your region.',
    helpText: 'We can scan the photo, but weed status depends on local context.',
    plantNetNote: 'Weed guidance needs local context beyond the photo.',
    analysisSteps: <String>[
      'Detecting plant features',
      'Matching species',
      'Preparing results',
    ],
    requiresPremium: true,
  ),
  CameraToolDefinition(
    id: CameraToolId.allergenId,
    icon: Icons.spa_rounded,
    title: 'Allergen ID',
    subtitle: 'Identify & watch out',
    accentColor: Color(0xFFF4B400),
    cameraTitle: 'Scan the plant',
    cameraHint: 'We can scan the photo, but allergen risk needs more context.',
    helpText: 'Allergen risk needs more context than a single photo.',
    plantNetNote: 'Allergen screening is separate from the photo match.',
    analysisSteps: <String>[
      'Detecting plant features',
      'Matching species',
      'Preparing results',
    ],
    requiresPremium: true,
  ),
  CameraToolDefinition(
    id: CameraToolId.toxicId,
    icon: Icons.warning_amber_rounded,
    title: 'Toxic ID',
    subtitle: 'Spot & stay safe',
    accentColor: Color(0xFFF06292),
    cameraTitle: 'Scan the plant',
    cameraHint: 'We can scan the photo, but toxicity checks need more context.',
    helpText: 'Toxicity guidance needs more context and careful review.',
    plantNetNote: 'Toxicity checks are separate from the photo match.',
    analysisSteps: <String>[
      'Detecting plant features',
      'Matching species',
      'Preparing results',
    ],
    requiresPremium: true,
  ),
  CameraToolDefinition(
    id: CameraToolId.treeId,
    icon: Icons.park_rounded,
    title: 'Tree ID',
    subtitle: 'Recognize & explore',
    accentColor: Color(0xFF22A45D),
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
    requiresPremium: true,
  ),
  CameraToolDefinition(
    id: CameraToolId.treeRingId,
    icon: Icons.album_rounded,
    title: 'Tree-ring ID',
    subtitle: 'Analyze growth',
    accentColor: Color(0xFFB08968),
    cameraTitle: 'Tree-ring analysis is not available',
    cameraHint:
        'Trunk cross-sections and growth-ring analysis are not supported here.',
    helpText: 'Tree-ring analysis is a different computer-vision problem.',
    plantNetNote: 'Tree-ring analysis is outside the current tool scope.',
    analysisSteps: <String>[
      'Reviewing tool support',
      'Checking available scan modes',
      'Preparing guidance',
    ],
    isRunnable: false,
    requiresPremium: true,
  ),
  CameraToolDefinition(
    id: CameraToolId.identify360,
    icon: Icons.threesixty_rounded,
    title: '360 ID',
    subtitle: 'Full-circle identify',
    accentColor: Color(0xFF26A69A),
    cameraTitle: 'Start a multi-angle scan',
    cameraHint:
        'Multi-angle matching is useful, but this camera flow captures one photo at a time.',
    helpText:
        'This screen is wired for the tool now, but the capture UX is still single-photo.',
    plantNetNote: 'Multi-image matching is not supported in the current capture flow.',
    analysisSteps: <String>[
      'Reviewing the photo',
      'Matching species',
      'Preparing results',
    ],
    requiresPremium: true,
  ),
  CameraToolDefinition(
    id: CameraToolId.birdId,
    icon: Icons.filter_vintage_rounded,
    title: 'Bird ID',
    subtitle: 'Observe & learn',
    accentColor: Color(0xFFFF8A65),
    cameraTitle: 'Bird ID is not available',
    cameraHint: 'This app is focused on plant identification rather than birds.',
    helpText: 'Bird identification is outside the scope of this workflow.',
    plantNetNote: 'Bird classification is not supported in this workflow.',
    analysisSteps: <String>[
      'Reviewing tool support',
      'Checking available scan modes',
      'Preparing guidance',
    ],
    isRunnable: false,
    requiresPremium: true,
  ),
  CameraToolDefinition(
    id: CameraToolId.insectId,
    icon: Icons.bug_report_rounded,
    title: 'Insect ID',
    subtitle: 'Discover & classify',
    accentColor: Color(0xFF5C6BC0),
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
    requiresPremium: true,
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
