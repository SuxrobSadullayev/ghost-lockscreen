# 🔒 lockscreen — School21 Session Keep-Alive Tool

> School21 kompyuterlarida akkountingiz avtomatik chiqarib yuborilmasligi uchun: ekranni qulflaydi va sessiyani N soat tirik ushlab turadi.

---

## Muammo nima?

School21 kompyuterlarida har bir akkount **30 daqiqa** faolsizlikdan so'ng avtomatik chiqarib yuboriladi (systemd-logind `IdleActionSec` orqali). Oddiy ekran bloklash (Super+L) yordam bermaydi — **qulflangan ekran ham tizim uchun "idle" hisoblanadi**, shuning uchun siz uzoq vaqt ketganingizda sessiya o'chib qoladi.

Bu tool muammoni hal qiladi: ekranni qulflaydi **VA** sessiyani belgilangan vaqtgacha o'chishdan himoya qiladi.

---

## Tezkor o'rnatish (School21, 1 daqiqa)

```bash
git clone https://github.com/SuxrobSadullayev/ghost-lockscreen.git
cd ghost-lockscreen
./diagnose.sh            # (ixtiyoriy) muhit tekshiruvi — INHIBIT_OK muhim
./install.sh             # ~/.local/bin ga o'rnatadi
source ~/.bashrc         # PATH yangilanadi
lockscreen status        # ishlayotganini tekshiring
```

So'ng har safar ketishdan oldin:

```bash
lockscreen 8h            # ekran qulflanadi, sessiya 8 soat himoyalanadi
```

---

## Qanday ishlaydi?

```
┌─────────────────────────────────────────────────────┐
│  lockscreen 6h                                      │
│                                                     │
│  1. Joriy sozlamalar saqlanadi                      │
│  2. Idle inhibitor ishga tushadi (systemd-inhibit)  │
│     → logind sessiyani "idle" deb bilmaydi          │
│  3. Ekran shu zahoti qulflanadi                     │
│  4. Fon timer → sleep 21600s                        │
│  5. 6 soat o'tgach → sozlamalar qaytariladi         │
│  6. Sessiya o'chmaydi, siz qaytib parol yozasiz     │
└─────────────────────────────────────────────────────┘
```

### Ichki mexanizm — qadamma-qadam

1. **`lockscreen Nh` yoziladi** — script ishga tushadi
2. **Joriy sozlamalar saqlanadi** — `~/.lockscreen_settings` fayliga (idle-delay, lock-enabled, xset timeout) — keyin qaytarish uchun
3. **Idle inhibitor ishga tushadi** — `systemd-inhibit --what=idle --mode=block sleep N` fon jarayoni sifatida. Bu logind'ga "session idle emas" deb aytadi — **30 daqiqalik avto-logout ishga tushmaydi**. Root huquqi kerak emas
4. **Ekran qulflanadi** — `loginctl lock-session` (Wayland/GNOME), kerak bo'lsa `gdbus`/`gnome-screensaver-command` fallback
5. **Fon timer** — `sleep N` + `disown`, terminal yopilsa ham ishlaydi
6. **Timer tugagach** — inhibitor o'zi tugaydi, sozlamalar avvalgi holatga qaytariladi, `notify-send` xabar beradi
7. **Siz qaytgach** — parol yozib ekranni ochasiz, sessiyangiz o'chmagan bo'ladi

### Fayllar

| Fayl | Joylashuv | Maqsad |
|---|---|---|
| `lockscreen` | `~/.local/bin/lockscreen` | Asosiy executable script |
| `.lockscreen_timer` | `~/.lockscreen_timer` | Timer jarayonining PID i |
| `.lockscreen_inhibitor_pid` | `~/.lockscreen_inhibitor_pid` | Inhibitor jarayonining PID i |
| `.lockscreen_settings` | `~/.lockscreen_settings` | Saqlangan sozlamalar (qaytarish uchun) |
| `.lockscreen_restore.sh` | `~/.lockscreen_restore.sh` | Vaqt tugaganda ishlaydigan restore script |
| `.lockscreen.log` | `~/.lockscreen.log` | Barcha amallar logi |

---

## O'rnatish (School21 kompyuterida)

### 1. Reponi clone qiling

```bash
git clone https://github.com/SuxrobSadullayev/ghost-lockscreen.git
cd ghost-lockscreen
```

### 2. Diagnostika (ixtiyoriy, lekin tavsiya etiladi)

Tool ishlashiga ishonch hosil qilish uchun School21'da birinchi bo'lib tekshiruvni yugurtiring:

```bash
./diagnose.sh
```

Bu script muhitni, logind sozlamalarini, dconf lock'larini va inhibitor huquqini tekshiradi. Natija `~/lockscreen_diagnose.txt` ga yoziladi. Muhim qatorlar:

- `INHIBIT_OK` — yechim ishlaydi
- `IdleActionSec=30min` + `IdleAction=logout/lock` — logout mezanizmi logind ekanini tasdiqlaydi
- `INHIBIT_FAILED` — systemd-inhibit bloklangan, fallback rejim ishlaydi (lekin qulflangan sessiyani himoya qilmaydi)

### 3. Installerni ishga tushiring

```bash
chmod +x install.sh
./install.sh
```

### 4. PATH ni yangilang

```bash
source ~/.bashrc
# yoki
source ~/.zshrc
```

### 5. Ishlashini tekshiring

```bash
lockscreen status
lockscreen dry-run 6h   # hech narsa qilmaydi, faqat rejani ko'rsatadi
```

