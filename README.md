# 🔒 lockscreen — School21 Auto-Lock Bypass Tool

> School21 kompyuterlarida shaxsiy akkountingiz avtomatik chiqarib yuborilmasligi uchun CLI tool.

---

## Muammo nima?

School21 kompyuterlarida har bir akkount **30 daqiqa** faolsizlikdan so'ng avtomatik ravishda lock bo'lib, foydalanuvchi tizimdan chiqarib yuboriladi. Agar siz uzoqroq vaqt ish bilan band bo'lsangiz (masalan, compile kutayotgan bo'lsangiz, yoki bir joyga ketib kelishingiz kerak bo'lsa), akkountingiz sessiyan yo'qoladi.

Bu tool o'sha muammoni hal qiladi.

---

## Qanday ishlaydi?

```
┌─────────────────────────────────────────────────────┐
│  lockscreen 6h                                      │
│                                                     │
│  1. GNOME idle-delay → 0  (lock o'chadi)            │
│  2. Fon timer → sleep 21600s                        │
│  3. 6 soat o'tgach → sozlamalar qaytariladi         │
│  4. Auto-lock yana 30 daqiqaga qaytadi              │
└─────────────────────────────────────────────────────┘
```

### Ichki mexanizm — qadamma-qadam

1. **`lockscreen Nh` yoziladi** — script ishga tushadi
2. **Lock tizimi aniqlanadi** — GNOME yoki xset borligini tekshiradi
3. **Joriy sozlamalar saqlanadi** — asl idle-delay qaytarish uchun yodda tutiladi
4. **Auto-lock o'chiriladi:**
   - GNOME: `gsettings set org.gnome.desktop.session idle-delay 0`
   - GNOME: `gsettings set org.gnome.desktop.screensaver lock-enabled false`
   - xset: `xset s off` va `xset -dpms`
5. **Fon jarayoni (timer) ishga tushadi** — `sleep N` orqali kutadi, `disown` bilan terminaldan ajratiladi
6. **Timer tugagach** — `~/.lockscreen_restore.sh` ishga tushadi va barcha sozlamalar avvalgi holatga qaytariladi
7. **Bildirishnoma keladi** — `notify-send` orqali ekranda xabar ko'rinadi

### Fayllar

| Fayl | Joylashuv | Maqsad |
|---|---|---|
| `lockscreen` | `~/.local/bin/lockscreen` | Asosiy executable script |
| `.lockscreen_timer` | `~/.lockscreen_timer` | Timer jarayonining PID i |
| `.lockscreen_restore.sh` | `~/.lockscreen_restore.sh` | Vaqt tugaganda ishlaydigan restore script |
| `.lockscreen.log` | `~/.lockscreen.log` | Barcha amallar logi |

---

## O'rnatish (School21 kompyuterida)

### 1. Reponi clone qiling

```bash
git clone https://github.com/SuxrobSadullayev/ghost-lockscreen.git
cd ghost-lockscreen
```

### 2. Installerni ishga tushiring

```bash
chmod +x install.sh
./install.sh
```

### 3. PATH ni yangilang

```bash
source ~/.bashrc
# yoki
source ~/.zshrc
```

### 4. Ishlashini tekshiring

```bash
lockscreen status
```

> **Eslatma:** `install.sh` faqat **bir marta** ishga tushiriladi. Keyingi sessiyalarda to'g'ridan-to'g'ri `lockscreen` buyrug'ini ishlatasiz.

---

## Ishlatish

### Asosiy buyruqlar

```bash
lockscreen 6h        # 6 soat
lockscreen 10h       # 10 soat
lockscreen 30m       # 30 daqiqa
lockscreen 90m       # 1 soat 30 daqiqa
lockscreen 150m      # 2 soat 30 daqiqa
lockscreen 8h        # 8 soat (to'liq ish kuni)
lockscreen off       # Vaqtidan oldin qaytarish
lockscreen status    # Joriy holatni ko'rish
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
Status: DISABLED  (auto-lock is OFF, timer running — PID: 12345)

Current settings:
  idle-delay   : uint32 0
  lock-enabled : false

Last 5 log entries:
[2025-01-15 09:00:01] Auto-lock DISABLED (system: gnome)
[2025-01-15 09:00:01] Disabled for 36000s (restores at 19:00), PID: 12345
```

---

## Ish oqimi (misol)

```bash
# Ertalab School21 ga keldingiz, ish boshladingiz
lockscreen 8h
# ✓ Auto-lock DISABLED for 8h
# Restores at : 18:00
# Lock system : gnome
# Timer PID   : 9821
#
# To cancel early: lockscreen off

# ... 8 soat ishlaysiz, tizim sizni chiqarmaydi ...

# Kechqurun ketishdan oldin (ixtiyoriy — o'zi qaytadi)
lockscreen off
# ✓ Done. Auto-lock restored (30 min idle timeout).
```

---

## Qo'shimcha

### Log faylni ko'rish

```bash
cat ~/.lockscreen.log
```

### Agar tool ishlamay qolsa

```bash
# Qo'lda sozlamalarni qaytarish (GNOME uchun)
gsettings set org.gnome.desktop.session idle-delay 1800
gsettings set org.gnome.desktop.screensaver lock-enabled true

# xset uchun
xset s 1800 1800
xset +dpms
```

### Timer jarayonini tekshirish

```bash
cat ~/.lockscreen_timer        # PID ni ko'rish
ps aux | grep $(cat ~/.lockscreen_timer)  # jarayon ishlayaptimi
```

---

## Texnik talablar

- Linux (Ubuntu/Debian) — School21 kompyuterlari
- Bash 4+
- GNOME Desktop yoki xset mavjud bo'lsa ishlaydi
- Alohida o'rnatish talab qilinmaydi (`gsettings` va `xset` o'rnatilgan bo'ladi)

---

## Loyiha tuzilmasi

```
ghost-lockscreen/
├── lockscreen      # Asosiy script
├── install.sh      # Bir martalik o'rnatuvchi
└── README.md       # Ushbu fayl
```
