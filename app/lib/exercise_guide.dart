// Levlofit's own notes on the moves its sessions prescribe: muscle group, the main and assisting muscles by their
// anatomical names, and the other versions of the same movement that the plans use. Instructions, animations and
// equipment for every move still come from the catalogue (public.exercises).
//
// Rules for this file (workstream 13):
// - Muscle lists are general anatomy (prime movers and main assistants), written for a reviewer to confirm. They
//   are not exhaustive and not a claim about how much each muscle works.
// - Regions within a muscle (for example the upper and lower chest) are named in [muscleRegions] only where anatomy
//   defines them. No move is said to isolate a region: regions of a muscle work together, and changing an angle can
//   shift some emphasis without isolating anything. Move-specific emphasis claims need a source first and are not
//   shown in the app (see [needsSource]).
// - Ids whose move cannot be confirmed from local data are listed in [missingGuide], never guessed.
// - Mobility entries (yoga poses named in session.dart) list in [MoveGuide.main] the muscles the pose stretches,
//   shown as STRETCHES, not WORKS.

typedef MoveGuide = ({String name, String group, List<String> main, List<String> assist, String? equipment, List<String> versions});

/// Muscle groups in display order, with the anatomical regions shown under each.
const muscleRegions = <String, List<String>>{
  'Chest': ['Pectoralis major, clavicular head (upper chest)', 'Pectoralis major, sternocostal head (middle and lower chest)'],
  'Back': ['Latissimus dorsi', 'Trapezius (upper, middle and lower fibres)', 'Rhomboids', 'Erector spinae'],
  'Shoulders': ['Deltoid, anterior (front)', 'Deltoid, lateral (side)', 'Deltoid, posterior (rear)'],
  'Arms': ['Biceps brachii', 'Brachialis', 'Triceps brachii (long, lateral and medial heads)', 'Forearm flexors (grip)'],
  'Core': ['Rectus abdominis', 'Obliques', 'Transversus abdominis', 'Quadratus lumborum'],
  'Hips and glutes': ['Gluteus maximus', 'Gluteus medius', 'Hip flexors (iliopsoas)', 'Adductors'],
  'Thighs': ['Quadriceps', 'Hamstrings'],
  'Calves': ['Gastrocnemius', 'Soleus'],
  'Whole body': [],
  'Mobility': [],
};

const regionNote = 'Regions of one muscle work together. Changing the angle of a move can shift some of the work, '
    'but no exercise isolates one region.';

// Movement families: every move in a family is listed as another version of the others.
const _push = ['I4hDWkc', 'B1EVP9F', 'EIeI8Vf', 'SpYC0Kp'];
const _pullVertical = ['lBDjFxJ', 'RVwzP10'];
const _rowFamily = ['fUBheHs', 'BJ0Hz5L', 'bZGHsAZ', 'wd4ds3s'];
const _squatFamily = ['QChZi3x', 'yn8yg1r', 'qXTaZnJ'];
const _singleLeg = ['9E25EOx', 'RRWFUcw', 'IZVHb27', 'aXtJhlg'];
const _hinge = ['wQ2c4XD', 'rR0LJzx', 'ila4NZS'];
const _press = ['znQUdHY', 'A6wtbuL'];

List<String> _others(List<String> family, String id) => [for (final x in family) if (x != id) x];

const _pushMain = ['Pectoralis major', 'Deltoid, anterior', 'Triceps brachii'];
const _rowMain = ['Latissimus dorsi', 'Rhomboids', 'Trapezius, middle fibres', 'Deltoid, posterior'];
const _squatMain = ['Quadriceps', 'Gluteus maximus'];
const _legAssist = ['Adductors', 'Gluteus medius', 'Calves'];
const _hingeMain = ['Hamstrings', 'Gluteus maximus'];

