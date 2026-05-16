import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../widgets/animated_background.dart';

class ReferenceScreen extends StatefulWidget {
  const ReferenceScreen({super.key});

  @override
  State<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: GemColors.referenceColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: GemColors.referenceColor.withValues(alpha: 0.35),
                    width: 0.8),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  size: 15, color: GemColors.referenceColor),
            ),
            const SizedBox(width: 10),
            const Text('Reference Guides',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ]),
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: GemColors.referenceColor,
            indicatorWeight: 2,
            labelColor: GemColors.referenceColor,
            unselectedLabelColor: GemColors.textSecondary,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(text: 'First Aid'),
              Tab(text: 'Maths'),
              Tab(text: 'Measures'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: const [
            _FirstAidTab(),
            _MathsTab(),
            _MeasuresTab(),
          ],
        ),
      ),
    );
  }
}

// FIRST AID TAB

class _FirstAidTab extends StatelessWidget {
  const _FirstAidTab();

  static const _items = [
    _FAItem(
      title: 'CPR (Adult)',
      icon: Icons.favorite_outlined,
      color: GemColors.danger,
      steps: [
        'Check the scene is safe and the person is unresponsive.',
        'Call emergency services (or ask someone else to call).',
        'Place heel of hand on centre of chest; interlock fingers.',
        'Push hard and fast - 30 compressions at 100-120/min.',
        'Tilt head back, lift chin. Give 2 rescue breaths (if trained).',
        'Repeat 30:2 cycle until help arrives or person recovers.',
        'Use an AED as soon as one is available.',
      ],
    ),
    _FAItem(
      title: 'Choking (Adult)',
      icon: Icons.air,
      color: GemColors.warning,
      steps: [
        'Ask "Are you choking?" - if they cannot speak, act immediately.',
        'Lean them forward. Give up to 5 firm back blows between shoulder blades.',
        'Check mouth after each blow. Remove any visible object.',
        'If back blows fail: stand behind, make fist just above navel.',
        'Give up to 5 sharp upward abdominal thrusts (Heimlich).',
        'Alternate 5 back blows and 5 abdominal thrusts until cleared.',
        'Call emergency services if object does not clear.',
      ],
    ),
    _FAItem(
      title: 'Severe Bleeding',
      icon: Icons.water_drop_outlined,
      color: Color(0xFFFF8C42),
      steps: [
        'Put on gloves or use a clean cloth as a barrier.',
        'Apply firm, direct pressure over the wound.',
        'Do NOT lift the dressing - add more on top if blood soaks through.',
        'Elevate the limb above heart level if possible.',
        'For a limb bleed that won\'t stop: apply tourniquet 5-8 cm above wound.',
        'Note the time the tourniquet was applied.',
        'Seek emergency care immediately.',
      ],
    ),
    _FAItem(
      title: 'Burns',
      icon: Icons.local_fire_department_outlined,
      color: Color(0xFFFF7043),
      steps: [
        'Cool the burn under cool running water for 20 minutes.',
        'Do NOT use ice, butter, toothpaste, or any cream.',
        'Remove jewellery - NOT clothing stuck to the skin.',
        'Cover loosely with cling film or a clean non-fluffy cloth.',
        'Do NOT burst blisters.',
        'Give paracetamol or ibuprofen for pain if available.',
        'Seek care for burns > size of a palm, or on face/hands/genitals.',
      ],
    ),
    _FAItem(
      title: 'Snake Bite',
      icon: Icons.warning_amber_rounded,
      color: GemColors.success,
      steps: [
        'Move away from the snake - do NOT try to catch or kill it.',
        'Keep the person calm and still - movement spreads venom.',
        'Remove rings, watches, or tight clothing near the bite.',
        'Keep bitten limb below the level of the heart.',
        'Do NOT cut the wound, suck out venom, or apply a tourniquet.',
        'Do NOT apply ice.',
        'Get to the nearest hospital with anti-venom as fast as possible.',
      ],
    ),
    _FAItem(
      title: 'Fractures',
      icon: Icons.accessibility_new_rounded,
      color: GemColors.iceBlue,
      steps: [
        'Do NOT try to straighten the broken bone.',
        'Immobilise in the position found - use a splint if available.',
        'Pad around the injury with soft material for comfort.',
        'For an open fracture (bone through skin): cover with clean cloth only.',
        'Treat for shock: keep warm, calm, and lying down.',
        'Do NOT give food or water (surgery may be needed).',
        'Seek emergency care.',
      ],
    ),
    _FAItem(
      title: 'Heat Stroke',
      icon: Icons.thermostat_rounded,
      color: Color(0xFFFFD93D),
      steps: [
        'Move to a cool, shaded place immediately.',
        'Remove excess clothing.',
        'Cool rapidly: wet skin, fan, apply ice packs to neck/armpits/groin.',
        'Give cool water to drink if conscious and able to swallow.',
        'Do NOT give paracetamol or aspirin - they won\'t help heat stroke.',
        'If confused, unconscious, or fitting - call emergency services.',
        'Continue cooling until temperature drops or help arrives.',
      ],
    ),
    _FAItem(
      title: 'Fever & Dehydration',
      icon: Icons.thermostat_outlined,
      color: GemColors.medicColor,
      steps: [
        'Keep person in a cool, ventilated room.',
        'Give plenty of fluids: water, ORS, or diluted juice.',
        'Paracetamol (age-appropriate dose) reduces fever safely.',
        'Do NOT give aspirin to children under 16.',
        'Sponge with lukewarm (not cold) water if temperature is very high.',
        'ORS recipe: 1 litre water + 6 tsp sugar + 0.5 tsp salt.',
        'Seek care if fever >39°C for >3 days, rash, stiff neck, or drowsiness.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _FACard(item: _items[i]),
    );
  }
}

class _FAItem {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> steps;
  const _FAItem(
      {required this.title,
      required this.icon,
      required this.color,
      required this.steps});
}

class _FACard extends StatefulWidget {
  final _FAItem item;
  const _FACard({required this.item});

