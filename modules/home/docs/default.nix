{ config, lib, pkgs, ... }: {
  options.renman-ymd.docs.enable = lib.mkEnableOption "Markdown viewers and document converters";

  config = lib.mkIf config.renman-ymd.docs.enable {
    home.packages = with pkgs; [
      glow        # TUI/Pager
      frogmouth   # Full TUI browser
      go-grip     # Browser preview + live reload
      pandoc
      poppler
    ];
  };
}