/// Guide entries by catalogue id. [MoveGuide.equipment] is null where the catalogue row is the only record of it.
final moveGuide = <String, MoveGuide>{
  'I4hDWkc': (name: 'Push-up', group: 'Chest', main: _pushMain, assist: const ['Serratus anterior', 'Core'], equipment: 'No equipment', versions: _others(_push, 'I4hDWkc')),
  'B1EVP9F': (name: 'Incline push-up', group: 'Chest', main: _pushMain, assist: const ['Serratus anterior', 'Core'], equipment: 'A bench, table or wall', versions: _others(_push, 'B1EVP9F')),
  'EIeI8Vf': (name: 'Bench press', group: 'Chest', main: _pushMain, assist: const [], equipment: null, versions: _others(_push, 'EIeI8Vf')),
  'SpYC0Kp': (name: 'Dumbbell bench press', group: 'Chest', main: _pushMain, assist: const [], equipment: 'Dumbbells and a bench', versions: _others(_push, 'SpYC0Kp')),
  '9WTm7dq': (name: 'Dip', group: 'Chest', main: _pushMain, assist: const [], equipment: 'Dip bars', versions: const ['B1EVP9F']),
  'lBDjFxJ': (name: 'Pull-up', group: 'Back', main: const ['Latissimus dorsi'], assist: const ['Biceps brachii', 'Brachialis', 'Trapezius, lower fibres', 'Rhomboids'], equipment: 'Pull-up bar', versions: [..._others(_pullVertical, 'lBDjFxJ'), 'bZGHsAZ']),
  'RVwzP10': (name: 'Pulldown', group: 'Back', main: const ['Latissimus dorsi'], assist: const ['Biceps brachii', 'Brachialis', 'Trapezius, lower fibres', 'Rhomboids'], equipment: null, versions: _others(_pullVertical, 'RVwzP10')),
  'fUBheHs': (name: 'Seated row', group: 'Back', main: _rowMain, assist: const ['Biceps brachii'], equipment: null, versions: _others(_rowFamily, 'fUBheHs')),
  'BJ0Hz5L': (name: 'Dumbbell row', group: 'Back', main: _rowMain, assist: const ['Biceps brachii'], equipment: 'Dumbbells', versions: _others(_rowFamily, 'BJ0Hz5L')),
  'bZGHsAZ': (name: 'Inverted row', group: 'Back', main: _rowMain, assist: const ['Biceps brachii', 'Core'], equipment: 'A sturdy table or low bar', versions: [..._others(_rowFamily, 'bZGHsAZ'), 'lBDjFxJ']),
  'znQUdHY': (name: 'Shoulder press', group: 'Shoulders', main: const ['Deltoid, anterior', 'Deltoid, lateral', 'Triceps brachii'], assist: const ['Trapezius, upper fibres', 'Serratus anterior'], equipment: null, versions: _others(_press, 'znQUdHY')),
  'A6wtbuL': (name: 'Overhead press', group: 'Shoulders', main: const ['Deltoid, anterior', 'Deltoid, lateral', 'Triceps brachii'], assist: const ['Trapezius, upper fibres', 'Serratus anterior', 'Core'], equipment: null, versions: _others(_press, 'A6wtbuL')),
  'QChZi3x': (name: 'Squat', group: 'Thighs', main: _squatMain, assist: _legAssist, equipment: 'No equipment', versions: _others(_squatFamily, 'QChZi3x')),
  'yn8yg1r': (name: 'Goblet squat', group: 'Thighs', main: _squatMain, assist: const ['Adductors', 'Erector spinae', 'Core'], equipment: null, versions: _others(_squatFamily, 'yn8yg1r')),
  'qXTaZnJ': (name: 'Squat (loaded)', group: 'Thighs', main: _squatMain, assist: const ['Adductors', 'Erector spinae', 'Core'], equipment: null, versions: _others(_squatFamily, 'qXTaZnJ')),
  '9E25EOx': (name: 'Split squat', group: 'Thighs', main: _squatMain, assist: _legAssist, equipment: 'No equipment', versions: _others(_singleLeg, '9E25EOx')),
  'RRWFUcw': (name: 'Lunge', group: 'Thighs', main: _squatMain, assist: _legAssist, equipment: null, versions: _others(_singleLeg, 'RRWFUcw')),
  'IZVHb27': (name: 'Lunge', group: 'Thighs', main: _squatMain, assist: _legAssist, equipment: null, versions: _others(_singleLeg, 'IZVHb27')),
  'aXtJhlg': (name: 'Step-up', group: 'Thighs', main: _squatMain, assist: _legAssist, equipment: 'A step or sturdy box', versions: _others(_singleLeg, 'aXtJhlg')),
  'wQ2c4XD': (name: 'Romanian deadlift', group: 'Thighs', main: _hingeMain, assist: const ['Erector spinae', 'Adductors', 'Forearm flexors (grip)'], equipment: null, versions: _others(_hinge, 'wQ2c4XD')),
  'rR0LJzx': (name: 'Dumbbell Romanian deadlift', group: 'Thighs', main: _hingeMain, assist: const ['Erector spinae', 'Adductors', 'Forearm flexors (grip)'], equipment: 'Dumbbells', versions: _others(_hinge, 'rR0LJzx')),
  'ila4NZS': (name: 'Deadlift', group: 'Thighs', main: const ['Gluteus maximus', 'Hamstrings', 'Quadriceps'], assist: const ['Erector spinae', 'Adductors', 'Trapezius', 'Forearm flexors (grip)'], equipment: null, versions: _others(_hinge, 'ila4NZS')),
  'u0cNiij': (name: 'Glute bridge', group: 'Hips and glutes', main: const ['Gluteus maximus'], assist: const ['Hamstrings'], equipment: 'No equipment', versions: const []),
  'UHJlbu3': (name: 'Kettlebell swing', group: 'Hips and glutes', main: _hingeMain, assist: const ['Erector spinae', 'Core', 'Forearm flexors (grip)'], equipment: 'Kettlebell', versions: const []),
  'iny3m5y': (name: 'Dead bug', group: 'Core', main: const ['Rectus abdominis', 'Transversus abdominis'], assist: const ['Obliques'], equipment: 'No equipment', versions: const []),
  'RKjH6Lt': (name: 'Side bridge', group: 'Core', main: const ['Obliques', 'Quadratus lumborum'], assist: const ['Gluteus medius'], equipment: 'No equipment', versions: const []),
  'I3tsCnC': (name: 'Hanging leg raise', group: 'Core', main: const ['Rectus abdominis', 'Hip flexors (iliopsoas)'], assist: const ['Forearm flexors (grip)'], equipment: 'Pull-up bar', versions: const []), // catalogue: hanging leg raise (2026-10-17)
  'bJYHBIN': (name: 'Calf raise', group: 'Calves', main: const ['Gastrocnemius', 'Soleus'], assist: const [], equipment: null, versions: const []),
  'qPEzJjA': (name: 'Loaded carry', group: 'Whole body', main: const ['Forearm flexors (grip)', 'Trapezius', 'Core'], assist: const ['Quadratus lumborum', 'Obliques'], equipment: null, versions: const []),
  'LIlE5Tn': (name: 'Jump squat', group: 'Thighs', main: _squatMain, assist: const ['Calves'], equipment: 'No equipment', versions: const ['QChZi3x']),
  'dK9394r': (name: 'Burpee', group: 'Whole body', main: const [], assist: const [], equipment: 'No equipment', versions: const []),
  'RJgzwny': (name: 'Mountain climber', group: 'Whole body', main: const [], assist: const [], equipment: 'No equipment', versions: const []),
  'oLrKqDH': (name: 'Run', group: 'Whole body', main: const [], assist: const [], equipment: 'No equipment', versions: const []),
  // Yoga poses (names from session.dart): muscles stretched.
  'DIVyqrU': (name: 'Sphinx pose', group: 'Mobility', main: const ['Rectus abdominis'], assist: const [], equipment: 'A mat', versions: const ['01qpYSe']),
  '01qpYSe': (name: 'Upward-facing dog', group: 'Mobility', main: const ['Rectus abdominis', 'Hip flexors (iliopsoas)', 'Pectoralis major'], assist: const [], equipment: 'A mat', versions: const ['DIVyqrU']),
  'bWlZvXh': (name: 'Butterfly pose', group: 'Mobility', main: const ['Adductors'], assist: const [], equipment: 'A mat', versions: const ['HIgYKAB']),
  'HIgYKAB': (name: 'Seated wide-angle fold', group: 'Mobility', main: const ['Adductors', 'Hamstrings'], assist: const [], equipment: 'A mat', versions: const ['bWlZvXh']),
  'K5xgdvI': (name: 'Reclining big toe pose', group: 'Mobility', main: const ['Hamstrings', 'Gastrocnemius'], assist: const [], equipment: 'A strap or towel', versions: const []),
  '2jl9K55': (name: 'Seated twist', group: 'Mobility', main: const ['Obliques', 'Gluteus maximus'], assist: const [], equipment: 'A mat', versions: const ['6sYyrRX']),
  '6sYyrRX': (name: 'Reclining twist', group: 'Mobility', main: const ['Obliques', 'Gluteus maximus'], assist: const [], equipment: 'A mat', versions: const ['2jl9K55']),
  // Identified from the ExerciseDB V1 catalogue (oss.exercisedb.dev API, one lookup per id, 2026-10-16; its terms allow
  // non-commercial apps with credit). Muscles are the catalogue's target and secondary muscles in the names used here;
  // for stretches, the muscles stretched. Expert review pending, like every list in this file.
  '9RT8oQW': (name: 'Bench dip on the floor', group: 'Arms', main: const ['Triceps brachii'], assist: const ['Pectoralis major', 'Deltoid, anterior'], equipment: 'No equipment', versions: const ['9WTm7dq']),
  'wd4ds3s': (name: 'Bodyweight standing row', group: 'Back', main: const ['Rhomboids', 'Trapezius, middle fibres'], assist: const ['Biceps brachii', 'Deltoid, posterior'], equipment: 'Something fixed and sturdy to hold, such as a railing or a pole', versions: _others(_rowFamily, 'wd4ds3s')),
  'ealLwvX': (name: 'High knees against a wall', group: 'Whole body', main: const [], assist: const ['Quadriceps', 'Hamstrings', 'Gluteus maximus', 'Calves'], equipment: 'A wall', versions: const []),
  'DFGXwZr': (name: "World's greatest stretch", group: 'Mobility', main: const ['Hamstrings', 'Gluteus maximus', 'Quadriceps', 'Calves'], assist: const [], equipment: 'No equipment', versions: const []),
  '0mB6wHO': (name: "Runner's stretch", group: 'Mobility', main: const ['Hamstrings', 'Calves', 'Quadriceps'], assist: const [], equipment: 'No equipment', versions: const ['99rWm7w']),
  '99rWm7w': (name: 'Hamstring stretch', group: 'Mobility', main: const ['Hamstrings', 'Gluteus maximus'], assist: const [], equipment: 'No equipment', versions: const ['0mB6wHO']),
  'DeDThfG': (name: 'Seated glute stretch', group: 'Mobility', main: const ['Gluteus maximus', 'Hamstrings'], assist: const [], equipment: 'No equipment', versions: const []),
  'f38OEuO': (name: 'Kneeling lat stretch', group: 'Mobility', main: const ['Latissimus dorsi', 'Deltoid', 'Triceps brachii'], assist: const [], equipment: 'No equipment', versions: const []),
  'JbC2iaV': (name: 'Spine stretch', group: 'Mobility', main: const ['Erector spinae', 'Hamstrings', 'Gluteus maximus'], assist: const [], equipment: 'No equipment', versions: const []),
  // Named "Frog pose (Mandukasana)" in the app until 2026-10-16; the catalogue row is a rocking frog stretch. The
  // catalogue lists glutes, hamstrings and quadriceps; anatomy texts usually name the hip adductors for a frog stretch:
  // the expert review should settle this list.
  '2Dk4xQV': (name: 'Rocking frog stretch', group: 'Mobility', main: const ['Gluteus maximus', 'Hamstrings', 'Quadriceps'], assist: const [], equipment: 'A mat', versions: const []),
};

