# md-converter.ps1 - Converts Markdown to HTML or Jupyter Notebook.
# Usage: .\md-converter.ps1 -InputFile <file> [-Format html,ipynb] [options]
# Examples:
#   .\md-converter.ps1
#   .\md-converter.ps1 -InputFile README.md -Format html
#   .\md-converter.ps1 -InputFile README.md -Format html,ipynb -OutputDirectory dist
# Dependencies: Windows PowerShell 5.1+ or PowerShell 7+. No external modules or programs are required.
# Limitations: the HTML renderer supports a practical Markdown subset, not the complete CommonMark specification.

[CmdletBinding()]
param(
    [Alias('i')][string]$InputFile,
    [Alias('f')][string[]]$Format = @('html'),
    [Alias('o')][string]$OutputFile,
    [string]$OutputDirectory,
    [string[]]$CodeLanguages = @('python', 'py'),
    [string]$KernelDisplayName = 'Python 3 (ipykernel)',
    [string]$KernelName = 'python3',
    [string]$LanguageName = 'python',
    [ValidateSet('light', 'dark', 'auto')][string]$HtmlTheme = 'light',
    [string]$HtmlTitle,
    [string]$HtmlCss,
    [ValidateRange(0, 2147483647)][int]$HtmlCodeCollapseLines = 5,
    [switch]$HtmlNoToc,
    [switch]$NoStandalone,
    [switch]$Force,
    [switch]$ListFormats,
    [switch]$Help
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$DefaultHtmlCss = @'
:root {
  --bg: #f4f7fb;
  --surface: rgba(255, 255, 255, 0.88);
  --surface-strong: #ffffff;
  --text: #1f2937;
  --muted: #5b6474;
  --border: rgba(148, 163, 184, 0.28);
  --accent: #0f766e;
  --accent-soft: rgba(15, 118, 110, 0.12);
  --code-bg: #0f172a;
  --code-text: #e2e8f0;
  --quote-bg: rgba(15, 118, 110, 0.08);
  --shadow: 0 18px 50px rgba(15, 23, 42, 0.08);
  /* Reduce these values if you want tighter line spacing. */
  --body-line-height: 1.58;
  --toc-line-height: 1.24;
  --code-line-height: 1.34;
}

html[data-theme="dark"] {
  --bg: #09111f;
  --surface: rgba(15, 23, 42, 0.82);
  --surface-strong: #0f172a;
  --text: #e5eefb;
  --muted: #9fb0c8;
  --border: rgba(148, 163, 184, 0.18);
  --accent: #5eead4;
  --accent-soft: rgba(94, 234, 212, 0.12);
  --code-bg: #020617;
  --code-text: #dbeafe;
  --quote-bg: rgba(94, 234, 212, 0.08);
  --shadow: 0 18px 50px rgba(2, 6, 23, 0.4);
}

@media (prefers-color-scheme: dark) {
  html[data-theme="auto"] {
    --bg: #09111f;
    --surface: rgba(15, 23, 42, 0.82);
    --surface-strong: #0f172a;
    --text: #e5eefb;
    --muted: #9fb0c8;
    --border: rgba(148, 163, 184, 0.18);
    --accent: #5eead4;
    --accent-soft: rgba(94, 234, 212, 0.12);
    --code-bg: #020617;
    --code-text: #dbeafe;
    --quote-bg: rgba(94, 234, 212, 0.08);
    --shadow: 0 18px 50px rgba(2, 6, 23, 0.4);
  }
}

* {
  box-sizing: border-box;
}

html {
  scroll-behavior: smooth;
}

body {
  margin: 0;
  color: var(--text);
  background:
    radial-gradient(circle at top, rgba(15, 118, 110, 0.12), transparent 34%),
    linear-gradient(180deg, rgba(255, 255, 255, 0.12), transparent 28%),
    var(--bg);
  font-family: "Segoe UI", "Inter", "Helvetica Neue", Arial, sans-serif;
  line-height: var(--body-line-height);
}

a {
  color: var(--accent);
}

.page {
  max-width: 1360px;
  margin: 0 auto;
  padding: 40px 20px 72px;
}

.layout {
  display: grid;
  gap: 24px;
}

.layout.has-toc {
  align-items: start;
}

@media (min-width: 1120px) {
  .layout.has-toc {
    grid-template-columns: minmax(220px, 280px) minmax(0, 1fr);
  }

  .layout.has-toc.is-toc-panel-collapsed {
    grid-template-columns: 42px minmax(0, 1fr);
  }
}

.toc {
  border: 1px solid var(--border);
  background: var(--surface);
  backdrop-filter: blur(14px);
  border-radius: 20px;
  padding: 18px 14px;
  box-shadow: var(--shadow);
  display: flex;
  flex-direction: column;
  gap: 10px;
  overflow: hidden;
}

@media (min-width: 1120px) {
  .toc {
    position: sticky;
    top: 24px;
    max-height: calc(100vh - 48px);
  }
}

.toc h2 {
  margin: 0;
  font-size: 0.9rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--muted);
}

.toc-header {
  display: grid;
  gap: 8px;
}

