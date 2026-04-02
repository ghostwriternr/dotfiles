{ ... }: {

  # ── Dock ────────────────────────────────────────────────────────────────────
  system.defaults.dock = {
    autohide = true;
    mru-spaces = false;           # Don't rearrange Spaces based on recent use
    show-recents = false;         # Hide recent apps section
    tilesize = 48;
    minimize-to-application = true;
    show-process-indicators = true;
  };

  # ── Keyboard ────────────────────────────────────────────────────────────────
  system.defaults.NSGlobalDomain = {
    InitialKeyRepeat = 10;        # Shortest: ~150ms before repeat starts
    KeyRepeat = 1;                # Fastest repeat rate
    ApplePressAndHoldEnabled = false;  # Disable accent popup, enable key repeat

    # Disable all "smart" text mangling
    NSAutomaticCapitalizationEnabled = false;
    NSAutomaticDashSubstitutionEnabled = false;
    NSAutomaticPeriodSubstitutionEnabled = false;
    NSAutomaticQuoteSubstitutionEnabled = false;
    NSAutomaticSpellingCorrectionEnabled = false;

    # Save/print panels: expanded by default
    NSNavPanelExpandedStateForSaveMode = true;
    NSNavPanelExpandedStateForSaveMode2 = true;
    PMPrintingExpandedStateForPrint = true;
    PMPrintingExpandedStateForPrint2 = true;

    # Scrollbar visibility
    AppleShowScrollBars = "WhenScrolling";

    # Hide menu bar (SketchyBar replaces it)
    _HIHideMenuBar = true;
  };

  # ── Custom preferences (not typed in nix-darwin) ───────────────────────────
  system.defaults.CustomUserPreferences.NSGlobalDomain = {
    AppleAccentColor = 3; # green
    SLSMenuBarUseBlurredAppearance = 1; # opaque bg when hidden menu bar shows on hover
  };

  # ── Finder ──────────────────────────────────────────────────────────────────
  system.defaults.finder = {
    AppleShowAllExtensions = true;
    ShowPathbar = true;
    ShowStatusBar = true;
    FXPreferredViewStyle = "Nlsv";       # List view by default
    FXDefaultSearchScope = "SCcf";       # Search current folder, not entire Mac
    FXEnableExtensionChangeWarning = false;
    _FXShowPosixPathInTitle = true;      # Full POSIX path in title bar
    _FXSortFoldersFirst = true;          # Folders on top when sorting by name
    NewWindowTarget = "Home";
  };

  # ── Mission Control / Spaces ────────────────────────────────────────────────
  system.defaults.spaces.spans-displays = false;  # Each display has its own Spaces

  # ── Trackpad ────────────────────────────────────────────────────────────────
  system.defaults.trackpad = {
    Clicking = true;                     # Tap to click
    TrackpadThreeFingerDrag = true;      # Three-finger drag
  };

  # ── Screenshots ─────────────────────────────────────────────────────────────
  system.defaults.screencapture = {
    type = "png";
    disable-shadow = true;               # No window shadow in screenshots
  };

  # ── Login window ────────────────────────────────────────────────────────────
  system.defaults.loginwindow = {
    GuestEnabled = false;
  };

  # ── Menu bar clock ─────────────────────────────────────────────────────────
  system.defaults.menuExtraClock = {
    Show24Hour = true;
    ShowSeconds = false;
  };

  # ── Touch ID for sudo ──────────────────────────────────────────────────────
  security.pam.services.sudo_local.touchIdAuth = true;
}