> **Eslatma:** `install.sh` faqat **bir marta** ishga tushiriladi. Keyingi sessiyalarda to'g'ridan-to'g'ri `lockscreen` buyrug'ini ishlatasiz.

---

## Laptopda o'rnatish (har qanday GNOME Linux)

Tool universaldir — o'z laptopingizda ham xuddi shu tarzda ishlaydi:

```bash
git clone https://github.com/SuxrobSadullayev/ghost-lockscreen.git
cd ghost-lockscreen
./install.sh          # ~/.local/bin ga o'rnatadi
source ~/.bashrc
lockscreen status     # tekshirish
lockscreen dry-run 6h # rejani ko'rsatadi (hech narsa qilmaydi)
```

Laptopda ham `lockscreen 6h` yozsangiz ekran qulflanadi va sessiya 6 soat himoyalanadi. School21'da ishlatishdan oldin laptopda **sinab ko'rish mumkin**: `lockscreen 5s` yozing — ekran qulflanadi, 5 soniyadan keyin timer tugaydi, parol bilan ochasiz.

> **Muhim:** `lockscreen` buyrug'i ekranni qulflaydi — terminalda yozganingizdan keyin ekran yopiladi, shuning uchun uni faqat ketishdan oldin ishlating. Test uchun `dry-run` yoki juda qisqa vaqt (masalan `lockscreen 1m`) ishlating.

---

## Ishlatish

### Asosiy buyruqlar

```bash
lockscreen 6h        # ekranni qulflaydi, sessiyani 6 soat himoya qiladi
lockscreen 10h       # 10 soat
lockscreen 30m       # 30 daqiqa
lockscreen 90m       # 1 soat 30 daqiqa
lockscreen 8h        # 8 soat (to'liq ish kuni)
lockscreen off       # Vaqtidan oldin bekor qilish (sozlamalarni qaytaradi)
lockscreen status    # Joriy holatni ko'rish
lockscreen dry-run 6h # Rejani ko'rsatadi, hech narsa qilmaydi
```

### Vaqt formatlari

| Format | Misol | Hisob |
|--------|-------|-------|
| `h` — soat | `lockscreen 10h` | 10 × 3600 = 36000 soniya |
| `m` — daqiqa | `lockscreen 45m` | 45 × 60 = 2700 soniya |
| `s` — soniya | `lockscreen 3600s` | 3600 soniya |

### Status chiqishi misoli

```
=== lockscreen status ===
Lock system: gnome
Timer      : RUNNING (PID: 12345)
Inhibitor  : RUNNING (PID: 54321) — session protected

Current settings:
  idle-delay   : uint32 0
  lock-enabled : false

Last 5 log entries:
[2026-01-15 09:00:01] Locked, session kept alive for 21600s (restores at 15:00), method: inhibitor, timer PID: 12345
```

---

## Ish oqimi (misol)

```bash
# Ertalab School21 ga keldingiz, ketishdan oldin:
lockscreen 8h
# ✓ Locked. Session kept alive for 8h
#   Restores at  : 18:00
#   Lock system  : gnome
#   Method       : inhibitor
#   Inhibitor PID: 9821
#
#   To cancel early: lockscreen off
# (ekran shu zahoti qulflanadi — siz ketishingiz mumkin)

# ... 8 soat o'tgach qaytasiz:
# Parol yozasiz — sessiya hali tirik, hamma narsa joyida

# Vaqtidan oldin bekor qilish (ixtiyoriy):
lockscreen off
# ✓ Done. Timer cancelled, settings restored.
```

---

## Fallback rejim

Agar `systemd-inhibit` mavjud bo'lmasa, tool avtomatik eski usulga o'tadi (GNOME idle-delay 0 + xset o'chirish). Bu rejim ekran ochiq turganda ishlaydi, lekin **qulflangan sessiyani himoya qilmaydi** — diagnostika `INHIBIT_OK` ko'rsatsa ham, tavsiya inhibitor rejim.

---

## Qo'shimcha

### Log faylni ko'rish

```bash
cat ~/.lockscreen.log
```

### Agar tool ishlamay qolsa — qo'lda qaytarish

```bash
# Timer/inhibitor fayllarini tozalash
rm -f ~/.lockscreen_timer ~/.lockscreen_inhibitor_pid ~/.lockscreen_restore.sh

# GNOME sozlamalarini qaytarish
gsettings set org.gnome.desktop.session idle-delay 1800
gsettings set org.gnome.desktop.screensaver lock-enabled true

# xset uchun
xset s 1800 1800
xset +dpms
```

### Jarayonlarni tekshirish

```bash
cat ~/.lockscreen_timer         # timer PID
cat ~/.lockscreen_inhibitor_pid # inhibitor PID
ps aux | grep -E "systemd-inhibit|lockscreen" | grep -v grep
```

---

## Testlar

```bash
bash tests/test_lockscreen.sh   # 21 ta test, hech qanday real ta'sirsiz (stub'lar bilan)
```

---

## Texnik talablar

- Linux (Ubuntu/Debian) — School21 kompyuterlari
- Bash 4+
- GNOME Desktop (gsettings) yoki xset
- `systemd-inhibit` (systemd paketi, odatda oldindan o'rnatilgan)
- Alohida o'rnatish talab qilinmaydi

---

## Loyiha tuzilmasi

```
ghost-lockscreen/
├── lockscreen            # Asosiy script
├── diagnose.sh           # School21 muhit diagnostikasi
├── install.sh            # Bir martalik o'rnatuvchi
├── tests/
│   └── test_lockscreen.sh # Testlar (stub'lar bilan)
└── README.md             # Ushbu fayl
```
