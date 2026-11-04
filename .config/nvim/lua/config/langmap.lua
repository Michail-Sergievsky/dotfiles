local M = {}

local current_layout = nil

local ru_langmap = "йq,цw,уe,кr,еt,нy,гu,шi,щo,зp,фa,ыs,вd,аf,пg,рh,оj,лk,дl,ж\\;,э',яz,чx,сc,мv,иb,тn,ьm,б\\,,ю.,х[,ъ],ё`,ЙQ,ЦW,УE,КR,ЕT,НY,ГU,ШI,ЩO,ЗP,ФA,ЫS,ВD,АF,ПG,РH,ОJ,ЛK,ДL,Ж:,Э\\\",ЯZ,ЧX,СC,МV,ИB,ТN,ЬM,Б<,Ю>,Х{,Ъ},Ё~,\\\"@,№#,\\;$,:^,?&,./,\\,?,/\\|"

local function set_layout(layout)
  if not layout or layout == current_layout then
    return
  end

  current_layout = layout

  if layout == "Russian" then
    vim.opt.langmap = ru_langmap
  else
    vim.opt.langmap = ""
  end
end

local function detect_layout()
  vim.system(
    { "swaymsg", "-t", "get_inputs", "-r" },
    { text = true },
    function(result)
      if result.code ~= 0 or not result.stdout then
        return
      end

      local ok, inputs = pcall(vim.json.decode, result.stdout)
      if not ok then
        return
      end

      for _, input in ipairs(inputs) do
        if input.type == "keyboard" and input.xkb_active_layout_name then
          vim.schedule(function()
            set_layout(input.xkb_active_layout_name)
          end)
          return
        end
      end
    end
  )
end

function M.setup()
  detect_layout()

  local buffer = ""

  vim.system(
    { "swaymsg", "-m", "-t", "subscribe", '["input"]' },
    {
      text = true,

      stdout = function(_, data)
        if not data then
          return
        end

        buffer = buffer .. data

        while true do
          local pos = buffer:find("\n", 1, true)

          if not pos then
            break
          end

          local line = buffer:sub(1, pos - 1)
          buffer = buffer:sub(pos + 1)

          local ok, event = pcall(vim.json.decode, line)

          if ok
              and event.change == "xkb_layout"
              and event.input
              and event.input.xkb_active_layout_name
          then
            vim.schedule(function()
              set_layout(event.input.xkb_active_layout_name)
            end)
          end
        end
      end,
    }
  )
end

return M