  @override
  State<_FACard> createState() => _FACardState();
}

class _FACardState extends State<_FACard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Container(
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: item.color.withValues(alpha: 0.25), width: 0.8),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 20, color: item.color),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(item.title,
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white))),
              Icon(
                _open
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: item.color.withValues(alpha: 0.7),
              ),
            ]),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: item.steps.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22, height: 22,
                          margin: const EdgeInsets.only(right: 10, top: 1),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text('${e.key + 1}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: item.color))),
                        ),
                        Expanded(child: Text(e.value,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Colors.white.withValues(alpha: 0.82)))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ]),
      ),
    );
  }
}

// BASIC MATHS TAB

class _MathsTab extends StatelessWidget {
  const _MathsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _MathSection(
          title: 'Multiplication Table (1-10)',
          icon: Icons.grid_on_rounded,
          color: GemColors.scholarColor,
          child: _MultiplicationTable(),
        ),
        SizedBox(height: 12),
        _MathSection(
          title: 'Area & Perimeter',
          icon: Icons.crop_square_rounded,
          color: Color(0xFF74B9FF),
          child: _FormulasCard(formulas: [
            ('Rectangle area',    'A = length × width'),
            ('Rectangle perim.', 'P = 2 × (length + width)'),
            ('Circle area',      'A = π × r²'),
            ('Circle circumf.',  'C = 2 × π × r'),
            ('Triangle area',    'A = ½ × base × height'),
            ('Square area',      'A = side²'),
          ]),
        ),
        SizedBox(height: 12),
        _MathSection(
          title: 'Volume',
          icon: Icons.view_in_ar_rounded,
          color: Color(0xFF6BFFB8),
          child: _FormulasCard(formulas: [
            ('Cube',          'V = side³'),
            ('Cuboid',        'V = l × w × h'),
            ('Cylinder',      'V = π × r² × h'),
            ('Sphere',        'V = 4/3 × π × r³'),
            ('Cone',          'V = 1/3 × π × r² × h'),
          ]),
        ),
        SizedBox(height: 12),
        _MathSection(
          title: 'Fractions & Percentages',
          icon: Icons.percent_rounded,
          color: Color(0xFFFFD93D),
          child: _FormulasCard(formulas: [
            ('% of a number',  'x% of N = (x ÷ 100) × N'),
            ('% change',       '((new − old) ÷ old) × 100'),
            ('Fraction → %',   '(a ÷ b) × 100'),
            ('Simple interest','I = P × R × T ÷ 100'),
          ]),
        ),
        SizedBox(height: 12),
        _MathSection(
          title: 'Common Shortcuts',
          icon: Icons.flash_on_rounded,
          color: GemColors.warning,
          child: _FormulasCard(formulas: [
            ('Sum 1 to n',   'n × (n + 1) ÷ 2'),
            ('Pythagoras',   'a² + b² = c²'),
            ('Speed',        'Speed = Distance ÷ Time'),
            ('Distance',     'Distance = Speed × Time'),
            ('Time',         'Time = Distance ÷ Speed'),
            ('Power',        'P = V × I  (watts)'),
          ]),
        ),
      ],
    );
  }
}

class _MathSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;
  const _MathSection(
      {required this.title,
      required this.icon,
      required this.color,
      required this.child});

  @override
  State<_MathSection> createState() => _MathSectionState();
}

class _MathSectionState extends State<_MathSection> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: widget.color.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(widget.icon, size: 17, color: widget.color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.title,
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white))),
              Icon(
                _open
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: widget.color.withValues(alpha: 0.6),
              ),
            ]),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: widget.child,
          ),
      ]),
    );
  }
}

