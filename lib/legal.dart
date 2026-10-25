// UK food safety and equipment guidance shown in the app.
// Written in plain English from official sources (FSA, GOV.UK, HSE).
// This is guidance only, not legal advice.

class LegalSection {
  final String title;
  final String icon; // material icon key used by the screen
  final List<String> points;
  final List<LegalLink> links;
  const LegalSection(this.title, this.icon, this.points, [this.links = const []]);
}

class LegalLink {
  final String label;
  final String url;
  const LegalLink(this.label, this.url);
}

const legalIntro =
    'Food businesses must keep food at safe temperatures and be able to show '
    'how they do it. Recording fridge and freezer checks is a key part of your '
    'food safety management system (for example HACCP or the FSA\'s Safer Food, '
    'Better Business pack). Environmental Health Officers may ask to see your records.';

const legalSections = <LegalSection>[
  LegalSection('Fridges and chilled food', 'fridge', [
    'Chilled food must be kept at 8°C or below. This is a legal requirement in England, Wales and Northern Ireland, and recommended in Scotland (where food must be kept "cool").',
    'The Food Standards Agency recommends fridges run at 5°C or below (0–5°C) to give a safety margin.',
    'The legal limit applies to the food itself. If an air reading is high, check a food sample with a clean, disinfected probe thermometer (avoid probing through packaging).',
    'A few limited exceptions allow food above 8°C for a short time, for example during service or display. Ask your local Environmental Health team if you rely on these.',
  ], [
    LegalLink('GOV.UK – Chilling and freezing', 'https://www.gov.uk/food-hygiene-businesses/chilling-and-freezing'),
    LegalLink('FSA – Chilling', 'https://www.food.gov.uk/safety-hygiene/chilling'),
  ]),
  LegalSection('Freezers and frozen food', 'freezer', [
    'Frozen food should be kept at -18°C or colder. It is usual for freezers to run between -18°C and -22°C.',
    'Readings can rise briefly during a defrost cycle or after loading. Re-check shortly afterwards.',
    'If frozen food has thawed, do not refreeze it. Use it promptly or discard it as appropriate.',
  ]),
  LegalSection('Checking and recording', 'check', [
    'Check and record fridge and freezer temperatures at least once a day. Many businesses check at opening and closing.',
    'Check your probe thermometer is accurate regularly (for example in iced water it should read between -1°C and 1°C, and in boiling water between 99°C and 101°C).',
    'When a reading is out of range, record what you did about it (the "corrective action"). ChillProof asks you for this automatically.',
    'Keep your records. Many businesses keep them for at least a year and ask their local authority how long they need them.',
  ], [
    LegalLink('FSA – Safer Food, Better Business', 'https://www.food.gov.uk/business-guidance/safer-food-better-business'),
  ]),
  LegalSection('Workroom and cold-room safety (HSE)', 'hse', [
    'Health and safety law covers the air temperature where people work. Workrooms should normally be at least 16°C, or at least 13°C where work involves serious physical effort.',
    'Where food must be kept cold, this can be met by chilling food locally, providing warm workstations, or providing suitable protective clothing and warm rest breaks.',
    'For work in chillers around 0°C, suitable clothing and normal breaks are usually enough. For blast freezers down to -30°C, breaks in warm areas are needed.',
    'Walk-in fridges, chill rooms and freezers must have a means of escape: doors that open from the inside, and lighting so the door and handle can be seen. Your risk assessment may show trapped-person alarms are needed.',
  ], [
    LegalLink('HSE – Chilled and frozen food workrooms', 'https://www.hse.gov.uk/food/industries/chilled.htm'),
  ]),
  LegalSection('F gas fridges and freezers', 'fgas', [
    'Some fridges and freezers contain fluorinated greenhouse gases ("F gas"), usually HFCs such as HFC 134a. Check the manual or rating plate.',
    'You must check whether a fridge or freezer contains F gas before getting rid of it, so the gas can be recovered safely.',
    'Businesses should use a licensed waste carrier or an F gas certified engineer to dispose of or service refrigeration equipment. Never vent the gas.',
  ], [
    LegalLink('GOV.UK – F gas fridges and freezers', 'https://www.gov.uk/f-gas-fridges-freezers'),
  ]),
];

const legalDisclaimer =
    'ChillProof helps you record temperature checks. It is not affiliated with or '
    'endorsed by the FSA, HSE or GOV.UK. The information here is general guidance, '
    'not legal advice, and rules can change. For advice about your business, '
    'contact your local authority\'s Environmental Health team.';