.toc-header-main {
  display: flex;
  align-items: center;
  justify-content: flex-start;
  gap: 6px;
}

.toc-controls {
  display: grid;
  gap: 6px;
  margin-bottom: 8px;
}

.toc.is-panel-collapsed {
  padding: 8px 4px;
  align-items: center;
}

.toc.is-panel-collapsed .toc-header {
  width: 100%;
  gap: 0;
}

.toc.is-panel-collapsed .toc-header-main {
  justify-content: center;
}

.toc.is-panel-collapsed h2,
.toc.is-panel-collapsed .toc-master-toggle,
.toc.is-panel-collapsed nav {
  display: none;
}

.toc-control-group {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.toc-control {
  border: 1px solid var(--border);
  background: var(--surface-strong);
  color: var(--muted);
  min-height: 24px;
  padding: 2px 8px;
  border-radius: 999px;
  font: inherit;
  font-size: 0.72rem;
  line-height: 1;
  cursor: pointer;
  transition:
    color 0.18s ease,
    border-color 0.18s ease,
    background 0.18s ease,
    transform 0.18s ease;
}

.toc-control:hover {
  color: var(--accent);
  border-color: rgba(15, 118, 110, 0.35);
  background: var(--accent-soft);
}

.toc-control.is-active {
  color: var(--accent);
  border-color: rgba(15, 118, 110, 0.38);
  background: var(--accent-soft);
  box-shadow: inset 0 0 0 1px rgba(15, 118, 110, 0.14);
}

.toc-control:active {
  transform: translateY(1px);
}
.toc nav {
  overflow: auto;
  min-height: 0;
  padding-right: 4px;
  margin-right: -4px;
}

.toc-tree {
  display: grid;
  gap: 4px;
}

.toc-item {
  display: grid;
  gap: 4px;
}

.toc-row {
  display: grid;
  grid-template-columns: 16px minmax(0, 1fr);
  align-items: start;
  gap: 6px;
}

.toc-toggle {
  border: 0;
  background: transparent;
  color: var(--muted);
  width: 16px;
  height: 16px;
  padding: 0;
  margin-top: 5px;
  cursor: pointer;
  border-radius: 6px;
  display: grid;
  place-items: center;
}

.toc-toggle::before {
  content: "";
  width: 0;
  height: 0;
  border-left: 4px solid transparent;
  border-right: 4px solid transparent;
  border-top: 6px solid currentColor;
  transform-origin: 50% 40%;
  transition: transform 0.18s ease;
}

.toc-toggle[aria-expanded="false"]::before {
  transform: rotate(-90deg);
}

.toc-item.is-collapsed > .toc-row .toc-toggle::before {
  transform: rotate(-90deg);
}

.toc-item.is-collapsed > .toc-children {
  display: none;
}

.toc-toggle:hover {
  background: var(--accent-soft);
  color: var(--accent);
}

.toc-toggle.is-hidden {
  visibility: hidden;
  pointer-events: none;
}

.toc-menu-toggle {
  border: 0;
  background: transparent;
  color: var(--muted);
  width: 18px;
  height: 18px;
  padding: 0;
  cursor: pointer;
  border-radius: 6px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 2px;
  flex: none;
}

.toc-menu-toggle:hover {
  background: var(--accent-soft);
  color: var(--accent);
}

.toc-menu-toggle span {
  display: block;
  width: 10px;
  height: 1.25px;
  border-radius: 999px;
  background: currentColor;
}

.toc.is-panel-collapsed .toc-menu-toggle {
  width: 18px;
  height: 18px;
}

.toc-master-toggle {
  margin-top: 0;
  flex: none;
}

.toc-link {
  display: block;
  text-decoration: none;
  padding: 4px 8px;
  border-radius: 9px;
  color: var(--muted);
  font-size: 0.92rem;
  line-height: var(--toc-line-height);
  overflow-wrap: anywhere;
}

.toc-link:hover,
.toc-link.is-active {
  background: var(--accent-soft);
  color: var(--accent);
}

.toc-link.is-active {
  font-weight: 600;
}

.toc-children {
  display: grid;
  gap: 4px;
  margin-left: 12px;
  padding-left: 8px;
  border-left: 1px solid var(--border);
}

.content {
  border: 1px solid var(--border);
  background: var(--surface);
  backdrop-filter: blur(14px);
  border-radius: 28px;
  box-shadow: var(--shadow);
  overflow: hidden;
}

.content-header {
  padding: 28px 32px 0;
}

.content-header h1 {
  margin: 0;
  font-size: clamp(1.8rem, 3vw, 3rem);
  line-height: 1.15;
}

.content-header p {
  margin: 12px 0 0;
  color: var(--muted);
}

.prose {
  padding: 24px 32px 36px;
}

.prose > :first-child {
  margin-top: 0;
}

.prose h1,
.prose h2,
.prose h3,
.prose h4,
.prose h5,
.prose h6 {
  line-height: 1.2;
  margin: 1.8em 0 0.55em;
}

.prose p,
.prose ul,
.prose ol,
.prose blockquote,
.prose pre,
.prose hr {
  margin: 0 0 1rem;
}

.prose ul,
.prose ol {
  padding-left: 1.35rem;
}

.prose li + li {
  margin-top: 0.2rem;
}

.prose code {
  font-family: "Cascadia Code", Consolas, monospace;
  background: rgba(148, 163, 184, 0.14);
  border-radius: 0.4rem;
  padding: 0.12rem 0.4rem;
  font-size: 0.92em;
}

.code-block {
  margin: 0 0 0.8rem;
  border-radius: 14px;
  background: var(--code-bg);
  color: var(--code-text);
  overflow: hidden;
}

.code-block-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 8px 10px 0;
}

