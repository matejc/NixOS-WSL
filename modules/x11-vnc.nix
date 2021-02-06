{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.vnc;
  vnc_config = pkgs.writeText "config" ''
    localhost
    depth=24
    PAMService=vnc
    SecurityTypes=plain
    PlainUsers=${cfg.user}
  '';
  xstartup = pkgs.writeScript "xstartup" ''
    #!/bin/sh
    . /etc/profile
    [ -x $HOME/.profile ] && . $HOME/.profile
    [ -r $HOME/.Xresources ] && ${pkgs.xorg.xrdb}/bin/xrdb $HOME/.Xresources
    export XDG_RUNTIME_DIR="/run/user/${toString config.users.users.${cfg.user}.uid}"
    exec ${cfg.startCmd}
  '';
  xinit = pkgs.writeScript "xinit.sh" ''
    #!/bin/sh
    systemctl restart systemd-logind
    sleep 0.2
    export XDG_RUNTIME_DIR="/run/user/${toString config.users.users.${cfg.user}.uid}"
    mkdir -p $XDG_RUNTIME_DIR
    chown -R ${cfg.user}:nobody $XDG_RUNTIME_DIR
    /wrappers/su -l ${cfg.user} -c 'env PATH="${makeBinPath (with pkgs; [ coreutils xorg.xinit xorg.xauth xterm xorg.xsetroot ])}:$PATH" xinit ${xstartup} -- ${cfg.package}/bin/Xvnc :${toString cfg.display} -depth 24 -localhost -auth $HOME/.Xauthority -desktop "$(uname -n):99 (${cfg.user})" -pn -rfbport ${toString (5900 + cfg.display)} -rfbauth ${cfg.passwordFile} -rfbwait 30000 +extension GLX +render -noreset +iglx'
  '';
in

{
  ###### interface

  options = {
    services.vnc = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable vnc as display manager.";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.tigervnc;
        defaultText = "pkgs.tigervnc";
        description = ''
          The package to use for the VNC daemon's binary.
        '';
      };

      display = mkOption {
        type = types.int;
        default = 99;
        description = ''
          Specifies display number.
        '';
      };

      startCmd = mkOption {
        type = types.str;
        default = "${pkgs.i3}/bin/i3";
        description = ''
          Desktop/window manager command.
        '';
      };

      user = mkOption {
        type = types.str;
        description = ''
          VNC service user.
        '';
      };

      passwordFile = mkOption {
        type = types.str;
        default = "/home/${cfg.user}/.vnc/passwd";
        description = ''
          VNC password file.
        '';
      };

      locale = mkOption {
        type = types.str;
        default = "en_US.UTF-8";
        description = ''
          VNC Locale.
        '';
      };

    };
  };

  ###### implementation

  config = mkIf cfg.enable {

    systemd.services.vnc = {
      description = "vnc server";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${xinit}";
        ExecStop = "${pkgs.procps}/bin/pkill -15 Xvnc";
        Restart = "always";
        RestartSec = "10s";
      };
    };

    security.pam.services.su.startSession = true;
    security.pam.services.su.enableKwallet = true;
    security.pam.services.su.enableGnomeKeyring = true;

    environment.systemPackages = [ cfg.package ];
  };

}
