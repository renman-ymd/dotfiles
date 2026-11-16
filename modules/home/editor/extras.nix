# The extras of the editor core: group -> extra -> its Emacs packages.
# Each extra has an Elisp file, configs/emacs/extras/<group>/<extra>.el.
# `needs` names another extra, as [ group extra ], that it cannot work without.
{
  completion = {
    vertico.packages = e: [ e.vertico ];
    orderless.packages = e: [ e.orderless ];
    marginalia.packages = e: [ e.marginalia ];
    consult.packages = e: [ e.consult ];
    corfu.packages = e: [ e.corfu ];
    cape.packages = e: [ e.cape ];
  };

  comfort = {
    move-text.packages = e: [ e.move-text ];
    hl-todo.packages = e: [ e.hl-todo ];
    clipetty.packages = e: [ e.clipetty ];
    which-key.packages = e: [ ];
    gcmh.packages = e: [ e.gcmh ];
    no-littering.packages = e: [ e.no-littering ];
  };

  cursors = {
    multiple-cursors.packages = e: [ e.multiple-cursors ];
    tui-caret.packages = e: [ ];
  };

  editing = {
    embark.packages = e: [ e.embark ];
    embark-consult = {
      packages = e: [ e.embark e.embark-consult ];
      needs = [ "completion" "consult" ];
    };
    wgrep.packages = e: [ e.wgrep ];
    avy.packages = e: [ e.avy ];
    ace-window.packages = e: [ e.ace-window ];
    expand-region.packages = e: [ e.expand-region ];
    vundo.packages = e: [ e.vundo ];
    ws-butler.packages = e: [ e.ws-butler ];
    consult-todo = {
      packages = e: [ e.consult-todo ];
      needs = [ "completion" "consult" ];
    };
  };

  jj = {
    vc-jj.packages = e: [ e.vc-jj ];
    majutsu.packages = e: [ e.majutsu ];
    diff-hl.packages = e: [ e.diff-hl ];
  };

  ui = {
    doom-modeline.packages = e: [ e.doom-modeline ];
    nerd-icons.packages = e: [ e.nerd-icons e.nerd-icons-dired e.nerd-icons-completion ];
    rainbow-delimiters.packages = e: [ e.rainbow-delimiters ];
    indent-bars.packages = e: [ e.indent-bars ];
    diminish.packages = e: [ e.diminish ];
    helpful.packages = e: [ e.helpful ];
  };

  tools = {
    vterm.packages = e: [ e.vterm ];
    yasnippet.packages = e: [ e.yasnippet e.yasnippet-snippets ];
    rainbow-mode.packages = e: [ e.rainbow-mode ];
    csv-mode.packages = e: [ e.csv-mode ];
    treemacs.packages = e: [ e.treemacs ];
  };
}