.code-block-label {
  color: rgba(226, 232, 240, 0.82);
  font-size: 0.72rem;
  letter-spacing: 0.02em;
  line-height: 1.2;
}

.code-block-actions {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}

.code-block-toggle {
  border: 1px solid rgba(255, 255, 255, 0.14);
  background: rgba(15, 23, 42, 0.72);
  color: var(--code-text);
  border-radius: 999px;
  padding: 0.22rem 0.56rem;
  font: inherit;
  font-size: 0.68rem;
  letter-spacing: 0.01em;
  cursor: pointer;
  line-height: 1.1;
}

.code-block-toggle:hover {
  background: rgba(15, 23, 42, 0.88);
}

.code-block.is-collapsible.is-collapsed pre {
  max-height: calc(var(--collapsed-lines, 5) * 1em * var(--code-line-height) + 24px);
  overflow: hidden;
}

.code-block.is-collapsible.is-collapsed pre::after {
  content: "";
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 52px;
  pointer-events: none;
  background: linear-gradient(180deg, rgba(2, 6, 23, 0), rgba(2, 6, 23, 0.94));
}

.copy-code-button {
  border: 1px solid rgba(255, 255, 255, 0.14);
  background: rgba(15, 23, 42, 0.72);
  color: var(--code-text);
  border-radius: 999px;
  padding: 0.22rem 0.56rem;
  font-size: 0.68rem;
  letter-spacing: 0.01em;
  cursor: pointer;
  line-height: 1.1;
}

.copy-code-button:hover {
  background: rgba(15, 23, 42, 0.88);
}

.copy-code-button[data-copy-state="done"] {
  color: #a7f3d0;
}

.copy-code-button[data-copy-state="error"] {
  color: #fecaca;
}

.prose pre {
  position: relative;
  overflow: auto;
  padding: 12px;
  background: transparent;
  color: inherit;
  margin: 0;
  font-size: 0.78rem;
  line-height: var(--code-line-height);
}

.prose pre code {
  display: block;
  padding: 0;
  background: transparent;
  color: inherit;
  font-size: 1em;
  line-height: inherit;
}

.prose pre .tok-comment {
  color: #94a3b8;
  font-style: italic;
}

.prose pre .tok-string {
  color: #86efac;
}

.prose pre .tok-keyword {
  color: #7dd3fc;
  font-weight: 600;
}

.prose pre .tok-builtin {
  color: #c4b5fd;
}

.prose pre .tok-number {
  color: #fca5a5;
}

.prose pre .tok-decorator,
.prose pre .tok-variable {
  color: #f9a8d4;
}

.prose pre .tok-key {
  color: #fcd34d;
}

.prose blockquote {
  margin-left: 0;
  padding: 0.9rem 1rem;
  border-left: 4px solid var(--accent);
  background: var(--quote-bg);
  border-radius: 0 14px 14px 0;
}

.prose hr {
  border: 0;
  border-top: 1px solid var(--border);
}

.prose img {
  max-width: 100%;
  display: block;
  border-radius: 16px;
}

@media (max-width: 768px) {
  .page {
    padding: 20px 12px 32px;
  }

  .toc {
    max-height: min(42vh, 520px);
  }

  .content-header,
  .prose {
    padding-left: 18px;
    padding-right: 18px;
  }

  .toc-children {
    margin-left: 8px;
    padding-left: 6px;
  }

  .copy-code-button {
    top: 8px;
    right: 8px;
  }
}
'@

