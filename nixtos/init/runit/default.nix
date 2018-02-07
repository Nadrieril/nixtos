{ pkgs, top }:

{
  kernel ? "kernel",
  files ? "files",
}:

extenders:

let
  # TODO(medium): compute `name` from the service name + given name
  services = top.lib.make-attrset (s:
    throw "Trying to define the same services at multiple locations: ${builtins.toJSON s}"
  ) (map (e: { name = e.name; value = e; }) extenders);

  services-dir =
    pkgs.runCommand "runit-services" {} (
      ''
        mkdir $out
      '' + pkgs.lib.concatStringsSep "\n" (pkgs.lib.mapAttrsToList (service: d:
        assert d.type == "service"; ''
          mkdir "$out/${service}"

          ln -s "/run/runit/supervise-${service}" \
                "$out/${service}/supervise"

          cat > "$out/${service}/run" <<EOF
          #!${pkgs.bash}/bin/bash

          exec ${pkgs.writeScript "runit-init-${service}" d.script}
          EOF

          chmod +x "$out/${service}/run"
        ''
      ) services)
    );
in
[
  { extends = kernel;
    data = {
      type = "init";
      command = "${pkgs.runit}/bin/runit";
    };
  }

  { extends = files;
    data = {
      type = "symlink";
      file = "/etc/runit/1";
      target = pkgs.writeScript "runit-1" "#!${pkgs.bash}/bin/bash";
    };
  }

  { extends = files;
    data = {
      type = "symlink";
      file = "/etc/runit/3";
      target = pkgs.writeScript "runit-3" "#!${pkgs.bash}/bin/bash";
    };
  }

  { extends = files;
    data = {
      type = "symlink";
      file = "/etc/runit/2";
      target = pkgs.writeScript "runit-2" ''
        #!${pkgs.bash}/bin/bash

        ${pkgs.coreutils}/bin/mkdir -p /run/runit

        exec ${pkgs.coreutils}/bin/env PATH=${pkgs.runit}/bin \
             ${pkgs.runit}/bin/runsvdir -P ${services-dir}
      '';
    };
  }
]
