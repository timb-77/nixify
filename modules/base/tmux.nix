{ ... }:
{
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    mouse = false;
    escapeTime = 500;
    historyLimit = 10000;
    extraConfig = ''
      set -g status-position bottom
    '';
  };
}