$DefaultHtmlJs = @'
(() => {
  const copyButtons = Array.from(document.querySelectorAll("[data-copy-code]"));
  copyButtons.forEach((button) => {
    button.dataset.defaultLabel = button.textContent.trim();
  });

  const copyText = async (value) => {
    if (navigator.clipboard?.writeText && window.isSecureContext) {
      await navigator.clipboard.writeText(value);
      return;
    }

    const textArea = document.createElement("textarea");
    textArea.value = value;
    textArea.setAttribute("readonly", "");
    textArea.style.position = "fixed";
    textArea.style.top = "-9999px";
    textArea.style.left = "-9999px";
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();

    const ok = document.execCommand("copy");
    textArea.remove();
    if (!ok) {
      throw new Error("copy failed");
    }
  };

  const setToggleState = (item, expanded) => {
    const toggle = item.querySelector(".toc-row [data-toc-toggle]");
    if (!toggle) {
      return;
    }
    toggle.setAttribute("aria-expanded", String(expanded));
    toggle.setAttribute("aria-label", expanded ? "Свернуть раздел" : "Развернуть раздел");
  };

  const setItemExpanded = (item, expanded) => {
    item.classList.toggle("is-collapsed", !expanded);
    setToggleState(item, expanded);
  };

  const tocLinks = Array.from(document.querySelectorAll(".toc-link[data-target-id]"));
  if (!tocLinks.length) {
    return;
  }

  const tocContainer = document.querySelector(".toc");
  const tocLayout = tocContainer?.closest(".layout.has-toc") ?? null;
  const tocItems = Array.from(document.querySelectorAll(".toc-item.has-children"));
  const tocControlButtons = Array.from(document.querySelectorAll(".toc-control"));
  const tocMasterToggle = document.querySelector(".toc-master-toggle");
  const tocPanelToggle = document.querySelector("[data-toc-panel-toggle]");
  const headingEntries = tocLinks
    .map((link, index) => {
      const id = link.dataset.targetId || "";
      const element = document.getElementById(id);
      if (!element) {
        return null;
      }

      return {
        id,
        index,
        level: Number(link.dataset.headingLevel || "0"),
        link,
        element,
      };
    })
    .filter(Boolean);

  const tocBaseLevel = headingEntries.reduce((minLevel, entry) => {
    return Math.min(minLevel, entry.level || minLevel);
  }, Number.POSITIVE_INFINITY);
  const linkById = new Map(
    headingEntries.map((entry) => [entry.id, entry.link])
  );
  const headingIndexById = new Map(
    headingEntries.map((entry) => [entry.id, entry.index])
  );

  let tocMode = { type: "all", level: Number.POSITIVE_INFINITY };

  const setPanelState = (expanded) => {
    if (tocContainer) {
      tocContainer.classList.toggle("is-panel-collapsed", !expanded);
    }
    if (tocLayout) {
      tocLayout.classList.toggle("is-toc-panel-collapsed", !expanded);
    }
    if (!tocPanelToggle) {
      return;
    }
    tocPanelToggle.setAttribute("aria-expanded", String(expanded));
    tocPanelToggle.setAttribute("aria-label", expanded ? "\u0421\u043a\u0440\u044b\u0442\u044c \u043e\u0433\u043b\u0430\u0432\u043b\u0435\u043d\u0438\u0435" : "\u041f\u043e\u043a\u0430\u0437\u0430\u0442\u044c \u043e\u0433\u043b\u0430\u0432\u043b\u0435\u043d\u0438\u0435");
  };

  const setMasterToggleState = (expanded) => {
    if (!tocMasterToggle) {
      return;
    }
    tocMasterToggle.setAttribute("aria-expanded", String(expanded));
    tocMasterToggle.setAttribute("aria-label", expanded ? "\u0421\u0432\u0435\u0440\u043d\u0443\u0442\u044c \u0432\u0441\u0435" : "\u0420\u0430\u0441\u043a\u0440\u044b\u0442\u044c \u0432\u0441\u0435");
  };

  const getVisibleLevelLimit = () => {
    if (tocMode.type === "collapsed") {
      return tocBaseLevel;
    }
    if (tocMode.type === "level") {
      return tocMode.level;
    }
    return Number.POSITIVE_INFINITY;
  };

  const shouldExpandItem = (level) => {
    if (tocMode.type === "collapsed") {
      return false;
    }
    if (tocMode.type === "level") {
      return level < tocMode.level;
    }
    return true;
  };

  const syncItemWithMode = (item) => {
    const itemLevel = Number(item.dataset.tocLevel || "0");
    setItemExpanded(item, shouldExpandItem(itemLevel));
  };

  const setCodeBlockState = (block, expanded) => {
    block.classList.toggle("is-collapsed", !expanded);
    const toggle = block.querySelector("[data-code-toggle]");
    if (!toggle) {
      return;
    }
    const lineCount = toggle.dataset.lineCount || "";
    const countLabel = lineCount ? ` - ${lineCount}` : "";
    toggle.setAttribute("aria-expanded", String(expanded));
    toggle.textContent = expanded ? `Свернуть код${countLabel}` : `Показать весь код${countLabel}`;
  };

  const setControlsState = () => {
    tocControlButtons.forEach((button) => {
      const action = button.dataset.tocAction || "";
      const level = Number(button.dataset.tocLevelControl || "0");
      const isActive =
        (action === "expand-all" && tocMode.type === "all") ||
        (action === "collapse-all" && tocMode.type === "collapsed") ||
        (button.dataset.tocLevelControl && tocMode.type === "level" && level === tocMode.level);
      button.classList.toggle("is-active", isActive);
    });
  };

  const applyTocMode = (mode) => {
    tocMode = mode;
    tocItems.forEach((item) => {
      syncItemWithMode(item);
    });
    setControlsState();
    setMasterToggleState(tocMode.type === "all");
  };

  const resolveVisibleId = (id) => {
    if (!id) {
      return "";
    }

    const visibleLevelLimit = getVisibleLevelLimit();
    if (!Number.isFinite(visibleLevelLimit)) {
      return id;
    }

    let currentIndex = headingIndexById.get(id);
    if (currentIndex == null) {
      return id;
    }

    while (currentIndex >= 0) {
      const entry = headingEntries[currentIndex];
      if (entry && entry.level <= visibleLevelLimit) {
        return entry.id;
      }
      currentIndex -= 1;
    }

    return headingEntries[0]?.id || id;
  };

  const openParents = (link) => {
    let current = link.closest(".toc-item");
    while (current) {
      if (current.classList.contains("has-children")) {
        syncItemWithMode(current);
      }
      current = current.parentElement?.closest(".toc-item") ?? null;
    }
  };

  document.addEventListener("click", async (event) => {
    const copyButton = event.target.closest("[data-copy-code]");
    if (copyButton) {
      const code = copyButton.closest(".code-block")?.querySelector("pre code");
      if (!code) {
        return;
      }

      const defaultLabel = copyButton.dataset.defaultLabel || "Копировать";
      try {
        await copyText((code.textContent || "").replace(/\n$/, ""));
        copyButton.textContent = "Скопировано";
        copyButton.dataset.copyState = "done";
      } catch (error) {
        copyButton.textContent = "Ошибка";
        copyButton.dataset.copyState = "error";
      }

      window.setTimeout(() => {
        copyButton.textContent = defaultLabel;
        delete copyButton.dataset.copyState;
      }, 1600);
      return;
    }

    const codeToggle = event.target.closest("[data-code-toggle]");
    if (codeToggle) {
      const codeBlock = codeToggle.closest(".code-block");
      if (!codeBlock) {
        return;
      }

      const expanded = codeBlock.classList.contains("is-collapsed");
      setCodeBlockState(codeBlock, expanded);
      return;
    }

    const tocPanelButton = event.target.closest("[data-toc-panel-toggle]");
    if (tocPanelButton) {
      setPanelState(tocContainer?.classList.contains("is-panel-collapsed"));
      return;
    }

    const toggle = event.target.closest("[data-toc-toggle]");
    if (toggle) {
      if (toggle.classList.contains("toc-master-toggle")) {
        applyTocMode(
          tocMode.type === "all"
            ? { type: "collapsed", level: tocBaseLevel }
            : { type: "all", level: Number.POSITIVE_INFINITY }
        );
        return;
      }

      const item = toggle.closest(".toc-item");
      if (!item) {
        return;
      }

      const expanded = item.classList.contains("is-collapsed");
      setItemExpanded(item, expanded);
      return;
    }

    const tocControl = event.target.closest(".toc-control[data-toc-level-control]");
    if (!tocControl) {
      return;
    }

    const level = Number(tocControl.dataset.tocLevelControl || "0");
    if (level > 0) {
      applyTocMode({ type: "level", level });
    }
  });

  const setActiveLink = (id) => {
    const visibleId = resolveVisibleId(id);
    if (!visibleId) {
      return;
    }

    tocLinks.forEach((link) => {
      link.classList.toggle("is-active", link.dataset.targetId === visibleId);
    });

    const activeLink = linkById.get(visibleId);
    if (!activeLink) {
      return;
    }

    openParents(activeLink);
    activeLink.scrollIntoView({ block: "nearest" });
  };

  tocLinks.forEach((link) => {
    link.addEventListener("click", () => {
      setActiveLink(link.dataset.targetId || "");
    });
  });

  const observedHeadings = headingEntries.map((entry) => entry.element);

  const fallbackId = headingEntries[0]?.id || "";
  setPanelState(true);
  applyTocMode({ type: "all", level: Number.POSITIVE_INFINITY });
  if (!("IntersectionObserver" in window) || !observedHeadings.length) {
    setActiveLink(fallbackId);
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      const visible = entries
        .filter((entry) => entry.isIntersecting)
        .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);

      if (visible.length) {
        setActiveLink(visible[0].target.id);
        return;
      }

      const passed = entries
        .filter((entry) => entry.boundingClientRect.top < 140)
        .sort((a, b) => b.boundingClientRect.top - a.boundingClientRect.top);

      if (passed.length) {
        setActiveLink(passed[0].target.id);
      }
    },
    {
      rootMargin: "-18% 0px -70% 0px",
      threshold: [0, 1],
    },
  );

  observedHeadings.forEach((heading) => observer.observe(heading));
  setActiveLink(fallbackId);
})();
'@

