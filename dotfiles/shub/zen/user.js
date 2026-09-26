// Zen Browser prefs, copied into the active profile on every Home Manager activation (users/modules/zen.nix).

// 5 = DoH off, system DNS only, so Tailscale MagicDNS / Pi-hole apply.
user_pref("network.trr.mode", 5);

// Off, as Zen ships it: its probe expects an empty reply, so Firefox's URL made every network look like a login page.
user_pref("network.captive-portal-service.enabled", false);

// Iris Xe + iHD decodes H264/HEVC/VP9/AV1 in hardware; the master switches must be named, the restored profile had them false.
user_pref("webgl.disabled", false);
user_pref("gfx.webrender.all", true);
user_pref("gfx.webrender.compositor", true);
user_pref("widget.dmabuf.force-enabled", true);
user_pref("media.hardware-video-decoding.enabled", true);
user_pref("gfx.webrender.enabled", true);
user_pref("layers.acceleration.disabled", false);
user_pref("gfx.canvas.accelerated", true);
user_pref("apz.content_response_timeout", 400);
user_pref("apz.axis_lock.mode", 2);
user_pref("dom.ipc.processPriorityManager.enabled", true);

// Must stay OFF: when on, Gecko skips the VA-API probe and its Vulkan frame export dies (EGL_BAD_ACCESS) into software decode.
user_pref("media.hardware-video-decoding-vulkan.enabled", false);

user_pref("signon.rememberSignons", true);
user_pref("signon.autofillForms", true);
user_pref("browser.formfill.enable", true);
user_pref("extensions.formautofill.addresses.enabled", true);
user_pref("extensions.formautofill.creditCards.enabled", true);

// Restore the previous session on startup.
user_pref("browser.startup.page", 3);

// Gruvbox dark: scheme 0 = dark; the accent shows in a space with no picked colour dot, or only a custom one.
user_pref("zen.view.window.scheme", 0);
user_pref("zen.theme.accent-color", "#83a598");

// Shows Custom Color in a space's Edit Theme panel, the one way to give a space the exact Gruvbox #282828.
user_pref("zen.theme.gradient.show-custom-colors", true);
