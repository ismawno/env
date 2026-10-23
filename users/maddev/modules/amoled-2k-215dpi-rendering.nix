{
  # ~215 DPI: subpixel AA buys nothing and fringes at fractional scale.
  fonts = {
    fontconfig = {
      antialias = true;
      hinting = {
        enable = true;
        style = "slight"; # "full" would distort stems that are 3px wide here
      };
      subpixel = {
        rgba = "none";
        lcdfilter = "none"; # only meaningful with subpixel AA
      };
    };
  };
}
