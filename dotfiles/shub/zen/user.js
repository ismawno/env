// Zen Browser profile prefs. Copied into the active profile on every Home
// Manager activation (see home.activation.zenUserJs in users/maddev/home.nix).

// Use system DNS (respects Tailscale MagicDNS / Pi-hole)
user_pref("network.trr.mode", 5); // 5 = explicitly disable DoH, use system DNS only

// Off, as Zen ships it: its probe expects an empty reply, so Firefox's URL made every network look like a login page.
user_pref("network.captive-portal-service.enabled", false);
user_pref("captivedetect.canonicalURL", "http://firefox-portal-detection.com/generate_204");

// Iris Xe + iHD does full hw decode (H264/HEVC/VP9/AV1, verified with vainfo).
// The green/purple artifacting these once worked around was the OLD laptop's GPU.
user_pref("webgl.disabled", false);
user_pref("gfx.webrender.all", true);
user_pref("gfx.webrender.compositor", true);
user_pref("widget.dmabuf.force-enabled", true);
// Master switches. The restored profile carried these as false from the old
// laptop; user.js only overrides prefs it names, so they must be set here.
user_pref("media.hardware-video-decoding.enabled", true);
user_pref("gfx.webrender.enabled", true);
user_pref("layers.acceleration.disabled", false);
user_pref("gfx.canvas.accelerated", true);
user_pref("apz.content_response_timeout", 400);
user_pref("apz.axis_lock.mode", 2);
user_pref("dom.ipc.processPriorityManager.enabled", true);

// Must stay OFF: when on, Gecko skips the VA-API probe, then its Vulkan frame
// export dies (EGL_BAD_ACCESS) and it silently falls back to software.
user_pref("media.hardware-video-decoding-vulkan.enabled", false);

// Gecko 153 blocklists VA-API on the NVIDIA proprietary driver and never even
// runs vaapitest, so the feature reports FEATURE_FAILURE_VIDEO_DECODING_TEST_FAILED.
user_pref("media.hardware-video-decoding.force-enabled", true);

// Enable form autofill and password saving
user_pref("signon.rememberSignons", true);
user_pref("signon.autofillForms", true);
user_pref("browser.formfill.enable", true);
user_pref("extensions.formautofill.addresses.enabled", true);
user_pref("extensions.formautofill.creditCards.enabled", true);

// Restore the previous session on startup.
user_pref("browser.startup.page", 3);