function Encode-Html([AllowEmptyString()][string]$Text) {
    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function Show-Usage {
    Write-Output 'Markdown converter'
    Write-Output ''
    Write-Output 'Usage:'
    Write-Output '  md-converter.cmd <input.md> [options]'
    Write-Output '  powershell -NoProfile -File .\md-converter.ps1 -InputFile <input.md> [options]'
    Write-Output ''
    Write-Output 'Options:'
    Write-Output '  -Format html,ipynb       Output format(s). Default: html.'
    Write-Output '  -OutputFile <path>       Exact output path for one format.'
    Write-Output '  -OutputDirectory <path>  Directory for generated files.'
    Write-Output '  -HtmlTheme <theme>       light, dark, or auto.'
    Write-Output '  -HtmlNoToc               Do not create the heading tree.'
    Write-Output '  -NoStandalone            Create an HTML fragment.'
    Write-Output '  -Force                   Overwrite existing output files.'
    Write-Output '  -ListFormats             List supported formats.'
    Write-Output '  -Help                    Show this help.'
    Write-Output ''
    Write-Output 'Examples:'
    Write-Output '  md-converter.cmd README.md'
    Write-Output '  md-converter.cmd README.md -Format html,ipynb -OutputDirectory dist'
    Write-Output '  powershell -NoProfile -File .\md-converter.ps1 -InputFile README.md -Format html'
}

function Build-TocNodes([object[]]$Headings, [ref]$Index, [int]$ParentLevel) {
    $items = [Collections.Generic.List[string]]::new()
    while ($Index.Value -lt $Headings.Count) {
        $heading = $Headings[$Index.Value]
        if ($heading.Level -le $ParentLevel) { break }
        $level = $heading.Level
        $Index.Value++
        $children = ''
        if ($Index.Value -lt $Headings.Count -and $Headings[$Index.Value].Level -gt $level) {
            $children = Build-TocNodes $Headings $Index $level
        }
        $hasChildren = -not [string]::IsNullOrEmpty($children)
        $toggle = if ($hasChildren) { '<button class="toc-toggle" type="button" data-toc-toggle aria-expanded="true" aria-label="Свернуть раздел"></button>' } else { '<span class="toc-toggle is-hidden" aria-hidden="true"></span>' }
        $childHtml = if ($hasChildren) { '<div class="toc-children">' + $children + '</div>' } else { '' }
        $classes = 'toc-item level-' + $level + $(if ($hasChildren) { ' has-children' } else { '' })
        $items.Add('<div class="' + $classes + '" data-toc-level="' + $level + '"><div class="toc-row">' + $toggle + '<a class="toc-link" data-target-id="' + $heading.Id + '" data-heading-level="' + $level + '" href="#' + $heading.Id + '">' + (Encode-Html $heading.Text) + '</a></div>' + $childHtml + '</div>')
    }
    if (-not $items.Count) { return '' }
    return $items -join "`n"
}

function Get-CodeLanguageLabel([string]$Language) {
    $labels = @{ py='Python'; python='Python'; js='JavaScript'; javascript='JavaScript'; ts='TypeScript'; typescript='TypeScript'; json='JSON'; bash='Bash'; sh='Shell'; shell='Shell'; powershell='PowerShell'; ps1='PowerShell'; cmd='CMD'; html='HTML'; css='CSS'; sql='SQL'; yaml='YAML'; yml='YAML'; xml='XML'; md='Markdown'; markdown='Markdown' }
    $normalized = $Language.Trim().ToLowerInvariant()
    if ($labels.ContainsKey($normalized)) { return $labels[$normalized] }
    if (-not $normalized) { return 'Код' }
    if ($normalized.Length -le 4) { return $normalized.ToUpperInvariant() }
    return $normalized.Substring(0, 1).ToUpperInvariant() + $normalized.Substring(1)
}

function Get-RussianLineCount([int]$Count) {
    $lastTwo = $Count % 100; $last = $Count % 10
    $suffix = if ($lastTwo -ge 11 -and $lastTwo -le 14) { 'строк' } elseif ($last -eq 1) { 'строка' } elseif ($last -ge 2 -and $last -le 4) { 'строки' } else { 'строк' }
    return "$Count $suffix"
}

function Convert-Inline([string]$Text) {
    $value = Encode-Html $Text
    $value = [regex]::Replace($value, '!\[([^]]*)\]\(([^)]+)\)', '<img src="$2" alt="$1">')
    $value = [regex]::Replace($value, '\[([^]]+)\]\(([^)]+)\)', '<a href="$2">$1</a>')
    $value = [regex]::Replace($value, '`([^`]+)`', '<code>$1</code>')
    $value = [regex]::Replace($value, '(\*\*|__)(.+?)\1', '<strong>$2</strong>')
    $value = [regex]::Replace($value, '\*([^*]+)\*|_([^_]+)_', {
        param($Match)
        $content = if ($Match.Groups[1].Success) { $Match.Groups[1].Value } else { $Match.Groups[2].Value }
        "<em>$content</em>"
    })
    return $value
}

function Convert-MarkdownToHtml([string]$Markdown) {
    $output = [Collections.Generic.List[string]]::new()
    $headings = [Collections.Generic.List[object]]::new()
    $paragraph = [Collections.Generic.List[string]]::new()
    $code = [Collections.Generic.List[string]]::new()
    $slugCounts = @{}
    $inCode = $false
    $codeLanguage = ''
    $list = ''

    function Flush-Paragraph {
        if ($paragraph.Count) {
            $output.Add('<p>' + (Convert-Inline ($paragraph -join ' ')) + '</p>')
            $paragraph.Clear()
        }
    }
    function Close-List {
        if ($list) {
            $output.Add("</$list>")
            Set-Variable -Name list -Value '' -Scope 1
        }
    }

    foreach ($line in ($Markdown -split "`r?`n")) {
        if ($inCode) {
            if ($line -match '^```\s*$') {
                $class = if ($codeLanguage) { ' class="language-' + (Encode-Html $codeLanguage) + '"' } else { '' }
                $lineCount = $code.Count
                $lineLabel = Get-RussianLineCount $lineCount
                $isCollapsible = $HtmlCodeCollapseLines -gt 0 -and $lineCount -gt $HtmlCodeCollapseLines
                $wrapperClass = if ($isCollapsible) { 'code-block is-collapsible is-collapsed' } else { 'code-block' }
                $style = if ($isCollapsible) { ' style="--collapsed-lines: ' + [Math]::Max($HtmlCodeCollapseLines, 1) + '"' } else { '' }
                $toggle = if ($isCollapsible) { '<button class="code-block-toggle" type="button" data-code-toggle data-line-count="' + $lineLabel + '" aria-expanded="false">Показать весь код - ' + $lineLabel + '</button>' } else { '' }
                $codeHtml = Encode-Html ($code -join "`n")
                $output.Add('<div class="' + $wrapperClass + '"' + $style + '><div class="code-block-header"><div class="code-block-label">' + (Encode-Html (Get-CodeLanguageLabel $codeLanguage)) + '</div><div class="code-block-actions">' + $toggle + '<button class="copy-code-button" type="button" data-copy-code>Копировать</button></div></div><pre><code' + $class + '>' + $codeHtml + '</code></pre></div>')
                $code.Clear(); $inCode = $false; $codeLanguage = ''
            } else { $code.Add($line) }
            continue
        }
        if ($line -match '^```([\w#+.-]*)\s*$') {
            Flush-Paragraph; Close-List
            $inCode = $true; $codeLanguage = $Matches[1]
            continue
        }
        if ([string]::IsNullOrWhiteSpace($line)) {
            Flush-Paragraph; Close-List
            continue
        }
        if ($line -match '^(#{1,6})\s+(.+?)\s*$') {
            Flush-Paragraph; Close-List
            $level = $Matches[1].Length; $text = $Matches[2]
            $slug = ($text.ToLowerInvariant() -replace '[^\p{L}\p{Nd}\s-]', '' -replace '[\s_-]+', '-').Trim('-')
            if (-not $slug) { $slug = 'section' }
            if ($slugCounts.ContainsKey($slug)) { $slugCounts[$slug]++; $slug += '-' + $slugCounts[$slug] } else { $slugCounts[$slug] = 1 }
            $output.Add("<h$level id=`"$slug`">$(Convert-Inline $text)</h$level>")
            $headings.Add([pscustomobject]@{ Level = $level; Id = $slug; Text = ($text -replace '[`*_]', '') })
            continue
        }
        $ordered = $line -match '^\s*\d+\.\s+(.+)$'
        $unordered = $line -match '^\s*[-*+]\s+(.+)$'
        if ($ordered -or $unordered) {
            Flush-Paragraph
            $kind = if ($ordered) { 'ol' } else { 'ul' }
            $content = $Matches[1]
            if ($list -ne $kind) { Close-List; $list = $kind; $output.Add("<$list>") }
            $output.Add('<li>' + (Convert-Inline $content) + '</li>')
            continue
        }
        Flush-Paragraph; Close-List
        if ($line -match '^\s*>\s?(.*)$') { $output.Add('<blockquote><p>' + (Convert-Inline $Matches[1]) + '</p></blockquote>') }
        elseif ($line -match '^\s*(---+|\*\*\*+|___+)\s*$') { $output.Add('<hr>') }
        else { $paragraph.Add($line.Trim()) }
    }
    Flush-Paragraph; Close-List
    if ($inCode) { throw 'The input contains an unterminated fenced code block.' }
    return [pscustomobject]@{ Body = ($output -join "`n"); Headings = $headings }
}

function Write-Html([string]$Markdown, [string]$Source, [string]$Destination) {
    $rendered = Convert-MarkdownToHtml $Markdown
    $title = $HtmlTitle
    if (-not $title) {
        $match = [regex]::Match($Markdown, '(?m)^#{1,6}\s+(.+?)\s*$')
        $title = if ($match.Success) { $match.Groups[1].Value -replace '[`*_]', '' } else { [IO.Path]::GetFileNameWithoutExtension($Source) }
    }
    $toc = ''
    if (-not $HtmlNoToc -and $rendered.Headings.Count) {
        $tocIndex = 0
        $tocTree = Build-TocNodes @($rendered.Headings) ([ref]$tocIndex) 0
        $levels = @($rendered.Headings | ForEach-Object { $_.Level } | Sort-Object -Unique)
        $controls = @($levels | ForEach-Object { '<button class="toc-control" type="button" data-toc-level-control="' + $_ + '">H' + $_ + '</button>' }) -join ''
        $toc = '<aside class="toc"><div class="toc-header"><div class="toc-header-main"><button class="toc-menu-toggle" type="button" data-toc-panel-toggle aria-expanded="true" aria-label="Скрыть оглавление"><span></span><span></span><span></span></button><h2>Оглавление</h2><button class="toc-toggle toc-master-toggle" type="button" data-toc-toggle aria-expanded="true" aria-label="Свернуть все"></button></div></div><nav aria-label="Оглавление"><div class="toc-controls" role="group" aria-label="Управление оглавлением"><div class="toc-control-group">' + $controls + '</div></div><div class="toc-tree">' + $tocTree + '</div></nav></aside>'
    }
    if ($NoStandalone) {
        $document = $toc + "`n<article>`n" + $rendered.Body + "`n</article>`n"
    } else {
        $extraCss = ''
        if ($HtmlCss) {
            if (-not (Test-Path -LiteralPath $HtmlCss -PathType Leaf)) { throw "HTML CSS file not found: $HtmlCss" }
            $extraCss = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $HtmlCss), [Text.Encoding]::UTF8)
        }
        $css = $DefaultHtmlCss
        $layout = if ($toc) { 'layout has-toc' } else { 'layout' }
        $safeTitle = Encode-Html $title
        $document = '<!doctype html><html lang="ru" data-theme="' + $HtmlTheme + '"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>' + $safeTitle + '</title><style>' + $css + "`n`n" + $extraCss + '</style></head><body><div class="page"><div class="' + $layout + '">' + $toc + '<main class="content"><header class="content-header"><h1>' + $safeTitle + '</h1><p>Сгенерировано из Markdown встроенным HTML-рендером md-converter.ps1</p></header><article class="prose">' + $rendered.Body + '</article></main></div></div><script>' + $DefaultHtmlJs + '</script></body></html>'
    }
    [IO.File]::WriteAllText($Destination, $document, [Text.UTF8Encoding]::new($false))
}

