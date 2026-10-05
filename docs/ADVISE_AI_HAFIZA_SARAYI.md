# AdVise AI Hafıza Sarayı

## Amaç
Gemini ilk aşamada üretim motoru/öğretmen olarak kalır. AdVise AI kalıcı hafızası ayrı bir tenant-scoped veri katmanı olarak üretim ve reklam performansını saklar.

## Öğrenme döngüsü
1. Medya analiz edilir.
2. Gemini structured output üretir.
3. learnFromGeneration ile üretim kartı saklanır.
4. İçerik yayınlanır.
5. Meta 12 saatlik performans verisi gelir.
6. learnFromOutcome hook/angle/tone/format/time/audience puanlarını günceller.
7. buildMemoryContext en alakalı güçlü örüntüleri sonraki Gemini promptuna verir.

## Veri
backend/data/ai_memory.json
- generations
- outcomes
- patterns.hooks
- patterns.angles
- patterns.tones
- patterns.formats
- patterns.times
- patterns.audiences

## Önemli sınır
Bu sistem gerçek model ağırlığı eğitimi değildir. Harici hafıza + retrieval + prompt bağlamıdır.

## Gelecek
- sektör bazlı hafıza
- ürün benzerliği
- kazanan/kaybeden örnekleri
- zaman ağırlığı
- novelty kontrolü
- daha seçici retrieval
- gerekirse küçük/yerel model entegrasyonu