class _MultiplicationTable extends StatelessWidget {
  const _MultiplicationTable();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(36),
        children: [
          TableRow(children: [
            _th('×'),
            for (var c = 1; c <= 10; c++) _th('$c'),
          ]),
          for (var r = 1; r <= 10; r++)
            TableRow(children: [
              _th('$r'),
              for (var c = 1; c <= 10; c++) _td('${r * c}'),
            ]),
        ],
      ),
    );
  }

  Widget _th(String t) => Container(
        height: 30,
        alignment: Alignment.center,
        color: GemColors.scholarColor.withValues(alpha: 0.15),
        child: Text(t,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: GemColors.scholarColor)),
      );

  Widget _td(String t) => Container(
        height: 30,
        alignment: Alignment.center,
        child: Text(t,
            style: TextStyle(
                fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
      );
}

class _FormulasCard extends StatelessWidget {
  final List<(String, String)> formulas;
  const _FormulasCard({required this.formulas});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: formulas.map((f) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(
                flex: 4,
                child: Text(f.$1,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.6)))),
            Expanded(
                flex: 5,
                child: Text(f.$2,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'monospace'))),
          ]),
        );
      }).toList(),
    );
  }
}

// MEASURES TAB

class _MeasuresTab extends StatelessWidget {
  const _MeasuresTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _MeasureCard(
          title: 'Length',
          icon: Icons.straighten_rounded,
          color: GemColors.iceBlue,
          rows: [
            ('1 km',    '= 1,000 m   = 0.621 miles'),
            ('1 mile',  '= 1.609 km  = 1,760 yards'),
            ('1 m',     '= 100 cm    = 3.281 feet'),
            ('1 foot',  '= 30.48 cm  = 12 inches'),
            ('1 inch',  '= 2.54 cm'),
          ],
        ),
        SizedBox(height: 12),
        _MeasureCard(
          title: 'Weight / Mass',
          icon: Icons.scale_rounded,
          color: GemColors.warning,
          rows: [
            ('1 tonne',  '= 1,000 kg  = 2,205 lbs'),
            ('1 kg',     '= 1,000 g   = 2.205 lbs'),
            ('1 lb',     '= 453.6 g   = 16 oz'),
            ('1 oz',     '= 28.35 g'),
          ],
        ),
        SizedBox(height: 12),
        _MeasureCard(
          title: 'Volume / Liquid',
          icon: Icons.water_outlined,
          color: Color(0xFF6BCFFF),
          rows: [
            ('1 litre',    '= 1,000 mL  = 1.76 pints'),
            ('1 gallon',   '= 4.546 L   (UK)  /  3.785 L (US)'),
            ('1 pint',     '= 568 mL (UK)  /  473 mL (US)'),
            ('1 cup',      '= 250 mL (metric)'),
            ('1 tbsp',     '= 15 mL'),
            ('1 tsp',      '= 5 mL'),
          ],
        ),
        SizedBox(height: 12),
        _MeasureCard(
          title: 'Temperature',
          icon: Icons.thermostat_rounded,
          color: GemColors.danger,
          rows: [
            ('°C → °F',  '°F = (°C × 9/5) + 32'),
            ('°F → °C',  '°C = (°F − 32) × 5/9'),
            ('0 °C',     '= 32 °F   (freezing)'),
            ('37 °C',    '= 98.6 °F (body temperature)'),
            ('100 °C',   '= 212 °F  (boiling)'),
          ],
        ),
        SizedBox(height: 12),
        _MeasureCard(
          title: 'Area',
          icon: Icons.crop_square_rounded,
          color: GemColors.referenceColor,
          rows: [
            ('1 hectare', '= 10,000 m²  = 2.471 acres'),
            ('1 acre',    '= 4,047 m²   = 0.405 ha'),
            ('1 km²',     '= 100 ha     = 247.1 acres'),
          ],
        ),
      ],
    );
  }
}

class _MeasureCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<(String, String)> rows;
  const _MeasureCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.rows});

  @override
  State<_MeasureCard> createState() => _MeasureCardState();
}

class _MeasureCardState extends State<_MeasureCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Container(
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: widget.color.withValues(alpha: 0.22), width: 0.8),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, size: 18, color: widget.color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.title,
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white))),
              Icon(
                _open
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: widget.color.withValues(alpha: 0.7),
              ),
            ]),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: widget.rows.map((row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      SizedBox(
                        width: 80,
                        child: Text(row.$1,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: widget.color)),
                      ),
                      Expanded(child: Text(row.$2,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.75)))),
                    ]),
                  );
                }).toList(),
              ),
            ),
        ]),
      ),
    );
  }
}