function Write-Notebook([string]$Markdown, [string]$Destination) {
    $cells = [Collections.Generic.List[object]]::new()
    $buffer = [Collections.Generic.List[string]]::new()
    $inCode = $false
    $languages = @($CodeLanguages | ForEach-Object { $_.ToLowerInvariant() })
    function Add-Cell([string]$Type) {
        $text = $buffer -join "`n"
        if ($text) {
            if ($Type -eq 'code') { $cells.Add([ordered]@{ cell_type='code'; execution_count=$null; metadata=@{}; outputs=@(); source=@($text) }) }
            else { $cells.Add([ordered]@{ cell_type='markdown'; metadata=@{}; source=@($text) }) }
        }
        $buffer.Clear()
    }
    foreach ($line in ($Markdown -split "`r?`n")) {
        if (-not $inCode -and $line -match '^```([\w#+.-]*)\s*$' -and $languages -contains $Matches[1].ToLowerInvariant()) { Add-Cell 'markdown'; $inCode = $true; continue }
        if ($inCode -and $line -match '^```\s*$') { Add-Cell 'code'; $inCode = $false; continue }
        $buffer.Add($line)
    }
    if ($inCode) { throw 'The input contains an unterminated notebook code block.' }
    Add-Cell 'markdown'
    $notebook = [ordered]@{ cells=@($cells); metadata=[ordered]@{ kernelspec=[ordered]@{ display_name=$KernelDisplayName; language=$LanguageName; name=$KernelName }; language_info=[ordered]@{ name=$LanguageName } }; nbformat=4; nbformat_minor=5 }
    [IO.File]::WriteAllText($Destination, (($notebook | ConvertTo-Json -Depth 20) + "`n"), [Text.UTF8Encoding]::new($false))
}

