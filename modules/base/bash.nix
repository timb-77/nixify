{ ... }:
{
  programs.bash = {
    enable = true;
    historySize = 10000;
    historyControl = [
      "ignoredups"
      "ignorespace"
    ];
    shellAliases = {
      ll = "ls -la";
      gs = "git status";
    };
    initExtra = ''
      # GSD-managed bash init
    '';
  };
  home.sessionVariables = {
    EDITOR = "vim";
    PAGER = "less";
  };
}
