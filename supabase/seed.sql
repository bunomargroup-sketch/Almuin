-- ============================================================================
-- Almuin — server seed (excerpt).
-- The canonical, fuller content lives in the app's bundled seeds
-- (assets/data/*.json), which are also the offline source of truth.
-- Use the service role to run this. Content must stay curated — never accept
-- scraped or user-submitted Islamic text into these tables.
-- ============================================================================

insert into public.adhkar
  (id, category, time_pref, arabic, transliteration, translation_en,
   meaning_ar, reward_ar, repeat, grade, refs_json, tags_json)
values
  ('morn_hasbiyallah','morning','morning',
   'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
   'HasbiyAllahu la ilaha illa Huwa, alayhi tawakkalt, wa Huwa Rabbul-Arshil-Azim',
   'Allah is sufficient for me; there is no god but He. In Him I trust, and He is Lord of the magnificent Throne.',
   'دواء الهم: كفاية الله لمن توكل عليه.',
   'من قالها سبعًا صباحًا ومساءً كفاه الله ما أهمّه', 7, 'hasan',
   '[{"collection":"سنن أبي داود","number":"٥٠٨١","grade":"hasan"}]',
   '["anxiety","worry","relief","morning"]'),
  ('lat_sleep_fatimah','sleep','night',
   'سُبْحَانَ اللَّهِ (٣٣)، الْحَمْدُ لِلَّهِ (٣٣)، اللَّهُ أَكْبَرُ (٣٤)',
   'SubhanAllah (33), Alhamdulillah (33), Allahu Akbar (34)',
   'The Tasbeeh of Fatimah before sleep.',
   'تسبيح فاطمة رضي الله عنها قبل النوم.',
   'قال النبي ﷺ: هو خير لكما من خادم', 1, 'sahih',
   '[{"collection":"صحيح البخاري","number":"٥٣٦١","grade":"sahih"},{"collection":"صحيح مسلم","number":"٢٧٢٧","grade":"sahih"}]',
   '["sleep","insomnia","tasbeeh"]')
on conflict (id) do nothing;

insert into public.verses
  (id, surah_name_ar, surah_number, ayah_number, arabic, translation_en, tafsir_brief_ar, tags_json)
values
  ('v_raad_28','الرعد',13,28,
   'الَّذِينَ آمَنُوا وَتَطْمَئِنُّ قُلُوبُهُمْ بِذِكْرِ اللَّهِ ۗ أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
   'Those who believe and whose hearts find rest in the remembrance of Allah...',
   'سكينة القلب الحقيقية لا تنال إلا بذكر الله.',
   '["anxiety","stress","worry","general"]')
on conflict (id) do nothing;

insert into public.hadiths
  (id, arabic, translation_en, benefit_ar, collection, number, grade, tags_json)
values
  ('h_consistency',
   'أَحَبُّ الْأَعْمَالِ إِلَى اللَّهِ أَدْوَمُهَا وَإِنْ قَلَّ',
   'The deeds most beloved to Allah are the most consistent, even if small.',
   'قليل دائم خير من كثير منقطع.',
   'متفق عليه','البخاري ٦٤٦٤، مسلم ٧٨٣','sahih','["general","streak"]')
on conflict (id) do nothing;
