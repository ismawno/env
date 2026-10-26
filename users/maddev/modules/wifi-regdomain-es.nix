{
  # Regdomain was observed as "00" (world), the most restrictive; user is in Spain.
  hardware.wirelessRegulatoryDatabase = true;
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom="ES"
  '';
}
