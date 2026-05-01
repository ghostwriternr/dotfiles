{ buildNpmPackage, fetchurl, lib }:

buildNpmPackage rec {
  pname = "pi-mcp-adapter";
  version = "2.5.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/pi-mcp-adapter/-/pi-mcp-adapter-${version}.tgz";
    hash = "sha256-71CttXvu1THITWAWAbBWqiQfOkciAcaemjKlmeli0x4=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-KRxEyrgSf5hCTl31c3f3JNRcRNnxF42L5+OzCx6qwTM=";
  dontNpmBuild = true;
  npmInstallFlags = [ "--ignore-scripts" ];
  npmPackFlags = [ "--ignore-scripts" ];

  meta = {
    description = "Pi package that adapts MCP servers into Pi tools";
    homepage = "https://www.npmjs.com/package/pi-mcp-adapter";
    license = lib.licenses.mit;
  };
}
