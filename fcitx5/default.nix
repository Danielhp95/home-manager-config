# fcitx5 via home-manager's i18n.inputMethod module: it wraps the package with
# the addons, writes ~/.config/fcitx5 declaratively, and generates the
# fcitx5-daemon user service (WantedBy=graphical-session.target, so it starts
# with any compositor session and survives hyprland's target restart).
#
# The whole ~/.config/fcitx5 directory becomes a read-only store symlink, so
# nothing can be changed via fcitx5-configtool without porting it back here.
# The `settings` below are the former user-level files transcribed verbatim
# (config -> globalOptions, profile -> inputMethod, conf/*.conf -> addons).
# Mutable runtime data (pinyin user dict, rime data) lives in ~/.local/share
# and is unaffected.
{ pkgs, ... }:

{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        rime-data
        fcitx5-gtk # Does help with making fcitx5 work in QT apps
        fcitx5-rime
        qt6Packages.fcitx5-configtool
        qt6Packages.fcitx5-chinese-addons
        fcitx5-rose-pine
        (import ./ember/package.nix { inherit (pkgs) stdenvNoCC lib librsvg; })
      ];

      settings = {
        # ~/.config/fcitx5/config
        globalOptions = {
          Hotkey = {
            EnumerateWithTriggerKeys = "True";
            EnumerateForwardKeys = "";
            EnumerateBackwardKeys = "";
            EnumerateSkipFirst = "False";
            ModifierOnlyKeyTimeout = 250;
          };
          "Hotkey/TriggerKeys"."0" = "Alt+space"; # Trigger fcitx5
          "Hotkey/ActivateKeys"."0" = "Hangul_Hanja";
          "Hotkey/DeactivateKeys"."0" = "Hangul_Romaja";
          "Hotkey/AltTriggerKeys"."0" = "Shift_L";
          "Hotkey/EnumerateGroupForwardKeys"."0" = "Super+space";
          "Hotkey/EnumerateGroupBackwardKeys"."0" = "Shift+Super+space";
          "Hotkey/PrevPage"."0" = "Up";
          "Hotkey/NextPage"."0" = "Down";
          "Hotkey/PrevCandidate"."0" = "Shift+Tab";
          "Hotkey/NextCandidate"."0" = "Tab";
          "Hotkey/TogglePreedit"."0" = "Control+Alt+P";
          Behavior = {
            ActiveByDefault = "False";
            resetStateWhenFocusIn = "No";
            ShareInputState = "No";
            PreeditEnabledByDefault = "True";
            ShowInputMethodInformation = "True";
            showInputMethodInformationWhenFocusIn = "False";
            CompactInputMethodInformation = "True";
            ShowFirstInputMethodInformation = "True";
            DefaultPageSize = 5;
            OverrideXkbOption = "False";
            CustomXkbOption = "";
            EnabledAddons = "";
            DisabledAddons = "";
            PreloadInputMethod = "True";
            AllowInputMethodForPassword = "False";
            ShowPreeditForPassword = "False";
            AutoSavePeriod = 30;
          };
        };

        # ~/.config/fcitx5/profile (the input method list)
        inputMethod = {
          GroupOrder."0" = "Default";
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "pinyin";
          };
          "Groups/0/Items/0" = {
            Name = "keyboard-us";
            Layout = "";
          };
          "Groups/0/Items/1" = {
            Name = "pinyin";
            Layout = "";
          };
        };

        # ~/.config/fcitx5/conf/*.conf
        addons = {
          # fcitx5 only reads these from here now; don't recreate them via
          # fcitx5-configtool without porting changes back.
          # This is the former user-level config verbatim, plus Theme=Ember.
          classicui.globalSection = {
            "Vertical Candidate List" = "False";
            WheelForPaging = "True";
            Font = "\"Sans 14\"";
            MenuFont = "\"Sans 14\"";
            TrayFont = "\"Sans Bold 14\"";
            TrayOutlineColor = "#000000";
            TrayTextColor = "#ffffff";
            PreferTextIcon = "False";
            ShowLayoutNameInIcon = "True";
            UseInputMethodLanguageToDisplayText = "True";
            Theme = "Ember";
            DarkTheme = "Ember";
            UseDarkTheme = "False";
            UseAccentColor = "True";
            PerScreenDPI = "False";
            ForceWaylandDPI = "0";
            EnableFractionalScale = "True";
          };

          pinyin = {
            globalSection = {
              ShuangpinProfile = "Ziranma";
              ShowShuangpinMode = "True";
              PageSize = 7;
              SpellEnabled = "True";
              SymbolsEnabled = "True";
              ChaiziEnabled = "True";
              ExtBEnabled = "True";
              StrokeCandidateEnabled = "True";
              CloudPinyinEnabled = "True";
              CloudPinyinIndex = 2;
              CloudPinyinAnimation = "True";
              KeepCloudPinyinPlaceHolder = "False";
              PreeditMode = "\"Composing pinyin\"";
              PreeditCursorPositionAtBeginning = "True";
              PinyinInPreedit = "False";
              Prediction = "False";
              KeepCurrentContext = "True";
              PredictionSize = 49;
              BackspaceBehaviorOnPrediction = "\"Backspace when not using on-screen keyboard\"";
              SwitchInputMethodBehavior = "\"Commit current preedit\"";
              SecondCandidate = "";
              ThirdCandidate = "";
              UseKeypadAsSelection = "False";
              BackSpaceToUnselect = "True";
              "Number of sentence" = 2;
              WordCandidateLimit = 15;
              LongWordLengthLimit = 4;
              QuickPhraseKey = "semicolon";
              VAsQuickphrase = "True";
              FirstRun = "False";
            };
            sections = {
              ForgetWord."0" = "Control+7";
              PrevPage = {
                "0" = "minus";
                "1" = "Up";
                "2" = "KP_Up";
                "3" = "Page_Up";
              };
              NextPage = {
                "0" = "equal";
                "1" = "Down";
                "2" = "KP_Down";
                "3" = "Next";
              };
              PrevCandidate."0" = "Shift+Tab";
              NextCandidate."0" = "Tab";
              CurrentCandidate = {
                "0" = "space";
                "1" = "KP_Space";
              };
              CommitRawInput = {
                "0" = "Return";
                "1" = "KP_Enter";
                "2" = "Control+Return";
                "3" = "Control+KP_Enter";
                "4" = "Shift+Return";
                "5" = "Shift+KP_Enter";
                "6" = "Control+Shift+Return";
                "7" = "Control+Shift+KP_Enter";
              };
              ChooseCharFromPhrase = {
                "0" = "bracketleft";
                "1" = "bracketright";
              };
              FilterByStroke."0" = "grave";
              QuickPhraseTriggerRegex = {
                "0" = ".(/|@)$";
                "1" = "\"^(www|bbs|forum|mail|bbs)\\\\\\\\.\"";
                "2" = "^(http|https|ftp|telnet|mailto):";
              };
              Fuzzy = {
                VE_UE = "True";
                NG_GN = "True";
                Inner = "True";
                InnerShort = "True";
                PartialFinal = "True";
                PartialSp = "False";
                V_U = "False";
                AN_ANG = "False";
                EN_ENG = "False";
                IAN_IANG = "False";
                IN_ING = "False";
                U_OU = "False";
                UAN_UANG = "False";
                C_CH = "False";
                F_H = "False";
                L_N = "False";
                L_R = "False";
                S_SH = "False";
                Z_ZH = "False";
                Correction = "None";
              };
            };
          };

          chttrans = {
            globalSection = {
              Engine = "OpenCC";
              EnabledIM = "";
              OpenCCS2TProfile = "default";
              OpenCCT2SProfile = "default";
            };
            sections.Hotkey."0" = "Control+Shift+F";
          };

          punctuation = {
            globalSection = {
              HalfWidthPuncAfterLetterOrNumber = "True";
              TypePairedPunctuationsTogether = "False";
              Enabled = "True";
            };
            sections.Hotkey."0" = "Control+period";
          };

          notifications.sections.HiddenNotifications."0" = "wayland-diagnose-other";
        };
      };
    };
  };
}
