<div align="center">

# Xarita

**Kodning shaklini koʻr.**

macOS uchun native ilova. Loyihani oʻqib chiqadi va muharriring hech qachon koʻrsatmaydigan
xaritani chizadi — qaysi funksiya qaysinisini chaqiradi, hammasi qayerga toʻplanadi va
nimaga umuman hech kim tegmaydi.

[![Platforma](https://img.shields.io/badge/platforma-macOS%2014%2B-black)]()
[![Til](https://img.shields.io/badge/Swift-6.3-orange)]()
[![Arxitektura](https://img.shields.io/badge/Apple%20Silicon-arm64-blue)]()
[![Litsenziya](https://img.shields.io/badge/litsenziya-MIT-green)]()

[English →](README.md)

</div>

---

## Muammo

Muharriring senga **fayllarni** koʻrsatadi. Lekin kod fayl boʻlib ishlamaydi — u **graf** boʻlib
ishlaydi.

Fayllar daraxti faqat bitta dasturchi fayllarni diskda qanday joylashtirganini koʻrsatadi.
Nima nimani chaqirishi haqida esa hech narsa demaydi. Shuning uchun har safar notanish loyihani
ochganingda, oʻsha grafni oʻz miyangda, bittalab `go to definition` bosib qayta qurasan. Inson
xotirasi esa bir vaqtda taxminan yettita narsani ushlab tura oladi.

Bu dastur ilgari bor edi — [Sourcetrail](https://github.com/CoatiSoftware/Sourcetrail) deb atalgan,
dasturchilar uni yaxshi koʻrishardi, lekin 2021-yilda yopildi. macOS uchun uning oʻrnini bosadigan
native dastur chiqmadi.

**Xarita — oʻsha gʻoya, Apple Silicon uchun qaytadan yozilgan.**

---

## Qanday savollarga javob beradi

| Savol | Xarita qanday javob beradi |
|---|---|
| *Katta loyihani ochdim, adashib qoldim.* | Xarita shaklni darrov koʻrsatadi — qayerdan boshlanadi, markaz qayerda, va qaysi 80% eʼtiborga olmasa ham boʻladi. |
| *Bu funksiyaga qanday yetib kelindi?* | Teskari chaqiruv grafi, bir necha qavat chuqurlikda, bir bosishda. `grep` kerak emas. |
| *Buni oʻzgartirsam, nima buziladi?* | Taʼsir doirasi — unga bogʻliq hamma narsa ajratib koʻrsatiladi. |
| *Bu kod hali ishlatiladimi?* | Hech kim chaqirmaydigan funksiyalar yolgʻiz orol boʻlib koʻrinadi. |

---

## Oʻlchangan natijalar

**MacBook Air M4 (16 GB)** — hozirgi eng kichik Apple Silicon kompyuterda, `-O` optimizatsiya bilan
oʻlchandi. Vaqt ichiga fayllarni topish, tokenizatsiya, parsing va fayllararo bogʻlash kiradi.

| Loyiha | Til | Fayl | Qator | Simvol | Chaqiruv | Vaqt |
|---|---|--:|--:|--:|--:|--:|
| [redis](https://github.com/redis/redis) | C | 333 | 241 121 | 8 359 | 20 622 | **0.05 s** |
| [express](https://github.com/expressjs/express) | JavaScript | 141 | 21 616 | 335 | 255 | 0.02 s |
| [flask](https://github.com/pallets/flask) | Python | 83 | 18 428 | 1 622 | 1 283 | 0.01 s |

Joylashtirish algoritmi **8 359 ta nuqtada bir qadamga 7.4 ms** sarflaydi — taxminan 135 fps.
Buni Barnes–Hut yaqinlashtirishi taʼminlaydi.

### Javoblar toʻgʻrimi?

Tezlik faqat javob toʻgʻri boʻlsa maʼnoga ega. Redis'da eng koʻp chaqirilgan funksiyalarni
soʻrasang, Xarita shuni qaytaradi:

```
sdslen      476 ta chaqiruv    src/sds.h:98
sdsfree     423 ta chaqiruv    src/sds.c:221
zfree       370 ta chaqiruv    src/zmalloc.c:585
zmalloc     273 ta chaqiruv    src/zmalloc.c:284
sdsempty    201 ta chaqiruv    src/sds.c:205
```

Bular Redis'ning satrlar kutubxonasi va xotira ajratuvchisi — Redis kodini bilgan odam aynan
shularni aytadi. Flask'da `Scaffold.route`, `Flask.url_for` va `render_template` chiqadi;
Express'da esa `res.send` va `app.set`.

---

## Qanday ishlaydi

```mermaid
flowchart LR
    A[Fayllarni topish] --> B[Tokenizer]
    B --> C[Parser]
    C --> D[Graf qurish]
    D --> E[Barnes–Hut joylashtirish]
    E --> F[Ekranga chizish]

    style A fill:#1e293b,stroke:#475569,color:#e2e8f0
    style B fill:#1e293b,stroke:#475569,color:#e2e8f0
    style C fill:#1e293b,stroke:#475569,color:#e2e8f0
    style D fill:#1e293b,stroke:#475569,color:#e2e8f0
    style E fill:#1e293b,stroke:#475569,color:#e2e8f0
    style F fill:#1e293b,stroke:#475569,color:#e2e8f0
```

**1 · Tokenizer** — bayt darajasidagi lekser. `Character` emas, toʻgʻridan-toʻgʻri UTF-8 baytlar
bilan ishlaydi, chunki kod deyarli butunlay ASCII, va yuz minglab qatorli faylda grapheme
hisoblash bekorga sarflangan vaqt. Izohlar va satr ichidagi matnni yutib yuboradi — shuning uchun
satr ichidagi `(` hech qachon soxta chaqiruv yasay olmaydi. Ichma-ich izohlar, uch tirnoqli satrlar
va template literal'lar har bir til qoidasi boʻyicha hisobga olinadi.

**2 · Parser** — bu tip tekshiruvchi emas, **shakl** taniydigan parser. U eʼlonning sintaktik
koʻrinishini taniydi (`func name(`, `def name(`, `Type name(args) {`, `name: function`, Go
qabul qiluvchilari, Rust `impl` bloklari, JS strelka funksiyalari) va chaqiruvning `name(`
shaklini. Qamrovni tilga qarab qavs chuqurligi yoki chekinish boʻyicha kuzatadi.

**3 · Graf qurish** — har bir chaqiruvni eʼlonga bogʻlaydi. `foo.bar()` uchun avval `foo` nomli
tipdagi `bar` metodini qidiradi, keyin chaqiruvchining oʻz tipidagisini, keyin oʻsha fayldagisini,
oxirida butun loyihada yagona mos kelganini. Topilmagan nomlar tashqi tugun boʻlib qoladi — shunda
uchinchi tomon kutubxonalari koʻrinmay qolmaydi.

**4 · Joylashtirish** — kuchga asoslangan joylashtirish: tugunlar bir-birini itaradi, bogʻlanishlar
prujina kabi tortadi, tizim sekin sovib joyiga oʻtiradi. Oddiy usul har qadamda O(n²) va ikki ming
tugundan keyin ishlamay qoladi. Xarita esa har qadamda **Barnes–Hut kvadrant daraxtini** quradi:
yetarlicha uzoqdagi butun bir toʻda (`oʻlcham / masofa < θ`) bitta ogʻirlik markazi bilan
almashtiriladi. Natijada har qadam O(n log n) boʻladi va yigirma ming tugunli graf ham silliq
ishlaydi. Tugunlar boshida fayllar boʻyicha guruhlanib, filotaksis spirali boʻylab joylashtiriladi —
bu tasodifiy boshlashdan ancha tez yigʻiladi.

### Nega toʻliq parser emas?

Har bir til uchun toʻliq kompilyator old qismini yozish aniqroq boʻlardi — va oʻn uchta shunday
qismni saqlab yurishni anglatardi. Xarita tanlagan yoʻl (Sourcetrail ham xuddi shunday qilgan)
kodni oʻqish uchun muhimroq boʻlgan uchta narsani beradi:

- **kompilyatsiya boʻlmaydigan** yoki kutubxonalari yetishmaydigan loyihada ham ishlaydi
- bitta implementatsiya bilan **oʻn uch tilni** qamrab oladi
- **chorak million qatorni 50 millisekundda** oʻqiydi

Evaziga overload va dinamik chaqiruvlarda aniqlik yoʻqoladi. Pastdagi [Cheklovlar](#cheklovlar)ga qara.

---

## Qoʻllab-quvvatlanadigan tillar

Swift · Python · JavaScript · TypeScript · C · C++ · Go · Java · Rust · Ruby · C# · PHP · Kotlin

Yangi til qoʻshish uchun `Language.swift` fayliga bitta case qoʻshiladi — leksik qoidalar va eʼlon
shakllari oʻsha yerda, quvurning qolgan qismi oʻzgarmaydi.

---

## Holat

| Qism | Holati |
|---|---|
| Build quvuri — bundle, imzo, ishga tushirish | ✅ Ishlaydi |
| Tokenizer, parser, graf bogʻlash | ✅ Ishlaydi, oʻlchandi |
| Barnes–Hut joylashtirish | ✅ Ishlaydi, oʻlchandi |
| Dizayn tizimi, ikki til (uz/en) | 🚧 Jarayonda |
| Interaktiv xarita | 🚧 Jarayonda |
| Kod paneli, qidiruv, inspektor | ⬜ Rejada |
| Bildirishnoma markazi widget'i | ⬜ Rejada |
| Bildirishnomalar | ⬜ Rejada |
| Imzolangan `.dmg` | ⬜ Rejada |

---

## Yigʻish

macOS 14+ va Apple Silicon kerak, hamda Xcode Command Line Tools. Toʻliq Xcode **shart emas**.

```bash
xcode-select --install
```

```bash
git clone https://github.com/<sen>/xarita.git && cd xarita && ./Scripts/build.sh
```

Build repo ichiga emas, `~/Library/Caches/uz.xarita.build` ichiga yoziladi. Bu ataylab qilingan:
loyiha iCloud bilan sinxronlanadigan papkada turadi, iCloud esa fayllarga `com.apple.FinderInfo`
belgisini qoʻshadi, natijada `codesign` *"resource fork, Finder information, or similar detritus
not allowed"* xatosini beradi. Sinxronlanadigan papkadan tashqarida yigʻish buni butunlay hal qiladi.

---

## Cheklovlar

Ochiq aytilgan, chunki imkoniyatini oshirib koʻrsatadigan dastur — umuman yoʻq dasturdan yomonroq:

- **Nom boʻyicha bogʻlash.** Bir xil nomli ikki funksiya birlashib ketishi mumkin. Funksiya
  koʻrsatkichlari, dekoratorlar, refleksiya yoki router orqali chaqiruvlar koʻrinmaydi.
- **"Ishlatilmagan" degani "oʻlik" degani emas.** Nol chaqiruv — bu faqat ishora. Framework
  callback'lari va dinamik kirish nuqtalarining koʻrinadigan chaqiruvchisi boʻlmasligi tabiiy.
  Shuning uchun test fayllari, misollar va kirish nuqtasiga oʻxshash nomlar roʻyxatdan chiqarilgan —
  lekin baribir oʻzing tekshirishing kerak.
- **Tip chiqarish yoʻq.** `a.render()` va `b.render()` tip boʻyicha emas, nom va qamrov boʻyicha
  bogʻlanadi.
- **Ad-hoc imzo.** `codesign -s -` bilan imzolanadi, shuning uchun Gatekeeper birinchi ochilishda
  ogohlantiradi — buni yoʻqotish uchun pullik Developer ID va notarizatsiya kerak.

---

## Nega "Xarita"?

*Xarita* — bu soʻzning maʼnosining oʻzi. Ilova interfeysi oʻzbek va ingliz tillarida.

---

## Litsenziya

MIT
