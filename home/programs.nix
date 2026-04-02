{ config, lib, pkgs, ... }:

let
  t = config.theme;
  p = t.palette;

  batTmTheme = mode: let
    m = p.${mode};
    a = p.accent;
    s = name: scope: fg: ''
      <dict><key>name</key><string>${name}</string>
      <key>scope</key><string>${scope}</string>
      <key>settings</key><dict><key>foreground</key><string>${fg}</string></dict></dict>'';
    sStyle = name: scope: fg: style: ''
      <dict><key>name</key><string>${name}</string>
      <key>scope</key><string>${scope}</string>
      <key>settings</key><dict><key>foreground</key><string>${fg}</string>
      <key>fontStyle</key><string>${style}</string></dict></dict>'';
    sBg = name: scope: fg: bg: ''
      <dict><key>name</key><string>${name}</string>
      <key>scope</key><string>${scope}</string>
      <key>settings</key><dict><key>foreground</key><string>${fg}</string>
      <key>background</key><string>${bg}</string></dict></dict>'';
  in ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
      "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
    <key>name</key><string>Theme ${mode}</string>
    <key>settings</key><array>
      <dict><key>settings</key><dict>
        <key>background</key><string>${m.bg_dim}</string>
        <key>foreground</key><string>${m.fg}</string>
        <key>caret</key><string>${m.fg}</string>
        <key>selection</key><string>${m.bg_visual}</string>
        <key>selectionForeground</key><string>${m.fg}</string>
        <key>lineHighlight</key><string>${m.bg1}</string>
        <key>gutterBackground</key><string>${m.bg_dim}</string>
        <key>gutterForeground</key><string>${m.grey1}</string>
        <key>findHighlight</key><string>${a.yellow}</string>
        <key>findHighlightForeground</key><string>${m.bg_dim}</string>
        <key>guide</key><string>${m.bg2}</string>
        <key>activeGuide</key><string>${m.grey1}</string>
        <key>bracketsForeground</key><string>${a.aqua}</string>
        <key>bracketsOptions</key><string>underline</string>
        <key>bracketContentsForeground</key><string>${a.aqua}</string>
        <key>bracketContentsOptions</key><string>underline</string>
      </dict></dict>
      ${sStyle "Comment" "comment, punctuation.definition.comment" m.grey1 "italic"}
      ${s "String" "string, string.quoted" a.aqua}
      ${s "String Interpolation" "constant.character.escape, string.interpolated, punctuation.section.embedded" a.aqua}
      ${s "Number" "constant.numeric" a.purple}
      ${s "Built-in constant" "constant.language" a.purple}
      ${s "User constant" "constant.character, constant.other" a.aqua}
      ${s "Variable" "variable" m.fg}
      ${s "Parameter" "variable.parameter" m.fg}
      ${s "Keyword" "keyword" a.red}
      ${s "Control keyword" "keyword.control" a.red}
      ${s "Operator" "keyword.operator" a.orange}
      ${s "Storage" "storage" a.red}
      ${s "Storage type" "storage.type" a.yellow}
      ${s "Class name" "entity.name.class, entity.name.type.class" a.yellow}
      ${s "Inherited class" "entity.other.inherited-class" a.yellow}
      ${s "Function name" "entity.name.function" a.green}
      ${s "Function call" "variable.function, support.function" a.green}
      ${s "Type" "entity.name.type, support.type" a.yellow}
      ${s "Built-in type" "support.type.builtin" a.yellow}
      ${s "Tag name" "entity.name.tag" a.aqua}
      ${s "Tag attribute" "entity.other.attribute-name" a.green}
      ${s "Punctuation" "punctuation" m.grey1}
      ${s "Punctuation definition" "punctuation.definition.tag, punctuation.definition.string" m.grey1}
      ${s "Library class" "support.class" a.yellow}
      ${s "Library constant" "support.constant" a.purple}
      ${sBg "Invalid" "invalid" m.fg a.red}
      ${sBg "Invalid deprecated" "invalid.deprecated" m.fg a.purple}
      ${s "Diff inserted" "markup.inserted, meta.diff.header.to-file" a.green}
      ${s "Diff deleted" "markup.deleted, meta.diff.header.from-file" a.red}
      ${s "Diff changed" "markup.changed" a.yellow}
      ${s "Diff range" "meta.diff.range, meta.diff.index" a.aqua}
      ${sStyle "Markup heading" "markup.heading, punctuation.definition.heading" a.blue "bold"}
      ${s "Markup link" "markup.underline.link, string.other.link" a.blue}
      ${s "Markup list" "markup.list, punctuation.definition.list" a.aqua}
      ${sStyle "Markup quote" "markup.quote" m.grey1 "italic"}
      ${s "Markup raw" "markup.raw, markup.inline.raw" a.aqua}
      ${s "JSON key" "meta.structure.dictionary.key.json string.quoted" a.blue}
      ${s "YAML key" "entity.name.tag.yaml" a.blue}
      ${s "CSS selector" "entity.name.tag.css, entity.other.attribute-name.class.css, entity.other.attribute-name.id.css" a.yellow}
      ${s "CSS property" "support.type.property-name.css" a.blue}
      ${s "CSS value" "support.constant.property-value.css" a.orange}
      ${s "Regex" "string.regexp" a.aqua}
      ${s "Namespace" "entity.name.namespace, entity.name.module" a.yellow}
      ${s "Decorator" "meta.decorator, meta.annotation" a.purple}
      ${s "Shell variable" "variable.other.normal.shell, variable.other.positional.shell, variable.other.bracket.shell, variable.other.special.shell" m.fg}
      ${s "Shell command" "support.function.builtin.shell" a.green}
    </array></dict></plist>
  '';

  ripgrepConfig = mode: let
    g = p.${mode};
    a = p.accent;
  in ''
    # Colors (all 5 ripgrep color types)
    --colors=match:fg:${a.green}
    --colors=match:style:bold
    --colors=line:fg:${g.grey2}
    --colors=path:fg:${a.blue}
    --colors=path:style:bold
    --colors=column:fg:${g.grey2}
    --colors=match:bg:${g.bg_green}

    # Sensible defaults (from ivuorinen/everforest-resources reference)
    --smart-case
    --hidden
    --follow
    --glob=!.git/*
    --glob=!node_modules/*
    --glob=!.vscode/*
    --glob=!.idea/*
    --max-columns=150
    --max-columns-preview
    --line-number
  '';

  ghosttyTheme = mode: let
    n = t.ansi.${mode};
    b = if mode == "dark" then {
      "0" = p.light.grey0; "1" = p.accentLight.red; "2" = p.accentLight.green;
      "3" = p.accentLight.yellow; "4" = p.accentLight.blue; "5" = p.accentLight.purple;
      "6" = p.accentLight.aqua; "7" = p.light.bg0;
    } else {
      "0" = p.dark.grey0; "1" = p.accent.red; "2" = p.accent.green;
      "3" = p.accent.yellow; "4" = p.accent.blue; "5" = p.accent.purple;
      "6" = p.accent.aqua; "7" = p.dark.fg;
    };
    bg = p.${mode}.bg;
    fg = p.${mode}.fg;
    sel = p.${mode}.bg_visual;
  in ''
    palette = 0=${n."0"}
    palette = 1=${n."1"}
    palette = 2=${n."2"}
    palette = 3=${n."3"}
    palette = 4=${n."4"}
    palette = 5=${n."5"}
    palette = 6=${n."6"}
    palette = 7=${n."7"}
    palette = 8=${b."0"}
    palette = 9=${b."1"}
    palette = 10=${b."2"}
    palette = 11=${b."3"}
    palette = 12=${b."4"}
    palette = 13=${b."5"}
    palette = 14=${b."6"}
    palette = 15=${b."7"}
    background=${bg}
    foreground=${fg}
    cursor-color=${fg}
    cursor-text=${bg}
    selection-foreground=${fg}
    selection-background=${sel}
  '';
in
{
  # ── Direnv ──────────────────────────────────────────────────────────────────
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    silent = true;
    # TODO: remove after nixpkgs-unstable includes NixOS/nixpkgs#502769
    package = pkgs.direnv.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace GNUmakefile --replace-fail " -linkmode=external" ""
      '';
    });
  };

  # ── FZF ─────────────────────────────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # ── Zoxide ──────────────────────────────────────────────────────────────────
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # ── Starship ────────────────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      format = "$directory$git_branch$git_status$fill$cmd_duration$line_break$character";

      directory = {
        truncation_length = 4;
        style = "bold blue";
      };

      git_branch = {
        symbol = " ";
        style = "bold purple";
      };

      git_status = {
        format = "([\\[$all_status$ahead_behind\\]]($style) )";
        style = "bold red";
      };

      fill.symbol = " ";

      cmd_duration = {
        min_time = 2000;
        format = "[$duration](italic yellow)";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
    };
  };

  # ── Neovim ──────────────────────────────────────────────────────────────────
  # Config managed separately at ~/.config/nvim (ghostwriternr/LazyVim)
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # ── Shared color include ─────────────────────────────────────────────────
  # Sourced by SketchyBar and JankyBorders configs.
  home.file.".config/theme/current.sh".text = let
    d = p.dark; l = p.light; a = p.accent; al = p.accentLight;
  in ''
    #!/usr/bin/env bash
    # Generated by nix from home/programs.nix -- do not edit
    if defaults read -g AppleInterfaceStyle &>/dev/null; then
      THEME_BG="${d.bg}"; THEME_BG_DIM="${d.bg_dim}"; THEME_BG3="${d.bg3}"
      THEME_FG="${d.fg}"; THEME_GREY0="${d.grey0}"; THEME_GREY2="${d.grey2}"
      THEME_GREEN="${a.green}"; THEME_AQUA="${a.aqua}"; THEME_RED="${a.red}"
    else
      THEME_BG="${l.bg}"; THEME_BG_DIM="${l.bg_dim}"; THEME_BG3="${l.bg3}"
      THEME_FG="${l.fg}"; THEME_GREY0="${l.grey0}"; THEME_GREY2="${l.grey2}"
      THEME_GREEN="${al.green}"; THEME_AQUA="${al.aqua}"; THEME_RED="${al.red}"
    fi
  '';

  # ── SketchyBar ──────────────────────────────────────────────────────────
  home.file.".config/sketchybar/sketchybarrc" = {
    source = ../config/sketchybar/sketchybarrc;
    executable = true;
  };
  home.file.".config/sketchybar/plugins/spaces.sh" = {
    source = ../config/sketchybar/plugins/spaces.sh;
    executable = true;
  };
  home.file.".config/sketchybar/plugins/battery.sh" = {
    source = ../config/sketchybar/plugins/battery.sh;
    executable = true;
  };
  home.file.".config/sketchybar/plugins/clock.sh" = {
    source = ../config/sketchybar/plugins/clock.sh;
    executable = true;
  };

  # ── JankyBorders ───────────────────────────────────────────────────────
  home.file.".config/borders/bordersrc" = {
    source = ../config/borders/bordersrc;
    executable = true;
  };

  # ── Ripgrep ────────────────────────────────────────────────────────────────
  # Color configs generated from Everforest palette; precmd hook switches between them.
  home.file.".config/ripgrep/config-dark".text = ripgrepConfig "dark";
  home.file.".config/ripgrep/config-light".text = ripgrepConfig "light";

  # ── Bat ──────────────────────────────────────────────────────────────────
  # Theme files generated from Everforest palette.
  home.file.".config/bat/themes/theme-dark.tmTheme".text = batTmTheme "dark";
  home.file.".config/bat/themes/theme-light.tmTheme".text = batTmTheme "light";

  programs.bat = {
    enable = true;
  };

  # ── Eza ──────────────────────────────────────────────────────────────────
  programs.eza = {
    enable = true;
    icons = "auto";
    git = false;
  };

  # ── Ghostty ────────────────────────────────────────────────────────────────
  # Installed via brew cask; nix manages config only.
  # Theme files generated from Everforest palette below.
  home.file.".config/ghostty/themes/theme-dark".text = ghosttyTheme "dark";
  home.file.".config/ghostty/themes/theme-light".text = ghosttyTheme "light";

  programs.ghostty = {
    enable = true;
    package = null;
    settings = {
      theme = "dark:theme-dark,light:theme-light";
      font-family = "FiraCode Nerd Font";
      font-size = 14;
      font-thicken = true;
      cursor-style = "block";
      mouse-hide-while-typing = true;
      macos-titlebar-style = "transparent";
      adjust-cell-height = "25%";
      keybind = "shift+enter=text:\\x1b\\r";
    };
  };

  # ── SSH ────────────────────────────────────────────────────────────────────
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false; # all defaults match SSH's own; avoids redundant Host * block
    includes = [
      "~/.colima/ssh_config"
    ];
    matchBlocks."cloudflare" = {
      match = "all";
      extraOptions = {
        Include = "~/.ssh/cloudflare/config";
      };
    };
  };

  # ── btop ─────────────────────────────────────────────────────────────────
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "everforest-dark-hard";
      theme_background = false;
    };
  };

  # ── fastfetch ───────────────────────────────────────────────────────────
  home.file.".config/fastfetch/config.jsonc".source = ../config/fastfetch/config.jsonc;

  # ── Theme watcher (reloads SketchyBar/JankyBorders on appearance change) ─
  home.file.".local/bin/theme-watcher" = {
    source = ../config/theme-watcher/theme-watcher;
    executable = true;
  };

  launchd.agents.theme-watcher = {
    enable = true;
    config = {
      Label = "com.user.theme-watcher";
      ProgramArguments = [ "/Users/naresh/.local/bin/theme-watcher" ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  # ── GitHub CLI ────────────────────────────────────────────────────────────
  programs.gh = {
    enable = true;
    settings = {
      version = 1;
      git_protocol = "ssh";
    };
  };
}
