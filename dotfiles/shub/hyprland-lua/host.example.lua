-- Stand-in for the host.lua that Nix renders on NixOS; copy it to ~/.config/hypr/host.lua elsewhere.
return {
  monitors = {
    { output = "", mode = "preferred", position = "auto", scale = 1 },
  },

  inactive_opacity = 0.7,
  blur = true,

  -- A laptop sets this to the switch name plus a script taking close, open or sync.
  lid = nil,

  programs = {},
}
