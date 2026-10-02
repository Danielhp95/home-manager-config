# matplotlib in the selected palette. matplotlib is not installed here;
# projects bring their own, and all of them read ~/.config/matplotlib.
#
# Two levels, because a global dark ground would paint every saved figure
# (papers, docs, CI plots) dark, and break projects whose own style sheet sets
# a white axes but not its text colour:
#   matplotlibrc                    only the colour cycle, safe everywhere;
#   stylelib/palette.mplstyle       the full dark look, opt in with
#                                   `plt.style.use("palette")`.
# A switch reaches every Python started afterwards; open figures and running
# kernels keep the old colours. A project that sets its own cycle (a style
# sheet, seaborn) still wins over matplotlibrc.
#
# Hex is written without '#': in an rc file or style sheet that starts a
# comment, and matplotlib accepts bare six-digit hex for colours and cycles.
{ lib, ... }:
let
  p = import ./palette;

  # Categorical order: violet first, then the hues furthest from it, so two
  # series in one axes are never neighbours on the colour wheel. A palette that
  # gives two roles one colour (Ember's steel and orange) cycles it once.
  cycleOf =
    c:
    "axes.prop_cycle: cycler('color', ["
    + lib.concatMapStringsSep ", " (n: "'${n}'") (lib.unique [
      c.accent
      c.sage
      c.gold
      c.mauve
      c.steel
      c.olive
      c.extra.orange
      c.fgDim
    ])
    + "])";

  # matplotlibrc sits on whatever ground the project picks, usually white, so
  # it takes the light half's hues, which are tuned for paper.
  rc = ''
    # Generated from palette/ (matplotlib.nix); edits are overwritten.
    # Colour cycle only; `plt.style.use("palette")` is the full dark look.
    ${cycleOf p.light}
  '';

  style = ''
    # Generated from palette/ (matplotlib.nix); edits are overwritten.
    figure.facecolor: ${p.bg}
    figure.edgecolor: ${p.bg}
    savefig.facecolor: ${p.bg}
    savefig.edgecolor: ${p.bg}

    axes.facecolor: ${p.bg}
    axes.edgecolor: ${p.divider}
    axes.labelcolor: ${p.fg}
    axes.titlecolor: ${p.fg}
    ${cycleOf p}

    grid.color: ${p.border}

    text.color: ${p.fg}
    xtick.color: ${p.fgSoft}
    ytick.color: ${p.fgSoft}
    xtick.labelcolor: ${p.fgSoft}
    ytick.labelcolor: ${p.fgSoft}

    legend.facecolor: ${p.bgAlt}
    legend.edgecolor: ${p.border}

    boxplot.boxprops.color: ${p.fgSoft}
    boxplot.whiskerprops.color: ${p.fgSoft}
    boxplot.capprops.color: ${p.fgSoft}
    boxplot.medianprops.color: ${p.gold}
  '';
in
{
  xdg.configFile."matplotlib/matplotlibrc".text = rc;
  xdg.configFile."matplotlib/stylelib/palette.mplstyle".text = style;
}
