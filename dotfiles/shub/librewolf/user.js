// Use system DNS (respects Tailscale MagicDNS / Pi-hole)
user_pref("network.trr.mode", 5); // 5 = explicitly disable DoH, use system DNS only

// Re-enable captive portal detection (fixes "behind firewall" warning)
user_pref("network.captive-portal-service.enabled", true);
user_pref("captivedetect.canonicalURL", "http://detectportal.firefox.com/canonical.html");

// Fix WhatsApp image artifacting (green/purple grids) - disable hardware acceleration that causes color issues
user_pref("webgl.disabled", false);
user_pref("gfx.webrender.all", true);
user_pref("gfx.webrender.compositor", true);
user_pref("media.ffmpeg.vaapi.enabled", false); // Disable hardware video decode that can cause artifacts
user_pref("widget.dmabuf.force-enabled", false); // Disable dmabuf which can cause color issues

// Enable form autofill and password saving
user_pref("signon.rememberSignons", true);
user_pref("signon.autofillForms", true);
user_pref("browser.formfill.enable", true);
user_pref("extensions.formautofill.addresses.enabled", true);
user_pref("extensions.formautofill.creditCards.enabled", true);
