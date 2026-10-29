/* ProfileSmith 主页脚本：三语、三主题、证书卡片叠、锻造火星、下载直链 */
(function () {
  "use strict";

  var root = document.documentElement;
  var params = new URLSearchParams(location.search);
  var reduceMotion = matchMedia("(prefers-reduced-motion: reduce)");
  var darkQuery = matchMedia("(prefers-color-scheme: dark)");
  var REPO = "wangwanjie/ProfileSmith";

  // ---------- 文案 ----------
  var I18N = {
    "zh-CN": {
      "meta.title": "ProfileSmith — macOS 描述文件管理器",
      "meta.desc": "ProfileSmith 是原生 macOS 描述文件管理器：自动索引本机所有 .mobileprovision / .provisionprofile，一眼看清到期状态、Team、证书与 Entitlements，支持导入、导出、批量清理和 IPA 归档预览。",
      "skip": "跳到正文",
      "brandLabel": "ProfileSmith 首页",
      "navLabel": "页面导航",
      "nav.status": "到期看板",
      "nav.features": "功能",
      "nav.window": "截图",
      "nav.install": "安装",
      "langLabel": "语言",
      "themeLabel": "主题",
      "theme.light": "浅色",
      "theme.dark": "深色",
      "theme.system": "跟随系统",
      "githubLabel": "GitHub 仓库",
      "hero.eyebrow": "描述文件档案馆 · macOS 12+",
      "hero.title1": "每一张描述文件，",
      "hero.title2": "都归档在册。",
      "hero.lead": "ProfileSmith 自动索引本机所有 <code>.mobileprovision</code> / <code>.provisionprofile</code>，一眼看清哪些快过期、属于哪个 Team、绑定了哪些证书和 Entitlements，并支持导入、导出与批量清理。",
      "dl.arm": "下载 Apple 芯片版",
      "dl.intel": "下载 Intel 版",
      "dl.history": "全部版本 →",
      "hero.meta": "免费 · Developer ID 签名并经 Apple 公证 · 内置 Sparkle 自动更新",
      "deck.label": "演示用描述文件卡片",
      "deck.flip": "翻面",
      "deck.next": "下一张",
      "deck.note": "演示数据 · 点按卡片翻面",
      "deck.cardLabel": "{name}，{status}。点按翻面",
      "f.team": "Team",
      "f.teamId": "Team ID",
      "f.expires": "到期",
      "f.created": "创建",
      "f.type": "类型",
      "back.title": "Entitlements",
      "back.cert": "证书",
      "type.dev": "开发",
      "type.enterprise": "企业",
      "type.devid": "分发（Developer ID）",
      "type.appstore": "分发（App Store）",
      "st.expired": "已过期",
      "st.valid": "有效",
      "st.today": "今天到期",
      "st.soon": "{n} 天内到期",
      "status.code": "到期看板",
      "status.title": "红黄绿三色，到期一眼可辨",
      "status.sub": "状态列与菜单栏图标会标出已过期和 30 天内到期的描述文件，剩余天数随每次刷新重新计算。",
      "status.bad.title": "已过期",
      "status.bad.text": "「文件 → 清理过期描述文件…」确认后把全部过期项一次性移到废纸篓。",
      "status.warn.badge": "30 天内到期",
      "status.warn.title": "即将到期",
      "status.warn.text": "显示剩余天数，可用「30 天内到期」筛选单独列出。",
      "status.ok.title": "有效",
      "status.ok.text": "按开发、分发、企业、Mac 等条件筛选，列表支持多列排序。",
      "features.code": "功能索引",
      "features.title": "从索引到清理，整个档案柜都在手边",
      "features.sub": "识别 iOS 开发 / Ad Hoc / App Store / 企业，以及 Mac 开发 / App Store / Developer ID 描述文件。",
      "ft.index.t": "自动索引",
      "ft.index.d": "扫描 MobileDevice 与 Xcode 的描述文件目录，增量索引；Xcode 下载、删除或替换描述文件后列表自动刷新。",
      "ft.search.t": "全文搜索与筛选",
      "ft.search.d": "按名称、Bundle ID、Team、UUID、Entitlements 等任意内容做子串搜索；按即将过期、已过期、开发、分发、企业、Mac 筛选。",
      "ft.expiry.t": "到期提醒",
      "ft.expiry.d": "状态列与菜单栏图标标出已过期、30 天内到期的描述文件。",
      "ft.detail.t": "详情查看",
      "ft.detail.d": "概要、Entitlements、证书摘要（SHA1 / SHA256）和完整的原始 plist 结构树。",
      "ft.files.t": "文件管理",
      "ft.files.d": "导入（拖入或 ⌘O）、导出、在 Finder 中显示、美化文件名（自动备份原文件）、移到废纸篓、彻底删除。",
      "ft.cert.t": "证书导出",
      "ft.cert.d": "在「详情」页右键证书节点，导出为 .cer（DER）或 .pem，或复制 SHA1 / SHA256。",
      "ft.copy.t": "批量复制",
      "ft.copy.d": "列表右键可复制 UUID 与 Bundle ID，支持多选；⌘C 复制选中行。",
      "ft.archive.t": "归档预览",
      "ft.archive.d": "预览 IPA、XCArchive、App、App Extension 的 Info.plist 与内嵌描述文件。",
      "ft.lang.t": "多语言与外观",
      "ft.lang.d": "简体中文、繁体中文、English；浅色 / 深色 / 跟随系统，偏好设置中即时切换。",
      "window.code": "实物照片",
      "window.title": "原生 AppKit 界面",
      "window.sub": "左侧是全部描述文件，右侧是概要、详情与预览。截图中的描述文件均为演示数据。",
      "window.alt": "ProfileSmith 主界面：描述文件列表与详情",
      "archive.code": "拆封检视",
      "archive.title": "不解包，也能看清内嵌描述文件",
      "archive.sub": "预览 IPA、XCArchive、App、App Extension 的 Info.plist 与内嵌描述文件。预览 IPA 时只解压这两个文件，并在后台完成，大体积 IPA 也不会卡住界面。",
      "archive.finder": "在 Finder 中右键描述文件 →「打开方式 → ProfileSmith」：未导入的自动导入，已存在的直接定位。",
      "keys.code": "工具架",
      "keys.title": "常用操作都有快捷键",
      "keys.import": "导入描述文件",
      "keys.refresh": "刷新索引",
      "keys.spaceKey": "空格 / 双击",
      "keys.preview": "预览选中项",
      "keys.copy": "复制选中行",
      "keys.trash": "移到废纸篓",
      "keys.settings": "偏好设置",
      "install.code": "领用登记",
      "install.title": "安装",
      "install.sub": "需要 macOS 12.0 或更高版本。不确定芯片类型？打开「苹果菜单 › 关于本机」查看「芯片」或「处理器」，或在终端执行 <code>uname -m</code>。",
      "install.s1": "下载与本机芯片匹配的 DMG：Apple 芯片选 <code>arm64</code>，Intel 芯片选 <code>x86_64</code>。",
      "install.s2": "打开 DMG，把 ProfileSmith 拖进「应用程序」文件夹，再从「应用程序」中打开。",
      "install.s3": "ProfileSmith 会自动索引本机的描述文件；也可以把描述文件或 IPA 直接拖进窗口导入、预览。",
      "install.s4": "之后的新版本由内置的 Sparkle 自动更新，会按本机芯片下载对应的安装包。",
      "footerLabel": "页脚链接",
      "footer.more": "VanJay 的更多作品",
      "footer.repo": "GitHub 仓库",
      "footer.changelog": "更新日志",
      "footer.issues": "反馈问题",
      "ver.latest": "最新版本 {v}"
    },
    "en": {
      "meta.title": "ProfileSmith — Provisioning profile manager for macOS",
      "meta.desc": "ProfileSmith is a native provisioning profile manager for macOS. It indexes every .mobileprovision and .provisionprofile on your Mac, shows expiry, Team, certificates and entitlements at a glance, and handles import, export, bulk cleanup and IPA archive preview.",
      "skip": "Skip to content",
      "brandLabel": "ProfileSmith home",
      "navLabel": "Page navigation",
      "nav.status": "Expiry",
      "nav.features": "Features",
      "nav.window": "Screenshots",
      "nav.install": "Install",
      "langLabel": "Language",
      "themeLabel": "Theme",
      "theme.light": "Light",
      "theme.dark": "Dark",
      "theme.system": "System",
      "githubLabel": "GitHub repository",
      "hero.eyebrow": "A profile archive · macOS 12+",
      "hero.title1": "Every provisioning profile,",
      "hero.title2": "on file.",
      "hero.lead": "ProfileSmith indexes every <code>.mobileprovision</code> and <code>.provisionprofile</code> on your Mac and shows at a glance which ones expire soon, which Team they belong to and which certificates and entitlements they carry. Import, export and clean up in bulk.",
      "dl.arm": "Download for Apple silicon",
      "dl.intel": "Download for Intel",
      "dl.history": "All releases →",
      "hero.meta": "Free · Signed with Developer ID and notarized by Apple · Sparkle auto-update built in",
      "deck.label": "Demo provisioning profile cards",
      "deck.flip": "Flip",
      "deck.next": "Next",
      "deck.note": "Demo data · Tap a card to flip it",
      "deck.cardLabel": "{name}, {status}. Tap to flip",
      "f.team": "Team",
      "f.teamId": "Team ID",
      "f.expires": "Expires",
      "f.created": "Created",
      "f.type": "Type",
      "back.title": "Entitlements",
      "back.cert": "Certificate",
      "type.dev": "Development",
      "type.enterprise": "Enterprise",
      "type.devid": "Distribution (Developer ID)",
      "type.appstore": "Distribution (App Store)",
      "st.expired": "Expired",
      "st.valid": "Valid",
      "st.today": "Expires today",
      "st.soon": "Expires in {n} days",
      "status.code": "Expiry board",
      "status.title": "Red, amber, green: expiry at a glance",
      "status.sub": "The status column and the menu bar icon flag expired profiles and those expiring within 30 days. Days left are recalculated on every refresh.",
      "status.bad.title": "Expired",
      "status.bad.text": "File › Clean Up Expired Profiles… moves every expired profile to the Trash in one step after you confirm.",
      "status.warn.badge": "Within 30 days",
      "status.warn.title": "Expiring soon",
      "status.warn.text": "Shows the days left. The “Expiring Within 30 Days” filter lists them on their own.",
      "status.ok.title": "Valid",
      "status.ok.text": "Filter by development, distribution, enterprise or Mac, and sort the list by any column.",
      "features.code": "Feature index",
      "features.title": "From indexing to cleanup, the whole cabinet at hand",
      "features.sub": "Recognizes iOS Development, Ad Hoc, App Store and Enterprise profiles, plus Mac Development, App Store and Developer ID.",
      "ft.index.t": "Auto indexing",
      "ft.index.d": "Scans the MobileDevice and Xcode profile folders with an incremental index. The list refreshes when Xcode downloads, deletes or replaces a profile.",
      "ft.search.t": "Search & filter",
      "ft.search.d": "Substring search across name, Bundle ID, Team, UUID, entitlements and more. Filter by expiring, expired, development, distribution, enterprise or Mac.",
      "ft.expiry.t": "Expiry alerts",
      "ft.expiry.d": "The status column and the menu bar icon flag expired profiles and those expiring within 30 days.",
      "ft.detail.t": "Details",
      "ft.detail.d": "Summary, entitlements, certificate digests (SHA1 / SHA256) and the full raw plist tree.",
      "ft.files.t": "File management",
      "ft.files.d": "Import (drag in or ⌘O), export, reveal in Finder, tidy file names with an automatic backup, move to Trash or delete for good.",
      "ft.cert.t": "Certificate export",
      "ft.cert.d": "Right-click a certificate in Details to export it as .cer (DER) or .pem, or copy its SHA1 / SHA256.",
      "ft.copy.t": "Bulk copy",
      "ft.copy.d": "Copy UUIDs and Bundle IDs from the context menu, with multiple selection. ⌘C copies the selected rows.",
      "ft.archive.t": "Archive preview",
      "ft.archive.d": "Preview the Info.plist and embedded profile of IPAs, XCArchives, apps and app extensions.",
      "ft.lang.t": "Languages & appearance",
      "ft.lang.d": "Simplified Chinese, Traditional Chinese and English; light, dark or system appearance, switched instantly in Settings.",
      "window.code": "On the bench",
      "window.title": "A native AppKit interface",
      "window.sub": "All profiles on the left; summary, details and preview on the right. Profiles in the screenshots are demo data.",
      "window.alt": "ProfileSmith main window with the profile list and details",
      "archive.code": "Unsealed",
      "archive.title": "See embedded profiles without unpacking",
      "archive.sub": "Preview the Info.plist and embedded profile of IPAs, XCArchives, apps and app extensions. For an IPA only those two files are extracted, in the background, so large IPAs never block the window.",
      "archive.finder": "In Finder, right-click a profile › Open With › ProfileSmith. New profiles are imported; existing ones are selected in the list.",
      "keys.code": "Tool rack",
      "keys.title": "Keyboard shortcuts for common actions",
      "keys.import": "Import profiles",
      "keys.refresh": "Refresh index",
      "keys.spaceKey": "Space / double-click",
      "keys.preview": "Preview selection",
      "keys.copy": "Copy selected rows",
      "keys.trash": "Move to Trash",
      "keys.settings": "Settings",
      "install.code": "Check-out",
      "install.title": "Install",
      "install.sub": "Requires macOS 12.0 or later. Not sure which chip you have? Open  › About This Mac and check “Chip” or “Processor”, or run <code>uname -m</code> in Terminal.",
      "install.s1": "Download the DMG for your chip: <code>arm64</code> for Apple silicon, <code>x86_64</code> for Intel.",
      "install.s2": "Open the DMG, drag ProfileSmith into Applications and launch it from there.",
      "install.s3": "ProfileSmith indexes the profiles on your Mac automatically. You can also drag profiles or IPAs into the window to import or preview them.",
      "install.s4": "New versions arrive through the built-in Sparkle updater, which downloads the package for your chip.",
      "footerLabel": "Footer links",
      "footer.more": "More by VanJay",
      "footer.repo": "GitHub repository",
      "footer.changelog": "Changelog",
      "footer.issues": "Feedback",
      "ver.latest": "Latest {v}"
    },
    "zh-TW": {
      "meta.title": "ProfileSmith — macOS 描述檔管理器",
      "meta.desc": "ProfileSmith 是原生 macOS 描述檔管理器：自動索引本機所有 .mobileprovision / .provisionprofile，一眼看清到期狀態、Team、憑證與 Entitlements，支援匯入、匯出、批次清理和 IPA 封存預覽。",
      "skip": "跳到內文",
      "brandLabel": "ProfileSmith 首頁",
      "navLabel": "頁面導覽",
      "nav.status": "到期看板",
      "nav.features": "功能",
      "nav.window": "截圖",
      "nav.install": "安裝",
      "langLabel": "語言",
      "themeLabel": "主題",
      "theme.light": "淺色",
      "theme.dark": "深色",
      "theme.system": "跟隨系統",
      "githubLabel": "GitHub 儲存庫",
      "hero.eyebrow": "描述檔檔案館 · macOS 12+",
      "hero.title1": "每一張描述檔，",
      "hero.title2": "都歸檔在冊。",
      "hero.lead": "ProfileSmith 自動索引本機所有 <code>.mobileprovision</code> / <code>.provisionprofile</code>，一眼看清哪些快過期、屬於哪個 Team、綁定了哪些憑證和 Entitlements，並支援匯入、匯出與批次清理。",
      "dl.arm": "下載 Apple 晶片版",
      "dl.intel": "下載 Intel 版",
      "dl.history": "所有版本 →",
      "hero.meta": "免費 · Developer ID 簽署並經 Apple 公證 · 內建 Sparkle 自動更新",
      "deck.label": "示範用描述檔卡片",
      "deck.flip": "翻面",
      "deck.next": "下一張",
      "deck.note": "示範資料 · 點按卡片翻面",
      "deck.cardLabel": "{name}，{status}。點按翻面",
      "f.team": "Team",
      "f.teamId": "Team ID",
      "f.expires": "到期",
      "f.created": "建立",
      "f.type": "類型",
      "back.title": "Entitlements",
      "back.cert": "憑證",
      "type.dev": "開發",
      "type.enterprise": "企業",
      "type.devid": "發佈（Developer ID）",
      "type.appstore": "發佈（App Store）",
      "st.expired": "已過期",
      "st.valid": "有效",
      "st.today": "今天到期",
      "st.soon": "{n} 天內到期",
      "status.code": "到期看板",
      "status.title": "紅黃綠三色，到期一眼可辨",
      "status.sub": "狀態欄與選單列圖示會標出已過期和 30 天內到期的描述檔，剩餘天數隨每次重新整理重新計算。",
      "status.bad.title": "已過期",
      "status.bad.text": "「檔案 → 清理過期描述檔…」確認後把全部過期項目一次移到垃圾桶。",
      "status.warn.badge": "30 天內到期",
      "status.warn.title": "即將到期",
      "status.warn.text": "顯示剩餘天數，可用「30 天內到期」篩選單獨列出。",
      "status.ok.title": "有效",
      "status.ok.text": "依開發、發佈、企業、Mac 等條件篩選，列表支援多欄排序。",
      "features.code": "功能索引",
      "features.title": "從索引到清理，整個檔案櫃都在手邊",
      "features.sub": "識別 iOS 開發 / Ad Hoc / App Store / 企業，以及 Mac 開發 / App Store / Developer ID 描述檔。",
      "ft.index.t": "自動索引",
      "ft.index.d": "掃描 MobileDevice 與 Xcode 的描述檔資料夾，增量索引；Xcode 下載、刪除或取代描述檔後列表自動重新整理。",
      "ft.search.t": "全文搜尋與篩選",
      "ft.search.d": "依名稱、Bundle ID、Team、UUID、Entitlements 等任意內容做子字串搜尋；依即將過期、已過期、開發、發佈、企業、Mac 篩選。",
      "ft.expiry.t": "到期提醒",
      "ft.expiry.d": "狀態欄與選單列圖示標出已過期、30 天內到期的描述檔。",
      "ft.detail.t": "詳情檢視",
      "ft.detail.d": "概要、Entitlements、憑證摘要（SHA1 / SHA256）和完整的原始 plist 結構樹。",
      "ft.files.t": "檔案管理",
      "ft.files.d": "匯入（拖入或 ⌘O）、匯出、在 Finder 中顯示、美化檔名（自動備份原檔案）、移到垃圾桶、永久刪除。",
      "ft.cert.t": "憑證匯出",
      "ft.cert.d": "在「詳情」頁右鍵點按憑證節點，匯出為 .cer（DER）或 .pem，或拷貝 SHA1 / SHA256。",
      "ft.copy.t": "批次拷貝",
      "ft.copy.d": "列表右鍵選單可拷貝 UUID 與 Bundle ID，支援多選；⌘C 拷貝選取的列。",
      "ft.archive.t": "封存預覽",
      "ft.archive.d": "預覽 IPA、XCArchive、App、App Extension 的 Info.plist 與內嵌描述檔。",
      "ft.lang.t": "多語言與外觀",
      "ft.lang.d": "簡體中文、繁體中文、English；淺色 / 深色 / 跟隨系統，在偏好設定中即時切換。",
      "window.code": "實物照片",
      "window.title": "原生 AppKit 介面",
      "window.sub": "左側是全部描述檔，右側是概要、詳情與預覽。截圖中的描述檔皆為示範資料。",
      "window.alt": "ProfileSmith 主視窗：描述檔列表與詳情",
      "archive.code": "拆封檢視",
      "archive.title": "不用解包，也能看清內嵌描述檔",
      "archive.sub": "預覽 IPA、XCArchive、App、App Extension 的 Info.plist 與內嵌描述檔。預覽 IPA 時只解壓這兩個檔案，並在背景完成，大型 IPA 也不會卡住介面。",
      "archive.finder": "在 Finder 中右鍵點按描述檔 →「打開檔案的應用程式 → ProfileSmith」：未匯入的自動匯入，已存在的直接定位。",
      "keys.code": "工具架",
      "keys.title": "常用操作都有快速鍵",
      "keys.import": "匯入描述檔",
      "keys.refresh": "重新整理索引",
      "keys.spaceKey": "空白鍵 / 點兩下",
      "keys.preview": "預覽選取項目",
      "keys.copy": "拷貝選取的列",
      "keys.trash": "移到垃圾桶",
      "keys.settings": "偏好設定",
      "install.code": "領用登記",
      "install.title": "安裝",
      "install.sub": "需要 macOS 12.0 或以上版本。不確定晶片類型？打開「蘋果選單 › 關於這台 Mac」查看「晶片」或「處理器」，或在終端機執行 <code>uname -m</code>。",
      "install.s1": "下載與本機晶片相符的 DMG：Apple 晶片選 <code>arm64</code>，Intel 晶片選 <code>x86_64</code>。",
      "install.s2": "打開 DMG，把 ProfileSmith 拖進「應用程式」檔案夾，再從「應用程式」中打開。",
      "install.s3": "ProfileSmith 會自動索引本機的描述檔；也可以把描述檔或 IPA 直接拖進視窗匯入、預覽。",
      "install.s4": "之後的新版本由內建的 Sparkle 自動更新，會依本機晶片下載對應的安裝包。",
      "footerLabel": "頁尾連結",
      "footer.more": "VanJay 的更多作品",
      "footer.repo": "GitHub 儲存庫",
      "footer.changelog": "更新日誌",
      "footer.issues": "回報問題",
      "ver.latest": "最新版本 {v}"
    }
  };

  var lang = "zh-CN";

  function t(key, vars) {
    var dict = I18N[lang] || I18N["zh-CN"];
    var text = dict[key];
    if (text === undefined) {
      text = I18N["zh-CN"][key];
    }
    if (text === undefined) {
      return key;
    }
    if (vars) {
      text = text.replace(/\{(\w+)\}/g, function (m, name) {
        return vars[name] !== undefined ? vars[name] : m;
      });
    }
    return text;
  }

  // 把各种写法归一到三种语言代码
  function normalizeLang(value) {
    if (!value) {
      return null;
    }
    var v = String(value).toLowerCase();
    if (v === "en" || v.indexOf("en-") === 0) {
      return "en";
    }
    if (/^zh[-_](tw|hk|mo|hant)/.test(v) || v === "tw" || v === "zh-hant") {
      return "zh-TW";
    }
    if (v.indexOf("zh") === 0 || v === "cn") {
      return "zh-CN";
    }
    return null;
  }

  function detectLang() {
    var fromParam = normalizeLang(params.get("lang"));
    if (fromParam) {
      return fromParam;
    }
    try {
      var saved = normalizeLang(localStorage.getItem("profilesmith.lang"));
      if (saved) {
        return saved;
      }
    } catch (e) {}
    var list = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language || "en"];
    for (var i = 0; i < list.length; i++) {
      var v = String(list[i]).toLowerCase();
      if (v.indexOf("zh") === 0) {
        return normalizeLang(v) || "zh-CN";
      }
      if (v.indexOf("en") === 0) {
        return "en";
      }
    }
    return "en";
  }

  function applyLang(next, persist) {
    lang = I18N[next] ? next : "zh-CN";
    root.lang = lang;
    document.title = t("meta.title");
    document.querySelector('meta[name="description"]').content = t("meta.desc");
    document.querySelector('meta[property="og:title"]').content = t("meta.title");
    document.querySelector('meta[property="og:description"]').content = t("meta.desc");
    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      el.textContent = t(el.dataset.i18n);
    });
    document.querySelectorAll("[data-i18n-html]").forEach(function (el) {
      el.innerHTML = t(el.dataset.i18nHtml);
    });
    document.querySelectorAll("[data-i18n-attr]").forEach(function (el) {
      el.dataset.i18nAttr.split(";").forEach(function (pair) {
        var parts = pair.split(":");
        el.setAttribute(parts[0], t(parts[1]));
      });
    });
    document.getElementById("lang-select").value = lang;
    renderFeatures();
    renderDeck();
    renderVersion();
    if (persist) {
      try {
        localStorage.setItem("profilesmith.lang", lang);
      } catch (e) {}
    }
  }

  // ---------- 主题 ----------
  function resolveTheme(pref) {
    return pref === "dark" || (pref === "system" && darkQuery.matches) ? "dark" : "light";
  }

  function applyTheme(pref, persist) {
    root.dataset.themePref = pref;
    var theme = resolveTheme(pref);
    root.dataset.theme = theme;
    document.querySelector('meta[name="theme-color"]').content = theme === "dark" ? "#0a0e18" : "#eef1f0";
    document.querySelectorAll("#theme-switch button").forEach(function (b) {
      b.setAttribute("aria-checked", String(b.dataset.themeValue === pref));
    });
    if (persist) {
      try {
        localStorage.setItem("profilesmith.theme", pref);
      } catch (e) {}
    }
    showShot(theme);
    sparks.sync();
  }

  // ---------- 功能索引卡 ----------
  var ICONS = {
    index: '<path d="M4 7h16M4 12h16M4 17h10"/><circle cx="19" cy="17" r="2"/>',
    search: '<circle cx="11" cy="11" r="6"/><path d="m20 20-4.5-4.5"/>',
    expiry: '<circle cx="12" cy="13" r="7"/><path d="M12 9v4l2.5 2M9 3h6"/>',
    detail: '<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 8h8M8 12h8M8 16h5"/>',
    files: '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M12 10v6m-3-3h6"/>',
    cert: '<circle cx="12" cy="9" r="5"/><path d="m9 13.5-1.5 7L12 18l4.5 2.5-1.5-7"/>',
    copy: '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/>',
    archive: '<path d="M3 5h18v4H3zM5 9v10h14V9M10 13h4"/>',
    lang: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>'
  };
  var FEATURES = ["index", "search", "expiry", "detail", "files", "cert", "copy", "archive", "lang"];

  function renderFeatures() {
    var grid = document.getElementById("feature-grid");
    var html = "";
    FEATURES.forEach(function (id, i) {
      var code = "PS-B" + String(i + 1).padStart(2, "0");
      html += '<article class="icard reveal" data-tab="' + code + '" style="--delay:' + (i % 3) * 0.08 + 's">' +
        '<div class="ico"><svg viewBox="0 0 24 24" aria-hidden="true">' + ICONS[id] + "</svg></div>" +
        "<h3>" + t("ft." + id + ".t") + "</h3><p>" + t("ft." + id + ".d") + "</p></article>";
    });
    grid.innerHTML = html;
    observeReveal(grid.querySelectorAll(".reveal"));
  }

  // ---------- 证书卡片叠（演示数据，到期日相对今天计算，状态始终自洽） ----------
  var DAY = 86400000;
  var today = new Date();
  today.setHours(12, 0, 0, 0);

  var PROFILES = [
    {
      name: "Acme Wallet Enterprise", bundle: "com.acme.enterprise.wallet", platform: "iOS", type: "type.enterprise",
      days: 3, age: 362, uuid: "95370711-8178-4610-892C-6250CF5AA432",
      ents: [["application-identifier", "ACME123456.com.acme.enterprise.wallet", "s"], ["aps-environment", "production", "s"],
        ["com.apple.developer.team-identifier", "ACME123456", "s"], ["get-task-allow", "false", "f"], ["keychain-access-groups", "[ACME123456.*]", "s"]],
      cert: "Apple Distribution: Acme Studio Inc."
    },
    {
      name: "Acme Notes Share Extension", bundle: "com.acme.notes.share", platform: "iOS", type: "type.dev",
      days: 12, age: 353, uuid: "4C1E7B2A-0F3D-4A8E-9B61-2D7F0C5E8A13",
      ents: [["application-identifier", "ACME123456.com.acme.notes.share", "s"], ["aps-environment", "development", "s"],
        ["com.apple.security.application-groups", "[group.com.acme.notes]", "s"], ["get-task-allow", "true", "t"], ["keychain-access-groups", "[ACME123456.*]", "s"]],
      cert: "Apple Development: Acme Studio Inc."
    },
    {
      name: "Acme Studio Mac Developer ID", bundle: "com.acme.studio.mac", platform: "Mac", type: "type.devid",
      days: 1623, age: 203, uuid: "B2D45F10-6E7A-4C39-8A0B-91F3E6D2C7A4",
      ents: [["com.apple.application-identifier", "ACME123456.com.acme.studio.mac", "s"], ["com.apple.developer.team-identifier", "ACME123456", "s"],
        ["keychain-access-groups", "[ACME123456.*]", "s"]],
      cert: "Developer ID Application: Acme Studio Inc."
    },
    {
      name: "Acme Legacy Push Debug", bundle: "com.acme.legacy", platform: "iOS", type: "type.dev",
      days: -149, age: 514, uuid: "7E0A93C5-2B18-4F6D-A4E2-58C1B907D3F6",
      ents: [["application-identifier", "ACME123456.com.acme.legacy", "s"], ["aps-environment", "development", "s"],
        ["get-task-allow", "true", "t"]],
      cert: "Apple Development: Acme Studio Inc."
    }
  ];

  function fmtDate(offsetDays) {
    var d = new Date(today.getTime() + offsetDays * DAY);
    return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
  }

  // 与应用一致的判定：已过期 / 30 天内到期 / 有效
  function statusOf(days) {
    if (days < 0) {
      return { tone: "bad", text: t("st.expired") };
    }
    if (days === 0) {
      return { tone: "warn", text: t("st.today") };
    }
    if (days <= 30) {
      return { tone: "warn", text: t("st.soon", { n: days }) };
    }
    return { tone: "ok", text: t("st.valid") };
  }

  function esc(s) {
    return String(s).replace(/[&<>"]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
    });
  }

  var deck = document.getElementById("deck");
  var order = PROFILES.map(function (_, i) {
    return i;
  });
  var cards = [];

  function cardHTML(p) {
    var st = statusOf(p.days);
    var ents = p.ents.map(function (e) {
      return '<li><span class="k">' + esc(e[0]) + '</span><span class="v ' + e[2] + '">' + esc(e[1]) + "</span></li>";
    }).join("");
    return '<div class="pcard-inner">' +
      '<div class="face face-front">' +
        '<div class="face-band"><span>' + esc(t(p.type)) + '</span><span class="plat">' + p.platform + "</span></div>" +
        '<div class="face-body">' +
          '<div class="seal" aria-hidden="true">P</div>' +
          '<p class="pc-name">' + esc(p.name) + "</p>" +
          '<p class="pc-bundle">' + esc(p.bundle) + "</p>" +
          '<dl class="pc-fields">' +
            "<div><dt>" + t("f.team") + "</dt><dd>Acme Studio Inc.</dd></div>" +
            "<div><dt>" + t("f.teamId") + '</dt><dd class="mono">ACME123456</dd></div>' +
            "<div><dt>" + t("f.created") + '</dt><dd class="mono">' + fmtDate(p.days - p.age) + "</dd></div>" +
            "<div><dt>" + t("f.expires") + '</dt><dd class="mono">' + fmtDate(p.days) + "</dd></div>" +
          "</dl>" +
        "</div>" +
        '<div class="face-foot"><span class="uuid">' + p.uuid + '</span><span class="badge" data-tone="' + st.tone + '"><i></i>' + esc(st.text) + "</span></div>" +
      "</div>" +
      '<div class="face face-back" aria-hidden="true">' +
        '<div class="face-band"><span>' + t("back.title") + '</span><span class="plat">' + p.platform + "</span></div>" +
        '<ul class="ents">' + ents + "</ul>" +
        '<div class="face-foot"><span class="cert">' + t("back.cert") + " · " + esc(p.cert) + "</span></div>" +
      "</div>" +
    "</div>";
  }

  function renderDeck() {
    var flipped = cards.map(function (c) {
      return c.classList.contains("is-flipped");
    });
    deck.innerHTML = "";
    cards = PROFILES.map(function (p, i) {
      var el = document.createElement("div");
      el.className = "pcard" + (flipped[i] ? " is-flipped" : "");
      el.innerHTML = cardHTML(p);
      el.setAttribute("role", "button");
      el.setAttribute("aria-label", t("deck.cardLabel", { name: p.name, status: statusOf(p.days).text }));
      el.addEventListener("click", function () {
        if (order[0] === i) {
          flip();
        } else {
          next();
        }
        pauseAuto();
      });
      deck.appendChild(el);
      return el;
    });
    layout();
  }

  // 第 n 层卡片的位置：向右上方错开，逐层压后
  function posTransform(n) {
    return "translate3d(" + n * 16 + "px," + n * -18 + "px," + n * -46 + "px) rotateZ(" + n * 2.2 + "deg)";
  }

  function layout() {
    order.forEach(function (cardIndex, n) {
      var el = cards[cardIndex];
      el.style.transform = posTransform(n);
      el.style.zIndex = String(10 - n);
      el.style.setProperty("--dim", String(n * 0.16));
      el.tabIndex = n === 0 ? 0 : -1;
    });
  }

  function flip() {
    var top = cards[order[0]];
    top.classList.toggle("is-flipped");
  }

  var dealing = false;

  // 顶层卡片抽出、滑到最底层
  function next() {
    if (dealing) {
      return;
    }
    var topIndex = order.shift();
    order.push(topIndex);
    var el = cards[topIndex];
    var last = order.length - 1;
    if (reduceMotion.matches || !el.animate) {
      el.classList.remove("is-flipped");
      layout();
      return;
    }
    dealing = true;
    el.style.transition = "none";
    var anim = el.animate([
      { transform: posTransform(0) },
      { transform: "translate3d(118%, 6%, 60px) rotateZ(9deg)", offset: 0.45 },
      { transform: posTransform(last) }
    ], { duration: 950, easing: "cubic-bezier(.45,.05,.25,1)" });
    setTimeout(function () {
      el.classList.remove("is-flipped");
      el.style.zIndex = "0";
    }, 430);
    // 其余卡片同步上移一层
    order.forEach(function (ci, n) {
      if (ci !== topIndex) {
        var c = cards[ci];
        c.style.transform = posTransform(n);
        c.style.zIndex = String(10 - n);
        c.style.setProperty("--dim", String(n * 0.16));
        c.tabIndex = n === 0 ? 0 : -1;
      }
    });
    anim.onfinish = function () {
      el.style.transition = "";
      layout();
      dealing = false;
    };
  }

  deck.addEventListener("keydown", function (e) {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      flip();
      pauseAuto();
    } else if (e.key === "ArrowRight") {
      next();
      pauseAuto();
    }
  });
  document.getElementById("deck-flip").addEventListener("click", function () {
    flip();
    pauseAuto();
  });
  document.getElementById("deck-next").addEventListener("click", function () {
    next();
    pauseAuto();
  });

  // 指针倾斜：只改 deck 的 rotateX / rotateY
  var stage = document.getElementById("deck-stage");
  var tiltFrame = 0;
  var BASE_RX = 10;
  var BASE_RY = -16;
  stage.addEventListener("pointermove", function (e) {
    if (reduceMotion.matches || e.pointerType === "touch") {
      return;
    }
    var rect = stage.getBoundingClientRect();
    var x = (e.clientX - rect.left) / rect.width - 0.5;
    var y = (e.clientY - rect.top) / rect.height - 0.5;
    cancelAnimationFrame(tiltFrame);
    tiltFrame = requestAnimationFrame(function () {
      deck.classList.add("is-tracking");
      deck.style.setProperty("--rx", (BASE_RX - y * 18).toFixed(2) + "deg");
      deck.style.setProperty("--ry", (BASE_RY + x * 30).toFixed(2) + "deg");
    });
    hovering = true;
  });
  stage.addEventListener("pointerleave", function () {
    cancelAnimationFrame(tiltFrame);
    deck.classList.remove("is-tracking");
    deck.style.removeProperty("--rx");
    deck.style.removeProperty("--ry");
    hovering = false;
  });

  // 自动演示：翻面看 Entitlements，再翻回、发到下一张
  var hovering = false;
  var autoTimer = 0;
  var autoStep = 0;
  var pausedUntil = 0;
  var heroVisible = true;

  function pauseAuto() {
    pausedUntil = Date.now() + 12000;
  }

  function autoTick() {
    if (reduceMotion.matches || document.hidden || !heroVisible || hovering || Date.now() < pausedUntil || dealing) {
      return;
    }
    var top = cards[order[0]];
    if (autoStep % 2 === 0) {
      top.classList.add("is-flipped");
    } else {
      next();
    }
    autoStep++;
  }

  function startAuto() {
    clearInterval(autoTimer);
    autoTimer = setInterval(autoTick, 3200);
  }

  // ---------- 锻造火星（仅深色主题，hero 可见且页面可见时运行） ----------
  var sparks = (function () {
    var canvas = document.getElementById("sparks");
    var ctx = canvas.getContext("2d");
    var parts = [];
    var raf = 0;
    var w = 0;
    var h = 0;
    var dpr = 1;
    var last = 0;

    function resize() {
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      w = canvas.clientWidth;
      h = canvas.clientHeight;
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }

    function spawn(initial) {
      // 火星集中在右下方的「炉口」，与 forge-glow 对齐
      var wide = w < 980;
      var cx = wide ? w * 0.5 : w * 0.72;
      var spread = wide ? w * 0.45 : w * 0.3;
      return {
        x: cx + (Math.random() - 0.5) * 2 * spread,
        y: initial ? h * (0.35 + Math.random() * 0.65) : h + 8,
        vx: (Math.random() - 0.5) * 0.25,
        vy: -(0.35 + Math.random() * 0.9),
        r: 0.6 + Math.random() * 1.6,
        life: 0,
        max: 260 + Math.random() * 320,
        hue: 18 + Math.random() * 26,
        wob: Math.random() * Math.PI * 2
      };
    }

    function frame(now) {
      raf = requestAnimationFrame(frame);
      var dt = Math.min((now - last) / 16.67, 3);
      last = now;
      ctx.clearRect(0, 0, w, h);
      ctx.globalCompositeOperation = "lighter";
      for (var i = 0; i < parts.length; i++) {
        var p = parts[i];
        p.life += dt;
        p.wob += 0.03 * dt;
        p.x += (p.vx + Math.sin(p.wob) * 0.18) * dt;
        p.y += p.vy * dt;
        var k = p.life / p.max;
        if (k >= 1 || p.y < -10) {
          parts[i] = spawn(false);
          continue;
        }
        var a = (k < 0.1 ? k / 0.1 : 1 - (k - 0.1) / 0.9) * 0.9;
        ctx.fillStyle = "hsla(" + p.hue + ",100%," + (62 + (1 - k) * 18) + "%," + a.toFixed(3) + ")";
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r * (1 - k * 0.5), 0, Math.PI * 2);
        ctx.fill();
      }
    }

    function shouldRun() {
      return root.dataset.theme === "dark" && !reduceMotion.matches && !document.hidden && heroVisible;
    }

    function sync() {
      if (shouldRun()) {
        if (!raf) {
          resize();
          if (!parts.length) {
            var count = w < 640 ? 34 : 70;
            for (var i = 0; i < count; i++) {
              parts.push(spawn(true));
            }
          }
          last = performance.now();
          raf = requestAnimationFrame(frame);
        }
      } else if (raf) {
        cancelAnimationFrame(raf);
        raf = 0;
      }
    }

    window.addEventListener("resize", function () {
      if (raf) {
        resize();
      }
    });
    return { sync: sync };
  })();

  // ---------- 滚动渐入 ----------
  var revealObserver = "IntersectionObserver" in window ? new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-in");
        revealObserver.unobserve(entry.target);
      }
    });
  }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 }) : null;

  function observeReveal(nodes) {
    nodes.forEach(function (el) {
      if (revealObserver && !reduceMotion.matches) {
        revealObserver.observe(el);
      } else {
        el.classList.add("is-in");
      }
    });
  }

  // ---------- 截图切换 ----------
  var shotImg = document.getElementById("shot-img");
  var shotTabs = document.getElementById("shot-tabs");
  var currentShot = "";

  function showShot(name) {
    if (name === currentShot) {
      return;
    }
    currentShot = name;
    shotTabs.querySelectorAll("button").forEach(function (b) {
      b.setAttribute("aria-selected", String(b.dataset.shot === name));
    });
    var base = "assets/screenshots/main-" + name;
    shotImg.srcset = base + "-800.webp 800w, " + base + "-1600.webp 1600w";
    shotImg.src = base + "-1600.webp";
  }

  shotTabs.addEventListener("click", function (e) {
    var b = e.target.closest("button");
    if (b) {
      showShot(b.dataset.shot);
    }
  });

  // ---------- 下载：按芯片排序，并用 GitHub API 换成直链 ----------
  var release = null;

  function guessIntel() {
    try {
      var c = document.createElement("canvas");
      var gl = c.getContext("webgl");
      var info = gl && gl.getExtension("WEBGL_debug_renderer_info");
      var renderer = info ? gl.getParameter(info.UNMASKED_RENDERER_WEBGL) : "";
      return /Intel|AMD|Radeon/i.test(renderer) && !/Apple/i.test(renderer);
    } catch (e) {
      return false;
    }
  }

  function preferIntel() {
    ["downloads", "downloads-end"].forEach(function (id) {
      var box = document.getElementById(id);
      var arm = box.querySelector('[data-arch="arm64"]');
      var intel = box.querySelector('[data-arch="x86_64"]');
      arm.className = "btn btn-ghost";
      intel.className = "btn btn-primary";
      box.insertBefore(intel, arm);
    });
  }

  function renderVersion() {
    var el = document.getElementById("version");
    el.textContent = release && release.tag_name ? " · " + t("ver.latest", { v: release.tag_name }) : "";
  }

  function loadRelease() {
    fetch("https://api.github.com/repos/" + REPO + "/releases/latest", { headers: { Accept: "application/vnd.github+json" } })
      .then(function (r) {
        return r.ok ? r.json() : null;
      })
      .then(function (data) {
        if (!data) {
          return;
        }
        release = data;
        var assets = data.assets || [];
        document.querySelectorAll("[data-arch]").forEach(function (a) {
          var arch = a.dataset.arch;
          var asset = assets.find(function (x) {
            return new RegExp("_" + arch + "\\.dmg$").test(x.name);
          });
          if (asset) {
            a.href = asset.browser_download_url;
            var small = a.querySelector("small");
            small.textContent = arch + " · " + (asset.size / 1048576).toFixed(1) + " MB";
          }
        });
        renderVersion();
      })
      .catch(function () {});
  }

  // ---------- 初始化 ----------
  var initialTheme = root.dataset.themePref || "system";

  document.getElementById("lang-select").addEventListener("change", function (e) {
    applyLang(e.target.value, true);
  });
  document.getElementById("theme-switch").addEventListener("click", function (e) {
    var b = e.target.closest("button");
    if (b) {
      applyTheme(b.dataset.themeValue, true);
    }
  });
  darkQuery.addEventListener("change", function () {
    if (root.dataset.themePref === "system") {
      applyTheme("system", false);
    }
  });

  applyLang(detectLang(), false);
  applyTheme(initialTheme, false);
  observeReveal(document.querySelectorAll(".reveal"));

  if ("IntersectionObserver" in window) {
    new IntersectionObserver(function (entries) {
      heroVisible = entries[0].isIntersecting;
      sparks.sync();
    }).observe(document.querySelector(".hero"));
  }
  document.addEventListener("visibilitychange", function () {
    sparks.sync();
  });
  reduceMotion.addEventListener("change", function () {
    sparks.sync();
  });

  if (guessIntel()) {
    preferIntel();
  }
  startAuto();
  loadRelease();
})();
