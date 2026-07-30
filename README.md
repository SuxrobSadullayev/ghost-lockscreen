# lockscreen — School21 Auto-Lock Bypass Tool

School21 kompyuterlarida shaxsiy akkountingizni vaqtincha auto-lockdan himoya qiluvchi tool.

---

## Qanday ishlaydi

- `lockscreen 6h` — 6 soat davomida akkount avtomatik chiqarib yubormaydigan bo'ladi
- 6 soat tugagach, tizim o'zi avvalgi holatiga (30 daqiqa) qaytadi
- `lockscreen off` — istalgan vaqtda qo'lda qaytarish

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

---

## Ishlatish

```bash
# 6 soat uchun auto-lockni o'chirish
lockscreen 6h

# 90 daqiqa uchun
lockscreen 90m

# 2 soat 30 daqiqa uchun (minutlarda yozing)
lockscreen 150m

# Holatni ko'rish
lockscreen status

# Vaqtidan oldin qaytarish
lockscreen off
```

---

## Qo'llab-quvvatlanadigan vaqt formatlari

| Format | Misol | Ma'nosi |
|--------|-------|---------|
| `h`    | `6h`  | 6 soat  |
| `m`    | `90m` | 90 daqiqa |
| `s`    | `3600s` | 3600 soniya |

---

## Qanday ishlaydi (texnik)

1. GNOME yoki xset orqali idle-delay ni `0` ga qo'yadi (lock o'chadi)
2. Fon jarayoni (`sleep N`) ishga tushadi
3. Vaqt tugagach, `~/.lockscreen_restore.sh` ishga tushadi va sozlamalarni qaytaradi
4. Timer PID `~/.lockscreen_timer` faylida saqlanadi

---

## Log fayl

```bash
cat ~/.lockscreen.log
```

---

## Eslatma

- Bu tool faqat **o'zingizning akkountingiz** uchun ishlaydi
- Tizim sozlamalarini o'zgartirmaydi, faqat GNOME/xset user sozlamalarini boshqaradi
- School21 kompyuterlarida har sessiyada qaytadan o'rnatish **shart emas** — bir marta `install.sh` ishlatsangiz kifoya (`~/.local/bin/` da saqlanadi)
