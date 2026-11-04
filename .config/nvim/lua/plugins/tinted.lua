return {
  "tinted-theming/tinted-nvim",
  priority = 1000,
  lazy = false,

  opts = {
    selector = {
      enabled = true,
      mode = "cmd",
      cmd = "tinty current",
    },
  },
}
