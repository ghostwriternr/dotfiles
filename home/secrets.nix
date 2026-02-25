{ ... }:

{
  sops = {
    defaultSopsFile = ../secrets/default.yaml;
    age.sshKeyPaths = [ "/Users/naresh/.ssh/cloudflare/id_ed25519" ];

    secrets = {
      exa_api_key = {};
    };
  };
}
