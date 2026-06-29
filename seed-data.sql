-- ============================================================
-- AL BNDR - SEED DATA
-- شغّل هذا الملف في Supabase SQL Editor
-- ============================================================

-- ----------------------------------------
-- 1. معرفة رقم المستخدم (غيّر الرقم لرقمك)
-- ----------------------------------------
-- شغّل هذا أولاً عشان تتأكد من رقم حسابك:
-- SELECT id, phone, full_name, role FROM profiles WHERE phone = '9665xxxxxxxx';

-- ----------------------------------------
-- 2. إنشاء مجموعة ملاعب
-- ----------------------------------------
WITH new_group AS (
  INSERT INTO facility_groups (name, description)
  VALUES (
    'ملاعب البندر',
    'مجموعة ملاعب البندر لكرة القدم - جميع الملاعب مضاءة ومكيفة'
  )
  RETURNING id
)
-- ----------------------------------------
-- 3. إضافة ملاعب داخل المجموعة
-- ----------------------------------------
INSERT INTO facilities (group_id, name, description, price_per_hour)
SELECT
  new_group.id,
  name,
  descr,
  price
FROM new_group, (VALUES
  ('ملعب 1', 'ملعب كرة قدم خماسي - عشب صناعي', 150.00),
  ('ملعب 2', 'ملعب كرة قدم خماسي - عشب صناعي', 150.00),
  ('ملعب 3', 'ملعب كرة قدم سداسي - عشب طبيعي', 200.00),
  ('ملعب 4', 'ملعب كرة قدم سداسي - عشب طبيعي', 200.00)
) AS f(name, descr, price);

-- ----------------------------------------
-- 4. ترقية مستخدم إلى facility_admin
--    (غيّر الرقم لرقم جوالك)
-- ----------------------------------------
-- UPDATE profiles
-- SET role = 'facility_admin',
--     facility_group_id = (SELECT id FROM facility_groups WHERE name = 'ملاعب البندر')
-- WHERE phone = '9665xxxxxxxx';

-- ----------------------------------------
-- 5. التحقق من النتيجة
-- ----------------------------------------
-- SELECT * FROM facility_groups;
-- SELECT * FROM facilities;
-- SELECT id, phone, full_name, role, facility_group_id FROM profiles;
