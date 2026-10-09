{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "User";
      user.email = "user@example.com";
      init.defaultBranch = "main";
      core.editor = "vim";
      pull.rebase = true;
      alias = {
        st = "status";
        lg = "log --oneline";
      };
    };
  };
}