try {
    if ($Help -or (-not $InputFile -and -not $ListFormats)) { Show-Usage; exit 0 }
    if ($ListFormats) { Write-Output "Supported formats:`n- html`n- ipynb`nAliases: notebook, jupyter -> ipynb"; exit 0 }
    if (-not (Test-Path -LiteralPath $InputFile -PathType Leaf)) { throw "Input file not found: $InputFile" }
    $normalizedFormats = @($Format | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
    $unknownFormats = @($normalizedFormats | Where-Object { $_ -notin @('html', 'ipynb', 'notebook', 'jupyter') })
    if ($unknownFormats.Count) { throw "Unsupported format: $($unknownFormats -join ', '). Supported formats: html, ipynb." }
    if ($OutputFile -and $normalizedFormats.Count -gt 1) { throw 'OutputFile can only be used with one format.' }
    $source = (Resolve-Path -LiteralPath $InputFile).Path
    $markdown = [IO.File]::ReadAllText($source, [Text.Encoding]::UTF8)
    foreach ($requested in $normalizedFormats) {
        $target = if ($requested -in @('notebook','jupyter')) { 'ipynb' } else { $requested }
        $extension = if ($target -eq 'html') { '.html' } else { '.ipynb' }
        if ($OutputFile) { $destination = [IO.Path]::GetFullPath($OutputFile) }
        else {
            $directory = if ($OutputDirectory) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetDirectoryName($source) }
            $destination = Join-Path $directory ([IO.Path]::GetFileNameWithoutExtension($source) + $extension)
        }
        if ((Test-Path -LiteralPath $destination) -and -not $Force) {
            throw "Output file already exists: $destination. Use -Force to overwrite it."
        }
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
        if ($target -eq 'html') { Write-Html $markdown $source $destination } else { Write-Notebook $markdown $destination }
        Write-Output "[$target] $destination <- $source"
    }
    exit 0
} catch {
    [Console]::Error.WriteLine("Error: $($_.Exception.Message)")
    exit 1
}
