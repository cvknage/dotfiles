return {
    "mxsdev/nvim-dap-vscode-js", -- https://github.com/mxsdev/nvim-dap-vscode-js
    dependencies = {
        "mfussenegger/nvim-dap",
        {
            "microsoft/vscode-js-debug",
            -- lazy = true,
            build = "npm install --legacy-peer-deps && npx gulp vsDebugServerBundle && rm -rf out && mv dist out",
        }
    },
}
