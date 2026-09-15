(() => {
  const root = document.documentElement;
  const picker = document.querySelector("[data-theme-picker]");
  const storageKey = "vlad-theme";

  if (!picker) return;

  const summary = picker.querySelector("summary");
  const options = Array.from(picker.querySelectorAll("[data-theme-option]"));

  function storedPreference() {
    try {
      const value = localStorage.getItem(storageKey);
      return value === "light" || value === "dark" ? value : "system";
    } catch (error) {
      return "system";
    }
  }

  function persistPreference(value) {
    try {
      if (value === "system") {
        localStorage.removeItem(storageKey);
      } else {
        localStorage.setItem(storageKey, value);
      }
    } catch (error) {}
  }

  function applyPreference(value, persist = true) {
    if (value === "light" || value === "dark") {
      root.dataset.theme = value;
    } else {
      delete root.dataset.theme;
      value = "system";
    }

    if (persist) persistPreference(value);

    const label = value.charAt(0).toUpperCase() + value.slice(1);
    summary.title = `Theme: ${label}`;
    summary.setAttribute("aria-label", `Color theme: ${label}. Choose color theme`);

    options.forEach((option) => {
      option.setAttribute(
        "aria-pressed",
        String(option.dataset.themeOption === value)
      );
    });
  }

  options.forEach((option) => {
    option.addEventListener("click", () => {
      applyPreference(option.dataset.themeOption);
      picker.removeAttribute("open");
      summary.focus();
    });
  });

  document.addEventListener("click", (event) => {
    if (!picker.contains(event.target)) {
      picker.removeAttribute("open");
    }
  });

  picker.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      picker.removeAttribute("open");
      summary.focus();
    }
  });

  applyPreference(storedPreference(), false);
})();
