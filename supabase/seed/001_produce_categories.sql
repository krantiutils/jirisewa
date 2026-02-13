-- Curated produce categories for Nepal's agricultural marketplace.
-- icon values correspond to lucide-react icon names.

INSERT INTO produce_categories (name_en, name_ne, icon, sort_order) VALUES
  ('Vegetables',     'तरकारी',        'carrot',      1),
  ('Fruits',         'फलफूल',         'apple',       2),
  ('Grains & Rice',  'अन्न र चामल',   'wheat',       3),
  ('Lentils & Beans','दाल र सिमी',    'bean',        4),
  ('Spices',         'मसला',          'flame',       5),
  ('Dairy',          'दुग्ध पदार्थ',   'milk',        6),
  ('Herbs',          'जडीबुटी',       'leaf',        7),
  ('Oils & Ghee',    'तेल र घिउ',     'droplets',    8),
  ('Honey',          'मह',            'hexagon',     9),
  ('Dried Goods',    'सुकुटी/सुकेका',  'sun',        10),
  ('Nuts & Seeds',   'सुपारी र बीउ',  'nut',        11),
  ('Tea & Coffee',   'चिया र कफी',    'coffee',     12)
ON CONFLICT DO NOTHING;
