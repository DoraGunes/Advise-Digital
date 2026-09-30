export const TIME_MODEL = [
  {day:1,hour:12,base:0.70},{day:1,hour:18,base:0.86},{day:1,hour:19,base:0.92},{day:1,hour:20,base:0.90},{day:1,hour:21,base:0.84},
  {day:2,hour:12,base:0.72},{day:2,hour:18,base:0.88},{day:2,hour:19,base:0.94},{day:2,hour:20,base:0.93},{day:2,hour:21,base:0.86},
  {day:3,hour:12,base:0.74},{day:3,hour:18,base:0.90},{day:3,hour:19,base:0.96},{day:3,hour:20,base:0.95},{day:3,hour:21,base:0.88},
  {day:4,hour:12,base:0.74},{day:4,hour:18,base:0.91},{day:4,hour:19,base:0.97},{day:4,hour:20,base:0.96},{day:4,hour:21,base:0.89},
  {day:5,hour:12,base:0.78},{day:5,hour:18,base:0.94},{day:5,hour:19,base:0.98},{day:5,hour:20,base:0.97},{day:5,hour:21,base:0.92},
  {day:6,hour:11,base:0.82},{day:6,hour:12,base:0.86},{day:6,hour:13,base:0.84},{day:6,hour:18,base:0.95},{day:6,hour:19,base:0.98},{day:6,hour:20,base:0.97},{day:6,hour:21,base:0.93},
  {day:7,hour:11,base:0.80},{day:7,hour:12,base:0.84},{day:7,hour:13,base:0.82},{day:7,hour:18,base:0.93},{day:7,hour:19,base:0.96},{day:7,hour:20,base:0.95},{day:7,hour:21,base:0.90}
];

export function seedTimeScore(day,hour) {
  const row=TIME_MODEL.find(x=>x.day===day&&x.hour===hour);
  if(row) return row.base;
  if(hour>=18&&hour<=22) return 0.75;
  if(hour>=11&&hour<=14) return 0.65;
  return 0.40;
}

export function earlyAdDecision(metrics, settings) {
  const spend=Number(metrics.spend||0);
  const messages=Number(metrics.messages||0);
  const cost=metrics.messageCost==null?null:Number(metrics.messageCost);
  if(spend < Number(settings.earlyMinSpendBeforeDecision||50)) return {action:'WAIT',reason:'İlk 12 saat minimum harcama eşiği aşılmadı.'};
  if(cost!==null && cost >= Number(settings.earlyMessageCostLimit||2)) {
    return {action:'REDUCE',reason:`İlk ${settings.earlyWindowHours||12} saatte mesaj maliyeti ${cost.toFixed(2)} TL oldu. Reklam kapatılacak ve serbest kalan bütçe uygun reklama aktarılacak.`};
  }
  if(messages===0 && spend >= Number(settings.earlyNoMessageSpendThreshold||75)) {
    return {action:'REDUCE',reason:`İlk ${settings.earlyWindowHours||12} saatte mesaj oluşmadı ve ${spend.toFixed(2)} TL harcandı. Reklam kapatılacak ve serbest kalan bütçe uygun reklama aktarılacak.`};
  }
  return {action:'KEEP',reason:'İlk 12 saat verisi kabul edilebilir.'};
}
