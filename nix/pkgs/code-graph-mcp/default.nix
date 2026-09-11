{
  stdenv,
  lib,
  autoPatchelfHook,
  makeWrapper,
  src,
  modelsSrc,
}:
stdenv.mkDerivation {
  name = "code-graph-mcp";
  inherit src;
  dontUnpack = true;

  nativeBuildInputs = [makeWrapper] ++ lib.optionals stdenv.hostPlatform.isLinux [autoPatchelfHook];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [stdenv.cc.cc.lib];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/code-graph-mcp

    install -Dm444 -t $out/share/code-graph-mcp/model \
      ${modelsSrc}/model.safetensors \
      ${modelsSrc}/tokenizer.json \
      ${modelsSrc}/config.json

    # Pins the release's own embedding weights; the binary re-downloads on any mismatch/absence.
    # git/ignore already covers .code-graph/, so skip the tool's own per-repo .gitignore writes.
    wrapProgram $out/bin/code-graph-mcp \
      --set-default CODE_GRAPH_MODEL_DIR "$out/share/code-graph-mcp/model" \
      --set-default CODE_GRAPH_DISABLE_MODEL_DOWNLOAD 1 \
      --set-default CODE_GRAPH_NO_GITIGNORE 1

    runHook postInstall
  '';

  meta = {
    description = "AST knowledge graph MCP server: semantic search, call graph traversal, HTTP route tracing, impact analysis";
    homepage = "https://github.com/sdsrss/code-graph-mcp";
    license = lib.licenses.mit;
    mainProgram = "code-graph-mcp";
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
