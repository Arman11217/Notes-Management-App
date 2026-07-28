# 📝 noteflow Landing Page

Professional landing page for **noteflow** app — hosted on BDApps at:
**https://www.bdappsdigitalapps.com/NADB26105/noteflow/**

---

## 📁 File Structure

```
noteflow/
├── index.html              # Main landing page
├── css/
│   └── style.css          # All styles + animations
├── js/
│   └── script.js          # Smooth scroll, mobile menu, animations
└── assets/                # (Empty - reserved for app screenshots, logo)
```

---

## 🚀 How to Upload to BDApps Server (FTP)

### Step 1: Get FTP Credentials
Login to BDApps Portal → **App Management** → **noteflow** → **Upload Files**
You will get:
- FTP Host (e.g. `ftp.bdappsdigitalapps.com`)
- Username
- Password

### Step 2: Connect via FTP
Use **FileZilla** (free) or **WinSCP**:
```
Host:     ftp.bdappsdigitalapps.com
Username: <your-username>
Password: <your-password>
Port:     21
```

### Step 3: Upload Files
Navigate to remote folder:
```
/NADB26105/noteflow/
```
Upload these files:
- `index.html` → root
- `css/style.css` → `css/` folder
- `js/script.js` → `js/` folder

### Step 4: Test Live
Open in browser:
```
https://www.bdappsdigitalapps.com/NADB26105/noteflow/
```

---

## ✏️ What to Update Before Upload

Open `index.html` and replace these placeholder values:

| Line | Find | Replace With |
|------|------|--------------|
| ~5 | `NADB26105` | (already correct) |
| ~6 | `noteflow` | Your app display name |
| USSD section | `45334` | Your actual USSD code |
| Footer | `App ID: NADB26105/noteflow` | Your info |

---

## 🎨 Customization

### Change App Name
Open `index.html` and find/replace:
- `noteflow` → your app name
- `noteflow` → your app name (logo)

### Change USSD Subscription Code
Find in `index.html`:
```html
<div class="ussd-code">45334</div>
<a href="tel:45334" ...>Dial Now</a>
```
Replace `45334` with your actual USSD code from BDApps portal (also update the `tel:` href).

### Change Colors
Open `css/style.css`, edit `:root` variables:
```css
:root {
  --primary: #667eea;      /* main brand color */
  --secondary: #764ba2;    /* secondary color */
  --gradient: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}
```

---

## 📱 Features Included

✅ Responsive design (mobile + tablet + desktop)
✅ Smooth scroll navigation
✅ Animated phone mockup
✅ Gradient text effects
✅ Modern card-based layout
✅ Mobile hamburger menu
✅ Back-to-top button
✅ Subscription pricing section
✅ Download CTA button
✅ SEO meta tags

---

## 🔗 APK Download Link

The download button points to:
```
https://www.bdappsdigitalapps.com/NADB26105/noteflow/noteflow.apk
```

After uploading your actual APK to BDApps, replace `noteflow.apk` with your file name.

---

## 💡 Tips

1. **Test Locally First** — Open `index.html` in your browser before uploading
2. **Compress Images** — If you add screenshots, use WebP format
3. **Mobile Test** — Use Chrome DevTools (F12) → Toggle Device Mode
4. **PageSpeed** — Run https://pagespeed.web.dev/ after deploy

---

**Built with ❤️ for BDApps Gladiators NADB26**


