export const AD_REGIONS = {
  'Marmara': ['Balıkesir', 'Bilecik', 'Bursa', 'Çanakkale', 'Edirne', 'İstanbul', 'Kırklareli', 'Kocaeli', 'Sakarya', 'Tekirdağ', 'Yalova'],
  'Ege': ['Afyonkarahisar', 'Aydın', 'Denizli', 'İzmir', 'Kütahya', 'Manisa', 'Muğla', 'Uşak'],
  'Akdeniz': ['Adana', 'Antalya', 'Burdur', 'Hatay', 'Isparta', 'Kahramanmaraş', 'Mersin', 'Osmaniye'],
  'İç Anadolu': ['Aksaray', 'Ankara', 'Çankırı', 'Eskişehir', 'Karaman', 'Kayseri', 'Kırıkkale', 'Kırşehir', 'Konya', 'Nevşehir', 'Niğde', 'Sivas', 'Yozgat'],
  'Karadeniz': ['Amasya', 'Artvin', 'Bartın', 'Bayburt', 'Bolu', 'Çorum', 'Düzce', 'Giresun', 'Gümüşhane', 'Karabük', 'Kastamonu', 'Ordu', 'Rize', 'Samsun', 'Sinop', 'Tokat', 'Trabzon', 'Zonguldak'],
  'Doğu Anadolu': ['Ağrı', 'Ardahan', 'Bingöl', 'Bitlis', 'Elazığ', 'Erzincan', 'Erzurum', 'Hakkari', 'Iğdır', 'Kars', 'Malatya', 'Muş', 'Tunceli', 'Van'],
  'Güneydoğu Anadolu': ['Adıyaman', 'Batman', 'Diyarbakır', 'Gaziantep', 'Kilis', 'Mardin', 'Siirt', 'Şanlıurfa', 'Şırnak']
};

export const AD_CITIES = [...new Set(Object.values(AD_REGIONS).flat())].sort((a, b) => a.localeCompare(b, 'tr'));

export function normalizeLocationName(value) {
  return String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/ı/g, 'i')
    .toLocaleLowerCase('tr-TR')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

export function provinceNamesForTargeting(mode, locations) {
  const selected = Array.isArray(locations) ? locations.map(x => String(x || '').trim()) : [];
  const normalizedCities = new Map(AD_CITIES.map(city => [normalizeLocationName(city), city]));
  const normalizedRegions = new Map(Object.keys(AD_REGIONS).map(region => [normalizeLocationName(region), region]));
  if (mode === 'COUNTRY') return [];
  if (!selected.length) throw new Error('Reklam hedefi için en az bir il veya bölge seç.');
  if (mode === 'REGION') {
    const regions = selected.map(x => normalizedRegions.get(normalizeLocationName(x))).filter(Boolean);
    if (regions.length !== selected.length) throw new Error('Seçilen reklam bölgesi tanınmadı.');
    return [...new Set(regions.flatMap(region => AD_REGIONS[region]))];
  }
  if (mode === 'CITY') {
    const cities = selected.map(x => normalizedCities.get(normalizeLocationName(x))).filter(Boolean);
    if (cities.length !== selected.length) throw new Error('Seçilen reklam ili tanınmadı.');
    return [...new Set(cities)];
  }
  throw new Error('Reklam hedefleme türü CITY, REGION veya COUNTRY olmalı.');
}
