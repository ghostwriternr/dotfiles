# home/theme.nix
# Centralized theme -- single source of truth.
# Currently: Everforest (hard contrast).
# To change themes: update palette values below, rebuild.
{ lib, ... }:

let
  # ── Raw palette (Everforest hard, community values) ──────────────
  dark = {
    bg_dim = "#1E2326";
    bg = "#2b3339"; bg0 = "#272E33"; bg1 = "#323c41"; bg2 = "#3a454a";
    bg3 = "#414B50"; bg4 = "#495156"; bg5 = "#4F5B58";
    bg_visual = "#4C3743"; bg_red = "#493B40"; bg_yellow = "#45443C";
    bg_green = "#3C4841"; bg_blue = "#384B55";
    fg = "#d3c6aa";
    grey0 = "#7a8478"; grey1 = "#859289"; grey2 = "#9da9a0";
  };
  light = {
    bg_dim = "#F2EFDF";
    bg = "#fdf6e3"; bg0 = "#FFFBEF"; bg1 = "#f4f0d9"; bg2 = "#efebd4";
    bg3 = "#EDEADA"; bg4 = "#E8E5D5"; bg5 = "#BEC5B2";
    bg_visual = "#F0F2D4"; bg_red = "#FFE7DE"; bg_yellow = "#FEF2D5";
    bg_green = "#F3F5D9"; bg_blue = "#ECF5ED";
    fg = "#5c6a72";
    grey0 = "#a6b0a0"; grey1 = "#b3c0b0"; grey2 = "#c0cdb8";
  };
  accent = {
    red = "#e67e80"; orange = "#e69875"; yellow = "#dbbc7f";
    green = "#a7c080"; aqua = "#83c092"; blue = "#7fbbb3";
    purple = "#d699b6";
  };
  accentLight = {
    red = "#f85552"; orange = "#f57d26"; yellow = "#dfa000";
    green = "#8da101"; aqua = "#35a77c"; blue = "#3a94c5";
    purple = "#df69ba";
  };
  ansiDark = {
    "0" = "#4b565c"; "1" = "#e67e80"; "2" = "#a7c080"; "3" = "#dbbc7f";
    "4" = "#7fbbb3"; "5" = "#d699b6"; "6" = "#83c092"; "7" = "#d3c6aa";
  };
  ansiLight = {
    "0" = "#5c6a72"; "1" = "#f85552"; "2" = "#8da101"; "3" = "#dfa000";
    "4" = "#3a94c5"; "5" = "#df69ba"; "6" = "#35a77c"; "7" = "#dfddc8";
  };
in
{
  options.theme = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Active color theme";
  };

  config.theme = {
    name = "everforest";
    variant = "hard";

    # Raw palette (for tools needing specific values)
    palette = { inherit dark light accent accentLight ansiDark ansiLight; };

    # Semantic roles (for theme-agnostic consumers)
    ui = {
      bg = { dark = dark.bg; light = light.bg; };
      bgDim = { dark = dark.bg_dim; light = light.bg_dim; };
      bgAlt = { dark = dark.bg1; light = light.bg1; };
      border = { dark = dark.bg3; light = light.bg3; };
      borderActive = { dark = accent.green; light = accentLight.green; };
      fg = { dark = dark.fg; light = light.fg; };
      muted = { dark = dark.grey0; light = light.grey0; };
      subtle = { dark = dark.grey2; light = light.grey2; };
    };
    diff = {
      addBg = { dark = dark.bg_green; light = light.bg_green; };
      removeBg = { dark = dark.bg_red; light = light.bg_red; };
    };
    syntax = {
      keyword = accent.red; string = accent.green;
      function = accent.blue; type = accent.yellow;
      constant = accent.aqua; number = accent.purple;
      operator = accent.orange; comment = { dark = dark.grey2; light = light.grey2; };
    };
    ansi = { dark = ansiDark; light = ansiLight; };
  };
}
