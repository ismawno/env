{
  # App tokens (gh) are kept encrypted with the login password, which ly hands to the keyring at sign-in; mad.hypr.keyring finishes that startup in the session.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.ly.enableGnomeKeyring = true;
}