/// Prescribed ids with no confirmed identity. Empty since the catalogue lookup of 2026-10-16; a new prescribed id
/// goes here until it is looked up in the catalogue, never guessed.
const missingGuide = <String, String>{};

/// Move-specific emphasis claims kept out of the app until a source is recorded in the evidence register.
/// 2026-10-16: no open-access study found for this one (Europe PMC search); the other two were replaced below.
const needsSource = <String>[
  'Incline pressing shifts emphasis toward the clavicular head of pectoralis major.',
];

/// Evidence notes shown under a muscle group: what one study found, with its citation, in its own scope. Read in full
/// (open access, CC BY) on 2026-10-16; each replaces an earlier draft claim that went further than the study.
const evidenceNotes = <String, List<({String text, String source})>>{
  'Calves': [
    (
      text: 'Standing calf raises (knee straight) grew the gastrocnemius far more than seated calf raises (knee bent) over '
          '12 weeks in untrained adults; the soleus grew about the same either way.',
      source: 'Kinoshita M, Maeo S et al. Front Physiol 2023;14:1272106 (PMC10753835)',
    ),
  ],
  'Back': [
    (
      text: 'In 40 trained men, grip type and width in the lat pulldown did not change how hard the latissimus dorsi worked '
          '(muscle activity measured on the skin). Pick the grip that feels strongest and comfortable.',
      source: 'Buonsenso A et al. J Funct Morphol Kinesiol 2025;10(3):345 (PMC12452428)',
    ),
  ],
};

/// Guide moves in a muscle group, in the order the guide lists them, one per name.
List<(String id, MoveGuide g)> movesIn(String group) {
  final seen = <String>{};
  return [for (final e in moveGuide.entries) if (e.value.group == group && seen.add(e.value.name)) (e.key, e.value)];
}
