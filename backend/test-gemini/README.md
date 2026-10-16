# Gemini test ortamı

Bu klasör production server tarafından import edilmez. Meta API, reklam oluşturma, harcama, yayınlama ve kuyruk sistemiyle bağlantısı yoktur.

1. `.env.example` dosyasını aynı klasörde `.env` adıyla kopyalayın.
2. Yalnız test amaçlı Gemini anahtarını `GEMINI_API_KEY` satırına girin.
3. Mock doğrulama için `node --test test/gemini-test-environment.test.js` çalıştırın.

Gerçek Gemini çağrısı gerekiyorsa bunu yalnız bu klasördeki harness’i açıkça çağırarak yapın; production `.env` dosyasına anahtar eklemeyin.
